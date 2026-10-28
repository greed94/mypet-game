import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/ui/app_info.dart';
import 'package:mypet/ui/c3/c3_theme.dart';

void main() {
  testWidgets('작은 화면과 큰 글씨에서도 출처를 읽고 라이선스를 열 수 있다', (tester) async {
    // SDK의 NOTICES 압축 해제 isolate 대신 이번에 추가한 실제 글꼴 번들을 검사한다.
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const AppInfoScreen(),
      ),
    );
    expect(find.text('앱 정보와 출처'), findsOneWidget);
    final scrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final label in [
      'https://open-meteo.com/',
      'https://atmosphere.copernicus.eu/',
      'https://www.openstreetmap.org/copyright',
      '오픈소스 라이선스 보기',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        180,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text(label).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.runAsync(() async {
      final fonts = await LicenseRegistry.licenses
          .where(
            (entry) =>
                entry.packages.any({'Jua', 'Gowun Dodum', 'Gaegu'}.contains),
          )
          .toList();
      expect(fonts, hasLength(3));
      for (final entry in fonts) {
        expect(
          entry.paragraphs.map((p) => p.text).join('\n'),
          contains('SIL OPEN FONT LICENSE'),
        );
      }
    });
    await tester.tap(find.text('오픈소스 라이선스 보기'));
    await tester.pump();
    // 실제 asset Future와 라이선스 스트림을 처리한 뒤 화면 전환을 마친다.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text('Gaegu'), findsOneWidget);
    expect(find.text('Gowun Dodum'), findsOneWidget);
    expect(find.text('Jua'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
