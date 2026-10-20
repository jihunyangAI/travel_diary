import 'package:flutter/material.dart';
import 'package:native_exif/native_exif.dart';
import 'package:photo_manager/photo_manager.dart';

import 'photo_location.dart';

const PermissionRequestOption galleryPermission = PermissionRequestOption(
  androidPermission: AndroidPermission(
    type: RequestType.image,
    mediaLocation: true,
  ),
);

Future<bool> ensureGalleryPermission() async {
  final current = await PhotoManager.getPermissionState(
    requestOption: galleryPermission,
  );
  if (current.hasAccess) return true;
  final requested = await PhotoManager.requestPermissionExtend(
    requestOption: galleryPermission,
  );
  return requested.hasAccess;
}

Future<DateTimeRange?> selectDateRange(BuildContext context) {
  final today = DateUtils.dateOnly(DateTime.now());
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(2000),
    lastDate: today,
    initialDateRange: DateTimeRange(
      start: startOfRecentMonth(today),
      end: today,
    ),
    helpText: '사진 날짜 범위',
    saveText: '선택',
    locale: const Locale('ko'),
  );
}

Future<List<AssetEntity>> loadImagesInRange(DateTimeRange range) async {
  final filter = FilterOptionGroup(
    createTimeCond: DateTimeCond(
      min: DateTime(range.start.year, range.start.month, range.start.day),
      max: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
    ),
  );
  final albums = await PhotoManager.getAssetPathList(
    type: RequestType.image,
    onlyAll: true,
    filterOption: filter,
  );
  if (albums.isEmpty) return const [];

  final album = albums.first;
  final count = await album.assetCountAsync;
  const pageSize = 80;
  final assets = <AssetEntity>[];
  for (var page = 0; page * pageSize < count; page++) {
    assets.addAll(await album.getAssetListPaged(page: page, size: pageSize));
  }
  return assets;
}

Future<PhotoLocation?> extractPhotoLocation(AssetEntity asset) async {
  final file = await asset.originFile;
  if (file == null) return null;

  Exif? exif;
  try {
    exif = await Exif.fromPath(file.path);
    final gps = await exif.getLatLong();
    final takenAt = await exif.getOriginalDate();
    final location = photoLocationFromExif(
      latitude: gps?.latitude,
      longitude: gps?.longitude,
      takenAt: takenAt,
    );
    if (location == null) return null;
    return PhotoLocation(
      latitude: location.latitude,
      longitude: location.longitude,
      takenAt: location.takenAt,
      assetId: asset.id,
    );
  } catch (_) {
    return null;
  } finally {
    await exif?.close();
  }
}

Future<PhotoImportResult> importPhotoLocations(
  List<AssetEntity> assets,
  DateTimeRange range,
) async {
  final photos = <PhotoLocation>[];
  var skippedWithoutGps = 0;
  var skippedOutsideRange = 0;
  for (final asset in assets) {
    final location = await extractPhotoLocation(asset);
    if (location == null) {
      skippedWithoutGps++;
      continue;
    }
    if (!isWithinDateRange(
      photo: location,
      start: range.start,
      end: range.end,
    )) {
      skippedOutsideRange++;
      continue;
    }
    photos.add(location);
  }
  return PhotoImportResult(
    photos: sortPhotoLocationsByDate(photos),
    skippedWithoutGps: skippedWithoutGps,
    skippedOutsideRange: skippedOutsideRange,
  );
}
