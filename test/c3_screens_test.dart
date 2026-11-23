import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/shapes.dart';
import 'package:mypet/pet/spots.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/pet/tricks.dart';
import 'package:mypet/services/weather.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/c3/memo_input.dart';
import 'package:mypet/ui/c3/tape.dart';
import 'package:mypet/ui/c3/sticker_button.dart';
import 'package:mypet/ui/c3/sticker_card.dart';
import 'package:mypet/ui/friends.dart';
import 'package:mypet/ui/lesson_picker.dart';
import 'package:mypet/ui/checkup_card.dart';
import 'package:mypet/pet/checkup.dart';
import 'package:mypet/ui/collection_screen.dart';
import 'package:mypet/ui/diary_screen.dart';
import 'package:mypet/ui/kinder_photo_card.dart';
import 'package:mypet/ui/walk_card.dart';
import 'package:mypet/pet/walk_log.dart';
import 'package:mypet/pet/kinder_photo.dart';
import 'package:mypet/ui/item_icon.dart';
import 'package:mypet/ui/keep_words.dart';
import 'package:mypet/ui/known_dog_screen.dart';
import 'package:mypet/ui/shape_picker.dart';
import 'package:mypet/ui/trick_notebook.dart';
import 'package:mypet/art/photo_art.dart';
import 'package:mypet/ui/onboarding_screen.dart';
import 'package:mypet/ui/place_card.dart';
import 'package:mypet/ui/play_tray.dart';
import 'package:mypet/ui/settings_screen.dart';
import 'package:mypet/ui/time_sheet.dart';
import 'package:mypet/ui/town_map.dart';

const _shotKey = ValueKey('screen-shot');

