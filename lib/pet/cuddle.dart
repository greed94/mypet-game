import 'dart:math';

import 'cues.dart';
import 'pet_rules.dart';

/// 애교(대표가 꼽은 '꼭 기억할 것' 3순위). 친밀도 단계마다 다르게 다가온다.

/// 작은 목소리: 힘없는 말엔 대답이나 개인기 대신 천천히 와서 말없이 옆에 앉는다.
/// 상담사처럼 들리지 않게 속마음도 비운다. 위기 문장은 그보다 먼저 상담 안내로 간다.
/// 엎드리기는 삐짐과 같은 그림이라 곁에 있어 주는 게 아니라 삐진 걸로 보여서 앉기로.
const quietSteps = [
  PetStep(Behavior.walk, 8, targetX: rugX),
  PetStep(Behavior.sit, 12),
];

/// 손 베개: 방 바닥을 길게 누르면 그 자리에 주인 손이 놓이고, 펫이 사이에 맞게 다가온다.
/// 낯가릴 땐 멀찍이서 냄새만, 친하면 옆에 앉아 비비고, 가족이면 손을 베고 눕는다(졸리면 그대로 잔다).
/// 손에 닿은 단계에 StepTag.hand가 붙는다(그때 보상·일기). 걷기는 닿으면 끝나니 넉넉히.
List<PetStep> handSteps(Intimacy i, double handX, {bool sleepy = false}) {
  final x = handX.clamp(0.12, 0.88).toDouble();
  return switch (i) {
    Intimacy.stranger => [
      PetStep(
        Behavior.walk,
        10,
        targetX: (x + (x < 0.5 ? 0.16 : -0.16)).clamp(0.1, 0.9).toDouble(),
      ),
      const PetStep(
        Behavior.sniff,
        2.4,
        cue: Cue.sniff,
        tag: StepTag.hand,
        thought: '킁킁… 이 손 냄새는…',
      ),
      const PetStep(Behavior.idle, 2),
    ],
    Intimacy.friend => [
      PetStep(Behavior.walk, 10, targetX: x),
      const PetStep(Behavior.sniff, 1.2, cue: Cue.sniff),
      const PetStep(
        Behavior.happy,
        1.8,
        cue: Cue.yip,
        tag: StepTag.hand,
        thought: '이 손 좋아',
      ),
      const PetStep(Behavior.sit, 6),
    ],
    Intimacy.family => [
      PetStep(Behavior.run, 8, targetX: x, cue: Cue.yip),
      const PetStep(Behavior.happy, 1.2),
      PetStep(
        sleepy ? Behavior.sleep : Behavior.lieBeside,
        sleepy ? 30 : 12,
        tag: StepTag.hand,
        cue: Cue.sigh,
        thought: sleepy ? '여기서 잘래…' : '여기가 내 자리야',
      ),
    ],
  };
}

/// 같은 손 베개로 친밀도를 다시 받으려면 이만큼 지나야 한다(기본값). 길게 누르기를 되풀이해 친밀도를 쌓지 않게.
const handBondEvery = Duration(minutes: 10);

/// 조르기: 가족이 된 펫은 주인이 한동안 아무것도 안 하면 먼저 다가와 조른다. 앱을 열 때마다 한 번까지.
/// 안 받아 줘도 아무 일 없다.
const begAfter = Duration(seconds: 40);

/// 조른 뒤 이 안에 쓰다듬으면 앵긴다(기본값).
const begAnswerWithin = Duration(seconds: 8);

const _begLines = ['나 여기 있어…', '심심해… 놀아 줄래?', '쓰다듬어 줄래?', '히히, 나 봐 봐'];

List<PetStep> begSteps(Random r) => [
  const PetStep(Behavior.run, 8, targetX: 0.5, cue: Cue.yip),
  const PetStep(Behavior.sit, 1.2),
  PetStep(
    Behavior.happy,
    1.6,
    cue: Cue.whine,
    tag: StepTag.beg,
    thought: _begLines[r.nextInt(_begLines.length)],
  ),
  const PetStep(Behavior.sit, 6),
];

/// 조르자 쓰다듬어 줬다.
const begAnsweredSteps = [
  PetStep(Behavior.jump, 1.3, cue: Cue.yip),
  PetStep(Behavior.happy, 1.8, thought: '헤헤'),
];
