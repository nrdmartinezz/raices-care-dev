import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/guide_catalog.dart';
import '../domain/learning_guide.dart';

/// Learner payload. The editorial markdown in assets/guides is not bundled.
const learningGuidesAsset = 'assets/learning/guides.json';

class GuideRepository {
  const GuideRepository({this._bundle});

  final AssetBundle? _bundle;

  Future<GuideCatalog> load() async {
    final raw = await (_bundle ?? rootBundle).loadString(learningGuidesAsset);
    return GuideCatalog(decodeGuides(raw));
  }
}

final guideCatalogProvider = FutureProvider<GuideCatalog>((ref) {
  return const GuideRepository().load();
});
