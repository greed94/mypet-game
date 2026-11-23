import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../pet/checkup.dart';
import '../pet/door_news.dart';
import '../pet/friends.dart';
import '../pet/guest.dart';
import '../pet/kindergarten.dart';
import '../pet/pet_controller.dart';
import '../pet/pet_rules.dart';
import '../pet/shapes.dart';
import '../pet/spots.dart';
import '../pet/sky.dart';
import '../pet/treasure.dart';
import '../pet/treats.dart';
import '../pet/wish.dart';
import '../services/weather.dart';
import '../ui/keep_words.dart';
import '../ui/c3/c3_theme.dart';
import '../ui/c3/thought_cloud.dart';
import 'sprite_art.dart';

const _frame = 32.0;
const _prop = 16.0;

class PetGame extends FlameGame {
  PetGame(this.controller);

  final PetController controller;

  /// 방 문을 탭했을 때. 홈 화면이 동네 지도를 띄운다.
  VoidCallback? onDoorTap;

  /// 방이 짧으면 Flutter 사진 캡션이 같은 속마음을 보여 준다.
  bool showThoughtInRoom = true;

  /// 버튼으로도 드래그와 같은 물리 동작을 실행한다. 강아지 앞 여유가 있는 쪽으로 던진다.
  void tossBall() =>
      _ball?.fling(Vector2(controller.petX > .5 ? -520 : 520, -1000));

  /// 카페 손님을 탭했을 때. 홈 화면이 친구 카드를 띄운다.
  void Function(Guest guest)? onGuestTap;

  /// 손님이 있는 곳(카페·유치원)은 바닥을 넓혀 손님(뒷줄)과 펫(앞줄)이 덜 겹치게 한다.
  /// 펫이 손님보다 훨씬 커서 바닥이 얇으면 펫 머리가 손님을 가린다. 집은 원룸처럼 아늑하게 둔다.
  double get floorTop =>
      size.y *
      (const {Spot.cafe, Spot.kindergarten}.contains(controller.spot)
          ? 0.52
          : 0.7);
  double get petBaseline => size.y - max(16.0, size.y * 0.06);

  double _tallest = 0;
  int _loadedVersion = -1;
  bool _loading = false;
  late final SpriteSheet _props;
  late final SpriteSheet _items;

  /// 배변 패드와 쉬 자국. 방 바닥에 그린다.
  late final Sprite pad, puddle;
  _PetSprite? _sprite;
  _ThoughtBubble? _bubble;
  _Ball? _ball;

  /// 카페 손님. 시트는 한 번 칠해 두고 다시 쓴다. 집에 오면 치운다.
  final Map<String, SpriteSheet> _guestSheets = {};
  final Map<String, Future<SpriteSheet>> _guestSheetLoads = {};
  _DreamBubble? _dream;
  _WishBubble? _wish;
  final List<_GuestSprite> _guests = [];
  bool _guestsLoading = false;
  int _placeGen = 0;

  /// 지금 앉힌 손님들(그림 키). 아는 강아지를 고치거나 지워 손님 목록이 바뀌면 다시 앉힌다.
  String? _seated;

  /// 정수 배율이어야 픽셀이 뭉개지지 않는다. 키보드가 올라와 화면이 줄어도 펫 크기가
  /// 흔들리지 않게, 키보드가 없을 때의 높이를 기준으로 한다.
  double get pixelScale => (min(_tallest * 0.44, size.x * 0.5) / _frame)
      .floorToDouble()
      .clamp(2, 12);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final keyboard =
        ui.PlatformDispatcher.instance.implicitView?.viewInsets.bottom ?? 0;
    if (keyboard == 0 || size.y > _tallest) _tallest = size.y;
  }

  /// 강아지 몸은 프레임 가운데 3/4쯤만 차므로 여백을 프레임 절반보다 좁게 잡아야 문 앞까지 간다.
  double floorX(double fraction) {
    final margin = _frame * pixelScale * 0.36;
    return margin + fraction * (size.x - margin * 2);
  }

  double floorFraction(double x) {
    final margin = _frame * pixelScale * 0.36;
    return ((x - margin) / (size.x - margin * 2)).clamp(0, 1);
  }

  /// 손님은 뒤쪽 쿠션에 앉아 있어서 펫보다 작게(정수 배율), 바닥 안쪽에 그린다.
  double get guestScale => max(2, pixelScale - 2).toDouble();
  double get seatBase => floorTop + (petBaseline - floorTop) * 0.12;

  // 방 배치. 방 그림과 방 칸 물건이 같은 자리를 써야 해서 여기 모은다.
  double get _doorW => max(64.0, size.x * 0.24);
  Rect get doorRect {
    final h = size.y * 0.36;
    return Rect.fromLTWH(floorX(doorX) - _doorW / 2, floorTop - h, _doorW, h);
  }

  /// 아침 현관 물건(우산·마스크·목도리). 소품 시트 7번째 칸부터.
  Sprite doorProp(DoorItem i) => _props.getSprite(0, 6 + i.index);

  /// 현관 물건이 놓이는 칸. 문 발치 안쪽 바닥(방에 둔 물건 줄)에 둔다.
  /// 펫이 다니는 앞쪽 바닥이 아니라서 아래쪽 스티커(패드로)에 가리지 않고, 문 왼쪽이라 바닥 1번 칸 물건에 닿지 않는다.
  Rect get doorItemRect {
    final s = _prop * pixelScale;
    final y = floorTop + (petBaseline - floorTop) * 0.3;
    return Rect.fromLTWH(floorX(doorX - 0.05) - s / 2, y - s, s, s);
  }

  /// 방석(러그). 펫 발밑에 깔린 타원. 누르면 숨긴 게 있는 펫이 달려와 깔고 앉는다.
  Rect get rugRect => Rect.fromCenter(
    center: Offset(size.x * 0.5, petBaseline - 6),
    width: min(size.x * 0.66, pixelScale * _frame * 1.4),
    height: max(34.0, size.y * 0.12),
  );

  Rect get windowRect {
    final w = size.x * 0.36;
    return Rect.fromLTWH(
      size.x - w - size.x * 0.06,
      size.y * 0.1,
      w,
      size.y * 0.24,
    );
  }

  /// 문 위 선반. 문틀 위로 조금 띄워 건다.
  Rect get shelfRect {
    final d = doorRect;
    return Rect.fromLTWH(
      d.left - 10,
      d.top - 7 - size.y * 0.13,
      d.width + 20,
      6,
    );
  }

  /// 방 칸 물건 칸(16×16)의 아래 가운데가 닿는 자리. 선반·창턱은 가구 폭 안에서 나눠 화분과 겹치지 않게 둔다.
  Offset slotBase(Slot slot) {
    final shelf = shelfRect, win = windowRect;
    return switch (slot.id) {
      'shelf1' => Offset(shelf.left + shelf.width * 0.3, shelf.top),
      'shelf2' => Offset(shelf.left + shelf.width * 0.72, shelf.top),
      'sill1' => Offset(win.left + win.width * 0.16, win.bottom),
      'sill2' => Offset(win.left + win.width * 0.44, win.bottom),
      _ => Offset(
        floorX(slot.walkX),
        floorTop + (petBaseline - floorTop) * 0.3,
      ),
    };
  }

  Sprite? itemSprite(String id) {
    final item = itemById(id);
    if (item == null) return null;
    final i = itemIndex(item);
    return _items.getSprite(i ~/ 10, i % 10);
  }

  @override
  Color backgroundColor() => const Color(0xFFF7E5D6);

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/';
    add(_Room());
    add(_Door());
    _props = SpriteSheet(
      image: await images.load('sprites/props.png'),
      srcSize: Vector2.all(_prop),
    );
    pad = _props.getSprite(0, 3);
    puddle = _props.getSprite(0, 4);
    _items = SpriteSheet(
      image: await images.load('items/items.png'),
      srcSize: Vector2.all(_prop),
    );
    add(_Decor());
    add(_Hand(await images.load('ui/palm.png')));
    add(_DoorItem());
    add(_ball = _Ball(controller));
    add(_Fling());
    add(_Cctv());
    await _loadSprite();
  }

  Future<void> _loadSprite() async {
    _loading = true;
    final pet = controller.pet;
    final raw = await images.load(spriteAsset(pet.shape, pet.stage));
    final (image, mouths) = await paintSheet(
      raw,
      main: pet.furMain,
      second: pet.furSecond,
      accent: pet.accent,
      marking: pet.marking,
    );
    final sheet = SpriteSheet(image: image, srcSize: Vector2.all(_frame));
    _sprite?.removeFromParent();
    _bubble?.removeFromParent();
    final sprite = _PetSprite(
      controller,
      sheet,
      mouths,
      _props,
      startX: _sprite?._x ?? controller.petX,
    );
    add(sprite);
    add(_bubble = _ThoughtBubble(controller, sprite));
    _dream?.removeFromParent();
    add(_dream = _DreamBubble(sprite));
    _wish?.removeFromParent();
    add(_wish = _WishBubble(sprite));
    _sprite = sprite;
    _loadedVersion = controller.spriteVersion;
    _loading = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    controller.tick(dt);
    // 아기가 성체가 되면 다른 그림을 읽는다.
    if (!_loading && _loadedVersion != controller.spriteVersion) {
      unawaited(_loadSprite());
    }
    if (controller.out) {
      final want = controller.guests.map(_sheetKey).join('|');
      if (want != _seated && !_guestsLoading) {
        _clearGuests();
        _seated = want;
        if (controller.guests.isNotEmpty) unawaited(_seatGuests());
      }
    } else if (_seated != null) {
      _clearGuests();
      _seated = null;
    }
  }

  void _clearGuests() {
    _placeGen++;
    for (final g in _guests) {
      g.removeFromParent();
    }
    _guests.clear();
  }

  Future<void> _seatGuests() async {
    _guestsLoading = true;
    final gen = _placeGen;
    final guests = controller.guests;
    final seats = seatsFor(guests.length);
    // 유치원 친구들은 제 자리 둘레를 뛰어다닌다. 카페 손님은 쿠션에 있는다.
    final roam = controller.spot == Spot.kindergarten ? 0.14 : 0.0;
    for (final (i, g) in guests.indexed) {
      final sheet = await _guestSheet(g);
      // 시트를 칠하는 사이 집에 갔으면 앉히지 않는다.
      if (gen != _placeGen || !controller.out) break;
      final sprite = _GuestSprite(
        GuestMind(Random(g.id.hashCode), seat: seats[i], roam: roam),
        sheet,
        g,
        i,
      );
      add(sprite);
      _guests.add(sprite);
    }
    _guestsLoading = false;
  }

  /// 생김새까지 넣는다. 아는 강아지는 주인이 모습을 고칠 수 있어 id만으로는 옛 그림이 남는다.
  static String _sheetKey(Guest g) =>
      '${g.id}_${g.shape}_${g.main}_${g.second}_${g.marking}_${g.accent}_${g.puppy ? 'puppy' : 'adult'}';

  /// 손님 시트. 같은 손님을 동시에 두 번 칠하지 않는다.
  Future<SpriteSheet> _guestSheet(Guest g) => _guestSheetLoads[_sheetKey(g)] ??=
      _paintGuest(g).then((s) => _guestSheets[_sheetKey(g)] = s);

  Future<SpriteSheet> _paintGuest(Guest g) async {
    final stage = g.puppy ? PetStage.puppy : PetStage.adult;
    final raw = await images.load(spriteAsset(g.shape, stage));
    final (image, _) = await paintSheet(
      raw,
      main: g.main,
      second: g.second,
      accent: g.accent,
      marking: g.marking,
    );
    return SpriteSheet(image: image, srcSize: Vector2.all(_frame));
  }
}

