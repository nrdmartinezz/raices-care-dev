import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_values.dart';

/// Identifiers for the same species at each upstream provider.
///
/// Raíces mints its own document id from the scientific name, so the catalog
/// is not tied to any one provider's numbering.
class SpeciesExternalIds {
  const SpeciesExternalIds({
    this.trefle,
    this.trefleSlug,
    this.floraCodex,
    this.gbif,
  });

  final String? trefle;
  final String? trefleSlug;
  final String? floraCodex;
  final String? gbif;

  factory SpeciesExternalIds.fromMap(Map<String, dynamic> map) =>
      SpeciesExternalIds(
        trefle: FirestoreValue.text(map['trefle']),
        trefleSlug: FirestoreValue.text(map['trefleSlug']),
        floraCodex: FirestoreValue.text(map['floraCodex']),
        gbif: FirestoreValue.text(map['gbif']),
      );
}

/// Botanical tolerances from the catalog.
///
/// These are reference facts, not a care schedule. Coverage upstream is thin —
/// many records fill in well under half of this — so every field is nullable
/// and the UI must cope with "unknown".
class SpeciesGrowth {
  const SpeciesGrowth({
    this.light,
    this.atmosphericHumidity,
    this.soilMoisture,
    this.soilNutriments,
    this.soilTexture,
    this.phMinimum,
    this.phMaximum,
    this.minimumTemperatureC,
    this.maximumTemperatureC,
    this.minimumPrecipitationMm,
    this.maximumPrecipitationMm,
    this.daysToHarvest,
    this.growthMonths = const [],
    this.bloomMonths = const [],
    this.fruitMonths = const [],
    this.sowing,
    this.description,
  });

  /// 0–10, where 10 is full sun.
  final int? light;

  /// 0–10.
  final int? atmosphericHumidity;

  /// 0–10. The strongest single signal for a watering cadence.
  final int? soilMoisture;

  /// 0–10.
  final int? soilNutriments;
  final int? soilTexture;
  final double? phMinimum;
  final double? phMaximum;
  final double? minimumTemperatureC;
  final double? maximumTemperatureC;
  final double? minimumPrecipitationMm;
  final double? maximumPrecipitationMm;
  final int? daysToHarvest;
  final List<String> growthMonths;
  final List<String> bloomMonths;
  final List<String> fruitMonths;
  final String? sowing;
  final String? description;

  factory SpeciesGrowth.fromMap(Map<String, dynamic> map) => SpeciesGrowth(
    light: FirestoreValue.integer(map['light']),
    atmosphericHumidity: FirestoreValue.integer(map['atmosphericHumidity']),
    soilMoisture: FirestoreValue.integer(map['soilMoisture']),
    soilNutriments: FirestoreValue.integer(map['soilNutriments']),
    soilTexture: FirestoreValue.integer(map['soilTexture']),
    phMinimum: FirestoreValue.decimal(map['phMinimum']),
    phMaximum: FirestoreValue.decimal(map['phMaximum']),
    minimumTemperatureC: FirestoreValue.decimal(map['minimumTemperatureC']),
    maximumTemperatureC: FirestoreValue.decimal(map['maximumTemperatureC']),
    minimumPrecipitationMm: FirestoreValue.decimal(
      map['minimumPrecipitationMm'],
    ),
    maximumPrecipitationMm: FirestoreValue.decimal(
      map['maximumPrecipitationMm'],
    ),
    daysToHarvest: FirestoreValue.integer(map['daysToHarvest']),
    growthMonths: FirestoreValue.strings(map['growthMonths']),
    bloomMonths: FirestoreValue.strings(map['bloomMonths']),
    fruitMonths: FirestoreValue.strings(map['fruitMonths']),
    sowing: FirestoreValue.text(map['sowing']),
    description: FirestoreValue.text(map['description']),
  );
}

/// Licence text the app is obliged to display next to catalog data.
class SpeciesAttribution {
  const SpeciesAttribution({required this.text, this.license, this.url});

  final String text;
  final String? license;
  final String? url;

  factory SpeciesAttribution.fromMap(Map<String, dynamic> map) =>
      SpeciesAttribution(
        text: FirestoreValue.text(map['text']) ?? 'Catalog data',
        license: FirestoreValue.text(map['license']),
        url: FirestoreValue.text(map['url']),
      );
}

/// A shared catalog record at /species/{speciesId}.
///
/// Read-only from the client: the security rules deny every client write, and
/// records are cached by the `resolveSpecies` Cloud Function on demand.
class Species {
  const Species({
    required this.id,
    required this.scientificName,
    this.slug,
    this.commonName,
    this.commonNames = const [],
    this.synonyms = const [],
    this.family,
    this.familyCommonName,
    this.genus,
    this.rank,
    this.taxonomicStatus,
    this.author,
    this.year,
    this.plantGroups = const [],
    this.externalIds = const SpeciesExternalIds(),
    this.growth = const SpeciesGrowth(),
    this.imageUrl,
    this.imagePath,
    this.dataCompleteness,
    this.hasCompleteData = false,
    this.attribution,
    this.lastSyncedAt,
  });

