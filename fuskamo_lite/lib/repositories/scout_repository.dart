import '../models/scout_model.dart';
import '../services/scout_service.dart';

class ScoutRepository {
  final ScoutService _service = ScoutService();

  Future<List<Scout>> getVerifiedScouts() => _service.fetchVerifiedScouts();

  Future<List<Scout>> searchVerifiedScouts(String query) =>
      _service.searchVerifiedScouts(query);

  /// Submits a scout application as unverified (pending review) — see
  /// database/migrations/011_ownership_and_scout_applications.sql for the
  /// RLS policy that allows this specific insert shape from the anon key.
  Future<String?> applyAsScout({
    required String name,
    String? organization,
    String? contactEmail,
    String? contactPhone,
  }) => _service.applyAsScout(
        name: name,
        organization: organization,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
      );

  Future<Scout?> fetchMyScout() => _service.fetchMyScout();

  Future<bool> updateMyPreferences({
    required List<String> preferredPositions,
    required List<String> preferredCountries,
    int? ageMin,
    int? ageMax,
    String? preferredFoot,
    int? preferredHeightMin,
  }) =>
      _service.updateMyPreferences(
        preferredPositions: preferredPositions,
        preferredCountries: preferredCountries,
        ageMin: ageMin,
        ageMax: ageMax,
        preferredFoot: preferredFoot,
        preferredHeightMin: preferredHeightMin,
      );
}
