/// Copy that has no data source behind it yet.
///
/// The greeting, ritual list and plant cards now read from Firestore. What is
/// left here is waiting on services the app does not have: the weather strip
/// needs a forecast provider, and the tradition card needs the wisdom
/// collection.
abstract final class HomeTemplateContent {
  // Weather — awaiting a forecast provider keyed on users/{uid}.homeLocation.
  static const temperature = '24°C';
  static const sky = 'Sunny';
  static const weatherNote = 'Ideal absorption conditions';
  static const humidity = '48%';
  static const uvIndex = 'UV 6';

  // Tradition — awaiting the wisdom collection.
  static const traditionNumber = 'Tradition #14';
  static const wisdomQuote =
      '“Touch the soil with your knuckles before watering. '
      'If fresh dust clings, let the roots breathe until dusk.”';
  static const wisdomAuthor = 'Don Aurelio • Mindful Care';
}