  final String id;
  final String scientificName;
  final String? slug;
  final String? commonName;
  final List<String> commonNames;
  final List<String> synonyms;
  final String? family;
  final String? familyCommonName;
  final String? genus;
  final String? rank;
  final String? taxonomicStatus;
  final String? author;
  final int? year;
  final List<String> plantGroups;
  final SpeciesExternalIds externalIds;
  final SpeciesGrowth growth;

  /// Hosted upstream, with its own per-image attribution.
  final String? imageUrl;

  /// Set once the image has been mirrored into our Storage bucket.
  final String? imagePath;

  /// Upstream's own 0–100 estimate of how filled-in this record is.
  final int? dataCompleteness;
  final bool hasCompleteData;
  final SpeciesAttribution? attribution;
  final DateTime? lastSyncedAt;

  /// The best name to show a user.
  String get displayName => commonName ?? scientificName;

  factory Species.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return Species(
      id: snapshot.id,
      scientificName:
          FirestoreValue.text(data['scientificName']) ?? snapshot.id,
      slug: FirestoreValue.text(data['slug']),
      commonName: FirestoreValue.text(data['commonName']),
      commonNames: FirestoreValue.strings(data['commonNames']),
      synonyms: FirestoreValue.strings(data['synonyms']),
      family: FirestoreValue.text(data['family']),
      familyCommonName: FirestoreValue.text(data['familyCommonName']),
      genus: FirestoreValue.text(data['genus']),
      rank: FirestoreValue.text(data['rank']),
      taxonomicStatus: FirestoreValue.text(data['taxonomicStatus']),
      author: FirestoreValue.text(data['author']),
      year: FirestoreValue.integer(data['year']),
      plantGroups: FirestoreValue.strings(data['plantGroups']),
      externalIds: SpeciesExternalIds.fromMap(
        FirestoreValue.map(data['externalIds']),
      ),
      growth: SpeciesGrowth.fromMap(FirestoreValue.map(data['growth'])),
      imageUrl: FirestoreValue.text(data['imageUrl']),
      imagePath: FirestoreValue.text(data['imagePath']),
      dataCompleteness: FirestoreValue.integer(data['dataCompleteness']),
      hasCompleteData: FirestoreValue.boolean(data['hasCompleteData']),
      attribution: data['attribution'] == null
          ? null
          : SpeciesAttribution.fromMap(
              FirestoreValue.map(data['attribution']),
            ),
      lastSyncedAt: FirestoreValue.dateTime(data['lastSyncedAt']),
    );
  }
}

/// Provenance for one upstream provider, at
/// /species/{speciesId}/sources/{provider}.
///
/// Each upstream dataset keeps its own licence, so this is what makes correct
/// attribution possible per record rather than one blanket credit line.
class SpeciesSource {
  const SpeciesSource({
    required this.id,
    required this.provider,
    this.externalId,
    this.externalUrl,
    this.license,
    this.attributionText,
    this.bibliography,
    this.upstreamSources = const [],
    this.fetchedAt,
  });

  final String id;
  final String provider;
  final String? externalId;
  final String? externalUrl;
  final String? license;
  final String? attributionText;
  final String? bibliography;
  final List<UpstreamCitation> upstreamSources;
  final DateTime? fetchedAt;

  factory SpeciesSource.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final raw = data['upstreamSources'];
    return SpeciesSource(
      id: snapshot.id,
      provider: FirestoreValue.text(data['provider']) ?? snapshot.id,
      externalId: FirestoreValue.text(data['externalId']),
      externalUrl: FirestoreValue.text(data['externalUrl']),
      license: FirestoreValue.text(data['license']),
      attributionText: FirestoreValue.text(data['attributionText']),
      bibliography: FirestoreValue.text(data['bibliography']),
      upstreamSources: raw is Iterable
          ? raw
                .whereType<Map>()
                .map(
                  (entry) =>
                      UpstreamCitation.fromMap(entry.cast<String, dynamic>()),
                )
                .toList(growable: false)
          : const [],
      fetchedAt: FirestoreValue.dateTime(data['fetchedAt']),
    );
  }
}

/// One institutional dataset behind a catalog record.
class UpstreamCitation {
  const UpstreamCitation({this.name, this.url, this.citation, this.lastUpdate});

  final String? name;
  final String? url;
  final String? citation;
  final String? lastUpdate;

  factory UpstreamCitation.fromMap(Map<String, dynamic> map) =>
      UpstreamCitation(
        name: FirestoreValue.text(map['name']),
        url: FirestoreValue.text(map['url']),
        citation: FirestoreValue.text(map['citation']),
        lastUpdate: FirestoreValue.text(map['lastUpdate']),
      );
}