Future<void> _loadFonts() async {
  const families = {
    C3Fonts.jua: ['Jua-Regular.ttf'],
    C3Fonts.gowun: ['GowunDodum-Regular.ttf'],
    C3Fonts.gaegu: ['Gaegu-Regular.ttf', 'Gaegu-Bold.ttf'],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

/// 테스트 폰(360×879dp)에서 예외·넘침 없이 그려지는지 보고, 눈으로 확인하게 shots/ 에 남긴다.
/// 강아지 얼굴·모양 그림은 에셋을 읽고 칠하는 진짜 비동기라 몇 번 나눠 기다린다(한 번이면 빈칸으로 찍혔다).
Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpAndShot(
  WidgetTester tester,
  Widget screen,
  String name,
) async {
  tester.view.physicalSize = const Size(1080, 2637);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 84, bottom: 144);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildC3Theme(),
      home: RepaintBoundary(key: _shotKey, child: screen),
    ),
  );
  await _settleImages(tester);
  expect(tester.takeException(), isNull);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shotKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    Directory('shots').createSync();
    File('shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);
  setUp(() {
    GuestFace.resetCache();
    ShapePicker.resetCache();
    ItemIcon.resetCache();
    KinderPhotoCard.resetCache();
  });

  testWidgets('일기: 유치원 오늘의 한 장이 그날 일기 아래에 붙는다', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final pet = await tester.runAsync(() async {
      final pet = await db.createPet(
        name: '노을',
        stage: PetStage.adult,
        furMain: 0xFFB5582E,
        furSecond: 0xFFF5EDE2,
        marking: 0xFF8A3A1A,
        now: DateTime(2026, 9, 26),
      );
      await db.addDiary(
        '2026-10-05',
        '아침에 주인이 유치원에 맡기고 갔다. 낮에 유치원에서 놀다가 문득 주인 생각이 났다. '
            '저녁에 유치원에서 친구들이랑 놀다가 유치원 버스를 타고 집에 왔다.',
        DateTime(2026, 10, 6),
        byAi: false,
      );
      await db.addDiary('2026-10-04', '주인이랑 공놀이를 했다.', DateTime(2026, 10, 5));
      await db.addKinderPhoto(
        KinderPhotosCompanion.insert(
          day: '2026-10-05',
          scene: 'lesson',
          friends: 'bami,mandu',
          stage: PetStage.adult,
          trick: const Value('sit'),
        ),
      );
      return pet;
    });
    final c = PetController(db, pet!, random: Random(1));
    await _pumpAndShot(
      tester,
      Scaffold(
        body: SafeArea(
          child: DiaryScreen(controller: c, db: db),
        ),
      ),
      'screen_diary_photo',
    );
    expect(find.text("유치원 · '앉아' 수업"), findsOneWidget);
    expect(find.byType(KinderPhotoCard), findsOneWidget);
  });

  testWidgets('산책 지도: 길 낙서와 킁킁 자리 셋이 다이얼로그 폭에 들어간다', (tester) async {
    final start = DateTime(2026, 10, 5, 18, 20);
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: StickerCard(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
              child: WalkMap(
                startedAt: start,
                spots: walkSpots(start, 5, rain: true),
                summary: '23분 · 2140걸음 · 뭔가 물고 왔어요',
              ),
            ),
          ),
        ),
      ),
      'screen_walk_card',
    );
    expect(find.textContaining('물웅덩이'), findsOneWidget);
  });

  testWidgets('유치원 사진: 장면 다섯이 폴라로이드 안에 그려진다', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final pet = await tester.runAsync(
      () => db.createPet(
        name: '노을',
        stage: PetStage.puppy,
        furMain: 0xFFB5582E,
        furSecond: 0xFFF5EDE2,
        marking: 0xFF8A3A1A,
        now: DateTime(2026, 9, 26),
      ),
    );
    await _pumpAndShot(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              for (final (i, s) in KinderScene.values.indexed) ...[
                KinderPhotoCard(
                  photo: KinderPhotoRow(
                    day: '2026-10-0$i',
                    scene: s.name,
                    friends: i.isEven ? 'kong,duri' : 'hodu,bami',
                    stage: i < 3 ? PetStage.puppy : PetStage.adult,
                    trick: s == KinderScene.lesson ? 'spin' : null,
                  ),
                  pet: pet!,
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
      'screen_kinder_photos',
    );
    expect(find.text('유치원 · 낮잠 시간'), findsOneWidget);
    expect(find.text("유치원 · '돌아' 수업"), findsOneWidget);
  });

  testWidgets('온보딩 첫 장', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _pumpAndShot(
      tester,
      OnboardingScreen(
        db: db,
        weather: WeatherService(),
        onCreated: (_) async {},
      ),
      'screen_onboarding',
    );
  });

  testWidgets('온보딩에서 색을 고르면 그 색으로 칠한 모양들이 뜬다', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _pumpAndShot(
      tester,
      OnboardingScreen(
        db: db,
        weather: WeatherService(),
        onCreated: (_) async {},
      ),
      'screen_onboarding_blank',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '갈색'));
    await _settleImages(tester);
    for (final shape in dogShapes) {
      expect(
        find.text(shape.examples),
        shape.id == 'noeul' ? findsNothing : findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_shotKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File(
        'shots/screen_onboarding_shapes.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
    });
  });

  testWidgets('설정', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final pet = await tester.runAsync(
      () => db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: DateTime(2026, 9, 26),
      ),
    );
    final c = PetController(db, pet!, random: Random(1));
    await _pumpAndShot(
      tester,
      SettingsScreen(controller: c, onReset: () async {}),
      'screen_settings',
    );
  });

  testWidgets('동네 지도: 장소 여섯이 카드 안에 들어간다', (tester) async {
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StickerCard(
              padding: const EdgeInsets.all(14),
              child: AspectRatio(
                aspectRatio: 1,
                child: TownMap(onPick: (_) {}, wish: Spot.cafe),
              ),
            ),
          ),
        ),
      ),
      'screen_town_map',
    );
    for (final s in Spot.values) {
      expect(find.text(s.label), findsOneWidget);
    }
  });

  testWidgets('시간 보내기: 버튼 열두 개가 폰 폭에 들어간다', (tester) async {
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) =>
                      TimeSheet(now: DateTime(2026, 10, 5, 16, 20)),
                ),
              ),
            ],
          ),
        ),
      ),
      'screen_time_sheet',
    );
    expect(find.byType(ActionChip), findsNWidgets(12));
    expect(find.textContaining(keepWords('16:20')), findsOneWidget);
  });

  testWidgets('행동 줄: 간식까지 넷이어도 폰 폭에 들어가고 입력창 테이프가 첫 글자를 덮지 않는다', (
    tester,
  ) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    Widget sticker(String cut, String icon, String label) => StickerButton(
      cut: cut,
      icon: icon,
      label: label,
      width: 80,
      onTap: () {},
    );
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: SizedBox(
                height: 88,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    sticker('bowl', 'bowl', '밥 주기'),
                    sticker('ball', 'ball', '놀아주기'),
                    sticker('tree', 'tree', '산책 가기'),
                    sticker('box', 'bone', '간식 3'),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: SizedBox(
                height: 56,
                child: MemoInput(controller: input, hint: '노을에게 말 걸기…'),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
      'screen_action_row',
    );
    final label = tester.getRect(find.text('밥 주기'));
    final tape = tester.getRect(find.byType(Tape).last);
    expect(label.overlaps(tape), isFalse, reason: 'label $label tape $tape');
  });

  testWidgets('아는 강아지 카드: 이름을 비우면 저장 버튼이 꺼진다', (tester) async {
    final input = TextEditingController(text: '토토');
    addTearDown(input.dispose);
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: StickerCard(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
              child: FriendCard(
                guest: knownGuest(
                  id: 'known_1_0',
                  shape: 'shiba',
                  main: 0xFF3A3230,
                  second: 0xFF8C7B72,
                  marking: 0xFF3A3230,
                ),
                friendship: const Friendship(name: '토토'),
                input: input,
                nameRequired: true,
                onSave: () {},
                onClose: () {},
                onEdit: () {},
              ),
            ),
          ),
        ),
      ),
      'screen_known_friend_card',
    );
    final save = find.widgetWithText(FilledButton, '저장');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(find.text('아직 카페에서 못 만났어요'), findsOneWidget);
    expect(find.text('모습 고치기'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  ');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('친구 카드: 얼굴·사이 네 칸·이름 칸이 다이얼로그 폭에 들어간다', (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: StickerCard(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
              child: FriendCard(
                guest: cafeRegulars.first,
                friendship: const Friendship(
                  bond: Bond.play,
                  days: 3,
                  lastDay: '2026-10-05',
                ),
                input: input,
                onSave: () {},
                onClose: () {},
                share: '블루베리 젤리',
                onShare: () {},
              ),
            ),
          ),
        ),
      ),
      'screen_friend_card',
    );
    expect(find.text('카페에서 3번 만났어요'), findsOneWidget);
    expect(find.text('단짝'), findsOneWidget);
    expect(find.text('블루베리 젤리를 나눠 주기'), findsOneWidget);
  });

  testWidgets('오늘 수업: 개인기 칩과 자유 놀이가 다이얼로그 폭에 들어간다', (tester) async {
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: StickerCard(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
              child: LessonPicker(
                tricks: const {
                  Trick.sit: TrickProgress(attempts: 5, successes: 3, days: 2),
                },
                onPick: (_) {},
              ),
            ),
          ),
        ),
      ),
      'screen_lesson_picker',
    );
    expect(find.text('앉아 · 복습'), findsOneWidget);
    expect(find.text('자유 놀이'), findsOneWidget);
  });

  testWidgets('건강 수첩: 일곱 줄이 다이얼로그 폭에 들어간다', (tester) async {
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: StickerCard(
              child: CheckupCard(
                record: CheckupRecord(
                  at: DateTime(2026, 10, 5),
                  weight: 28.4,
                  previousWeight: 27.9,
                  temperature: 38.6,
                  shots: 2,
                  puppy: true,
                ),
              ),
            ),
          ),
        ),
      ),
      'screen_checkup',
    );
    expect(find.text('28.4kg (+0.5kg)'), findsOneWidget);
    expect(find.text('2/3차'), findsOneWidget);
  });

  testWidgets('장소 카드: 버튼이 둘이어도 폰 폭에서 넘치지 않는다', (tester) async {
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PlaceCard(
              tape: C3Colors.tapePink,
              icon: 'paw_ink',
              title: '카페에서',
              subtitle: '다른 강아지 3마리와 함께',
              actions: [
                FilledButton(onPressed: () {}, child: const Text('집으로')),
              ],
            ),
            PlaceCard(
              tape: C3Colors.tapeYellow,
              icon: 'ball',
              title: '유치원',
              subtitle: '친구 3마리',
              actions: [
                OutlinedButton(
                  style: compactButton,
                  onPressed: () {},
                  child: const Text('맡기기'),
                ),
                FilledButton(
                  style: compactButton,
                  onPressed: () {},
                  child: const Text('집으로'),
                ),
              ],
            ),
            PlaceCard(
              tape: C3Colors.tapeSky,
              icon: 'bone',
              title: '블루베리 젤리',
              subtitle: '골랐어요!',
              actions: [
                OutlinedButton(
                  style: compactButton,
                  onPressed: () {},
                  child: const Text('사 주기'),
                ),
                FilledButton(
                  style: compactButton,
                  onPressed: () {},
                  child: const Text('집으로'),
                ),
              ],
            ),
            PlaceCard(
              tape: C3Colors.tapeMint,
              icon: 'heart',
              title: '병원',
              subtitle: '다음 검진은 6일 뒤',
              actions: [
                FilledButton(
                  style: compactButton,
                  onPressed: () {},
                  child: const Text('집으로'),
                ),
              ],
            ),
            PlaceCard(
              tape: C3Colors.tapeYellow,
              icon: 'ball',
              title: '유치원에서',
              subtitle: '저녁 7시 하원',
              actions: [
                FilledButton(
                  style: compactButton,
                  onPressed: () {},
                  child: const Text('데리러 가기'),
                ),
              ],
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
      'screen_place_cards',
    );
  });

  testWidgets('놀이 칸: 배운 것·배우는 중·처음이 섞여도 넘치지 않는다', (tester) async {
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PlayTray(
              tricks: const {
                Trick.sit: TrickProgress(attempts: 9, successes: 7, days: 3),
                Trick.come: TrickProgress(attempts: 4, successes: 3, days: 1),
                Trick.down: TrickProgress(attempts: 2, successes: 1, days: 1),
              },
              onTrick: (_) {},
              onClose: () {},
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
      'screen_play_tray',
    );
    expect(find.text('★★★'), findsOneWidget);
    expect(find.text('그만 놀기'), findsOneWidget);
    expect(find.text('수첩'), findsNothing);
  });

  testWidgets('놀이 칸: 수첩 버튼과 칩 길게 누르기로 훈련 수첩을 연다(한 줄에 안 넘친다)', (tester) async {
    var opened = 0, tried = 0;
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PlayTray(
              tricks: const {
                Trick.sit: TrickProgress(attempts: 9, successes: 7, days: 3),
              },
              onTrick: (_) => tried++,
              onNotebook: () => opened++,
              onClose: () {},
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
      'screen_play_tray_notebook',
    );
    await tester.tap(find.text('훈련 수첩'));
    expect(opened, 1);
    await tester.longPress(find.text('앉아'));
    expect(opened, 2);
    expect(tried, 0);
    await tester.tap(find.text('앉아'));
    expect(tried, 1);
    final trained = find.semantics.byLabel('앉아, 별 3개');
    tester.semantics.tap(trained);
    await tester.pump();
    expect(tried, 2);
    tester.semantics.longPress(trained);
    await tester.pump();
    expect(opened, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('훈련 수첩: 개인기 아홉 줄과 도장 줄이 다이얼로그에 들어간다', (tester) async {
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StickerCard(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
              child: TrickNotebook(
                petName: '노을',
                tricks: const {
                  Trick.sit: TrickProgress(
                    attempts: 5,
                    successes: 5,
                    days: 2,
                    lastDay: '2026-10-09',
                    learnedDay: '2026-10-08',
                  ),
                  Trick.spin: TrickProgress(
                    attempts: 2,
                    successes: 1,
                    days: 1,
                    lastDay: '2026-10-09',
                  ),
                },
                today: '2026-10-09',
                stamps: 2,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
      'screen_trick_notebook',
    );
    for (final t in Trick.values) {
      expect(find.text(t.label), findsOneWidget);
    }
    expect(find.text('★★☆'), findsOneWidget);
    expect(find.text('배우는 중'), findsOneWidget);
    expect(
      find.text(keepWords('10월 8일에 배웠어요 · 내일 또 하면 별 하나 더')),
      findsOneWidget,
    );
    expect(find.text('발표회 도장 2개 · 금요일 유치원에서'), findsOneWidget);
  });

  testWidgets('도감(다 찾은 상태)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final pet = await tester.runAsync(
      () => db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: DateTime(2026, 9, 26),
      ),
    );
    final c = PetController(
      db,
      pet!.copyWith(
        treatsTried: const Value('cheese_ball:love,jerky:meh,pollack:plain'),
      ),
      random: Random(1),
    );
    await tester.runAsync(() async {
      for (final i in items.take(14)) {
        await db.addFind(i.id, gift: i.id == 'acorn');
      }
      c.finds = {for (final f in await db.allFinds()) f.itemId: f};
    });
    c.placed = {'floor1': 'acorn'};
    await _pumpAndShot(
      tester,
      Scaffold(body: CollectionScreen(controller: c)),
      'screen_collection',
    );
    // 입맛 칸: 먹여 본 셋은 반응, 나머지 다섯은 아직(?).
    await tester.scrollUntilVisible(
      find.text('좋아'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('좋아'), findsOneWidget);
    expect(find.text('별로'), findsOneWidget);
    expect(find.text('그냥'), findsOneWidget);
    expect(find.text('?', skipOffstage: false), findsWidgets);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_shotKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File(
        'shots/screen_collection_tastes.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
    });
  });

  testWidgets('도감 아는 강아지: 데려온 애는 만나기 전에도 얼굴·이름이 보이고 데려오기 칸이 있다', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final pet = await tester.runAsync(
      () => db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: DateTime(2026, 9, 26),
      ),
    );
    final c = PetController(db, pet!, random: Random(1));
    await tester.runAsync(
      () => c.addKnownDog(
        name: '토토',
        shape: 'corgi',
        colors: const PetColors(
          main: 0xFFC48C54,
          second: 0xFFF4E2C4,
          marking: 0xFF8A5E3B,
        ),
      ),
    );
    await _pumpAndShot(
      tester,
      Scaffold(body: CollectionScreen(controller: c)),
      'screen_collection_known',
    );
    expect(find.text('아는 강아지'), findsOneWidget);
    expect(find.text('토토'), findsOneWidget);
    expect(find.text('아직 못 만남'), findsOneWidget);
    expect(find.text('데려오기'), findsOneWidget);
  });

  testWidgets('도감 꾸미기: 발도장 수, 목걸이·방석 칸, 쓰는 중·가짐·값이 한 칸에 들어간다', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final pet = await tester.runAsync(() async {
      final p = await db.createPet(
        name: '노을',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: DateTime(2026, 9, 26),
      );
      final q = p.copyWith(paws: 23);
      await db.savePet(q);
      return q;
    });
    final c = PetController(db, pet!, random: Random(1));
    await tester.runAsync(() async {
      c.buyCosmetic('collar_sky');
    });
    await _pumpAndShot(
      tester,
      Scaffold(body: CollectionScreen(controller: c)),
      'screen_dress_up',
    );
    expect(find.text('꾸미기'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('쓰는 중'), findsNWidgets(2));
    expect(find.text('가짐'), findsOneWidget);
    expect(find.text('발도장 8'), findsNWidgets(5));
    expect(find.text('발도장 12'), findsNWidgets(3));
    await tester.ensureVisible(find.text('빨강 목걸이'));
    await tester.pump();
    tester.semantics.tap(find.semantics.byLabel('빨강 목걸이, 가짐'));
    await tester.pump();
    expect(c.collar.id, 'collar_red');
    expect(c.paws, 15);
    await tester.runAsync(() => c.settled);
  });

  testWidgets('아는 강아지 데려오기: 이름을 넣어야 버튼이 켜지고, 누르면 데려온다', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final pet = await tester.runAsync(
      () => db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: DateTime(2026, 9, 26),
      ),
    );
    final c = PetController(db, pet!, random: Random(1));
    await _pumpAndShot(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => RepaintBoundary(
                    key: const ValueKey('known_dog_editor'),
                    child: KnownDogScreen(controller: c),
                  ),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
      'screen_known_dog_host',
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await _settleImages(tester);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('known_dog_editor')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File(
        'shots/screen_known_dog.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
    });

    // 목록이 길어 아래쪽은 스크롤해야 만들어진다.
    final list = find.byType(Scrollable).first;
    final button = find.widgetWithText(FilledButton, '데려오기');
    await tester.scrollUntilVisible(button, 300, scrollable: list);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    // 목록은 화면에 보이는 칸만 그리니 모양은 위젯이 받은 목록으로 본다.
    final picker = tester.widget<ShapePicker>(find.byType(ShapePicker));
    expect(picker.shapes, friendShapes);
    expect(picker.shapes.map((s) => s.id), isNot(contains('noeul')));
    // 색을 이리저리 눌러 봐도 미리보기 얼굴은 앱 내내 쌓이지 않는다.
    final cached = GuestFace.paintedCount;
    await tester.scrollUntilVisible(find.text('검정'), -300, scrollable: list);
    for (final color in ['검정', '흰색', '회색', '크림']) {
      final chip = find.widgetWithText(ChoiceChip, color);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pump();
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(GuestFace.paintedCount, cached);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      -300,
      scrollable: list,
    );
    await tester.enterText(find.byType(TextField), '토토');
    await tester.pump();
    await tester.scrollUntilVisible(button, 300, scrollable: list);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
    expect(c.knownDogs, hasLength(1));
    expect(c.friends[c.knownDogs.single.id]?.name, '토토');
    expect(find.text('열기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
