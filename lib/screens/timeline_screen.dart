import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:photo_manager/photo_manager.dart';

import '../photo_location.dart';

const double samePlaceMeters = 50;

/// 사진 위치를 날짜별 장소 카드로 보여 준다.
///
/// 장소를 누르면 그 장소의 대표 [PhotoLocation]을 반환하고 화면을 닫는다.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({required this.photos, super.key});

  final List<PhotoLocation> photos;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late final List<TimelineDay> _days = buildTimelineDays(widget.photos);
  late final TimelineStats _stats = summarizeTimeline(widget.photos);
  final Map<String, String> _addresses = {};

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final Geocoding geocoding;
    try {
      geocoding = Geocoding();
    } catch (_) {
      return;
    }

    final pending = <TimelinePlace>[
      for (final day in _days) ...day.places,
    ];
    final seen = <String>{};
    for (final place in pending) {
      final key = _coordinateKey(place.latitude, place.longitude);
      if (!seen.add(key)) continue;
      final address = await _lookupAddress(geocoding, place);
      if (!mounted) return;
      setState(() => _addresses[key] = address);
    }
  }

  Future<String> _lookupAddress(Geocoding geocoding, TimelinePlace place) async {
    try {
      final marks = await geocoding.placemarkFromCoordinates(
        place.latitude,
        place.longitude,
        locale: const Locale('ko', 'KR'),
      );
      if (marks.isEmpty) return formatCoordinates(place.latitude, place.longitude);
      final formatted = formatPlacemark(marks.first);
      if (formatted.isEmpty) {
        return formatCoordinates(place.latitude, place.longitude);
      }
      return formatted;
    } catch (_) {
      return formatCoordinates(place.latitude, place.longitude);
    }
  }

  void _selectPlace(TimelinePlace place) {
    Navigator.of(context).pop<PhotoLocation>(place.selection);
  }

  Future<void> _enlarge(TimelinePlace place) async {
    final ids = place.assetIds;
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('미리볼 사진이 없습니다.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _PhotoViewer(assetIds: ids),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('여행 타임라인')),
      body: _days.isEmpty
          ? const _EmptyTimeline()
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [
                for (final day in _days) ...[
                  _DateHeader(label: formatTimelineDate(day.date)),
                  for (final place in day.places)
                    _PlaceCard(
                      place: place,
                      address:
                          _addresses[_coordinateKey(
                            place.latitude,
                            place.longitude,
                          )] ??
                          '주소 확인 중',
                      onSelect: () => _selectPlace(place),
                      onEnlarge: () => _enlarge(place),
                    ),
                ],
              ],
            ),
      bottomNavigationBar: _StatsBar(stats: _stats),
    );
  }
}

class TimelineDay {
  const TimelineDay({required this.date, required this.places});

  final DateTime? date;
  final List<TimelinePlace> places;
}

class TimelinePlace {
  const TimelinePlace({required this.photos});

  final List<PhotoLocation> photos;

  double get latitude {
    var sum = 0.0;
    for (final photo in photos) {
      sum += photo.latitude;
    }
    return sum / photos.length;
  }

  double get longitude {
    var sum = 0.0;
    for (final photo in photos) {
      sum += photo.longitude;
    }
    return sum / photos.length;
  }

  DateTime? get startedAt {
    for (final photo in photos) {
      final takenAt = photo.takenAt;
      if (takenAt != null) return takenAt;
    }
    return null;
  }

  DateTime? get endedAt {
    for (final photo in photos.reversed) {
      final takenAt = photo.takenAt;
      if (takenAt != null) return takenAt;
    }
    return null;
  }

  Duration? get dwell {
    final start = startedAt;
    final end = endedAt;
    if (start == null || end == null) return null;
    return end.difference(start);
  }

  String? get coverAssetId {
    for (final photo in photos) {
      final assetId = photo.assetId;
      if (assetId != null && assetId.isNotEmpty) return assetId;
    }
    return null;
  }

  List<String> get assetIds => [
    for (final photo in photos)
      if (photo.assetId != null && photo.assetId!.isNotEmpty) photo.assetId!,
  ];

  PhotoLocation get selection => PhotoLocation(
    latitude: latitude,
    longitude: longitude,
    takenAt: startedAt,
    assetId: coverAssetId,
  );
}

class TimelineStats {
  const TimelineStats({
    required this.distanceKm,
    required this.placeCount,
    required this.photoCount,
  });

  final double distanceKm;
  final int placeCount;
  final int photoCount;
}

List<TimelineDay> buildTimelineDays(List<PhotoLocation> photos) {
  final sorted = sortPhotoLocationsByDate(photos);
  final grouped = <DateTime?, List<PhotoLocation>>{};
  final keys = <DateTime?>[];
  for (final photo in sorted) {
    final takenAt = photo.takenAt;
    final key = takenAt == null
        ? null
        : DateTime(takenAt.year, takenAt.month, takenAt.day);
    grouped.putIfAbsent(key, () {
      keys.add(key);
      return <PhotoLocation>[];
    }).add(photo);
  }
  return [
    for (final key in keys)
      TimelineDay(date: key, places: clusterPlaces(grouped[key]!)),
  ];
}

List<TimelinePlace> clusterPlaces(List<PhotoLocation> photos) {
  final clusters = <List<PhotoLocation>>[];
  for (final photo in photos) {
    var joined = false;
    for (final cluster in clusters) {
      final center = _centroid(cluster);
      final meters =
          haversineKm(
            center.$1,
            center.$2,
            photo.latitude,
            photo.longitude,
          ) *
          1000;
      if (meters <= samePlaceMeters) {
        cluster.add(photo);
        joined = true;
        break;
      }
    }
    if (!joined) clusters.add([photo]);
  }
  return [
    for (final cluster in clusters)
      TimelinePlace(photos: List<PhotoLocation>.unmodifiable(cluster)),
  ];
}

