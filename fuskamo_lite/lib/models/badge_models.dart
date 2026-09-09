class BadgeAchievement {
  final String id;
  final String code;
  final String name;
  final String description;
  final String icon;
  final int points;

  const BadgeAchievement({required this.id, required this.code, required this.name, required this.description, required this.icon, required this.points});

  factory BadgeAchievement.fromJson(Map<String,dynamic> j) => BadgeAchievement(
    id: j['id'] as String,
    code: j['code'] as String,
    name: j['name'] as String,
    description: j['description'] as String,
    icon: j['icon'] as String? ?? '★',
    points: (j['points'] as num?)?.toInt() ?? 0,
  );
}

class VerificationApplication {
  final String id;
  final String role;
  final String claimedName;
  final String? organizationName;
  final String? country;
  final String? officialWebsite;
  final String? officialEmail;
  final String? officialDomain;
  final String? registrationNumber;
  final String? governingBody;
  final String? professionalLicense;
  final String status;
  final String? rejectionReason;
  final DateTime submittedAt;

  const VerificationApplication({required this.id,required this.role,required this.claimedName,this.organizationName,this.country,this.officialWebsite,this.officialEmail,this.officialDomain,this.registrationNumber,this.governingBody,this.professionalLicense,required this.status,this.rejectionReason,required this.submittedAt});

  factory VerificationApplication.fromJson(Map<String,dynamic> j) => VerificationApplication(
    id:j['id'] as String, role:j['applicant_role'] as String, claimedName:j['claimed_name'] as String,
    organizationName:j['organization_name'] as String?, country:j['country'] as String?, officialWebsite:j['official_website'] as String?, officialEmail:j['official_email'] as String?, officialDomain:j['official_domain'] as String?, registrationNumber:j['registration_number'] as String?, governingBody:j['governing_body'] as String?, professionalLicense:j['professional_license'] as String?, status:j['status'] as String, rejectionReason:j['rejection_reason'] as String?, submittedAt:DateTime.tryParse(j['submitted_at'] as String? ?? '') ?? DateTime.now());
}
