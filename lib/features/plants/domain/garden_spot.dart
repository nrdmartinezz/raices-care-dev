import 'plant.dart';

/// Where in the home a plant lives, as the gardener thinks of it.
///
/// Stored on the plant as `gardenId`. The Firestore rules only accept
/// `indoor`, `outdoor`, `greenhouse` or `other` for `locationType`, so the
/// front yard, the back yard and the balcony all record as outdoor and keep
/// the finer answer here.
enum GardenSpot {
  indoor('indoor', LocationType.indoor, GrowingMethod.container),
  backyard('back_yard', LocationType.outdoor, GrowingMethod.inGround),
  frontyard('front_yard', LocationType.outdoor, GrowingMethod.inGround),
  balcony('balcony', LocationType.outdoor, GrowingMethod.container);

  const GardenSpot(this.wire, this.locationType, this.growingMethod);

  final String wire;

  /// The coarse indoor-or-outdoor value the rules validate.
  final LocationType locationType;

  /// Assumed from the spot, since the flow does not ask: a balcony or a room
  /// means pots, a yard means the ground. Editable later on the plant.
  final GrowingMethod growingMethod;

  static GardenSpot? fromWire(Object? raw) {
    for (final spot in values) {
      if (spot.wire == raw) {
        return spot;
      }
    }
    return null;
  }
}