/// 방 문. 탭하면 동네 지도가 뜬다. 산책·카페 중엔 없다. 펫이 문 앞에 서 있으면 펫(우선순위 높음)이 먼저 받는다.
class _Door extends PositionComponent
    with TapCallbacks, HasGameReference<PetGame> {
  @override
  void update(double dt) {
    final c = game.controller;
    if (c.walking || c.out || c.replaying) {
      size.setZero();
      return;
    }
    final r = game.doorRect;
    position.setValues(r.left, r.top);
    size.setValues(r.width, r.height);
  }

  @override
  void onTapDown(TapDownEvent event) => game.onDoorTap?.call();
}

class _Room extends Component with HasGameReference<PetGame> {
  double _t = 0;
  final _paint = Paint();
  final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final c = game.controller;
    if (c.walking) {
      _renderOutdoor(canvas);
      return;
    }
    switch (c.spot) {
      case Spot.cafe:
        _renderCafe(canvas);
      case Spot.kindergarten:
        _renderKindergarten(canvas);
      case Spot.treatShop:
        _renderShop(canvas);
      case Spot.hospital:
        _renderHospital(canvas);
      default:
        _renderRoom(canvas);
    }
  }

  void _rect(Canvas canvas, Rect r, int color) =>
      canvas.drawRect(r, _paint..color = Color(color));

  /// 문틀과 창 사이 벽에 붙인 도장판. 폭이 좁은 폰에서도 문틀·창턱과 겹치지 않게 칸 크기를 남는 폭에 맞춘다.
  /// 창턱은 창틀보다 양옆으로 8, 아래로 15 나와 있다(_renderRoom의 sill).
  void _renderStampCard(Canvas canvas, Rect casing, Rect win, int stamps) {
    const gap = 4.0;
    final right = win.left - 8;
    final room = right - casing.right - 8;
    final fit = (room - gap * 5) / 4;
    // 아주 좁은 화면이면 칸이 너무 작아져 문틀에 걸친다. 그럴 땐 붙이지 않는다.
    if (fit < 6) return;
    final cell = min(fit, 12.0);
    final height = cell * 2 + gap * 3 + 4;
    final card = Rect.fromLTWH(
      (casing.right + right) / 2 - (cell * 4 + gap * 5) / 2,
      max(win.bottom + 15 + 6, casing.top + casing.height * 0.18),
      cell * 4 + gap * 5,
      height,
    );
    _box(canvas, card, 0xFFFFFDF8, 0xFFDDC9B0, 2);
    _rect(
      canvas,
      Rect.fromCenter(
        center: Offset(card.center.dx, card.top),
        width: cell * 1.6,
        height: 6,
      ),
      0xCCF7E196,
    );
    for (var i = 0; i < 8; i++) {
      final o = Offset(
        card.left + gap + (i % 4) * (cell + gap) + cell / 2,
        card.top + 4 + gap + (i ~/ 4) * (cell + gap) + cell / 2,
      );
      if (i >= stamps) {
        canvas.drawCircle(o, cell / 2, _paint..color = const Color(0xFFEFE3D3));
        continue;
      }
      canvas.drawCircle(o, cell / 2, _paint..color = const Color(0xFFE8584A));
      final k = cell / 12;
      _paint.color = const Color(0xFFFFFDF8);
      canvas.drawCircle(o.translate(0, 1.5 * k), 2.2 * k, _paint);
      for (final (dx, dy) in const [(-2.6, -2.0), (0.0, -3.2), (2.6, -2.0)]) {
        canvas.drawCircle(o.translate(dx * k, dy * k), 1.1 * k, _paint);
      }
    }
  }

  void _box(Canvas canvas, Rect r, int fill, int border, double width) {
    _rect(canvas, r, border);
    _rect(canvas, r.deflate(width), fill);
  }

  void _renderRoom(Canvas canvas) {
    final w = game.size.x, h = game.size.y, floor = game.floorTop;
    // 홈캠 다시보기 중엔 그 장면 시각의 하늘·밤빛으로.
    final c = game.controller;
    final hour = (c.replayMoment?.at ?? c.now()).hour;
    final sky = game.controller.weather?.sky;

    _rect(canvas, Rect.fromLTWH(0, 0, w, floor), 0xFFF7E5D6);
    for (var x = 22.0; x < w; x += 24) {
      _rect(canvas, Rect.fromLTWH(x, 0, 2, floor), 0xFFF2DCCA);
    }
    _rect(canvas, Rect.fromLTWH(0, 0, w, 8), 0xFFEDD2BD);
    _rect(canvas, Rect.fromLTWH(0, floor, w, h - floor), 0xFFEED5B7);
    for (var y = floor + 22; y < h; y += 24) {
      _rect(canvas, Rect.fromLTWH(0, y, w, 2), 0xFFE3C4A2);
    }

    final door = game.doorRect;
    final doorW = door.width, doorH = door.height, doorLeft = door.left;
    final casing = Rect.fromLTWH(
      doorLeft - 7,
      floor - doorH - 7,
      doorW + 14,
      doorH + 7,
    );
    _rect(canvas, casing, 0xFFE2CBB5);
    _rect(
      canvas,
      Rect.fromLTRB(casing.left + 3, casing.top + 3, casing.right - 3, floor),
      0xFFFFF9F1,
    );
    _box(canvas, door, 0xFFBFE1CF, 0xFF9FCBB4, 4);
    for (final (top, height) in [(0.07, 0.33), (0.61, 0.31)]) {
      final panel = Rect.fromLTWH(
        door.left + 8,
        door.top + doorH * top,
        doorW - 16,
        doorH * height,
      );
      _box(canvas, panel, 0xFFBFE1CF, 0xFFA9D5BF, 3);
    }
    _box(
      canvas,
      Rect.fromLTWH(door.right - 18, door.top + doorH * 0.49, 10, 10),
      0xFFF2C46B,
      0xFFD29E47,
      2,
    );

    _rect(canvas, Rect.fromLTWH(0, floor - 12, w, 12), 0xFFE4C6AB);
    _rect(canvas, Rect.fromLTWH(0, floor - 12, w, 3), 0xFFD6B393);

    // 발표회 도장판. 도장을 받으면 문과 창 사이 벽에 붙는다. 여덟 칸, 넘치면 최근 여덟 개만.
    final stamps = min(c.recitalStamps.length, 8);
    if (stamps > 0) _renderStampCard(canvas, casing, game.windowRect, stamps);

    final win = game.windowRect;
    final winW = win.width;
    _box(canvas, win, 0xFFFFFDF8, 0xFFE2CBB5, 3);
    final glass = win.deflate(8);
    _renderSky(canvas, glass, hour, sky);
    _rect(
      canvas,
      Rect.fromLTWH(glass.center.dx - 2.5, glass.top, 5, glass.height),
      0xFFFFFDF8,
    );
    _rect(
      canvas,
      Rect.fromLTWH(glass.left, glass.center.dy - 2.5, glass.width, 5),
      0xFFFFFDF8,
    );
    final sill = Rect.fromLTWH(win.left - 8, win.bottom, winW + 16, 15);
    _rect(canvas, sill, 0xFFE2CBB5);
    _rect(
      canvas,
      Rect.fromLTWH(sill.left, sill.top, sill.width, 12),
      0xFFFFFDF8,
    );
    _renderPot(canvas, Offset(win.right - 22, win.bottom));

    final shelf = game.shelfRect;
    for (final x in [shelf.left + 8, shelf.right - 12]) {
      _rect(canvas, Rect.fromLTWH(x, shelf.bottom, 4, 8), 0xFFD6B393);
    }
    _rect(canvas, shelf, 0xFFE2CBB5);
    _rect(
      canvas,
      Rect.fromLTWH(shelf.left, shelf.top, shelf.width, 3),
      0xFFFFF9F1,
    );

    final rug = game.rugRect;
    final rugColors = c.rug.colors;
    canvas.drawOval(rug, _paint..color = Color(rugColors[0]));
    canvas.drawOval(rug.deflate(5), _paint..color = Color(rugColors[1]));
    canvas.drawOval(rug.deflate(12), _paint..color = Color(rugColors[2]));

    // 패드는 늘 구석에 깔려 있고, 쉬 자국은 실수한 자리에 잠시 남는다. 둘 다 강아지 발 높이에 맞춘다.
    final k = game.pixelScale;
    final cell = Vector2.all(_prop * k);
    game.pad.render(
      canvas,
      position: Vector2(
        game.floorX(padX) - cell.x / 2,
        game.petBaseline - 13 * k,
      ),
      size: cell,
    );
    if (game.controller.puddleX case final px?) {
      game.puddle.render(
        canvas,
        position: Vector2(
          game.floorX(px) - cell.x / 2,
          game.petBaseline - 13 * k,
        ),
        size: cell,
      );
    }

    if (hour >= 20 || hour < 6) {
      _rect(canvas, Rect.fromLTWH(0, 0, w, h), 0x33202850);
    }
  }

  void _renderSky(Canvas canvas, Rect glass, int hour, Sky? sky) {
    canvas.save();
    canvas.clipRect(glass);
    final color = _skyColor(hour, sky);
    _rect(canvas, glass, color);
    if (sky == Sky.rain) {
      _rect(
        canvas,
        Rect.fromLTWH(glass.left, glass.center.dy, glass.width, glass.height),
        0xFFB9CBE3,
      );
    }
    if ((hour >= 20 || hour < 6) && sky != Sky.rain && sky != Sky.snow) {
      _renderMoon(canvas, glass, color);
    }
    if (sky == Sky.cloudy || sky == Sky.rain || sky == Sky.snow) {
      _paint.color = const Color(0xFFCDD8E8);
      for (final (x, y, cw) in [(0.08, 0.1, 0.34), (0.58, 0.2, 0.3)]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              glass.left + glass.width * x,
              glass.top + glass.height * y,
              glass.width * cw,
              9,
            ),
            const Radius.circular(5),
          ),
          _paint,
        );
      }
    }
    _renderPrecipitation(canvas, glass, sky, dense: false);
    _renderPasser(canvas, glass);
    if (game.controller.noseOnWindow) _renderNose(canvas, glass);
    canvas.restore();
  }

  /// 어제 만난 친구가 창밖을 지나간다. 걷는 줄 그림을 창 아래쪽에 작게, 왼쪽에서 오른쪽으로.
  void _renderPasser(Canvas canvas, Rect glass) {
    final c = game.controller;
    final passer = c.windowPasser;
    final p = c.windowPassProgress;
    if (passer == null || p == null) return;
    final sheet = game._guestSheets[PetGame._sheetKey(passer)];
    if (sheet == null) {
      unawaited(game._guestSheet(passer));
      return;
    }
    final k = max(1, (glass.height * 0.7 / _frame).floor()).toDouble();
    final size = _frame * k;
    final x = glass.left - size + (glass.width + size * 2) * p;
    sheet
        .getSprite(1, (_t * 7).floor() % 4)
        .render(
          canvas,
          position: Vector2(x, glass.bottom - size + 2),
          size: Vector2.all(size),
        );
  }

  /// 실제 달 모양. 밝은 쪽 반원에 세로로 긴 타원을 더하거나(볼록달) 빼서(초승달) 명암 경계를 만든다.
  void _renderMoon(Canvas canvas, Rect glass, int skyColor) {
    final p = moonPhase(game.controller.now());
    final r = min(glass.width, glass.height) * 0.14;
    final c = Offset(
      glass.left + glass.width * 0.28,
      glass.top + glass.height * 0.3,
    );
    final curve = cos(2 * pi * p);
    // 삭 무렵에는 보이지 않는다.
    if (curve > 0.95) return;
    final waxing = p < 0.5;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    _rect(
      canvas,
      Rect.fromLTRB(
        waxing ? c.dx : c.dx - r,
        c.dy - r,
        waxing ? c.dx + r : c.dx,
        c.dy + r,
      ),
      0xFFFFF3C4,
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 2 * r * curve.abs(), height: 2 * r),
      _paint..color = Color(curve < 0 ? 0xFFFFF3C4 : skyColor),
    );
    canvas.restore();
  }

  /// 첫눈 날 창문에 남은 코 자국과 입김.
  void _renderNose(Canvas canvas, Rect glass) {
    final c = Offset(
      glass.left + glass.width * 0.3,
      glass.bottom - glass.height * 0.22,
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 30, height: 18),
      _paint..color = const Color(0x66FFFFFF),
    );
    _paint.color = const Color(0x554B3A2F);
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(-4, 1), width: 4, height: 3),
      _paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(4, 1), width: 4, height: 3),
      _paint,
    );
  }

  void _renderPot(Canvas canvas, Offset bottomRight) {
    final pot = Rect.fromLTWH(bottomRight.dx - 18, bottomRight.dy - 16, 18, 16);
    for (final (dx, dy, lw, lh) in [
      (-4.0, -28.0, 10.0, 10.0),
      (6.0, -34.0, 10.0, 14.0),
      (14.0, -26.0, 10.0, 8.0),
    ]) {
      _box(
        canvas,
        Rect.fromLTWH(pot.left + dx, pot.bottom + dy, lw, lh),
        0xFF8FD0A3,
        0xFF63AE7D,
        2,
      );
    }
    _box(canvas, pot, 0xFFEFA98F, 0xFFD08468, 2);
  }

  void _renderOutdoor(Canvas canvas) {
    final w = game.size.x, h = game.size.y, floor = game.floorTop;
    final hour = game.controller.now().hour;
    final sky = game.controller.weather?.sky;

    _rect(canvas, Rect.fromLTWH(0, 0, w, floor), _skyColor(hour, sky));
    if (sky == null || sky == Sky.clear) {
      canvas.drawCircle(
        Offset(w * 0.8, h * 0.12),
        22,
        _paint..color = const Color(0xFFFFE08A),
      );
    }
    _paint.color = const Color(0xD9FFFFFF);
    for (var i = 0; i < 3; i++) {
      final x = (w * 0.3 * i + _t * 12) % (w + 120) - 60;
      final y = h * (0.08 + 0.06 * i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: 84, height: 24),
          const Radius.circular(12),
        ),
        _paint,
      );
    }
    _renderPrecipitation(
      canvas,
      Rect.fromLTWH(0, 0, w, floor),
      sky,
      dense: true,
    );

    _paint.color = const Color(0xFFCFE8D5);
    for (var i = -1; i < 4; i++) {
      final x = (i * w * 0.45 - (_t * 8) % (w * 0.45));
      canvas.drawOval(
        Rect.fromLTWH(x, floor - h * 0.08, w * 0.6, h * 0.16),
        _paint,
      );
    }
    _rect(canvas, Rect.fromLTWH(0, floor, w, h - floor), 0xFFBFE5C8);
    _rect(canvas, Rect.fromLTWH(0, floor, w, 5), 0xFFA9DDB8);
    final pathTop = game.petBaseline - 12;
    _rect(canvas, Rect.fromLTWH(0, pathTop, w, 30), 0xFFF1DDBF);
    for (var i = -1; i < 8; i++) {
      final x = (i * 90 - (_t * 60) % 90);
      _rect(canvas, Rect.fromLTWH(x, pathTop + 12, 40, 5), 0xFFE6CBA5);
    }
  }

  /// 동네 강아지 카페. 집보다 진한 나무색이라 다른 곳에 왔다는 게 한눈에 보인다.
  /// 카운터는 강아지 눈높이라 키가 크다. 밤엔 불이 낮고 탁상등만 켜 둔다.
  void _renderCafe(Canvas canvas) {
    final w = game.size.x, h = game.size.y, floor = game.floorTop;
    final now = game.controller.now();
    final hour = now.hour;
    final sky = game.controller.weather?.sky;
    final night = cafeNight(now);

    _rect(canvas, Rect.fromLTWH(0, 0, w, floor), 0xFFF4E4CC);
    final wainscot = Rect.fromLTWH(0, floor - h * 0.1, w, h * 0.1);
    for (var y = 24.0; y < wainscot.top; y += 26) {
      _rect(canvas, Rect.fromLTWH(0, y, w, 2), 0xFFEBD8BC);
    }
    _rect(canvas, wainscot, 0xFFD9B58C);
    for (var x = 18.0; x < w; x += 20) {
      _rect(
        canvas,
        Rect.fromLTWH(x, wainscot.top, 2, wainscot.height),
        0xFFCBA47A,
      );
    }
    _rect(canvas, Rect.fromLTWH(0, wainscot.top, w, 4), 0xFFE8CBA6);
    _rect(canvas, Rect.fromLTWH(0, floor, w, h - floor), 0xFFC9A078);
    for (var y = floor + 20; y < h; y += 22) {
      _rect(canvas, Rect.fromLTWH(0, y, w, 2), 0xFFB98E68);
      final even = ((y - floor) ~/ 22).isEven;
      for (var x = even ? 30.0 : 80.0; x < w; x += 100) {
        _rect(canvas, Rect.fromLTWH(x, y - 20, 2, 20), 0xFFB98E68);
      }
    }

    final win = Rect.fromLTWH(w * 0.07, h * 0.09, w * 0.3, h * 0.2);
    _box(canvas, win, 0xFFFFFDF8, 0xFFCDB08C, 3);
    final glass = win.deflate(7);
    _renderSky(canvas, glass, hour, sky);
    _rect(
      canvas,
      Rect.fromLTWH(glass.center.dx - 2, glass.top, 4, glass.height),
      0xFFFFFDF8,
    );
    _rect(
      canvas,
      Rect.fromLTWH(glass.left, glass.center.dy - 2, glass.width, 4),
      0xFFFFFDF8,
    );

    final sign = Rect.fromLTWH(w * 0.52, h * 0.05, w * 0.4, h * 0.085);
    for (final x in [sign.left + 10, sign.right - 10]) {
      _rect(canvas, Rect.fromLTWH(x - 1, 0, 2, sign.top), 0xFF8A6A4A);
    }
    _box(canvas, sign, 0xFF9C6B45, 0xFF6E4830, 3);
    final cupSize = sign.height * 0.42;
    final cup = Rect.fromLTWH(
      sign.left + sign.width * 0.28,
      sign.top + sign.height * 0.36,
      cupSize,
      cupSize,
    );
    _rect(canvas, cup, 0xFFFFFDF8);
    _rect(
      canvas,
      Rect.fromLTWH(cup.right, cup.top + cup.height * 0.2, 5, cup.height * 0.5),
      0xFFFFFDF8,
    );
    for (final (dx, dy) in const [(0.2, 0.0), (0.55, 0.1), (0.85, 0.0)]) {
      _rect(
        canvas,
        Rect.fromLTWH(
          cup.left + cup.width * dx,
          cup.top - cup.height * (0.42 - dy),
          2,
          cup.height * 0.25,
        ),
        0xFFEFD9C0,
      );
    }
    final paw = Offset(sign.left + sign.width * 0.66, sign.center.dy + 3);
    _paint.color = const Color(0xFFFFFDF8);
    canvas.drawCircle(paw, sign.height * 0.15, _paint);
    for (final (dx, dy) in const [(-0.65, -0.55), (0.0, -0.8), (0.65, -0.55)]) {
      canvas.drawCircle(
        paw.translate(dx * sign.height * 0.32, dy * sign.height * 0.32),
        sign.height * 0.075,
        _paint,
      );
    }

    final menu = Rect.fromLTWH(w * 0.6, h * 0.19, w * 0.32, h * 0.14);
    _box(canvas, menu, 0xFF3F3A36, 0xFF8A6A4A, 3);
    for (final (i, frac) in const [0.7, 0.5, 0.6].indexed) {
      _rect(
        canvas,
        Rect.fromLTWH(
          menu.left + 10,
          menu.top + 10 + i * (menu.height - 20) / 3,
          (menu.width - 20) * frac,
          3,
        ),
        0xFFEFE6D6,
      );
    }
    final counter = Rect.fromLTWH(
      w * 0.56,
      h * 0.4,
      w * 0.44 + 4,
      floor - h * 0.4,
    );
    _rect(canvas, counter, 0xFFB07A4F);
    for (var x = counter.left + 14; x < counter.right; x += 16) {
      _rect(
        canvas,
        Rect.fromLTWH(x, counter.top + 10, 2, counter.height - 10),
        0xFFA06E45,
      );
    }
    final topY = counter.top - 6;
    _rect(
      canvas,
      Rect.fromLTWH(counter.left - 4, topY, counter.width + 8, 10),
      0xFFEBD2AE,
    );
    _rect(
      canvas,
      Rect.fromLTWH(counter.left - 4, topY + 10, counter.width + 8, 3),
      0xFFC9A77E,
    );
    _box(
      canvas,
      Rect.fromLTWH(counter.left + 16, topY - 16, 14, 16),
      0xFFFFFDF8,
      0xFFDDC9B0,
      2,
    );
    _rect(
      canvas,
      Rect.fromLTWH(counter.left + 16, topY - 10, 14, 3),
      0xFFE8584A,
    );
    _box(
      canvas,
      Rect.fromLTWH(counter.left + 38, topY - 13, 12, 13),
      0xFFFFFDF8,
      0xFFDDC9B0,
      2,
    );
    final jar = Rect.fromLTWH(
      counter.left + counter.width * 0.5,
      topY - 26,
      22,
      26,
    );
    _box(canvas, jar, 0xFFE6F2F5, 0xFFB9D2DA, 2);
    _rect(
      canvas,
      Rect.fromLTWH(jar.left - 2, jar.top - 4, jar.width + 4, 6),
      0xFF8A6A4A,
    );
    for (final (dx, dy) in const [
      (4.0, 8.0),
      (11.0, 12.0),
      (5.0, 16.0),
      (12.0, 19.0),
    ]) {
      _rect(
        canvas,
        Rect.fromLTWH(jar.left + dx, jar.top + dy, 5, 4),
        0xFFC89A62,
      );
    }

    // 쿠션. 손님 수만큼, 손님보다 먼저 그려 깔려 보이게.
    final k = game.guestScale;
    final seats = seatsFor(game.controller.guests.length);
    const cushions = [
      (0xFFE9A8A0, 0xFFD48C84),
      (0xFFA8CFE9, 0xFF8CB4D4),
      (0xFFF2D58A, 0xFFD9B96A),
    ];
    for (final (i, s) in seats.indexed) {
      final (fill, rim) = cushions[i % cushions.length];
      final cushion = Rect.fromCenter(
        center: Offset(w * s, game.seatBase - 2),
        width: _frame * k * 0.9,
        height: 4.5 * k + 8,
      );
      canvas.drawOval(cushion, _paint..color = Color(rim));
      canvas.drawOval(cushion.deflate(3), _paint..color = Color(fill));
    }

    final lamp = Rect.fromLTWH(counter.right - 40, topY - 22, 16, 22);
    if (night) {
      _rect(canvas, Rect.fromLTWH(0, 0, w, h), 0x55202850);
      canvas.drawCircle(
        lamp.center.translate(0, -4),
        w * 0.22,
        _paint..color = const Color(0x3DFFD27A),
      );
    }
    _rect(
      canvas,
      Rect.fromLTWH(lamp.left + 6, lamp.top + 8, 4, lamp.height - 8),
      0xFF8A6A4A,
    );
    _rect(
      canvas,
      Rect.fromLTWH(lamp.left, lamp.top, lamp.width, 9),
      night ? 0xFFFFE08A : 0xFFF2D9B0,
    );
  }

  /// 강아지 유치원. 파스텔 벽에 가랜드, 미끄럼틀, 퍼즐 매트. 벽시계는 지금 시각을 가리킨다(하원이 언제인지 보이게).
  void _renderKindergarten(Canvas canvas) {
    final w = game.size.x, h = game.size.y, floor = game.floorTop;
    final now = game.controller.now();

    _rect(canvas, Rect.fromLTWH(0, 0, w, floor), 0xFFFFF3D6);
    _paint.color = const Color(0xFFFBE6B8);
    for (var y = 30.0; y < floor - 20; y += 34) {
      for (var x = ((y ~/ 34).isEven ? 18.0 : 35.0); x < w; x += 34) {
        canvas.drawCircle(Offset(x, y), 3, _paint);
      }
    }

    final win = Rect.fromLTWH(w * 0.06, h * 0.15, w * 0.28, h * 0.19);
    _box(canvas, win, 0xFFFFFDF8, 0xFFE0C38F, 3);
    final glass = win.deflate(7);
    _renderSky(canvas, glass, now.hour, game.controller.weather?.sky);
    _rect(
      canvas,
      Rect.fromLTWH(glass.center.dx - 2, glass.top, 4, glass.height),
      0xFFFFFDF8,
    );
    _rect(
      canvas,
      Rect.fromLTWH(glass.left, glass.center.dy - 2, glass.width, 4),
      0xFFFFFDF8,
    );

    // 가랜드: 천장 아래 늘어진 줄에 삼각 깃발.
    const flags = [0xFFF4AAB7, 0xFFBFE5C8, 0xFFBAD9F4, 0xFFF7E196];
    final y0 = h * 0.05, sag = h * 0.035;
    double hang(double x) => y0 + sag * sin(pi * x / w);
    const n = 9;
    for (var i = 0; i < n; i++) {
      final x0 = w * i / n + 3, x1 = w * (i + 1) / n - 3, mid = (x0 + x1) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(x0, hang(x0))
          ..lineTo(x1, hang(x1))
          ..lineTo(mid, hang(mid) + h * 0.05)
          ..close(),
        _paint..color = Color(flags[i % flags.length]),
      );
    }
    final rope = Path()..moveTo(0, hang(0));
    for (var x = 8.0; x <= w; x += 8) {
      rope.lineTo(x, hang(x));
    }
    canvas.drawPath(
      rope,
      _stroke
        ..color = const Color(0xFFB98E68)
        ..strokeWidth = 2,
    );

    final clock = Offset(w * 0.52, h * 0.24);
    final r = min(w, h) * 0.07;
    canvas.drawCircle(clock, r + 3, _paint..color = const Color(0xFFE38C9B));
    canvas.drawCircle(clock, r, _paint..color = const Color(0xFFFFFDF8));
    _paint.color = const Color(0xFF4B3A2F);
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      canvas.drawCircle(clock + Offset(sin(a), -cos(a)) * (r - 4), 1.4, _paint);
    }
    final minutes = now.minute + now.second / 60;
    final hours = now.hour % 12 + minutes / 60;
    _stroke
      ..color = const Color(0xFF4B3A2F)
      ..strokeWidth = 3;
    for (final (angle, length) in [
      (hours * pi / 6, r * 0.5),
      (minutes * pi / 30, r * 0.78),
    ]) {
      canvas.drawLine(
        clock,
        clock + Offset(sin(angle), -cos(angle)) * length,
        _stroke,
      );
    }

    // 미끄럼틀(오른쪽): 사다리, 꼭대기 발판, 비스듬한 미끄럼판.
    final top = floor - h * 0.24;
    _stroke
      ..color = const Color(0xFF8FC7E8)
      ..strokeWidth = 4;
    for (final x in [w * 0.87, w * 0.95]) {
      canvas.drawLine(Offset(x, floor), Offset(x, top), _stroke);
    }
    _stroke.strokeWidth = 3;
    for (var y = floor - 14; y > top + 6; y -= 14) {
      canvas.drawLine(Offset(w * 0.87, y), Offset(w * 0.95, y), _stroke);
    }
    _box(
      canvas,
      Rect.fromLTWH(w * 0.84, top - 6, w * 0.14, 9),
      0xFFBFE5C8,
      0xFF8FCBA6,
      2,
    );
    _stroke
      ..color = const Color(0xFFE38C9B)
      ..strokeWidth = 13;
    canvas.drawLine(
      Offset(w * 0.85, top + 4),
      Offset(w * 0.6, floor - 5),
      _stroke,
    );
    _stroke
      ..color = const Color(0xFFF4AAB7)
      ..strokeWidth = 7;
    canvas.drawLine(
      Offset(w * 0.85, top + 4),
      Offset(w * 0.6, floor - 5),
      _stroke,
    );

    // 장난감 상자(왼쪽)와 삐져나온 공.
    final box = Rect.fromLTWH(w * 0.05, floor - h * 0.085, w * 0.18, h * 0.085);
    for (final (dx, color) in const [
      (0.25, 0xFFE8584A),
      (0.55, 0xFF7EC8E3),
      (0.8, 0xFFF2C14E),
    ]) {
      canvas.drawCircle(
        Offset(box.left + box.width * dx, box.top - 2),
        box.width * 0.14,
        _paint..color = Color(color),
      );
    }
    _box(canvas, box, 0xFFE4B07A, 0xFFC98F5A, 3);
    _rect(
      canvas,
      Rect.fromLTWH(box.left, box.top + box.height * 0.45, box.width, 3),
      0xFFC98F5A,
    );

    _rect(canvas, Rect.fromLTWH(0, floor - 8, w, 8), 0xFFE9CFA0);
    const mats = [0xFFFFDDE4, 0xFFD9F1E1, 0xFFDDEBFA, 0xFFFFF1C6];
    const edges = [0xFFF4C3CE, 0xFFBFE3CB, 0xFFC4DAF2, 0xFFF2DFA2];
    final tileW = w / 5, tileH = (h - floor) / 2;
    for (var row = 0; row * tileH < h - floor; row++) {
      for (var col = 0; col * tileW < w; col++) {
        final i = (row + col) % mats.length;
        _box(
          canvas,
          Rect.fromLTWH(col * tileW, floor + row * tileH, tileW, tileH),
          mats[i],
          edges[i],
          2,
        );
      }
    }
  }

  /// 간식 가게. 줄무늬 벽에 뼈다귀 간판, 선반 위 간식 병, 바닥 쪽 유리 진열장 네 칸(그날 간식).
  /// 진열장 칸은 펫이 냄새 맡으러 서는 자리(shopSlots)에 맞춰 그린다.
  void _renderShop(Canvas canvas) {
    final w = game.size.x, h = game.size.y, floor = game.floorTop;
    final c = game.controller;

    for (var x = 0.0; x < w; x += 36) {
      _rect(canvas, Rect.fromLTWH(x, 0, 18, floor), 0xFFF6EBD9);
      _rect(canvas, Rect.fromLTWH(x + 18, 0, 18, floor), 0xFFF1E1C8);
    }

    // 뼈다귀 간판: 테두리 색으로 한 번, 속 색으로 한 번 그려 외곽선을 낸다.
    final bone = Rect.fromLTWH(w * 0.34, h * 0.06, w * 0.32, h * 0.06);
    for (final (grow, color) in const [(3.0, 0xFFC9A77E), (0.0, 0xFFFFF4D6)]) {
      _paint.color = Color(color);
      canvas.drawRect(bone.inflate(grow), _paint);
      final r = bone.height * 0.62 + grow;
      for (final p in [
        bone.topLeft,
        bone.bottomLeft,
        bone.topRight,
        bone.bottomRight,
      ]) {
        canvas.drawCircle(p, r, _paint);
      }
    }

    // 선반 둘과 간식 병.
    for (final (row, y) in [(0, h * 0.27), (1, h * 0.42)]) {
      for (var i = 0; i < 6; i++) {
        final jar = Rect.fromLTWH(
          w * (0.1 + i * 0.135),
          y - h * 0.075,
          w * 0.08,
          h * 0.075,
        );
        final t = treats[(i + row * 3) % treats.length];
        _box(canvas, jar, 0xFFEAF5F7, 0xFFB9D2DA, 2);
        _rect(
          canvas,
          Rect.fromLTRB(
            jar.left + 3,
            jar.top + jar.height * 0.4,
            jar.right - 3,
            jar.bottom - 3,
          ),
          t.color,
        );
        _rect(
          canvas,
          Rect.fromLTWH(jar.left - 2, jar.top - 4, jar.width + 4, 5),
          0xFF8A6A4A,
        );
      }
      _rect(canvas, Rect.fromLTWH(w * 0.06, y, w * 0.88, 6), 0xFFC9A078);
      _rect(canvas, Rect.fromLTWH(w * 0.06, y + 6, w * 0.88, 2), 0xFFB08A60);
    }

    for (var y = floor; y < h; y += 24) {
      for (var x = ((y - floor) ~/ 24).isEven ? 0.0 : 24.0; x < w; x += 48) {
        _rect(canvas, Rect.fromLTWH(x, y, 24, 24), 0xFFF3E3CF);
        _rect(canvas, Rect.fromLTWH(x + 24, y, 24, 24), 0xFFEAD6BC);
      }
    }

    // 유리 진열장. 칸마다 그날 간식이 소복이.
    final top = floor - h * 0.15;
    final case_ = Rect.fromLTRB(
      game.floorX(shopSlots.first) - w * 0.11,
      top,
      game.floorX(shopSlots.last) + w * 0.11,
      floor + 4,
    );
    _box(canvas, case_, 0xFFF4FAFB, 0xFFB98E68, 4);
    for (final (i, x) in shopSlots.indexed) {
      final cx = game.floorX(x);
      if (i > 0) {
        _rect(
          canvas,
          Rect.fromLTWH(
            (cx + game.floorX(shopSlots[i - 1])) / 2 - 1.5,
            top,
            3,
            case_.height,
          ),
          0xFFD9C3A5,
        );
      }
      if (i >= c.lineup.length) continue;
      _paint.color = Color(c.lineup[i].color);
      final base = floor - 6.0;
      for (final (dx, dy) in const [
        (-9.0, 0.0),
        (0.0, 0.0),
        (9.0, 0.0),
        (-4.5, -7.0),
        (4.5, -7.0),
        (0.0, -14.0),
      ]) {
        canvas.drawCircle(Offset(cx + dx, base + dy), 5, _paint);
      }
      if (c.pickShown && c.shopPickIndex == i) {
        final s = top - 10 - 3 * sin(_t * 4);
        canvas.drawPath(
          Path()
            ..moveTo(cx, s - 7)
            ..lineTo(cx + 5, s)
            ..lineTo(cx, s + 7)
            ..lineTo(cx - 5, s)
            ..close(),
          _paint..color = const Color(0xFFF2C14E),
        );
      }
    }
    _rect(
      canvas,
      Rect.fromLTWH(case_.left + 6, top + 6, case_.width - 12, 3),
      0xBFFFFFFF,
    );
  }

  /// 동물병원. 연한 민트 벽과 흰 타일, 빨간 십자 표시, 진찰대, 바닥 가운데 체중계.
  /// 체중계 화면은 펫이 올라가 있는 동안만 몸무게를 보인다.
  void _renderHospital(Canvas canvas) {
    final w = game.size.x, h = game.size.y, floor = game.floorTop;
    final c = game.controller;
    final now = c.now();

    _rect(canvas, Rect.fromLTWH(0, 0, w, floor), 0xFFE8F5EF);
    final tiles = floor - h * 0.22;
    _rect(canvas, Rect.fromLTWH(0, tiles, w, floor - tiles), 0xFFFFFFFF);
    for (var y = tiles; y < floor; y += 20) {
      _rect(canvas, Rect.fromLTWH(0, y, w, 2), 0xFFDDEDE6);
    }
    for (var x = 0.0; x < w; x += 20) {
      _rect(canvas, Rect.fromLTWH(x, tiles, 2, floor - tiles), 0xFFDDEDE6);
    }

    final win = Rect.fromLTWH(w * 0.06, h * 0.1, w * 0.26, h * 0.18);
    _box(canvas, win, 0xFFFFFFFF, 0xFFC5DDD3, 3);
    final glass = win.deflate(7);
    _renderSky(canvas, glass, now.hour, c.weather?.sky);
    _rect(
      canvas,
      Rect.fromLTWH(glass.center.dx - 2, glass.top, 4, glass.height),
      0xFFFFFFFF,
    );

    final sign = Rect.fromCenter(
      center: Offset(w * 0.6, h * 0.17),
      width: h * 0.13,
      height: h * 0.13,
    );
    _box(canvas, sign, 0xFFFFFFFF, 0xFFE5484D, 3);
    final arm = sign.width * 0.22;
    _rect(
      canvas,
      Rect.fromCenter(
        center: sign.center,
        width: arm,
        height: sign.height * 0.62,
      ),
      0xFFE5484D,
    );
    _rect(
      canvas,
      Rect.fromCenter(
        center: sign.center,
        width: sign.width * 0.62,
        height: arm,
      ),
      0xFFE5484D,
    );

    // 발자국 포스터.
    final poster = Rect.fromLTWH(w * 0.78, h * 0.1, w * 0.14, h * 0.15);
    _box(canvas, poster, 0xFFFFF4D6, 0xFFE0C38F, 2);
    _paint.color = const Color(0xFFE38C9B);
    final paw = poster.center.translate(0, poster.height * 0.12);
    canvas.drawCircle(paw, poster.width * 0.2, _paint);
    for (final (dx, dy) in const [(-0.28, -0.3), (0.0, -0.42), (0.28, -0.3)]) {
      canvas.drawCircle(
        paw + Offset(dx * poster.width, dy * poster.width),
        poster.width * 0.09,
        _paint,
      );
    }

    // 진찰대(오른쪽): 상판, 다리, 청진기.
    final table = Rect.fromLTWH(w * 0.72, floor - h * 0.13, w * 0.24, 9);
    for (final x in [table.left + 6, table.right - 10]) {
      _rect(
        canvas,
        Rect.fromLTWH(x, table.bottom, 4, floor - table.bottom),
        0xFFB7C7CF,
      );
    }
    _box(canvas, table, 0xFFFFFFFF, 0xFF9FB4BE, 2);
    _stroke
      ..color = const Color(0xFF5C7C8A)
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(table.center.dx, table.top - 6),
        width: table.width * 0.5,
        height: 12,
      ),
      pi,
      pi,
      false,
      _stroke,
    );
    canvas.drawCircle(
      Offset(table.center.dx + table.width * 0.25, table.top - 3),
      3,
      _paint..color = const Color(0xFF5C7C8A),
    );

    for (var y = floor; y < h; y += 26) {
      _rect(
        canvas,
        Rect.fromLTWH(0, y, w, 26),
        (y - floor) ~/ 26 % 2 == 0 ? 0xFFE4ECEF : 0xFFDDE7EA,
      );
    }

    // 체중계: 바닥 판과 왼쪽 기둥 위 작은 화면. 펫 몸에 가리지 않게 판 바깥에 세운다.
    // 잰 몸무게는 병원을 나갈 때까지 화면에 남는다. 재는 동안만 밝게.
    final cx = game.floorX(scaleX);
    final plate = Rect.fromCenter(
      center: Offset(cx, game.petBaseline - 2),
      width: game.pixelScale * _frame * 0.75,
      height: 8,
    );
    final postX = plate.left - 10;
    final screen = Rect.fromCenter(
      center: Offset(postX - 18, floor - h * 0.04),
      width: 64,
      height: 26,
    );
    _rect(
      canvas,
      Rect.fromLTWH(
        postX - 2,
        screen.bottom,
        4,
        plate.center.dy - screen.bottom,
      ),
      0xFFB7C7CF,
    );
    _rect(
      canvas,
      Rect.fromLTWH(postX, plate.center.dy - 2, plate.left - postX, 4),
      0xFFB7C7CF,
    );
    _box(canvas, screen, 0xFF2F3A3F, 0xFFB7C7CF, 3);
    final weighing = c.step.tag == StepTag.weigh;
    final text = c.lastCheckup != null
        ? '${c.lastCheckup!.weight.toStringAsFixed(1)}kg'
        : '0.0kg';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: C3Fonts.jua,
          fontSize: 13,
          color: weighing
              ? const Color(0xFF9CF0B8)
              : c.lastCheckup != null
              ? const Color(0xFF7CC497)
              : const Color(0xFF6B8A7A),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      screen.center - Offset(painter.width / 2, painter.height / 2),
    );
    _box(canvas, plate, 0xFFF4F7F8, 0xFF9FB4BE, 2);
  }

  void _renderPrecipitation(
    Canvas canvas,
    Rect area,
    Sky? sky, {
    required bool dense,
  }) {
    if (sky != Sky.rain && sky != Sky.snow) return;
    final paint = _paint
      ..color = sky == Sky.rain
          ? const Color(0xFFEEF4FB)
          : const Color(0xFFFFFFFF);
    final count = dense ? 60 : 14;
    final rnd = Random(7);
    for (var i = 0; i < count; i++) {
      final x = area.left + rnd.nextDouble() * area.width;
      final speed = sky == Sky.rain ? 220.0 : 40.0;
      final y =
          area.top +
          (rnd.nextDouble() * area.height + _t * speed) % area.height;
      if (sky == Sky.rain) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x - 2, y + 9),
          paint..strokeWidth = 2,
        );
      } else {
        canvas.drawCircle(Offset(x, y), 2.5, paint);
      }
    }
  }

  static int _skyColor(int hour, Sky? sky) {
    if (hour >= 20 || hour < 6) return 0xFF2C3560;
    if (sky == Sky.rain) return 0xFFA9BEDB;
    if (sky == Sky.snow || sky == Sky.cloudy) return 0xFFCDD8E8;
    if (hour < 9) return 0xFFF9D9C0;
    if (hour < 17) return 0xFFBFE3F5;
    return 0xFFF4B9A0;
  }
}

