import 'package:flutter/material.dart';

import '../services/crisis_support.dart';
import 'c3/sticker_card.dart';

Future<void> showCrisisDialog(BuildContext context) => showC3Dialog<void>(
  context,
  title: '혼자 견디지 않아도 돼요',
  body: const _CrisisHelp(),
);

class _CrisisHelp extends StatefulWidget {
  const _CrisisHelp();

  @override
  State<_CrisisHelp> createState() => _CrisisHelpState();
}

class _CrisisHelpState extends State<_CrisisHelp> {
  var _opening = false;
  var _failed = false;

  Future<void> _dial() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    final opened = await CrisisSupport.openDialer();
    if (!mounted) return;
    setState(() {
      _opening = false;
      _failed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '지금 많이 힘드시다면 전문 상담사와 이야기해 보세요.\n\n'
        '자살예방상담전화 109 (24시간)\n'
        '지금 다치거나 생명이 위험하면 112 또는 119에 연락해 주세요.\n\n'
        '말하기 어렵다면 109로 문자메시지를 보내거나 '
        '카카오톡에서 ‘마들랜’을 찾아 상담할 수 있어요.',
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _opening ? null : _dial,
        child: const Text('109 전화 화면 열기'),
      ),
      if (_failed) ...[
        const SizedBox(height: 8),
        const Text('전화 화면을 열지 못했어요. 전화 앱에서 109를 눌러 주세요.'),
      ],
    ],
  );
}
