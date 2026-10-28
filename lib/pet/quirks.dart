import 'dart:math';

import 'guest.dart';
import 'josa.dart';
import 'pet_rules.dart';

/// 우리 애만의 버릇. 펫마다 하나를 받고 어디에도 써 있지 않다. 주인이 자주 하는 일(밥·쓰다듬기·반김·잠·공놀이)에
/// 붙어 첫 주 안에 보이고, 다른 날 또 하면 그날 일기에 한 줄 새어 나온다(첫날은 주인이 먼저 알아챌 틈).
/// 받은 버릇은 DB(pets.quirk)에 남겨, 버릇 종류가 늘어도 이미 있는 펫의 버릇은 바뀌지 않는다.
enum Quirk {
  /// 밥을 주면 바로 안 먹고 얌전히 앉았다가 먹는다.
  sitBeforeEat,

  /// 다 먹고 나서 빈 그릇을 한참 킁킁댄다.
  sniffBowlAfter,

  /// 반기고 나면 꼭 주인 발 냄새를 맡는다.
  sniffOwnerAfterGreet,

  /// 쓰다듬으면 꼭 한 번 폴짝 뛴다.
  hopWhenPetted,

  /// 자기 전에 제자리에서 몇 번 돌아선다.
  circleBeforeSleep,

  /// 물어 온 공을 놓기 전에 한 바퀴 돈다.
  spinBeforeDrop,
}

/// 새 펫이 받을 버릇. 같은 펫(id·태어난 때)이면 늘 같다.
Quirk quirkFor(int petId, DateTime bornAt) =>
    Quirk.values[Random(
      petId * 104729 + bornAt.millisecondsSinceEpoch ~/ 1000,
    ).nextInt(Quirk.values.length)];

/// 카페 손님마다 있는 버릇(데이터). 사흘 내리 어울리면 우리 애한테 옮는다.
Quirk guestQuirk(String guestId) =>
    Quirk.values[stableHash('quirk:$guestId') % Quirk.values.length];

/// 이만큼 내리 만나 놀이 사이 이상이면 그 애 버릇이 옮는다.
const catchStreak = 3;

/// 옮은 버릇은 그 버릇을 가진 친구를 이만큼(펫의 날)보다 오래 못 보면 슬그머니 사라진다.
const habitFadeDays = 7;

/// 일기에 쓰는 버릇 이름.
String quirkDesc(Quirk q) => switch (q) {
  Quirk.sitBeforeEat => '밥 앞에서 앉는 버릇',
  Quirk.sniffBowlAfter => '빈 그릇을 킁킁대는 버릇',
  Quirk.sniffOwnerAfterGreet => '반기고 나서 발 냄새 맡는 버릇',
  Quirk.hopWhenPetted => '쓰다듬으면 폴짝 뛰는 버릇',
  Quirk.circleBeforeSleep => '자기 전에 빙글빙글 도는 버릇',
  Quirk.spinBeforeDrop => '공 놓기 전에 한 바퀴 도는 버릇',
};

String habitCaughtLine(String friend, Quirk q) =>
    '${josa(friend, '과/와')} 사흘 내리 놀았더니 ${josa(quirkDesc(q), '이/가')} 옮았다';

/// [friend]가 없으면(지워진 아는 강아지) 이름 없이.
String habitFadedLine(String? friend, Quirk q) => friend == null
    ? '친구한테 옮은 ${josa(quirkDesc(q), '이/가')} 슬그머니 없어졌다'
    : '요즘 ${josa(friend, '을/를')} 못 봐서 ${josa(quirkDesc(q), '이/가')} 슬그머니 없어졌다';

/// 일기에 새어 나오는 한 줄. 왜 그러는지는 펫도 잘 모른다.
String quirkLine(Quirk q) => switch (q) {
  Quirk.sitBeforeEat => '밥 앞에선 앉는다. 누가 시킨 건 아니다',
  Quirk.sniffBowlAfter => '다 먹은 그릇에도 냄새는 남아 있다. 그래서 맡는다',
  Quirk.sniffOwnerAfterGreet => '주인이 오면 발 냄새부터 맡는다. 어디 다녀왔는지 거기 다 있다',
  Quirk.hopWhenPetted => '쓰다듬으면 몸이 폴짝 한다. 왜인지는 모른다',
  Quirk.circleBeforeSleep => '자기 전엔 몇 번 돈다. 그래야 자리가 된다',
  Quirk.spinBeforeDrop => '공은 한 바퀴 돌고 놓는다. 그게 규칙이다',
};

/// 제자리에서 몇 번 돌아서는 걸음. 옆에서 보면 좌우로 돌아서다 제자리에 선다.
/// 방 안쪽으로만 왔다 갔다 한다(방 끝에서 자도 문·패드에 걸치지 않게).
List<PetStep> circleSteps(double x) {
  final d = x > rugX ? -0.04 : 0.04;
  return [
    PetStep(Behavior.walk, 1.5, targetX: x + d),
    PetStep(Behavior.walk, 1.5, targetX: x),
    PetStep(Behavior.walk, 1.5, targetX: x + d),
    PetStep(Behavior.walk, 1.5, targetX: x),
  ];
}
