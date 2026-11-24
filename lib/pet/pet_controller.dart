import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../art/photo_art.dart';
import '../brain/pet_brain.dart';
import '../data/database.dart';
import '../services/gallery_photo.dart' show storePetPortrait;
import '../services/regions.dart';
import '../services/telemetry.dart';
import '../services/weather.dart';
import 'checkup.dart';
import 'cuddle.dart';
import 'cues.dart';
import 'door_news.dart';
import 'friends.dart';
import 'guest.dart';
import 'hidden_treasure.dart';
import 'homecam.dart';
import 'josa.dart';
import 'kinder_photo.dart';
import 'kindergarten.dart';
import 'local_diary.dart';
import 'paws.dart';
import 'pet_rules.dart';
import 'quirks.dart';
import 'recital.dart';
import 'rhythm.dart';
import 'sky.dart';
import 'sleep_spot.dart';
import 'spots.dart';
import 'treasure.dart';
import 'treats.dart';
import 'tricks.dart';
import 'walk_log.dart';
import 'wish.dart';

class _PettingEnded implements Exception {
  const _PettingEnded();
}

/// 행동 타임라인은 게임 루프의 tick(dt)로 흐르고, 상태 변화는 벽시계 기준으로 계산한다.
class PetController extends ChangeNotifier {
  PetController(
    this._db,
    Pet pet, {
    this.systemPrompt = '',
    this.diaryPrompt = '',
    PetBrain? brain,
    this.readStepTotal,
    WeatherService? weatherService,
    Random? random,
    DateTime Function()? clock,
  }) : _pet = pet,
       _rhythm = OwnerRhythm.fromJson(pet.rhythm),
       traits = pet.activity != null && pet.attachment != null
           ? Traits(activity: pet.activity!, attachment: pet.attachment!)
           : Traits.seeded(pet.bornAt.microsecondsSinceEpoch),
       _brain = brain,
       _weatherService = weatherService,
       _random = random ?? Random(),
       _clock = clock ?? DateTime.now,
       careScore = pet.careScore,
       stats = PetStats(
         mood: pet.mood,
         hunger: pet.hunger,
         energy: pet.energy,
         affection: pet.affection,
       );

  final AppDatabase _db;
  final String systemPrompt;
  final String diaryPrompt;
  PetBrain? _brain;

  PetBrain? get brain => _brain;

  bool _disposed = false;
  bool _resetPending = false;
  Future<void>? _resetDrain;
  bool get isDisposed => _disposed;
  bool get isResetting => _resetPending;

  /// 설정에서 AI를 새로 연결하면 직전 실패로 쉬던 것도 푼다.
  set brain(PetBrain? b) {
    if (_disposed) return;
    if (!identical(_brain, b)) _supersedeReaction();
    _brain = b;
    _aiDownUntil = null;
    notifyListeners();
  }

  /// 폰 누적 걸음을 한 번 읽는다. 없으면 주머니 걸음을 쓰지 않는다.
  final Future<int?> Function()? readStepTotal;
  final WeatherService? _weatherService;
  final Random _random;
  final DateTime Function() _clock;
  Pet _pet;
  OwnerRhythm _rhythm;

  /// 타고난 성격. 같은 상황에서도 강아지마다 다르게 움직이게 한다.
  final Traits traits;

  /// 낮잠을 깨운 뒤 이때까지는 다시 졸지 않는다. 쓰다듬자마자 또 자면 만진 보람이 없다.
  DateTime? _awakeUntil;
  DateTime? _firstMetAt;
  static const _firstMeetingLength = Duration(seconds: 90);

  /// 쉬가 마려워 킁킁대는 중. 이 동안 '패드로' 버튼이 보인다.
  bool pottyUrge = false;

  /// 킁킁대다 다른 일(쓰다듬기·놀이·말 걸기)로 끊기면 조금 있다가 다시 마렵다.
  DateTime? _urgeAgainAt;

  /// 던진 공을 '물어와'로 가져오게 했을 때 내려놓은 뒤 할 칭찬. 배운 순간의 종소리가 묻히지 않게.
  PetStep? _fetchPraise;

  /// 바닥에 남은 쉬 자국 자리(0~1). 잠시 뒤 사라진다. 없으면 null.
  double? puddleX;
  DateTime? _puddleAt;

  /// 강아지가 지금 서 있는 바닥 자리(0~1). 게임이 매 프레임 적어 준다.
  double petX = 0.5;

  /// 펫을 걷지 않고 [petX]로 바로 옮길 때 올린다. 자는 사이에 왔으면 펫은 이미 제 자리에서 자고 있다.
  int snapGen = 0;

  /// 이번에 앱을 연 때. 열자마자는 반김·자랑·물건 내밀기가 먼저라 쉬는 조금 뒤에 마렵다.
  DateTime? _wokeAt;

  /// 화면이 발견 카드·설정처럼 방을 가리는 창을 띄운 동안. 그때 마려우면 주인이 못 본 채 실수가 된다.
  /// 창을 열고 닫는 것도 주인이 뭔가 한 것이라 조르기 시계를 다시 잰다.
  bool get uiBusy => _uiBusy;
  set uiBusy(bool v) {
    if (v && !_uiBusy) _roomVisit++;
    _uiBusy = v;
    _noteOwner(changesReaction: false);
    if (!v) _showWalkFinds();
  }

  bool _uiBusy = false;

  /// 일기·도감 탭을 보는 동안(방이 안 보인다). 게임 시간은 계속 가니 조르거나 쉬가 마렵지 않게 한다.
  bool get roomHidden => _roomHidden;
  set roomHidden(bool v) {
    if (v && !_roomHidden) _roomVisit++;
    _roomHidden = v;
    _noteOwner(changesReaction: false);
    if (!v) _showWalkFinds();
  }

  bool _roomHidden = false;
  int? _walkPresentation;

  PetStats stats;
  double careScore;
  PetStep step = const PetStep(Behavior.idle, 3);
  Weather? weather;

  bool walking = false;
  DateTime? walkStartedAt;
  int walkSteps = 0;
  int _walkSession = 0;
  int? _walkDeviceTotal;
  int? _pocketCreditAtWalkStart;
  bool _hasWalkReading = false;
  bool _walkStepGap = false;
  bool get walkSensorUnavailable => _walkStepGap;
  WalkStepCoverage get walkStepCoverage => !_hasWalkReading
      ? WalkStepCoverage.timeOnly
      : _walkStepGap
      ? WalkStepCoverage.partial
      : WalkStepCoverage.measured;
  ({Future<bool> saved, Future<bool> Function() retry})? lastWalkRecord;
  final _failedWalks = <String, Future<bool> Function()>{};
  int get unsavedWalkCount => _failedWalks.length;
  bool retryingWalks = false;

