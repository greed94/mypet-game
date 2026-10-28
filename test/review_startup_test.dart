import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/ui/app_startup.dart';

void main() {
  testWidgets('기록 열기 실패는 내부 내용 없이 안내하고 한 번씩 재시도한다', (tester) async {
    var calls = 0;
    final pending = Completer<Widget>();
    await tester.pumpWidget(
      AppStartup(
        load: () async {
          calls++;
          if (calls == 1) throw StateError('synthetic private database path');
          return pending.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('기록을 여는 데 실패했어요.'), findsOneWidget);
    expect(find.textContaining('앱을 삭제하거나 데이터를 지우지 말고'), findsOneWidget);
    expect(find.textContaining('synthetic private'), findsNothing);
    expect(find.text('처음부터 다시 만들기'), findsNothing);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(calls, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
    pending.complete(const MaterialApp(home: Text('기존 펫 복구')));
    await tester.pumpAndSettle();
    expect(find.text('기존 펫 복구'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('동기 열기 실패도 처리하며 해제 뒤 완료가 화면을 갱신하지 않는다', (tester) async {
    final pending = Completer<Widget>();
    var calls = 0;
    await tester.pumpWidget(
      AppStartup(
        load: () {
          calls++;
          if (calls == 1) throw StateError('synthetic sync failure');
          return pending.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
