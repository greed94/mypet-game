import 'package:flutter/material.dart';

import 'c3_theme.dart';
import 'gauge_sticker.dart';
import 'index_tabs.dart';
import 'memo_input.dart';
import 'paper.dart';
import 'pixel_icon.dart';
import 'polaroid.dart';
import 'room_backdrop.dart';
import 'stamp_button.dart';
import 'sticker_button.dart';
import 'sticker_card.dart';
import 'tape.dart';
import 'thought_cloud.dart';

/// 개발 확인용: c3 디자인 시스템 위젯을 한 화면에 늘어놓는다. 앱 라우트에는 연결하지 않는다.
class C3Gallery extends StatefulWidget {
  const C3Gallery({super.key});

  @override
  State<C3Gallery> createState() => _C3GalleryState();
}

class _C3GalleryState extends State<C3Gallery> {
  final _memo = TextEditingController();
  int _tab = 0;
  bool _listening = false;
  bool _notify = true;
  int _age = 1;

  static const _icons = [
    'rain', 'gear', 'smile', 'bone', 'bolt', 'heart', 'bowl', 'ball', //
    'tree', 'mic', 'paw', 'house', 'book', 'sun', 'cloud', 'snow',
    'moon', 'box', 'palm', 'sparkle', 'gift', 'leaf', 'close', 'back',
  ];

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: C3Colors.kraft,
      body: Column(
        children: [
          Expanded(
            child: PaperBackground(
              child: Padding(
                padding: EdgeInsets.only(top: top + 8),
                child: switch (_tab) {
                  0 => _home(),
                  1 => _diary(),
                  _ => _book(),
                },
              ),
            ),
          ),
          IndexTabs(
            labels: const ['집', '일기', '도감'],
            icons: const ['house', 'book', 'box'],
            selected: _tab,
            onSelect: (i) => setState(() => _tab = i),
          ),
        ],
      ),
    );
  }

  Widget _home() {
    return Column(
      children: [
        SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Row(
              children: [
                _portrait(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 34,
                        child: Row(
                          children: [
                            const Text('콩이', style: C3Text.title),
                            const SizedBox(width: 12),
                            Tape(
                              height: 28,
                              color: C3Colors.tapeSky,
                              angle: -3,
                              child: const Padding(
                                padding: EdgeInsets.only(left: 11, right: 13),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PixelIcon('rain'),
                                    SizedBox(width: 5),
                                    Text(
                                      '비 12°',
                                      style: TextStyle(
                                        fontFamily: C3Fonts.jua,
                                        fontFamilyFallback: C3Fonts.fallback,
                                        fontSize: 15,
                                        color: Color(0xFF3F5A74),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        '성체 · 친함 · 함께한 지 12일째',
                        maxLines: 1,
                        style: TextStyle(fontSize: 13, color: C3Colors.ink2),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: _gear()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: SizedBox(
            height: 75,
            child: Row(
              children: [
                Expanded(
                  child: GaugeSticker(
                    icon: 'smile',
                    label: '기분',
                    value: 72,
                    colors: GaugeColors.mood,
                    tilt: -3,
                  ),
                ),
                Expanded(
                  child: GaugeSticker(
                    icon: 'bone',
                    label: '배부름',
                    value: 70,
                    colors: GaugeColors.fullness,
                    tilt: 2,
                  ),
                ),
                Expanded(
                  child: GaugeSticker(
                    icon: 'bolt',
                    label: '기운',
                    value: 55,
                    colors: GaugeColors.energy,
                    tilt: -2,
                  ),
                ),
                Expanded(
                  child: GaugeSticker(
                    icon: 'heart',
                    label: '친밀도',
                    value: 48,
                    colors: GaugeColors.bond,
                    tilt: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 16, 12, 0),
            child: Polaroid(
              caption: '9월 26일, 콩이네 방',
              captionRight: '비 오는 토요일',
              child: _Room(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: SizedBox(
            height: 88,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                StickerButton(
                  cut: 'bowl',
                  icon: 'bowl',
                  label: '밥 주기',
                  tilt: -3,
                  onTap: () {},
                ),
                StickerButton(
                  cut: 'ball',
                  icon: 'ball',
                  label: '놀아주기',
                  tilt: 2,
                  onTap: () {},
                ),
                StickerButton(
                  cut: 'tree',
                  icon: 'tree',
                  label: '산책 가기',
                  tilt: -1.5,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: MemoInput(
                    controller: _memo,
                    hint: _listening ? '듣고 있어요…' : '콩이에게 말 걸기…',
                    listening: _listening,
                    onMic: () => setState(() => _listening = !_listening),
                    onSubmit: (_) => _memo.clear(),
                  ),
                ),
                const SizedBox(width: 12),
                StampButton(onTap: _memo.clear),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _portrait() {
    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(3),
      decoration: _discDecoration,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF7E5D6),
        ),
        child: Center(child: PixelIcon('smile', scale: 3)),
      ),
    );
  }

  static const _discDecoration = BoxDecoration(
    shape: BoxShape.circle,
    color: Colors.white,
    boxShadow: [
      BoxShadow(color: C3Colors.shadow, offset: Offset(0, 2), blurRadius: 2.6),
    ],
  );

  Widget _gear() {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: C3Colors.shadow,
            offset: Offset(0, 2),
            blurRadius: 1.7,
          ),
        ],
      ),
      child: const Center(child: PixelIcon('gear')),
    );
  }

  Widget _diary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('콩이의 일기', style: C3Text.title),
          const SizedBox(height: 22),
          const StickerCard(
            tape: C3Colors.tapeMint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('9월 25일 · 맑음', style: C3Text.label),
                SizedBox(height: 8),
                Text(
                  '오늘은 공을 세 번이나 물어 왔다.\n주인이 웃어서 꼬리가 멈추질 않았다.',
                  style: C3Text.pet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: () {}, child: const Text('저장')),
              OutlinedButton(onPressed: () {}, child: const Text('취소')),
              TextButton(onPressed: () {}, child: const Text('나중에')),
              const FilledButton(onPressed: null, child: Text('비활성')),
            ],
          ),
          const SizedBox(height: 14),
          const TextField(
            decoration: InputDecoration(labelText: '이름', hintText: '콩이'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('알림 받기'),
            subtitle: const Text('하루 두 번까지'),
            value: _notify,
            onChanged: (v) => setState(() => _notify = v),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('아기')),
              ButtonSegment(value: 1, label: Text('성체')),
            ],
            selected: {_age},
            onSelectionChanged: (s) => setState(() => _age = s.first),
          ),
          const SizedBox(height: 16),
          const LinearProgressIndicator(value: .6),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => showC3Dialog<void>(
              context,
              title: '콩이가 기다렸어요',
              body: const Text('6시간 만이에요. 밥그릇이 비어 있어요.'),
            ),
            child: const Text('다이얼로그 보기'),
          ),
        ],
      ),
    );
  }

  Widget _book() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final name in _icons)
                SizedBox(
                  width: 50,
                  child: Column(
                    children: [
                      PixelIcon(name, scale: 3),
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: C3Fonts.jua,
                          fontFamilyFallback: C3Fonts.fallback,
                          fontSize: 11,
                          color: C3Colors.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StickerButton(
                cut: 'palm',
                icon: 'palm',
                label: '쓰다듬기',
                tilt: -2,
                onTap: () {},
              ),
              StickerButton(
                cut: 'tree',
                icon: 'tree',
                label: '산책 가기',
                tilt: 2,
                highlighted: true,
                onTap: () {},
              ),
              const StickerButton(
                cut: 'box',
                icon: 'box',
                label: '비활성',
                tilt: 1.5,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const GaugeSticker(
                icon: 'smile',
                label: '기분',
                value: 0,
                colors: GaugeColors.mood,
              ),
              const GaugeSticker(
                icon: 'heart',
                label: '친밀도',
                value: 100,
                colors: GaugeColors.bond,
                tilt: -3,
              ),
              StampButton(onTap: () {}),
              const StampButton(enabled: false),
            ],
          ),
          const SizedBox(height: 22),
          MemoInput(
            controller: _memo,
            hint: '듣고 있어요…',
            listening: true,
            onMic: () {},
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              Tape(width: 70, height: 22, color: C3Colors.tapeSky, angle: -4),
              Tape(width: 70, height: 22, color: C3Colors.tapeMint, angle: 3),
              Tape(
                width: 70,
                height: 22,
                color: C3Colors.tapePink,
                pattern: TapePattern.dots,
              ),
              Tape(
                width: 70,
                height: 22,
                color: C3Colors.tapeYellow,
                pattern: TapePattern.plain,
                angle: -2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 목업 방 배경 자리표시. 실제 방은 게임 캔버스가 그린다.
class _Room extends StatelessWidget {
  const _Room();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final think = Offset(box.maxWidth / 2 - 130, box.maxHeight - 192 - 150);
        final body = (think + const Offset(9, 5)) & cloudBodyReference;
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RoomPainter(body, think + const Offset(173, 141)),
              ),
            ),
            Positioned.fromRect(
              rect: cloudBodyPadding.deflateRect(body),
              child: const Center(
                child: Text(
                  '비 오는 소리…\n오늘은 옆에 붙어 있을래.',
                  textAlign: TextAlign.center,
                  style: C3Text.pet,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoomPainter extends CustomPainter {
  const _RoomPainter(this.cloud, this.tail);

  final Rect cloud;
  final Offset tail;

  @override
  void paint(Canvas canvas, Size size) {
    paintRoomBackdrop(
      canvas,
      size,
      floorY: size.height - 118,
      rug: Rect.fromLTWH(size.width / 2 - 108, size.height - 72, 216, 58),
    );
    paintThoughtCloud(canvas, cloud, tail, aiTag: true);
  }

  @override
  bool shouldRepaint(_RoomPainter old) =>
      old.cloud != cloud || old.tail != tail;
}
