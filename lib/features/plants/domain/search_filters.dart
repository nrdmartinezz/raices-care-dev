/// Botanical rank values Trefle accepts on `filter[rank]`.
enum SearchRank {
  species('Species', 'species'),
  subspecies('Subspecies', 'subspecies'),
  variety('Variety', 'variety'),
  form('Form', 'form'),
  hybrid('Hybrid', 'hybrid'),
  subvariety('Subvariety', 'subvariety');

  const SearchRank(this.label, this.wire);

  final String label;
  final String wire;
}

/// Choices that narrow a catalog search.
///
/// Within Rank and within Family, selections are alternatives. Edible and
/// Vegetable, when on, both have to match.
class SearchFilters {
  const SearchFilters({
    this.ranks = const {},
    this.families = const {},
    this.edible = false,
    this.vegetable = false,
  });

  static const familyChoices = [
    'Asteraceae',
    'Orchidaceae',
    'Fabaceae',
    'Rubiaceae',
    'Poaceae',
    'Lamiaceae',
    'Apocynaceae',
  ];

  final Set<SearchRank> ranks;
  final Set<String> families;
  final bool edible;
  final bool vegetable;

  int get count =>
      ranks.length + families.length + (edible ? 1 : 0) + (vegetable ? 1 : 0);

  bool get isEmpty => count == 0;

  SearchFilters toggleRank(SearchRank rank) {
    final next = Set<SearchRank>.of(ranks);
    if (!next.add(rank)) next.remove(rank);
    return _copy(ranks: next);
  }

  SearchFilters toggleFamily(String family) {
    final next = Set<String>.of(families);
    if (!next.add(family)) next.remove(family);
    return _copy(families: next);
  }

  SearchFilters toggleEdible() => _copy(edible: !edible);

  SearchFilters toggleVegetable() => _copy(vegetable: !vegetable);

  SearchFilters _copy({
    Set<SearchRank>? ranks,
    Set<String>? families,
    bool? edible,
    bool? vegetable,
  }) {
    return SearchFilters(
      ranks: ranks ?? this.ranks,
      families: families ?? this.families,
      edible: edible ?? this.edible,
      vegetable: vegetable ?? this.vegetable,
    );
  }
}
