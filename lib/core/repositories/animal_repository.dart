import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../location/location_service.dart';
import '../models/encounter.dart';
import '../models/species.dart';
import '../models/zoo.dart';

class AnimalRepository {
  const AnimalRepository();

  Future<List<Zoo>> getAllZoos() => DatabaseHelper.getAllZoos();

  Future<List<Zoo>> getNearbyZoos({double radiusKm = 10.0}) async {
    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      return getAllZoos();
    }
    final nearby = await DatabaseHelper.getZoosNear(
      position.latitude,
      position.longitude,
      radiusKm: radiusKm,
    );
    if (nearby.isEmpty) {
      return await getAllZoos();
    }
    return nearby;
  }

  Future<List<Species>> getAllSpecies() => DatabaseHelper.getAllSpecies();

  Future<List<Species>> searchSpecies(String query) =>
      DatabaseHelper.searchSpecies(query);

  Future<Set<String>> getMetSpeciesIds() async {
    final summary = await DatabaseHelper.getEncounterSummary();
    return summary.map((row) => row['species_id'] as String).toSet();
  }

  Future<void> insertEncounter(Encounter encounter) =>
      DatabaseHelper.insertEncounter(encounter);
}

final animalRepositoryProvider = Provider<AnimalRepository>((ref) {
  return const AnimalRepository();
});