  Future<bool> retryWalkRecords() async {
    if (_disposed || _resetPending || retryingWalks) return false;
    if (_failedWalks.isEmpty) return true;
    retryingWalks = true;
    notifyListeners();
    try {
      for (final write in _failedWalks.values.toList()) {
        await write();
      }
      return _failedWalks.isEmpty;
    } finally {
      retryingWalks = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// 산책 중 킁킁댄 횟수. 산책 지도에 킁킁 자리로 찍힌다.
  int walkSniffs = 0;
  bool _walkRight = true;
  bool walkProposed = false;
  DateTime? _walkProposedAt;

  /// 지금 있는 곳(지도에서 고른 곳). 산책은 [walking]이 따로 맡는다. 앱을 끄면 집이다.
  Spot spot = Spot.home;
  DateTime? spotSince;

  /// 지금 장소에 있는 다른 강아지.
  List<Guest> guests = const [];

  /// 카페 친구 사이(손님 id → 사이). 열 때 읽는다.
  Map<String, Friendship> friends = {};
  Future<void>? _friendsLoad;

  /// 주인이 데려온 아는 강아지(친구·가족네). 카페 손님으로 온다.
  List<Guest> knownDogs = const [];

  /// 카페에 오는 애 전부: 단골과 아는 강아지.
  List<Guest> get cafeFriends => [...cafeRegulars, ...knownDogs];

  bool isKnownDog(String id) => knownDogs.any((g) => g.id == id);

  final _removingKnownDogs = <String, Future<void>>{};

  /// 오늘 카페에서 있었던 일 한 줄("코코 킁킁 · 두부 낯섦"). 카페 카드에 보인다.
  String cafeNote = '';

  /// 처음 서로 킁킁한 날 보여 줄 친구 카드. 만남 장면이 끝날 때(StepTag.meet) 잡히고, 화면이 띄우고 비운다.
  Guest? pendingCard;
  Guest? _cardCandidate;

  /// 장소에 들어가거나 나올 때마다 오른다. 만남 처리가 그 사이 장소가 바뀌었는지 본다.
  int _enterGen = 0;

  /// 이번 나들이에서 졸리다고 한 번 말했는지. 들어갈 때마다 다시 말할 수 있다.
  bool _dozeSaid = false;

  /// 오늘의 소원을 고른 뒤 한가할 때 속마음으로 한 번 말한다(앱을 다시 열 때마다 말하지 않는다).
  bool _wishToSay = false;

  /// 쓰다듬어 달라는 소원에 센 쓰다듬기(연타는 한 번).
  int _wishPets = 0;

  /// 손 베개: 주인이 길게 누른 바닥 자리(0~1). 없으면 null.
  double? handX;

  /// 손가락이 아직 닿아 있는지. 떼도 펫이 손 베개를 마칠 때까지 손은 남는다.
  bool _handHeld = false;

  /// 손 베개를 한 번이라도 해 봤는지. 말 걸기 칸 알림을 끈다.
  bool get triedHand => parseMarks(_pet.pawMarks).contains('hand');
  DateTime? _lastHandBond;

  /// 주인이 마지막으로 뭔가 한 때. 한동안 아무것도 안 하면 가족이 된 펫이 조른다.
  DateTime? _lastOwnerInput;

  /// 이번에 연 동안 조른 적이 있는지, 조른 때(그 뒤 곧 쓰다듬으면 앵긴다).
  bool _begged = false;
  DateTime? _begAt;

  void _noteOwner({bool changesReaction = true}) {
    _lastOwnerInput = _clock();
    if (changesReaction) _supersedeReaction();
  }

  void _supersedeReaction() {
    _reactionVersion++;
    _walkPresentation = null;
    if (bubble == _waitingThought) {
      bubble = null;
      _bubbleLeft = 0;
    }
  }

  bool _ownsReaction(int version) =>
      !_disposed && !_resetPending && version == _reactionVersion;

  /// 손 베개를 받을 수 있는 때. 집에서, 산책·다시보기·공놀이·쉬 신호·물건 내밀기·창 띄움이 없을 때.
  bool get canOfferHand =>
      !out &&
      !walking &&
      !replaying &&
      ball == Ball.none &&
      !pottyUrge &&
      !uiBusy &&
      (presenting == null || presenting!.source == FindSource.window);

  /// 바닥을 길게 눌렀다. 그 자리에 주인 손이 놓이고 펫이 사이에 맞게 다가온다. 깊이 자면 오지 않는다.
  /// 손은 한 번에 하나(두 손가락으로 눌러도 처음 것만).
  void offerHand(double x) {
    if (!canOfferHand || handX != null) return;
    _noteOwner();
    handX = x.clamp(0.0, 1.0).toDouble();
    _handHeld = true;
    Telemetry.track('hand', {'tier': intimacy.name});
    if (_soundAsleep) {
      notifyListeners();
      return;
    }
    final now = _clock();
    _stayAwake(now);
    final sleepy =
        _asleepAt(now) || _rhythm.isDrowsy(now) || stats.energy < tiredEnergy;
    _play(handSteps(intimacy, handX!, sleepy: sleepy));
    notifyListeners();
  }

  /// 손을 뗐다(손가락이 조금 밀려 취소된 것도 같다). 펫이 오는 중이면 마칠 때까지 손을 두고,
  /// 아니면 거둔다. 사람 손가락은 몇 초를 그대로 못 있어서, 떼는 순간 거두면 펫이 닿기 전에 손이 사라졌다.
  void releaseHand() {
    if (handX == null) return;
    _handHeld = false;
    final coming =
        step.tag == StepTag.hand || _plan.any((s) => s.tag == StepTag.hand);
    if (!coming) handX = null;
    notifyListeners();
  }

  /// 펫이 주인 손에 닿았다. 기분이 오르고, 친밀도는 하루 몫 안에서 손 베개마다 [handBondEvery]에 한 번.
  void _handReached(PetStep resting) {
    final now = _clock();
    stats = stats.copyWith(
      mood: stats.mood + (intimacy == Intimacy.stranger ? 1 : 2),
    );
    final last = _lastHandBond;
    if (last == null ||
        now.isBefore(last) ||
        now.difference(last) >= handBondEvery) {
      _lastHandBond = now;
      if (_takeBond(1)) stats = stats.copyWith(affection: stats.affection + 1);
      if (openWish?.kind == WishKind.cuddle) _wishPets++;
    }
    _background(
      _logOnce('cuddle', switch (intimacy) {
        Intimacy.stranger => '주인이 내민 손 냄새를 맡아 봤다',
        Intimacy.friend => '주인 손에 얼굴을 비볐다',
        Intimacy.family =>
          resting.behavior == Behavior.sleep ? '주인 손을 베고 잠들었다' : '주인 손을 베고 누웠다',
      }),
    );
    if (_wishPets >= cuddleWishPets) _fulfill(WishKind.cuddle);
    // 펫이 손에 실제로 닿았을 때 '써 봤다'로 친다(깊이 자서 안 온 건 아직 못 본 것).
    if (!triedHand) {
      final marks = parseMarks(_pet.pawMarks)..add('hand');
      _pet = _pet.copyWith(pawMarks: Value(marksToCsv(marks)));
    }
    _pet = _pet.copyWith(touchX: Value(handX ?? petX));
    _save(now);
  }

  /// 가족이 된 펫이 먼저 다가와 조를 때. 앱을 열 때마다 한 번까지, 주인이 한동안 아무것도 안 했을 때.
  bool _wantsToBeg(DateTime now) {
    final quiet = _lastOwnerInput;
    return intimacy == Intimacy.family &&
        !_begged &&
        quiet != null &&
        now.difference(quiet) >= begAfter &&
        !_rhythm.isDrowsy(now) &&
        _idleInView(now);
  }

  /// 펫이 집에서 한가하고 주인이 방을 보고 있다. 펫이 먼저 하는 일(조르기·보물 확인·꺼내 주기)은 이때만.
  bool _idleInView(DateTime now) =>
      !_asleepAt(now) &&
      stats.energy >= tiredEnergy &&
      !uiBusy &&
      !roomHidden &&
      ball == Ball.none &&
      !pottyUrge &&
      (presenting == null || presenting!.source == FindSource.window) &&
      handX == null;

  /// 오늘 밤 잘 자리(친밀도에 따라).
  double get sleepSpotX => sleepSpot(intimacy, lastTouchX: _pet.touchX);

  /// 방석 밑 보물을 이미 꺼내 줬는지.
  bool get hiddenGiven => parseMarks(_pet.pawMarks).contains('hidden');

  /// 우리 애만의 버릇. 처음 열 때 정해 DB에 남긴다.
  Quirk get quirk =>
      Quirk.values.asNameMap()[_pet.quirk] ?? quirkFor(_pet.id, _pet.bornAt);

  /// 카페 친구한테 옮은 버릇. 없으면 null.
  Quirk? get learnedQuirk {
    final h = _pet.habit;
    return h == null ? null : Quirk.values.asNameMap()[h.split('|').first];
  }

  /// 우리 애 버릇이거나 친구한테 옮은 버릇. 둘 다 하면 둘 다 한다(밥 앞에서 앉고, 다 먹고 그릇 킁킁).
  bool _has(Quirk q) => quirk == q || learnedQuirk == q;

  /// 옮은 버릇은 그 버릇을 가진 친구를 일주일 넘게 아무도 못 보면 슬그머니 사라진다.
  /// 같은 버릇을 가진 다른 친구를 만나도 이어진다(그래서 옮긴 친구가 바뀌지 않는다).
  /// 친구 목록이 이미 있으면 열자마자 정한다. 늦게 정하면 사라지는 그 열기에도 반김 뒤 버릇을 한 번 더 했다.
  void _fadeHabit(DateTime now) {
    final h = _pet.habit, q = learnedQuirk;
    if (h == null || q == null) return;
    DateTime? last;
    for (final MapEntry(key: id, value: f) in friends.entries) {
      final d = DateTime.tryParse(f.lastDay ?? '');
      if (d != null &&
          guestQuirk(id) == q &&
          (last == null || d.isAfter(last))) {
        last = d;
      }
    }
    if (last != null && petDate(now).difference(last).inDays <= habitFadeDays) {
      return;
    }
    _pet = _pet.copyWith(habit: const Value(null));
    final from = h.split('|').last;
    final g = cafeFriends.where((x) => x.id == from).firstOrNull;
    _log(
      'friend_habit_gone',
      habitFadedLine(g == null ? null : friendName(g, friends[from]), q),
    );
    _save(now);
    notifyListeners();
  }

  Future<void> _fadeHabitLater(DateTime now) async {
    final h = _pet.habit;
    await _ensureFriends();
    // 기다리는 사이 다른 열기가 이미 정했으면 두 번 적지 않는다.
    if (_pet.habit == h) _fadeHabit(now);
  }

  /// 버릇을 했다. 처음 한 날은 넘기고(주인이 먼저 알아챌 틈), 다른 날 또 하면 그날 일기에 한 줄 새어 나온다(한 번뿐).
  void _quirkShown() {
    final marks = parseMarks(_pet.pawMarks);
    if (marks.contains('quirk_told')) return;
    final today = 'quirk_day:${dayKey(petDate(_clock()))}';
    final first = marks.where((m) => m.startsWith('quirk_day:')).firstOrNull;
    if (first == null) {
      marks.add(today);
      Telemetry.track('quirk_first', {'kind': quirk.name});
    } else if (first != today) {
      marks
        ..remove(first)
        ..add('quirk_told');
      _log('quirk', quirkLine(quirk));
    } else {
      return;
    }
    _pet = _pet.copyWith(pawMarks: Value(marksToCsv(marks)));
    _save(_clock());
  }

  /// 이번에 연 동안 방석 밑을 몰래 확인하러 갈지(열 때 정한다).
  bool _hideCheckDue = false;

  bool _wantsHideCheck(DateTime now) {
    final woke = _wokeAt;
    return _hideCheckDue &&
        intimacy != Intimacy.family &&
        !hiddenGiven &&
        woke != null &&
        now.difference(woke) >= hideCheckAfter &&
        !_rhythm.isDrowsy(now) &&
        _idleInView(now);
  }

  /// 아침 현관에 물어다 둔 것. 정오가 지나거나 주인이 챙기면 없다.
  DoorItem? get doorItem {
    final now = _clock();
    final news = _pet.doorNews;
    final today = '${dayKey(petDate(now))}:';
    if (news == null || !doorMorning(now) || !news.startsWith(today)) {
      return null;
    }
    return DoorItem.values.asNameMap()[news.substring(today.length)];
  }

  bool get _doorNewsToday =>
      _pet.doorNews?.startsWith('${dayKey(petDate(_clock()))}:') ?? false;

  /// 오늘 현관에 둔 것을 남긴다. 주인이 챙겼으면 '-'. 둘 게 없던 날은 남기지 않아 아침 동안 새 날씨로 다시 본다.
  void _setDoorNews(DoorItem? item) {
    final today = dayKey(petDate(_clock()));
    _pet = _pet.copyWith(doorNews: Value('$today:${item?.name ?? '-'}'));
    _save(_clock());
  }

  /// 아침에 처음 한가할 때 오늘 날씨에 맞는 게 있으면 그걸 고른다.
  /// 오늘 받은 날씨로만(새로 받기가 실패해 어제 날씨가 남아 있을 수 있다).
  /// 정오 1분 전부터는 시작하지 않는다(장면 도중 정오가 되면 입에서 사라진다).
  DoorItem? _doorNewsDue(DateTime now) {
    final w = weather, woke = _wokeAt;
    if (w == null ||
        dayKey(w.fetchedAt) != dayKey(now) ||
        !doorMorning(now.add(const Duration(minutes: 1))) ||
        _doorNewsToday ||
        woke == null ||
        now.difference(woke) < doorAfter ||
        !_idleInView(now)) {
      return null;
    }
    return doorItemFor(w);
  }

  /// 자는 동안 아침이 됐으면 장면 없이 현관에 놓아 둔다(밤사이 물어다 놓은 것처럼).
  void _doorNewsWhileAsleep(DateTime now) {
    final w = weather;
    if (w == null ||
        dayKey(w.fetchedAt) != dayKey(now) ||
        !doorMorning(now) ||
        _doorNewsToday ||
        !_asleepAt(now) ||
        out ||
        walking) {
      return;
    }
    final item = doorItemFor(w);
    if (item == null) return;
    _setDoorNews(item);
    _log('door', doorPlacedLine(item));
    Telemetry.track('door_news', {'item': item.name, 'asleep': true});
    notifyListeners();
  }

  /// 현관에 둔 걸 주인이 챙겼다. 깨어 있으면 잘 다녀오라고 한다. 집 밖·다시보기 중엔 현관이 안 보인다.
  void takeDoorItem() {
    final item = doorItem;
    if (item == null ||
        step.tag == StepTag.door ||
        walking ||
        out ||
        replaying) {
      return;
    }
    final now = _clock();
    _noteOwner();
    _setDoorNews(null);
    Telemetry.track('door_take', {'item': item.name});
    _log('door_take', doorTakenLine(item));
    if (!_asleepAt(now) &&
        step.behavior != Behavior.sleep &&
        ball == Ball.none &&
        !pottyUrge) {
      _play(const [
        PetStep(Behavior.happy, 2, cue: Cue.yip, thought: '잘 다녀와!'),
      ]);
    }
    notifyListeners();
  }

  /// 가족이 됐으면 한가할 때 방석 밑 보물을 꺼내 준다.
  bool _wantsReveal(DateTime now) {
    final woke = _wokeAt;
    return intimacy == Intimacy.family &&
        !hiddenGiven &&
        woke != null &&
        now.difference(woke) >= revealAfter &&
        _idleInView(now);
  }

  /// 방석을 눌렀다. 숨긴 게 있는 동안엔 달려와 깔고 앉는다. 자는 동안엔 모른다.
  void tapRug() {
    if (hiddenGiven || intimacy == Intimacy.family) return;
    if (!canOfferHand || handX != null || step.behavior == Behavior.sleep) {
      return;
    }
    if (step.thought == guardLine || _plan.any((s) => s.thought == guardLine)) {
      return;
    }
    _noteOwner();
    Telemetry.track('rug_tap', {});
    _play(guardSteps);
    _background(_logOncePerDay('hide', '주인이 방석을 건드려서 얼른 가서 깔고 앉았다'));
  }

  /// 방석 밑에 숨겨 둔 걸 꺼내 문다. 한 번뿐이고, 받으면 도감에 선물로 들어간다.
  Future<void> _unearth() async {
    if (hiddenGiven) return;
    final now = _clock();
    final marks = parseMarks(_pet.pawMarks)..add('hidden');
    _pet = _pet.copyWith(pawMarks: Value(marksToCsv(marks)));
    final item = _pick(FindSource.hidden, now, weather?.sky == Sky.rain);
    Telemetry.track('hidden_reveal', {'item': item.id});
    // 한 번뿐인 보물이라 '꺼냈다'와 물건을 함께 저장한다(사이에 앱이 꺼져도 하나만 남지 않게).
    final pet = _pet;
    await _db.transaction(() async {
      await _db.addCarried(item.id, FindSource.hidden, now, gift: true);
      await _db.savePetState(pet);
    });
    carried = await _db.allCarried();
    notifyListeners();
  }

  /// 그 단계가 되고 처음 제 자리에서 잔 날 한 번 일기에 남긴다.
  void _sleptAtSpot() {
    final line = firstSpotLine(intimacy, lastTouchX: _pet.touchX);
    if (line == null) return;
    final marks = parseMarks(_pet.pawMarks);
    if (!marks.add('spot_${intimacy.name}')) return;
    _pet = _pet.copyWith(pawMarks: Value(marksToCsv(marks)));
    _log('spot', line);
    _save(_clock());
  }

  /// 발도장을 받으면 오른다. 화면이 "+N" 표시를 잠깐 띄운다.
  int pawToastGen = 0;
  int pawToast = 0;
  DateTime? _pawToastAt;

  int get paws => _pet.paws;

  /// 바꾼 꾸미기(처음 것 포함).
  Set<String> get ownedCosmetics => {
    ...freeCosmetics,
    ...parseMarks(_pet.owned),
  };

  Cosmetic get collar => collarFor(_pet.accent);

  Cosmetic get rug =>
      cosmeticById(_pet.rug ?? '') ??
      cosmetics.firstWhere((c) => c.kind == CosmeticKind.rug);

  /// 발도장을 번다. 하루 몫(이정표는 밖)을 넘기지 않는다. 돈으로는 살 수 없다.
  void _earn(int amount, String reason, {bool milestone = false}) {
    if (amount <= 0) return;
    final now = _clock();
    final today = dayKey(petDate(now));
    final earned = _pet.pawsDay == today ? _pet.pawsToday : 0;
    final give = milestone ? amount : cappedPaws(amount, earnedToday: earned);
    if (give <= 0) return;
    _pet = _pet.copyWith(
      paws: _pet.paws + give,
      pawsToday: earned + (milestone ? 0 : give),
      pawsDay: Value(today),
    );
    // 표시가 떠 있는 동안 또 받으면 더해서 보여 준다(소원+발표회, 7일+30일 이정표가 한꺼번에 들어온다).
    final showing =
        _pawToastAt != null &&
        !now.isBefore(_pawToastAt!) &&
        now.difference(_pawToastAt!) < const Duration(milliseconds: 2400);
    pawToast = showing ? pawToast + give : give;
    _pawToastAt = now;
    pawToastGen++;
    Telemetry.track('paws', {'reason': reason, 'amount': give});
    _save(now);
    notifyListeners();
  }

  /// 한 번뿐인 이정표 발도장.
  void _milestone(String mark, int amount) {
    final marks = parseMarks(_pet.pawMarks);
    if (!marks.add(mark)) return;
    _pet = _pet.copyWith(pawMarks: Value(marksToCsv(marks)));
    _earn(amount, mark.split(':').first, milestone: true);
  }

  /// 개인기를 처음 배운 순간이면 이정표.
  void _learnedMark(Trick t, TrickProgress before, TrickProgress after) {
    if (!before.learned && after.learned) {
      _milestone('trick:${t.name}', trickMilestonePaws);
    }
  }

  /// 함께한 날 수 이정표(7·30·100일). 그날 일기에도 남는다.
  /// 오래 비웠다 와서 여럿을 한꺼번에 넘기면 발도장은 다 주고 일기엔 가장 큰 것 하나만 쓴다
  /// (같은 종류는 폰 일기가 하나만 골라 30일 줄이 7일 줄에 밀렸다).
  void _togetherMarks(DateTime now) {
    final days = now.difference(_pet.bornAt).inDays + 1;
    int? biggest;
    for (final MapEntry(key: d, value: amount) in togetherMilestones.entries) {
      if (days < d || parseMarks(_pet.pawMarks).contains('days:$d')) continue;
      _milestone('days:$d', amount);
      biggest = max(biggest ?? d, d);
    }
    if (biggest != null) _log('together', '주인이랑 함께한 지 $biggest일이 됐다');
  }

  /// 발도장으로 꾸미기를 바꾸고 바로 쓴다. 이미 있으면 쓰기만. 모자라면 false.
  bool buyCosmetic(String id) {
    final c = cosmeticById(id);
    if (c == null) return false;
    if (!ownedCosmetics.contains(id)) {
      if (_pet.paws < c.price) return false;
      final owned = parseMarks(_pet.owned)..add(id);
      _pet = _pet.copyWith(
        paws: _pet.paws - c.price,
        owned: Value(marksToCsv(owned)),
      );
      Telemetry.track('cosmetic_buy', {'id': id, 'price': c.price});
    }
    wearCosmetic(id);
    return true;
  }

  /// 가진 꾸미기를 쓴다. 목걸이는 그림을 다시 칠한다.
  void wearCosmetic(String id) {
    final c = cosmeticById(id);
    if (c == null || !ownedCosmetics.contains(id)) return;
    switch (c.kind) {
      case CosmeticKind.collar:
        _pet = _pet.copyWith(accent: c.colors.first);
        spriteVersion++;
      case CosmeticKind.rug:
        _pet = _pet.copyWith(rug: Value(id));
    }
    Telemetry.track('cosmetic_wear', {'id': id});
    _save(_clock());
    notifyListeners();
  }

  /// 오늘(펫의 하루)의 소원. 아직 안 골랐거나 날이 바뀌었으면 null.
  Wish? get wish =>
      _pet.wishDay == dayKey(petDate(_clock())) ? Wish.decode(_pet.wish) : null;

  /// 아직 안 들어준 오늘의 소원. 생각 풍선과 지도 표시가 쓴다.
  Wish? get openWish => _pet.wishDone ? null : wish;

  /// 소원 친구(손님). 카페 단골이나 아는 강아지.
  Guest? get wishFriend {
    final id = wish?.target;
    if (id == null) return null;
    return cafeFriends.where((g) => g.id == id).firstOrNull;
  }

  String? get _wishFriendName => switch (wishFriend) {
    final g? => friendName(g, friends[g.id]),
    null => null,
  };

  /// 날이 바뀌었으면 오늘의 소원을 고른다. 개인기·친구를 다 읽은 뒤에만(그래야 다시 열어도 같다).
  void _rollWish(DateTime now) {
    final today = dayKey(petDate(now));
    if (_pet.wishDay == today || !_tricksReady || !_friendsReady) return;
    final yesterday = dayKey(petDayStart(petDate(now), offsetDays: -1));
    final w = pickWish(
      avoid: _pet.wishDay == yesterday ? Wish.decode(_pet.wish)?.kind : null,
      now: now,
      petId: _pet.id,
      stats: stats,
      tricks: tricks,
      friends: friends,
      known: knownDogs,
      pouch: pouch.length,
    );
    _pet = _pet.copyWith(
      wish: Value(w.encode()),
      wishDay: Value(today),
      wishDone: false,
    );
    _wishPets = 0;
    _wishToSay = true;
    Telemetry.track('wish', {'kind': w.kind.name, 'done': false});
    _save(now);
    notifyListeners();
  }

  /// 오늘의 소원을 들어줬다. 하던 장면은 끊지 않고 끝난 뒤에 기뻐한다.
  void _fulfill(WishKind kind, {String? target}) {
    final w = openWish;
    if (w == null || w.kind != kind) return;
    if ((kind == WishKind.friend || kind == WishKind.trick) &&
        w.target != target) {
      return;
    }
    final now = _clock();
    _pet = _pet.copyWith(wishDone: true);
    _wishToSay = false;
    final bond = _takeBond(1);
    stats = stats.copyWith(
      mood: stats.mood + 4,
      affection: stats.affection + (bond ? 1 : 0),
    );
    _log('wish', wishDoneLine(w, friend: _wishFriendName));
    _earn(wishPaws, 'wish');
    _plan.addAll(const [
      PetStep(Behavior.happy, 1.6, cue: Cue.chime, thought: '이거! 이거 하고 싶었어!'),
      PetStep(Behavior.jump, 1.3),
    ]);
    Telemetry.track('wish', {'kind': kind.name, 'done': true});
    _save(now);
    notifyListeners();
  }

  /// 밤(펫의 잘 시간)인지. 꿈 풍선은 밤잠에만 뜬다.
  bool get nightNow => _asleepAt(_clock());

  /// 지금 단계가 제 할 일(스스로 고른 서기·앉기·걷기·눕기)인지. 반김·개인기·위로 같은 반응이면 false.
  bool everyday = false;

  /// 카페에서 개인기를 해내 친구들이 따라 할 차례. 번호가 바뀌면 게임이 따라 하게 한다.
  int mimicGen = 0;
  Trick? mimicTrick;

  /// 유치원 발표회가 시작되면(친구들이 앉아서 본다)과 도장을 받으면(친구들이 기뻐한다) 오른다.
  int recitalGen = 0;
  int cheerGen = 0;

  /// 발표회에서 보여 줄 개인기와 해냈는지. 도장 받는 단계에서 연습으로 치고 비운다.
  List<(Trick, bool)>? _recitalActs;

  /// 발표회 도장을 받은 날들(dayKey).
  List<String> get recitalStamps => parseStamps(_pet.recitalDays);

  /// 오늘 발표회를 하는 중인지. 도장 단계가 남아 있으면 하는 중이다(끊기면 저절로 false).
  bool get recitalOn =>
      step.tag == StepTag.stamp || _plan.any((s) => s.tag == StepTag.stamp);

  bool get recitalStampedToday =>
      recitalStamps.contains(dayKey(petDate(_clock())));

  /// 금요일에 유치원을 구경 중이고(맡긴 게 아니다), 배운 개인기가 있고, 오늘 도장을 아직 안 받았다.
  /// 발표회는 길어야 30초쯤이다. 문 닫기·낮잠 1분 전부터는 띄우지 않는다(하다가 끊기면 도장이 없다).
  bool get recitalReady {
    final now = _clock();
    final soon = now.add(const Duration(minutes: 1));
    return spot == Spot.kindergarten &&
        !inDaycare &&
        kinderOpen(soon) &&
        !kinderNap(now) &&
        !kinderNap(soon) &&
        recitalDay(now) &&
        !recitalStampedToday &&
        !recitalOn &&
        recitalSet(tricks).isNotEmpty;
  }

  /// 창밖을 지나가는 친구와 어디까지 지나갔는지(0~1). 어제 만난 애가 낮에 가끔 지나간다.
  Guest? windowPasser;
  double? windowPassProgress;

  bool get atCafe => spot == Spot.cafe;

  /// 집 밖 어딘가(카페 등)에 있다. 집 안 규칙(반김·쉬·공·물건 내밀기)은 이때 멈춘다.
  bool get out => spot != Spot.home;

  /// 유치원에 맡겨 둔 동안(하원 전). 주인은 곁에 없고 화면은 유치원 CCTV다.
  bool get inDaycare => _pet.daycareFrom != null;

  /// 간식 가게 진열장(그날 넷)과 펫이 고른 칸. 진열장을 다 돌고 고른 칸 앞에 앉아야 [pickShown]이 된다.
  List<Treat> lineup = const [];
  int? shopPickIndex;
  bool pickShown = false;
  Treat? get shopPick => shopPickIndex == null ? null : lineup[shopPickIndex!];
  List<String> get pouch => pouchFrom(_pet.treatPouch);
  bool get boughtToday => _pet.treatDay == dayKey(petDate(_clock()));

  /// 비운 사이 홈캠 장면(두 시간 넘게 비웠을 때). 다시보기 중엔 [replayMoment]가 지금 보이는 장면이다.
  List<CamMoment> homeCam = const [];
  bool replaying = false;
  CamMoment? replayMoment;
  final List<CamMoment> _replayQueue = [];

  /// 오늘 검진 결과. 체중계 화면과 건강 수첩이 읽는다. 앱을 다시 켜면 비지만 다음 검진은 그대로 일주일 뒤다.
  CheckupRecord? lastCheckup;
  int get daysToCheckup => daysUntilCheckup(_pet.checkupAt, _clock());
  bool get _checkedToday =>
      _pet.checkupAt != null &&
      dayKey(petDate(_pet.checkupAt!)) == dayKey(petDate(_clock()));

  /// 도감(물건별 개수), 방 칸(칸 id → 물건 id), 물고 와서 아직 안 건넨 물건.
  Map<String, Find> finds = {};
  Map<String, String> placed = {};
  List<CarriedItem> carried = [];
  bool _treasureLoaded = false;
  bool _collecting = false;
  bool _receiving = false;

  /// 성체가 되면 올라간다. 게임이 이 값을 보고 스프라이트를 다시 읽는다.
  int spriteVersion = 0;
  int diaryVersion = 0;

  final List<PetStep> _plan = [];
  double _remaining = 0;
  double _sinceDecay = 0;
  DateTime? _lastPetted;
  bool _firstDayRecognized = false;
  String? _recognitionCheckedOn;
  int _roomVisit = 0;
  (DateTime, String)? _unwrittenRecognition;
  bool get hasUnsavedRecognition => _unwrittenRecognition != null;
  bool _restoringRecognition = false;
  DateTime? _lastPetLogged;
  String? _weatherLoggedDay;
  String? _diaryCheckedDay;
  String? _diaryWritingDay;
  Future<void>? _diaryWriting;
  bool diarySaveFailed = false;
  bool get writingDueDiaries => _diaryWriting != null;
  DateTime? _lastBond;
  DateTime? _aiDownUntil;
  final _loggedOnce = <String>{};

  /// 개인기 연습 기록. 앱을 처음 열 때 DB에서 읽는다.
  Map<Trick, TrickProgress> tricks = {};
  Future<void>? _tricksLoad;
  bool _tricksReady = false;

  /// 하원 때 잡힌 유치원 수업. 어제 일기를 쓰기 전에 기다린다.
  Future<void>? _lesson;

  /// 하원할 때 못 본 발표회를 남기는 중. 어제 일기는 이것까지 기다린다.
  Future<void>? _recital;

  /// 앱을 열 때 계산한 발표회 시각(3시)의 상태. 못 본 발표회를 해냈는지 정할 때 쓴다.
  PetStats? _recitalStats;

  /// 유치원 수업을 한 날(하루 한 번). 데리러 갈 때 그날 두 번째 하원이면 보여 주지 않는다.
  /// 앱을 다시 켜면 열 때 그날 기록에서 다시 읽는다.
  String? _lessonDay;
  final Map<Trick, int> _misses = {};

  /// 공놀이 상태. 공이 어디 있는지는 게임이 물리로 계산한다.
  Ball ball = Ball.none;
  bool _fetching = false;
  int _ballWait = 0;

  late final _cues = StreamController<Cue>.broadcast(onListen: _flushCues);
  final _pendingCues = <(Cue, DateTime)>[];

  /// 소리·진동 신호. 화면이 듣고 소리를 낸다.
  Stream<Cue> get cues => _cues.stream;

  String? bubble;

  /// AI가 만든 속마음일 때만 말풍선에 AI 표시를 붙인다(AI 기본법 고지). 폰 안 문구에는 붙이지 않는다.
  bool bubbleFromAi = false;
  double _bubbleLeft = 0;
  String? lastError;
  static const _waitingThought = '…';
  int _reactionVersion = 0;

  static const dailyTalkLimit = 20;

  /// AI 호출이 실패하면 이만큼은 다시 부르지 않고 폰 안 반응만 한다. 매번 기다리게 하지 않으려고.
  static const aiRetryAfter = Duration(minutes: 10);

  /// 쓰다듬기로 친밀도가 오르는 간격. 연타로 몇 분 만에 '가족'이 되지 않게.
  static const bondEvery = Duration(minutes: 30);

  Pet get pet => _pet;

  Intimacy get intimacy => intimacyOf(stats.affection);

  WeatherMood get weatherMood {
    final w = weather;
    if (w == null) return WeatherMood.none;
    if (w.sky == Sky.rain || w.sky == Sky.snow) return WeatherMood.watchWindow;
    if (w.hot) return WeatherMood.lazy;
    return WeatherMood.none;
  }

  DateTime now() => _clock();

  /// 앱을 열 때 부른다. 어떻게 반겼는지 돌려준다(가상 테스터가 센다).
  Greeting wake({bool firstMeeting = false}) {
    if (_disposed || _resetPending) return Greeting.none;
    _supersedeReaction();
    final now = _clock();
    _retryRecognition();
    final fresh = _wokeAt == null;
    final meeting = firstMeeting && fresh;
    _wokeAt = now;
    if (meeting) {
      _firstMetAt = now;
      _awakeUntil = now.add(_firstMeetingLength);
      petX = doorX;
      snapGen++;
    }
    // 처음이거나 남은 이름을 모르면(버릇이 없어졌으면) 지금 버릇을 남긴다. 안 남기면 버릇 종류가 늘 때 또 바뀐다.
    if (Quirk.values.asNameMap()[_pet.quirk] == null) {
      _pet = _pet.copyWith(quirk: Value(quirk.name));
    }
    if (_friendsReady) {
      _fadeHabit(now);
    } else {
      _background(_fadeHabitLater(now));
    }
    _lastOwnerInput = now;
    _begged = false;
    _begAt = null;
    handX = null;
    _handHeld = false;
    _hideCheckDue = hideCheckOn(now);
    final away = now.difference(_pet.lastSeenAt);
    // 이번에 연 것까지 세기 전에 물어야 "늘 오는 때"인지 알 수 있다.
    final usual = _rhythm.usualAt(now);
    _rhythm = _rhythm.observeOpen(now, _pet.lastSeenAt);
    final dropped = _pet.daycareFrom;
    _recitalStats = parseRecitalStats(_pet.daycareRecitalStats);
    // 못 본 발표회를 다음 날 아침에 처리하면 밤새 배고파진 지금 상태가 아니라 3시 상태로 해낸다.
    if (dropped != null &&
        _recitalStats == null &&
        daycareRecitalHeld(dropped, now) &&
        _pet.lastSeenAt.isBefore(daycareRecitalAt(dropped))) {
      _recitalStats = elapsedWithDaycare(
        stats,
        _pet.lastSeenAt,
        daycareRecitalAt(dropped),
        dropped: dropped,
        asleepAt: _rhythm.isDogNight,
        sleepGain: _rhythm.sleepGain,
      );
      _pet = _pet.copyWith(
        daycareRecitalStats: Value(recitalStatsTo(_recitalStats!)),
      );
    }
    stats = elapsedWithDaycare(
      stats,
      _pet.lastSeenAt,
      now,
      dropped: dropped,
      asleepAt: _rhythm.isDogNight,
      sleepGain: _rhythm.sleepGain,
    );
    // 유치원에 맡겨 둔 사이에 열었으면 유치원 CCTV를 보여 준다. 하원 시각이 지났으면 버스로 집에 와 있고,
    // 반김은 집에 혼자 있던 시간만큼만 한다(유치원에선 기다리지 않았다).
    var lonely = away;
    var afterBus = false;
    if (dropped != null) {
      if (inDaycareAt(dropped, now)) {
        // 맡기기 전 집에 있던 몫만 혼자 있던 시간이다(보통 0).
        lonely = dropped.isAfter(_pet.lastSeenAt)
            ? dropped.difference(_pet.lastSeenAt)
            : Duration.zero;
        if (spot != Spot.kindergarten) {
          guests = friendsOn(now);
          spot = Spot.kindergarten;
          spotSince = now;
        }
      } else {
        afterBus = !now.isBefore(dropped);
        final home = now.isBefore(dropped) ? now : pickupAt(dropped);
        _endDaycare(home, byOwner: false);
        lonely = now.difference(home);
      }
    }
    if (shouldGrow(_pet.stage, _pet.bornAt, careScore, now)) {
      _pet = _pet.copyWith(stage: PetStage.adult);
      Telemetry.track('grow', {'care': careScore.round()});
      spriteVersion++;
      _log('grow', '오늘 다 컸다. 몸이 커졌다');
      _say('나 이제 다 컸다!', 8);
    }
    // 산책·카페 중에 화면을 다시 켠 거면 같이 있던 거라 집에 온 반김을 하지 않는다.
    final back = walking || out
        ? (steps: const <PetStep>[], stats: stats, greeting: Greeting.none)
        : onReturn(
            stats,
            lonely,
            now,
            threshold: greetAfterFor(intimacy),
            firstMeeting: meeting,
            asleep: _asleepAt(now),
            drowsy: _rhythm.isDrowsy(now),
            usual: usual,
            traits: traits,
            random: _random,
          );
    stats = back.stats;
    // 하루에 처음 보러 오면 친밀도가 조금 오른다. 보기만 하는 사람도 아주 천천히 가까워지게.
    // 반김을 정한 뒤에 준다. 먼저 주면 단계가 바뀌는 날 반김 기준 시간까지 바뀐다.
    if (_rollDay(now) && _takeBond(1)) {
      stats = stats.copyWith(affection: stats.affection + 1);
    }
    // 한참 비웠다 오면 공은 치워져 있다. 놀이 칸이 밥·산책 버튼을 계속 가리지 않게.
    if (away > const Duration(minutes: 1)) _clearBall();
    puddleX = null;
    pottyUrge = false;
    // 다시보기 중에 껐다 켰으면 다시보기는 끝난다. 첫 동작을 고르기 전에 걷어야
    // 다시보기 마무리(가운데로 장면 전환)가 끼어들지 않는다.
    replaying = false;
    replayMoment = null;
    _replayQueue.clear();
    _plan
      ..clear()
      ..addAll(back.steps);
    if (_has(Quirk.sniffOwnerAfterGreet) &&
        back.greeting != Greeting.none &&
        back.greeting != Greeting.sleepy) {
      _plan.add(const PetStep(Behavior.sniff, 1.6, cue: Cue.sniff));
      if (quirk == Quirk.sniffOwnerAfterGreet) _quirkShown();
    }
    // 자는 사이에 왔으면 펫은 벌써 제 자리에 가서 자고 있다(걸어가는 건 못 봤다).
    // 앱이 새로 떴으면 펫이 어디 있었는지 모르니 밤엔 제 자리에서 시작한다.
    if (!walking &&
        !out &&
        _asleepAt(now) &&
        (fresh || away >= const Duration(minutes: 10))) {
      petX = sleepSpotX;
      snapGen++;
      // 이미 자고 있다. 잠드는 걸 못 봤으니 자기 전 돌기 버릇도 없다.
      step = const PetStep(Behavior.sleep, 30);
      _sleptAtSpot();
    }
    _next();
    _save(now);
    Telemetry.track('wake', {
      'away_min': away.inMinutes,
      'greet': back.greeting != Greeting.none,
      'greeting': back.greeting.name,
      'usual': (usual * 100).round(),
      'rhythm_learned': _rhythm.learned,
      'stage': _pet.stage.name,
      'intimacy': intimacy.name,
      ..._statsMap(),
    });
    switch (back.greeting) {
      case Greeting.sleepy when back.steps.first.behavior == Behavior.sleep:
        _log('greet', '자고 있는데 주인이 왔다. 모르고 계속 잤다');
      case Greeting.sleepy:
        _log('greet', '자고 있는데 주인이 와서 졸린 눈으로 잠깐 일어나 반겼다');
      case Greeting.big || Greeting.huge:
        final gap = lonely.inHours < 24
            ? '${lonely.inHours}시간'
            : '${lonely.inDays}일';
        _log('greet', '주인이 $gap 만에 돌아와서 꼬리를 흔들며 반겼다');
        final said = [for (final s in back.steps) ?s.thought];
        _background(
          _greetThought(lonely, said: said.isEmpty ? null : said.first),
        );
      case Greeting.usual:
        _background(_logOnce('greet', '주인이 늘 오는 때에 와서 기다렸다가 반겼다'));
      case Greeting.hello || Greeting.none:
    }
    final weatherDone = _tracked(_refreshWeather(now));
    final diaryDone = _tracked(_diaryForYesterday(now));
    // 오래 비운 날의 선물·좋아하는 물건 옮기기는 집에 혼자 있던 시간으로 정한다.
    collected = _tracked(
      _collect(
        now,
        lonely,
        atKindergarten: dropped != null,
        afterBus: afterBus,
      ),
    );
    _opening = [weatherDone, diaryDone];
    return back.greeting;
  }

  /// 테스트가 앱을 연 뒤 챙기기가 끝나길 기다릴 때 쓴다.
  Future<void> collected = Future.value();
  List<Future<void>> _opening = const [];
  final Set<Future<void>> _inFlight = {};

  /// AI를 기다리는 일(말 걸기·반김 생각). 끝나면 빠진다.
  Future<T> _tracked<T>(Future<T> f) {
    final done = f.then((_) {}, onError: (_) {});
    _inFlight.add(done);
    done.whenComplete(() => _inFlight.remove(done));
    return f;
  }

  void _background(Future<void> operation) {
    // 완료 추적은 오류를 소비하므로, 별도 Future로 기존 비동기 오류 보고를 유지한다.
    unawaited(_tracked(operation).then<void>((_) {}));
  }

  /// 기록을 초기화하거나 다른 펫 DB로 전환하기 전에 새 입력을 막고 이미 시작한 저장을 끝낸다.
  Future<void> prepareReset() {
    if (_resetDrain != null) return _resetDrain!;
    sleepApp();
    _resetPending = true;
    return _resetDrain = _drainForReset();
  }

  Future<void> _drainForReset() async {
    await Future.wait(
      [
        ..._opening,
        collected,
        ?_lesson,
        ?_recital,
        ?_friendsLoad,
        ?_tricksLoad,
      ].map((f) => f.then((_) {}, onError: (_) {})),
    );
    // 위 작업의 완료 콜백이 새 저장을 시작할 수 있어 한 번의 스냅샷으로 끝내지 않는다.
    while (_inFlight.isNotEmpty) {
      await Future.wait(_inFlight.toList());
    }
    await _db.customSelect('SELECT 1').get();
  }

  /// 기록 삭제나 DB 전환에 실패하면 아직 살아 있는 같은 펫으로 돌아간다.
  void cancelReset() {
    final showRetry = _resetPending && _retryPhoto != null;
    _resetPending = false;
    _resetDrain = null;
    if (showRetry && !_disposed) notifyListeners();
  }

  /// 열 때 시작한 비동기 일(날씨·어제 일기·수집·하원 수업)이 다 끝날 때. DB를 바꾸기(연습 모드) 전에 기다린다.
  /// AI 일기가 오래 걸려도 10초 넘게 붙잡지 않는다.
  Future<void> get settled => Future.wait([
    ..._opening,
    ..._inFlight,
    collected,
    ?_lesson,
    ?_recital,
  ]).timeout(const Duration(seconds: 10)).then((_) {}, onError: (_) {});

  /// 걸음 권한을 막 받았을 때처럼, 앱을 다시 열지 않고 한 번 더 챙긴다.
  Future<void> collectNow() => _disposed || _resetPending
      ? Future.value()
      : collected = _tracked(_collect(_clock(), Duration.zero));

  /// 올겨울 첫눈을 본 날에는 창문에 코 자국이 남는다.
  bool get noseOnWindow => _pet.snowDay == dayKey(_clock());

  void _maybeFirstSnow(Weather w, DateTime now) {
    if (w.sky != Sky.snow) return;
    final seen = _pet.snowDay;
    if (seen != null && winterOf(DateTime.parse(seen)) == winterOf(now)) {
      return;
    }
    _pet = _pet.copyWith(snowDay: Value(dayKey(now)));
    _save(now);
    _log('snow', '올해 첫눈이 왔다. 창문에 코를 대고 한참 봤다');
    Telemetry.track('first_snow');
    if (walking || out || _asleepAt(now)) return;
    _plan.clear();
    _start(const PetStep(Behavior.watchWindow, 15, targetX: windowX));
    _say('눈이다…!', 5);
  }

  /// 지금 내미는 것. 입에 문 것이 창틀에 떨어진 것보다 먼저다(창틀 물건은 창틀에 둔 채 기다린다).
  /// 창틀 물건이 먼저 와 있으면 그 뒤에 물고 온 게 입에 안 보이고 '창틀 보기'만 떴다.
  CarriedItem? get presenting =>
      carried.where((c) => c.source != FindSource.window).firstOrNull ??
      carried.firstOrNull;

  int placedCount(String itemId) =>
      placed.values.where((v) => v == itemId).length;

  /// 앱을 열 때마다 주머니 걸음, 창틀, 선물을 챙기고 물고 온 게 있으면 내민다.
  /// [atKindergarten]: 이번에 비운 사이 펫이 유치원에 있었다(주머니 걸음으로 "나도 동네를 돌다 주웠다"가 거짓이 된다).
  /// [afterBus]: 혼자 있던 시간이 하원 버스로 시작했다(주인이 나간 장면이 없다).
  Future<void> _collect(
    DateTime now,
    Duration away, {
    bool atKindergarten = false,
    bool afterBus = false,
  }) async {
    // 잠깐 나갔다 바로 돌아오면 wake가 겹쳐 불린다. 같은 걸음을 두 번 세지 않게 막는다.
    if (_collecting) return;
    _collecting = true;
    try {
      _ensureTaste();
      if (!_treasureLoaded) {
        placed = await _db.loadPlacements();
        finds = {for (final f in await _db.allFinds()) f.itemId: f};
        _treasureLoaded = true;
      }
      // 홈캠은 방에 둔 물건(가지고 논 장면)을 알아야 해서 물건을 읽은 뒤에 만든다.
      _makeHomeCam(now, away, afterBus: afterBus);
      if ((await _db.eventsOn(
        now,
      )).any((e) => e.kind == 'trick' && e.detail.startsWith('유치원'))) {
        _lessonDay = dayKey(petDate(now));
      }
      await _ensureTricks();
      await _ensureFriends();
      _rollWish(_clock());
      _togetherMarks(_clock());
      await _maybeShowOff(now);
      final raining = weather?.sky == Sky.rain;
      final found = <(Item, FindSource)>[];
      // 산책 중 걸음은 산책 보상으로 따로 준다. 여기서 세면 같은 걸음을 두 번 준다.
      final walkSession = _walkSession;
      final total = walking ? null : await readStepTotal?.call();
      if (total != null && !walking && walkSession == _walkSession) {
        // 첫 산책이 기기 기준을 남겼어도 주머니 수집 감사 선물은 한 번 준다.
        final first = _pet.lastStepTotal == null || _pet.pocketWelcomePending;
        final steps =
            stepsSince(_pet.lastStepTotal, total) + _pet.pocketStepCredit;
        final today = dayKey(now);
        final already = _pet.pocketDay == today ? _pet.pocketCount : 0;
        final n = atKindergarten ? 0 : pocketFinds(steps, already);
        for (var i = 0; i < n; i++) {
          found.add((
            _pick(FindSource.pocket, now, raining),
            FindSource.pocket,
          ));
        }
        // 처음 읽는 날은 기준만 잡혀 주울 게 없으니, 걸음을 허락해 준 답으로 하나 준다.
        if (first) {
          found.add((_pick(FindSource.gift, now, raining), FindSource.gift));
        }
        _pet = _pet.copyWith(
          lastStepTotal: Value(total),
          pocketStepCredit: remainingPocketSteps(steps, n),
          pocketWelcomePending: false,
          pocketDay: Value(today),
          pocketCount: already + n,
        );
        Telemetry.track('pocket', {'steps': steps, 'finds': n, 'first': first});
      }
      final night = windowNight(now);
      if (night != null && _pet.windowNight != night) {
        found.add((_pick(FindSource.window, now, raining), FindSource.window));
        _pet = _pet.copyWith(windowNight: Value(night));
      }
      if (away >= const Duration(hours: 12) && _pet.giftDay != dayKey(now)) {
        found.add((_pick(FindSource.gift, now, raining), FindSource.gift));
        _pet = _pet.copyWith(giftDay: Value(dayKey(now)));
      }
      if (_pet.comfortDue) {
        if (_calm(now) && _pet.comfortDay != dayKey(now)) {
          found.add((
            _pick(FindSource.comfort, now, raining),
            FindSource.comfort,
          ));
          _pet = _pet.copyWith(comfortDay: Value(dayKey(now)));
          // 지친 말을 했다는 사실이 드러나지 않게 사용 기록에는 보내지 않고 일기 재료로만 남긴다.
          await _db.addEvent('comfort', '주인이 지쳐 보여서 좋아하는 걸 하나 챙겨 왔다', now);
        }
        _pet = _pet.copyWith(comfortDue: false);
      }
      if (away >= const Duration(hours: 3)) await _maybeMoveFavorite();
      for (final (item, source) in found) {
        await _db.addCarried(
          item.id,
          source,
          now,
          gift: source == FindSource.gift || source == FindSource.comfort,
        );
      }
      carried = await _db.allCarried();
      _save(_clock());
      if (found.isNotEmpty) {
        Telemetry.track('find', {
          'sources': [for (final f in found) _sourceForLog(f.$2)],
        });
      }
      _present();
      notifyListeners();
    } finally {
      _collecting = false;
    }
  }

  /// 어제 연습한 개인기를 오늘 처음 볼 때 시키지 않아도 한 번 해 보인다. 자고 나면 는다는 걸 보여 준다.
  Future<void> _maybeShowOff(DateTime now) async {
    if (walking || out || ball != Ball.none || _asleepAt(now)) return;
    if (stats.energy < tiredEnergy) return;
    final yesterday = dayKey(petDayStart(petDate(now), offsetDays: -1));
    final t = showOffTrick(tricks, yesterday);
    if (t == null) return;
    if ((await _db.eventsOn(now)).any((e) => e.kind == 'show_off')) return;
    final queued = _plan.isNotEmpty;
    _plan.addAll([
      ...trickSteps(t, thought: '봐! 연습했어!'),
      const PetStep(Behavior.happy, 1.5, cue: Cue.bark),
    ]);
    if (!queued) _next();
    _log('show_off', '어제 연습한 ${_quoted(t.label, '을/를')} 주인에게 자랑했다');
  }

  /// 위기 안내 뒤 하루는 위로 선물로 이어지지 않는다.
  bool _calm(DateTime now) {
    final at = _pet.lastCrisisAt;
    return at == null || now.difference(at) > const Duration(hours: 24);
  }

  /// 위로 선물은 사용 기록에서 보통 선물과 구분하지 않는다.
  static String _sourceForLog(FindSource s) =>
      s == FindSource.comfort ? FindSource.gift.name : s.name;

  Item _pick(FindSource source, DateTime now, bool raining) => pickItem(
    _random,
    source: source,
    now: now,
    raining: raining,
    like: _pet.likeTaste,
  );

  void _ensureTaste() {
    if (_pet.likeTaste != null) return;
    final (like, dislike) = tasteFor(_pet.id * 7919 + _pet.bornAt.day);
    _pet = _pet.copyWith(likeTaste: Value(like), dislikeTaste: Value(dislike));
  }

  Future<void> _maybeMoveFavorite() async {
    final moved = moveFavorite(_random, placed, _pet.likeTaste);
    if (moved == null) return;
    placed = moved;
    await _db.savePlacements(placed);
    final item = itemById(moved['floor2']!);
    if (item != null) {
      _log('favorite', '좋아하는 ${josa(item.name, '을/를')} 방석 옆으로 옮겨 놨다');
    }
    Telemetry.track('favorite_moved');
  }

  /// 물고 온 물건은 문 앞에서 들고 들어와 가운데 앉아 내민다. 창틀 물건은 창틀에 둔 채 기다린다.
  void _present() {
    final c = presenting;
    if (c == null || walking || out || c.source == FindSource.window) {
      return;
    }
    if (ball != Ball.none) return;
    // 밤에는 문까지 나오지 않고 물건을 옆에 둔 채 잔다.
    if (step.behavior == Behavior.sleep || _asleepAt(_clock())) return;
    // 반김 중이면 이미 문 앞 → 가운데로 오는 흐름이라 그 뒤에 앉기만 붙인다.
    final greeting = _plan.isNotEmpty;
    if (!greeting) {
      _plan.addAll(const [
        PetStep(Behavior.waitAtDoor, 2, targetX: doorX),
        PetStep(Behavior.run, 4, targetX: 0.5),
      ]);
    }
    _plan.add(const PetStep(Behavior.sit, 40));
    if (!greeting) _next();
  }

  /// 손을 내밀면 물고 있던 걸 떨어뜨린다. 도감에 넣고 취향대로 반응한다.
  Future<ReceiveResult?> receive() =>
      _disposed || _resetPending ? Future.value() : _tracked(_receive());

  Future<ReceiveResult?> _receive() async {
    if (carried.isEmpty || _receiving) return null;
    _noteOwner();
    _stayAwake(_clock());
    _receiving = true;
    try {
      final c = presenting!;
      carried.remove(c);
      final item = itemById(c.itemId) ?? items.first;
      final before = finds[item.id]?.count ?? 0;
      await _db.removeCarried(c.id);
      await _db.addFind(item.id, gift: c.gift);
      finds = {for (final f in await _db.allFinds()) f.itemId: f};
      final r = reactionTo(item, _pet.likeTaste, _pet.dislikeTaste);
      stats = stats.copyWith(
        mood: stats.mood + (r == Reaction.love ? 6 : 2),
        affection: stats.affection + 1,
      );
      careScore += careReceive;
      final name = josa(item.name, '을/를');
      final comfort = c.source == FindSource.comfort;
      _log('find', switch (c.source) {
        FindSource.gift => '주인에게 $name 선물했다',
        FindSource.comfort => '주인 곁에 $name 가만히 두고 옆에 붙어 있었다',
        FindSource.walk => '같이 산책하다가 $name 주워 와서 주인에게 줬다',
        FindSource.window => '창틀에 떨어져 있던 $name 주인이 가져갔다',
        FindSource.pocket => '주인이 밖에서 걷는 동안 나도 동네를 돌다가 $name 주워 와서 줬다',
        FindSource.friend => '카페 단짝이 두고 간 $name 주인에게 보여 줬다',
        FindSource.hidden => '방석 밑에 숨겨 뒀던 $name 꺼내서 주인에게 줬다',
      });
      Telemetry.track('receive', {
        'item': item.id,
        'source': _sourceForLog(c.source),
        'new': before == 0,
        'reaction': r.name,
      });
      if (comfort && !_soundAsleep) {
        // 위로 선물은 말풍선 없이 옆에 붙어 있기만 한다.
        _plan.clear();
        _start(const PetStep(Behavior.lieBeside, 12));
      } else if (!_soundAsleep) {
        _perform(switch (r) {
          Reaction.love => const [PetStep(Behavior.happy, 3, cue: Cue.pop)],
          Reaction.meh => const [PetStep(Behavior.sulk, 2.5)],
          Reaction.plain => const [PetStep(Behavior.happy, 2, cue: Cue.pop)],
        }, receiveThought(item, r, _random));
        final next = presenting;
        if (next != null && next.source != FindSource.window) {
          _plan.add(const PetStep(Behavior.sit, 30));
        }
      }
      _save(_clock());
      // 자는 중에 받으면 동작이 안 바뀌어 알림이 안 나가므로 버튼 글자가 그대로 남는다.
      notifyListeners();
      return ReceiveResult(
        item,
        count: before + 1,
        gift: c.gift,
        reaction: r,
        source: c.source,
      );
    } finally {
      _receiving = false;
    }
  }

  /// 모양 틀을 바꾼다. 기억·일기·상태는 그대로 두고 그림만 다시 읽는다.
  void changeShape(String id) {
    if (id == _pet.shape) return;
    _pet = _pet.copyWith(shape: id);
    spriteVersion++;
    Telemetry.track('shape', {'to': id});
    _save(_clock());
    notifyListeners();
  }

  Future<void> _appearanceWrites = Future.value();
  bool _savingPhoto = false;
  PetPhotoLook? _retryPhoto;
  bool get savingPhoto => _savingPhoto;
  PetPhotoLook? get retryPhoto =>
      _resetPending || _disposed ? null : _retryPhoto;

  /// 화면이 닫혀도 확정한 얼굴은 이 펫에 저장한다. 실패 시에는 작은 결과만 보관한다.
  Future<bool> saveConfirmedPhoto(PetPhotoLook look) {
    if (_disposed || _resetPending || _savingPhoto) return Future.value(false);
    _savingPhoto = true;
    final pending = _tracked(_storeConfirmedPhoto(look));
    notifyListeners();
    return pending;
  }

  Future<bool> _storeConfirmedPhoto(PetPhotoLook look) async {
    bool current() => !_disposed && !_resetPending;
    var saved = false;
    try {
      saved = await storePetPortrait(
        look.portrait,
        current: current,
        commit: (path) => changeColors(look.colors, portraitPath: path),
      );
      return saved;
    } finally {
      _savingPhoto = false;
      _retryPhoto = !saved && !_disposed ? look : null;
      if (current()) notifyListeners();
    }
  }

  /// 파일과 DB가 연결된 뒤에만 외모를 바꾼다. 직전 초상화 경로로 사용을 마친 파일을 찾는다.
  Future<({String? previousPortrait})?> changeColors(
    PetColors colors, {
    String? portraitPath,
  }) {
    if (_disposed || _resetPending) return Future.value(null);
    final operation = _appearanceWrites.then<({String? previousPortrait})?>((
      _,
    ) async {
      final previousPortrait = _pet.portraitPath;
      try {
        final written = await _db.saveAppearance(
          _pet.id,
          colors.main,
          colors.second,
          colors.marking,
          portraitPath,
        );
        if (!written) return null;
      } catch (_) {
        return null;
      }
      _pet = _pet.copyWith(
        furMain: colors.main,
        furSecond: colors.second,
        marking: colors.marking,
        portraitPath: portraitPath == null
            ? const Value.absent()
            : Value(portraitPath),
      );
      spriteVersion++;
      Telemetry.track('recolor', {'portrait': portraitPath != null});
      if (!_disposed && !_resetPending) notifyListeners();
      return (previousPortrait: previousPortrait);
    });
    _appearanceWrites = operation.then((_) {});
    return _tracked(operation);
  }

  Future<void> place(String slotId, String? itemId) =>
      _disposed || _resetPending
      ? Future.value()
      : _tracked(_place(slotId, itemId));

  Future<void> _place(String slotId, String? itemId) async {
    final slot = slotById(slotId);
    if (slot == null) return;
    final item = itemId == null ? null : itemById(itemId);
    if (item == null) {
      placed.remove(slotId);
    } else {
      placed[slotId] = item.id;
      _log('place', '주인이 ${josa(item.name, '을/를')} ${slot.label}에 놓아 줬다');
    }
    await _db.savePlacements(placed);
    Telemetry.track('place', {'slot': slotId, 'item': item?.id});
    notifyListeners();
  }

  /// 설정에서 동네를 찾을 때. 앱 안 목록에서 먼저, 없으면 인터넷 지역 검색.
  Future<List<Place>> searchRegion(String query) =>
      _weatherService?.search(query) ?? Future.value(searchKorea(query));

  /// 설정에서 동네를 바꾼다. 날씨는 새 동네로 다시 받는다.
  Future<void> setRegion(Place place) =>
      _disposed || _resetPending ? Future.value() : _tracked(_setRegion(place));

  Future<void> _setRegion(Place place) async {
    final now = _clock();
    _pet = _pet.copyWith(
      regionName: Value(place.name),
      latitude: Value(place.lat),
      longitude: Value(place.lon),
    );
    weather = null;
    _save(now);
    Telemetry.track('region_set');
    notifyListeners();
    await _refreshWeather(now);
  }

  Future<void> _refreshWeather(DateTime now) async {
    final service = _weatherService;
    final lat = _pet.latitude, lon = _pet.longitude;
    if (service == null || lat == null || lon == null) return;
    final w = weather;
    if (w != null && now.difference(w.fetchedAt) < const Duration(hours: 1)) {
      _doorNewsWhileAsleep(now);
      return;
    }
    final fresh = await service.current(lat, lon, now);
    if (fresh == null) return;
    weather = fresh;
    _doorNewsWhileAsleep(now);
    Telemetry.track('weather', {
      'sky': fresh.sky.name,
      'mood': weatherMood.name,
    });
    if (_weatherLoggedDay != dayKey(now)) {
      _weatherLoggedDay = dayKey(now);
      _log('weather', '오늘 날씨는 ${fresh.label}');
    }
    _maybeFirstSnow(fresh, now);
    notifyListeners();
  }

  /// 앱을 열거나 펼쳐 둔 일기장이 새벽 5시를 지날 때 같은 작업을 공유한다.
  Future<void> refreshDueDiaries() => _disposed || _resetPending
      ? Future.value()
      : _tracked(_diaryForYesterday(_clock()));

  Future<void> _diaryForYesterday(DateTime now) {
    final day = dayKey(petDate(now));
    if (_disposed || _resetPending || _diaryCheckedDay == day) {
      return Future.value();
    }
    final pending = _diaryWriting;
    if (pending != null) {
      return _diaryWritingDay == day
          ? pending
          : pending.then((_) => _diaryForYesterday(_clock()));
    }
    _diaryWritingDay = day;
    final writing = _fillMissingDiaries(now)
        .then(
          (_) {
            _diaryCheckedDay = day;
            diarySaveFailed = false;
          },
          onError: (Object _) {
            // 저장하지 못한 날짜는 다음 앱 재개나 일기장의 다시 쓰기에서 같은 재료로 복구한다.
            diarySaveFailed = true;
            Telemetry.track('diary_storage_error');
          },
        )
        .whenComplete(() {
          _diaryWriting = null;
          _diaryWritingDay = null;
          if (!_disposed) notifyListeners();
        });
    _diaryWriting = writing;
    scheduleMicrotask(() {
      if (!_disposed && identical(_diaryWriting, writing)) notifyListeners();
    });
    return writing;
  }

  Future<void> _fillMissingDiaries(DateTime now) async {
    // 같이 열린 하원 처리의 수업·발표회 기록이 먼저 남아야 그날 일기에 들어간다.
    await _lesson;
    await _recital;
    // 며칠 만에 열면 그 사이 일이 있었던 날(일주일까지)은 폰이 쓴다. 버스 하원·못 본 발표회·유치원 사진처럼
    // 다음에 열 때 그날 시각으로 남는 일이 있어서, 어제만 쓰면 그날 일기와 사진이 영영 안 보였다.
    // AI는 어제 일기에만 쓴다(한 번에 여러 번 부르지 않게).
    final today = petDate(now);
    for (var back = 7; back >= 1; back--) {
      final day = petDayStart(today, offsetDays: -back);
      if (await _db.hasDiary(dayKey(petDate(day)))) continue;
      await _writeDiary(day, save: true, local: back > 1, automatic: true);
    }
  }

  /// 그날 있었던 일로 펫 시점 일기를 쓴다. AI가 없거나 안 되면 폰이 쓴다. 그날 일이 없으면 null.
  /// 미리 보기는 저장하지 않는다. 저장하면 다음 날 그날 일기를 다시 쓰지 않아 저녁 일이 빠진다.
  Future<({String text, bool byAi})?> writeDiary(
    DateTime day, {
    bool save = true,
    bool local = false,
  }) => _disposed || _resetPending
      ? Future.value()
      : _tracked(_writeDiary(day, save: save, local: local));

  Future<({String text, bool byAi})?> _writeDiary(
    DateTime day, {
    required bool save,
    required bool local,
    bool automatic = false,
  }) async {
    final events = await _db.eventsOn(day);
    if (events.isEmpty) {
      if (!automatic) lastError = '그날은 있었던 일이 없어요';
      return null;
    }
    final date = petDate(day);
    String? text;
    final b = brain;
    if (b != null && !_offline && !local && (save || _canTalk())) {
      if (!save) {
        // 동시에 열린 요청도 마지막 한 번을 함께 쓰지 않도록 await 전에 예약한다.
        _pet = _pet.copyWith(talksToday: _pet.talksToday + 1);
        await _db.savePetState(_pet);
      }
      final lines = events
          .map((e) => '- ${_hhmm(e.at)} ${e.detail}')
          .join('\n');
      try {
        text = await b.writeText(
          diaryPrompt,
          '날짜: ${dayKey(date)} (${_weekday(date)})\n오늘 있었던 일:\n$lines\n\n일기:',
        );
      } on BrainError catch (e) {
        if (!automatic) lastError = e.message;
        Telemetry.track('diary_error', {'error': e.kind.code});
      }
    }
    final byAi = text != null;
    text ??= localDiary([
      for (final e in events) (at: e.at, kind: e.kind, detail: e.detail),
    ], _random);
    if (text == null) {
      if (!automatic) lastError = '일기에 쓸 만한 일이 없어요';
      return null;
    }
    Telemetry.track(save ? 'diary' : 'diary_preview', {
      'events': events.length,
      'length': text.length,
      'by': byAi ? 'ai' : 'local',
    });
    if (save) {
      await _db.addDiary(dayKey(date), text, _clock(), byAi: byAi);
      diaryVersion++;
      notifyListeners();
    }
    return (text: text, byAi: byAi);
  }

  /// 반김 동작은 로컬로 정해져 있고, 기억을 반영한 속마음 한 줄만 AI에게 받는다.
  /// [said]는 방금 로컬 반김으로 띄운 속마음. AI가 같은 말을 되풀이하지 않게 알려 준다.
  Future<void> _greetThought(Duration away, {String? said}) async {
    final b = brain;
    if (b == null || _offline || !_canTalk()) return;
    final version = _reactionVersion;
    try {
      final memories = await _tryTalkStorage('read', _memoryLines);
      if (memories == null ||
          !_ownsReaction(version) ||
          !identical(_brain, b) ||
          !_takeTalkSlot()) {
        return;
      }
      final d = await b.decide(
        systemPrompt,
        userTurn(stats, memories, _greetInput(away, said: said)),
      );
      final current = _ownsReaction(version);
      Telemetry.track('greet_thought', {'shown': current});
      if (current) _say(d.thought, 6, ai: true);
    } on BrainError catch (e) {
      if (!_ownsReaction(version)) return;
      lastError = e.message;
      _aiDownUntil = _clock().add(_retryAfter(e.kind));
      Telemetry.track('greet_error', {'error': e.kind.code});
    }
  }

  /// 반김 때 AI에게 주는 상황. 그날 맥락(요일·시각·날씨·오늘 소원)이 없으면 같은 상태·기억에선
  /// 날마다 같은 문장이 나왔다(폰에서 사흘 내내 "드디어 왔다! 너무 보고 싶었어!").
  String _greetInput(Duration away, {String? said}) {
    final now = _clock();
    final sky = switch (weather?.sky) {
      Sky.rain => ', 비',
      Sky.snow => ', 눈',
      Sky.clear => ', 맑음',
      Sky.cloudy => ', 흐림',
      null => '',
    };
    final w = openWish;
    final wished = w == null ? '' : '. 오늘 바라는 것: ${wishTopic(w.kind)}';
    // 로컬 반김 바로 뒤에 같은 뜻의 문장이 이어지면 되풀이로 보였다(폰에서 "드디어 왔다! 보고 싶었어!" →
    // "진짜 보고 싶었어! 드디어 왔다!").
    final already = said == null ? '' : '. 방금 "$said" 하고 반겼으니 다른 말로';
    return '(주인이 ${away.inHours}시간 만에 집에 돌아왔다. '
        '${_weekday(now)}요일 ${now.hour}시$sky$wished$already)';
  }

  Duration _retryAfter(BrainErrorKind kind) => switch (kind) {
    BrainErrorKind.blocked ||
    BrainErrorKind.format ||
    BrainErrorKind.empty => Duration.zero,
    BrainErrorKind.timeout ||
    BrainErrorKind.network ||
    BrainErrorKind.server ||
    BrainErrorKind.http5xx => const Duration(seconds: 30),
    BrainErrorKind.http429 => const Duration(minutes: 1),
    _ => aiRetryAfter,
  };

  bool get _offline => _aiDownUntil?.isAfter(_clock()) ?? false;

  Future<TalkOutcome> talk(String text, {bool voice = false}) =>
      _disposed || _resetPending
      ? Future.value(TalkOutcome.ignored)
      : _tracked(_talk(text, voice: voice));

  Future<TalkOutcome> _talk(String text, {bool voice = false}) async {
    final input = text.trim();
    if (input.isEmpty) return TalkOutcome.ignored;
    _noteOwner();
    // 말을 걸면 칭찬 기회는 지나간다(위기·힘없는 말 직후 '간식을 주면 칭찬' 안내가 뜨지 않게).
    _praisable = null;
    _praisePending = null;
    Telemetry.track('talk', {
      'length': input.length,
      'voice': voice,
      ..._statsMap(),
    });
    if (replaying) stopReplay();
    if (isCrisis(input)) {
      // 위기 문장이었다는 사실은 사용 기록에 남기지 않는다(지친 말을 남기지 않는 것과 같은 까닭).
      // 상담 안내가 주인공이다. 앞서 예약된 위로 선물도 지우고 하루 동안은 새로 잡지 않는다.
      _pet = _pet.copyWith(comfortDue: false, lastCrisisAt: Value(_clock()));
      _save(_clock());
      _clearBall();
      if (!inDaycare) _perform(_stepsFor(PetAction.lieBeside), '곁에 있을게.');
      return TalkOutcome.crisis;
    }
    // 유치원에 맡겨 둔 사이엔 펫이 곁에 없다. AI도 부르지 않는다.
    // 소리는 안 가도 부른 말이 허공에 사라지지 않게, 펫도 문득 주인 생각을 한다.
    if (inDaycare) {
      final asleep = step.behavior == Behavior.sleep;
      Telemetry.track('talk_outcome', {
        'outcome': asleep ? 'away_asleep' : 'away',
      });
      if (asleep) return TalkOutcome.awayAsleep;
      // 속마음이 떠 있는 동안 또 말해도 처음부터 다시 하지 않는다(앉기는 2.5초, 말풍선은 5초).
      if (step.thought != _missThought && bubble != _missThought) {
        _play(const [
          PetStep(Behavior.sit, 2.5, thought: _missThought),
          PetStep(Behavior.happy, 1.2),
        ]);
        // 하원 줄과 종류를 나눈다. 같은 'daycare'면 폰 일기가 먼저 적힌 이 줄만 남기고 하원 줄을 뺐다.
        _background(_logOnce('daycare_miss', '유치원에서 놀다가 문득 주인 생각이 났다'));
      }
      return TalkOutcome.away;
    }
    // 하루 끝 이야기: 저녁(새벽 5시 전까지)에 처음 말을 걸면 펫의 하루에 한 번.
    final talkAt = _clock();
    final talkDay = dayKey(petDate(talkAt));
    if ((talkAt.hour >= eveningFrom || talkAt.hour < dayStartHour) &&
        _pet.eveningDay != talkDay) {
      _pet = _pet.copyWith(eveningDay: Value(talkDay));
      _earn(eveningTalkPaws, 'evening');
    }
    // 이름만 부른 말은 이름 연습이다. 처음엔 반쯤만 돌아보다가 자주 부를수록 매번 달려온다.
    if (parseEveryday(input, _pet.name) == Everyday.called) {
      command(Trick.name, via: voice ? 'voice' : 'text');
      Telemetry.track('talk_outcome', {'outcome': 'command'});
      return TalkOutcome.command;
    }
    // 오늘 소원을 물으면 아침 풍선과 같은 말로 폰이 답한다(AI 한도를 쓰지 않고, 풍선과 말이 어긋나지 않게).
    if (parseEveryday(input, _pet.name) == Everyday.wish) {
      _tellWish();
      Telemetry.track('talk_outcome', {'outcome': 'wish'});
      return TalkOutcome.command;
    }
    // 개인기 명령은 AI 없이 폰에서 바로 한다. 대화 한도도 쓰지 않는다.
    // 잘 익힌 개인기 여럿을 한 말에 시키면 이어서 한다. 하나라도 덜 익혔으면 처음 것만.
    final chain = parseChain(input, _pet.name);
    if (chain.length >= 2) {
      final via = voice ? 'voice' : 'text';
      if (chain.every((t) => chainable(t, tricks[t]))) {
        commandChain(chain, via: via);
      } else {
        command(chain.first, via: via);
      }
      Telemetry.track('talk_outcome', {'outcome': 'command'});
      return TalkOutcome.command;
    }
    if (parseCommand(input, _pet.name) case final cmd?) {
      final via = voice ? 'voice' : 'text';
      if (cmd.trick case final t?) {
        command(t, via: via);
      } else {
        _play(unknownTrickSteps(cmd.word));
        Telemetry.track('trick', {'outcome': 'unknown', 'via': via});
      }
      Telemetry.track('talk_outcome', {'outcome': 'command'});
      return TalkOutcome.command;
    }
    // AI가 있든 없든 잘 자는 강아지가 주인의 잠자리 시각을 배우는 가장 확실한 신호다.
    if (parseEveryday(input, _pet.name) == Everyday.sleep) {
      _rhythm = _rhythm.observeGoodnight(_clock());
    }
    // 그보다 가벼운 지친 말만 다음 선물로 잇는다. 대화 내용이 드러나지 않게 사용 기록에는 남기지 않는다.
    final weak = needsComfort(input) && !askingOrDenying(input);
    if (weak && !_pet.comfortDue && _calm(_clock())) {
      _pet = _pet.copyWith(comfortDue: true);
    }
    // 잘 자라는 말이 섞였으면 자는 반응이 맞다.
    final quiet = weak && parseEveryday(input, _pet.name) != Everyday.sleep;
    final b = brain;
    final offline = _offline;
    if (b == null || offline || !_canTalk()) {
      final outcome = b == null
          ? TalkOutcome.noBrain
          : offline
          ? TalkOutcome.failed
          : TalkOutcome.limited;
      Telemetry.track('talk_outcome', {
        'outcome': offline ? 'offline' : outcome.name,
      });
      return _localTalk(input, quiet: quiet, outcome: outcome, at: _clock());
    }
    final version = _reactionVersion;
    final heardAt = _clock();

    _plan.clear();
    _start(const PetStep(Behavior.sit, 20));
    _say(_waitingThought, 20);
    int? heardEvent;
    try {
      // 다음 날 일기가 먼저 쓰이더라도 주인이 말을 건 사실은 그날 기록에 남긴다.
      heardEvent = await _tryTalkStorage(
        'heard',
        () => _db.addEvent('talk', '주인이 말을 걸었다', heardAt),
      );
      if (heardEvent != null) Telemetry.track('event', {'kind': 'talk'});
      final memories = await _tryTalkStorage('read', _memoryLines);
      if (_disposed || _resetPending || !identical(_brain, b)) {
        return TalkOutcome.ignored;
      }
      // 읽기가 끝난 뒤 실제로 호출할 때만 한 자리를 쓴다. 한도 확인과 횟수 증가는 한 번에 처리한다.
      if (memories == null || !_takeTalkSlot()) {
        if (!_ownsReaction(version)) return TalkOutcome.ignored;
        return await _localTalk(
          input,
          quiet: quiet,
          heardEvent: heardEvent,
          at: heardAt,
          outcome: memories == null
              ? TalkOutcome.historyUnavailable
              : TalkOutcome.limited,
        );
      }
      final d = await b.decide(systemPrompt, userTurn(stats, memories, input));
      if (_disposed || !identical(_brain, b)) return TalkOutcome.ignored;
      // 대화에서 나온 기억은 말한 시각으로 남긴다. 저장 중에도 돌봄이나 새 대화가 시작될 수 있다.
      final memory = d.memory;
      final storedMemory =
          memory != null &&
          await _tryTalkStorage(
                'memory',
                () => _db.addMemory(memory, heardAt, heardEventId: heardEvent),
              ) !=
              null;
      if (!_ownsReaction(version)) return TalkOutcome.ignored;
      // 작은 모델은 숫자 상태를 자주 놓친다. 지친 펫이 뛰어노는 모순은 앱 규칙으로 막는다.
      final tired =
          stats.energy < tiredEnergy &&
          (d.action == PetAction.play || d.action == PetAction.proposeWalk);
      final warmth = d.affectionDelta * 3.0;
      stats = stats.copyWith(
        mood: stats.mood + (tired ? min(0, d.moodDelta) : d.moodDelta) * 3,
        // 오르는 쪽은 쓰다듬기·공놀이와 같은 하루 몫 안에서만. 말을 많이 걸어 며칠 만에 '가족'이 되지 않게.
        affection: stats.affection + (warmth > 0 ? _bondUpTo(warmth) : warmth),
      );
      careScore += careTalk;
      Telemetry.track('talk_outcome', {
        'outcome': 'ai',
        'action': d.action.id,
        'mood_delta': d.moodDelta,
        'affection_delta': d.affectionDelta,
        'saved_memory': storedMemory,
        'thought_length': d.thought.length,
        'overridden_tired': tired,
      });
      final String detail;
      if (quiet) {
        // 기억과 기분은 AI 답대로 남기고, 보이는 반응만 말없이 곁에(졸려도 말은 하지 않는다).
        _quietBeside();
        detail =
            '주인이 "$input"라고 했다. ${walking ? '말없이 같이 걸었다' : '말없이 옆에 붙어 있었다'}';
      } else if (tired) {
        _perform(const [PetStep(Behavior.lieBeside, 8)], '졸려… 조금만 쉴래.');
        detail = '주인이 "$input"라고 했다. 너무 졸려서 옆에 엎드렸다';
      } else {
        if (d.action == PetAction.proposeWalk && !walking && !out) {
          walkProposed = true;
          _walkProposedAt = _clock();
        }
        _perform(_stepsFor(d.action), d.thought, ai: true);
        detail = '주인이 "$input"라고 했다. ${_actionKo(d.action)}';
      }
      final recorded = await _recordTalkDetail(detail, heardEvent, heardAt);
      if (!_ownsReaction(version)) return TalkOutcome.ignored;
      return recorded && (memory == null || storedMemory)
          ? TalkOutcome.ai
          : TalkOutcome.recordIssue;
    } on BrainError catch (e) {
      if (!_ownsReaction(version)) return TalkOutcome.ignored;
      lastError = e.message;
      _aiDownUntil = _clock().add(_retryAfter(e.kind));
      Telemetry.track('talk_outcome', {
        'outcome': 'failed',
        'error': e.kind.code,
      });
      return await _localTalk(
        input,
        quiet: quiet,
        providerBlocked: e.kind == BrainErrorKind.blocked,
        heardEvent: heardEvent,
        at: heardAt,
        outcome: TalkOutcome.failed,
      );
    } finally {
      if (_ownsReaction(version)) _save(_clock());
    }
  }

  /// 듣는 동안 띄운 "…"도 거둔다. 산책 중엔 같이 걷는 게 곁에 있는 것이라 걸음은 그대로 둔다.
  void _quietBeside() {
    bubble = null;
    if (!walking) _play(quietSteps);
    notifyListeners();
  }

  /// AI가 없거나 안 될 때. 아는 말이면 그에 맞게 움직이고, 모르는 말이면 다가와 귀를 기울인다.
  void _tellWish() {
    if (_soundAsleep) {
      _say('…쿨.', 3);
      return;
    }
    _wishToSay = false;
    final w = wish;
    _play([
      if (w == null)
        const PetStep(Behavior.happy, 2, thought: '주인이랑 있으면 다 좋아')
      else if (_pet.wishDone)
        const PetStep(
          Behavior.happy,
          2,
          cue: Cue.yip,
          thought: '오늘 소원은 벌써 이뤘어!',
        )
      else
        PetStep(
          Behavior.sit,
          3.5,
          thought: wishThought(w, friend: _wishFriendName),
        ),
    ]);
  }

  Future<TalkOutcome> _localTalk(
    String input, {
    required bool quiet,
    required TalkOutcome outcome,
    required DateTime at,
    int? heardEvent,
    bool providerBlocked = false,
  }) async {
    final String? detail;
    if (providerBlocked) {
      // 차단 사유로 사용자의 기분이나 말뜻을 추측하지 않는다.
      _quietBeside();
      detail = heardEvent == null ? '주인이 말을 걸었다' : null;
    } else {
      detail = _replyLocally(input, quiet: quiet);
    }
    final version = _reactionVersion;
    final recorded =
        detail == null || await _recordTalkDetail(detail, heardEvent, at);
    if (!_ownsReaction(version)) return TalkOutcome.ignored;
    return recorded ? outcome : TalkOutcome.recordIssue;
  }

  Future<T?> _tryTalkStorage<T>(
    String part,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } catch (_) {
      Telemetry.track('talk_storage_error', {'part': part});
      return null;
    }
  }

  Future<bool> _recordTalkDetail(
    String detail,
    int? heardEvent,
    DateTime at,
  ) async {
    if (heardEvent != null) {
      return await _tryTalkStorage(
            'detail',
            () => _db.describeTalk(heardEvent, detail),
          ) ==
          1;
    }
    final id = await _tryTalkStorage(
      'event',
      () => _db.addEvent('talk', detail, at),
    );
    if (id != null) Telemetry.track('event', {'kind': 'talk'});
    return id != null;
  }

  String? _replyLocally(String input, {bool quiet = false}) {
    if (quiet) {
      _quietBeside();
      return walking ? '주인 목소리가 작았다. 말없이 같이 걸었다' : '주인 목소리가 작았다. 말없이 옆에 붙어 있었다';
    }
    switch (parseEveryday(input, _pet.name)) {
      case Everyday.sleep when step.behavior == Behavior.sleep:
        _say('…쿨.', 3);
      case Everyday.sleep when walking:
        _play(const [PetStep(Behavior.sniff, 2, thought: '산책 끝나고 잘래.')]);
      case Everyday.sleep when out:
        _play(const [PetStep(Behavior.sniff, 2, thought: '집에 가서 잘래.')]);
      case Everyday.sleep:
        _play(const [
          PetStep(Behavior.sit, 1.5, cue: Cue.sigh, thought: '잘 자… 나도 잘래.'),
          PetStep(Behavior.sleep, 30),
        ]);
        return '주인이 잘 자라고 해 줬다';
      case Everyday.love:
        stats = stats.copyWith(mood: stats.mood + 3);
        _play(const [
          PetStep(Behavior.happy, 3, cue: Cue.bark, thought: '꼬리가 멈추질 않아!'),
        ]);
        return '주인이 예뻐해 줬다';
      case Everyday.play when walking || out:
        _play(const [
          PetStep(Behavior.happy, 2, cue: Cue.yip, thought: '집에 가서 놀자!'),
        ]);
      case Everyday.play:
        takeOutBall();
        return '주인이 놀자고 했다';
      case Everyday.walk when walking || out || stats.energy < tiredEnergy:
        _play([
          PetStep(
            Behavior.happy,
            2,
            thought: walking
                ? '산책 좋아!'
                : out
                ? '집에 가서 가자!'
                : '지금은 좀 쉬고 싶어…',
          ),
        ]);
      case Everyday.walk:
        walkProposed = true;
        _walkProposedAt = _clock();
        _play(const [
          PetStep(
            Behavior.run,
            4,
            targetX: doorX,
            cue: Cue.yip,
            thought: '산책? 산책!',
          ),
          PetStep(Behavior.spin, 2.4),
        ]);
        return '주인이 산책 가자고 해서 문 앞으로 달려갔다';
      // 이름만 부른 말과 소원을 묻는 말은 talk()가 먼저 받아서 여기 오지 않는다.
      case Everyday.called:
      case Everyday.wish:
      case null:
        _play(const [
          PetStep(Behavior.run, 4, targetX: 0.5, thought: '…?'),
          PetStep(Behavior.sit, 2.5),
        ]);
        return '주인이 말을 걸어 줬다. 무슨 말인지는 몰라도 귀를 기울였다';
    }
    return null;
  }

  /// 방금 해낸 배우는 중인 개인기. 곧 간식을 주면 칭찬이 되어 한 번 더 해낸 걸로 친다.
  ({Trick trick, DateTime at})? _praisable;

  /// 방금 해낸 개인기. '간식 냄새' 킁킁이 시작되면 그때부터 칭찬 기회가 열린다(해 보이기 전에 안내가 뜨지 않게).
  Trick? _praisePending;

  /// 지금 열린 칭찬 기회. 지났으면 null.
  Trick? get _livePraise {
    final p = _praisable;
    if (p == null || pouch.isEmpty) return null;
    final since = _clock().difference(p.at);
    return !since.isNegative && since <= praiseWithin ? p.trick : null;
  }

  /// 지금 간식을 주면 칭찬이 되는지(말 걸기 칸 안내에 쓴다).
  bool get praiseOpen => _livePraise != null;

  /// 개인기를 시킨다. 목소리·글이나 놀이 칸 칩에서 온다.
  TrickCommandOutcome command(Trick t, {String via = 'chip'}) {
    _noteOwner();
    if ((walking || out) && t == Trick.fetch) {
      _play(const [PetStep(Behavior.happy, 2, thought: '집에 가서 하자!')]);
      return TrickCommandOutcome.away;
    }
    // 칩을 고르는 동안은 공을 치우지 않는다. 밤엔 몇 초 만에 치워 칩이 사라졌다.
    _ballWait = 0;
    _stayAwake(_clock());
    final now = _clock();
    final today = dayKey(petDate(now));
    final before = tricks[t] ?? const TrickProgress();
    // 던진 공을 물고 돌아오는 중이다. '물어와'라고 하면 이미 하고 있는 거라 해낸 걸로 친다.
    final bringing = t == Trick.fetch && ball == Ball.carried && _fetching;
    // 공을 물어 오는 건 내려놓을 때(_dropBall) 공놀이 몫으로 보상한다. 두 번 주지 않는다.
    // _play가 공 상태를 바꾸기 전에 정해야 한다. 바뀐 뒤에 보면 보상이 둘 다 빠졌다.
    final viaBall =
        t == Trick.fetch &&
        (ball == Ball.thrown || ball == Ball.ready || bringing);
    final r = tryTrick(
      t,
      before,
      stats,
      today: today,
      misses: _misses[t] ?? 0,
      random: _random,
      sure: bringing,
      known: [
        for (final MapEntry(key: k, value: p) in tricks.entries)
          if (p.successes > 0) k,
      ],
    );
    // 새로 시킬 때마다 칭찬 기회를 다시 정한다. 남겨 두면 그 뒤 배운 개인기에 옛 기회가 남았다.
    // 배우는 중에 집에서 해냈고 주머니에 간식이 있을 때만(바깥에선 간식을 못 준다).
    final smells =
        r.success &&
        t.chip &&
        t != Trick.fetch &&
        before.successes + 1 < learnAfter &&
        !out &&
        !walking &&
        pouch.isNotEmpty;
    _praisable = null;
    _praisePending = smells ? t : null;
    if (bringing) {
      // 물고 오는 길을 끊지 않는다(끊으면 공을 그 자리에 떨어뜨린다). 내려놓은 뒤의 기쁨만 개인기 칭찬으로.
      if (r.success && _plan.isNotEmpty) _plan[_plan.length - 1] = r.steps.last;
    } else {
      // 자고 있었으면 졸린 채로 일어나서 한다. 밤이라고 거절하지 않는다. 물어 올 땐 바로 뛰어간다.
      // 앞에 다른 동작이 끼면 물고 있던 공을 그 자리에 떨어뜨린다(_start).
      final sleepy =
          r.counted && step.behavior == Behavior.sleep && t != Trick.fetch;
      _play([
        if (sleepy)
          const PetStep(Behavior.sit, 1, cue: Cue.sigh, thought: '으응… 졸린데.'),
        ...t == Trick.fetch && r.success ? _fetchSteps(r.steps.last) : r.steps,
        if (smells)
          const PetStep(
            Behavior.sit,
            2.5,
            cue: Cue.sniff,
            tag: StepTag.praise,
            thought: '킁킁… 간식 냄새',
          ),
      ]);
    }
    if (atCafe && r.success && t.chip) _friendsMimic(t);
    if (r.counted) {
      final after = before.practiced(success: r.success, today: today);
      tricks[t] = after;
      _misses[t] = r.success ? 0 : (_misses[t] ?? 0) + 1;
      _background(_db.saveTrick(t, after));
      _learnedMark(t, before, after);
    }
    if (r.success && !viaBall) {
      final bond = _takeBond(1);
      stats = stats.copyWith(
        mood: stats.mood + 3,
        affection: stats.affection + (bond ? 1 : 0),
      );
      if (bond) careScore += careTrick;
    }
    if (r.success) {
      if (t == Trick.name) {
        if (r.learnedNow) {
          _log('trick', '내 이름이 ${_pet.name}인 걸 알았다');
        } else {
          _background(_logOnce('talk', '주인이 이름을 불러서 달려갔다'));
        }
      } else if (r.learnedNow) {
        _log('trick', '주인이 가르쳐 준 ${_quoted(t.label, '을/를')} 처음으로 해냈다');
      } else {
        _background(
          _logOnce('trick', '주인 앞에서 ${_quoted(t.label, '을/를')} 해 보였다'),
        );
      }
      _fulfill(WishKind.trick, target: t.name);
    }
    Telemetry.track('trick', {
      'trick': t.name,
      'outcome': r.success
          ? 'success'
          : r.counted
          ? 'miss'
          : 'tired',
      'via': via,
      'learned_now': r.learnedNow,
      'stars': (tricks[t] ?? before).stars,
    });
    _save(now);
    // 물고 오는 중에는 동작을 바꾸지 않아도 연습 횟수와 별은 바로 표시해야 한다.
    if (bringing) notifyListeners();
    return switch (r) {
      TrickTry(learnedNow: true) => TrickCommandOutcome.learned,
      TrickTry(success: true) => TrickCommandOutcome.succeeded,
      TrickTry(counted: true) => TrickCommandOutcome.missed,
      _ => TrickCommandOutcome.tired,
    };
  }

  /// 잘 익힌 개인기를 이어서 한다(앉아 엎드려 돌아). 별 셋이라 틀리지 않는다.
  /// 하나하나 연습으로 치고, 칭찬은 끝에 한 번 크게.
  void commandChain(List<Trick> ts, {String via = 'text'}) {
    _noteOwner();
    _ballWait = 0;
    // 자고 있었으면 하나씩 시킬 때처럼 졸린 채로 일어나서 한다.
    final sleepy = step.behavior == Behavior.sleep;
    _stayAwake(_clock());
    final now = _clock();
    if (stats.energy < tiredEnergy) {
      _play(const [
        PetStep(Behavior.lieBeside, 4, cue: Cue.sigh, thought: '졸려… 나중에 할래.'),
      ]);
      Telemetry.track('trick_chain', {
        'count': ts.length,
        'via': via,
        'outcome': 'tired',
      });
      return;
    }
    final today = dayKey(petDate(now));
    for (final t in ts) {
      final after = (tricks[t] ?? const TrickProgress()).practiced(
        success: true,
        today: today,
      );
      tricks[t] = after;
      _misses[t] = 0;
      _background(_db.saveTrick(t, after));
    }
    _play([
      if (sleepy)
        const PetStep(Behavior.sit, 1, cue: Cue.sigh, thought: '으응… 졸린데.'),
      for (final t in ts) ...trickSteps(t),
      const PetStep(Behavior.happy, 2.5, cue: Cue.bark, thought: '다 했다!'),
    ]);
    // 카페에선 친해진 친구들이 마지막 개인기를 따라 한다(하나씩 시킬 때와 같게).
    if (atCafe) _friendsMimic(ts.last);
    final bond = _takeBond(1);
    stats = stats.copyWith(
      mood: stats.mood + 4,
      affection: stats.affection + (bond ? 1 : 0),
    );
    if (bond) careScore += careTrick;
    final names = [for (final t in ts) "'${t.label}'"];
    // 개인기 줄과 종류를 나눈다. 같은 'trick'이면 폰 일기가 그날 먼저 해 보인 줄만 골라 이 줄이 묻혔다.
    _background(
      _logOnce(
        'trick_chain',
        '${names.take(names.length - 1).join('·')}·${_quoted(ts.last.label, '을/를')} 이어서 해 보였다',
      ),
    );
    Telemetry.track('trick_chain', {
      'count': ts.length,
      'via': via,
      'outcome': 'done',
    });
    _save(now);
  }

  /// '물어와'를 해냈다. 던진 공이 있으면 쫓아가 물어 오고, 없으면 상자에서 물고 와 앞에 놓는다.
  /// [praise]는 해낸 뒤 기뻐하는 단계(배운 날이면 종소리).
  List<PetStep> _fetchSteps(PetStep praise) {
    if (ball == Ball.thrown || ball == Ball.ready) {
      _ballWait = 0;
      // 물어 온 뒤의 기쁨은 공을 내려놓는 흐름(arrived)이 맡는다. 칭찬만 넘긴다.
      _fetchPraise = praise;
      return [_chase()];
    }
    if (ball == Ball.carried) {
      return [
        PetStep(Behavior.happy, 2, cue: Cue.yip, thought: '여기 있어!'),
        praise,
      ];
    }
    ball = Ball.carried;
    _ballWait = 0;
    return [
      const PetStep(
        Behavior.run,
        4,
        targetX: 0.5,
        tag: StepTag.carry,
        cue: Cue.yip,
        thought: '물어왔다!',
      ),
      const PetStep(Behavior.sit, 1, tag: StepTag.drop, cue: Cue.drop),
      praise,
    ];
  }

  /// 놀아 주기를 누르거나 놀자고 하면 공을 물고 와서 앞에 내려놓는다.
  void takeOutBall() {
    if (walking || out) return;
    _noteOwner();
    if (ball != Ball.none) {
      _play(const [PetStep(Behavior.happy, 2, cue: Cue.yip, thought: '던져 줘!')]);
      return;
    }
    final tired = stats.energy < tiredEnergy;
    Telemetry.track('ball_out', {'tired': tired});
    if (tired) {
      _play(const [
        PetStep(Behavior.lieBeside, 5, cue: Cue.sigh, thought: '헥헥… 좀 쉬었다 할래.'),
      ]);
      return;
    }
    ball = Ball.carried;
    _ballWait = 0;
    _play(const [
      PetStep(
        Behavior.run,
        4,
        targetX: 0.5,
        tag: StepTag.carry,
        cue: Cue.yip,
        thought: '공이다! 던져 줘!',
      ),
      PetStep(Behavior.sit, 1, tag: StepTag.drop, cue: Cue.drop),
    ]);
  }

  /// 공을 던졌다. 게임이 공을 날리고, 강아지는 멈출 때까지 쫓아가서 물어 온다.
  bool throwBall() {
    if (ball != Ball.ready) return false;
    ball = Ball.thrown;
    _ballWait = 0;
    _noteOwner();
    _cue(Cue.throwBall);
    final tired = stats.energy < tiredEnergy;
    Telemetry.track('throw', {'tired': tired});
    _play([
      tired
          ? const PetStep(
              Behavior.lieBeside,
              6,
              cue: Cue.sigh,
              thought: '헥헥… 좀 쉬었다 할래.',
            )
          : _chase(),
    ]);
    return true;
  }

  PetStep _chase() =>
      PetStep(_sleepy ? Behavior.walk : Behavior.run, 15, tag: StepTag.chase);

  /// 게임이 알린다: 던진 공이 바닥에 멈췄다.
  void ballLanded() {
    if (ball != Ball.thrown) return;
    ball = Ball.ready;
    notifyListeners();
  }

  /// 게임이 알린다: 공이 바닥에 세게 튀었다.
  void bounced() => _cue(Cue.bounce);

  /// 놀이 칸을 닫으면 공을 치운다.
  void putBallAway() {
    if (ball == Ball.none) return;
    _noteOwner();
    _clearBall();
    if (step.tag != StepTag.none || _plan.any((s) => s.tag != StepTag.none)) {
      _plan.clear();
      _next();
    }
    Telemetry.track('ball_away', {'auto': false});
    notifyListeners();
  }

  void _clearBall() {
    ball = Ball.none;
    _fetching = false;
    _fetchPraise = null;
    _ballWait = 0;
  }

  /// 물고 있던 공을 내려놓는다. 던진 공을 주인 앞까지 물어 온 거면 칭찬받는다.
  void _dropBall({required bool home}) {
    ball = Ball.ready;
    final fetched = home && _fetching;
    _fetching = false;
    if (!fetched) return;
    final bond = _takeBond(1);
    stats = afterFetch(stats, bond: bond, traits: traits);
    if (bond) careScore += carePlay;
    _background(_logOnce('play', '주인이 던진 공을 물어 왔다', perCalendarDay: true));
    _fulfill(WishKind.ball);
    Telemetry.track('fetch', {'bond': bond, ..._statsMap()});
    _save(_clock());
  }

  bool startWalk() {
    if (walking) return true;
    if (out) return false;
    if (!canGoOut()) {
      Telemetry.track('walk_refused', _statsMap());
      return false;
    }
    // 마려울 때 산책을 나가면 밖에서 해결한다. 연습으로 치지는 않는다.
    if (pottyUrge) {
      pottyUrge = false;
      _pet = _pet.copyWith(pottyAt: Value(_clock()));
    }
    _noteOwner();
    Telemetry.track('walk_start', {'proposed_by_pet': walkProposed});
    _clearBall();
    walking = true;
    walkProposed = false;
    walkStartedAt = _clock();
    walkSteps = 0;
    _walkSession++;
    _walkDeviceTotal = null;
    _pocketCreditAtWalkStart = null;
    _hasWalkReading = false;
    _walkStepGap = false;
    walkSniffs = 0;
    _walkRight = true;
    _plan.clear();
    _start(const PetStep(Behavior.walk, 6, targetX: 0.85));
    _say('산책이다!', 4);
    return true;
  }

  void updateWalkSteps(int steps, {int? deviceTotal}) {
    if (_disposed || !walking || steps < walkSteps) return;
    if (deviceTotal != null && deviceTotal >= 0) {
      // 첫 유효 계수에서 산책을 시작하기 전 몫을 고정한다. 이후 기기가 다시 0이 되어도 보관한다.
      _pocketCreditAtWalkStart ??=
          _pet.pocketStepCredit +
          max(0, stepsSince(_pet.lastStepTotal, deviceTotal) - steps);
      _walkDeviceTotal = deviceTotal;
    }
    if (_hasWalkReading && steps == walkSteps) return;
    _hasWalkReading = true;
    walkSteps = steps;
    notifyListeners();
  }

  void markWalkSensorUnavailable() {
    if (_disposed || !walking || _walkStepGap) return;
    _walkStepGap = true;
    notifyListeners();
  }

  WalkResult endWalk() {
    final now = _clock();
    // 두 번 눌려도 걸음 보상·발견물·발도장을 두 번 주지 않는다.
    if (!walking) {
      return (
        steps: 0,
        coverage: WalkStepCoverage.timeOnly,
        minutes: 0,
        finds: 0,
        startedAt: now,
        spots: const <WalkSpot>[],
      );
    }
    _noteOwner();
    final started = walkStartedAt ?? now;
    final length = now.isBefore(started)
        ? Duration.zero
        : now.difference(started);
    final spots = walkSpots(
      started,
      walkSniffs,
      rain: weather?.sky == Sky.rain,
      snow: weather?.sky == Sky.snow,
    );
    final n = walkFinds(walkSteps, length);
    final raining = weather?.sky == Sky.rain;
    // 비 오는 날 같이 걸어 준 날은 하루 한 번 선물을 하나 더 가져온다.
    final rainGift = raining && n > 0 && _pet.giftDay != dayKey(now);
    if (rainGift) _pet = _pet.copyWith(giftDay: Value(dayKey(now)));
    final items = [
      for (var i = 0; i < n; i++)
        (_pick(FindSource.walk, now, raining).id, FindSource.walk),
      if (rainGift) (_pick(FindSource.gift, now, raining).id, FindSource.gift),
    ];
    // 산책 걸음은 산책 보상으로 줬으니 다음에 열 때 주머니 걸음으로 다시 세지 않게 기준을 옮긴다.
    final oldBase = _pet.lastStepTotal;
    final nextBase =
        _walkDeviceTotal ?? (oldBase == null ? null : oldBase + walkSteps);
    if (nextBase != null) {
      _pet = _pet.copyWith(
        lastStepTotal: Value(nextBase),
        pocketStepCredit: _pocketCreditAtWalkStart ?? _pet.pocketStepCredit,
        pocketWelcomePending: oldBase == null || _pet.pocketWelcomePending,
      );
    }
    final r = afterWalk(stats, walkSteps, length);
    stats = r.stats;
    careScore += r.care;
    walking = false;
    Telemetry.track('walk_end', {
      'steps': walkSteps,
      'coverage': walkStepCoverage.name,
      'minutes': length.inMinutes,
      'finds': n,
    });
    final result = (
      steps: walkSteps,
      coverage: walkStepCoverage,
      minutes: length.inMinutes,
      finds: n,
      startedAt: started,
      spots: spots,
    );
    _recordWalk(result, now, items);
    _earn(walkPaws(length), 'walk');
    _plan.clear();
    _start(const PetStep(Behavior.happy, 3));
    _say('산책 좋았다!', 6);
    _save(now);
    return result;
  }

  void _showWalkFinds() {
    final pending = _walkPresentation;
    if (pending == null || uiBusy || roomHidden) return;
    _walkPresentation = null;
    if (_ownsReaction(pending)) _present();
  }

  void _recordWalk(
    WalkResult result,
    DateTime at,
    List<(String, FindSource)> items,
  ) {
    // 연습 시계를 되감아 똑같은 산책을 다시 해도 새 산책은 별도 기록이다.
    final random = Random.secure();
    final receipt =
        '${at.microsecondsSinceEpoch}-${random.nextInt(1 << 32)}-${random.nextInt(1 << 32)}';
    final map = encodeWalkMap(result, receipt: receipt);
    final duration = result.minutes == 0 ? '잠깐' : '${result.minutes}분';
    final steps = switch (result.coverage) {
      WalkStepCoverage.timeOnly => '시간으로 기록',
      WalkStepCoverage.partial => '확인한 ${result.steps}걸음',
      WalkStepCoverage.measured => '${result.steps}걸음',
    };
    final detail = '주인이랑 $duration 산책했다 ($steps)';
    final spot = walkSpotLine(result.spots);
    Telemetry.track('event', {'kind': 'walk'});
    final version = _reactionVersion;
    var recorded = false;
    Future<bool>? active;
    late Future<bool> Function() save;
    Future<bool> attempt() async {
      try {
        final addedSpot = await _db.storeFinishedWalk(
          at,
          detail,
          map,
          spot,
          items,
        );
        if (addedSpot) Telemetry.track('event', {'kind': 'walk_spot'});
        if (items.isNotEmpty) {
          final updated = await _db.allCarried();
          if (!_disposed) {
            carried = updated;
            if (_ownsReaction(version)) {
              _walkPresentation = version;
              _showWalkFinds();
            }
          }
        }
        recorded = true;
        _failedWalks.remove(receipt);
        return true;
      } catch (_) {
        if (!_disposed) _failedWalks[receipt] = save;
        return false;
      } finally {
        if (!_disposed) notifyListeners();
      }
    }

    save = () {
      if (recorded) return Future.value(true);
      if (_disposed || _resetPending) return Future.value(false);
      return active ??= _tracked(attempt()).whenComplete(() => active = null);
    };
    lastWalkRecord = (saved: save(), retry: save);
  }

  /// 문을 열었다. 깊이 자거나 지쳤으면 어디에도 안 나간다(속마음으로 알린다).
  bool canGoOut() {
    if (_soundAsleep) {
      _supersedeReaction();
      _say('…쿨.', 3);
      return false;
    }
    if (stats.energy < tiredEnergy) {
      _supersedeReaction();
      _say('지금은 좀 쉬고 싶어…', 4);
      return false;
    }
    _stayAwake(_clock());
    return true;
  }

  /// 지도에서 카페를 골랐다. 24시간 연다.
  bool goToCafe() {
    if (out || walking) return atCafe;
    if (!_mayEnter()) return false;
    _enter(
      Spot.cafe,
      guestsAt(
        _clock(),
        known: [
          for (final g in knownDogs)
            if (!_removingKnownDogs.containsKey(g.id)) g,
        ],
        newcomers: {
          for (final g in knownDogs)
            if (newcomerAt(friends[g.id], _clock())) g.id,
        },
      ),
      '카페다!',
    );
    cafeNote = '';
    _background(_meetGuests());
    return true;
  }

  /// 지도에서 유치원을 골랐다. 문 연 시간인지는 화면이 먼저 본다.
  bool goToKindergarten() {
    if (out || walking) return spot == Spot.kindergarten;
    if (!kinderOpen(_clock()) || !_mayEnter()) return false;
    _enter(Spot.kindergarten, friendsOn(_clock()), '친구들이다!');
    _fulfill(WishKind.kinder);
    return true;
  }

  /// 두 시간 넘게 집에 혼자 있었으면 그사이 장면 서너 개를 만든다. 일기엔 한 장면만 하루 한 번.
  void _makeHomeCam(DateTime now, Duration lonely, {bool afterBus = false}) {
    if (out || walking || lonely < homeCamAfter) return;
    final floor = [
      for (final e in placed.entries)
        if (slotById(e.key) case final s? when s.area == SlotArea.floor)
          if (itemById(e.value) case final item?) (s.walkX, item.name),
    ];
    final sky = weather?.sky;
    homeCam = homeCamMoments(
      from: now.subtract(lonely),
      to: now,
      asleepAt: _rhythm.isDogNight,
      traits: traits,
      seed: _pet.id,
      ownerLeft: !afterBus,
      rainy: sky == Sky.rain || sky == Sky.snow,
      toyName: floor.isEmpty ? null : floor.first.$2,
      toyX: floor.isEmpty ? null : floor.first.$1,
      sleepX: sleepSpotX,
    );
    final best = homeCamHighlight(homeCam);
    if (best == null || dayKey(petDate(best.at)) != dayKey(petDate(now))) {
      return;
    }
    _background(
      _logOncePerDay('homecam', switch (best.kind) {
        CamKind.doorWait => '주인이 올 때쯤 문 앞에 가 있었다',
        CamKind.window => '주인이 없는 동안 창밖을 오래 봤다',
        CamKind.toy => '혼자서 ${josa(best.item!, '을/를')} 가지고 놀았다',
        CamKind.nap =>
          '주인이 없는 동안 ${_asleepAt(best.at) ? sleepPlaceName(intimacy, lastTouchX: _pet.touchX) : '방석'}에서 푹 잤다',
        CamKind.sniff => '주인이 없는 동안 방 구석구석 냄새를 맡았다',
        CamKind.doorOut => '주인이 나간 문 앞을 잠깐 서성였다',
      }),
    );
  }

  /// 홈캠 다시보기. 장면마다 그 자리로 옮겨 그 동작을 몇 초씩 보여 준다.
  void startReplay() {
    if (homeCam.isEmpty || replaying || out || walking) return;
    _noteOwner();
    replaying = true;
    _clearBall();
    _replayQueue
      ..clear()
      ..addAll(homeCam);
    Telemetry.track('homecam', {'moments': homeCam.length});
    _play([
      for (final m in homeCam)
        PetStep(m.behavior, 3.5, targetX: m.x, tag: StepTag.cut),
    ]);
  }

  /// 끝까지 본 홈캠은 칩을 거둔다. 중간에 멈췄으면 다시 볼 수 있게 둔다.
  void _finishReplay() {
    homeCam = const [];
    stopReplay();
  }

  void stopReplay() {
    if (!replaying) return;
    replaying = false;
    replayMoment = null;
    _replayQueue.clear();
    _play(const [PetStep(Behavior.idle, 1, targetX: 0.5, tag: StepTag.cut)]);
    _present();
  }

  /// 지도에서 간식 가게를 골랐다. 펫이 진열장을 돌며 냄새를 맡고 하나를 고른다.
  bool goToTreatShop() {
    if (out || walking) return spot == Spot.treatShop;
    if (!_mayEnter()) return false;
    _ensureTaste();
    lineup = lineupOn(petDate(_clock()));
    final pick = pickIndex(lineup, _pet.likeTaste, _pet.dislikeTaste);
    shopPickIndex = pick;
    pickShown = false;
    _enter(Spot.treatShop, const [], '킁킁, 맛있는 냄새!');
    _plan.addAll(sniffTour(pick));
    return true;
  }

  /// 펫이 고른 간식을 산다. 하루 한 번, 주머니가 차면 못 산다.
  bool buyTreat() {
    _noteOwner();
    final pick = shopPick;
    if (spot != Spot.treatShop || !pickShown || pick == null) return false;
    if (boughtToday || pouch.length >= pouchSize) return false;
    final now = _clock();
    _pet = _pet.copyWith(
      treatPouch: Value(pouchTo([...pouch, pick.id])),
      treatDay: Value(dayKey(petDate(now))),
    );
    Telemetry.track('treat_buy', {'treat': pick.id});
    _log('shop', '간식 가게에서 ${josa(pick.name, '을/를')} 골랐더니 주인이 사 줬다');
    _play(const [
      PetStep(Behavior.happy, 2, cue: Cue.bark, thought: '내 거다!'),
      PetStep(Behavior.sit, 20),
    ]);
    _save(now);
    return true;
  }

  /// 오늘 간식을 산 뒤 발도장으로 하나 더 살 수 있는지.
  bool get canBuyExtraTreat =>
      spot == Spot.treatShop &&
      pickShown &&
      shopPick != null &&
      boughtToday &&
      pouch.length < pouchSize &&
      _pet.paws >= extraTreatPaws;

  /// 발도장으로 펫이 고른 간식을 하나 더 산다. 매일 쓸 곳이 없으면 발도장이 쌓이기만 했다.
  bool buyExtraTreat() {
    if (!canBuyExtraTreat) return false;
    _noteOwner();
    final pick = shopPick!;
    final now = _clock();
    _pet = _pet.copyWith(
      treatPouch: Value(pouchTo([...pouch, pick.id])),
      paws: _pet.paws - extraTreatPaws,
    );
    Telemetry.track('treat_buy', {'treat': pick.id, 'paws': extraTreatPaws});
    _background(
      _logOnce('shop', '간식 가게에서 발도장으로 ${josa(pick.name, '을/를')} 하나 더 샀다'),
    );
    _play(const [
      PetStep(Behavior.happy, 2, cue: Cue.bark, thought: '하나 더!'),
      PetStep(Behavior.sit, 20),
    ]);
    _save(now);
    notifyListeners();
    return true;
  }

  /// 간식을 나눠 받으러 펫 쪽으로 오는 카페 친구. 번호가 바뀌면 게임이 그 애를 데려온다.
  String? shareGuest;
  int shareGen = 0;

  Set<String> get _sharedToday =>
      sharedOn(_pet.treatShares, dayKey(petDate(_clock())));

  /// 카페에 와 있는 이 친구에게 지금 간식을 나눠 줄 수 있는지. 서로 냄새를 맡은 사이부터, 친구마다 하루 한 번.
  /// 밤엔 손님들이 자서 깨우지 않는다.
  bool canShareWith(String guestId) =>
      !_removingKnownDogs.containsKey(guestId) &&
      atCafe &&
      !cafeNight(_clock()) &&
      pouch.isNotEmpty &&
      guests.any((g) => g.id == guestId) &&
      (friends[guestId]?.bond.index ?? 0) >= Bond.sniff.index &&
      !_sharedToday.contains(guestId);

  /// 카페 친구에게 주머니 간식을 나눠 준다. 친구가 와서 먹고, 펫은 옆에서 꼬리를 흔든다.
  /// 사이는 올리지 않는다. 카페에 오면 만남으로 이미 한 칸 올라서, 나눠 주기까지 올리면 하루에 두 칸이 됐다.
  bool shareTreat(String guestId) {
    if (_disposed || _resetPending) return false;
    if (!canShareWith(guestId)) return false;
    _noteOwner();
    final now = _clock();
    final today = dayKey(petDate(now));
    final ids = pouch;
    final t = treatById(ids.first)!;
    final g = guests.firstWhere((g) => g.id == guestId);
    final before = friends[guestId] ?? const Friendship();
    _pet = _pet.copyWith(
      treatPouch: Value(pouchTo(ids.sublist(1))),
      treatShares: Value(sharesTo(today, {..._sharedToday, guestId})),
    );
    shareGuest = guestId;
    shareGen++;
    final loves = t.taste == g.taste;
    stats = stats.copyWith(mood: stats.mood + 3);
    _play([
      const PetStep(Behavior.sit, 3, cue: Cue.yip, thought: '같이 먹자!'),
      PetStep(Behavior.happy, 1.5, thought: loves ? '쟤도 엄청 좋아한다!' : null),
    ]);
    final name = friendName(g, friends[guestId]);
    _log(
      'share',
      loves
          ? '카페에서 $name에게 ${josa(t.name, '을/를')} 나눠 줬더니 엄청 좋아했다'
          : '카페에서 $name에게 ${josa(t.name, '을/를')} 나눠 줬다',
    );
    Telemetry.track('treat_share', {
      'bond': (friends[guestId] ?? before).bond.name,
      'loves': loves,
    });
    _save(now);
    notifyListeners();
    return true;
  }

  /// 먹여 본 간식과 반응(도감의 입맛 칸).
  Map<String, Reaction> get treatsTried => parseTried(_pet.treatsTried);

  /// 주머니에서 간식을 하나 꺼내 준다. 먼저 산 것부터. 싫어하는 갈래면 냄새만 맡고 만다.
  void giveTreat() {
    final ids = pouch;
    // 공을 물고 오는 중엔 입이 차 있다(먹이면 공을 그 자리에 떨어뜨려 공놀이 몫이 빠졌다).
    if (ids.isEmpty || out || walking || ball == Ball.carried) return;
    _noteOwner();
    final now = _clock();
    // 간식 냄새를 맡고 다시 잠든 참이면 칭찬 간식엔 깬다.
    if (_soundAsleep && _livePraise == null) {
      _say('…쿨.', 3);
      return;
    }
    _stayAwake(now);
    final t = treatById(ids.first)!;
    final r = eatTreat(stats, t, _pet.likeTaste, _pet.dislikeTaste);
    // 방금 배우는 중인 개인기를 해냈으면 간식이 칭찬이 된다. 싫어하는 간식은 칭찬이 안 된다.
    final live = _livePraise;
    _praisable = null;
    _praisePending = null;
    final praised = r.reaction != Reaction.meh ? live : null;
    stats = r.stats;
    if (r.reaction != Reaction.meh && _takeBond(1)) {
      stats = stats.copyWith(affection: stats.affection + 1);
    }
    _pet = _pet.copyWith(
      treatPouch: Value(pouchTo(ids.sublist(1))),
      treatsTried: Value(triedToCsv({...treatsTried, t.id: r.reaction})),
    );
    Telemetry.track('treat', {'treat': t.id, 'reaction': r.reaction.name});
    _log('treat', switch (r.reaction) {
      Reaction.love => '주인이 준 ${t.name}, 최고였다',
      Reaction.meh => '주인이 ${josa(t.name, '을/를')} 줬는데 냄새만 맡았다',
      Reaction.plain => '주인이 준 ${josa(t.name, '을/를')} 먹었다',
    });
    if (praised == null) {
      _play(r.steps);
    } else {
      final before = tricks[praised] ?? const TrickProgress();
      final after = before.praised(dayKey(petDate(now)));
      tricks[praised] = after;
      _background(_db.saveTrick(praised, after));
      _learnedMark(praised, before, after);
      final learnedNow = !before.learned && after.learned;
      Telemetry.track('treat_praise', {
        'trick': praised.name,
        'learned_now': learnedNow,
      });
      // 폰 일기는 개인기 줄 중 '처음'이 든 줄을 크게 친다(배운 날 줄이 그날 앞서 해 보인 줄에 묻히지 않게).
      if (learnedNow) {
        _log('trick', '간식 칭찬을 받고 ${_quoted(praised.label, '을/를')} 처음으로 익혔다');
      } else {
        _background(
          _logOnce('trick', '${_quoted(praised.label, '을/를')} 해내고 간식을 받았다'),
        );
      }
      _play([
        ...r.steps,
        learnedNow
            ? const PetStep(
                Behavior.happy,
                2,
                cue: Cue.chime,
                thought: '이제 알겠어!',
              )
            : const PetStep(
                Behavior.happy,
                1.5,
                cue: Cue.yip,
                thought: '또 시켜 줘!',
              ),
      ]);
    }
    if (r.reaction != Reaction.meh) _fulfill(WishKind.treat);
    _save(now);
  }

  /// 지도에서 병원을 골랐다. 낯선 냄새에 머뭇거린다.
  bool goToHospital() {
    if (out || walking) return spot == Spot.hospital;
    if (!_mayEnter()) return false;
    if (!_checkedToday) lastCheckup = null;
    _enter(Spot.hospital, const [], '여긴… 병원 냄새.');
    return true;
  }

  /// 검진. 일주일에 한 번. 체중계에 올라가 몸무게를 재고, 잘 참으면 기분이 조금 오른다.
  CheckupRecord? startCheckup() {
    _noteOwner();
    if (spot != Spot.hospital || daysToCheckup > 0) return null;
    final now = _clock();
    final record = checkupFor(
      shape: _pet.shape,
      stage: _pet.stage,
      bornAt: _pet.bornAt,
      now: now,
      seed: _pet.id,
      checkupsBefore: _pet.checkups,
      previousWeight: _pet.lastWeight,
    );
    lastCheckup = record;
    _pet = _pet.copyWith(
      checkupAt: Value(now),
      checkups: _pet.checkups + 1,
      lastWeight: Value(record.weight),
    );
    stats = stats.copyWith(mood: stats.mood + 3);
    if (_takeBond(1)) stats = stats.copyWith(affection: stats.affection + 1);
    _earn(checkupPaws, 'checkup');
    Telemetry.track('checkup', {
      'count': _pet.checkups,
      'stage': _pet.stage.name,
    });
    _log(
      'hospital',
      '병원에서 검진을 받았다. 몸무게는 ${record.weight.toStringAsFixed(1)}kg. 무서웠지만 잘 참았다',
    );
    _play(const [
      PetStep(Behavior.walk, 4, targetX: scaleX),
      PetStep(Behavior.sit, 3.5, tag: StepTag.weigh, cue: Cue.whine),
      PetStep(Behavior.happy, 2.5, cue: Cue.yip, thought: '잘 참았다!'),
      PetStep(Behavior.sit, 20),
    ]);
    _save(now);
    return record;
  }

  /// 물건을 내밀고 있으면 먼저 받으라고 한다.
  bool _mayEnter() {
    if (!canGoOut()) return false;
    if (presenting case final p? when p.source != FindSource.window) {
      _say('이거 먼저 받아 줘!', 4);
      return false;
    }
    return true;
  }

  void _enter(Spot to, List<Guest> others, String thought) {
    final now = _clock();
    _noteOwner();
    _clearBall();
    guests = others;
    spot = to;
    spotSince = now;
    _enterGen++;
    mimicTrick = null;
    _recitalActs = null;
    _dozeSaid = false;
    _plan.clear();
    // 입구(화면 밖 왼쪽)에서 걸어 들어온다. 닿으면 끝나니 넉넉히.
    _start(const PetStep(Behavior.walk, 9, targetX: 0.4));
    _say(thought, 4);
    Telemetry.track('place_enter', {'place': to.name, 'guests': others.length});
  }

  /// 유치원 발표회. 배운 개인기를 잇달아 보여 주고 도장을 받는다. 해냈는지는 지금 정하고,
  /// 연습 기록·도장·일기는 끝까지 했을 때(StepTag.stamp) 남긴다. 중간에 끊기면 아무것도 남지 않는다.
  bool startRecital() {
    if (!recitalReady) return false;
    if (stats.energy < tiredEnergy) {
      _say('지금은 좀 쉬고 싶어…', 4);
      return false;
    }
    _beginRecital();
    return true;
  }

  void _beginRecital() {
    _supersedeReaction();
    if (inDaycare && _recitalStats == null) {
      _recitalStats = stats;
      _pet = _pet.copyWith(daycareRecitalStats: Value(recitalStatsTo(stats)));
      _save(_clock());
    }
    final acts = _recitalActsFor(
      dayKey(petDate(_clock())),
      inDaycare ? (_recitalStats ?? stats) : stats,
    );
    _recitalActs = acts;
    _play(recitalSteps(acts));
    recitalGen++;
    Telemetry.track('recital_start', {
      'tricks': acts.length,
      'daycare': inDaycare,
    });
    notifyListeners();
  }

  /// 보여 줄 개인기와 해냈는지. 해냈는지는 시작할 때([s] 상태로) 정한다.
  List<(Trick, bool)> _recitalActsFor(String day, PetStats s) => [
    for (final t in recitalSet(tricks))
      (t, _random.nextDouble() < trickChance(t, tricks[t]!, s, today: day)),
  ];

  void _awardStamp() {
    final acts = _recitalActs;
    _recitalActs = null;
    if (acts == null) return;
    cheerGen++;
    _stamp(acts, at: _clock(), watched: true);
  }

  /// 맡긴 금요일 3시 발표회를 CCTV로 보는 중이다. 10분이 지나면 하원 때 하고 온 것으로 친다.
  bool get _daycareRecitalLive {
    final d = _pet.daycareFrom;
    if (d == null || !_tricksReady || recitalOn) return false;
    final now = _clock();
    return daycareRecitalHeld(d, now) &&
        now.isBefore(daycareRecitalAt(d).add(daycareRecitalWindow)) &&
        !recitalStamps.contains(dayKey(petDate(d))) &&
        recitalSet(tricks).isNotEmpty;
  }

  /// 맡긴 오늘 3시에 발표회가 있다(맡길 때 안내에 쓴다).
  bool get daycareRecitalPlanned {
    final d = _pet.daycareFrom;
    return d != null &&
        recitalDay(d) &&
        d.isBefore(daycareRecitalAt(d)) &&
        !recitalStamps.contains(dayKey(petDate(d))) &&
        recitalSet(tricks).isNotEmpty;
  }

  /// 맡긴 동안 지난 발표회를 못 봤다. 하원할 때 하고 온 것으로 친다(연습·도장·일기는 3시에).
  Future<void> _daycareRecital(DateTime dropped, PetStats s) async {
    await _ensureTricks();
    final day = dayKey(petDate(dropped));
    if (recitalStamps.contains(day) || recitalSet(tricks).isEmpty) return;
    _stamp(
      _recitalActsFor(day, s),
      at: daycareRecitalAt(dropped),
      watched: false,
    );
  }

  void _stamp(
    List<(Trick, bool)> acts, {
    required DateTime at,
    required bool watched,
  }) {
    final now = _clock();
    final day = dayKey(petDate(at));
    for (final (t, ok) in acts) {
      final after = (tricks[t] ?? const TrickProgress()).practiced(
        success: ok,
        today: day,
      );
      tricks[t] = after;
      _background(_db.saveTrick(t, after));
    }
    final stamps = recitalStamps;
    if (!stamps.contains(day)) {
      _pet = _pet.copyWith(recitalDays: Value([...stamps, day].join(',')));
    }
    // 버스로 온 걸 다음 날 아침에 처리하면 소원도 하루 몫도 오늘 것이 아니다.
    final sameDay = day == dayKey(petDate(now));
    if (sameDay) _fulfill(WishKind.recital);
    _earn(recitalPaws, 'recital', milestone: !sameDay);
    final shown = acts.map((a) => "'${a.$1.label}'").join('·');
    final last = acts.last.$1.label;
    _log(
      'recital',
      '유치원 발표회에서 친구들 앞에 $shown${josa(last, '을/를').substring(last.length)} 보여 주고 도장을 받았다',
      at: at,
    );
    Telemetry.track('recital', {
      'tricks': acts.length,
      'misses': acts.where((a) => !a.$2).length,
      'stamps': recitalStamps.length,
      'watched': watched,
    });
    _save(now);
  }

  /// 유치원에 맡긴다. 저녁 7시에 하원한다. 그 전에 앱을 열면 유치원에서 노는 모습이 보인다.
  /// [lesson]이 null이면 자유 놀이(수업 없음).
  bool dropOff({Trick? lesson}) {
    final now = _clock();
    _noteOwner();
    if (spot != Spot.kindergarten || inDaycare || !canDropOff(now)) {
      return false;
    }
    _pet = _pet.copyWith(
      daycareFrom: Value(now),
      daycareLesson: Value(lesson?.name ?? 'free'),
      daycareRecitalStats: const Value(null),
    );
    _recitalStats = null;
    Telemetry.track('daycare_drop', {'hour': now.hour});
    _log('daycare_drop', '주인이 유치원에 맡기고 갔다');
    _play(const [
      PetStep(Behavior.sit, 2, cue: Cue.whine, thought: '금방 와야 해!'),
      PetStep(Behavior.run, 4, targetX: 0.75, cue: Cue.yip),
    ]);
    _save(now);
    return true;
  }

  /// 하원 전에 데리러 왔다. 문 앞부터 달려온다.
  void pickUp() {
    if (!inDaycare) return;
    _noteOwner();
    final now = _clock();
    _applyPending(now);
    final lesson = _endDaycare(now, byOwner: true);
    if (_takeBond(1)) stats = stats.copyWith(affection: stats.affection + 1);
    stats = stats.copyWith(mood: stats.mood + 5);
    _play([
      const PetStep(
        Behavior.run,
        3,
        targetX: 0.5,
        cue: Cue.bark,
        thought: '데리러 왔다!',
      ),
      const PetStep(Behavior.happy, 2, cue: Cue.yip),
      if (lesson != null) ...[
        ...trickSteps(lesson, thought: '오늘 배운 거 봐!'),
        const PetStep(Behavior.happy, 1.5, cue: Cue.bark),
      ],
    ]);
    _save(now);
  }

  /// 하원. 주인이 데리러 왔거나 저녁 7시 버스로 왔다. 쉬는 유치원에서 하고 왔다.
  /// 두 시간 넘게 있었으면 그날 수업한 개인기를 돌려준다(데리러 가면 보여 준다).
  Trick? _endDaycare(DateTime at, {required bool byOwner}) {
    final dropped = _pet.daycareFrom;
    if (dropped == null) return null;
    final stayed = at.difference(dropped);
    final chosen = _pet.daycareLesson;
    _pet = _pet.copyWith(
      daycareFrom: const Value(null),
      daycareLesson: const Value(null),
      daycareRecitalStats: const Value(null),
      pottyAt: Value(at),
    );
    pottyUrge = false;
    spot = Spot.home;
    guests = const [];
    Telemetry.track('daycare_end', {
      'by_owner': byOwner,
      'minutes': stayed.inMinutes,
    });
    _log(
      'daycare',
      byOwner
          ? '유치원에서 친구들이랑 놀다가 주인이 데리러 와서 같이 집에 왔다'
          : '유치원에서 친구들이랑 놀다가 유치원 버스를 타고 집에 왔다',
      at: at,
    );
    final picked = Trick.values.where((t) => t.name == chosen).firstOrNull;
    // 같은 날 또 맡겨 수업이 없던 둘째 번이어도 괜찮다. 오늘의 한 장은 처음 것만 남는다.
    final lesson = stayed >= lessonAfter && picked != null;
    if (planKinderPhoto(dropped, at, lesson: lesson, random: _random)
        case final p?) {
      _background(
        _db.addKinderPhoto(
          KinderPhotosCompanion.insert(
            day: dayKey(petDate(at)),
            scene: p.scene.name,
            friends: p.friends.join(','),
            stage: _pet.stage,
            trick: Value(p.scene == KinderScene.lesson ? picked?.name : null),
          ),
        ),
      );
      Telemetry.track('kinder_photo', {'scene': p.scene.name});
    }
    if (daycareRecitalHeld(dropped, at)) {
      _recital = _daycareRecital(dropped, _recitalStats ?? stats);
    }
    _recitalStats = null;
    if (stayed < lessonAfter || chosen == 'free') return null;
    if (_lessonDay == dayKey(petDate(at))) return null;
    _lesson = _daycareLesson(at, picked);
    // 고른 수업이 없으면(이 기능 전에 맡긴 경우) 개인기 기록을 읽은 뒤에 정한다. 보여 주기는 이미 읽혀 있을 때만.
    return picked ?? (_tricksReady ? lessonTrick(tricks) : null);
  }

  /// 유치원 수업. 하루 한 번 [picked](없으면 못 배운 것 중 가장 가까운 것)를 한 번 해낸다.
  /// 배운 것이면 복습이라 별이 는다.
  Future<void> _daycareLesson(DateTime at, Trick? picked) async {
    await _ensureTricks();
    final today = await _db.eventsOn(at);
    if (today.any((e) => e.kind == 'trick' && e.detail.startsWith('유치원'))) {
      _lessonDay = dayKey(petDate(at));
      return;
    }
    final t = picked ?? lessonTrick(tricks);
    if (t == null) return;
    _lessonDay = dayKey(petDate(at));
    final before = tricks[t] ?? const TrickProgress();
    final after = before.practiced(success: true, today: dayKey(petDate(at)));
    tricks[t] = after;
    await _db.saveTrick(t, after);
    _learnedMark(t, before, after);
    _log(
      'trick',
      after.learned && !before.learned
          ? '유치원에서 ${_quoted(t.label, '을/를')} 배워 왔다'
          : '유치원에서 ${_quoted(t.label, '을/를')} 연습했다',
      at: at,
    );
    notifyListeners();
  }

  Future<void> _ensureFriends() => _friendsLoad ??= _loadFriends();

  bool _friendsReady = false;

  Future<void> _loadFriends() async {
    friends = await _db.loadFriends();
    knownDogs = [
      for (final r in await _db.loadKnownDogs())
        knownGuest(
          id: r.id,
          shape: r.shape,
          main: r.furMain,
          second: r.furSecond,
          marking: r.marking,
          puppy: r.puppy,
        ),
    ];
    _friendsReady = true;
  }

  /// 오늘 카페에서 만난 애들. 밤 꿈 풍선에 나온다.
  List<Guest> get metToday {
    final today = dayKey(petDate(_clock()));
    return [
      for (final g in cafeFriends)
        if (friends[g.id]?.lastDay == today) g,
    ];
  }

  /// 카페에 와 있는 애들과 오늘의 한 칸. 가장 가까워진 애와의 장면을 보여 준다.
  Future<void> _meetGuests() async {
    await _ensureFriends();
    if (!atCafe) return;
    final gen = _enterGen;
    final now = _clock();
    final today = dayKey(petDate(now));
    final night = cafeNight(now);
    final seats = seatsFor(guests.length);
    Guest? star;
    var starBond = Bond.none;
    var starX = 0.5;
    // 주인이 데려온 애를 처음 만나는 날은 그 애와의 장면을 보여 준다(더 친한 단골이 있어도).
    var newcomer = false;
    // 처리하는 사이 주인이 아는 강아지를 지웠으면 그 애는 건너뛴다(지운 사이가 되살아나지 않게).
    bool here(Guest g) =>
        !_removingKnownDogs.containsKey(g.id) &&
        guests.any((x) => x.id == g.id);
    var caught = false;
    for (final (i, g) in guests.indexed) {
      if (!here(g)) continue;
      final before = friends[g.id] ?? const Friendship();
      final after = before.met(today);
      if (identical(after, before)) continue;
      friends[g.id] = after;
      await _db.saveFriend(g.id, after);
      // 저장하는 사이 집에 갔거나 다시 들어왔으면 그 방문 것은 여기서 끝. 사이·저장은 이미 됐다.
      if (gen != _enterGen) {
        _present();
        return;
      }
      if (!here(g)) continue;
      final name = friendName(g, after);
      // 내리 만난 날이 문턱을 넘는 그날 한 번만 옮는다(그 뒤로 날마다 다시 옮으면 친구 둘 사이에서 날마다
      // 뒤집혔다). 한 방문에 하나, 이미 같은 버릇이면 그대로(옮긴 친구도 그대로).
      final habit = guestQuirk(g.id);
      if (!caught &&
          before.streak < catchStreak &&
          after.streak >= catchStreak &&
          habit != quirk &&
          habit != learnedQuirk) {
        caught = true;
        _background(_logOnce('friend_habit', habitCaughtLine(name, habit)));
        Telemetry.track('habit_caught', {'quirk': habit.name});
        _pet = _pet.copyWith(habit: Value('${habit.name}|${g.id}'));
        _save(now);
      }
      final newBestie = after.bond == Bond.bestie && before.bond != Bond.bestie;
      Telemetry.track('friend', {'guest': g.id, 'bond': after.bond.name});
      final String line;
      if (newBestie) {
        _milestone('bestie:${g.id}', bestieMilestonePaws);
        line = '${josa(name, '과/와')} 단짝이 됐다. 아끼던 걸 하나 주고 갔다';
      } else {
        line = switch (after.bond) {
          Bond.sniff => '카페에서 ${josa(name, '과/와')} 서로 킁킁 냄새를 맡았다',
          Bond.play => '카페에서 ${josa(name, '과/와')} 신나게 놀았다',
          Bond.bestie => '카페에서 단짝 ${josa(name, '과/와')} 또 신나게 놀았다',
          _ => '카페에서 ${josa(name, '을/를')} 처음 봤다. 멀찍이서 서로 쳐다봤다',
        };
      }
      _background(_logOnce('friend', line));
      if (after.bond == Bond.sniff) _cardCandidate ??= g;
      // 단짝이 되는 날 하루만 아끼던 물건을 두고 간다.
      if (newBestie) {
        await _db.addCarried(
          pickItem(
            _random,
            source: FindSource.friend,
            now: now,
            raining: false,
            like: g.taste,
          ).id,
          FindSource.friend,
          now,
        );
        carried = await _db.allCarried();
        if (gen != _enterGen) {
          _present();
          return;
        }
        if (!here(g)) continue;
      }
      final first = before.bond == Bond.none && isKnownDog(g.id);
      if (!newcomer && (first || after.bond.index > starBond.index)) {
        star = g;
        starBond = after.bond;
        starX = seats[i];
        newcomer = first;
      }
    }
    // 장면 주인공을 고른 뒤에 지워졌으면 장면 없이 카드 글만.
    if (star != null && !here(star)) star = null;
    final starId = star?.id;
    // 카드 두 줄 안에 들어가게: 가장 가까운 애만 앞에, 이름 없는 처음 보는 애들은 수로.
    bool nameless(Guest g) =>
        friends[g.id]?.bond == Bond.stranger && friends[g.id]?.name == null;
    final strangers = [
      for (final g in guests)
        if (g.id != starId && nameless(g)) g,
    ].length;
    final others = [
      for (final g in guests)
        if (g.id != starId && !nameless(g))
          '${friendName(g, friends[g.id])} ${bondLabel(friends[g.id]?.bond ?? Bond.none)}',
    ];
    cafeNote = [
      if (star != null)
        '${friendName(star, friends[star.id])} ${bondLabel(starBond)}',
      ...others,
      if (strangers > 0) '처음 보는 애 $strangers',
    ].join(' · ');
    // 입장 걷기('카페다!')가 끝난 뒤에 만남 장면으로 잇는다.
    if (star != null) {
      _plan.addAll(
        meetSteps(
          starBond,
          starX,
          friendName(star, friends[star.id]),
          night: night,
        ),
      );
    }
    // 만나고 싶던 애가 와 있다(오늘 이미 만났어도). 만남 장면 뒤에 기뻐한다.
    final wanted = openWish?.target;
    if (wanted != null && guests.any((g) => g.id == wanted)) {
      _fulfill(WishKind.friend, target: wanted);
    }
    notifyListeners();
  }

  /// 아는 강아지를 데려온다. 아직 못 만난 애라 다음에 카페에 가면 꼭 와 있다.
  /// 이름은 유저 입력이라 사용 기록엔 모양·사진 여부만 남긴다. 이름이 비었거나 꽉 찼으면 null.
  Future<Guest?> addKnownDog({
    required String name,
    required String shape,
    required PetColors colors,
    bool puppy = false,
    bool fromPhoto = false,
  }) => _disposed || _resetPending
      ? Future.value()
      : _tracked(
          _addKnownDog(
            name: name,
            shape: shape,
            colors: colors,
            puppy: puppy,
            fromPhoto: fromPhoto,
          ),
        );

  Future<Guest?> _addKnownDog({
    required String name,
    required String shape,
    required PetColors colors,
    required bool puppy,
    required bool fromPhoto,
  }) async {
    if (_disposed) return null;
    await _ensureFriends();
    if (_disposed) return null;
    final clean = cleanFriendName(name);
    if (clean == null || knownDogs.length >= maxKnownDogs) return null;
    final now = _clock();
    // id에 이름을 넣지 않는다(사용 기록에 id가 간다).
    var n = 0;
    String id;
    do {
      id = 'known_${now.millisecondsSinceEpoch}_${n++}';
    } while (friends.containsKey(id) || isKnownDog(id));
    final g = knownGuest(
      id: id,
      shape: shape,
      main: colors.main,
      second: colors.second,
      marking: colors.marking,
      puppy: puppy,
    );
    final f = Friendship(name: clean);
    await _db.addKnownDog(g, f, now);
    if (_disposed) return g;
    friends[id] = f;
    knownDogs = [...knownDogs, g];
    Telemetry.track('known_dog', {
      'action': 'add',
      'shape': shape,
      'puppy': puppy,
      'photo': fromPhoto,
    });
    notifyListeners();
    return g;
  }

  /// 아는 강아지의 이름·모습을 고친다. 카페에 와 있으면 바뀐 모습으로 다시 앉는다.
  Future<void> editKnownDog(
    String id, {
    required String name,
    required String shape,
    required PetColors colors,
    bool puppy = false,
    bool fromPhoto = false,
  }) => _disposed || _resetPending
      ? Future.value()
      : _tracked(
          _editKnownDog(
            id,
            name: name,
            shape: shape,
            colors: colors,
            puppy: puppy,
            fromPhoto: fromPhoto,
          ),
        );

  Future<void> _editKnownDog(
    String id, {
    required String name,
    required String shape,
    required PetColors colors,
    required bool puppy,
    required bool fromPhoto,
  }) async {
    if (_disposed || _removingKnownDogs.containsKey(id)) return;
    await _ensureFriends();
    if (_disposed || _removingKnownDogs.containsKey(id)) return;
    final i = knownDogs.indexWhere((g) => g.id == id);
    final clean = cleanFriendName(name);
    if (i < 0 || clean == null) return;
    final g = knownGuest(
      id: id,
      shape: shape,
      main: colors.main,
      second: colors.second,
      marking: colors.marking,
      puppy: puppy,
    );
    final f = (friends[id] ?? const Friendship()).named(clean);
    await _db.updateKnownDog(g, f);
    if (_disposed) return;
    final current = knownDogs.indexWhere((g) => g.id == id);
    if (current < 0) return;
    friends[id] = f;
    knownDogs = [...knownDogs]..[current] = g;
    if (guests.any((x) => x.id == id)) {
      guests = [for (final x in guests) x.id == id ? g : x];
    }
    Telemetry.track('known_dog', {
      'action': 'edit',
      'shape': shape,
      'puppy': puppy,
      'photo': fromPhoto,
    });
    notifyListeners();
  }

  /// 아는 강아지를 지운다. 사이·이름도 지우고, 카페에 와 있으면 자리에서 뺀다.
  Future<void> removeKnownDog(String id) {
    final pending = _removingKnownDogs[id];
    if (pending != null) return pending;
    if (_disposed || _resetPending) return Future.value();
    final removing = _tracked(_removeKnownDog(id));
    _removingKnownDogs[id] = removing;
    return removing;
  }

  Future<void> _removeKnownDog(String id) async {
    try {
      await _ensureFriends();
      if (_disposed || !isKnownDog(id)) return;
      // 재개설한 화면도 같은 삭제의 완료·실패를 기다린다.
      await _db.deleteKnownDog(id);
      if (_disposed) return;
      knownDogs = [
        for (final g in knownDogs)
          if (g.id != id) g,
      ];
      friends.remove(id);
      guests = [
        for (final g in guests)
          if (g.id != id) g,
      ];
      if (pendingCard?.id == id) pendingCard = null;
      if (_cardCandidate?.id == id) _cardCandidate = null;
      if (windowPasser?.id == id) {
        windowPasser = null;
        windowPassProgress = null;
      }
      Telemetry.track('known_dog', {'action': 'remove'});
      notifyListeners();
    } finally {
      _removingKnownDogs.remove(id);
    }
  }

  /// 친구에게 이름을 붙인다(빈 이름이면 뗀다). 유저 입력이라 일기·카페 안에서만 쓰고 알림·사용 기록엔 넣지 않는다.
  /// 아는 강아지는 주인이 지어 데려온 이름이라 비울 수 없다.
  Future<void> nameFriend(String id, String raw) => _disposed || _resetPending
      ? Future.value()
      : _tracked(_nameFriend(id, raw));

  Future<void> _nameFriend(String id, String raw) async {
    if (_disposed) return;
    await _ensureFriends();
    if (_disposed || _removingKnownDogs.containsKey(id)) return;
    if (id.startsWith('known_') && !isKnownDog(id)) return;
    final clean = cleanFriendName(raw);
    if (clean == null && isKnownDog(id)) return;
    final f = (friends[id] ?? const Friendship()).named(clean);
    friends[id] = f;
    await _db.saveFriend(id, f);
    if (_disposed) return;
    Telemetry.track('friend_named', {'guest': id, 'named': f.name != null});
    notifyListeners();
  }

  /// 놀이 사이가 넘는 친구들이 개인기를 따라 한다. 그날 처음은 일기에 남는다.
  void _friendsMimic(Trick t) {
    // 밤엔 손님들이 자고 있다. 깨워서 따라 하게 하지 않는다.
    if (cafeNight(_clock())) return;
    final fans = [
      for (final g in guests)
        if ((friends[g.id]?.bond.index ?? 0) >= Bond.play.index) g,
    ];
    if (fans.isEmpty) return;
    mimicTrick = t;
    // 펫이 개인기와 칭찬을 끝낸 뒤 친구들이 따라 하고(StepTag.mimic에서 시작), 펫은 그걸 보며 좋아한다.
    _plan.addAll(const [
      PetStep(Behavior.sit, 1, tag: StepTag.mimic),
      PetStep(Behavior.happy, 2, cue: Cue.yip, thought: '따라 하네! 나 잘하지?'),
    ]);
    final name = friendName(fans.first, friends[fans.first.id]);
    _background(
      _logOnce(
        'friend_trick',
        '카페에서 ${_quoted(t.label, '을/를')} 했더니 ${josa(name, '이/가')} 따라 했다',
      ),
    );
  }

  /// 어제 만난 친구가 낮에 창밖을 지나간다. 한가하면 창가로 가서 본다.
  void _watchWindowPasser() {
    if (out || walking || replaying) {
      windowPasser = null;
      windowPassProgress = null;
      return;
    }
    final now = _clock();
    final p = windowPass(now, _pet.id);
    final passer = p == null ? null : passerFor(cafeFriends, friends, now);
    final starting = passer != null && windowPasser == null;
    windowPasser = passer;
    windowPassProgress = passer == null ? null : p;
    if (!starting) return;
    // 제 할 일(서기·앉기·걷기·킁킁, 날씨 탓에 제 발로 누운 것)만 끊는다.
    // 반김·개인기 칭찬·쓰다듬 반응·위로하느라 누운 것 같은 반응은 두고 본다.
    final held = presenting;
    final free =
        _plan.isEmpty &&
        ball == Ball.none &&
        !pottyUrge &&
        (held == null || held.source == FindSource.window) &&
        (const {
              Behavior.idle,
              Behavior.sit,
              Behavior.walk,
              Behavior.sniff,
            }.contains(step.behavior) ||
            (everyday && step.behavior == Behavior.lieBeside));
    if (!free) return;
    _play(const [
      PetStep(
        Behavior.watchWindow,
        8,
        targetX: windowX,
        cue: Cue.yip,
        thought: '어? 그 애다!',
      ),
    ]);
    final name = friendName(passer, friends[passer.id]);
    _background(
      _logOnce('friend_window', '${josa(name, '이/가')} 창밖으로 지나가는 걸 봤다'),
    );
  }

  Future<void> _ensureTricks() => _tricksLoad ??= _db.loadTricks().then((
    t,
  ) async {
    tricks = t;
    _tricksReady = true;
    // 날짜 채우기는 덤이라 실패해도 읽기는 성공으로 둔다. 이 Future는 다시 만들지 않아서,
    // 실패가 남으면 그 뒤 개인기를 쓰는 일(명령·수업·소원)이 모두 같은 에러로 막힌다.
    try {
      await _fillLearnedDays();
    } catch (e) {
      Telemetry.track('learned_day_error', {'error': e.runtimeType.toString()});
    }
  });

  /// 배운 날 칸이 생기기 전에 배운 개인기는 일기 재료에서 배운 날을 찾아 채운다(훈련 수첩에 날짜가 나오게).
  Future<void> _fillLearnedDays() async {
    if (!tricks.values.any((p) => p.learned && p.learnedDay == null)) return;
    final lines = [
      for (final e in await _db.eventsOfKind('trick'))
        (at: e.at, detail: e.detail),
    ];
    // 읽는 사이 연습한 기록을 덮지 않게 지금 기록에 날짜만 붙인다.
    for (final MapEntry(key: t, value: p) in tricks.entries.toList()) {
      if (!p.learned || p.learnedDay != null) continue;
      final day = learnedDayFromLines(t, lines);
      if (day == null) continue;
      final filled = TrickProgress(
        attempts: p.attempts,
        successes: p.successes,
        days: p.days,
        lastDay: p.lastDay,
        learnedDay: day,
      );
      tricks[t] = filled;
      _background(_db.saveTrick(t, filled));
    }
  }

  /// 장소에서 집으로. 몇 분 있었는지 돌려주고 일기 재료로 남긴다.
  int comeHome() {
    final now = _clock();
    final was = spot;
    final minutes = now.difference(spotSince ?? now).inMinutes;
    Telemetry.track('place_leave', {
      'place': was.name,
      'minutes': minutes,
      'guests': guests.length,
    });
    switch (was) {
      case Spot.cafe:
        _log('cafe', '카페에 가서 다른 강아지 ${guests.length}마리를 구경했다');
      case Spot.kindergarten:
        _log('daycare', '주인이랑 유치원에 놀러 가서 친구들이랑 뛰어놀았다');
      // 산 날·검진받은 날은 그 기록이 하루 이야기라 둘러보기만 한 방문은 따로 남기지 않는다.
      // 둘러본 뒤에 샀다면 둘 다 맞는 일이라 종류를 나눠 둘 다 남는다.
      case Spot.treatShop when !boughtToday:
        _background(_logOnce('shop_visit', '간식 가게에 가서 진열장 냄새만 실컷 맡았다'));
      case Spot.hospital when !_checkedToday:
        _background(_logOnce('hospital_visit', '병원에 갔다. 냄새만 맡고 무서워서 금방 나왔다'));
      default:
    }
    spot = Spot.home;
    guests = const [];
    _noteOwner();
    _enterGen++;
    cafeNote = '';
    pendingCard = null;
    _cardCandidate = null;
    mimicTrick = null;
    _recitalActs = null;
    _plan.clear();
    // 밤이면 가운데를 거치지 않고 자는 자리로 간다.
    _start(
      PetStep(Behavior.walk, 9, targetX: _asleepAt(now) ? sleepSpotX : 0.5),
    );
    _present();
    _save(now);
    return minutes;
  }

  Stream<List<Memory>> watchMemoryNotebook(int limit) =>
      _db.watchMemoryNotebook(limit);

  Future<MemoryPinResult> setMemoryPinned(int id, bool pinned) =>
      _disposed || _resetPending
      ? Future.value(MemoryPinResult.missing)
      : _tracked(_db.setMemoryPinned(id, pinned));

  Future<bool> forgetMemory(int id) => _disposed || _resetPending
      ? Future.value(false)
      : _tracked(_db.forgetMemory(id));

  Future<List<String>> _memoryLines() async {
    final today = _dateOnly(_clock());
    return [
      for (final m in await _db.conversationMemories())
        '(${_relativeDay(today.difference(_dateOnly(m.createdAt)).inDays)}) ${m.content}',
    ];
  }

  bool _canTalk() {
    _rollDay(_clock());
    return _pet.talksToday < dailyTalkLimit;
  }

  bool _takeTalkSlot() {
    if (!_canTalk()) return false;
    _pet = _pet.copyWith(talksToday: _pet.talksToday + 1);
    // 기억을 읽는 동안 화면이 꺼졌을 수 있다. 횟수를 적으며 마지막 방문 시각을 밀지 않는다.
    _background(_db.savePetState(_pet));
    return true;
  }

  /// 하루가 앞으로 바뀌었으면 하루 한도를 비우고 true. 시계를 하루이틀 되돌린 건(시간대 이동 같은) 같은 날로
  /// 쳐서 한도를 다시 채우지 않는다. 그보다 멀리 되돌렸으면 시계를 바로잡은 것으로 보고 한도만 비운다.
  bool _rollDay(DateTime now) {
    final day = petDate(now);
    final today = dayKey(day);
    if (_pet.countDay == today) return false;
    final last = DateTime.tryParse(_pet.countDay ?? '');
    final back = last != null && day.isBefore(last);
    if (back && last.difference(day).inDays <= 2) return false;
    _pet = _pet.copyWith(countDay: Value(today), bondToday: 0, talksToday: 0);
    return !back;
  }

  /// 오늘 남은 친밀도 몫에서 [amount]까지 쓰고, 실제로 쓴 만큼 돌려준다.
  double _bondUpTo(double amount) {
    _rollDay(_clock());
    final got = min(amount, max(0.0, dailyBondFor(intimacy) - _pet.bondToday));
    _pet = _pet.copyWith(bondToday: _pet.bondToday + got);
    return got;
  }

  /// 오늘 남은 친밀도 몫에서 [amount]를 쓴다. 다 썼으면 false.
  bool _takeBond(double amount) {
    _rollDay(_clock());
    if (_pet.bondToday + amount > dailyBondFor(intimacy)) return false;
    _pet = _pet.copyWith(bondToday: _pet.bondToday + amount);
    return true;
  }

  List<PetStep> _stepsFor(PetAction action) {
    return switch (action) {
      PetAction.happy ||
      PetAction.proposeWalk => const [PetStep(Behavior.happy, 3)],
      PetAction.approach => const [
        PetStep(Behavior.run, 4, targetX: 0.5),
        PetStep(Behavior.sit, 4),
      ],
      PetAction.lieBeside => const [
        PetStep(Behavior.run, 4, targetX: 0.5),
        PetStep(Behavior.lieBeside, 8),
      ],
      PetAction.sit => const [PetStep(Behavior.sit, 4)],
      PetAction.sulk => const [PetStep(Behavior.sulk, 5)],
      PetAction.sleep => const [PetStep(Behavior.sleep, 20)],
      PetAction.play => [
        PetStep(Behavior.run, 3, targetX: 0.2 + _random.nextDouble() * 0.6),
        const PetStep(Behavior.happy, 2),
        PetStep(Behavior.run, 3, targetX: 0.2 + _random.nextDouble() * 0.6),
      ],
    };
  }

  void _perform(List<PetStep> steps, String thought, {bool ai = false}) {
    _play(steps);
    _say(thought, 6, ai: ai);
  }

  void _play(List<PetStep> steps) {
    _plan
      ..clear()
      ..addAll(steps.skip(1));
    _start(steps.first);
  }

  /// 강아지가 자는 때. 주인에게 배운 리듬을 따른다. 소리를 줄이는 밤(23~7시)과는 다르다.
  bool _asleepAt(DateTime t) {
    final met = _firstMetAt;
    if (met != null &&
        !t.isBefore(met) &&
        t.difference(met) < _firstMeetingLength) {
      return false;
    }
    return _rhythm.isDogNight(t);
  }

  /// 밤잠이나 지쳐서 자는 잠. 낮잠은 쓰다듬으면 깨서 반긴다.
  bool get _soundAsleep =>
      step.behavior == Behavior.sleep &&
      (_asleepAt(_clock()) || stats.energy < tiredEnergy);

  bool get _sleepy {
    final now = _clock();
    return _asleepAt(now) || _rhythm.isDrowsy(now);
  }

  void _cue(Cue c) {
    if (_cues.isClosed) return;
    final now = _clock();
    // 밤에 크게 짖으면 옆에서 자는 사람이 깬다.
    final cue = c == Cue.bark && isNight(now) ? Cue.yip : c;
    // 앱을 새로 켜면 화면이 듣기 전에 반김 첫 소리가 먼저 난다. 잠깐 잡아 뒀다가 들려준다.
    if (!_cues.hasListener) {
      _pendingCues
        ..removeWhere((e) => now.difference(e.$2) >= _cueHold)
        ..add((cue, now));
      return;
    }
    _cues.add(cue);
  }

  static const _cueHold = Duration(seconds: 2);

  void _flushCues() {
    final now = _clock();
    for (final (cue, at) in _pendingCues) {
      if (now.difference(at) < _cueHold) _cues.add(cue);
    }
    _pendingCues.clear();
  }

  void _say(String text, double seconds, {bool ai = false}) {
    bubble = text;
    bubbleFromAi = ai;
    _bubbleLeft = seconds;
    notifyListeners();
  }

  void sleepApp() {
    if (_disposed || _resetPending) return;
    _retryRecognition();
    _supersedeReaction();
    final now = _clock();
    _applyPending(now);
    _save(now);
    Telemetry.track('pause', _statsMap());
  }

  /// 켜져 있는 동안의 실시간 진행만 담당한다. 꺼져 있던 시간은 wake()가 계산하므로
  /// 백그라운드에서 돌아온 직후의 큰 dt는 잘라낸다.
  void tick(double dt) {
    if (_disposed || _resetPending) return;
    dt = min(dt, 1);
    _remaining -= dt;
    _sinceDecay += dt;
    if (bubble != null) {
      _bubbleLeft -= dt;
      if (_bubbleLeft <= 0) {
        bubble = null;
        notifyListeners();
      }
    }
    // 산책 조르기는 몇 분 지나면 스스로 접는다. 거절 버튼 없이도 강조가 계속 남지 않게.
    if (walkProposed &&
        _clock().difference(_walkProposedAt ?? _clock()) >
            const Duration(minutes: 5)) {
      walkProposed = false;
      notifyListeners();
    }
    if (_sinceDecay >= 60) {
      final now = _clock();
      _applyPending(now);
      _rollWish(now);
      _save(now);
      notifyListeners();
    }
    if (spot == Spot.kindergarten && !inDaycare && !kinderOpen(_clock())) {
      comeHome();
      _say('문 닫을 시간이래.', 4);
    }
    if (_pet.daycareFrom case final d? when !inDaycareAt(d, _clock())) {
      final now = _clock();
      _applyPending(now);
      _endDaycare(now.isBefore(d) ? now : pickupAt(d), byOwner: false);
      _play(const [
        PetStep(Behavior.walk, 5, targetX: 0.5, thought: '버스 타고 왔다!'),
        PetStep(Behavior.happy, 2, cue: Cue.yip),
      ]);
      _save(now);
    }
    _watchWindowPasser();
    // 칭찬 기회가 지나면 말 걸기 칸 안내도 거둔다(다음 동작 전까지 남아 있었다).
    if (_praisable != null && _livePraise == null) {
      _praisable = null;
      notifyListeners();
    }
    if (puddleX != null && _clock().difference(_puddleAt!) >= puddleLasts) {
      puddleX = null;
      notifyListeners();
    }
    if (_remaining <= 0) _next();
  }

  /// 지금 동작이 시작된 뒤 지난 시간. 게임이 점프 높이처럼 동작에 맞춘 움직임을 그릴 때 쓴다.
  double get stepElapsed =>
      (step.seconds - _remaining).clamp(0.0, step.seconds);

  /// 쉬가 마려울 때 '패드로' 버튼을 눌렀다. 패드로 데려가면 거기서 하고, 한 번 성공으로 센다.
  void goToPad() {
    if (!pottyUrge || step.tag != StepTag.urge) return;
    _resolvePotty(byOwner: true);
  }

  /// 킁킁대는 중에 다른 동작이 끼어들었다. 연습으로 치지 않고 2분 뒤 다시 마렵다.
  void _cancelUrge() {
    pottyUrge = false;
    _urgeAgainAt = _clock().add(const Duration(minutes: 2));
  }

  bool _pottyDue(DateTime now) {
    if (pottyUrge || uiBusy || roomHidden || walking || out || replaying) {
      return false;
    }
    if (ball != Ball.none) return false;
    // 창틀에 떨어진 물건은 물고 있는 게 아니다.
    if (presenting case final p? when p.source != FindSource.window) {
      return false;
    }
    if (_asleepAt(now) || stats.energy < tiredEnergy) return false;
    if (_urgeAgainAt case final again? when now.isBefore(again)) return false;
    // 열고 나서 반김·자랑·발견 카드가 지나갈 만큼 기다린다.
    final woke = _wokeAt;
    if (woke == null || now.difference(woke) < const Duration(seconds: 45)) {
      return false;
    }
    final last = _pet.pottyAt;
    return last == null || now.difference(last) >= pottyEvery;
  }

  /// 킁킁대며 빙글 도는 8초. 그 안에 패드로 데려가지 않으면 배운 애는 혼자 가고, 아직이면 그 자리에서 한다.
  void _startUrge() {
    pottyUrge = true;
    Telemetry.track('potty_urge', {
      'learned': tricks[Trick.potty]?.learned ?? false,
    });
    _play(const [
      PetStep(
        Behavior.sniff,
        2.5,
        cue: Cue.sniff,
        tag: StepTag.urge,
        thought: '킁킁… 어디서 하지?',
      ),
      PetStep(Behavior.spin, 1.6, tag: StepTag.urge),
      PetStep(Behavior.sniff, 2.5, tag: StepTag.urge),
      PetStep(Behavior.sit, 1.5, tag: StepTag.urge, thought: '급해…'),
    ]);
  }

  void _resolvePotty({required bool byOwner}) {
    final now = _clock();
    final today = dayKey(petDate(now));
    final before = tricks[Trick.potty] ?? const TrickProgress();
    final success = byOwner || before.learned;
    final after = before.practiced(success: success, today: today);
    tricks[Trick.potty] = after;
    _background(_db.saveTrick(Trick.potty, after));
    _learnedMark(Trick.potty, before, after);
    pottyUrge = false;
    _pet = _pet.copyWith(pottyAt: Value(now));
    if (success) {
      final learnedNow = byOwner && !before.learned && after.learned;
      final bond = byOwner && _takeBond(1);
      stats = stats.copyWith(
        mood: stats.mood + 2,
        affection: stats.affection + (bond ? 1 : 0),
      );
      if (bond) careScore += careTrick;
      _play([
        PetStep(
          byOwner ? Behavior.run : Behavior.walk,
          4,
          targetX: padX,
          tag: StepTag.potty,
          cue: byOwner ? Cue.yip : null,
        ),
        const PetStep(Behavior.sit, 2.5, tag: StepTag.potty, thought: '쉬—'),
        PetStep(
          Behavior.happy,
          1.5,
          cue: learnedNow ? Cue.chime : Cue.bark,
          thought: learnedNow
              ? '여기서 하는 거구나! 알았어!'
              : byOwner
              ? '잘했지?'
              : null,
        ),
      ]);
      if (learnedNow) {
        _log('trick', '패드에서 쉬하는 걸 배웠다');
      } else if (byOwner) {
        _background(_logOnce('trick', '주인이 패드로 데려가 줘서 거기에 쉬했다'));
      } else {
        _background(_logOnce('trick', '혼자서 패드에 가서 쉬했다'));
      }
    } else {
      // 실수. 벌도 깎이는 것도 없다. 자국은 잠시 뒤 사라지고, 다음엔 조금 더 잘 알아챈다.
      puddleX = petX;
      _puddleAt = now;
      _play(const [
        PetStep(Behavior.sit, 2, tag: StepTag.potty, thought: '…해 버렸다'),
        PetStep(Behavior.sniff, 1.5, tag: StepTag.potty),
      ]);
      _background(_logOnce('trick', '바닥에 쉬했다. 패드는 아직 어렵다'));
    }
    Telemetry.track('potty', {
      'by_owner': byOwner,
      'success': success,
      'learned': after.learned,
    });
    _save(now);
    notifyListeners();
  }

  void _applyPending(DateTime now) {
    final from = now.subtract(
      Duration(milliseconds: (_sinceDecay * 1000).round()),
    );
    stats = elapsedWithDaycare(
      stats,
      from,
      now,
      dropped: _pet.daycareFrom,
      napping: step.behavior == Behavior.sleep,
      asleepAt: _rhythm.isDogNight,
      sleepGain: _rhythm.sleepGain,
    );
    _sinceDecay = 0;
  }

  void arrived() {
    if (step.tag == StepTag.chase) {
      if (ball != Ball.ready) return;
      ball = Ball.carried;
      _fetching = true;
      _cue(Cue.pickUp);
      final praise = _fetchPraise;
      _fetchPraise = null;
      _play([
        const PetStep(Behavior.sniff, 0.4, tag: StepTag.carry),
        const PetStep(Behavior.run, 4, targetX: 0.5, tag: StepTag.carry),
        if (_has(Quirk.spinBeforeDrop))
          const PetStep(Behavior.spin, 1.2, tag: StepTag.carry),
        const PetStep(Behavior.sit, 1, tag: StepTag.drop, cue: Cue.drop),
        praise ??
            const PetStep(Behavior.happy, 2, cue: Cue.bark, thought: '또 던져 줘!'),
      ]);
      if (quirk == Quirk.spinBeforeDrop) _quirkShown();
      return;
    }
    if (step.behavior == Behavior.walk || step.behavior == Behavior.run) {
      // 게임은 매 프레임 자리를 적어 주지만, 그림 없이 도는 테스트·가상 테스터에선 닿은 자리가 지금 자리다.
      if (step.targetX case final x?) petX = x;
      _next();
    }
  }

  void interact(Interaction interaction) {
    if (_disposed || _resetPending || replaying) return;
    _retryRecognition();
    // 유치원 CCTV로 보는 중이라 만질 수 없다. 화면을 누르면 카메라 쪽을 쳐다본다. 친밀도는 오르지 않는다.
    if (inDaycare) {
      if (step.behavior != Behavior.sleep && step.thought != _cctvThought) {
        _play(const [
          PetStep(Behavior.sit, 1.5, thought: _cctvThought),
          PetStep(Behavior.happy, 1.5),
        ]);
      }
      return;
    }
    final now = _clock();
    _stayAwake(now);
    final sinceLast = _lastPetted == null ? null : now.difference(_lastPetted!);
    final cooledDown =
        sinceLast == null ||
        sinceLast.isNegative ||
        sinceLast > const Duration(seconds: 3);
    _noteOwner();
    if (interaction == Interaction.pet && spot == Spot.home && !walking) {
      _pet = _pet.copyWith(touchX: Value(petX));
    }
    if (interaction == Interaction.pet && cooledDown) {
      _lastPetted = now;
      // 깊이 잠든 동안 쓰다듬은 건 세지 않는다(친해지는 것과 같은 규칙).
      if (openWish?.kind == WishKind.cuddle && !_soundAsleep) _wishPets++;
    }
    final last = _lastBond;
    final spaced =
        last == null || now.isBefore(last) || now.difference(last) >= bondEvery;
    final bond =
        interaction == Interaction.pet &&
        cooledDown &&
        spaced &&
        !_soundAsleep &&
        _takeBond(2);
    final r = react(
      stats,
      interaction,
      sleeping: _soundAsleep,
      cooledDown: cooledDown,
      bond: bond,
    );
    if (bond) _lastBond = now;
    stats = r.stats;
    Telemetry.track('tap', {
      'what': interaction.name,
      'result': r.step.behavior.name,
      'cooled_down': cooledDown,
      ..._statsMap(),
    });
    switch (interaction) {
      case Interaction.feed when r.step.behavior == Behavior.eat:
        careScore += careFeed;
        _log('feed', '주인이 밥을 줬다');
      case Interaction.pet when cooledDown && r.step.behavior == Behavior.happy:
        careScore += carePet;
        // 쓰다듬기는 잦아서 10분에 한 번만 일기 재료로 남긴다.
        if (_lastPetLogged == null ||
            dayKey(_lastPetLogged!) != dayKey(now) ||
            now.difference(_lastPetLogged!) > const Duration(minutes: 10)) {
          _lastPetLogged = now;
          _log('pet', '주인이 쓰다듬어 줬다');
        }
      default:
    }
    // 밥 앞에서 앉아 기다리는 동안 쓰다듬으면 좋아한 뒤 그대로 먹는다(배고픔은 이미 줄었다).
    final waitingToEat =
        step.tag == StepTag.bowl && step.behavior == Behavior.sit;
    if (!walking && !waitingToEat) _plan.clear();
    final eats =
        interaction == Interaction.feed &&
        r.step.behavior == Behavior.eat &&
        !walking;
    // 밥 앞에서 앉아 기다리는 사이엔 폴짝하지 않는다(폴짝이 계획을 비워 밥을 못 먹었다).
    final hops =
        interaction == Interaction.pet &&
        r.step.behavior == Behavior.happy &&
        cooledDown &&
        !walking &&
        !waitingToEat &&
        _has(Quirk.hopWhenPetted);
    final sits = eats && _has(Quirk.sitBeforeEat);
    final licks = eats && _has(Quirk.sniffBowlAfter);
    if (sits || licks) {
      _play([
        if (sits)
          const PetStep(Behavior.sit, 1.2, cue: Cue.yip, tag: StepTag.bowl),
        r.step,
        if (licks)
          const PetStep(Behavior.sniff, 2.4, cue: Cue.sniff, tag: StepTag.bowl),
      ]);
      if (quirk == Quirk.sitBeforeEat || quirk == Quirk.sniffBowlAfter) {
        _quirkShown();
      }
    } else if (hops) {
      // 쓰다듬은 소리는 바로 나야 해서 폴짝에 붙인다.
      _play([
        const PetStep(Behavior.jump, 0.65, cue: Cue.pop),
        PetStep(r.step.behavior, r.step.seconds),
      ]);
      if (quirk == Quirk.hopWhenPetted) _quirkShown();
    } else {
      _start(r.step);
    }
    // 조르러 왔는데 곧 쓰다듬어 줬다. 앵긴다(안 받아 줘도 아무 일 없다).
    final begAt = _begAt;
    if (interaction == Interaction.pet &&
        begAt != null &&
        !now.isBefore(begAt) &&
        now.difference(begAt) <= begAnswerWithin) {
      _begAt = null;
      stats = stats.copyWith(mood: stats.mood + 2);
      _plan.addAll(begAnsweredSteps);
      _background(_logOnce('cuddle', '조르러 갔더니 주인이 쓰다듬어 줬다'));
      Telemetry.track('beg_answered', {});
    }
    // 쓰다듬는 반응 뒤에 기뻐한다(위에서 계획을 비우니 그다음에).
    final cuddleJustCompleted =
        _wishPets >= cuddleWishPets && openWish?.kind == WishKind.cuddle;
    if (cuddleJustCompleted) _fulfill(WishKind.cuddle);
    _save(now);
    if (interaction == Interaction.pet &&
        cooledDown &&
        r.step.behavior == Behavior.happy &&
        !_firstDayRecognized &&
        _canRecognizeOwner &&
        !waitingToEat &&
        !cuddleJustCompleted) {
      final today = petDate(now);
      if (today.isAfter(petDate(_pet.bornAt)) &&
          _recognitionCheckedOn != dayKey(today)) {
        _background(_recognizeFirstDay(now, _reactionVersion));
      }
    }
  }

  static const _firstDayScents = [
    'play',
    'walk',
    'feed',
    'pet',
    'first_meeting',
  ];

  (String, String) _firstDayScent(
    String kind,
    DateTime happened,
    DateTime now,
  ) {
    final day = dayKey(happened);
    final when = day == dayKey(now)
        ? (happened.hour < dayStartHour ? '새벽에' : '아까')
        : day == dayKey(DateTime(now.year, now.month, now.day - 1))
        ? '어제'
        : '그때';
    return switch (kind) {
      'play' => ('$when 공 던져 준 그 손이다!', '$when 공을 던져 준 주인 손을 알아봤다'),
      'walk' => ('$when 같이 산책한 주인 냄새다.', '$when 함께 산책한 주인 냄새를 알아봤다'),
      'feed' => ('킁… $when 밥 주던 손 냄새다!', '$when 밥을 준 주인 손을 알아봤다'),
      'pet' => ('$when 쓰다듬던 그 손이다.', '$when 쓰다듬어 준 주인 손을 알아봤다'),
      _ => ('이 냄새, $when 처음 맡아 봤어.', '$when 처음 맡은 주인 냄새를 알아봤다'),
    };
  }

  bool get _canRecognizeOwner =>
      !out &&
      !walking &&
      !roomHidden &&
      !uiBusy &&
      !replaying &&
      ball == Ball.none &&
      !pottyUrge &&
      !_soundAsleep;

  Future<void> _recognizeFirstDay(DateTime at, int version) async {
    final visit = _roomVisit;
    bool stillPetting() {
      final now = _clock();
      final age = now.difference(at);
      return _ownsReaction(version) &&
          _roomVisit == visit &&
          _canRecognizeOwner &&
          !_firstDayRecognized &&
          !age.isNegative &&
          age <= const Duration(seconds: 3) &&
          dayKey(petDate(now)) == dayKey(petDate(at));
    }

    final previousDay = petDayStart(petDate(at), offsetDays: -1);
    Map<String, DateTime> facts;
    try {
      facts = await _db.firstDayCareTimes(previousDay);
    } catch (_) {
      return;
    }
    if (!stillPetting()) return;
    final meeting = facts['first_meeting'];
    if (facts.containsKey('first_recognition') || meeting == null) {
      _firstDayRecognized = true;
      return;
    }
    if (dayKey(petDate(meeting)) != dayKey(previousDay)) {
      _recognitionCheckedOn = dayKey(petDate(at));
      if (petDate(meeting).isBefore(petDate(previousDay))) {
        _firstDayRecognized = true;
      }
      return;
    }
    final kind = _firstDayScents.firstWhere(facts.containsKey);
    final (thought, detail) = _firstDayScent(kind, facts[kind]!, at);
    try {
      await _db.transaction(() async {
        if (!stillPetting()) return;
        if (!await _db.insertFirstRecognition(at, detail)) {
          _firstDayRecognized = true;
          return;
        }
        // 쓰는 사이 화면이 가려졌거나 다른 손길이 왔다면 이 INSERT도 함께 롤백한다.
        if (!stillPetting()) throw const _PettingEnded();
        _firstDayRecognized = true;
        _unwrittenRecognition = (at, detail);
        _say(thought, 7);
      });
      if (_unwrittenRecognition == (at, detail)) _unwrittenRecognition = null;
    } on _PettingEnded {
      return;
    } catch (_) {
      Telemetry.track('recognition_storage_error');
    }
  }

  // INSERT 뒤 최종 커밋이 실패한 경우, 이미 보여 준 말은 되풀이하지 않고 기록만 복구한다.
  void _retryRecognition() {
    final pending = _unwrittenRecognition;
    if (pending == null || _restoringRecognition) return;
    _restoringRecognition = true;
    _background(() async {
      try {
        await _db.transaction(
          () => _db.insertFirstRecognition(pending.$1, pending.$2),
        );
        _unwrittenRecognition = null;
      } catch (_) {
        Telemetry.track('recognition_storage_error');
      } finally {
        _restoringRecognition = false;
      }
    }());
  }

  void _next() {
    if (handX != null && !_handHeld && _plan.isEmpty) {
      handX = null;
      notifyListeners();
    }
    if (replaying && _plan.isEmpty) {
      _finishReplay();
      return;
    }
    // 킁킁대는 동안 아무도 데려가지 않았다.
    if (pottyUrge && _plan.isEmpty && step.tag == StepTag.urge) {
      _resolvePotty(byOwner: false);
      return;
    }
    if (_plan.isNotEmpty) {
      _start(_plan.removeAt(0));
      return;
    }
    if (walking) {
      if (step.behavior != Behavior.sniff && _random.nextDouble() < 0.25) {
        // 지도에 찍는 킁킁 자리는 길에서 스스로 멈춘 것만(명령을 못 알아들은 킁킁은 빼고).
        walkSniffs++;
        _start(const PetStep(Behavior.sniff, 2.5));
        return;
      }
      _walkRight = !_walkRight;
      _start(PetStep(Behavior.walk, 6, targetX: _walkRight ? 0.85 : 0.15));
      return;
    }
    // 진열장을 다 돌기 전에 쓰다듬기·말 걸기가 끼면 남은 길이 지워진다. 고른 칸으로 다시 가서 앉는다.
    if (spot == Spot.treatShop && !pickShown && shopPickIndex != null) {
      _play(toPick(shopPickIndex!));
      return;
    }
    if (out) {
      // 바깥에서도 잘 시간이거나 지쳤으면 그 자리에서 꾸벅 존다. 상태 계산은 잘 시간을 이미 잠으로 치는데
      // 장소 동작엔 잠이 없어서, 새벽 카페에서 계속 돌아다니는 그림이 됐다. 처음 한 번만 속마음으로 알린다.
      // 주인이 낮잠을 깨웠으면 몇 분은 집에서처럼 안 존다.
      final now = _clock();
      final tired =
          stats.energy < tiredEnergy &&
          (_awakeUntil == null || !now.isBefore(_awakeUntil!));
      if (!inDaycare && (tired || _asleepAt(now))) {
        if (!_dozeSaid) {
          _dozeSaid = true;
          _start(
            PetStep(
              Behavior.sit,
              2.5,
              cue: Cue.sigh,
              thought: tired ? '헥헥… 집에 가서 쉴래' : '꾸벅… 나도 졸려',
            ),
          );
          return;
        }
        _start(PetStep(Behavior.sleep, 20 + _random.nextDouble() * 10));
        return;
      }
      if (_daycareRecitalLive) {
        _beginRecital();
        return;
      }
      _start(switch (spot) {
        Spot.kindergarten => kinderStep(_random, _clock()),
        Spot.treatShop => shopStep(_random, shopSlots[shopPickIndex ?? 0]),
        Spot.hospital => hospitalStep(_random),
        _ => cafeStep(_random),
      });
      return;
    }
    if (ball == Ball.thrown || ball == Ball.ready) {
      // 공 때문에 잠을 못 자면 안 된다. 지쳤거나 한참 안 던지면(밤엔 금방) 공을 치운다.
      final limit = _sleepy ? 2 : 7;
      if (stats.energy < tiredEnergy || _ballWait > limit) {
        _clearBall();
        Telemetry.track('ball_away', {'auto': true});
      } else if (ball == Ball.thrown) {
        _start(_chase());
        return;
      } else {
        _start(switch (_ballWait++) {
          0 => const PetStep(Behavior.sit, 4),
          1 => const PetStep(
            Behavior.sniff,
            1.5,
            cue: Cue.whine,
            thought: '안 던져?',
          ),
          _ => const PetStep(Behavior.lieBeside, 10),
        });
        return;
      }
    }
    if (_doorNewsDue(_clock()) case final item?) {
      _setDoorNews(item);
      _log('door', doorPlacedLine(item));
      Telemetry.track('door_news', {'item': item.name});
      _play(doorSteps(item));
      return;
    }
    if (_wantsReveal(_clock())) {
      _play(revealSteps);
      return;
    }
    if (_wantsToBeg(_clock())) {
      _begged = true;
      Telemetry.track('beg', {});
      _play(begSteps(_random));
      return;
    }
    // 오늘의 소원을 고른 뒤 한가할 때 속마음으로 한 번 말한다.
    if (openWish case final w?
        when _wishToSay &&
            bubble == null &&
            !_asleepAt(_clock()) &&
            stats.energy >= tiredEnergy) {
      _wishToSay = false;
      _start(
        PetStep(
          Behavior.sit,
          3.5,
          thought: wishThought(w, friend: _wishFriendName),
        ),
      );
      return;
    }
    if (_wantsHideCheck(_clock())) {
      _hideCheckDue = false;
      _play(hideCheckSteps(petX));
      _background(_logOncePerDay('hide', '방석 밑을 몰래 확인했다. 거기 있는 건 아무도 모른다'));
      return;
    }
    if (_wantsVisit()) {
      final visit = chooseVisit(
        _random,
        placed,
        like: _pet.likeTaste,
        dislike: _pet.dislikeTaste,
      );
      if (visit != null) {
        _plan.addAll(visit.skip(1));
        _start(visit.first);
        return;
      }
    }
    if (_pottyDue(_clock())) {
      _startUrge();
      return;
    }
    // 밤잠은 제 자리에서 잔다(친해질수록 주인 쪽으로). 멀면 걸어가서 눕는다.
    // 주인이 손을 대고 있으면 손 곁에서 잔다.
    if (_asleepAt(_clock()) && handX == null) {
      final x = sleepSpotX;
      if ((petX - x).abs() > sleepSpotSlack) {
        final circles = _has(Quirk.circleBeforeSleep);
        _plan.addAll([
          if (circles) ...circleSteps(x),
          const PetStep(Behavior.sleep, 30),
        ]);
        _start(PetStep(Behavior.walk, 9, targetX: x));
        if (quirk == Quirk.circleBeforeSleep) _quirkShown();
        return;
      }
      _sleptAtSpot();
    }
    final next = chooseNext(
      stats,
      _clock(),
      _random,
      weather: weatherMood,
      intimacy: intimacy,
      asleep: _asleepAt(_clock()),
      traits: traits,
      puppy: _pet.stage == PetStage.puppy,
      napAllowed: _awakeUntil == null || !_clock().isBefore(_awakeUntil!),
    );
    // 자다가 다시 잘 땐 돌지 않는다.
    if (next.behavior == Behavior.sleep &&
        step.behavior != Behavior.sleep &&
        _has(Quirk.circleBeforeSleep)) {
      _play([...circleSteps(petX), next]);
      if (quirk == Quirk.circleBeforeSleep) _quirkShown();
      return;
    }
    _start(next);
    everyday = true;
  }

  /// 낮잠 자는 강아지를 만졌으면 몇 분은 깨어 있는다. 밤잠과 지쳐서 자는 잠은 해당 없다.
  void _stayAwake(DateTime now) {
    if (step.behavior == Behavior.sleep && !_soundAsleep) {
      _awakeUntil = now.add(const Duration(minutes: 3));
    }
  }

  bool _wantsVisit() =>
      !_asleepAt(_clock()) &&
      stats.energy >= tiredEnergy &&
      stats.hunger <= 75 &&
      _random.nextDouble() < 0.3;

  void _start(PetStep next) {
    everyday = false;
    if (ball == Ball.carried && next.tag != StepTag.carry) {
      // 버릇으로 주인 앞에서 도는 중에 끊겼으면 이미 가져온 것이다.
      final home =
          next.tag == StepTag.drop ||
          (step.tag == StepTag.carry && step.behavior == Behavior.spin);
      _dropBall(home: home);
    }
    if (pottyUrge && next.tag != StepTag.urge && next.tag != StepTag.potty) {
      _cancelUrge();
    }
    if (next.tag == StepTag.pick) pickShown = true;
    if (next.tag == StepTag.meet && _cardCandidate != null) {
      pendingCard = _cardCandidate;
      _cardCandidate = null;
    }
    if (next.tag == StepTag.mimic) mimicGen++;
    if (next.tag == StepTag.stamp) _awardStamp();
    if (next.tag == StepTag.hand) _handReached(next);
    if (next.tag == StepTag.beg) _begAt = _clock();
    if (next.tag == StepTag.unearth) _background(_unearth());
    if (next.tag == StepTag.praise && _praisePending != null) {
      _praisable = (trick: _praisePending!, at: _clock());
      _praisePending = null;
    }
    if (replaying && next.tag != StepTag.cut) {
      // 다시보기 도중 다른 일(장소 가기·물건 받기·간식·반김)이 끼었다. 녹화 화면을 바로 걷는다.
      replaying = false;
      replayMoment = null;
      _replayQueue.clear();
    }
    if (next.tag == StepTag.cut && replaying && _replayQueue.isNotEmpty) {
      replayMoment = _replayQueue.removeAt(0);
    }
    step = next;
    _remaining = next.seconds;
    if (next.cue case final c?) _cue(c);
    if (next.thought case final t?) _say(t, 5);
    notifyListeners();
  }

  // 일기 재료(detail)에는 유저가 한 말이 들어갈 수 있어 사용 기록에는 종류만 남긴다.
  void _log(String kind, String detail, {DateTime? at}) {
    Telemetry.track('event', {'kind': kind});
    _background(_db.addEvent(kind, detail, at ?? _clock()));
  }

  /// 같은 날 같은 일은 앱을 다시 켜도 일기 재료에 한 번만 남긴다.
  /// DB를 읽는 사이에 같은 일이 또 생겨도 두 번 쓰지 않게 먼저 메모리에 표시한다.
  /// 내용이 달라도 그날 그 종류는 한 번만(홈캠처럼 비울 때마다 장면이 다른 것).
  Future<void> _logOncePerDay(String kind, String detail) async {
    final now = _clock();
    if (!_loggedOnce.add('${dayKey(petDate(now))} $kind')) return;
    if ((await _db.eventsOn(now)).any((e) => e.kind == kind)) return;
    _log(kind, detail);
  }

  Future<void> _logOnce(
    String kind,
    String detail, {
    bool perCalendarDay = false,
  }) async {
    final now = _clock();
    final calendar = perCalendarDay ? dayKey(now) : '';
    if (!_loggedOnce.add('${dayKey(petDate(now))} $calendar $kind $detail')) {
      return;
    }
    final today = await _db.eventsOn(now);
    if (today.any(
      (e) =>
          e.kind == kind &&
          e.detail == detail &&
          (!perCalendarDay || dayKey(e.at) == calendar),
    )) {
      return;
    }
    _log(kind, detail, at: now);
  }

  Map<String, Object?> _statsMap() => {
    'mood': stats.mood.round(),
    'hunger': stats.hunger.round(),
    'energy': stats.energy.round(),
    'affection': stats.affection.round(),
    'care': careScore.round(),
  };

  void _save(DateTime now) {
    _pet = _pet.copyWith(
      mood: stats.mood,
      hunger: stats.hunger,
      energy: stats.energy,
      affection: stats.affection,
      careScore: careScore,
      lastSeenAt: now,
      rhythm: Value(_rhythm.toJson()),
      activity: Value(traits.activity),
      attachment: Value(traits.attachment),
    );
    _background(_db.savePetState(_pet));
  }

  @override
  void dispose() {
    _disposed = true;
    _retryPhoto = null;
    unawaited(_cues.close());
    super.dispose();
  }
}

/// 공은 없거나, 강아지 입에 있거나, 던져져 굴러가는 중이거나, 바닥에 있어 던질 수 있다.
enum Ball { none, carried, thrown, ready }

enum TrickCommandOutcome { away, tired, missed, succeeded, learned }

enum TalkOutcome {
  ai,
  recordIssue,
  historyUnavailable,
  noBrain,
  failed,
  limited,
  crisis,
  command,
  ignored,
  away,

