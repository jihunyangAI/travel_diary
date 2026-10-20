import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'package:travel_diary/main.dart';

void main() {
  setUp(() {
    GoogleMapsFlutterPlatform.instance = _FakeMapPlatform();
  });

  testWidgets('지도와 하단 버튼 두 개가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const TravelDiaryApp());
    await tester.pump();

    expect(find.byType(GoogleMap), findsOneWidget);

    final Finder photoButton = find.byKey(const Key('load_photos_button'));
    final Finder animationButton = find.byKey(const Key('animation_button'));
    expect(photoButton, findsOneWidget);
    expect(animationButton, findsOneWidget);
    expect(
      find.descendant(of: photoButton, matching: find.byIcon(Icons.add)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: animationButton, matching: find.text('>')),
      findsOneWidget,
    );

    expect(_backgroundOf(tester, photoButton), Colors.orange);
    expect(_backgroundOf(tester, animationButton), Colors.orange);
  });
}

Color? _backgroundOf(WidgetTester tester, Finder button) {
  final FilledButton widget = tester.widget<FilledButton>(
    find.descendant(of: button, matching: find.byType(FilledButton)),
  );
  return widget.style?.backgroundColor?.resolve(<WidgetState>{});
}

class _FakeMapPlatform extends GoogleMapsFlutterPlatform {
  @override
  Future<void> init(int mapId) async {}

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapObjects mapObjects = const MapObjects(),
    MapConfiguration mapConfiguration = const MapConfiguration(),
  }) {
    onPlatformViewCreated(creationId);
    return const SizedBox.expand();
  }

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {}

  @override
  void dispose({required int mapId}) {}

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MapTapEvent> onTap({required int mapId}) => const Stream.empty();

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) =>
      const Stream.empty();
}
