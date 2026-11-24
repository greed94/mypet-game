import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pet/josa.dart';
import '../brain/ai_config.dart';
import '../brain/firebase_brain.dart';
import '../brain/pet_brain.dart';
import '../art/photo_art.dart';
import 'photo_framing_screen.dart';
import '../pet/pet_controller.dart';
import '../services/gallery_photo.dart';
import '../services/notifications.dart';
import '../services/sfx.dart';
import '../services/telemetry.dart';
import '../services/test_mode.dart';
import '../services/weather.dart';
import 'app_info.dart';
import 'keep_words.dart';
import 'shape_picker.dart';

enum _SettingsFeedback { photo, ai, region }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.onReset,
    this.testMode,
    this.onTestMode,
    this.effects,
  });

  final PetController controller;
  final Sfx? effects;
  final Future<void> Function() onReset;

  /// 테스트 빌드에서만 있다.
  final TestMode? testMode;
  final Future<void> Function(bool on)? onTestMode;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _regionInput = TextEditingController();

  bool get _practicing => widget.testMode?.on ?? false;

  final _url = TextEditingController();
  final _model = TextEditingController();
  final _key = TextEditingController();
  final _feedback = <_SettingsFeedback, String>{};
  final _feedbackKeys = {
    for (final area in _SettingsFeedback.values) area: GlobalKey(),
  };
  bool _busy = false;
  bool _photoBusy = false;
  EditablePetPhoto? _editablePhoto;
  bool _telemetryOff = false;

  @override
  void initState() {
    super.initState();
    Telemetry.isUserOff().then((off) {
      if (mounted) setState(() => _telemetryOff = off);
    });
    final b = widget.controller.brain;
    if (b is AiBrain) {
      _url.text = b.baseUrl;
      _model.text = b.model;
    }
  }

  @override
  void dispose() {
    _regionInput.dispose();
    _url.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  void _showFeedback(_SettingsFeedback area, String? message) {
    if (!mounted) return;
    setState(() {
      if (message == null) {
        _feedback.remove(area);
      } else {
        _feedback[area] = message;
      }
    });
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _feedback[area] != message) return;
      final target = _feedbackKeys[area]!.currentContext;
      if (target != null) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            alignment: 0.5,
            duration: const Duration(milliseconds: 180),
          ),
        );
      }
    });
  }

  Widget _feedbackFor(_SettingsFeedback area) {
    final message = _feedback[area];
    if (message == null) return const SizedBox.shrink();
    return Padding(
      key: _feedbackKeys[area],
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(liveRegion: true, child: SelectableText(message)),
    );
  }

  void _preset(String url, String model, [String key = '']) {
    setState(() {
      _url.text = url;
      _model.text = model;
      _key.text = key;
      _feedback.remove(_SettingsFeedback.ai);
    });
  }

  Future<void> _saveAndCheck() async {
    if (!mounted || _busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final current = widget.controller.brain;
    final url = _url.text.trim();
    final typed = _key.text.trim();
    // 키 칸을 비우면 지금 키를 쓰되, 같은 서버일 때만. 다른 서버로 키가 새지 않게 한다.
    final sameHost =
        current is AiBrain &&
        Uri.tryParse(url)?.host == Uri.tryParse(current.baseUrl)?.host;
    final config = AiConfig(
      url,
      _model.text.trim(),
      typed.isNotEmpty ? typed : (sameHost ? current.apiKey : ''),
    );
    if (!config.complete) {
      _showFeedback(
        _SettingsFeedback.ai,
        '서버 주소, 모델, 키를 모두 넣어 주세요. 서버를 바꾸면 키도 다시 넣어야 해요.',
      );
      return;
    }
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.host.isEmpty || !parsed.isScheme('https')) {
      _showFeedback(_SettingsFeedback.ai, '서버 주소는 https://로 시작해야 해요.');
      return;
    }
    setState(() {
      _busy = true;
      _feedback.remove(_SettingsFeedback.ai);
    });
    final c = widget.controller;
    final brain = config.toBrain();
    var result = '연결 실패: 알 수 없는 오류';
    try {
      final d = await brain.decide(
        c.systemPrompt,
        userTurn(c.stats, const [], '안녕'),
      );
      if (!mounted) return;
      _key.clear();
      Telemetry.track('ai_check', {'ok': true, 'provider': 'custom'});
      result = '연결됐어요. ${c.pet.name}의 속마음: "${d.thought}"';
      try {
        await saveAiConfig(
          config,
          onApply: () {
            if (!c.isDisposed) c.brain = brain;
          },
        );
      } on PlatformException catch (e) {
        result = '연결은 됐지만 설정을 저장하지 못했어요(${e.message}). 앱을 다시 켜면 다시 넣어야 해요.';
      }
    } on BrainError catch (e) {
      Telemetry.track('ai_check', {
        'ok': false,
        'provider': 'custom',
        'error': e.kind.code,
      });
      result = '연결 실패: ${e.message}';
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _showFeedback(_SettingsFeedback.ai, result);
      }
    }
  }

  Future<void> _reset() async {
    if (!mounted || _busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _feedback.remove(_SettingsFeedback.ai);
    });
    Telemetry.track('ai_reset');
    final c = widget.controller;
    String? result;
    try {
      await clearAiConfig(
        onCleared: () {
          if (!c.isDisposed) c.brain = FirebaseBrain();
        },
      );
      if (!mounted) return;
      _key.clear();
      result = '저장한 설정을 지우고 기본 AI(Google Gemini)로 돌아갔어요.';
    } on PlatformException catch (e) {
      result = '설정을 지우지 못했어요: ${e.message}';
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _showFeedback(_SettingsFeedback.ai, result);
      }
    }
  }

  Future<EditablePetPhoto?> _chooseFace(
    PetController c,
    bool Function() active,
  ) async {
    final bytes = await pickPetPhotoBytes(active);
    if (bytes == null || !active()) return null;
    final source = await compute(preparePetPhoto, bytes);
    if (!active()) return null;
    if (source == null) {
      _showFeedback(_SettingsFeedback.photo, '사진을 읽지 못했어요. 다른 사진으로 해볼까요?');
      return null;
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return null;
    final choice = await editPetPhoto(
      context,
      source,
      centerPetPhoto(source).selection,
      shape: c.pet.shape,
      stage: c.pet.stage,
      accent: c.pet.accent,
      confirmLabel: '이 얼굴로 바꾸기',
    );
    if (choice == null || !active()) return null;
    return (source: source, selection: choice);
  }

  /// 확정 전의 사진은 화면이 맡고, 확정 후의 저장과 재시도는 해당 펫이 맡는다.
  Future<void> _recolorFromPhoto({
    EditablePetPhoto? edited,
    PetPhotoLook? retry,
  }) async {
    final c = widget.controller;
    if (!mounted ||
        _photoBusy ||
        c.savingPhoto ||
        c.isDisposed ||
        c.isResetting) {
      return;
    }
    bool active() =>
        mounted &&
        identical(widget.controller, c) &&
        !c.isDisposed &&
        !c.isResetting;
    setState(() => _photoBusy = true);
    _showFeedback(_SettingsFeedback.photo, null);
    try {
      EditablePetPhoto? photo = edited;
      if (retry == null) {
        if (edited != null &&
            !identical(_editablePhoto?.source.pixels, edited.source.pixels)) {
          return;
        }
        photo ??= await _chooseFace(c, active);
        if (photo == null || !active()) return;
      } else {
        if (!identical(c.retryPhoto?.portrait, retry.portrait)) return;
        if (identical(
          _editablePhoto?.selection.look.portrait,
          retry.portrait,
        )) {
          photo = _editablePhoto;
        }
      }
      final saved = await c.saveConfirmedPhoto(retry ?? photo!.selection.look);
      if (!active()) return;
      setState(() => _editablePhoto = photo);
      _showFeedback(
        _SettingsFeedback.photo,
        saved
            ? (edited == null && retry == null
                  ? '사진에서 뽑은 색으로 다시 칠했어요.'
                  : '고른 얼굴로 초상화와 털색을 바꿨어요.')
            : '새 얼굴을 저장하지 못했어요. 다시 저장할 수 있어요.',
      );
    } on PlatformException {
      if (active()) {
        _showFeedback(_SettingsFeedback.photo, '사진을 열지 못했어요. 다시 골라 볼까요?');
      }
    } on FileSystemException {
      if (active()) {
        _showFeedback(_SettingsFeedback.photo, '사진을 읽거나 저장하지 못했어요. 다시 해볼까요?');
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Widget _photoActions(PetController c) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final busy = _photoBusy || c.savingPhoto;
      final retry = c.retryPhoto;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: busy ? null : _recolorFromPhoto,
            icon: const Icon(Icons.photo_outlined),
            label: const Text('사진으로 색 다시 뽑기'),
          ),
          if (_editablePhoto case final photo?)
            PhotoFrameButton(
              shape: c.pet.shape,
              stage: c.pet.stage,
              accent: c.pet.accent,
              confirmLabel: '이 얼굴로 바꾸기',
              photo: photo,
              onApply: busy ? null : (next) => _recolorFromPhoto(edited: next),
            ),
          if (c.savingPhoto)
            Semantics(liveRegion: true, child: const Text('선택한 얼굴을 저장하고 있어요…')),
          if (retry != null && !c.savingPhoto) ...[
            if (_feedback[_SettingsFeedback.photo] == null)
              const Text('새 얼굴을 저장하지 못했어요.'),
            TextButton.icon(
              onPressed: busy ? null : () => _recolorFromPhoto(retry: retry),
              icon: const Icon(Icons.refresh),
              label: const Text('이 얼굴 다시 저장'),
            ),
          ],
        ],
      );
    },
  );

  /// 온보딩에서 건너뛴 동네를 여기서 넣거나 바꾼다.
  Future<void> _pickRegion() async {
    _showFeedback(_SettingsFeedback.region, null);
    final c = widget.controller;
    final input = _regionInput..clear();
    var results = <Place>[];
    var searching = false, searched = false;
    // 느린 인터넷 검색이 나중에 끝나 새 검색 결과를 덮지 않게 번호를 매긴다.
    var gen = 0;
    final chosen = await showDialog<Place>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          Future<void> search() async {
            final mine = ++gen;
            setDialog(() => searching = true);
            final found = await c.searchRegion(input.text);
            if (!context.mounted || mine != gen) return;
            setDialog(() {
              results = found;
              searching = false;
              searched = true;
            });
          }

          return AlertDialog(
            title: const Text('어디에 살아요?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: input,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => search(),
                    decoration: InputDecoration(
                      hintText: '예: 서울, 관악구, 수원',
                      suffixIcon: IconButton(
                        onPressed: searching ? null : search,
                        icon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  for (final p in results)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.label),
                      onTap: () => Navigator.pop(context, p),
                    ),
                  if (searched && !searching && results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('찾지 못했어요. 시·구 이름으로 다시 해볼까요?'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
            ],
          );
        },
      ),
    );
    if (chosen == null) return;
    await c.setRegion(chosen);
    _showFeedback(_SettingsFeedback.region, '이제 ${chosen.label} 날씨를 봐요.');
  }

  Future<void> _enableNotifications() async {
    final name = widget.controller.pet.name;
    final ok = await Notifications.requestPermission();
    Telemetry.track('notifications', {'granted': ok, 'from': 'settings'});
    if (ok) await Notifications.scheduleDaily(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '아침 8시 반, 저녁 9시에 ${josa(name, '이/가')} 불러요.'
              : '알림 권한이 없어요. 폰 설정에서 켜 주세요.',
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('처음부터 다시 만들까요?'),
        content: Text(keepWords('지금 아이와 기억, 일기가 모두 지워져요. 되돌릴 수 없어요.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지우고 다시 만들기'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    Telemetry.track('pet_reset');
    Navigator.pop(context);
    await widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    final effects = widget.effects ?? appSfx;
    final b = widget.controller.brain;
    final name = widget.controller.pet.name;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('모습', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(keepWords('우리 아이와 가장 비슷한 모양을 골라요. 기억과 일기는 그대로예요.')),
            const SizedBox(height: 10),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final pet = widget.controller.pet;
                return ShapePicker(
                  colors: PetColors(
                    main: pet.furMain,
                    second: pet.furSecond,
                    marking: pet.marking,
                  ),
                  selected: pet.shape,
                  stage: pet.stage,
                  onSelect: widget.controller.changeShape,
                );
              },
            ),
            const SizedBox(height: 12),
            _photoActions(widget.controller),
            _feedbackFor(_SettingsFeedback.photo),
            const Divider(height: 32),
            Text('AI', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              keepWords(
                '${josa(name, '이/가')} 속마음과 일기는 AI가 써요. 기본은 Google Gemini예요. '
                '다른 AI 서비스(Groq 등)를 쓰려면 주소, 모델, 키를 넣어요. '
                '키는 이 폰 안에만 암호화해서 저장돼요.',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              b == null ? '지금은 AI 없이 폰 안 반응만 해요.' : '지금 연결: ${b.label}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Groq'),
                  onPressed: () =>
                      _preset(AiConfig.groqUrl, AiConfig.groqModel),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '서버 주소',
                hintText: 'https://…/v1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _model,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '모델',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: '키',
                hintText: b is AiBrain ? '비워 두면 지금 키 그대로' : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _saveAndCheck,
              child: Text(_busy ? '확인 중…' : '저장하고 연결 확인'),
            ),
            TextButton(
              onPressed: _busy ? null : _reset,
              child: const Text('저장한 설정 지우기'),
            ),
            _feedbackFor(_SettingsFeedback.ai),
            if (Telemetry.buildEnabled) ...[
              const Divider(height: 32),
              Text('테스트 기록', style: Theme.of(context).textTheme.titleSmall),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('사용 기록 보내기'),
                subtitle: Text(
                  keepWords(
                    '테스트 빌드에서는 버튼, 화면 이동, 펫 상태와 오류를 Firebase로 보내요. 최근 놀이 입력과 결과는 이 기기에도 저장하며, 끄면 앱에 보관한 진단 파일을 지워요. 이 사용 기록에는 대화와 일기 본문이 포함되지 않아요.',
                  ),
                ),
                value: !_telemetryOff,
                onChanged: (on) async {
                  await Telemetry.setUserOff(!on);
                  if (mounted) setState(() => _telemetryOff = !on);
                },
              ),
            ],
            const Divider(height: 32),
            Text('소리', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(keepWords('무음·진동 모드에서는 소리 없이 진동만 해요.')),
            ListenableBuilder(
              listenable: effects,
              builder: (context, _) => Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('소리'),
                    value: effects.soundOn,
                    onChanged: (on) {
                      unawaited(effects.setSoundOn(on));
                      Telemetry.track('sound', {'on': on});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('진동'),
                    value: effects.hapticOn,
                    onChanged: (on) {
                      unawaited(effects.setHapticOn(on));
                      Telemetry.track('haptic', {'on': on});
                    },
                  ),
                  if (effects.needsSave) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        keepWords(
                          '이번에는 설정을 저장하지 못했어요. 지금 선택한 소리와 진동은 앱을 닫을 때까지 적용돼요.',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => unawaited(effects.retrySave()),
                      child: const Text('소리·진동 설정 다시 저장'),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 32),
            Text('알림', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            // 연습 펫으로는 알림을 다시 잡지 않는다(진짜 펫 알림을 연습 펫 이름으로 덮는다).
            if (!_practicing)
              OutlinedButton.icon(
                onPressed: _enableNotifications,
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('아침·저녁 알림 켜기'),
              )
            else
              Text(keepWords('연습 펫일 땐 알림을 바꾸지 않아요.')),
            const Divider(height: 32),
            Text('동네', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              keepWords(
                widget.controller.pet.regionName == null
                    ? '아직 동네가 없어요. 동네를 알면 비 오는 날 창밖을 보고, 더운 날 늘어져 있어요.'
                    : '지금 동네: ${widget.controller.pet.regionName}',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickRegion,
              icon: const Icon(Icons.place_outlined),
              label: Text(
                widget.controller.pet.regionName == null ? '동네 넣기' : '동네 바꾸기',
              ),
            ),
            _feedbackFor(_SettingsFeedback.region),
            const SizedBox(height: 4),
            Text(
              '전국 시·군·구 목록 © OpenStreetMap 기여자',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.testMode case final mode?) ...[
              const Divider(height: 32),
              Text('테스트 모드', style: Theme.of(context).textTheme.titleSmall),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('연습 펫으로 시간 보내기'),
                subtitle: Text(
                  keepWords(
                    mode.on
                        ? '지금은 연습 펫이에요(${aheadLabel(mode.offset)}). 끄면 진짜 펫으로 돌아가요.'
                        : '지금 펫을 복사한 연습 펫으로 바꿔요. 시간을 앞으로 보내도 진짜 펫 기록과 시계는 그대로예요.',
                  ),
                ),
                value: mode.on,
                onChanged: (on) {
                  // 바꾸면 펫이 새로 열려서 이 화면이 들고 있는 펫은 옛 펫이 된다. 먼저 닫는다.
                  Navigator.of(context).pop();
                  widget.onTestMode?.call(on);
                },
              ),
            ],
            const Divider(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AppInfoScreen()),
              ),
              icon: const Icon(Icons.info_outline),
              label: const Text('앱 정보와 출처'),
            ),
            const Divider(height: 32),
            Text('펫', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            // 연습 펫을 지우면 연습 모드를 끌 길이 없는 처음 화면에 갇히고, 알림 취소가 진짜 펫 알림까지 지운다.
            if (!_practicing)
              OutlinedButton.icon(
                onPressed: _confirmReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('처음부터 다시 만들기'),
              )
            else
              Text(keepWords('연습 펫은 위 테스트 모드를 끄면 사라져요.')),
          ],
        ),
      ),
    );
  }
}
