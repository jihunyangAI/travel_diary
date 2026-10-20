import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:travel_diary/photo_location.dart';
import 'package:travel_diary/screens/timeline_screen.dart';

void main() {
  test('같은 날짜의 50미터 이내 사진은 한 장소로 묶는다', () {
    final morning = DateTime(2026, 10, 21, 9, 10);
    final later = DateTime(2026, 10, 21, 11, 40);
    final nextDay = DateTime(2026, 10, 22, 8);
    final photos = [
      PhotoLocation(latitude: 37.5, longitude: 127.0, takenAt: morning),
      PhotoLocation(
        latitude: 37.5,
        longitude: 127.0 + _longitudeDelta(37.5, 20),
        takenAt: later,
      ),
      PhotoLocation(
        latitude: 37.5,
        longitude: 127.0 + _longitudeDelta(37.5, 200),
        takenAt: DateTime(2026, 10, 21, 15),
      ),
      PhotoLocation(latitude: 37.5, longitude: 127.0, takenAt: nextDay),
    ];

    final days = buildTimelineDays(photos);

    expect(days, hasLength(2));
    expect(days.first.date, DateTime(2026, 10, 21));
    expect(days.first.places, hasLength(2));
    expect(days.first.places.first.photos, hasLength(2));
    expect(days.first.places.first.dwell, const Duration(hours: 2, minutes: 30));
    expect(formatPlaceTime(days.first.places.first), '09:10 – 11:40');
    expect(formatDwell(days.first.places.first), '2시간 30분');
    expect(days.last.places, hasLength(1));
  });

  test('날짜가 없는 사진은 따로 묶고 통계는 장소와 사진을 센다', () {
    final photos = [
      const PhotoLocation(latitude: 0, longitude: 0),
      PhotoLocation(
        latitude: 0,
        longitude: _longitudeDelta(0, 10),
        takenAt: null,
      ),
    ];

    final stats = summarizeTimeline(photos);

    expect(buildTimelineDays(photos).single.date, isNull);
    expect(stats.placeCount, 1);
    expect(stats.photoCount, 2);
    expect(formatTimelineDate(null), '날짜 없음');
    expect(formatTimelineDistance(0.01), '10m');
    expect(formatTimelineDistance(12), '12km');
    expect(formatTimelineDistance(12.4), '12.4km');
  });

  test('역지오코딩 주소는 중복 없이 지역과 도로를 붙인다', () {
    const place = Placemark(
      administrativeArea: '서울특별시',
      locality: '서울',
      subLocality: '중구',
      thoroughfare: '세종대로',
      subThoroughfare: '110',
    );

    expect(formatPlacemark(place), '서울특별시 중구 세종대로 110');
  });
}

double _longitudeDelta(double latitude, double meters) {
  final kilometers = meters / 1000;
  return kilometers / (haversineKm(latitude, 0, latitude, 1));
}
