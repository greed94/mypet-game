import 'dart:async';
import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';

import 'brain/ai_config.dart';
import 'brain/firebase_brain.dart';
import 'data/database.dart';
import 'pet/pet_controller.dart';
import 'services/notifications.dart';
import 'services/sfx.dart';
import 'services/steps.dart';
import 'services/telemetry.dart';
import 'services/test_mode.dart';
import 'services/weather.dart';
import 'ui/c3/c3_theme.dart';
import 'ui/home_screen.dart';
import 'ui/app_startup.dart';
import 'ui/onboarding_screen.dart';

/// 플레이 스토어에서 받지 않은 테스트 APK는 Play Integrity를 통과하지 못해서, 콘솔에 등록한 디버그 토큰으로
/// 우리 앱임을 증명한다. secrets.json → --dart-define-from-file로만 넣고 스토어 빌드에는 넣지 않는다.
const _appCheckDebugToken = String.fromEnvironment(
  'MYPET_APPCHECK_DEBUG_TOKEN',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppStartup(load: _loadApp));
}

Future<Widget> _loadApp() async {
  unawaited(Sfx.init());
  // 디버그 전용: 몇 시간 비운 뒤 돌아온 상황(DEBUG_REWIND_HOURS)과
  // 밤에 낮 장면(DEBUG_HOUR)을 기다리지 않고 바로 확인하기 위한 옵션. 실제 펫 기록과 섞이지 않게 별도 DB를 쓴다.
  const rewindHours = int.fromEnvironment('DEBUG_REWIND_HOURS');
  const debugHour = int.fromEnvironment('DEBUG_HOUR', defaultValue: -1);
  var offset = Duration.zero;
  if (kDebugMode && debugHour >= 0) {
    final real = DateTime.now();
    offset = DateTime(
      real.year,
      real.month,
      real.day,
      debugHour,
      real.minute,
    ).difference(real);
  }
  // 테스트 빌드의 연습 모드(설정에서 켬): 연습 펫 DB를 쓰고, 그 펫의 시계만 앞으로 보낸다.
  final docs = (await getApplicationDocumentsDirectory()).path;
  final testMode = await TestMode.load(File('$docs/test_mode.json'));
  final debugTime = kDebugMode && (debugHour >= 0 || rewindHours > 0);
  // 디버그 시계는 따로 DB를 쓰니 연습 모드와 섞지 않는다.
  if (!testModeAvailable || debugTime) testMode.on = false;
  DateTime clock() => testMode.now().add(offset);

  var db = AppDatabase(
    driftDatabase(name: debugTime ? 'mypet_debug' : testMode.dbName),
  );
  try {
    // 연습 모드가 켜진 채인데 연습 펫이 없으면(파일만 남음) 처음 만들기 화면에 갇혀 끌 수가 없다. 진짜 펫으로 연다.
    if (testMode.on && !debugTime && await db.loadPet() == null) {
      await db.close();
      await testMode.select(false);
      db = AppDatabase(driftDatabase(name: testMode.dbName));
    }
    await Notifications.init();
    try {
      await Firebase.initializeApp();
      await FirebaseAppCheck.instance.activate(
        providerAndroid: _appCheckDebugToken.isEmpty
            ? const AndroidPlayIntegrityProvider()
            : const AndroidDebugProvider(debugToken: _appCheckDebugToken),
      );
    } catch (_) {
      // Firebase가 안 떠도 펫은 AI 없이 폰 안 반응으로 돈다.
    }
    await Telemetry.start();
    // 테스트 중 앱이 죽거나 화면이 깨지면 원인을 오류 보고에서 볼 수 있게 남긴다.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      Telemetry.recordFlutterError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      Telemetry.recordError(error, stack);
      return false;
    };

    var pet = await db.loadPet();
    Telemetry.track('app_start', {
      'has_pet': pet != null,
      'ai': Firebase.apps.isNotEmpty,
    });
    if (kDebugMode && rewindHours > 0 && pet != null) {
      pet = pet.copyWith(
        lastSeenAt: clock().subtract(const Duration(hours: rewindHours)),
      );
    }

    return MypetApp(
      db: db,
      initialPet: pet,
      systemPrompt: await rootBundle.loadString(
        'assets/brain/pet_system_prompt.md',
      ),
      diaryPrompt: await rootBundle.loadString('assets/brain/diary_prompt.md'),
      ai: await loadAiConfig(),
      clock: clock,
      testMode: testMode,
      docs: docs,
      initialFirstMeeting: pet != null && await db.beginFirstMeeting(clock()),
    );
  } catch (_) {
    // 열지 못한 연결만 정리한다. 기록 파일과 연습 모드 상태를 초기화하지 않는다.
    try {
      await db.close();
    } catch (_) {}
    rethrow;
  }
}