TimelineStats summarizeTimeline(List<PhotoLocation> photos) {
  final days = buildTimelineDays(photos);
  var placeCount = 0;
  for (final day in days) {
    placeCount += day.places.length;
  }
  return TimelineStats(
    distanceKm: totalDistanceKm(sortPhotoLocationsByDate(photos)),
    placeCount: placeCount,
    photoCount: photos.length,
  );
}

String formatTimelineDate(DateTime? date) {
  if (date == null) return '날짜 없음';
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${date.year}년 ${date.month}월 ${date.day}일 '
      '${weekdays[date.weekday - 1]}요일';
}

String formatPlaceTime(TimelinePlace place) {
  final start = place.startedAt;
  if (start == null) return '시간 없음';
  final end = place.endedAt;
  final startLabel = _clock(start);
  if (end == null || _clock(start) == _clock(end)) return startLabel;
  return '$startLabel – ${_clock(end)}';
}

String formatDwell(TimelinePlace place) {
  final dwell = place.dwell;
  if (dwell == null) return '머문 시간 없음';
  if (dwell.inMinutes < 1) return '잠시';
  final hours = dwell.inHours;
  final minutes = dwell.inMinutes.remainder(60);
  if (hours == 0) return '$minutes분';
  if (minutes == 0) return '$hours시간';
  return '$hours시간 $minutes분';
}

String formatTimelineDistance(double kilometers) {
  if (kilometers < 1) return '${(kilometers * 1000).round()}m';
  final text = kilometers.toStringAsFixed(1);
  if (text.endsWith('.0')) return '${text.substring(0, text.length - 2)}km';
  return '${text}km';
}

String formatPlacemark(Placemark place) {
  final parts = <String>[];
  void add(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return;
    if (parts.any((part) => part == text || part.contains(text))) return;
    parts.add(text);
  }

  add(place.administrativeArea);
  add(place.subAdministrativeArea);
  add(place.locality);
  add(place.subLocality);
  add(place.thoroughfare);
  add(place.subThoroughfare);
  if (parts.isEmpty) add(place.street);
  if (parts.isEmpty) add(place.name);
  return parts.join(' ');
}

String formatCoordinates(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

(double, double) _centroid(List<PhotoLocation> photos) {
  var latitude = 0.0;
  var longitude = 0.0;
  for (final photo in photos) {
    latitude += photo.latitude;
    longitude += photo.longitude;
  }
  return (latitude / photos.length, longitude / photos.length);
}

String _coordinateKey(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
}

String _clock(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}';
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined, size: 48, color: color),
          const SizedBox(height: 12),
          Text('표시할 사진이 없습니다.', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.address,
    required this.onSelect,
    required this.onEnlarge,
  });

  final TimelinePlace place;
  final String address;
  final VoidCallback onSelect;
  final VoidCallback onEnlarge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlaceThumbnail(
              assetId: place.coverAssetId,
              photoCount: place.photos.length,
              onTap: onEnlarge,
            ),
            Expanded(
              child: InkWell(
                onTap: onSelect,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatPlaceTime(place),
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  formatDwell(place),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceThumbnail extends StatefulWidget {
  const _PlaceThumbnail({
    required this.assetId,
    required this.photoCount,
    required this.onTap,
  });

  final String? assetId;
  final int photoCount;
  final VoidCallback onTap;

  @override
  State<_PlaceThumbnail> createState() => _PlaceThumbnailState();
}

class _PlaceThumbnailState extends State<_PlaceThumbnail> {
  late final Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() async {
    final assetId = widget.assetId;
    if (assetId == null) return null;
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return null;
      return asset.thumbnailDataWithSize(const ThumbnailSize.square(240));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: widget.onTap,
      child: SizedBox(
        width: 104,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: FutureBuilder<Uint8List?>(
                future: _bytes,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data == null) {
                    return Icon(
                      Icons.image_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    );
                  }
                  return Image.memory(
                    data,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  );
                },
              ),
            ),
            if (widget.photoCount > 1)
              Positioned(
                right: 6,
                bottom: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      '${widget.photoCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});

  final TimelineStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 3,
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.route,
                  value: formatTimelineDistance(stats.distanceKm),
                  label: '거리',
                ),
              ),
              Expanded(
                child: _StatTile(
                  icon: Icons.place_outlined,
                  value: '${stats.placeCount}',
                  label: '장소',
                ),
              ),
              Expanded(
                child: _StatTile(
                  icon: Icons.photo_outlined,
                  value: '${stats.photoCount}',
                  label: '사진',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.assetIds});

  final List<String> assetIds;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.assetIds.length;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_index + 1} / $count'),
        ),
        body: PageView.builder(
          controller: _controller,
          itemCount: count,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (context, index) {
            return _EnlargedPhoto(assetId: widget.assetIds[index]);
          },
        ),
      ),
    );
  }
}

class _EnlargedPhoto extends StatefulWidget {
  const _EnlargedPhoto({required this.assetId});

  final String assetId;

  @override
  State<_EnlargedPhoto> createState() => _EnlargedPhotoState();
}

class _EnlargedPhotoState extends State<_EnlargedPhoto> {
  late final Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() async {
    try {
      final asset = await AssetEntity.fromId(widget.assetId);
      if (asset == null) return null;
      return asset.thumbnailDataWithSize(const ThumbnailSize.square(1200));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          return const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white70),
          );
        }
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(child: Image.memory(data, fit: BoxFit.contain)),
        );
      },
    );
  }
}
