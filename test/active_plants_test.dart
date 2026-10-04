import 'package:flutter_test/flutter_test.dart';
import 'package:raices/features/plants/data/plant_repository.dart';
import 'package:raices/features/plants/domain/plant.dart';

Plant _plant(String name, {bool archived = false, String? gardenId}) => Plant(
  id: name,
  speciesId: 'sp',
  displayName: name,
  gardenId: gardenId,
  status: PlantStatus(isArchived: archived),
);

void main() {
  test('active plants drop archived rows and sort by display name', () {
    final plants = activePlantsIn([
      _plant('Zucchini'),
      _plant('Old basil', archived: true),
      _plant('Basil'),
    ]);

    expect(plants.map((plant) => plant.displayName), ['Basil', 'Zucchini']);
  });
}
