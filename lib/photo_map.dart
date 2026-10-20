import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'photo_location.dart';

const String photoRouteId = 'photo_route';

Set<Marker> buildPhotoMarkers(List<PhotoLocation> photos) {
  return {
    for (var i = 0; i < photos.length; i++)
      Marker(
        markerId: MarkerId('photo_$i'),
        position: LatLng(photos[i].latitude, photos[i].longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: formatTakenAt(photos[i].takenAt)),
      ),
  };
}

Set<Polyline> buildRoutePolylines(List<PhotoLocation> photos) {
  if (photos.length < 2) return {};
  return {
    Polyline(
      polylineId: const PolylineId(photoRouteId),
      color: Colors.blue,
      width: 5,
      points: [
        for (final photo in photos) LatLng(photo.latitude, photo.longitude),
      ],
    ),
  };
}

CameraUpdate cameraUpdateForPhotos(List<PhotoLocation> photos) {
  final first = photos.first;
  final firstTarget = LatLng(first.latitude, first.longitude);
  if (photos.length == 1 || _spanIsTiny(photos)) {
    return CameraUpdate.newLatLngZoom(firstTarget, 14);
  }

  var minLat = first.latitude;
  var maxLat = first.latitude;
  var minLng = first.longitude;
  var maxLng = first.longitude;
  for (final photo in photos.skip(1)) {
    minLat = math.min(minLat, photo.latitude);
    maxLat = math.max(maxLat, photo.latitude);
    minLng = math.min(minLng, photo.longitude);
    maxLng = math.max(maxLng, photo.longitude);
  }

  return CameraUpdate.newLatLngBounds(
    LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    ),
    72,
  );
}

Future<void> focusPhotoLocation(
  GoogleMapController controller,
  PhotoLocation photo,
) {
  return controller.animateCamera(
    CameraUpdate.newLatLngZoom(LatLng(photo.latitude, photo.longitude), 16),
  );
}

Future<void> focusPhotoCamera(
  GoogleMapController controller,
  List<PhotoLocation> photos,
) async {
  if (photos.isEmpty) return;
  final first = photos.first;
  await controller.animateCamera(
    CameraUpdate.newLatLng(LatLng(first.latitude, first.longitude)),
  );
  await controller.animateCamera(cameraUpdateForPhotos(photos));
}

bool _spanIsTiny(List<PhotoLocation> photos) {
  final first = photos.first;
  for (final photo in photos.skip(1)) {
    if ((photo.latitude - first.latitude).abs() > 0.0001) return false;
    if ((photo.longitude - first.longitude).abs() > 0.0001) return false;
  }
  return true;
}
