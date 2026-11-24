import 'dart:async';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../art/photo_art.dart';
import '../data/database.dart';
import '../game/pet_game.dart';
import '../pet/checkup.dart';
import '../pet/cues.dart';
import '../pet/friends.dart';
import '../pet/guest.dart';
import '../pet/josa.dart';
import '../pet/kindergarten.dart';
import '../pet/pet_controller.dart';
import '../pet/pet_rules.dart';
import '../pet/spots.dart';
import '../pet/treasure.dart';
import '../pet/treats.dart';
import '../pet/tricks.dart';
import '../pet/walk_log.dart' show WalkStepCoverage;
import '../pet/wish.dart';
import '../services/notifications.dart';
import '../services/sfx.dart';
import '../services/steps.dart';
import '../services/telemetry.dart';
import '../services/test_mode.dart';
import '../services/weather.dart';
import 'c3/c3_theme.dart';
import 'c3/gauge_sticker.dart';
import 'c3/index_tabs.dart';
import 'c3/memo_input.dart';
import 'c3/paper.dart';
import 'c3/pixel_icon.dart';
import 'c3/polaroid.dart';
import 'c3/stamp_button.dart';
import 'c3/sticker_button.dart';
import 'c3/sticker_card.dart';
import 'c3/tape.dart';
import 'checkup_card.dart';
import 'collection_screen.dart';
import 'diary_screen.dart';
import 'crisis_dialog.dart';
import 'friends.dart';
import 'walk_card.dart';
import 'walk_journal.dart';
import 'lesson_picker.dart';
import 'keep_words.dart';
import 'place_card.dart';
import 'play_tray.dart';
import 'shape_picker.dart';
import 'trick_notebook.dart';
import 'time_sheet.dart';
import 'settings_screen.dart';
import 'town_map.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.db,
    required this.onReset,
    this.testMode,
    this.onTestMode,
    this.onJump,
    this.speech,
    this.effects,
    this.stepsStorage,
  });

  final PetController controller;
  final AppDatabase db;
  final Sfx? effects;
  final Future<void> Function() onReset;

  /// 테스트 빌드에서만 있다. 켜져 있으면 위에 띠가 뜨고 시간을 보낼 수 있다.
  final TestMode? testMode;
  final Future<void> Function(bool on)? onTestMode;
  final Future<void> Function(Duration d)? onJump;

  @visibleForTesting
  final SpeechToText? speech;

  @visibleForTesting
  final FlutterSecureStorage? stepsStorage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PetGame _game = PetGame(widget.controller);
  late final AppLifecycleListener _lifecycle;
  final _input = TextEditingController();
  late final _speech = widget.speech ?? SpeechToText();
  final _steps = StepCounter();
  final _playTrayKey = GlobalKey();
  final _playPresses = <(PlayAction, Trick?), ({int pointer, int input})>{};
  Timer? _walkClock;
  int _walkSession = 0;
  bool _confirmingWalk = false;
  StreamSubscription<Cue>? _cueSub;
  int _tab = 0;
  int _seenDiary = 0;
  bool _listening = false;
  bool _micBusy = false;
  int _micSession = 0;
  int _feedbackSession = 0;
  bool _settingsOpen = false;
  bool _savingPracticeTime = false;
  bool _appPaused = false;

  // SpeechToText는 화면이 바뀌어도 같은 인스턴스이므로 이전 취소가 끝난 뒤 시작한다.
  static Future<void> _speechOperations = Future<void>.value();
  bool _toldAboutKey = false;
  bool _toldAboutAi = false;
  bool _toldAboutDaycare = false;
  bool _checkingSteps = false;

  bool get _acceptsInput =>
      !widget.controller.isResetting && !widget.controller.isDisposed;

  bool get _canHearRoom =>
      !_appPaused &&
      !_settingsOpen &&
      !_listening &&
      !_micBusy &&
      _tab == 0 &&
      _acceptsInput;

  static const _storage = FlutterSecureStorage();
  static const _stepsAskedKey = 'steps_asked';
  PetController? _stepsDialogOwner;

  void _releaseStepsDialog() {
    final owner = _stepsDialogOwner;
    _stepsDialogOwner = null;
    if (owner != null && !owner.isDisposed) owner.uiBusy = false;
  }

  @override
  void initState() {
    super.initState();
    _game.onDoorTap = _openMap;
    _game.onGuestTap = _guestCard;
    // resumed까지 기다리면 분할 화면처럼 포커스 없이 돌아온 경우 inactive 상태에서 게임 루프가 먼저 돌아
    // 비운 시간을 덮어쓴다. paused→hidden 시점에 계산해야 루프가 다시 돌기 전에 끝난다.
    _lifecycle = AppLifecycleListener(
      onPause: () {
        _appPaused = true;
        _leaveRoomSound();
        widget.controller.sleepApp();
      },
      onRestart: () {
        _appPaused = false;
        widget.controller.wake();
      },
      onResume: _offerPocketSteps,
    );
    _seenDiary = widget.controller.diaryVersion;
    // 말을 듣는 동안 짖으면 음성 인식이 그 소리까지 받아 적는다.
    _cueSub = widget.controller.cues.listen((cue) {
      if (!mounted || !_canHearRoom) return;
      final session = _feedbackSession;
      final route = ModalRoute.of(context);
      final inFront = route?.isCurrent;
      final pet = widget.controller.pet;
      (widget.effects ?? appSfx).play(
        cue,
        shape: pet.shape,
        puppy: pet.stage == PetStage.puppy,
        stillHere: () =>
            mounted &&
            _canHearRoom &&
            session == _feedbackSession &&
            route?.isCurrent == inFront,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFromNotification();
      _offerPocketSteps();
    });
    Notifications.opened.addListener(_showFromNotification);
  }

  @override
  void dispose() {
    _releaseStepsDialog();
    Notifications.opened.removeListener(_showFromNotification);
    _lifecycle.dispose();
    _leaveRoomSound();
    _cueSub?.cancel();
    if (_micSession > 0) {
      _micSession++;
      unawaited(
        _withSpeech(() async {
          _speech.errorListener = null;
          _speech.statusListener = null;
          await _speech.cancel();
        }).catchError((Object _) {}),
      );
    }
    _input.dispose();
    _walkSession++;
    _walkClock?.cancel();
    _steps.stop();
    super.dispose();
  }

  /// 알림을 눌러 열었으면 그 알림이 부르는 탭으로 간다.
  void _showFromNotification() {
    final to = Notifications.opened.value;
    if (to == null || !mounted) return;
    Notifications.opened.value = null;
    Telemetry.track('notification_open', {'to': to});
    Navigator.of(context).popUntil(
      (route) =>
          route.settings.name != WalkJournal.routeName &&
          route.settings.name != walkMapRouteName,
    );
    _selectTab(to == 'diary' ? 1 : 0);
  }

  void _leaveRoomSound() {
    _feedbackSession++;
    (widget.effects ?? appSfx).silence();
  }

  void _selectTab(int index) {
    if (index != _tab) _leaveRoomSound();
    setState(() => _tab = index);
    widget.controller.roomHidden = index != 0;
    if (index == 0) _offerPocketSteps();
  }

  // 처음 하루는 직접 산책을 시작할 때만 걸음 권한을 묻는다.
  bool get _canOfferPocketSteps {
    final c = widget.controller;
    return _acceptsInput &&
        _tab == 0 &&
        !c.walking &&
        !c.uiBusy &&
        c.now().difference(c.pet.bornAt) >= const Duration(days: 1) &&
        ModalRoute.of(context)?.isCurrent == true;
  }

  Future<void> _offerPocketSteps() async {
    if (!mounted || _checkingSteps || !_canOfferPocketSteps) return;
    _checkingSteps = true;
    try {
      await _askSteps();
    } finally {
      _checkingSteps = false;
    }
  }

  /// 주머니 걸음은 걸음 권한이 있어야 한다. 시스템 창보다 먼저 왜 필요한지 한 번만 묻는다.
  Future<void> _askSteps() async {
    if (!mounted || !_acceptsInput) return;
    final storage = widget.stepsStorage ?? _storage;
    if (await StepCounter.isGranted() || !mounted || !_acceptsInput) return;
    try {
      if (await storage.read(key: _stepsAskedKey) == 'true' ||
          !mounted ||
          !_acceptsInput) {
        return;
      }
    } on Exception {
      return;
    }
    if (!mounted || !_canOfferPocketSteps) return;
    final c = widget.controller;
    final name = c.pet.name;
    final yes = await _withStepsDialog(
      c,
      () => showC3Dialog<bool>(
        context,
        title: '${josa(name, '이/가')} 동네를 돌아다녀도 될까요?',
        body: Text(
          '앱을 열 때 폰이 센 걸음 수를 한 번만 읽어요. '
          '주인이 걸은 만큼 $name도 동네를 돌며 뭔가 주워 와요. '
          '위치나 경로는 보지 않아요.',
        ),
        actions: [
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('나중에'),
            ),
          ),
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('좋아요'),
            ),
          ),
        ],
      ),
    );
    if (!mounted || !_acceptsInput || !identical(widget.controller, c)) return;
    // 실제 안내에 응답하기 전에 완료로 저장하면 화면 전환 때 안내를 영영 놓칠 수 있다.
    try {
      await storage.write(key: _stepsAskedKey, value: 'true');
    } on Exception {
      return;
    }
    if (!mounted || !_acceptsInput) return;
    final granted =
        yes == true && await _withStepsDialog(c, StepCounter.request);
    if (!mounted || !_acceptsInput) return;
    Telemetry.track('steps_permission', {
      'asked': yes == true,
      'granted': granted,
    });
    if (granted && identical(widget.controller, c)) await c.collectNow();
  }

  Future<T> _withStepsDialog<T>(
    PetController c,
    Future<T> Function() show,
  ) async {
    _stepsDialogOwner = c;
    c.uiBusy = true;
    try {
      return await show();
    } finally {
      _releaseStepsDialog();
    }
  }

  Future<void> _send(String text, {bool voice = false}) async {
    if (!_acceptsInput) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _input.clear();
    final outcome = await widget.controller.talk(text, voice: voice);
    if (!mounted || !_acceptsInput) return;
    final name = widget.controller.pet.name;
    // 힘없는 말엔 펫이 말없이 곁에 온다. 그때 '연결 안 됨·쉬고 싶대요' 안내가 뜨면 거절처럼 읽혔다.
    final soft = needsComfort(text) && !askingOrDenying(text);
    switch (outcome) {
      case TalkOutcome.crisis:
        await showCrisisDialog(context);
      case TalkOutcome.noBrain when !_toldAboutKey && !soft:
        _toldAboutKey = true;
        _snack('오른쪽 위 설정에서 AI 서버를 연결하면 ${josa(name, '이/가')} 말을 알아들어요.');
      case TalkOutcome.recordIssue:
        _snack('이번 대화 기록 일부를 저장하지 못했어요.');
      case TalkOutcome.historyUnavailable:
        _snack('기억을 불러오지 못해 이번에는 폰 안 반응으로 이어갔어요.');
      case TalkOutcome.failed when !_toldAboutAi && !soft:
        _toldAboutAi = true;
        _snack('AI 답변을 받지 못해 이번에는 폰 안 반응으로 이어가요.');
      case TalkOutcome.away when !_toldAboutDaycare:
        _toldAboutDaycare = true;
        _snack('지금은 유치원에 있어요. 소리는 안 가도 마음은 가나 봐요.');
      // 자는 동안은 아무 반응이 없어 말이 사라진 것처럼 보인다. 그래서 매번 알려 준다.
      case TalkOutcome.awayAsleep:
        _snack('유치원 낮잠 시간이라 자고 있어요. 깨면 다시 불러 봐요.');
      case TalkOutcome.limited when !soft:
        _snack('오늘은 이야기를 많이 해서 ${josa(name, '이/가')} 쉬고 싶대요. 내일 또 얘기해요.');
      default:
    }
  }

  Future<void> _withSpeech(Future<void> Function() operation) {
    final next = _speechOperations.then((_) => operation());
    _speechOperations = next.catchError((Object _) {});
    return next;
  }

  Future<void> _toggleMic() async {
    if (!mounted || _micBusy) return;
    _micBusy = true;
    _leaveRoomSound();
    final stopping = _listening;
    final session = stopping ? _micSession : ++_micSession;
    bool active() => mounted && session == _micSession;
    try {
      await _withSpeech(() async {
        if (!active()) return;
        if (stopping) {
          await _speech.stop();
          if (active()) setState(() => _listening = false);
          return;
        }
        // 초기화가 캐시되면 SDK가 콜백을 교체하지 않으므로 현재 화면에 다시 연결한다.
        _speech.errorListener = (e) {
          if (!active()) return;
          Telemetry.track('mic_error', {'error': e.errorMsg});
          setState(() => _listening = false);
        };
        _speech.statusListener = (status) {
          if (active() && status == 'done') {
            setState(() => _listening = false);
          }
        };
        final ready = await _speech.initialize(
          onError: _speech.errorListener,
          onStatus: _speech.statusListener,
        );
        if (!active()) return;
        if (!ready) {
          _snack('음성 인식을 켤 수 없어요. 마이크 권한을 확인해 주세요.');
          return;
        }
        setState(() => _listening = true);
        Telemetry.track('mic_start');
        await _speech.listen(
          listenOptions: SpeechListenOptions(localeId: 'ko_KR'),
          onResult: (r) {
            if (!active()) return;
            _input.text = r.recognizedWords;
            if (r.finalResult) {
              Telemetry.track('mic_result', {
                'length': r.recognizedWords.length,
              });
              setState(() => _listening = false);
              _send(r.recognizedWords, voice: true);
            }
          },
        );
      });
    } on Exception {
      if (active()) {
        setState(() => _listening = false);
        _snack('음성 인식을 켤 수 없어요.');
      }
    } finally {
      _micBusy = false;
    }
  }

  Future<void> _startWalk() async {
    final c = widget.controller;
    if (c.walking || !c.startWalk()) return;
    final session = ++_walkSession;
    _walkClock = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
    final counted = await _steps.start(
      (steps) => c.updateWalkSteps(steps, deviceTotal: _steps.deviceTotal),
      onUnavailable: c.markWalkSensorUnavailable,
    );
    if (!mounted || session != _walkSession || !c.walking) return;
    if (!counted && !c.walkSensorUnavailable) {
      c.markWalkSensorUnavailable();
      Telemetry.track('steps_permission_denied');
      _snack('걸음 수 권한이 없어서 시간만 재요.');
    }
  }

  Future<void> _confirmEndWalk() async {
    final c = widget.controller;
    if (_confirmingWalk || c.uiBusy || !c.walking || !_acceptsInput) return;
    final session = _walkSession;
    _confirmingWalk = true;
    c.uiBusy = true;
    bool? finish;
    try {
      finish = await showC3Dialog<bool>(
        context,
        title: '산책을 마칠까요?',
        body: const Text('지금까지 함께 걸은 기록을 남기고 집으로 돌아갈 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 걷기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('산책 마치기'),
          ),
        ],
      );
    } finally {
      _confirmingWalk = false;
      if (!c.isDisposed) c.uiBusy = false;
    }
    if (finish == true &&
        mounted &&
        _acceptsInput &&
        session == _walkSession &&
        c.walking) {
      _endWalk();
    }
  }

  void _endWalk() {
    if (!widget.controller.walking) return;
    _walkSession++;
    _walkClock?.cancel();
    _walkClock = null;
    _steps.stop();
    final c = widget.controller;
    final r = c.endWalk();
    setState(() {});
    // 문만 나갔다 들어온 짧은 산책은 지도 대신 한 줄로.
    if (r.minutes == 0) {
      _snack(
        '잠깐 다녀왔어요 · ${walkStepLabel(r.steps, r.coverage)}'
        '${r.finds > 0 ? ' · 뭔가 물고 왔어요!' : ''}',
      );
      return;
    }
    c.uiBusy = true;
    unawaited(
      showWalkCard(
        context,
        name: c.pet.name,
        startedAt: r.startedAt,
        minutes: r.minutes,
        steps: r.steps,
        coverage: r.coverage,
        finds: r.finds,
        spots: r.spots,
      ).whenComplete(() => c.uiBusy = false),
    );
  }

  /// 방 문이나 사진 아래 지도를 누르면 동네를 고른다. 지도가 떠 있는 동안은 쉬 신호를 미룬다.
  Future<void> _openMap() async {
    final c = widget.controller;
    if (!_acceptsInput ||
        c.uiBusy ||
        _tab != 0 ||
        c.out ||
        c.walking ||
        c.replaying ||
        !c.canGoOut()) {
      return;
    }
    c.uiBusy = true;
    Spot? picked;
    try {
      picked = await showTownMap(
        context,
        wish: switch (c.openWish) {
          final w? => wishSpot(w),
          null => null,
        },
      );
    } finally {
      c.uiBusy = false;
    }
    if (!mounted ||
        !_acceptsInput ||
        _tab != 0 ||
        c.out ||
        c.walking ||
        c.replaying) {
      return;
    }
    switch (picked) {
      case Spot.cafe:
        if (c.goToCafe()) unawaited(_maybeFriendCard());
      case Spot.kindergarten when !kinderOpen(c.now()):
        _snack('유치원은 아침 7시부터 저녁 7시까지 열어요.');
      case Spot.kindergarten:
        c.goToKindergarten();
      case Spot.treatShop:
        c.goToTreatShop();
      case Spot.hospital:
        c.goToHospital();
      case Spot.park:
        await _startWalk();
      default:
    }
  }

  /// 처음 서로 킁킁한 날은 그 장면이 끝나면(컨트롤러가 카드를 잡으면) 친구 카드를 보여 준다.
  Future<void> _maybeFriendCard() async {
    final c = widget.controller;
    for (
      var i = 0;
      i < 90 && mounted && !c.isDisposed && c.atCafe && c.pendingCard == null;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    while (mounted &&
        !c.isDisposed &&
        c.atCafe &&
        (c.uiBusy || c.isResetting)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final g = c.pendingCard;
    if (!mounted || !_acceptsInput || g == null || !c.atCafe || c.uiBusy) {
      return;
    }
    c.pendingCard = null;
    c.uiBusy = true;
    try {
      await showFriendDialog(context, c, g);
    } finally {
      c.uiBusy = false;
    }
  }

  /// 카페 손님을 누르면 친구 카드. 만난 적 있는 애만(처음 보는 날은 만남 장면 뒤에 카드가 뜬다).
  Future<void> _guestCard(Guest g) async {
    final c = widget.controller;
    if (c.uiBusy || (c.friends[g.id]?.bond ?? Bond.none) == Bond.none) return;
    c.uiBusy = true;
    try {
      await showFriendDialog(context, c, g);
    } finally {
      c.uiBusy = false;
    }
  }

  /// 카페에서 개인기 칸을 열어 둔 동안. 공 없이도 친구들 앞에서 시킬 수 있다.
  bool _cafeTray = false;

  void _comeHome() {
    final c = widget.controller;
    final was = c.spot;
    _cafeTray = false;
    final minutes = c.comeHome();
    _snack(switch (was) {
      Spot.kindergarten => '유치원에서 놀다 왔어요.',
      Spot.treatShop => '간식 가게에서 돌아왔어요.',
      Spot.hospital => '병원에서 돌아왔어요.',
      _ when minutes > 0 => '카페에서 $minutes분 놀고 왔어요.',
      _ => '카페에서 놀고 왔어요.',
    });
    setState(() {});
  }

  Future<void> _dropOff() async {
    final c = widget.controller;
    if (!canDropOff(c.now())) {
      _snack('유치원은 오후 5시까지만 맡길 수 있어요.');
      return;
    }
    final choice = await showLessonPicker(context, c.tricks);
    if (choice == null || !mounted || !_acceptsInput) return;
    if (c.dropOff(lesson: choice.trick)) {
      _snack(
        c.daycareRecitalPlanned
            ? '오늘은 오후 3시에 발표회가 있어요. 그때 열면 CCTV로 볼 수 있어요. 하원은 저녁 7시.'
            : '저녁 7시에 하원해요. 그 전에 열면 유치원 CCTV가 보여요.',
      );
    } else {
      _snack('유치원은 오후 5시까지만 맡길 수 있어요.');
    }
    setState(() {});
  }

  void _buyExtraTreat() {
    final c = widget.controller;
    if (c.buyExtraTreat()) {
      _snack(
        '${josa(c.shopPick!.name, '을/를')} 하나 더 넣었어요. 발도장 $extraTreatPaws개를 썼어요.',
      );
    }
    setState(() {});
  }

  void _buyTreat() {
    final c = widget.controller;
    if (c.buyTreat()) {
      _snack('${josa(c.shopPick!.name, '을/를')} 주머니에 넣었어요. 집에서 꺼내 줄 수 있어요.');
    }
    setState(() {});
  }

  Future<void> _checkup() async {
    final c = widget.controller;
    final record = c.startCheckup();
    if (record == null) return;
    setState(() {});
    // 체중계에 올라가 재는 모습을 먼저 보여 주고 수첩을 띄운다.
    await Future<void>.delayed(const Duration(seconds: 7));
    if (!mounted || !_acceptsInput) return;
    final here = ModalRoute.of(context)?.isCurrent ?? false;
    if (c.spot != Spot.hospital || !here || _recordOpen) return;
    await _showRecord(record);
  }

  bool _recordOpen = false;

  Future<void> _showRecord(CheckupRecord record) async {
    final c = widget.controller;
    c.uiBusy = true;
    _recordOpen = true;
    try {
      await showC3Dialog<void>(
        context,
        title: '건강 수첩',
        body: CheckupCard(record: record),
      );
    } finally {
      c.uiBusy = false;
      _recordOpen = false;
    }
  }

  void _pickUp() {
    widget.controller.pickUp();
    _snack('유치원에서 데려왔어요.');
    setState(() {});
  }

  Future<void> _receive() async {
    final c = widget.controller;
    final r = await c.receive();
    if (r == null || !mounted || !_acceptsInput) return;
    c.uiBusy = true;
    try {
      await showFoundDialog(context, c, r);
    } finally {
      c.uiBusy = false;
    }
  }

  Future<void> _openSettings() async {
    if (_settingsOpen) return;
    _settingsOpen = true;
    _leaveRoomSound();
    final c = widget.controller;
    c.uiBusy = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(
            controller: c,
            effects: widget.effects,
            onReset: widget.onReset,
            testMode: widget.testMode,
            onTestMode: widget.onTestMode,
          ),
        ),
      );
    } finally {
      _settingsOpen = false;
      c.uiBusy = false;
    }
  }

  /// 연습 모드 띠. 누르면 시간을 보낸다.
  Widget _testBar(PetController c) {
    final now = c.now();
    final mm = now.minute.toString().padLeft(2, '0');
    return Material(
      color: C3Colors.tapeYellow,
      child: InkWell(
        onTap: _savingPracticeTime ? null : () => _openTimeSheet(c),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '연습 펫 · ${now.month}/${now.day} ${now.hour}:$mm '
                  '(${aheadLabel(widget.testMode!.offset)})',
                  style: C3Text.label.copyWith(fontSize: 14),
                ),
              ),
              Text(
                _savingPracticeTime ? '시간 저장 중…' : '시간 보내기 ›',
                style: C3Text.label.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTimeSheet(PetController c) async {
    if (!TestMode.canJump(c)) {
      _snack('산책이나 카페·가게·병원에서 집에 온 뒤에 시간을 보내요.');
      return;
    }
    final d = await showTimeSheet(context, c.now);
    if (d == null || !mounted || widget.controller != c || !_acceptsInput) {
      return;
    }
    setState(() => _savingPracticeTime = true);
    try {
      await widget.onJump?.call(d);
    } on FileSystemException {
      if (mounted && widget.controller == c) {
        _snack('연습 시간을 저장하지 못했어요. 시간 보내기를 다시 눌러 주세요.');
      }
    } finally {
      if (mounted) setState(() => _savingPracticeTime = false);
    }
  }

  void _snack(String text) {
    if (!mounted || !_acceptsInput) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final top = MediaQuery.paddingOf(context).top;
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    // 기록을 읽다가 뒤로 가면 돌보던 집으로 돌아간다.
    return ListenableBuilder(
      listenable: c,
      builder: (context, child) => PopScope<void>(
        canPop: _tab == 0 && !c.walking,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || !_acceptsInput) return;
          if (_tab != 0) {
            _selectTab(0);
          } else if (c.walking) {
            unawaited(_confirmEndWalk());
          }
        },
        child: child!,
      ),
      child: Scaffold(
        backgroundColor: C3Colors.kraft,
        body: PaperBackground(
          child: Padding(
            padding: EdgeInsets.only(top: top + 8),
            child: IndexedStack(
              index: _tab,
              children: [
                _home(c, typing),
                TickerMode(
                  enabled: _tab == 1,
                  child: DiaryScreen(
                    controller: c,
                    db: widget.db,
                    visible: _tab == 1,
                  ),
                ),
                CollectionScreen(controller: c),
              ],
            ),
          ),
        ),
        // 글을 쓰는 동안은 탭을 숨겨 방이 덜 줄어들게 한다.
        bottomNavigationBar: typing
            ? null
            : ListenableBuilder(
                listenable: c,
                builder: (context, _) {
                  // 일기 탭을 보고 있는 동안 써진 일기는 이미 본 것이다.
                  if (_tab == 1) _seenDiary = c.diaryVersion;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      WalkSaveNotice(controller: c),
                      IndexTabs(
                        labels: const ['집', '일기', '도감'],
                        icons: const ['house', 'book', 'box'],
                        selected: _tab,
                        // 새 일기가 써졌으면 일기 탭을 열 때까지 점을 찍어 둔다.
                        dots: {if (c.diaryVersion != _seenDiary) 1},
                        onSelect: (i) {
                          Telemetry.track('tab', {
                            'to': const ['home', 'diary', 'collection'][i],
                          });
                          _selectTab(i);
                        },
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _home(PetController c, bool typing) {
    // 세로가 짧으면 게이지를 접고 돌봄 스티커를 작은 한 줄로 표시한다.
    return LayoutBuilder(
      builder: (context, box) {
        final compact = typing || box.maxHeight < 480;
        final room = _homeColumn(
          c,
          typing: typing,
          showGauges: !typing && box.maxHeight >= 600,
          showActions: !compact,
          // 개인기 이름이 여러 줄로 감겨도 방과 대화 입력란을 남긴다.
          maxPlayTrayHeight: box.maxHeight * .4,
        );
        // 화면 분할·시스템 여백이 큰 창에서도 방이 사라지지 않게 아래 입력줄까지 스크롤한다.
        return ListenableBuilder(
          listenable: c,
          child: room,
          builder: (context, child) {
            final controlsHeight = _availableRoomActions(c).isEmpty
                ? 0.0
                : 48.0;
            final minHeight = (typing ? 270.0 : 380.0) + controlsHeight;
            return SingleChildScrollView(
              child: SizedBox(
                height: box.maxHeight < minHeight ? minHeight : box.maxHeight,
                child: child,
              ),
            );
          },
        );
      },
    );
  }

  Widget _homeColumn(
    PetController c, {
    required bool typing,
    required bool showGauges,
    required bool showActions,
    required double maxPlayTrayHeight,
  }) {
    return Column(
      children: [
        if (widget.testMode?.on ?? false)
          ListenableBuilder(
            listenable: c,
            builder: (context, _) => _testBar(c),
          ),
        ListenableBuilder(
          listenable: c,
          builder: (context, _) =>
              _Header(controller: c, onSettings: _openSettings),
        ),
        if (showGauges)
          ListenableBuilder(
            listenable: c,
            builder: (context, _) => _Gauges(stats: c.stats),
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, showActions ? 16 : 8, 12, 0),
            child: _roomPhoto(c, typing: typing, showActions: showActions),
          ),
        ),
        ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            if (c.walking) return _walkPanel(c);
            if (c.out && !(c.atCafe && _cafeTray)) return _placePanel(c);
            if (!c.out) {
              if (c.replaying) return _replayPanel(c);
              if (typing) return const SizedBox();
              if (c.ball == Ball.none) {
                return _actions(c, compact: !showActions);
              }
            }
            final tray = _playTray(c, compact: !showActions, atCafe: c.out);
            if (!showActions) return tray;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxPlayTrayHeight),
              child: tray,
            );
          },
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            showActions ? 10 : 4,
            12,
            showActions ? 10 : 4,
          ),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: c,
                    builder: (context, _) => MemoInput(
                      controller: _input,
                      hint: _listening
                          ? '듣고 있어요…'
                          : c.praiseOpen
                          ? '지금 간식을 주면 칭찬이 돼요'
                          : c.ball != Ball.none
                          ? '"앉아"처럼 말로 시켜도 돼요'
                          : _handHint(c)
                          ? '방 바닥을 길게 누르면 손을 내밀어요'
                          : '${c.pet.name}에게 말 걸기…',
                      listening: _listening,
                      onMic: _toggleMic,
                      onSubmit: (t) {
                        if (!_listening) _send(t);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StampButton(
                  enabled: !_listening,
                  onTap: () => _send(_input.text),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _roomPhoto(
    PetController c, {
    required bool typing,
    required bool showActions,
  }) {
    return LayoutBuilder(
      builder: (context, frame) => ListenableBuilder(
        listenable: c,
        child: ExcludeFocus(child: GameWidget(game: _game, autofocus: false)),
        builder: (context, game) {
          final controls = _roomActions(c);
          final playing =
              !c.walking &&
              (c.out
                  ? c.atCafe && _cafeTray
                  : !typing && !c.replaying && c.ball != Ball.none);
          // 사진틀에는 캡션과 선택 버튼도 들어간다. 놀이판을 연 뒤 사진이 낮아지면
          // 강아지 머리 위에 구름을 겹쳐 그리지 않고 사진 아래에서 전문을 읽게 한다.
          final shortPlayRoom =
              _tab == 0 &&
              playing &&
              frame.maxHeight < 180 + (controls == null ? 0 : 48);
          final inRoom = showActions && !shortPlayRoom;
          _game.showThoughtInRoom = inRoom;
          final thought = c.bubble;

          bool canPet() =>
              mounted &&
              _acceptsInput &&
              identical(widget.controller, c) &&
              _tab == 0 &&
              !c.uiBusy &&
              !c.roomHidden &&
              !c.walking &&
              !c.out &&
              !c.replaying;
          final pettable = canPet();
          void pet() {
            if (canPet()) c.interact(Interaction.pet);
          }

          final roomThought = inRoom ? thought : null;
          return Polaroid(
            caption: _caption(c),
            controls: controls,
            captionRight: inRoom ? _captionRight(c) : null,
            captionContent: !inRoom && thought != null
                ? _compactThought(c, thought, c.bubbleFromAi)
                : null,
            action: typing || c.walking || c.out || c.replaying
                ? null
                : TextButton.icon(
                    onPressed: _openMap,
                    icon: const Icon(Icons.map_outlined, size: 17),
                    label: const Text('동네 지도'),
                    style: TextButton.styleFrom(
                      foregroundColor: C3Colors.ink,
                      backgroundColor: C3Colors.tapeMint,
                      textStyle: C3Text.label.copyWith(fontSize: 14),
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PetKeyboardTarget(
                  onPet: pettable ? pet : null,
                  child: Semantics(
                    container: true,
                    liveRegion: roomThought != null,
                    button: pettable,
                    onTap: pettable ? pet : null,
                    onTapHint: pettable ? '쓰다듬기' : null,
                    label: roomThought == null
                        ? (pettable ? '${c.pet.name} 쓰다듬기' : c.pet.name)
                        : '${c.pet.name}의 ${c.bubbleFromAi ? 'AI 속마음' : '속마음'}',
                    value: roomThought,
                    child: game,
                  ),
                ),
                Stack(
                  fit: StackFit.expand,
                  children: [
                    _homeCamButton(c, compact: !showActions),
                    _PawToast(controller: c),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 방 바닥은 어디서든 개를 만질 수 있게 두고, 그때 할 수 있는 일은 사진 테두리에 모은다.
  List<(String, String, VoidCallback)> _availableRoomActions(PetController c) {
    final here = !c.walking && !c.out;
    final held = c.presenting;
    return [
      if (here && !c.replaying && held != null)
        (
          held.source == FindSource.window ? '창틀 보기' : '손 내밀기',
          'palm',
          _receive,
        ),
      if (here && c.pottyUrge) ('패드로', 'paw_ink', c.goToPad),
      if (c.recitalReady) ('발표회', 'sparkle', c.startRecital),
    ];
  }

  Widget? _roomActions(PetController c) {
    final actions = _availableRoomActions(c);
    if (actions.isEmpty) return null;
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 6,
      children: [
        for (final (label, icon, action) in actions)
          TextButton.icon(
            onPressed: action,
            icon: PixelIcon(icon),
            label: Text(label),
            style: TextButton.styleFrom(
              foregroundColor: C3Colors.ink,
              backgroundColor: C3Colors.tapeYellow,
              minimumSize: const Size(48, 32),
              tapTargetSize: MaterialTapTargetSize.padded,
              textStyle: C3Text.label.copyWith(fontSize: 14),
            ),
          ),
      ],
    );
  }

  /// 손 베개를 아직 안 써 본 사람에게 말 걸기 칸에서 가끔 알려 준다(친해진 뒤, 한 시간 중 10분).
  bool _handHint(PetController c) =>
      c.intimacy != Intimacy.stranger && !c.triedHand && c.now().minute < 10;

  Widget _compactThought(PetController c, String thought, bool fromAi) {
    final title = '${c.pet.name}의 ${fromAi ? 'AI 속마음' : '속마음'}';
    Future<void> open() async {
      if (!_acceptsInput || c.uiBusy) return;
      c.uiBusy = true;
      try {
        await showC3Dialog<void>(
          context,
          title: title,
          body: Text(keepWords(thought), style: C3Text.pet),
        );
      } finally {
        c.uiBusy = false;
      }
    }

    return Semantics(
      button: true,
      liveRegion: true,
      label: title,
      value: thought,
      excludeSemantics: true,
      onTap: open,
      child: TextButton(
        onPressed: open,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: C3Colors.ink,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Text(
          '${fromAi ? 'AI · ' : ''}$thought',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: C3Text.pet.copyWith(fontSize: 16, height: 1.15),
        ),
      ),
    );
  }

  String _caption(PetController c) {
    final now = c.now();
    final place = switch (c.spot) {
      Spot.cafe => '동네 강아지 카페',
      Spot.kindergarten => '동네 강아지 유치원',
      Spot.treatShop => '동네 간식 가게',
      Spot.hospital => '동네 동물병원',
      _ => '${c.pet.name}네 방',
    };
    return '${now.month}월 ${now.day}일, $place';
  }

  String _captionRight(PetController c) {
    if (c.walking) return '산책 중';
    if (c.inDaycare) return '유치원 CCTV';
    if (c.spot == Spot.treatShop) return '하루 한 번 간식';
    if (c.spot == Spot.hospital) return '일주일에 한 번 검진';
    if (c.out) return '친구 ${c.guests.length}마리';
    if (c.ball == Ball.ready) return '위로 쓱 튕겨 던지기';
    if (c.walkProposed) return '산책 가자고 해요!';
    final day =
        '${const ['월', '화', '수', '목', '금', '토', '일'][c.now().weekday - 1]}요일';
    final sky = switch (c.weather?.sky) {
      Sky.rain => '비 오는 ',
      Sky.snow => '눈 오는 ',
      Sky.clear => '맑은 ',
      Sky.cloudy => '흐린 ',
      null => '',
    };
    return '$sky$day';
  }

  Widget _actions(PetController c, {required bool compact}) {
    // 간식이 있으면 네 번째 스티커. 방 위에 두면 문 앞 펫을 가려 쓰다듬으려다 간식이 나갔다.
    final treats = c.pouch.length;
    final width = treats > 0 ? 80.0 : 104.0;
    final buttons = [
      StickerButton(
        compact: compact,
        cut: 'bowl',
        icon: 'bowl',
        label: '밥 주기',
        tilt: -3,
        width: width,
        onTap: () => c.interact(Interaction.feed),
      ),
      StickerButton(
        compact: compact,
        cut: 'ball',
        icon: 'ball',
        label: '놀아주기',
        tilt: 2,
        width: width,
        onTap: () => _playInput(c, PlayAction.open, apply: c.takeOutBall),
      ),
      StickerButton(
        compact: compact,
        cut: 'tree',
        icon: 'tree',
        label: '산책 가기',
        tilt: -1.5,
        width: width,
        highlighted: c.walkProposed,
        onTap: _startWalk,
      ),
      if (treats > 0)
        StickerButton(
          compact: compact,
          cut: 'box',
          icon: 'bone',
          label: '간식 $treats',
          tilt: 2.5,
          width: width,
          onTap: c.giveTreat,
        ),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(14, compact ? 2 : 12, 14, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [for (final button in buttons) Flexible(child: button)],
      ),
    );
  }

  Widget _playTray(
    PetController c, {
    required bool compact,
    required bool atCafe,
  }) {
    final tracing = Telemetry.playTraceEnabled;
    return PlayTray(
      key: _playTrayKey,
      compact: compact,
      homePlay: !atCafe,
      hide: atCafe ? const {Trick.fetch} : const {},
      // 진단 프레임에서는 이 위젯이 받은 수치와 이후의 컨트롤러 수치를 구분한다.
      tricks: tracing ? Map.unmodifiable(c.tricks) : c.tricks,
      onPointer: tracing ? _playPointer : null,
      onTrick: (trick) => _playInput(c, PlayAction.trick, trick: trick),
      onNotebook: () => _playInput(
        c,
        PlayAction.notebook,
        apply: () => showTrickNotebook(context, c),
      ),
      onThrow: !atCafe && c.ball == Ball.ready
          ? () => _playInput(c, PlayAction.throwBall, apply: _game.tossBall)
          : null,
      treats: atCafe ? 0 : c.pouch.length,
      onTreat: atCafe || c.ball == Ball.carried
          ? null
          : () => _playInput(c, PlayAction.treat, apply: c.giveTreat),
      onClose: () => _playInput(
        c,
        PlayAction.close,
        apply: () {
          try {
            if (!atCafe) c.putBallAway();
          } finally {
            // 공이 이미 치워졌거나 다음 행동 선택에서 실패해도 현재 상태로 다시 그린다.
            setState(() => _cafeTray = false);
          }
        },
      ),
    );
  }

  void _playPointer(PlayAction action, Trick? trick, PointerEvent e) {
    final key = (action, trick);
    if (e is PointerDownEvent) {
      if (_playPresses.containsKey(key)) return;
      final id = Telemetry.playTrace(
        action,
        PlayPhase.pointer,
        trick: trick,
        ball: widget.controller.ball,
        atCafe: widget.controller.atCafe,
      );
      _playPresses[key] = (pointer: e.pointer, input: id);
      return;
    }
    // onTap은 포인터 처리 끝에서 확정된다. 스크롤·길게 누르기로 소비된 터치만 취소로 남긴다.
    scheduleMicrotask(() {
      final press = _playPresses[key];
      if (press == null || press.pointer != e.pointer) return;
      _playPresses.remove(key);
      Telemetry.playTrace(
        action,
        PlayPhase.cancel,
        trick: trick,
        input: press.input,
      );
    });
  }

  void _playInput(
    PetController c,
    PlayAction action, {
    Trick? trick,
    VoidCallback? apply,
  }) {
    final tracing = Telemetry.playTraceEnabled;
    final press = _playPresses.remove((action, trick));
    int log(PlayPhase phase, {int? id, Enum? outcome, bool frame = false}) {
      final tray = _playTrayKey.currentWidget as PlayTray?;
      final progress = trick == null || (frame && tray == null)
          ? null
          : (frame ? tray!.tricks[trick] : c.tricks[trick]) ??
                const TrickProgress();
      return Telemetry.playTrace(
        action,
        phase,
        input: id,
        trick: trick,
        outcome: outcome,
        ball: c.ball,
        atCafe: c.atCafe,
        menuOpen: frame
            ? tray != null
            : (c.atCafe ? _cafeTray : c.ball != Ball.none),
        attempts: progress?.attempts,
        successes: progress?.successes,
        stars: progress?.stars,
      );
    }

    final input = tracing ? log(PlayPhase.tap, id: press?.input) : null;
    Enum? outcome;
    try {
      if (trick != null) {
        outcome = c.command(trick);
      } else {
        apply!();
      }
      if (tracing) log(PlayPhase.result, id: input, outcome: outcome);
    } catch (_) {
      if (tracing) log(PlayPhase.error, id: input);
      rethrow;
    } finally {
      if (tracing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && identical(widget.controller, c)) {
            log(PlayPhase.frame, id: input, frame: true);
          }
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      }
    }
  }

  Widget _walkPanel(PetController c) {
    final now = c.now();
    final since = now.difference(c.walkStartedAt ?? now);
    final elapsed = since.isNegative ? Duration.zero : since;
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: StickerCard(
        tape: C3Colors.tapeMint,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Row(
          children: [
            const PixelIcon('tree', scale: 3),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('산책 중 · $mm:$ss', style: C3Text.label),
                  const SizedBox(height: 2),
                  Text(
                    c.walkStepCoverage == WalkStepCoverage.timeOnly
                        ? (c.walkSensorUnavailable ? '시간으로 기록 중' : '걸음 센서 대기 중')
                        : walkStepLabel(c.walkSteps, c.walkStepCoverage),
                    style: C3Text.body.copyWith(color: C3Colors.ink2),
                  ),
                ],
              ),
            ),
            FilledButton(onPressed: _endWalk, child: const Text('집으로')),
          ],
        ),
      ),
    );
  }

  Widget _shopCard(PetController c, Widget home) {
    final pick = c.shopPick;
    if (!c.pickShown || pick == null) {
      return PlaceCard(
        tape: C3Colors.tapeSky,
        icon: 'bone',
        title: '간식 가게',
        subtitle: '고르는 중…',
        actions: [home],
      );
    }
    final full = c.pouch.length >= pouchSize;
    return PlaceCard(
      tape: C3Colors.tapeSky,
      icon: 'bone',
      title: pick.name,
      subtitle: c.canBuyExtraTreat
          ? '발도장으로 하나 더?'
          : c.boughtToday
          ? '오늘은 샀어요'
          : full
          ? '주머니 꽉 참'
          : '골랐어요!',
      actions: [
        if (!c.boughtToday && !full)
          OutlinedButton(
            style: compactButton,
            onPressed: _buyTreat,
            child: const Text('사 주기'),
          ),
        if (c.canBuyExtraTreat)
          OutlinedButton(
            style: compactButton,
            onPressed: _buyExtraTreat,
            child: const Text('발도장 $extraTreatPaws'),
          ),
        home,
      ],
    );
  }

  /// 몇 시간 비웠다 오면 방 오른쪽 위에 뜨는 홈캠. 누르면 비운 사이 장면을 다시 본다.
  Widget _homeCamButton(PetController c, {required bool compact}) {
    if (c.homeCam.isEmpty || c.replaying || c.out || c.walking) {
      return const SizedBox();
    }
    // 오른쪽 위 모서리는 폴라로이드 테이프가 덮어서 위 가운데에 둔다.
    return Positioned(
      top: compact ? 4 : 10,
      left: compact ? 6 : 0,
      right: compact ? null : 0,
      child: Center(
        child: Material(
          color: const Color(0xE62F3A3F),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: c.startReplay,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 12, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5484D),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '홈캠 ${c.homeCam.length}장면',
                    style: C3Text.label.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _replayPanel(PetController c) {
    final m = c.replayMoment;
    final i = m == null ? 0 : c.homeCam.indexOf(m) + 1;
    final hh = m?.at.hour.toString().padLeft(2, '0');
    final mm = m?.at.minute.toString().padLeft(2, '0');
    return PlaceCard(
      tape: C3Colors.tapePink,
      icon: 'house',
      title: '홈캠 다시보기 $i/${c.homeCam.length}',
      subtitle: m == null ? '' : '$hh:$mm ${m.label}',
      actions: [
        FilledButton(
          style: compactButton,
          onPressed: c.stopReplay,
          child: const Text('그만 보기'),
        ),
      ],
    );
  }

  Widget _placePanel(PetController c) {
    final home = FilledButton(
      style: compactButton,
      onPressed: _comeHome,
      child: const Text('집으로'),
    );
    return switch (c.spot) {
      Spot.kindergarten when c.inDaycare => PlaceCard(
        tape: C3Colors.tapeYellow,
        icon: 'ball',
        title: '유치원에서',
        subtitle: '저녁 7시 하원',
        actions: [
          FilledButton(
            style: compactButton,
            onPressed: _pickUp,
            child: const Text('데리러 가기'),
          ),
        ],
      ),
      Spot.treatShop => _shopCard(c, home),
      Spot.hospital => PlaceCard(
        tape: C3Colors.tapeMint,
        icon: 'heart',
        title: '병원',
        subtitle: c.lastCheckup != null
            ? '검진 끝!'
            : c.daysToCheckup > 0
            ? '다음 검진은 ${c.daysToCheckup}일 뒤'
            : '오늘 검진 날',
        actions: [
          if (c.lastCheckup == null && c.daysToCheckup == 0)
            OutlinedButton(
              style: compactButton,
              onPressed: _checkup,
              child: const Text('검진'),
            ),
          if (c.lastCheckup case final record?)
            OutlinedButton(
              style: compactButton,
              onPressed: () => _showRecord(record),
              child: const Text('수첩'),
            ),
          home,
        ],
      ),
      Spot.kindergarten => PlaceCard(
        tape: C3Colors.tapeYellow,
        icon: 'ball',
        title: '유치원',
        // 버튼 둘 옆이라 한 줄에 일곱 자쯤 들어간다. 길면 '발표/회'처럼 낱말 한가운데서 줄이 바뀐다.
        subtitle: c.recitalReady
            ? '오늘 발표회 날'
            : c.recitalStampedToday
            ? '도장 받았다!'
            : '친구 ${c.guests.length}마리',
        actions: [
          OutlinedButton(
            style: compactButton,
            onPressed: _dropOff,
            child: const Text('맡기기'),
          ),
          home,
        ],
      ),
      _ => PlaceCard(
        tape: C3Colors.tapePink,
        icon: 'paw_ink',
        title: '카페에서',
        subtitle: c.cafeNote.isEmpty
            ? '다른 강아지 ${c.guests.length}마리와 함께'
            : c.cafeNote,
        actions: [
          OutlinedButton(
            style: compactButton,
            onPressed: () => _playInput(
              c,
              PlayAction.open,
              apply: () => setState(() => _cafeTray = true),
            ),
            child: const Text('개인기'),
          ),
          home,
        ],
      ),
    };
  }
}

/// 발도장을 받으면 방 위 가운데에 "발도장 +N"이 잠깐 떴다 사라진다. 홈캠 칩이 있으면 그 아래.
class _PawToast extends StatefulWidget {
  const _PawToast({required this.controller});

  final PetController controller;

  @override
  State<_PawToast> createState() => _PawToastState();
}

class _PawToastState extends State<_PawToast> {
  late int _seen = widget.controller.pawToastGen;
  int _amount = 0;
  bool _on = false;
  Timer? _off;

  @override
  void didUpdateWidget(_PawToast old) {
    super.didUpdateWidget(old);
    final c = widget.controller;
    if (c.pawToastGen != _seen) {
      _seen = c.pawToastGen;
      _amount = c.pawToast;
      _on = true;
      _off?.cancel();
      _off = Timer(const Duration(milliseconds: 2400), () {
        if (mounted) setState(() => _on = false);
      });
    }
  }

  @override
  void dispose() {
    _off?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final camChip =
        c.homeCam.isNotEmpty && !c.replaying && !c.out && !c.walking;
    return Positioned(
      top: camChip ? 46 : 10,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _on ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: Semantics(
              liveRegion: true,
              label: '발도장 $_amount개 받았어요',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 11, 5),
                decoration: BoxDecoration(
                  color: C3Colors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: C3Colors.stamp, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: C3Colors.shadow,
                      offset: Offset(0, 2),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PixelIcon('paw_ink', scale: 2),
                    const SizedBox(width: 5),
                    Text('발도장 +$_amount', style: C3Text.label),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PetKeyboardTarget extends StatefulWidget {
  const _PetKeyboardTarget({required this.onPet, required this.child});
  final VoidCallback? onPet;
  final Widget child;

  @override
  State<_PetKeyboardTarget> createState() => _PetKeyboardTargetState();
}

class _PetKeyboardTargetState extends State<_PetKeyboardTarget> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    debugLabel: '강아지 쓰다듬기',
    canRequestFocus: widget.onPet != null,
    onFocusChange: (focused) => setState(() => _focused = focused),
    onKeyEvent: (_, event) {
      if (widget.onPet == null ||
          (event.logicalKey != LogicalKeyboardKey.enter &&
              event.logicalKey != LogicalKeyboardKey.space &&
              event.logicalKey != LogicalKeyboardKey.numpadEnter)) {
        return KeyEventResult.ignored;
      }
      if (event is KeyDownEvent) widget.onPet!();
      return KeyEventResult.handled;
    },
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: _focused ? Border.all(color: C3Colors.ink, width: 3) : null,
      ),
      child: widget.child,
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onSettings});

  final PetController controller;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final pet = controller.pet;
    final days = daysTogether(pet.bornAt, controller.now());
    final sub = [
      pet.stage == PetStage.puppy ? '아기' : '성체',
      intimacyLabel(controller.intimacy),
      days == 1 ? '함께한 첫날' : '$days일째 함께',
    ].join(' · ');
    final weather = controller.weather;
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Row(
          children: [
            _portrait(pet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 34,
                    child: Row(
                      children: [
                        // 이름은 8자까지라 날씨 테이프와 함께 들어가도록 넘치면 글자를 줄인다.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              pet.name,
                              maxLines: 1,
                              style: C3Text.title,
                            ),
                          ),
                        ),
                        if (weather != null) ...[
                          const SizedBox(width: 12),
                          _WeatherTape(
                            weather: weather,
                            hour: controller.now().hour,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: C3Colors.ink2),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Semantics(
                  button: true,
                  label: '설정',
                  child: GestureDetector(
                    onTap: onSettings,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: _disc,
                          child: const Center(child: PixelIcon('gear')),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _disc = BoxDecoration(
    shape: BoxShape.circle,
    color: Colors.white,
    boxShadow: [
      BoxShadow(color: C3Colors.shadow, offset: Offset(0, 2), blurRadius: 2.6),
    ],
  );

  Widget _portrait(Pet pet) {
    final path = pet.portraitPath;
    final preview = ColoredBox(
      color: const Color(0xFFF7E5D6),
      child: OverflowBox(
        maxWidth: 64,
        maxHeight: 64,
        child: PetSpritePreview(
          shape: pet.shape,
          colors: PetColors(
            main: pet.furMain,
            second: pet.furSecond,
            marking: pet.marking,
          ),
          stage: pet.stage,
          accent: pet.accent,
          dimension: 64,
          sitting: true,
        ),
      ),
    );
    return Semantics(
      image: true,
      label: '${pet.name}의 모습',
      excludeSemantics: true,
      child: Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(3),
        decoration: _disc,
        child: ClipOval(
          child: path == null || path.isEmpty
              ? preview
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) => preview,
                ),
        ),
      ),
    );
  }
}

class _WeatherTape extends StatelessWidget {
  const _WeatherTape({required this.weather, required this.hour});

  final Weather weather;
  final int hour;

  @override
  Widget build(BuildContext context) {
    final night = hour >= 20 || hour < 6;
    final icon = switch (weather.sky) {
      Sky.rain => 'rain',
      Sky.snow => 'snow',
      Sky.cloudy => 'cloud',
      Sky.clear => night ? 'moon' : 'sun',
    };
    final word = switch (weather.sky) {
      Sky.rain => '비',
      Sky.snow => '눈',
      Sky.cloudy => '흐림',
      Sky.clear => '맑음',
    };
    return Tape(
      height: 28,
      color: C3Colors.tapeSky,
      angle: -3,
      child: Padding(
        padding: const EdgeInsets.only(left: 11, right: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelIcon(icon),
            const SizedBox(width: 5),
            Text(
              '$word ${weather.tempC.round()}°',
              style: const TextStyle(
                fontFamily: C3Fonts.jua,
                fontFamilyFallback: C3Fonts.fallback,
                fontSize: 15,
                color: Color(0xFF3F5A74),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Gauges extends StatelessWidget {
  const _Gauges({required this.stats});

  final PetStats stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: SizedBox(
        height: 75,
        child: Row(
          children: [
            Expanded(
              child: GaugeSticker(
                icon: 'smile',
                label: '기분',
                value: stats.mood.round(),
                colors: GaugeColors.mood,
                tilt: -3,
              ),
            ),
            Expanded(
              child: GaugeSticker(
                icon: 'bone',
                label: '배부름',
                value: (100 - stats.hunger).round(),
                colors: GaugeColors.fullness,
                tilt: 2,
              ),
            ),
            Expanded(
              child: GaugeSticker(
                icon: 'bolt',
                label: '기운',
                value: stats.energy.round(),
                colors: GaugeColors.energy,
                tilt: -2,
              ),
            ),
            Expanded(
              child: GaugeSticker(
                icon: 'heart',
                label: '친밀도',
                value: stats.affection.round(),
                colors: GaugeColors.bond,
                tilt: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
