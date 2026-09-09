import '../constants/position_constants.dart';

/// Mirrors the `players` table in Supabase (see database/schema.sql).
/// No sample/demo instances of this model are constructed anywhere in the
/// app — every Player object comes from a real Supabase row at runtime.
class Player {
  final String id;
  final String? submittedBy;
  final String name;
  final PlayerPosition position;
  final int age;
  final String country;
  final String? club;
  final String? strengths;
  final String? videoUrl;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? jerseyNumber;
  final DateTime? createdAt;
  final DateTime? featuredUntil; // set by a completed M-Pesa boost payment
  final String? contactEmail;
  final String? contactPhone;
  final String? league;
  final int? height; // cm
  final String? foot; // 'left' | 'right' | 'both'

  // Discovery-engine inputs (015_discovery_engine.sql). Read-only from the
  // app's side — quality_score is set by admin review, fraud_score by the
  // nightly recompute job; profile_completeness is the one the app itself
  // computes and sends, in toInsertJson().
  final double profileCompleteness;
  final double qualityScore;
  final double fraudScore;

  Player({
    required this.id,
    this.submittedBy,
    required this.name,
    required this.position,
    required this.age,
    required this.country,
    this.club,
    this.strengths,
    this.videoUrl,
    this.status = 'pending',
    this.jerseyNumber,
    this.createdAt,
    this.featuredUntil,
    this.contactEmail,
    this.contactPhone,
    this.league,
    this.height,
    this.foot,
    this.profileCompleteness = 0,
    this.qualityScore = 0.5,
    this.fraudScore = 0,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      submittedBy: json['submitted_by'] as String?,
      name: json['name'] as String,
      position: PlayerPositionX.fromDbValue(json['position'] as String),
      age: json['age'] as int,
      country: json['country'] as String,
      club: json['club'] as String?,
      strengths: json['strengths'] as String?,
      videoUrl: json['video_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      jerseyNumber: json['jersey_number'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      featuredUntil: json['featured_until'] != null
          ? DateTime.tryParse(json['featured_until'] as String)
          : null,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      league: json['league'] as String?,
      height: json['height'] as int?,
      foot: json['foot'] as String?,
      profileCompleteness: (json['profile_completeness'] as num?)?.toDouble() ?? 0,
      qualityScore: (json['quality_score'] as num?)?.toDouble() ?? 0.5,
      fraudScore: (json['fraud_score'] as num?)?.toDouble() ?? 0,
    );
  }

  /// 0..1 — how many optional fields a submission filled in. Sent on
  /// insert as players.profile_completeness, which discoveryEngine.js's
  /// calculateScore() weights directly: a fuller profile is more useful to
  /// a scout, independent of how good the player actually is.
  static double _computeCompleteness({
    String? club,
    String? strengths,
    String? videoUrl,
    String? contactEmail,
    String? contactPhone,
    String? league,
    int? height,
    String? foot,
    String? jerseyNumber,
  }) {
    final fields = [club, strengths, videoUrl, contactEmail, contactPhone, league, foot, jerseyNumber];
    final filled = fields.where((f) => f != null && f.isNotEmpty).length + (height != null ? 1 : 0);
    return filled / (fields.length + 1);
  }

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'position': position.dbValue,
        'age': age,
        'country': country,
        'club': club,
        'strengths': strengths,
        'video_url': videoUrl,
        'contact_email': contactEmail,
        'contact_phone': contactPhone,
        'league': league,
        'height': height,
        'foot': foot,
        'jersey_number': jerseyNumber,
        'profile_completeness': _computeCompleteness(
          club: club,
          strengths: strengths,
          videoUrl: videoUrl,
          contactEmail: contactEmail,
          contactPhone: contactPhone,
          league: league,
          height: height,
          foot: foot,
          jerseyNumber: jerseyNumber,
        ),
        'status': 'pending', // client-side inserts are always pending — enforced again by RLS
      };

  bool get isFeatured => featuredUntil != null && featuredUntil!.isAfter(DateTime.now());
  bool get hasContactInfo => (contactEmail?.isNotEmpty ?? false) || (contactPhone?.isNotEmpty ?? false);

  String get initials =>
      name.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
}
