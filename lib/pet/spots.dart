/// 동네 지도의 장소. 문을 열면 고른다. 자리는 지도 그림(assets/art/town_map.png)에서 건물 아래쪽 비율.
enum Spot {
  home('집', 0.23, 0.86),
  cafe('카페', 0.68, 0.655),
  park('공원', 0.17, 0.42),
  kindergarten('유치원', 0.515, 0.355),
  hospital('병원', 0.86, 0.415),
  treatShop('간식 가게', 0.81, 0.92);

  const Spot(this.label, this.x, this.y);

  final String label;

  /// 이름표 가운데 자리(가로·세로 비율 0~1). 건물은 이름표 위에 있다.
  final double x;
  final double y;
}

/// 지도에서 누르는 칸(지도 가로·세로 비율). 이름표와 그 위 건물을 덮고, 서로 겹치지 않는다.
const spotTapWidth = 0.34;
const spotTapHeight = 0.22;
