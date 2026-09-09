/// Mirrors the `scouts` table in Supabase. Like Player, never instantiated
/// with hardcoded sample data — only from real rows.
class Scout {
  final String id;
  final String? userId;
  final String name;
  final String? organization;
  final String badgeType; // CAF | FIFA | EU | PRO
  final bool verified;
  final String? contactEmail;
  final String? contactPhone;

  // Discovery-engine preferences (015_discovery_engine.sql). Null/empty =
  // no stated preference — discoveryEngine.js treats that as neutral, never
  // as a filter, so an unconfigured scout still gets a sane feed.
  final List<String> preferredPositions;
  final List<String> preferredCountries;
  final int? ageMin;
  final int? ageMax;
  final String? preferredFoot; // left | right | both
  final int? preferredHeightMin;

  Scout({
    required this.id,
    this.userId,
    required this.name,
    this.organization,
    this.badgeType = 'PRO',
    this.verified = false,
    this.contactEmail,
    this.contactPhone,
    this.preferredPositions = const [],
    this.preferredCountries = const [],
    this.ageMin,
    this.ageMax,
    this.preferredFoot,
    this.preferredHeightMin,
  });

  factory Scout.fromJson(Map<String, dynamic> json) {
    return Scout(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      organization: json['organization'] as String?,
      badgeType: json['badge_type'] as String? ?? 'PRO',
      verified: json['verified'] as bool? ?? false,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      preferredPositions:
          (json['preferred_positions'] as List?)?.map((e) => e as String).toList() ?? const [],
      preferredCountries:
          (json['preferred_countries'] as List?)?.map((e) => e as String).toList() ?? const [],
      ageMin: json['age_min'] as int?,
      ageMax: json['age_max'] as int?,
      preferredFoot: json['preferred_foot'] as String?,
      preferredHeightMin: json['preferred_height_min'] as int?,
    );
  }

  bool get hasContactInfo => (contactEmail?.isNotEmpty ?? false) || (contactPhone?.isNotEmpty ?? false);

  String get initials =>
      name.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
}