/// 연습 모드는 테스트 빌드(사용 기록 표시가 있는 빌드)와 디버그 빌드에서만 보인다. 스토어 빌드엔 없다.
bool get testModeAvailable => Telemetry.buildEnabled || kDebugMode;

class MypetApp extends StatefulWidget {
  const MypetApp({
    super.key,
    required this.db,
    required this.initialPet,
    this.initialFirstMeeting = false,
    required this.systemPrompt,
    required this.diaryPrompt,
    required this.ai,
    required this.clock,
    required this.testMode,
    required this.docs,
  });

  final AppDatabase db;
  final Pet? initialPet;
  final bool initialFirstMeeting;
  final String systemPrompt;
  final String diaryPrompt;
  final AiConfig? ai;
  final DateTime Function() clock;
  final TestMode testMode;

  /// 앱 문서 폴더. DB 파일이 여기 있다.
  final String docs;

  @override
  State<MypetApp> createState() => _MypetAppState();
}

class _MypetAppState extends State<MypetApp> {
  final _weather = WeatherService();
  PetController? _controller;
  bool _resetting = false;
  final _messages = GlobalKey<ScaffoldMessengerState>();
  final _navigation = GlobalKey<NavigatorState>();
  late AppDatabase _db = widget.db;

  @override
  void initState() {
    super.initState();
    final pet = widget.initialPet;
    if (pet != null) {
      _controller = _make(pet)..wake(firstMeeting: widget.initialFirstMeeting);
    }
  }

  PetController _make(Pet pet) => PetController(
    _db,
    pet,
    systemPrompt: widget.systemPrompt.replaceAll('{name}', pet.name),
    diaryPrompt: widget.diaryPrompt.replaceAll('{name}', pet.name),
    brain: widget.ai?.toBrain() ?? FirebaseBrain(),
    readStepTotal: StepCounter.readTotal,
    weatherService: _weather,
    clock: widget.clock,
  );

  /// 연습 모드에선 부르지 않는다(설정에서 버튼을 숨김). 알림 취소가 진짜 펫 알림까지 지운다.
  Future<void> _reset() async {
    final old = _controller;
    if (_resetting || _switching || widget.testMode.on || old == null) return;
    setState(() => _resetting = true);
    try {
      await old.prepareReset();
      await _db.resetAll();
    } catch (_) {
      old.cancelReset();
      if (mounted) {
        setState(() => _resetting = false);
        _messages.currentState?.showSnackBar(
          const SnackBar(
            content: Text('기록을 지우지 못했어요. 기존 아이와 기록은 그대로예요. 다시 시도해 주세요.'),
          ),
        );
      }
      return;
    }
    old.dispose();
    // 알림은 DB 삭제 성공 뒤에 정리한다. 알림 플러그인 실패가 새 시작을 막지 않는다.
    try {
      await Notifications.cancelAll();
    } catch (_) {
      Telemetry.track('reset_notification_error');
    }
    if (!mounted) return;
    setState(() {
      _controller = null;
      _resetting = false;
    });
  }

  /// 연습 모드를 켜거나 끈다. 켤 땐 지금 펫을 복사한 연습 펫으로, 끌 땐 진짜 펫으로 바꿔 다시 연다.
  bool _switching = false;
  Future<void>? _jumping;

