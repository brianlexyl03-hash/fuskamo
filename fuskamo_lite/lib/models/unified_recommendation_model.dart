class UnifiedRecommendation {
  final String objectType;
  final String objectId;
  final String authorId;
  final String role;
  final double quality;
  final double trust;
  final double safety;
  final DateTime? createdAt;
  final double engagement;
  final double score;
  final String reason;
  final String modelVersion;

  const UnifiedRecommendation({
    required this.objectType,
    required this.objectId,
    required this.authorId,
    required this.role,
    required this.quality,
    required this.trust,
    required this.safety,
    this.createdAt,
    required this.engagement,
    required this.score,
    required this.reason,
    required this.modelVersion,
  });

  factory UnifiedRecommendation.fromJson(Map<String, dynamic> json) => UnifiedRecommendation(
        objectType: json['object_type'] as String? ?? '',
        objectId: json['object_id'] as String? ?? '',
        authorId: json['author_id'] as String? ?? '',
        role: json['role'] as String? ?? 'fan',
        quality: (json['quality'] as num?)?.toDouble() ?? 0,
        trust: (json['trust'] as num?)?.toDouble() ?? 0,
        safety: (json['safety'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        engagement: (json['engagement'] as num?)?.toDouble() ?? 0,
        score: (json['score'] as num?)?.toDouble() ?? 0,
        reason: json['reason'] as String? ?? '',
        modelVersion: json['model_version'] as String? ?? 'unified-v1',
      );
}
