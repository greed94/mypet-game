import 'dart:math';

import 'cues.dart';
import 'pet_rules.dart';

/// 숨긴 보물. 가족이 되기 전까지 펫은 방석 밑에 아끼는 걸 하나 숨겨 두고 가끔 몰래 확인한다.
/// 주인이 방석을 누르면 달려와 깔고 앉는다. 가족이 되면 그걸 꺼내 주인에게 준다(한 번뿐).

/// 앱을 열 때 이 확률로 그번에 한 번 확인하러 간다. 하루에 한두 번쯤 보이게.
const hideCheckChance = 0.4;

/// 열고 나서 반김·물건 내밀기가 지나간 뒤에 간다.
const hideCheckAfter = Duration(seconds: 30);

/// 꺼내 주기도 열고 조금 뒤에. 열 때 챙기는 물건(주머니·선물)은 펫이 첫 동작을 고른 뒤에 도착해서,
/// 바로 시작하면 방석에서 꺼낸 순간 입에 그 물건이 보였다.
const revealAfter = Duration(seconds: 12);

/// 이번에 연 때([openedAt])에 확인하러 갈지. 같은 분에 열면 늘 같다.
/// 펫의 다른 움직임과 주사위를 나눠 쓰지 않게 따로 굴린다.
bool hideCheckOn(DateTime openedAt) =>
    Random(openedAt.millisecondsSinceEpoch ~/ 60000).nextDouble() <
    hideCheckChance;

/// 방석으로 가서 킁킁, 그대로 있는 걸 보고 하던 자리로 돌아온다.
List<PetStep> hideCheckSteps(double from) {
  final back = (from - rugX).abs() < 0.15 ? (from < rugX ? 0.3 : 0.7) : from;
  return [
    const PetStep(Behavior.walk, 9, targetX: rugX),
    const PetStep(Behavior.sniff, 2.5, cue: Cue.sniff, thought: '킁킁… 잘 있다'),
    PetStep(Behavior.walk, 9, targetX: back),
  ];
}

/// 주인이 방석을 누르면 달려와 그 위에 앉아 버린다.
const guardLine = '여기 아무것도 없어';
const guardSteps = [
  PetStep(Behavior.run, 4, targetX: rugX, cue: Cue.yip),
  PetStep(Behavior.sit, 5, thought: guardLine),
];

/// 가족이 된 날: 방석 밑을 킁킁 뒤져 꺼내 물고 돌아앉아 내민다. [StepTag.unearth]에서 물건이 입에 생긴다.
const revealSteps = [
  PetStep(Behavior.walk, 9, targetX: rugX),
  PetStep(Behavior.sniff, 2.5, cue: Cue.sniff, thought: '이제 보여 줘도 되겠다'),
  PetStep(Behavior.happy, 1.5, cue: Cue.pickUp, tag: StepTag.unearth),
  PetStep(Behavior.sit, 40),
];