  Future<void> _setTestMode(bool on) async {
    final mode = widget.testMode;
    if (on == mode.on || _switching || _resetting) return;
    setState(() => _switching = true);
    FocusManager.instance.primaryFocus?.unfocus();
    _navigation.currentState?.popUntil((route) => route.isFirst);
    try {
      // 시간 저장 뒤의 wake까지 끝내야 이전 펫을 닫거나 모드 파일을 덮어쓸 수 있다.
      await _jumping?.then((_) {}, onError: (_) {});
      if (!mounted) return;
      await _switchTo(on);
    } catch (_) {
      if (mounted) {
        _messages.currentState?.showSnackBar(
          const SnackBar(content: Text('펫을 바꾸지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _switchTo(bool on) async {
    final mode = widget.testMode;
    final old = _controller;
    final oldDb = _db;
    AppDatabase? nextDb;
    try {
      await old?.prepareReset();
      if (old != null && old.unsavedWalkCount > 0) {
        old.cancelReset();
        if (!await old.retryWalkRecords()) throw StateError('산책 기록 저장 대기');
        await old.prepareReset();
      }
      if (!mounted) return;
      if (on) {
        await TestMode.copyForPractice(
          oldDb,
          '${widget.docs}/${TestMode.testDb}.sqlite',
        );
      }
      final db = nextDb = AppDatabase(
        driftDatabase(name: on ? TestMode.testDb : TestMode.realDb),
      );
      final pet = await db.loadPet();
      if (!mounted) return;
      // 복사와 열기에 성공한 뒤에만 다음 실행이 사용할 모드를 저장한다.
      await mode.select(on);
      if (!mounted) return;
      setState(() {
        _db = db;
        _controller = pet == null ? null : (_make(pet)..wake());
      });
      nextDb = null;
    } finally {
      if (identical(_db, oldDb)) old?.cancelReset();
      await nextDb?.close();
    }
    Telemetry.track('test_mode', {'on': on});
    old?.dispose();
    try {
      await oldDb.close();
    } catch (_) {
      // 새 펫과 파일은 이미 전환됐다. 이전 연결 정리 실패만 기록한다.
      Telemetry.track('test_mode_previous_close_error');
    }
  }

  Future<void> _jump(Duration d) async {
    if (_switching || _jumping != null || _resetting) return;
    final c = _controller;
    if (c == null) return;
    final jumping = widget.testMode.jump(c, d);
    _jumping = jumping;
    try {
      await jumping;
    } finally {
      _jumping = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final busy = _resetting || _switching;
    return MaterialApp(
      title: '마이펫',
      scaffoldMessengerKey: _messages,
      navigatorKey: _navigation,
      debugShowCheckedModeBanner: false,
      theme: buildC3Theme(),
      // C3 화면은 스티커·게이지 크기가 고정이라 시스템 글자 확대에서 넘친다. 출시 전 글자 확대 지원을 다시 본다.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: c3SystemBars,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeFocus(
                excluding: busy,
                child: ExcludeSemantics(
                  excluding: busy,
                  child: AbsorbPointer(absorbing: busy, child: child!),
                ),
              ),
              if (busy)
                Material(
                  color: C3Colors.paper,
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: C3Colors.stamp,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _resetting ? '기록을 정리하고 있어요.' : '펫을 불러오고 있어요.',
                            style: C3Text.body,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      home: PopScope(
        canPop: !busy,
        child: c == null
            ? OnboardingScreen(
                db: _db,
                weather: _weather,
                clock: widget.clock,
                onCreated: (pet) async {
                  final meeting = await _db.beginFirstMeeting(widget.clock());
                  if (!mounted) return;
                  setState(
                    () => _controller = _make(pet)..wake(firstMeeting: meeting),
                  );
                },
              )
            : HomeScreen(
                key: ValueKey(c),
                controller: c,
                db: _db,
                onReset: _reset,
                testMode: testModeAvailable ? widget.testMode : null,
                onTestMode: _setTestMode,
                onJump: _jump,
              ),
      ),
    );
  }
}
