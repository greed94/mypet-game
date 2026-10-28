import 'pet_rules.dart';

/// 강아지 모양 틀. 견종이 아니라 실루엣 기준이라 믹스견도 가장 가까운 틀을 고른다.
/// 털색은 사진에서 뽑아 틀에 칠하므로 여기에는 모양만 있다.
class DogShape {
  const DogShape(this.id, this.examples);

  /// 그림 파일 이름 앞부분. assets/sprites/{id}_{단계}.png
  final String id;
  final String examples;
}

const dogShapes = [
  DogShape('papillon', '파피용·치와와'),
  DogShape('maltese', '말티즈·푸들·비숑·포메'),
  DogShape('shiba', '시바·진돗개·스피츠'),
  DogShape('retriever', '리트리버·비글·코커'),
  DogShape('corgi', '코기·닥스훈트'),
  DogShape('pug', '퍼그·프렌치불독·불독'),
  DogShape('noeul', '이전 버전 모양'),
];

/// 아는 강아지(남의 강아지)에게 고를 수 있는 틀. 사진으로 그린 실험 틀은 그 아이 그림이라 뺀다.
final friendShapes = [
  for (final s in dogShapes)
    if (s.id != 'noeul') s,
];

/// 목걸이 기본색. 틀의 포인트 키 색이 이 색으로 칠해진다.
const defaultAccent = 0xFFD64040;

/// 아기 그림이 들어온 틀. 없는 틀은 아기 때도 성체 그림을 쓴다.
const puppySheets = {
  'papillon',
  'maltese',
  'shiba',
  'retriever',
  'corgi',
  'pug',
};

DogShape shapeById(String id) =>
    dogShapes.firstWhere((s) => s.id == id, orElse: () => dogShapes.first);

String spriteAsset(String shape, PetStage stage) {
  final id = shapeById(shape).id;
  if (id == 'noeul') return 'sprites/papillon_adult.png';
  final puppy = stage == PetStage.puppy && puppySheets.contains(id);
  return 'sprites/${id}_${puppy ? 'puppy' : 'adult'}.png';
}
