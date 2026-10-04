/// A 2023 USDA hardiness zone from the PRISM ZIP listing.
///
/// This is the ZIP file at phzmapi.org, not a reading from the official
/// interactive USDA map, and not a zone derived from latitude.
class HardinessZone {
  const HardinessZone({
    required this.postalCode,
    required this.zone,
    required this.temperatureRange,
  });

  final String postalCode;

  /// Half-zone, such as `8a`.
  final String zone;

  /// Average annual extreme minimum, as published, such as `10 to 15`.
  /// Empty when the zone was restored from the profile rather than a lookup.
  final String temperatureRange;

  String? get temperatureLabel =>
      temperatureRange.isEmpty ? null : '$temperatureRange°F';
}
