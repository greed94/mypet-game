import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/art/photo_art.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/shapes.dart';
import 'package:mypet/pet/spots.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/c3/sticker_card.dart';
import 'package:mypet/ui/c3/sticker_button.dart';
import 'package:mypet/ui/friends.dart';
import 'package:mypet/ui/shape_picker.dart';
import 'package:mypet/ui/town_map.dart';

const _captureKey = ValueKey('design-audit-capture');

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 640),
  double scale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildC3Theme(),
      builder: (context, child) => RepaintBoundary(
        key: _captureKey,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> settleImages(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
  }
}

Future<void> shot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final folder = Directory('shots/audit_2026-10-28')
      ..createSync(recursive: true);
    File(
      '${folder.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    for (final (family, file) in [
      (C3Fonts.jua, 'Jua-Regular.ttf'),
      (C3Fonts.gowun, 'GowunDodum-Regular.ttf'),
      (C3Fonts.gaegu, 'Gaegu-Regular.ttf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(
          Future.value(
            ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync()),
          ),
        );
      await loader.load();
    }
  });

  testWidgets('글씨를 150%로 키워도 돌봄 스티커의 아이콘과 이름이 한 칸에 들어간다', (tester) async {
    var tapped = false;
    await mount(
      tester,
      Scaffold(
        body: Center(
          child: StickerButton(
            cut: 'tree',
            icon: 'tree',
            label: '산책 가기',
            width: 73,
            onTap: () => tapped = true,
          ),
        ),
      ),
      size: const Size(320, 700),
      scale: 1.5,
    );
    expect(tester.getSize(find.byType(StickerButton)).height, greaterThan(88));
    await tester.tap(find.text('산책 가기').hitTestable());
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('짧은 화면과 큰 글씨에서도 지도 모든 장소를 고를 수 있다', (tester) async {
    Spot? picked;
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showTownMap(context),
            child: const Text('지도 열기'),
          ),
        ),
      ),
      size: const Size(360, 360),
      scale: 1.3,
    );
    for (final spot in Spot.values) {
      await tester.tap(find.text('지도 열기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(spot.label));
      await tester.pumpAndSettle();
      if (spot == Spot.treatShop) {
        await settleImages(tester);
        await shot(tester, 'map_short_large_text');
      }
      await tester.tap(find.text(spot.label));
      await tester.pumpAndSettle();
      expect(picked, spot);
      expect(find.byType(Dialog), findsNothing);
    }
  });

  testWidgets('지도 닫기와 장소는 읽을 수 있는 버튼이고 닫기는 48dp 이상이다', (tester) async {
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(showTownMap(context)),
            child: const Text('지도 열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('지도 열기'));
    await tester.pumpAndSettle();
    final close = find.bySemanticsLabel('지도 닫기');
    expect(close, findsOneWidget);
    expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(close),
      matchesSemantics(label: '지도 닫기', isButton: true, hasTapAction: true),
    );
    for (final spot in Spot.values) {
      expect(find.bySemanticsLabel('${spot.label}에 가기'), findsOneWidget);
    }
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('친구 이름 키보드와 큰 글씨가 있어도 저장 버튼에 닿는다', (tester) async {
    final input = TextEditingController(text: '검사친구');
    addTearDown(input.dispose);
    var saved = 0;
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: StickerCard(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
                  child: FriendCard(
                    guest: cafeRegulars.first,
                    friendship: const Friendship(bond: Bond.play, days: 3),
                    input: input,
                    nameRequired: true,
                    share: '검사간식',
                    onShare: () {},
                    onEdit: () {},
                    onClose: () => Navigator.of(context).pop(),
                    onSave: () => saved++,
                  ),
                ),
              ),
            ),
            child: const Text('친구 열기'),
          ),
        ),
      ),
      size: const Size(320, 640),
      scale: 1.4,
      keyboard: 300,
    );
    await tester.tap(find.text('친구 열기'));
    await tester.pumpAndSettle();
    await settleImages(tester);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '고친친구');
    await tester.pump();
    final save = find.widgetWithText(FilledButton, '저장');
    expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(340));
    await shot(tester, 'friend_keyboard_large_text');
    await tester.tap(save);
    await tester.pump();
    expect(saved, 1);
    expect(input.text, '고친친구');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
  });

  const colors = PetColors(
    main: 0xFFC48C54,
    second: 0xFFF4E2C4,
    marking: 0xFF8A5E3B,
  );

  testWidgets('일반 모양 선택에는 개인 실험 틀이 나오지 않는다', (tester) async {
    ShapePicker.resetCache();
    await mount(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: ShapePicker(
            colors: colors,
            selected: 'papillon',
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await settleImages(tester);
    expect(find.text('이전 버전 모양'), findsNothing);
    for (final shape in friendShapes) {
      expect(find.text(shape.examples), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('이미 개인 틀을 쓰는 펫은 선택과 자산 조회를 유지한다', (tester) async {
    ShapePicker.resetCache();
    await mount(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: ShapePicker(
            colors: colors,
            selected: 'noeul',
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await settleImages(tester);
    expect(find.text('이전 버전 모양'), findsOneWidget);
    expect(shapeById('noeul').id, 'noeul');
    expect(spriteAsset('noeul', PetStage.puppy), 'sprites/papillon_adult.png');
    await tester.ensureVisible(find.text('이전 버전 모양'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.label == '이전 버전 모양',
            ),
          )
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
