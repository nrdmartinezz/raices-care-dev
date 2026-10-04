import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/garden_weather.dart';

/// Current conditions from api.weather.gov for a garden point.
///
/// The point comes from the ZIP saved at onboarding. The service only covers
/// the United States. A point outside that area comes back as 404, which is
/// reported as [WeatherLookupException] rather than a crash. The UV index is
/// not part of an observation, so it is not read.
class WeatherRepository {
  WeatherRepository({required this._client});

  final http.Client _client;

  static const _userAgent = 'Raices (care.raices.app)';
  static const _host = 'api.weather.gov';

  static const _outsideCoverage = WeatherLookupException(
    'No forecast here',
    'Weather is available for gardens in the United States.',
  );

  static const _unavailable = WeatherLookupException(
    'Weather unavailable',
    'The forecast could not be loaded.',
  );

  Future<GardenWeather> current({
    required double latitude,
    required double longitude,
  }) async {
    final latitudeText = latitude.toStringAsFixed(4);
    final longitudeText = longitude.toStringAsFixed(4);

    final forecastPoint = await _get(
      Uri.parse('https://$_host/points/$latitudeText,$longitudeText'),
      missingMeansOutside: true,
    );
    final properties = _map(forecastPoint['properties']);
    final stationsUrl = properties?['observationStations'];
    if (stationsUrl is! String) {
      throw _unavailable;
    }

    final stations = await _get(Uri.parse(stationsUrl));
    final features = stations['features'];
    if (features is! List || features.isEmpty) {
      throw _unavailable;
    }

    // The nearest station sometimes has not reported. A couple of neighbours
    // usually have.
    for (final feature in features.take(3)) {
      if (feature is! Map) {
        continue;
      }
      final stationId = _stationId(feature);
      if (stationId == null) {
        continue;
      }
      final GardenWeather? reading;
      try {
        final observation = await _get(
          Uri.parse('https://$_host/stations/$stationId/observations/latest'),
        );
        reading = _reading(observation, _place(properties));
      } on WeatherLookupException {
        // A quiet station is not the same as a point outside the country.
        continue;
      }
      if (reading != null) {
        return reading;
      }
    }

    throw _unavailable;
  }

  GardenWeather? _reading(Map<String, dynamic> observation, String place) {
    final properties = _map(observation['properties']);
    if (properties == null) {
      return null;
    }
    final celsius = _celsius(properties['temperature']);
    if (celsius == null) {
      return null;
    }
    final sky = properties['textDescription'];
    return GardenWeather(
      temperatureCelsius: celsius,
      sky: sky is String ? sky : '',
      place: place,
      humidityPercent: _number(properties['relativeHumidity']),
    );
  }

  /// "Austin, TX" from the point's relative location. Empty when it is missing.
  String _place(Map<String, dynamic>? properties) {
    final relative = _map(properties?['relativeLocation']);
    final place = _map(relative?['properties']);
    final city = place?['city'];
    final state = place?['state'];
    if (city is String &&
        city.isNotEmpty &&
        state is String &&
        state.isNotEmpty) {
      return '$city, $state';
    }
    if (city is String) {
      return city;
    }
    return '';
  }

  String? _stationId(Map<dynamic, dynamic> feature) {
    final properties = _map(feature['properties']);
    final named = properties?['stationIdentifier'];
    final raw = named is String && named.isNotEmpty
        ? named
        : _idFromUrl(feature['id']);
    if (raw == null || !RegExp(r'^[A-Za-z0-9]+$').hasMatch(raw)) {
      return null;
    }
    return raw;
  }

  String? _idFromUrl(Object? value) {
    if (value is! String) {
      return null;
    }
    final marker = '/stations/';
    final index = value.indexOf(marker);
    if (index == -1) {
      return null;
    }
    return value.substring(index + marker.length).split('/').first;
  }

  double? _celsius(Object? node) {
    final reading = _map(node);
    final value = reading?['value'];
    if (value is! num) {
      return null;
    }
    if (reading?['unitCode'] == 'wmoUnit:degF') {
      return (value.toDouble() - 32) * 5 / 9;
    }
    return value.toDouble();
  }

  double? _number(Object? node) {
    final value = _map(node)?['value'];
    return value is num ? value.toDouble() : null;
  }

  Map<String, dynamic>? _map(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  Future<Map<String, dynamic>> _get(
    Uri uri, {
    bool missingMeansOutside = false,
  }) async {
    if (uri.host != _host || uri.scheme != 'https') {
      throw _unavailable;
    }

    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent': _userAgent,
              'Accept': 'application/geo+json',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on Object {
      throw _unavailable;
    }

    if (response.statusCode == 404) {
      throw missingMeansOutside ? _outsideCoverage : _unavailable;
    }
    if (response.statusCode != 200) {
      throw _unavailable;
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      throw _unavailable;
    }
    throw _unavailable;
  }
}
