import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/sprite_art.dart';
import '../pet/friends.dart';
import '../pet/josa.dart';
import '../pet/guest.dart';
import '../pet/treats.dart';
import '../pet/pet_controller.dart';
import '../pet/pet_rules.dart';
import '../pet/shapes.dart';
import 'c3/c3_theme.dart';
import 'c3/sticker_card.dart';
import 'known_dog_screen.dart';

/// 손님 얼굴. 그 애 색으로 칠한 시트의 서 있는 첫 칸을 정수배로 키워 그린다.
class GuestFace extends StatefulWidget {
  const GuestFace(
    this.guest, {
    super.key,
    this.box = 56,
    this.dim = false,
    this.cache = true,
  });

  final Guest guest;
  final double box;

  /// 아직 못 만난 애. 흐리게.
  final bool dim;

  /// 데려오기 화면의 미리보기처럼 고를 때마다 바뀌는 얼굴은 앱이 켜져 있는 내내 남기지 않는다.
  final bool cache;

  @visibleForTesting
  static int get paintedCount => _GuestFaceState._painted.length;

  /// 위젯 테스트는 테스트마다 시계(zone)가 따로라, 앞 테스트에서 시작한 칠하기가 끝나지 않은 채 남는다.
  @visibleForTesting
  static void resetCache() {
    _GuestFaceState._painted.clear();
    _GuestFaceState._sheets.clear();
  }

  @override
  State<GuestFace> createState() => _GuestFaceState();
}

class _GuestFaceState extends State<GuestFace> {
  static final _painted = <String, Future<ui.Image>>{};
  static final _sheets = <String, Future<ui.Image>>{};
  String? _ownKey;
  Future<ui.Image>? _own;

  @override
  Widget build(BuildContext context) {
    final g = widget.guest;
    // 생김새까지 키에 넣는다. 아는 강아지는 모습을 고칠 수 있다.
    final key =
        '${g.id}_${g.shape}_${g.main}_${g.second}_${g.marking}_${g.accent}_${g.puppy}';
    final Future<ui.Image> image;
    if (widget.cache) {
      image = _painted[key] ??= _paint(g);
    } else {
      if (_ownKey != key) {
        _ownKey = key;
        _own = _paint(g);
      }
      image = _own!;
    }
    return Opacity(
      opacity: widget.dim ? 0.35 : 1,
      child: SizedBox.square(
        dimension: widget.box,
        child: FutureBuilder<ui.Image>(
          future: image,
          builder: (context, snap) => snap.data == null
              ? const SizedBox()
              : CustomPaint(painter: _FacePainter(snap.data!)),
        ),
      ),
    );
  }

  static Future<ui.Image> _paint(Guest g) async {
    final asset =
        'assets/${spriteAsset(g.shape, g.puppy ? PetStage.puppy : PetStage.adult)}';
    final sheet = await (_sheets[asset] ??= _decode(asset));
    final (image, _) = await paintSheet(
      sheet,
      main: g.main,
      second: g.second,
      accent: g.accent,
      marking: g.marking,
    );
    return image;
  }

  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.sheet);

  final ui.Image sheet;

  @override
  void paint(Canvas canvas, Size size) {
    const frame = spriteFrame * 1.0;
    final k = (size.shortestSide / frame).floorToDouble().clamp(1.0, 8.0);
    final dst = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: frame * k,
      height: frame * k,
    );
    canvas.drawImageRect(
      sheet,
      const Rect.fromLTWH(0, 0, frame, frame),
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.sheet != sheet;
}

/// 도감의 친구 칸. 만난 애는 얼굴·이름·사이, 못 만난 애는 흐린 얼굴과 물음표.
/// 주인이 데려온 아는 강아지는 만나기 전에도 얼굴과 이름을 보여 준다.
class FriendTile extends StatelessWidget {
  const FriendTile({super.key, required this.controller, required this.guest});

  final PetController controller;
  final Guest guest;

