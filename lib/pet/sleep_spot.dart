import 'pet_rules.dart';

/// 자는 자리. 친밀도 단계마다 밤에 자러 가는 곳이 바뀐다. 말없이 거리가 줄어드는 걸 보여 준다.
/// 낯가릴 땐 방석(방 가운데), 친해지면 문 앞(주인이 들어오는 곳), 가족이 되면 주인이 마지막으로 쓰다듬은 자리.
/// 펫 그림이 패드(오른쪽 끝)에 걸리는 자리에서는 자지 않는다.
double sleepSpot(Intimacy i, {double? lastTouchX}) => switch (i) {
  Intimacy.stranger => rugX,
  Intimacy.friend => doorX + 0.06,
  Intimacy.family => (lastTouchX ?? rugX).clamp(0.15, 0.78).toDouble(),
};

/// 자는 자리까지 이만큼보다 멀면 걸어가서 잔다(가까우면 그 자리에서).
const sleepSpotSlack = 0.08;

/// 일기에 쓰는 자는 자리 이름. 가족이어도 주인이 만진 적이 없으면 방석에서 잔다.
String sleepPlaceName(Intimacy i, {double? lastTouchX}) => switch (i) {
  Intimacy.stranger => '방석',
  Intimacy.friend => '문 앞',
  Intimacy.family => lastTouchX == null ? '방석' : '주인 냄새 나는 자리',
};

/// 그 단계가 되고 처음 제 자리에서 잔 날 일기. 낯가릴 때 방석은 처음부터 자던 곳이라 없고,
/// 가족의 자리는 주인이 만진 적이 있어야 '주인 냄새'가 난다.
String? firstSpotLine(Intimacy i, {double? lastTouchX}) => switch (i) {
  Intimacy.stranger => null,
  Intimacy.friend => '문 앞에서 잤다. 주인이 들어오면 제일 먼저 알 수 있게',
  Intimacy.family => lastTouchX == null ? null : '거기는 주인 냄새가 난다. 그래서 거기서 잤다',
};
