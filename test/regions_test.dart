import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/services/kr_regions.dart';
import 'package:mypet/services/regions.dart';

void main() {
  test('목록에 시·도 16개 이상과 시·군·구 200개 이상이 있고 좌표가 한국 안이다', () {
    expect(krRegions.where((r) => r.$5).length, greaterThanOrEqualTo(16));
    expect(krRegions.where((r) => !r.$5).length, greaterThanOrEqualTo(200));
    for (final (_, _, lat, lon, _) in krRegions) {
      expect(lat, inInclusiveRange(33.0, 38.7));
      expect(lon, inInclusiveRange(124.5, 132.0));
    }
  });

  test('"서울"·"관악"·"수원"처럼 흔히 치는 이름이 바로 나온다', () {
    expect(searchKorea('서울').first.label, '서울특별시');
    expect(searchKorea('관악').first.label, '관악구, 서울');
    expect(searchKorea('관악구').first.label, '관악구, 서울');
    expect(searchKorea('수원').first.label, '수원시, 경기');
    expect(searchKorea('강남').first.label, '강남구, 서울');
    expect(searchKorea('부산').first.label, '부산광역시');
  });

  test('같은 이름이 여러 곳이면 시·도로 가르고, "서울 중구"처럼 앞에 시·도를 붙여 좁힐 수 있다', () {
    final all = searchKorea('중구');
    expect(all.length, greaterThanOrEqualTo(5));
    expect(all.map((p) => p.region).toSet().length, all.length);
    expect(searchKorea('서울 중구').single.label, '중구, 서울');
    expect(searchKorea('부산 중구').single.label, '중구, 부산');
  });

  test('줄임말·조사 붙은 표기·합쳐진 시·도도 찾고, 같은 이름은 서울부터 보인다', () {
    expect(searchKorea('충북').first.label, '충청북도');
    expect(searchKorea('경남').first.label, '경상남도');
    expect(searchKorea('서울시').first.label, '서울특별시');
    expect(searchKorea('제주도').first.label, '제주특별자치도');
    expect(searchKorea('강원도').first.label, '강원특별자치도');
    // 2026년 광주·전남이 합쳐졌다. '광주'는 경기 광주시보다 그쪽이 먼저.
    final gwangju = searchKorea('광주');
    expect(gwangju.first.label, '전남광주통합특별시');
    expect(gwangju.map((p) => p.label), contains('광주시, 경기'));
    expect(searchKorea('광주 동구').single.label, '동구, 광주');
    expect(searchKorea('전남 목포').first.label, '목포시, 전남');
    expect(searchKorea('강서').first.label, '강서구, 서울');
    expect(searchKorea('분당').first.label, '분당구, 경기');
  });

  test('시·도 좌표가 먼 섬에 끌려 바다에 찍히지 않는다', () {
    final incheon = searchKorea('인천').first;
    expect(incheon.lon, greaterThan(126.4));
    final gyeongbuk = searchKorea('경북').first;
    expect(gyeongbuk.lon, lessThan(129.4));
  });

  test('없는 이름이나 빈 글은 빈 목록이라 인터넷 검색으로 넘어간다', () {
    expect(searchKorea('봉천동'), isEmpty);
    expect(searchKorea('   '), isEmpty);
    expect(searchKorea('Seoul'), isEmpty);
  });
}