/// 방 칸에 놓인 물건, 창틀에 떨어진 물건. 강아지보다 뒤에 그린다.
class _Decor extends Component with HasGameReference<PetGame> {
  double _t = 0;
  final _spark = Paint()..color = const Color(0xFFFFFFFF);

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final c = game.controller;
    if (c.walking || c.out) return;
    final k = game.pixelScale;
    final cell = Vector2.all(_prop * k);
    for (final e in c.placed.entries) {
      final slot = slotById(e.key);
      if (slot == null) continue;
      final base = game.slotBase(slot);
      game
          .itemSprite(e.value)
          ?.render(
            canvas,
            position: Vector2(base.dx - cell.x / 2, base.dy - cell.y),
            size: cell,
          );
    }
    // 아침 현관 물건. 펫이 물고 오는 동안은 입에 그린다.
    if (c.doorItem case final item? when c.step.tag != StepTag.door) {
      final r = game.doorItemRect;
      game
          .doorProp(item)
          .render(canvas, position: Vector2(r.left, r.top), size: cell);
      final a = (sin(_t * 4 + 1) + 1) / 2;
      _spark.color = Color.fromRGBO(255, 255, 255, 0.4 + a * 0.6);
      final s = k * (1 + a);
      final o = Offset(r.center.dx + k * 5, r.bottom - k * 9);
      canvas.drawRect(
        Rect.fromCenter(center: o, width: s, height: s * 3),
        _spark,
      );
      canvas.drawRect(
        Rect.fromCenter(center: o, width: s * 3, height: s),
        _spark,
      );
    }
    final sill = c.carried
        .where((x) => x.source == FindSource.window)
        .firstOrNull;
    if (sill != null) {
      // 비어 있는 창턱 칸에 떨어진다. 둘 다 차 있으면 두 칸 사이.
      final free = slots.where(
        (s) => s.area == SlotArea.sill && !c.placed.containsKey(s.id),
      );
      final win = game.windowRect;
      final base = free.isEmpty
          ? Offset(win.left + win.width * 0.3, win.bottom)
          : game.slotBase(free.first);
      game
          .itemSprite(sill.itemId)
          ?.render(
            canvas,
            position: Vector2(base.dx - cell.x / 2, base.dy - cell.y),
            size: cell,
          );
      // 창틀에 뭔가 왔다는 걸 반짝임으로 알린다.
      final a = (sin(_t * 4) + 1) / 2;
      _spark.color = Color.fromRGBO(255, 255, 255, 0.4 + a * 0.6);
      final s = k * (1 + a);
      final o = Offset(base.dx + k * 5, base.dy - k * 9);
      canvas.drawRect(
        Rect.fromCenter(center: o, width: s, height: s * 3),
        _spark,
      );
      canvas.drawRect(
        Rect.fromCenter(center: o, width: s * 3, height: s),
        _spark,
      );
    }
  }
}