  @override
  Widget build(BuildContext context) {
    final f = controller.friends[guest.id];
    final met = f != null && f.bond != Bond.none;
    final known = controller.isKnownDog(guest.id);
    final shown = met || known;
    return GestureDetector(
      onTap: shown ? () => showFriendDialog(context, controller, guest) : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: shown ? C3Colors.card : C3Colors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: shown ? null : Border.all(color: C3Colors.line, width: 1.2),
          boxShadow: shown
              ? const [
                  BoxShadow(
                    color: Color.fromRGBO(98, 72, 50, .16),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Column(
            children: [
              Expanded(
                child: Center(child: GuestFace(guest, box: 44, dim: !shown)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  shown ? friendName(guest, f) : '?',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: C3Text.label.copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  met
                      ? bondLabel(f.bond)
                      : known
                      ? '아직 못 만남'
                      : '카페에서',
                  maxLines: 1,
                  style: C3Text.body.copyWith(
                    fontSize: 12,
                    color: C3Colors.ink3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 친구 카드. 얼굴, 사이 네 칸, 만난 날 수, 이름 붙이기. 아는 강아지는 '모습 고치기'도.
Future<void> showFriendDialog(
  BuildContext context,
  PetController c,
  Guest guest,
) {
  final input = TextEditingController(text: c.friends[guest.id]?.name ?? '');
  // 모습을 고치면 새 그림으로 보여야 해서 그때그때 컨트롤러에서 다시 찾는다.
  Guest current() =>
      c.knownDogs.where((g) => g.id == guest.id).firstOrNull ?? guest;
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: StickerCard(
        tape: C3Colors.tapeSky,
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => FriendCard(
            guest: current(),
            friendship: c.friends[guest.id] ?? const Friendship(),
            input: input,
            nameRequired: c.isKnownDog(guest.id),
            onSave: () async {
              await c.nameFriend(guest.id, input.text);
              if (context.mounted) Navigator.of(context).pop();
            },
            onClose: () => Navigator.of(context).pop(),
            share: c.canShareWith(guest.id)
                ? treatById(c.pouch.first)?.name
                : null,
            onShare: () {
              c.shareTreat(guest.id);
              Navigator.of(context).pop();
            },
            onEdit: c.isKnownDog(guest.id)
                ? () async {
                    final removed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            KnownDogScreen(controller: c, dog: current()),
                      ),
                    );
                    if (!context.mounted) return;
                    if (removed == true) {
                      Navigator.of(context).pop();
                    } else {
                      input.text = c.friends[guest.id]?.name ?? '';
                    }
                  }
                : null,
          ),
        ),
      ),
    ),
  ).whenComplete(input.dispose);
}

class FriendCard extends StatelessWidget {
  const FriendCard({
    super.key,
    required this.guest,
    required this.friendship,
    required this.input,
    required this.onSave,
    required this.onClose,
    this.onEdit,
    this.nameRequired = false,
    this.share,
    this.onShare,
  });

  final Guest guest;
  final Friendship friendship;
  final TextEditingController input;
  final VoidCallback onSave;
  final VoidCallback onClose;

  /// 아는 강아지만: 모습 고치기 화면을 연다.
  final VoidCallback? onEdit;

  /// 아는 강아지는 주인이 지어 데려온 이름이라 비우고 저장할 수 없다.
  final bool nameRequired;

  /// 카페에서 지금 나눠 줄 수 있는 간식 이름. 없으면 버튼을 숨긴다.
  final String? share;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final f = friendship;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(friendName(guest, f), style: C3Text.title),
                const SizedBox(height: 10),
                Center(child: GuestFace(guest, box: 96)),
                const SizedBox(height: 6),
                Text(
                  f.name == null ? '아직 이름이 없어요' : guest.look,
                  textAlign: TextAlign.center,
                  style: C3Text.body.copyWith(
                    fontSize: 14,
                    color: C3Colors.ink2,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final b in Bond.values.skip(1))
                      _BondDot(
                        label: bondLabel(b),
                        on: f.bond.index >= b.index,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  f.days == 0 ? '아직 카페에서 못 만났어요' : '카페에서 ${f.days}번 만났어요',
                  textAlign: TextAlign.center,
                  style: C3Text.body.copyWith(
                    fontSize: 13,
                    color: C3Colors.ink3,
                  ),
                ),
                if (share case final s? when onShare != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: onShare,
                    child: Text('${josa(s, '을/를')} 나눠 주기'),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: input,
                  maxLength: 10,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!nameRequired || cleanFriendName(input.text) != null) {
                      onSave();
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: '이름 붙이기',
                    hintText: '일기에서 이 이름으로 불러요',
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onEdit case final edit?)
              TextButton(onPressed: edit, child: const Text('모습 고치기')),
            TextButton(onPressed: onClose, child: const Text('닫기')),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: input,
              builder: (context, v, _) => FilledButton(
                onPressed: nameRequired && cleanFriendName(v.text) == null
                    ? null
                    : onSave,
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BondDot extends StatelessWidget {
  const _BondDot({required this.label, required this.on});

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: on ? C3Colors.tapePink : C3Colors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? C3Colors.stamp : C3Colors.line),
      ),
      child: Text(
        label,
        style: C3Text.label.copyWith(
          fontSize: 12,
          color: on ? C3Colors.ink : C3Colors.hint,
        ),
      ),
    );
  }
}
