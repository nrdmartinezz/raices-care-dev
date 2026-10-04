/// Copy that has no data source behind it yet.
///
/// The greeting, ritual list, plant cards and weather strip now read from
/// live data. What is left here is the tradition card, which needs the
/// wisdom collection.
abstract final class HomeTemplateContent {
  // Tradition — awaiting the wisdom collection.
  static const traditionNumber = 'Tradition #14';
  static const wisdomQuote =
      '“Touch the soil with your knuckles before watering. '
      'If fresh dust clings, let the roots breathe until dusk.”';
  static const wisdomAuthor = 'Don Aurelio • Mindful Care';
}