class _PetSprite extends SpriteAnimationGroupComponent<Behavior>
    with TapCallbacks, HasGameReference<PetGame> {
  _PetSprite(
    this.controller,
    this.sheet,
    this.mouths,
    SpriteSheet props, {
    double startX = 0.5,
  }) : _x = startX,
       _spot = controller.spot,
       _snapGen = controller.snapGen,
       _bowl = props.getSprite(0, 0),
       _emptyBowl = props.getSprite(0, 5),
       _heart = props.getSprite(0, 1),
       _z = props.getSprite(0, 2),
       super(
         anchor: Anchor.bottomCenter,
         size: Vector2.all(_frame),
         priority: 2,
       );

  final PetController controller;
  final SpriteSheet sheet;

  /// (줄, 칸) → 프레임 안 입 위치. 스프라이트 시트의 입 위치 표시 픽셀에서 읽었다.
  final Map<(int, int), (int, int)> mouths;
  final Sprite _bowl, _emptyBowl, _heart, _z;
  final _shadow = Paint()..color = const Color(0x477862AA);
  double _x;
  double _t = 0;
  bool _facingLeft = false;

  /// 성장·외형 변경으로 스프라이트를 다시 만들 때 카페에 있으면 입구로 되돌아가지 않게 지금 장소로 시작한다.
  Spot _spot;

  /// 컨트롤러가 펫을 걷지 않고 옮긴 횟수(자는 사이에 와서 이미 제 자리에서 자고 있을 때).
  int _snapGen;

  static const _rows = {
    Behavior.idle: (0, 0.2),
    Behavior.walk: (1, 0.14),
    Behavior.run: (1, 0.08),
    Behavior.sleep: (2, 0.6),
    Behavior.eat: (3, 0.2),
    Behavior.happy: (4, 0.12),
    Behavior.sulk: (5, 0.6),
    Behavior.lieBeside: (5, 0.6),
    Behavior.sit: (6, 0.35),
    Behavior.waitAtDoor: (6, 0.35),
    Behavior.watchWindow: (6, 0.35),
    Behavior.sniff: (7, 0.18),
    Behavior.spin: (4, 0.1),
    Behavior.jump: (4, 0.12),
  };

  /// 점프 중 바닥에서 떠 있는 높이(게임 좌표). 그림자는 바닥에 남는다.
  double _lift = 0;

  /// 지금 프레임의 입 위치(프레임 좌표). 표시가 없는 프레임은 그 줄 첫 칸 값을 쓴다.
  /// 정수로 둬야 물건·소품이 강아지 픽셀 격자에 맞는다.
  Vector2 get mouth {
    final row = _rows[current]?.$1 ?? 0;
    final col = animationTicker?.currentIndex ?? 0;
    final m = mouthAt(mouths, row, col);
    return Vector2(m.$1.toDouble(), m.$2.toDouble());
  }

  @override
  Future<void> onLoad() async {
    animations = {
      for (final e in _rows.entries)
        e.key: sheet.createAnimation(row: e.value.$1, stepTime: e.value.$2),
    };
    current = controller.step.behavior;
  }

  @override
  void onMount() {
    super.onMount();
    controller.addListener(_sync);
    _sync();
  }

  @override
  void onRemove() {
    controller.removeListener(_sync);
    super.onRemove();
  }

  void _sync() {
    final step = controller.step;
    current = step.behavior;
    if (step.behavior == Behavior.waitAtDoor) {
      _x = step.targetX ?? doorX;
      _facingLeft = false;
    }
    // 홈캠 다시보기의 장면 전환: 걸어가지 않고 그 자리로 바로.
    if (step.tag == StepTag.cut && step.targetX != null) {
      _x = step.targetX!;
      _facingLeft = false;
    }
    // 장소가 바뀌면 입구에서 걸어 들어온다. 바깥 장소는 왼쪽 밖, 집은 문 앞.
    if (controller.spot != _spot) {
      _spot = controller.spot;
      _x = _spot == Spot.home ? doorX : -0.2;
      _facingLeft = false;
    }
    // 바로 옮기기는 장소 바뀜보다 나중에(유치원 버스로 밤에 와 있으면 문 앞이 아니라 자는 자리).
    if (controller.snapGen != _snapGen) {
      _snapGen = controller.snapGen;
      _x = controller.petX;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final step = controller.step;
    final moving =
        step.behavior == Behavior.walk ||
        step.behavior == Behavior.run ||
        step.behavior == Behavior.watchWindow;
    final ballX = game._ball?.x;
    final chasing = step.tag == StepTag.chase && ballX != null;
    if (moving) {
      final target = chasing ? _mouthTo(ballX) : step.targetX ?? _x;
      final speed = step.behavior == Behavior.run ? 0.35 : 0.1;
      final d = target - _x;
      if (d.abs() < 0.01) {
        if (step.behavior == Behavior.watchWindow) {
          // 창가에 닿으면 앉아서 오른쪽(창문)을 본다.
          current = Behavior.watchWindow;
          _facingLeft = false;
        } else if (chasing) {
          // 공이 멈출 때까지 공을 보며 기다린다. 멈추면 컨트롤러가 줍게 한다.
          current = Behavior.idle;
          _facingLeft = ballX < position.x;
          controller.arrived();
        } else {
          controller.arrived();
        }
      } else {
        current = Behavior.walk;
        _facingLeft = d < 0;
        _x += d.sign * (speed * dt).clamp(0, d.abs());
      }
    }
    if (step.behavior == Behavior.spin) _facingLeft = (_t * 7).floor().isEven;
    controller.petX = _x;
    final k = game.pixelScale;
    // 0.65초마다 한 번 폴짝. 두 번 뛰면 개인기 한 번이다. 동작이 시작된 때부터 재야 바닥에서 출발한다.
    _lift = step.behavior == Behavior.jump
        ? sin((controller.stepElapsed % 0.65) / 0.65 * pi) * 9 * k
        : 0;
    scale.setValues(_facingLeft ? -k : k, k);
    position.setValues(game.floorX(_x), game.petBaseline - _lift);
  }

  /// 입이 공 위에 오도록 설 자리. 공 쪽을 보고 서므로 몸은 공보다 입 길이만큼 뒤에 있다.
  /// 입 위치는 동작마다 한두 픽셀 달라서, 멈춰 기다리는 동안 자리가 흔들리지 않게 서기 첫 칸 값을 쓴다.
  double _mouthTo(double ballX) {
    final m = mouthAt(mouths, 0, 0);
    final reach = (m.$1 - _frame / 2) * game.pixelScale;
    final here = game.floorX(_x);
    return game.floorFraction(here < ballX ? ballX - reach : ballX + reach);
  }

  /// 입에 문 공의 아래 가운데(게임 좌표). 떨어뜨릴 때 여기서 시작한다.
  Vector2 get mouthBottom {
    final m = mouth;
    return Vector2(
      position.x + (m.x - _frame / 2) * scale.x,
      position.y + (m.y + 5 - _frame) * scale.y,
    );
  }

  bool get facingLeft => _facingLeft;

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(16, 30.5 + _lift / game.pixelScale),
        width: 22,
        height: 3,
      ),
      _shadow,
    );
    final inhaling = _inhaling;
    if (inhaling) {
      // 숨을 들이쉴 때 다리 위만 한 픽셀 들린다. 늘이면 픽셀이 뭉개져서 경계 한 줄을 겹쳐 그린다.
      // 경계를 부드럽게 자르면 두 번 그린 반투명 줄이 겹쳐 옅은 선이 보여서 딱 잘라 그린다.
      canvas
        ..save()
        ..clipRect(
          const Rect.fromLTWH(0, _chest, _frame, _frame - _chest),
          doAntiAlias: false,
        );
      super.render(canvas);
      canvas
        ..restore()
        ..save()
        ..translate(0, -1)
        ..clipRect(
          const Rect.fromLTWH(0, 0, _frame, _chest + 1),
          doAntiAlias: false,
        );
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }
    _renderProp(canvas, lift: inhaling ? 1 : 0);
  }

  /// 이 줄 위가 숨 쉴 때 들리는 몸통이다.
  static const _chest = 24.0;

  /// 가만히 있을 때만 숨이 보인다. 잘 때는 깊고 느리게 쉰다.
  bool get _inhaling {
    final period = switch (current) {
      Behavior.sleep => 3.5,
      Behavior.sit ||
      Behavior.idle ||
      Behavior.lieBeside ||
      Behavior.sulk ||
      Behavior.waitAtDoor ||
      Behavior.watchWindow => 2.4,
      _ => 0.0,
    };
    return period > 0 && _t % period < period * 0.45;
  }

  /// 밥그릇·하트·zzz와 물고 온 물건은 시트에 없고 여기서 겹친다. 프레임 좌표라 뒤집기를 그대로 따른다.
  /// 입에 문 것은 숨 쉴 때 머리와 같이 [lift]만큼 들린다.
  void _renderProp(Canvas canvas, {required double lift}) {
    final m = mouth;
    final held = controller.presenting;
    final door = controller.doorItem;
    if (door != null && controller.step.tag == StepTag.door) {
      game
          .doorProp(door)
          .render(canvas, position: Vector2(m.x - 8, m.y - 11 - lift));
    } else if (controller.ball == Ball.carried) {
      game
          .itemSprite(_ballItem)
          ?.render(canvas, position: Vector2(m.x - 8, m.y - 11 - lift));
    } else if (held != null &&
        controller.ball == Ball.none &&
        held.source != FindSource.window &&
        !controller.walking &&
        !controller.out &&
        !controller.replaying &&
        current != Behavior.eat) {
      // 물건 칸(16×16)은 아래 가운데에 그려져 있어서, 칸을 입 위치에 맞추면 입에 물린 것처럼 보인다.
      game
          .itemSprite(held.itemId)
          ?.render(canvas, position: Vector2(m.x - 8, m.y - 11 - lift));
    }
    final rise = (_t * 0.8) % 1;
    final fade = Paint()
      ..color = Color.fromRGBO(255, 255, 255, 1 - rise * 0.8)
      ..filterQuality = FilterQuality.none;
    switch (current) {
      case Behavior.eat when controller.step.tag != StepTag.snack:
      case Behavior.sit when controller.step.tag == StepTag.bowl:
        _bowl.render(canvas, position: Vector2(m.x - 9, 17));
      case Behavior.sniff when controller.step.tag == StepTag.bowl:
        _emptyBowl.render(canvas, position: Vector2(m.x - 9, 17));
      case Behavior.happy:
        _heart.render(
          canvas,
          position: Vector2(m.x - 12, -6 - rise * 8),
          overridePaint: fade,
        );
      case Behavior.sleep:
        // z는 좌우가 뒤집히면 이상하게 보여서 펫이 왼쪽을 봐도 똑바로 둔다.
        canvas.save();
        canvas.translate(m.x - 4, 2 - rise * 8);
        canvas.scale(_facingLeft ? -1 : 1, 1);
        _z.render(canvas, position: Vector2(-8, 0), overridePaint: fade);
        canvas.restore();
      default:
    }
  }

  @override
  void onTapDown(TapDownEvent event) => controller.interact(Interaction.pet);
}

