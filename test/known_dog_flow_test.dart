import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mypet/art/photo_art.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/known_dog_screen.dart';
import 'package:mypet/ui/shape_picker.dart';

const _picker = MethodChannel('plugins.flutter.io/image_picker');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AppDatabase db;
  late PetController controller;
  late Directory folder;
  late File photo;
  final errors = <Object>[];

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
  }

  Future<void> invoke(WidgetTester tester, VoidCallback action) async {
    await tester.runAsync(() async {
      runZonedGuarded(action, (error, stack) => errors.add(error));
      await pumpEventQueue();
    });
    await drain(tester);
  }

  Future<void> mount(
    WidgetTester tester, {
    AppDatabase Function()? database,
    bool editing = false,
  }) async {
    ShapePicker.resetCache();
    errors.clear();
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      db = database?.call() ?? AppDatabase(NativeDatabase.memory());
      final pet = await db.createPet(
        name: '합성 펫',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: DateTime(2026, 10, 20, 14),
      );
      controller = PetController(
        db,
        pet,
        clock: () => DateTime(2026, 10, 20, 15),
      );
      if (editing) {
        await controller.addKnownDog(
          name: '이전 합성 친구',
          shape: 'papillon',
          colors: const PetColors(main: 1, second: 2, marking: 3),
        );
      }
      folder = await Directory.systemTemp.createTemp('mypet-known-');
      final image = img.Image(width: 8, height: 8);
      img.fill(image, color: img.ColorRgb8(120, 80, 30));
      photo = File('${folder.path}/synthetic.png');
      await photo.writeAsBytes(img.encodePng(image));
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
      await tester.runAsync(() async {
        await controller.settled;
        if (!controller.isDisposed) controller.dispose();
        await db.close();
        await photo.delete();
        await folder.delete();
      });
      messenger.setMockMethodCallHandler(_picker, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => KnownDogScreen(
                    controller: controller,
                    dog: editing ? controller.knownDogs.single : null,
                  ),
                ),
              ),
              child: const Text('검사 화면 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('검사 화면 열기'));
    await tester.pumpAndSettle();
    await drain(tester);
  }

  VoidCallback pick(WidgetTester tester) => tester
      .widget<OutlinedButton>(
        find.ancestor(
          of: find.text('사진에서 털색 뽑기'),
          matching: find.byWidgetPredicate(
            (widget) => widget is OutlinedButton,
          ),
        ),
      )
      .onPressed!;

  Future<VoidCallback> save(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextField, '이름'), '합성 친구');
    await tester.pump();
    final label =
        tester.widget<KnownDogScreen>(find.byType(KnownDogScreen)).dog == null
        ? '데려오기'
        : '저장';
    return tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, label))
        .onPressed!;
  }

  testWidgets('늦은 친구 사진이 직접 고른 색을 덮어쓰지 않는다', (tester) async {
    await mount(tester);
    final reply = (await tester.runAsync(() async => Completer<String?>()))!;
    messenger.setMockMethodCallHandler(_picker, (_) => reply.future);
    await invoke(tester, pick(tester));
    await tester.tap(find.widgetWithText(ChoiceChip, '흰색'));
    await tester.pump();
    await tester.runAsync(() async => reply.complete(photo.path));
    await drain(tester);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '흰색')).selected,
      isTrue,
    );
    expect(errors, isEmpty);
    expect(await tester.runAsync(() => db.loadKnownDogs()), isEmpty);
  });

  testWidgets('아는 강아지 사진을 취소하면 그대로 두고 고른 영역의 색은 친구 수첩에 저장한다', (tester) async {
    await mount(tester);
    final fixture = File(
      'tools/scene_preview/fixtures/synthetic-beagle.jpg',
    ).absolute;
    messenger.setMockMethodCallHandler(_picker, (_) async => fixture.path);
    await invoke(tester, pick(tester));
    final edit = find.text('얼굴 위치 맞추기');
    for (var i = 0; i < 12 && edit.evaluate().isEmpty; i++) {
      await drain(tester);
    }
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(KnownDogScreen), findsOneWidget);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(2.0);
    await tester.pump();
    final box = tester.getRect(find.byKey(const ValueKey('pet-photo-frame')));
    await tester.tapAt(
      Offset(box.left + .78 * box.width, box.top + .44 * box.height),
    );
    await tester.pump(const Duration(milliseconds: 150));
    final confirm = find.widgetWithText(FilledButton, '이 영역 사용');
    for (
      var i = 0;
      i < 20 && tester.widget<FilledButton>(confirm).onPressed == null;
      i++
    ) {
      await drain(tester);
    }
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await invoke(tester, await save(tester));
    final saved = (await tester.runAsync(() => db.loadKnownDogs()))!.single;
    final main = saved.furMain;
    expect(controller.friends[saved.id]?.name, '합성 친구');
    expect((main >> 16) & 255, greaterThan((main & 255) + 20));
    expect(errors, isEmpty);
  });

  testWidgets('친구 사진 선택 실패 후 안내하고 다시 고른다', (tester) async {
    await mount(tester);
    var attempts = 0;
    messenger.setMockMethodCallHandler(_picker, (_) async {
      if (++attempts == 1) throw PlatformException(code: 'synthetic-picker');
      return photo.path;
    });
    await invoke(tester, pick(tester));
    expect(errors, isEmpty);
    expect(find.text('사진을 열지 못했어요. 다시 골라 볼까요?'), findsOneWidget);
    await invoke(tester, pick(tester));
    expect(attempts, 2);
    expect(find.text('사진에서 털색 뽑기'), findsOneWidget);
  });

  testWidgets('친구 저장 실패 뒤 입력을 보존하고 다시 저장한다', (tester) async {
    await mount(tester);
    await tester.runAsync(
      () => db.customStatement(
        'CREATE TRIGGER fail_known BEFORE INSERT ON known_dogs '
        "BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
      ),
    );
    final action = await save(tester);
    await invoke(tester, action);
    expect(errors, isEmpty);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '이름'))
          .controller!
          .text,
      '합성 친구',
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '데려오기'))
          .onPressed,
      isNotNull,
    );
    expect(find.text('저장하지 못했어요. 다시 해볼까요?'), findsOneWidget);
    expect(await tester.runAsync(() => db.loadKnownDogs()), isEmpty);
    await tester.runAsync(() => db.customStatement('DROP TRIGGER fail_known'));
    await invoke(tester, action);
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, hasLength(1));
    expect(controller.knownDogs, hasLength(1));
    expect(find.byType(KnownDogScreen), findsNothing);
  });

  testWidgets('친구 추가 대기 중 같은 콜백을 두 번 실행해도 저장은 하나다', (tester) async {
    final release = (await tester.runAsync(() async => Completer<void>()))!;
    late _GateDb gated;
    await mount(tester, database: () => gated = _GateDb(release.future));
    final action = await save(tester);
    await invoke(tester, action);
    await invoke(tester, action);
    final starts = gated.starts;
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, '이름')).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '흰색'))
          .onSelected,
      isNull,
    );
    await tester.runAsync(() async => release.complete());
    await drain(tester);
    expect(starts, 1);
    expect(errors, isEmpty);
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, hasLength(1));
    expect(controller.knownDogs, hasLength(1));
    expect(find.byType(KnownDogScreen), findsNothing);
  });

  testWidgets('취소와 파일 읽기 실패 뒤 사진을 다시 고를 수 있다', (tester) async {
    await mount(tester);
    var attempt = 0;
    messenger.setMockMethodCallHandler(_picker, (_) async {
      attempt++;
      return switch (attempt) {
        1 => null,
        2 => '${folder.path}/missing.png',
        _ => photo.path,
      };
    });
    final before = tester
        .widget<ShapePicker>(find.byType(ShapePicker))
        .colors
        .main;
    await invoke(tester, pick(tester));
    expect(
      tester.widget<ShapePicker>(find.byType(ShapePicker)).colors.main,
      before,
    );
    await invoke(tester, pick(tester));
    expect(find.text('사진을 읽지 못했어요. 다른 사진으로 해볼까요?'), findsOneWidget);
    await invoke(tester, pick(tester));
    expect(errors, isEmpty);
    expect(attempt, 3);
    expect(
      tester.widget<ShapePicker>(find.byType(ShapePicker)).colors.main,
      isNot(before),
    );
    expect(await tester.runAsync(() => db.loadKnownDogs()), isEmpty);
    expect(folder.listSync(), hasLength(1));
  });

  testWidgets('손상된 친구 사진 안내 뒤 정상 사진으로 다시 시도한다', (tester) async {
    await mount(tester);
    final valid = photo.readAsBytesSync();
    photo.writeAsBytesSync([1, 2, 3]);
    messenger.setMockMethodCallHandler(_picker, (_) async => photo.path);
    await invoke(tester, pick(tester));
    expect(errors, isEmpty);
    expect(find.text('사진을 읽지 못했어요. 다른 사진으로 해볼까요?'), findsOneWidget);
    photo.writeAsBytesSync(valid);
    await invoke(tester, pick(tester));
    expect(errors, isEmpty);
    expect(find.text('사진을 읽지 못했어요. 다른 사진으로 해볼까요?'), findsNothing);
  });

  testWidgets('친구 사진 응답 전 화면 해제는 파일 읽기와 이전 콜백을 무시한다', (tester) async {
    await mount(tester);
    final reply = (await tester.runAsync(() async => Completer<String?>()))!;
    messenger.setMockMethodCallHandler(_picker, (_) => reply.future);
    final action = pick(tester);
    await invoke(tester, action);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () async => reply.complete('${folder.path}/missing.png'),
    );
    await drain(tester);
    await invoke(tester, action);
    expect(errors, isEmpty);
    expect(await tester.runAsync(() => db.loadKnownDogs()), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('친구 사진 응답 전 컨트롤러 해제는 기존 색을 유지한다', (tester) async {
    await mount(tester);
    final before = tester
        .widget<ShapePicker>(find.byType(ShapePicker))
        .colors
        .main;
    final reply = (await tester.runAsync(() async => Completer<String?>()))!;
    messenger.setMockMethodCallHandler(_picker, (_) => reply.future);
    await invoke(tester, pick(tester));
    controller.dispose();
    await tester.runAsync(() async => reply.complete(photo.path));
    await drain(tester);
    expect(errors, isEmpty);
    expect(
      tester.widget<ShapePicker>(find.byType(ShapePicker)).colors.main,
      before,
    );
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, '이름')).enabled,
      isFalse,
    );
  });

  testWidgets('같은 친구 사진 콜백을 연속 호출해도 선택기는 하나다', (tester) async {
    await mount(tester);
    final reply = (await tester.runAsync(() async => Completer<String?>()))!;
    var requests = 0;
    messenger.setMockMethodCallHandler(_picker, (_) {
      requests++;
      return reply.future;
    });
    final action = pick(tester);
    await invoke(tester, action);
    await invoke(tester, action);
    final pending = requests;
    await tester.runAsync(() async => reply.complete(null));
    await drain(tester);
    expect(pending, 1);
    expect(errors, isEmpty);
    expect(find.text('사진에서 털색 뽑기'), findsOneWidget);
  });

  testWidgets('사진 응답을 기다리는 동안 저장을 막고 완료된 색으로 저장한다', (tester) async {
    await mount(tester);
    final action = await save(tester);
    final reply = (await tester.runAsync(() async => Completer<String?>()))!;
    messenger.setMockMethodCallHandler(_picker, (_) => reply.future);
    await invoke(tester, pick(tester));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '데려오기'))
          .onPressed,
      isNull,
    );
    await invoke(tester, action);
    expect(await tester.runAsync(() => db.loadKnownDogs()), isEmpty);
    await tester.runAsync(() async => reply.complete(photo.path));
    await drain(tester);
    final chosen = tester.widget<ShapePicker>(find.byType(ShapePicker)).colors;
    await invoke(tester, action);
    final saved = (await tester.runAsync(() => db.loadKnownDogs()))!.single;
    expect(saved.furMain, chosen.main);
    expect(saved.furSecond, chosen.second);
    expect(saved.marking, chosen.marking);
    expect(errors, isEmpty);
    expect(folder.listSync(), hasLength(1));
  });

  testWidgets('기존 친구 고치기 실패 뒤 원래 자료를 지키고 다시 저장한다', (tester) async {
    await mount(tester, editing: true);
    final id = controller.knownDogs.single.id;
    await tester.runAsync(
      () => db.customStatement(
        'CREATE TRIGGER fail_edit BEFORE UPDATE ON known_dogs '
        "BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
      ),
    );
    final action = await save(tester);
    await invoke(tester, action);
    expect(errors, isEmpty);
    expect(controller.friends[id]!.name, '이전 합성 친구');
    expect(
      (await tester.runAsync(() => db.loadFriends()))![id]!.name,
      '이전 합성 친구',
    );
    expect(find.text('저장하지 못했어요. 다시 해볼까요?'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '저장'))
          .onPressed,
      isNotNull,
    );
    await tester.runAsync(() => db.customStatement('DROP TRIGGER fail_edit'));
    await invoke(tester, action);
    expect(controller.friends[id]!.name, '합성 친구');
    expect((await tester.runAsync(() => db.loadFriends()))![id]!.name, '합성 친구');
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, hasLength(1));
    expect(find.byType(KnownDogScreen), findsNothing);
  });

  testWidgets('친구 정원 안내 뒤 빈자리가 생기면 다시 데려올 수 있다', (tester) async {
    await mount(tester);
    await tester.runAsync(() async {
      for (var i = 0; i < maxKnownDogs; i++) {
        await controller.addKnownDog(
          name: '합성 $i',
          shape: 'papillon',
          colors: const PetColors(main: 1, second: 2, marking: 3),
        );
      }
    });
    final action = await save(tester);
    await invoke(tester, action);
    expect(errors, isEmpty);
    expect(find.text('아는 강아지는 $maxKnownDogs마리까지 데려올 수 있어요.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '데려오기'))
          .onPressed,
      isNotNull,
    );
    await tester.runAsync(
      () => controller.removeKnownDog(controller.knownDogs.first.id),
    );
    await invoke(tester, action);
    expect(controller.knownDogs, hasLength(maxKnownDogs));
    expect(
      (await tester.runAsync(() => db.loadKnownDogs()))!,
      hasLength(maxKnownDogs),
    );
    expect(find.byType(KnownDogScreen), findsNothing);
  });

  testWidgets('친구 추가 저장 중 화면과 컨트롤러 해제는 저장만 마무리한다', (tester) async {
    final release = (await tester.runAsync(() async => Completer<void>()))!;
    await mount(tester, database: () => _GateDb(release.future));
    final action = await save(tester);
    await invoke(tester, action);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.runAsync(() async => release.complete());
    await drain(tester);
    expect(errors, isEmpty);
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, hasLength(1));
    expect(controller.knownDogs, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('친구 수정 저장 중 화면과 컨트롤러 해제는 저장만 마무리한다', (tester) async {
    final release = (await tester.runAsync(() async => Completer<void>()))!;
    await mount(
      tester,
      editing: true,
      database: () => _GateDb(release.future, editing: true),
    );
    final id = controller.knownDogs.single.id;
    final action = await save(tester);
    await invoke(tester, action);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.runAsync(() async => release.complete());
    await drain(tester);
    expect(errors, isEmpty);
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, hasLength(1));
    expect((await tester.runAsync(() => db.loadFriends()))![id]!.name, '합성 친구');
    expect(controller.friends[id]!.name, '이전 합성 친구');
    expect(tester.takeException(), isNull);
  });
}

class _GateDb extends AppDatabase {
  _GateDb(this.release, {this.editing = false})
    : super(NativeDatabase.memory());
  final bool editing;
  final Future<void> release;
  int starts = 0;

  @override
  Future<void> addKnownDog(Guest guest, Friendship friend, DateTime at) async {
    starts++;
    if (!editing) await release;
    await super.addKnownDog(guest, friend, at);
  }

  @override
  Future<void> updateKnownDog(Guest guest, Friendship friend) async {
    if (editing) await release;
    await super.updateKnownDog(guest, friend);
  }
}
