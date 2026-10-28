import 'package:flutter/material.dart';

import 'c3/c3_theme.dart';

/// 저장소 열기에 실패해도 기록을 지우거나 처음 만들기로 보내지 않는다.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key, required this.load});

  final Future<Widget> Function() load;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late Future<Widget> _opening = Future.sync(widget.load);

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _opening,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.requireData;
      final failed =
          snapshot.connectionState == ConnectionState.done && snapshot.hasError;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildC3Theme(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: failed
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '기록을 여는 데 실패했어요.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '기존 기록은 지우지 않았어요.\n'
                              '앱을 삭제하거나 데이터를 지우지 말고 다시 시도해 주세요.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: () => setState(() {
                                _opening = Future.sync(widget.load);
                              }),
                              child: const Text('다시 시도'),
                            ),
                          ],
                        )
                      : const CircularProgressIndicator(),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