const _ballItem = 'tennis_ball';

/// 던지는 공. 바닥에 있거나 날아갈 때만 여기서 그린다. 물고 있을 때는 강아지가 입에 그린다.
class _Ball extends Component with HasGameReference<PetGame> {
  _Ball(this.controller);

  final PetController controller;

  /// 공 그림 칸의 아래 가운데(게임 좌표).
  final _pos = Vector2.zero();
  final _v = Vector2.zero();
  final _shadow = Paint()..color = const Color(0x477862AA);
  Ball _was = Ball.none;
  bool _moving = false;
  double _sinceBounce = 1;

  /// 멈춘 공의 방 바닥 가로 위치(0~1).
  double _rest = 0.5;

  double? get x => switch (controller.ball) {
    Ball.thrown || Ball.ready => _pos.x,
    _ => null,
  };

  void fling(Vector2 velocity) {
    if (controller.ball != Ball.ready || velocity.y > -250) return;
    if (!controller.throwBall()) return;
    if (_was == Ball.carried || _was == Ball.none) _dropFromMouth();
    _was = Ball.thrown;
    _v.setValues(
      (velocity.x * 0.55).clamp(-1000, 1000),
      (velocity.y * 0.55).clamp(-1300, -500),
    );
    _moving = true;
  }

  @override
  void update(double dt) {
    final state = controller.ball;
    _sinceBounce += dt;
    if (state == Ball.none || state == Ball.carried) {
      _was = state;
      _moving = false;
      return;
    }
    if (_was == Ball.carried || _was == Ball.none) {
      _dropFromMouth();
    }
    _was = state;
    if (!_moving) {
      // 키보드가 올라와 방 높이가 바뀌어도 바닥에 붙어 있게 한다.
      _pos.setValues(game.floorX(_rest), game.petBaseline - game.pixelScale);
      return;
    }
    // 한 프레임이 길어도 바닥을 뚫지 않게 잘게 나눠 계산한다.
    final n = (dt / 0.008).ceil().clamp(1, 12);
    for (var i = 0; i < n && _moving; i++) {
      _step(min(dt, 0.1) / n);
    }
  }

