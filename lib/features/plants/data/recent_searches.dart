import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The catalog searches made since the app opened, newest first.
///
/// Memory only: the app carries no local-storage package, so these are a
/// convenience within a session rather than a saved history.
class RecentSearches extends Notifier<List<String>> {
  static const _keep = 7;

  @override
  List<String> build() => const [];

  void remember(String term) {
    final entry = term.trim();
    if (entry.isEmpty) {
      return;
    }
    final lower = entry.toLowerCase();
    state = [
      entry,
      ...state.where((existing) => existing.toLowerCase() != lower),
    ].take(_keep).toList(growable: false);
  }

  void clear() => state = const [];
}

final recentSearchesProvider =
    NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);
