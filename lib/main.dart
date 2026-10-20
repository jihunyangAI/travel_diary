import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:photo_manager/photo_manager.dart' hide LatLng;

import 'gallery_picker_page.dart';
import 'photo_import.dart';
import 'photo_location.dart';
import 'photo_map.dart';
import 'screens/timeline_screen.dart';

void main() {
  runApp(const TravelDiaryApp());
}

class TravelDiaryApp extends StatelessWidget {
  const TravelDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '여행기록',
      locale: const Locale('ko'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ko'), Locale('en')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const CameraPosition _korea = CameraPosition(
    target: LatLng(36.34, 127.77),
    zoom: 6.8,
  );

  GoogleMapController? _mapController;
  List<PhotoLocation> _photos = const [];
  Set<Marker> _markers = const {};
  Set<Polyline> _polylines = const {};

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _korea,
            onMapCreated: _onMapCreated,
            markers: _markers,
            polylines: _polylines,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            padding: EdgeInsets.only(bottom: bottomInset + 120),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MapActionButton(
                      key: const Key('load_photos_button'),
                      backgroundColor: Colors.orange,
                      tooltip: '사진 불러오기',
                      onPressed: _loadPhotoData,
                      child: const Icon(Icons.add, size: 36),
                    ),
                    _MapActionButton(
                      key: const Key('animation_button'),
                      backgroundColor: Colors.orange,
                      tooltip: '타임라인',
                      onPressed: _openTimeline,
                      child: const Text(
                        '>',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_photos.isNotEmpty) {
      focusPhotoCamera(controller, _photos);
    }
  }

  Future<void> _loadPhotoData() async {
    final granted = await ensureGalleryPermission();
    if (!mounted) return;
    if (!granted) {
      _showMessage(
        '갤러리 접근 권한이 필요합니다. 설정 > 앱 > 여행기록 > 권한에서 사진과 위치 정보를 허용해 주세요.',
      );
      return;
    }

    final range = await selectDateRange(context);
    if (!mounted || range == null) return;

    final assets = await pickGalleryPhotos(context, range);
    if (!mounted || assets.isEmpty) return;

    final PhotoImportResult result;
    try {
      result = await readSelectedPhotoLocations(context, assets, range);
    } catch (_) {
      if (!mounted) return;
      _showMessage('사진 정보를 읽지 못했습니다.');
      return;
    }
    if (!mounted) return;

    await _showPhotosOnMap(result.photos);
    if (!mounted) return;
    _showMessage(_importMessage(result));
  }

  Future<void> _showPhotosOnMap(List<PhotoLocation> photos) async {
    setState(() {
      _photos = photos;
      _markers = buildPhotoMarkers(photos);
      _polylines = buildRoutePolylines(photos);
    });
    final controller = _mapController;
    if (controller != null && photos.isNotEmpty) {
      await focusPhotoCamera(controller, photos);
    }
    printTotalDistance(photos);
  }

  Future<void> _openTimeline() async {
    final selected = await Navigator.of(context).push<PhotoLocation>(
      PageRouteBuilder<PhotoLocation>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return TimelineScreen(photos: _photos);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slide =
              Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return SlideTransition(position: slide, child: child);
        },
      ),
    );
    if (!mounted || selected == null) return;
    final controller = _mapController;
    if (controller == null) return;
    await focusPhotoLocation(controller, selected);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<PhotoImportResult> readSelectedPhotoLocations(
  BuildContext context,
  List<AssetEntity> assets,
  DateTimeRange range,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      );
    },
  );
  try {
    return await importPhotoLocations(assets, range);
  } finally {
    navigator.pop();
  }
}

String _importMessage(PhotoImportResult result) {
  if (result.photos.isEmpty && result.skippedOutsideRange == 0) {
    return 'GPS 위치 정보가 있는 사진이 없습니다.';
  }
  if (result.photos.isEmpty) {
    return '선택한 기간 안에 위치 정보가 있는 사진이 없습니다.';
  }
  final excluded = result.skippedWithoutGps + result.skippedOutsideRange;
  if (excluded == 0) {
    return '사진 ${result.photos.length}장의 위치를 지도에 표시했습니다.';
  }
  return '사진 ${result.photos.length}장을 표시했습니다. '
      'GPS가 없거나 기간 밖인 $excluded장은 제외했습니다.';
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    super.key,
    required this.backgroundColor,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final Color backgroundColor;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Tooltip(
        message: tooltip,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          child: child,
        ),
      ),
    );
  }
}