  /// 맡긴 동안 말을 걸었는데 펫이 유치원 낮잠 중이라 모른다.
  awayAsleep,
}

const _cctvThought = '어? 누가 보고 있나?';
const _missThought = '…? 문득 주인 생각';

class ReceiveResult {
  const ReceiveResult(
    this.item, {
    required this.count,
    required this.gift,
    required this.reaction,
    required this.source,
  });

  final Item item;

  /// 받은 뒤 도감에 있는 개수. 1이면 처음 찾은 것.
  final int count;
  final bool gift;
  final Reaction reaction;
  final FindSource source;
}

String _actionKo(PetAction a) => switch (a) {
  PetAction.happy => '꼬리를 흔들었다',
  PetAction.approach => '곁으로 다가갔다',
  PetAction.lieBeside => '옆에 엎드려 있었다',
  PetAction.sit => '가만히 바라봤다',
  PetAction.sulk => '조금 삐졌다',
  PetAction.sleep => '잠들었다',
  PetAction.play => '신나서 뛰어다녔다',
  PetAction.proposeWalk => '산책 가자고 졸랐다',
};

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

String _relativeDay(int days) => days <= 0
    ? '오늘'
    : days == 1
    ? '어제'
    : '$days일 전';

/// '앉아'를처럼 따옴표 뒤에 조사를 붙인다.
String _quoted(String word, String pair) =>
    "'$word'${josa(word, pair).substring(word.length)}";

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _weekday(DateTime t) =>
    const ['월', '화', '수', '목', '금', '토', '일'][t.weekday - 1];
