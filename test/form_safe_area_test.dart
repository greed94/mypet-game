import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/ui/app_info.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/known_dog_screen.dart';
import 'package:mypet/ui/settings_screen.dart';

void main() {
  for (final (label, margin, screen)
      in <(String, double, Widget Function(PetController))>[
        (
          '처음부터 다시 만들기',
          16,
          (pet) => SettingsScreen(controller: pet, onReset: () async {}),
        ),
        ('데려오기', 16, (pet) => KnownDogScreen(controller: pet)),
        ('오픈소스 라이선스 보기', 20, (_) => const AppInfoScreen()),
      ]) {
    testWidgets('$label 버튼은 시스템 바와 키보드 위까지 스크롤할 수 있다', (tester) async {
      const size = Size(420, 540);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final db = AppDatabase(NativeDatabase.memory());
      final pet = await tester.runAsync(
        () => db.createPet(
          name: '보리',
          stage: PetStage.adult,
          furMain: 1,
          furSecond: 2,
          marking: 3,
          now: DateTime(2026, 11, 25),
        ),
      );
      final controller = PetController(db, pet!);
      addTearDown(() async {
        controller.dispose();
        await db.close();
      });
      await tester.pumpWidget(
        MaterialApp(theme: buildC3Theme(), home: screen(controller)),
      );
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final lastButton = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      );
      for (final (bottom, keyboard) in [
        (24.0, 0.0),
        (48.0, 0.0),
        (48.0, 216.0),
      ]) {
        tester.view.viewPadding = FakeViewPadding(
          left: 32,
          right: 28,
          bottom: bottom,
        );
        tester.view.padding = FakeViewPadding(
          left: 32,
          right: 28,
          bottom: keyboard > 0 ? 0 : bottom,
        );
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();
        // 지연 생성되는 리스트는 마지막 항목이 만들어진 뒤 스크롤 범위가 달라질 수 있다.
        for (var i = 0; i < 5; i++) {
          scroll.jumpTo(scroll.maxScrollExtent);
          await tester.pumpAndSettle();
          if (scroll.extentAfter < 0.1 && lastButton.evaluate().isNotEmpty) {
            break;
          }
        }
        final rect = tester.getRect(lastButton);
        final expectedBottom =
            size.height - (keyboard > 0 ? keyboard : bottom) - margin;
        final reason = '하단 ${bottom}dp, 키보드 ${keyboard}dp';
        expect(rect.bottom, closeTo(expectedBottom, 0.1), reason: reason);
        expect(rect.left, greaterThanOrEqualTo(32), reason: reason);
        expect(rect.right, lessThanOrEqualTo(size.width - 28), reason: reason);
      }
    });
  }
}
