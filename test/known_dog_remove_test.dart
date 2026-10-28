import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/art/photo_art.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/known_dog_screen.dart';
import 'package:mypet/ui/shape_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late PetController controller;
  late Guest dog;
  final errors = <Object>[];
  late Zone actionZone;

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
      actionZone.run(action);
      await pumpEventQueue();
    });
    await drain(tester);
  }

  Future<void> mount(
    WidgetTester tester, {
    AppDatabase Function()? database,
  }) async {
    ShapePicker.resetCache();
    errors.clear();
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      actionZone = runZonedGuarded<Zone>(
        () => Zone.current,
        (error, stack) => errors.add(error),
      )!;
      db = database?.call() ?? AppDatabase(NativeDatabase.memory());
      final pet = await db.createPet(
        name: '합성 펫',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: DateTime(2026, 10, 21, 14),
      );
      controller = PetController(
        db,
        pet,
        clock: () => DateTime(2026, 10, 21, 15),
      );
      dog = (await controller.addKnownDog(
        name: '합성 친구',
        shape: 'papillon',
        colors: const PetColors(main: 1, second: 2, marking: 3),
      ))!;
      await db.addDiary('2026-10-20', '합성 이전 일기', DateTime(2026, 10, 21));
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
      await tester.runAsync(() async {
        await controller.settled;
        if (!controller.isDisposed) controller.dispose();
        await db.close();
      });
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
                  builder: (_) =>
                      KnownDogScreen(controller: controller, dog: dog),
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

  VoidCallback remove(WidgetTester tester) => tester
      .widget<TextButton>(find.widgetWithText(TextButton, '이 친구 지우기'))
      .onPressed!;

  Future<void> failDeletes(WidgetTester tester) => tester.runAsync(
    () => db.customStatement(
      'CREATE TRIGGER fail_delete BEFORE DELETE ON friends '
      "BEGIN SELECT RAISE(ABORT, 'synthetic delete failure'); END",
    ),
  );

  testWidgets('친구 삭제 실패는 이름과 목록을 저장 데이터와 같게 유지한다', (tester) async {
    await mount(tester);
    controller.guests = [dog];
    controller.pendingCard = dog;
    controller.windowPasser = dog;
    controller.windowPassProgress = 0.5;
    final before = controller.friends[dog.id]!;
    await failDeletes(tester);
    Object? failure;
    await tester.runAsync(() async {
      try {
        await controller.removeKnownDog(dog.id);
      } on Exception catch (error) {
        failure = error;
      }
    });
    expect(failure, isNotNull);
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, hasLength(1));
    final saved = (await tester.runAsync(() => db.loadFriends()))![dog.id]!;
    expect(
      (saved.name, saved.bond, saved.days, saved.lastDay, saved.streak),
      (before.name, before.bond, before.days, before.lastDay, before.streak),
    );
    expect(controller.isKnownDog(dog.id), isTrue);
    expect(controller.friends[dog.id], before);
    expect(controller.guests.single.id, dog.id);
    expect(controller.pendingCard?.id, dog.id);
    expect(controller.windowPasser?.id, dog.id);
  });

  testWidgets('친구 삭제 DB 실패 안내 뒤 취소 없이 다시 지울 수 있다', (tester) async {
    await mount(tester);
    await failDeletes(tester);
    await invoke(tester, remove(tester));
    await invoke(
      tester,
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '지우기'))
          .onPressed!,
    );
    expect(errors, isEmpty);
    expect(find.text('지우지 못했어요. 다시 해볼까요?'), findsOneWidget);
    expect(controller.isKnownDog(dog.id), isTrue);
    expect(remove(tester), isNotNull);
    await tester.runAsync(() => db.customStatement('DROP TRIGGER fail_delete'));
    await invoke(tester, remove(tester));
    await invoke(
      tester,
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '지우기'))
          .onPressed!,
    );
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, isEmpty);
    expect(
      (await tester.runAsync(() => db.loadFriends()))!.containsKey(dog.id),
      isFalse,
    );
    expect(controller.isKnownDog(dog.id), isFalse);
    expect(find.byType(KnownDogScreen), findsNothing);
  });

  testWidgets('삭제 취소는 친구와 일기를 바꾸지 않고 편집을 다시 연다', (tester) async {
    await mount(tester);
    await invoke(tester, remove(tester));
    await invoke(
      tester,
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '취소'))
          .onPressed!,
    );
    expect(errors, isEmpty);
    expect(controller.isKnownDog(dog.id), isTrue);
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, hasLength(1));
    expect(await tester.runAsync(() => db.hasDiary('2026-10-20')), isTrue);
    expect(remove(tester), isNotNull);
  });

  testWidgets('같은 삭제 콜백은 확인창을 하나만 연다', (tester) async {
    await mount(tester);
    final action = remove(tester);
    await invoke(tester, action);
    await invoke(tester, action);
    expect(find.byType(AlertDialog), findsOneWidget);
    final cancel = tester
        .widget<TextButton>(find.widgetWithText(TextButton, '취소'))
        .onPressed!;
    await invoke(tester, cancel);
    await invoke(tester, cancel);
    expect(errors, isEmpty);
    expect(find.byType(KnownDogScreen), findsOneWidget);
    expect(controller.isKnownDog(dog.id), isTrue);
  });

  testWidgets('삭제 확인을 두 번 눌러도 편집창을 먼저 닫거나 DB 요청을 겹치지 않는다', (tester) async {
    final gate = (await tester.runAsync(() async => Completer<void>()))!;
    late _DeleteDb delayed;
    await mount(
      tester,
      database: () => delayed = _DeleteDb(deleteGate: gate.future),
    );
    controller.guests = [dog];
    controller.pendingCard = dog;
    controller.windowPasser = dog;
    controller.windowPassProgress = 0.5;
    await invoke(tester, remove(tester));
    final confirm = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '지우기'))
        .onPressed!;
    await invoke(tester, confirm);
    await invoke(tester, confirm);
    late Future<void> duplicate;
    var duplicateDone = false;
    await tester.runAsync(() async {
      duplicate = controller.removeKnownDog(dog.id);
      unawaited(
        duplicate.then((_) {
          duplicateDone = true;
        }),
      );
      await pumpEventQueue();
    });
    final completedWhilePending = duplicateDone;
    expect(delayed.deletes, 1);
    expect(find.byType(KnownDogScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, '이름')).enabled,
      isFalse,
    );
    expect(controller.isKnownDog(dog.id), isTrue);
    await tester.runAsync(() async => gate.complete());
    await drain(tester);
    expect(errors, isEmpty);
    expect(controller.isKnownDog(dog.id), isFalse);
    expect(controller.guests, isEmpty);
    expect(controller.pendingCard, isNull);
    expect(controller.windowPasser, isNull);
    expect(controller.windowPassProgress, isNull);
    expect(completedWhilePending, isFalse);
    expect(duplicateDone, isTrue);
    expect(await tester.runAsync(() => db.hasDiary('2026-10-20')), isTrue);
    expect(find.byType(KnownDogScreen), findsNothing);
  });

  testWidgets('삭제 확인 대기 중 컨트롤러가 해제되면 DB 요청을 하지 않는다', (tester) async {
    late _DeleteDb delayed;
    await mount(tester, database: () => delayed = _DeleteDb());
    await invoke(tester, remove(tester));
    controller.dispose();
    await invoke(
      tester,
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '지우기'))
          .onPressed!,
    );
    expect(errors, isEmpty);
    expect(delayed.deletes, 0);
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, hasLength(1));
    expect(find.byType(KnownDogScreen), findsOneWidget);
  });

  testWidgets('삭제 DB 대기 중 화면과 컨트롤러가 해제돼도 DB 삭제만 마친다', (tester) async {
    final gate = (await tester.runAsync(() async => Completer<void>()))!;
    await mount(tester, database: () => _DeleteDb(deleteGate: gate.future));
    await invoke(tester, remove(tester));
    await invoke(
      tester,
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '지우기'))
          .onPressed!,
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.runAsync(() async => gate.complete());
    await drain(tester);
    expect(errors, isEmpty);
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, isEmpty);
    expect(controller.isKnownDog(dog.id), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('삭제 DB 대기 중 편집을 닫아도 남은 화면을 다시 닫지 않는다', (tester) async {
    final gate = (await tester.runAsync(() async => Completer<void>()))!;
    await mount(tester, database: () => _DeleteDb(deleteGate: gate.future));
    final action = remove(tester);
    await invoke(tester, action);
    await invoke(
      tester,
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '지우기'))
          .onPressed!,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.runAsync(() async => gate.complete());
    await drain(tester);
    await invoke(tester, action);
    expect(errors, isEmpty);
    expect(find.text('검사 화면 열기'), findsOneWidget);
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, isEmpty);
    expect(controller.isKnownDog(dog.id), isFalse);
  });

  testWidgets('삭제된 친구의 늦은 이름과 모습 수정은 이름 행을 다시 만들지 않는다', (tester) async {
    await mount(tester);
    await tester.runAsync(() async {
      await controller.removeKnownDog(dog.id);
      await controller.nameFriend(dog.id, '늦은 합성 이름');
      await db.updateKnownDog(dog, const Friendship(name: '늦은 합성 이름'));
      await controller.nameFriend('kong', '합성 단골');
    });
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, isEmpty);
    final names = (await tester.runAsync(() => db.loadFriends()))!;
    expect(names.containsKey(dog.id), isFalse);
    expect(names['kong']!.name, '합성 단골');
    expect(controller.friends.containsKey(dog.id), isFalse);
  });

  testWidgets('삭제 중인 친구는 새 수정과 만남에서 제외하고 다른 친구는 유지한다', (tester) async {
    final gate = (await tester.runAsync(() async => Completer<void>()))!;
    await mount(tester, database: () => _DeleteDb(deleteGate: gate.future));
    await invoke(tester, remove(tester));
    await invoke(
      tester,
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '지우기'))
          .onPressed!,
    );
    await tester.runAsync(() async {
      await controller.nameFriend(dog.id, '끼어든 합성 이름');
      await controller.editKnownDog(
        dog.id,
        name: '끼어든 합성 이름',
        shape: 'maltese',
        colors: const PetColors(main: 4, second: 5, marking: 6),
      );
      await controller.nameFriend('kong', '합성 단골');
      controller.goToCafe();
      await pumpEventQueue(times: 50);
    });
    expect(controller.friends[dog.id]!.name, '합성 친구');
    expect(controller.guests.any((guest) => guest.id == dog.id), isFalse);
    await tester.runAsync(() async => gate.complete());
    await drain(tester);
    expect(errors, isEmpty);
    expect(
      (await tester.runAsync(() => db.loadFriends()))!.containsKey(dog.id),
      isFalse,
    );
    expect(controller.friends['kong']!.name, '합성 단골');
  });

  testWidgets('다른 친구를 지우는 동안의 모습 수정은 현재 인덱스를 사용한다', (tester) async {
    final gate = (await tester.runAsync(() async => Completer<void>()))!;
    await mount(tester, database: () => _DeleteDb(editGate: gate.future));
    late Guest second;
    late Future<void> edit;
    await tester.runAsync(() async {
      second = (await controller.addKnownDog(
        name: '두 번째 합성',
        shape: 'papillon',
        colors: const PetColors(main: 4, second: 5, marking: 6),
      ))!;
      edit = controller.editKnownDog(
        second.id,
        name: '바뀐 두 번째',
        shape: 'maltese',
        colors: const PetColors(main: 7, second: 8, marking: 9),
      );
      await pumpEventQueue();
      await controller.removeKnownDog(dog.id);
      gate.complete();
      await edit;
    });
    expect(controller.knownDogs.single.id, second.id);
    expect(controller.knownDogs.single.shape, 'maltese');
    expect(controller.friends[second.id]!.name, '바뀐 두 번째');
    expect(
      (await tester.runAsync(() => db.loadKnownDogs()))!.single.id,
      second.id,
    );
  });

  testWidgets('모습 수정이 삭제 뒤 늦게 끝나도 친구와 이름을 되살리지 않는다', (tester) async {
    final gate = (await tester.runAsync(() async => Completer<void>()))!;
    await mount(tester, database: () => _DeleteDb(editGate: gate.future));
    await tester.runAsync(() async {
      final edit = controller.editKnownDog(
        dog.id,
        name: '늦은 수정',
        shape: 'maltese',
        colors: const PetColors(main: 7, second: 8, marking: 9),
      );
      await pumpEventQueue();
      await controller.removeKnownDog(dog.id);
      gate.complete();
      await edit;
    });
    expect(controller.knownDogs, isEmpty);
    expect(controller.friends.containsKey(dog.id), isFalse);
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, isEmpty);
    expect(
      (await tester.runAsync(() => db.loadFriends()))!.containsKey(dog.id),
      isFalse,
    );
  });

  testWidgets('편집 재개설 뒤 같은 삭제도 첫 요청의 실패를 기다리고 재시도한다', (tester) async {
    final gate = (await tester.runAsync(() async => Completer<void>()))!;
    late _DeleteDb delayed;
    await mount(
      tester,
      database: () => delayed = _DeleteDb(deleteGate: gate.future),
    );
    await failDeletes(tester);
    await invoke(tester, remove(tester));
    await invoke(
      tester,
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '지우기'))
          .onPressed!,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('검사 화면 열기'));
    await tester.pumpAndSettle();
    await invoke(tester, remove(tester));
    await invoke(
      tester,
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '지우기'))
          .onPressed!,
    );
    final stayedOpen = find.byType(KnownDogScreen).evaluate().length;
    final requests = delayed.deletes;
    await tester.runAsync(() async => gate.complete());
    await drain(tester);
    expect(requests, 1);
    expect(stayedOpen, 1);
    expect(errors, isEmpty);
    expect(find.text('지우지 못했어요. 다시 해볼까요?'), findsOneWidget);
    expect(controller.isKnownDog(dog.id), isTrue);
    expect(remove(tester), isNotNull);
    await tester.runAsync(() => db.customStatement('DROP TRIGGER fail_delete'));
    await invoke(tester, remove(tester));
    await invoke(
      tester,
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '지우기'))
          .onPressed!,
    );
    expect(delayed.deletes, 2);
    expect((await tester.runAsync(() => db.loadKnownDogs()))!, isEmpty);
    expect(find.byType(KnownDogScreen), findsNothing);
  });
}

class _DeleteDb extends AppDatabase {
  _DeleteDb({this.deleteGate, this.editGate}) : super(NativeDatabase.memory());
  final Future<void>? deleteGate;
  final Future<void>? editGate;
  int deletes = 0;

  @override
  Future<void> deleteKnownDog(String id) async {
    deletes++;
    await deleteGate;
    await super.deleteKnownDog(id);
  }

  @override
  Future<void> updateKnownDog(Guest dog, Friendship friend) async {
    await editGate;
    await super.updateKnownDog(dog, friend);
  }
}