  void _dropFromMouth() {
    final pet = game._sprite;
    if (pet != null) {
      _pos.setFrom(pet.mouthBottom);
      _v.setValues(pet.facingLeft ? -50 : 50, -90);
    } else {
      _pos.setValues(game.floorX(0.5), game.petBaseline);
      _v.setZero();
    }
    _moving = true;
  }

  void _step(double dt) {
    final k = game.pixelScale;
    _v.y += 2200 * dt;
    _pos.addScaled(_v, dt);
    final left = game.floorX(0), right = game.floorX(1);
    final floor = game.petBaseline - k;
    final top = 8 * k;
    if (_pos.x < left) {
      _pos.x = left;
      _v.x = _v.x.abs() * 0.6;
    } else if (_pos.x > right) {
      _pos.x = right;
      _v.x = -_v.x.abs() * 0.6;
    }
    if (_pos.y < top) {
      _pos.y = top;
      _v.y = _v.y.abs() * 0.3;
    }
    if (_pos.y < floor) return;
    _pos.y = floor;
    if (_v.y > 0) {
      if (_v.y > 260 && _sinceBounce > 0.08) {
        controller.bounced();
        _sinceBounce = 0;
      }
      _v.y = _v.y > 160 ? -_v.y * 0.45 : 0;
    }
    if (_v.y != 0) return;
    _v.x *= pow(0.12, dt);
    if (_v.x.abs() < 10) {
      _v.setZero();
      _moving = false;
      _rest = game.floorFraction(_pos.x);
      controller.ballLanded();
    }
  }

