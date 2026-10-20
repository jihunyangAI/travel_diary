import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:travel_diary/photo_location.dart';
import 'package:travel_diary/photo_map.dart';

void main() {
  test('GPS가 없으면 사진 위치에서 제외한다', () {
    expect(photoLocationFromExif(latitude: null, longitude: 127), isNull);
    expect(photoLocationFromExif(latitude: 0, longitude: 0), isNull);
    expect(photoLocationFromExif(latitude: 37.5, longitude: 127.0), isNotNull);
  });

  test('촬영일 오름차순으로 정렬하고 날짜가 없는 사진은 뒤로 보낸다', () {
    final later = DateTime(2026, 10, 2);
    final earlier = DateTime(2026, 10, 1);
    final sorted = sortPhotoLocationsByDate([
      PhotoLocation(latitude: 1, longitude: 1, takenAt: later),
      const PhotoLocation(latitude: 2, longitude: 2),
      PhotoLocation(latitude: 3, longitude: 3, takenAt: earlier),
    ]);

    expect(sorted.map((photo) => photo.latitude), [3, 1, 2]);
  });

  test('최근 1개월 시작일은 말일을 넘기지 않는다', () {
    expect(startOfRecentMonth(DateTime(2026, 3, 31)), DateTime(2026, 2, 28));
    expect(startOfRecentMonth(DateTime(2024, 3, 31)), DateTime(2024, 2, 29));
    expect(startOfRecentMonth(DateTime(2026, 1, 15)), DateTime(2025, 12, 15));
  });

  test('Haversine 총 이동거리는 시간순 구간을 더한다', () {
    const equatorStep = [
      PhotoLocation(latitude: 0, longitude: 0),
      PhotoLocation(latitude: 0, longitude: 1),
      PhotoLocation(latitude: 0, longitude: 0),
    ];

    expect(haversineKm(0, 0, 0, 1), closeTo(111.19, 0.05));
    expect(totalDistanceKm(equatorStep), closeTo(222.39, 0.1));
    expect(
      totalDistanceKm(const [PhotoLocation(latitude: 37, longitude: 127)]),
      0,
    );
  });

  test('마커는 빨간색이고 경로는 시간순 파란색 두께 5다', () {
    final photos = [
      PhotoLocation(
        latitude: 37.5,
        longitude: 127.0,
        takenAt: DateTime(2026, 10, 1, 9),
      ),
      PhotoLocation(
        latitude: 35.1,
        longitude: 129.0,
        takenAt: DateTime(2026, 10, 2, 15, 30),
      ),
    ];

    final markers = buildPhotoMarkers(photos);
    final routes = buildRoutePolylines(photos);

    expect(markers, hasLength(2));
    expect(
      markers.map((marker) => marker.infoWindow.title),
      containsAll(['2026.10.01 09:00', '2026.10.02 15:30']),
    );
    final redMarker = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueRed,
    ).toJson();
    expect(
      markers.map((marker) => marker.icon.toJson()),
      everyElement(redMarker),
    );

    final route = routes.single;
    expect(route.color, Colors.blue);
    expect(route.width, 5);
    expect(route.points.map((point) => point.latitude), [37.5, 35.1]);
  });
}
