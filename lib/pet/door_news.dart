import '../services/weather.dart';
import 'cues.dart';
import 'josa.dart';
import 'pet_rules.dart';

/// 아침 현관 소식. 아침에 그날 날씨에 맞는 걸 펫이 현관에 물어다 둔다. 날씨 앱 대신 펫을 본다.
/// 맑고 포근한 날은 아무것도 안 둔다(날마다 뭔가 있으면 숙제가 된다). 예보가 빗나가도 삐지지 않는다.
enum DoorItem { umbrella, mask, scarf }

/// 펫의 아침(하루가 바뀌는 5시부터 정오 전까지). 정오가 되면 현관 물건은 치운다.
bool doorMorning(DateTime t) => t.hour >= dayStartHour && t.hour < 12;

/// 열 때 챙기는 물건(주머니·선물)이 먼저 도착하게 열고 조금 뒤에 물고 온다(꺼내 주기와 같은 까닭).
const doorAfter = Duration(seconds: 12);

/// 오늘 비 올 확률이 이만큼부터 우산.
const umbrellaChance = 60;

/// 오늘 최저기온이 이만큼보다 낮으면 목도리.
const scarfBelowC = 3.0;

/// 비·눈이 오거나 올 것 같으면 우산, 미세먼지가 나쁘면 마스크, 추우면 목도리. 아무것도 아니면 null.
DoorItem? doorItemFor(Weather w) {
  if (w.sky == Sky.rain ||
      w.sky == Sky.snow ||
      (w.rainChance ?? 0) >= umbrellaChance) {
    return DoorItem.umbrella;
  }
  if (w.dusty) return DoorItem.mask;
  if ((w.lowC ?? w.tempC) < scarfBelowC) return DoorItem.scarf;
  return null;
}

String doorItemName(DoorItem i) => switch (i) {
  DoorItem.umbrella => '우산',
  DoorItem.mask => '마스크',
  DoorItem.scarf => '목도리',
};

/// 현관 앞에 앉아서 하는 말. 펫은 냄새와 공기로 안다.
String doorThought(DoorItem i) => switch (i) {
  DoorItem.umbrella => '비 냄새 나. 이거 챙겨',
  DoorItem.mask => '공기가 매워. 이거 써',
  DoorItem.scarf => '밖이 차가워. 이거 둘러',
};

String _why(DoorItem i) => switch (i) {
  DoorItem.umbrella => '비 냄새가 났다',
  DoorItem.mask => '공기가 매웠다',
  DoorItem.scarf => '밖이 차가웠다',
};

/// 물어다 둔 날 일기. 때를 나타내는 말(아침에 등)은 폰 일기가 앞에 붙이니 넣지 않는다.
String doorPlacedLine(DoorItem i) =>
    '현관에 ${josa(doorItemName(i), '을/를')} 물어다 놨다. ${_why(i)}';

String doorTakenLine(DoorItem i) =>
    '현관에 둔 ${josa(doorItemName(i), '을/를')} 주인이 챙겼다';

/// 물고 와서 현관 앞에 앉아 알려 주고 내려놓은 뒤, 물건이 보이게 방 가운데로 물러나 꼬리를 흔든다.
/// [StepTag.door] 동안 입에 물고 있다.
List<PetStep> doorSteps(DoorItem i) => [
  const PetStep(Behavior.walk, 9, targetX: doorX + 0.06, tag: StepTag.door),
  PetStep(Behavior.sit, 3.5, tag: StepTag.door, thought: doorThought(i)),
  const PetStep(Behavior.sniff, 1, cue: Cue.drop),
  const PetStep(Behavior.walk, 6, targetX: rugX),
  const PetStep(Behavior.happy, 1.5),
];
