import 'kr_regions.dart';
import 'weather.dart';

/// 앱 안의 시·도·시·군·구 목록에서 동네를 찾는다. 인터넷 지역 검색(Open-Meteo)이 '서울'·'관악구' 같은
/// 한국 이름을 못 찾아서 흔한 이름은 여기서 바로 찾고, 동 이름처럼 없는 것만 인터넷에 묻는다.
List<Place> searchKorea(String query) {
  final words = query.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return const [];
  // "서울 중구"처럼 두 단어면 앞은 시·도, 뒤는 이름.
  final q = _stem(words.last);
  final where = words.length > 1 ? _stem(words.first) : null;
  final scored = <(int, int, Place)>[];
  for (final (i, (name, region, lat, lon, top)) in krRegions.indexed) {
    if (where != null && !region.contains(where) && !name.startsWith(where)) {
      continue;
    }
    final score = _score(name, top ? region : null, q);
    if (score == null) continue;
    scored.add((
      score,
      i,
      Place(name: name, region: top ? '' : region, lat: lat, lon: lon),
    ));
  }
  scored.sort((a, b) {
    final s = a.$1.compareTo(b.$1);
    return s != 0 ? s : a.$2.compareTo(b.$2);
  });
  return [for (final (_, _, p) in scored.take(8)) p];
}

/// 딱 맞으면 0, 앞이 맞으면 1, 가운데가 맞으면 2. '서울'은 '서울특별시'와, '관악'은 '관악구'와 딱 맞는 것으로
/// 친다. 시·도는 '충북'·'광주' 같은 짧은 이름으로도 딱 맞는다.
int? _score(String name, String? short, String q) {
  final stem = _stem(name);
  if (name == q || stem == q) return 0;
  if (short != null && short.contains(q)) return 0;
  if (name.startsWith(q) || stem.startsWith(q)) return 1;
  if (name.contains(q)) return 2;
  return null;
}

final _suffix = RegExp(r'(특별자치시|특별자치도|통합특별시|광역시|특별시|시|군|구|도)$');

/// '서울시'·'제주도'처럼 뒤에 붙은 시·군·구·도를 뗀다. '중구'·'남구'처럼 두 글자면 그대로.
String _stem(String name) =>
    name.length > 2 ? name.replaceFirst(_suffix, '') : name;
