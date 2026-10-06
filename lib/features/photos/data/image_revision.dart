import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Versions of object keys replaced during this session.
///
/// The custom domain caches `avatar.jpg` for a few minutes. A new version
/// changes the URL the widgets request, so the circle and the card refresh
/// without waiting that out.
class ImageRevision extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  void bump(String storagePath) {
    state = {...state, storagePath: DateTime.now().millisecondsSinceEpoch};
  }
}

final imageRevisionProvider = NotifierProvider<ImageRevision, Map<String, int>>(
  ImageRevision.new,
);