  @override
  void render(Canvas canvas) {
    if (x == null) return;
    final k = game.pixelScale;
    final floor = game.petBaseline - k;
    // 높이 뜰수록 그림자가 작아진다.
    final lift = ((floor - _pos.y) / (game.size.y * 0.5)).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(_pos.x, floor - k * 0.5),
        width: k * 6 * (1 - lift * 0.6),
        height: k * 1.5,
      ),
      _shadow,
    );
    // 픽셀 격자에 맞춰야 강아지·방 칸 물건과 같은 크기의 픽셀로 보인다.
    final px = (_pos.x / k).round() * k, py = (_pos.y / k).round() * k;
    game
        .itemSprite(_ballItem)
        ?.render(
          canvas,
          position: Vector2(px - _prop * k / 2, py - _prop * k),
          size: Vector2.all(_prop * k),
        );
  }
}

/// 손 베개. 방 바닥을 길게 누르면 그 자리에 주인 손(손바닥 아이콘)이 놓인다. 떼면 펫이 마칠 때까지 두었다가 거둔다.
/// 펫보다 먼저 그려서 펫이 손 위에 눕는다. 펫은 우선순위가 높아 제 탭(쓰다듬기)을 먼저 받고,
/// 문은 바닥 위에 있어 자리가 안 겹치며, 공 던지기는 끌기라 탭과 따로 간다.
class _Hand extends PositionComponent
    with TapCallbacks, HasGameReference<PetGame> {
  _Hand(this.palm) : super(priority: 1);

  final ui.Image palm;
  final _pixel = Paint()..filterQuality = FilterQuality.none;

  @override
  void update(double dt) {
    position.setZero();
    size.setFrom(game.size);
  }

  /// 바닥만. 벽을 눌러 바닥에 손이 생기면 어색하다.
  @override
  bool containsLocalPoint(Vector2 point) =>
      game.controller.canOfferHand &&
      point.y >= game.floorTop &&
      point.y <= game.size.y;

  /// 길게 누른 손가락들. 떼도 짧은 탭(방석)으로 치지 않는다.
  final _long = <int>{};

  /// 손을 놓은 손가락. 이 손가락을 떼야 손을 거둔다(다른 손가락의 탭이 손을 거두지 않게).
  int? _holder;

  @override
  void onLongTapDown(TapDownEvent event) {
    _long.add(event.pointerId);
    final c = game.controller;
    final had = c.handX != null;
    c.offerHand(game.floorFraction(event.localPosition.x));
    if (!had && c.handX != null) _holder = event.pointerId;
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (_long.remove(event.pointerId)) {
      _release(event.pointerId);
      return;
    }
    if (game.rugRect.inflate(6).contains(event.localPosition.toOffset())) {
      game.controller.tapRug();
    }
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _long.remove(event.pointerId);
    _release(event.pointerId);
  }

  void _release(int pointer) {
    if (pointer != _holder) return;
    _holder = null;
    game.controller.releaseHand();
  }

  @override
  void render(Canvas canvas) {
    final x = game.controller.handX;
    if (x == null) return;
    final k = game.pixelScale;
    final w = 12 * k;
    // 손가락 끝만 펫 밑에 들어가고 손바닥은 방 아래 가장자리에서 들어오는 것처럼 보이게(주인 쪽에서 내민 손).
    canvas.drawImageRect(
      palm,
      const Rect.fromLTWH(0, 0, 12, 12),
      Rect.fromLTWH(game.floorX(x) - w / 2, game.petBaseline - 4 * k, w, w),
      _pixel,
    );
  }
}

/// 현관 앞에 물어다 둔 물건. 누르면 챙긴다. 그림은 방 꾸밈(_Decor)이 펫 뒤에 그리고 여긴 누르기만 받는다.
/// 누르는 칸은 그림이 있는 아랫줄만이라 문(지도)과 겹치지 않는다. 펫과 같은 우선순위라 겹치면 나중에 놓인 펫이
/// 먼저 받고(쓰다듬기), 바닥 손 베개(_Hand)보다는 먼저 받는다.
class _DoorItem extends PositionComponent
    with TapCallbacks, HasGameReference<PetGame> {
  _DoorItem() : super(priority: 2);

  @override
  void update(double dt) {
    final r = game.doorItemRect;
    final k = game.pixelScale;
    final top = max(r.bottom - 7 * k, game.floorTop);
    position.setValues(r.left, top);
    size.setValues(r.width, r.bottom + 2 * k - top);
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    final c = game.controller;
    return c.doorItem != null &&
        c.step.tag != StepTag.door &&
        !c.walking &&
        !c.out &&
        !c.replaying &&
        super.containsLocalPoint(point);
  }

  @override
  void onTapUp(TapUpEvent event) => game.controller.takeDoorItem();
}

/// 방 어디서든 공을 위로 쓸어 올리면 던진다. 공이 바닥에 있을 때만 끌기를 받는다.
class _Fling extends Component with DragCallbacks, HasGameReference<PetGame> {
  @override
  bool containsLocalPoint(Vector2 point) => game.controller.ball == Ball.ready;

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game._ball?.fling(event.velocity);
  }
}

/// 카페 손님. 펫과 같은 줄 배치의 시트를 쓰고 제 쿠션에 앉아 자기 마음(GuestMind)대로 움직인다.
/// 펫보다 뒤(우선순위 낮음)에 그리고, 깨어 있으면 펫 쪽으로 고개를 돌린다.
class _GuestSprite extends SpriteAnimationGroupComponent<Behavior>
    with TapCallbacks, HasGameReference<PetGame> {
  _GuestSprite(this.mind, this.sheet, this.guest, this.index)
    : super(
        anchor: Anchor.bottomCenter,
        size: Vector2.all(_frame),
        priority: 1,
      );

  final GuestMind mind;
  final SpriteSheet sheet;
  final Guest guest;

  /// 몇 번째 손님인지. 따라 할 때 차례로 조금씩 늦게 한다.
  final int index;
  int _seenMimic = 0;
  double _mimicIn = -1;
  // 앉힌 때의 번호로 시작한다. 0으로 시작하면 발표회 뒤에 들어온 애가 괜히 앉아 버린다.
  int _seenRecital = 0;
  int _seenCheer = 0;
  double _cheerIn = -1;
  int _seenShare = 0;
  final _shadow = Paint()..color = const Color(0x477862AA);
  bool _facingLeft = true;

  @override
  Future<void> onLoad() async {
    animations = {
      for (final e in _PetSprite._rows.entries)
        e.key: sheet.createAnimation(row: e.value.$1, stepTime: e.value.$2),
    };
    current = mind.step.behavior;
    _seenRecital = game.controller.recitalGen;
    _seenCheer = game.controller.cheerGen;
    _seenShare = game.controller.shareGen;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.controller.atCafe) game.onGuestTap?.call(guest);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final c = game.controller;
    final now = c.now();
    // 발표회가 시작되면 앉아서 보고, 도장을 받으면 차례로 기뻐한다.
    if (c.recitalGen != _seenRecital) {
      _seenRecital = c.recitalGen;
      mind.act(const [PetStep(Behavior.sit, 35)]);
    }
    if (c.cheerGen != _seenCheer) {
      _seenCheer = c.cheerGen;
      _cheerIn = 0.2 + index * 0.25;
    }
    if (_cheerIn >= 0) {
      _cheerIn -= dt;
      if (_cheerIn < 0) {
        mind.act(const [
          PetStep(Behavior.happy, 1.5),
          PetStep(Behavior.jump, 1.3),
        ]);
      }
    }
    // 간식을 나눠 받는 애는 펫 옆으로 와서 먹고 기뻐한다.
    if (c.shareGen != _seenShare) {
      _seenShare = c.shareGen;
      if (c.shareGuest == guest.id) {
        final pet = game.floorX(c.petX) / game.size.x;
        final side = mind.x < pet ? -0.13 : 0.13;
        final to = (pet + side).clamp(0.08, 0.92);
        // 걷기는 시간이 다 되면 닿기 전에 끝난다. 멀리 앉은 애도 닿게 거리만큼 준다(초당 0.1).
        mind.act([
          PetStep(Behavior.walk, (to - mind.x).abs() / 0.1 + 1, targetX: to),
          const PetStep(Behavior.eat, 2.5),
          const PetStep(Behavior.happy, 1.5),
        ]);
      }
    }
    // 유치원 친구들은 낮잠 시간에, 카페 손님은 밤에 잔다.
    final night = c.spot == Spot.kindergarten ? kinderNap(now) : cafeNight(now);
    mind.tick(dt, night: night);
    // 펫이 개인기를 해냈다. 놀이 사이가 넘는 애만, 차례로 조금씩 늦게 따라 한다.
    if (c.mimicGen != _seenMimic) {
      _seenMimic = c.mimicGen;
      final bond = c.friends[guest.id]?.bond ?? Bond.none;
      if (bond.index >= Bond.play.index && c.mimicTrick != null) {
        _mimicIn = 0.6 + index * 0.35;
      }
    }
    if (_mimicIn >= 0) {
      _mimicIn -= dt;
      if (_mimicIn < 0 && c.mimicTrick != null) {
        mind.act(mimicSteps(c.mimicTrick!));
      }
    }
    var step = mind.step;
    final moving =
        step.behavior == Behavior.walk || step.behavior == Behavior.run;
    if (moving && step.targetX != null) {
      final d = step.targetX! - mind.x;
      if (d.abs() < 0.01) {
        mind.arrived(night: night);
        step = mind.step;
      } else {
        _facingLeft = d < 0;
        final speed = step.behavior == Behavior.run ? 0.25 : 0.1;
        mind.x += d.sign * (speed * dt).clamp(0, d.abs());
      }
    } else if (step.behavior != Behavior.sleep) {
      _facingLeft = game.floorX(c.petX) < game.size.x * mind.x;
    }
    current = step.behavior;
    final k = game.guestScale;
    scale.setValues(_facingLeft ? -k : k, k);
    position.setValues(game.size.x * mind.x, game.seatBase);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(16, 30.5), width: 22, height: 3),
      _shadow,
    );
    super.render(canvas);
  }
}

