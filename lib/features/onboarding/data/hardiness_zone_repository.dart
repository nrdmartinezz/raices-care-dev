import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';
import '../domain/hardiness_zone.dart';

/// Looks up a US ZIP in the 2023 PRISM hardiness listing.
///
/// Responses are cached for the life of this repository. A miss or a network
/// failure is not cached, so a retry can succeed. Coordinates in the file are
/// ignored: a zone is never invented from latitude.
class HardinessZoneRepository {
  HardinessZoneRepository({required this._client});

  final http.Client _client;
  final Map<String, HardinessZone> _cache = {};

  static const _userAgent = 'Raices (care.raices.app)';
  static final _zip = RegExp(r'^\d{5}$');
  static final _zone = RegExp(r'^[1-9][0-9]?[ab]$');

  static const _missing = ZoneLookupException(
    "That ZIP isn't in the 2023 zone listing.",
  );
  static const _unavailable = ZoneLookupException(
    'The zone listing could not be loaded.',
  );

  Future<HardinessZone> lookup(String postalCode) async {
    final zip = postalCode.trim();
    if (!_zip.hasMatch(zip)) {
      throw const ZoneLookupException('Enter a 5-digit US ZIP.');
    }

    final cached = _cache[zip];
    if (cached != null) {
      return cached;
    }

    final uri = Uri.parse('https://phzmapi.org/$zip.json');
    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent': _userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on Object {
      throw _unavailable;
    }

    if (response.statusCode == 404) {
      throw _missing;
    }
    if (response.statusCode != 200) {
      throw _unavailable;
    }

    final zone = _parse(zip, response.body);
    _cache[zip] = zone;
    return zone;
  }

  HardinessZone _parse(String zip, String body) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw _unavailable;
    }
    if (decoded is! Map) {
      throw _unavailable;
    }

    final zone = decoded['zone'];
    final range = decoded['temperature_range'];
    if (zone is! String || !_zone.hasMatch(zone.toLowerCase())) {
      throw _unavailable;
    }
    if (range is! String || range.trim().isEmpty) {
      throw _unavailable;
    }

    return HardinessZone(
      postalCode: zip,
      zone: zone.toLowerCase(),
      temperatureRange: range.trim(),
    );
  }
}

final hardinessZoneRepositoryProvider = Provider<HardinessZoneRepository>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return HardinessZoneRepository(client: client);
});
