import 'dart:math' as math;

import 'package:flutter/foundation.dart';

class PhotoLocation {
  const PhotoLocation({
    required this.latitude,
    required this.longitude,
    this.takenAt,
    this.assetId,
  });

  final double latitude;
  final double longitude;
  final DateTime? takenAt;

  /// 갤러리 사진 ID. 있으면 타임라인에서 섬네일을 불러온다.
  final String? assetId;
}

class PhotoImportResult {
  const PhotoImportResult({
    required this.photos,
    required this.skippedWithoutGps,
    required this.skippedOutsideRange,
  });

  final List<PhotoLocation> photos;
  final int skippedWithoutGps;
  final int skippedOutsideRange;
}

/// EXIF에 위도·경도가 없으면 null. (0, 0)은 위치 권한이 없어 지워진 값으로 본다.
PhotoLocation? photoLocationFromExif({
  double? latitude,
  double? longitude,
  DateTime? takenAt,
}) {
  if (latitude == null || longitude == null) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  if (latitude == 0 && longitude == 0) return null;
  return PhotoLocation(
    latitude: latitude,
    longitude: longitude,
    takenAt: takenAt,
  );
}

DateTime startOfRecentMonth(DateTime day) {
  final year = day.month == 1 ? day.year - 1 : day.year;
  final month = day.month == 1 ? 12 : day.month - 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final date = day.day > lastDay ? lastDay : day.day;
  return DateTime(year, month, date);
}

bool isWithinDateRange({
  required PhotoLocation photo,
  required DateTime start,
  required DateTime end,
}) {
  final takenAt = photo.takenAt;
  if (takenAt == null) return true;
  final rangeStart = DateTime(start.year, start.month, start.day);
  final rangeEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
  return !takenAt.isBefore(rangeStart) && !takenAt.isAfter(rangeEnd);
}

List<PhotoLocation> sortPhotoLocationsByDate(List<PhotoLocation> photos) {
  final sorted = List<PhotoLocation>.of(photos);
  sorted.sort((a, b) {
    final aTime = a.takenAt;
    final bTime = b.takenAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return aTime.compareTo(bTime);
  });
  return sorted;
}

double haversineKm(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const earthRadiusKm = 6371.0;
  final lat1 = _toRadians(latitude1);
  final lat2 = _toRadians(latitude2);
  final dLat = _toRadians(latitude2 - latitude1);
  final dLon = _toRadians(longitude2 - longitude1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double totalDistanceKm(List<PhotoLocation> photos) {
  var distance = 0.0;
  for (var i = 1; i < photos.length; i++) {
    final previous = photos[i - 1];
    final current = photos[i];
    distance += haversineKm(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
  }
  return distance;
}

void printTotalDistance(List<PhotoLocation> photos) {
  debugPrint('총 이동거리: ${totalDistanceKm(photos).toStringAsFixed(2)} km');
}

String formatTakenAt(DateTime? takenAt) {
  if (takenAt == null) return '촬영일 없음';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${takenAt.year}.${two(takenAt.month)}.${two(takenAt.day)} '
      '${two(takenAt.hour)}:${two(takenAt.minute)}';
}

double _toRadians(double degrees) => degrees * math.pi / 180;
