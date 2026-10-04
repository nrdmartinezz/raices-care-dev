import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/garden_weather.dart';

/// This phone's position, at low accuracy.
///
/// The forecast grid is about 2.5 km, so a coarse fix is enough and it works
/// with the coarse-location permission alone.
class DeviceLocation {
  const DeviceLocation();

  static const _unavailable = WeatherLookupException(
    'Location is off',
    'Turn on location to see the weather here.',
  );

  Future<({double latitude, double longitude})> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw _unavailable;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw _unavailable;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } on WeatherLookupException {
      rethrow;
    } on TimeoutException {
      throw _unavailable;
    } on LocationServiceDisabledException {
      throw _unavailable;
    } on PermissionDeniedException {
      throw _unavailable;
    }
  }
}