/// 유치원에 맡겨 둔 동안(지금 시각)과 홈캠 다시보기(장면 시각) 화면이 카메라라는 표시. 모서리 틀, 깜빡이는 빨간 점, 시각.
class _Cctv extends Component with HasGameReference<PetGame> {
  _Cctv() : super(priority: 4);

  double _t = 0;
  final _dot = Paint()..color = const Color(0xFFE5484D);
  final _frameLine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0xD9FFFFFF);

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final c = game.controller;
    if (!c.inDaycare && !c.replaying) return;
    final w = game.size.x, h = game.size.y;
    const m = 10.0, len = 20.0;
    for (final (x, y, sx, sy) in [
      (m, m, 1.0, 1.0),
      (w - m, m, -1.0, 1.0),
      (m, h - m, 1.0, -1.0),
      (w - m, h - m, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + sy * len)
          ..lineTo(x, y)
          ..lineTo(x + sx * len, y),
        _frameLine,
      );
    }
    // 가랜드·창 같은 밝은 그림 위에서도 읽히게 글자 밑에 어두운 띠를 깐다.
    final back = Paint()..color = const Color(0x8C1E2428);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(m + 6, m + 6, 60, 22),
        const Radius.circular(11),
      ),
      back,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - m - 66, m + 6, 60, 22),
        const Radius.circular(11),
      ),
      back,
    );
    if (_t % 1.2 < 0.75) {
      canvas.drawCircle(const Offset(m + 16, m + 17), 5, _dot);
    }
    // 다시보기 중엔 그 장면이 찍힌 시각.
    final now = c.replayMoment?.at ?? c.now();
    String two(int v) => v.toString().padLeft(2, '0');
    for (final (text, right) in [
      ('REC', false),
      ('${two(now.hour)}:${two(now.minute)}', true),
    ]) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontFamily: C3Fonts.jua,
            fontSize: 13,
            color: Color(0xFFFFFFFF),
            shadows: [Shadow(color: Color(0x88000000), blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(right ? w - m - 10 - painter.width : m + 26, m + 9),
      );
    }
  }
}

/// 밤에 자는 펫 머리 위 꿈 풍선. 오늘 카페에서 만난 친구 얼굴이 번갈아 뜬다.
class _DreamBubble extends Component with HasGameReference<PetGame> {
  _DreamBubble(this.pet) : super(priority: 3);

  final _PetSprite pet;
  double _t = 0;
  final _cloud = Paint()..color = const Color(0xF2FFFFFF);
  final _edge = Paint()
    ..color = const Color(0xFFD9C9B4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final c = game.controller;
    if (c.out || c.walking || c.replaying) return;
    final faces = c.metToday;
    if (faces.isEmpty) return;
    // 잠들기 전에 미리 칠해 둔다. 잠든 뒤에 칠하면 첫 꿈이 늦게 뜬다.
    final g = faces[(_t ~/ 3) % faces.length];
    final sheet = game._guestSheets[PetGame._sheetKey(g)];
    if (sheet == null) {
      unawaited(game._guestSheet(g));
      return;
    }
    // 밤잠에만. 낮잠엔 안 뜬다.
    if (c.step.behavior != Behavior.sleep || c.bubble != null || !c.nightNow) {
      return;
    }
    const k = 2.0;
    const size = _frame * k;
    final head = Offset(
      pet.position.x,
      pet.position.y - _frame * game.pixelScale * 0.6,
    );
    final center = _ideaCloud(
      canvas,
      head: head,
      size: size,
      width: game.size.x,
      fill: _cloud,
      edge: _edge,
    );
    sheet
        .getSprite(0, (_t * 4).floor() % 4)
        .render(
          canvas,
          position: Vector2(center.dx - size / 2, center.dy - size / 2),
          size: Vector2.all(size),
        );
  }
}

/// 머리 위 생각 구름(말 없는 풍선). 꿈 풍선과 소원 풍선이 같이 쓴다. 그림이 들어갈 가운데를 돌려준다.
Offset _ideaCloud(
  Canvas canvas, {
  required Offset head,
  required double size,
  required double width,
  required Paint fill,
  required Paint edge,
}) {
  final center = Offset(
    (head.dx + 44).clamp(size / 2 + 10, width - size / 2 - 10),
    (head.dy - 40 - size / 2).clamp(size / 2 + 8, double.infinity),
  );
  final body = Rect.fromCenter(
    center: center,
    width: size + 18,
    height: size + 12,
  );
  final rr = RRect.fromRectAndRadius(body, Radius.circular(body.height / 2));
  canvas.drawRRect(rr, fill);
  canvas.drawRRect(rr, edge);
  for (final (f, r) in const [(0.28, 7.0), (0.5, 9.0), (0.72, 7.0)]) {
    final o = Offset(body.left + body.width * f, body.top + 2);
    canvas.drawCircle(o, r, fill);
    canvas.drawCircle(o, r, edge);
  }
  for (final (dx, dy, r) in const [(10.0, -8.0, 3.0), (22.0, -20.0, 5.0)]) {
    final o = head.translate(dx, dy);
    canvas.drawCircle(o, r, fill);
    canvas.drawCircle(o, r, edge);
  }
  return center;
}

/// 오늘의 소원이 생각 풍선으로 가끔 떴다 진다. 늘 떠 있으면 할 일 목록처럼 읽혀서 잠깐씩만.
/// 소원 풍선이 뜨는 주기(기본값): 연 지 [wishFirst]초 뒤 처음, 그다음 [wishEvery]초마다 [wishShow]초.
/// 잠깐 열어 보는 사람(엘리베이터 10초)도 한 번은 보게 처음을 앞당겼다.
const wishFirst = 3.0;
const wishEvery = 20.0;
const wishShow = 6.0;

class _WishBubble extends Component with HasGameReference<PetGame> {
  _WishBubble(this.pet) : super(priority: 3);

  final _PetSprite pet;
  double _t = 0;
  final _cloud = Paint()..color = const Color(0xF2FFFFFF);
  final _edge = Paint()
    ..color = const Color(0xFFD9C9B4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final _pixel = Paint()..filterQuality = FilterQuality.none;
  final Map<String, ui.Image> _icons = {};

  @override
  Future<void> onLoad() async {
    for (final k in WishKind.values) {
      final name = wishIcon(k);
      if (name == null) continue;
      _icons[name] = await game.images.load('ui/$name.png');
    }
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final c = game.controller;
    final w = c.openWish;
    if (w == null || c.out || c.walking || c.replaying) return;
    if (c.bubble != null || c.nightNow || c.ball != Ball.none) return;
    // 차분할 때만. 기뻐하거나(하트)·먹거나(밥그릇)·자는(z) 동안은 그 그림과 겹친다.
    // 삐진 때는 넣는다. 배고프거나 우울하면 반 넘게 삐져 있어 소원이 거의 안 보였다(폰에서 확인).
    if (!const {
      Behavior.idle,
      Behavior.sit,
      Behavior.walk,
      Behavior.sniff,
      Behavior.sulk,
      Behavior.lieBeside,
      Behavior.watchWindow,
      Behavior.waitAtDoor,
    }.contains(c.step.behavior)) {
      return;
    }
    // 친구 얼굴은 미리 칠해 둔다(뜰 때 칠하면 첫 번엔 빈 풍선이다).
    final friend = c.wishFriend;
    SpriteSheet? face;
    if (friend != null) {
      face = game._guestSheets[PetGame._sheetKey(friend)];
      if (face == null) {
        unawaited(game._guestSheet(friend));
        return;
      }
    }
    if (_t < wishFirst || (_t - wishFirst) % wishEvery >= wishShow) return;
    // 깨어 있을 땐 머리가 프레임 위쪽이다(꿈 풍선은 누운 머리라 0.6).
    final head = Offset(
      pet.position.x,
      pet.position.y - _frame * game.pixelScale * 0.88,
    );
    if (face != null) {
      const k = 2.0;
      const size = _frame * k;
      final center = _ideaCloud(
        canvas,
        head: head,
        size: size,
        width: game.size.x,
        fill: _cloud,
        edge: _edge,
      );
      face
          .getSprite(0, 0)
          .render(
            canvas,
            position: Vector2(center.dx - size / 2, center.dy - size / 2),
            size: Vector2.all(size),
          );
      return;
    }
    final icon = _icons[wishIcon(w.kind)];
    if (icon == null) return;
    const size = 12.0 * 4;
    final center = _ideaCloud(
      canvas,
      head: head,
      size: size,
      width: game.size.x,
      fill: _cloud,
      edge: _edge,
    );
    canvas.drawImageRect(
      icon,
      const Rect.fromLTWH(0, 0, 12, 12),
      Rect.fromCenter(center: center, width: size, height: size),
      _pixel,
    );
  }
}

class _ThoughtBubble extends Component with HasGameReference<PetGame> {
  _ThoughtBubble(this.controller, this.pet) : super(priority: 3);

  final PetController controller;
  final _PetSprite pet;

  @override
  void render(Canvas canvas) {
    final text = controller.bubble;
    if (text == null || !game.showThoughtInRoom) return;
    final painter = TextPainter(
      text: TextSpan(text: keepWords(text), style: C3Text.pet),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: min(game.size.x * 0.7, 240));

    final pad = cloudBodyPadding;
    final w = painter.width + pad.horizontal;
    final h = painter.height + pad.vertical;
    final headTop = pet.position.y - _frame * game.pixelScale * 0.8;
    final cx = pet.position.x.clamp(w / 2 + 8, game.size.x - w / 2 - 8);
    var bottom = headTop - 26;
    // 손님이 있는 곳(카페·유치원)에선 손님 줄보다 위로 띄운다. 펫 머리 위 그대로면 뒤에 앉은 손님 몸을 가렸다.
    if (controller.out && controller.guests.isNotEmpty) {
      bottom = min(bottom, game.seatBase - _frame * game.guestScale - 6);
    }
    // 키보드가 올라와 게임 영역이 낮아져도 구름이 방 위로 넘치지 않게 한다.
    // 손님 위로 올릴 자리가 없으면 손님을 가리더라도 글자가 잘리지 않는 쪽을 고른다.
    final top = (bottom - h).clamp(6.0, double.infinity);
    final body = Rect.fromLTWH(cx - w / 2, top, w, h);
    paintThoughtCloud(
      canvas,
      body,
      Offset(pet.position.x, headTop),
      aiTag: controller.bubbleFromAi,
    );
    painter.paint(canvas, Offset(body.left + pad.left, body.top + pad.top));
  }
}
