/// 달의 위상 0~1. 0은 삭, 0.5는 보름. 평균 삭망월로 계산해서 하루 안팎 어긋날 수 있다.
double moonPhase(DateTime t) {
  const synodic = 29.530588853;
  final newMoon = DateTime.utc(2000, 1, 6, 18, 14);
  final days = t.toUtc().difference(newMoon).inMinutes / 1440;
  final p = (days / synodic) % 1;
  return p < 0 ? p + 1 : p;
}

/// 7월부터 이듬해 6월까지를 한 겨울로 본다. 첫눈은 겨울마다 한 번.
int winterOf(DateTime t) => t.month >= 7 ? t.year : t.year - 1;
