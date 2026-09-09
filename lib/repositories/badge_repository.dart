import '../models/badge_models.dart';
import '../services/badge_service.dart';

class BadgeRepository {
  final BadgeService _service = BadgeService();
  Future<List<BadgeAchievement>> achievements(String userId)=>_service.achievements(userId);
  Future<List<VerificationApplication>> myApplications()=>_service.myApplications();
  Future<VerificationApplication> submit({required String role,required String claimedName,String? organizationName,String? country,String? website,String? email,String? domain,String? registrationNumber,String? governingBody,String? license,List<String> evidenceUrls=const [],List<String> socialLinks=const [],String? identityDocumentRef,String? organizationDocumentRef})=>_service.submit(role:role,claimedName:claimedName,organizationName:organizationName,country:country,website:website,email:email,domain:domain,registrationNumber:registrationNumber,governingBody:governingBody,license:license,evidenceUrls:evidenceUrls,socialLinks:socialLinks,identityDocumentRef:identityDocumentRef,organizationDocumentRef:organizationDocumentRef);
  Future<Map<String,dynamic>?> domainChallenge(String applicationId)=>_service.domainChallenge(applicationId);
  Future<Map<String,dynamic>> refreshTrust()=>_service.refreshTrust();
  Future<void> likeProfile(String userId)=>_service.likeProfile(userId);
  Future<void> unlikeProfile(String userId)=>_service.unlikeProfile(userId);
  Future<void> setIdentityClaim(String? claim)=>_service.setIdentityClaim(claim);
  Future<int> likeCount(String userId)=>_service.likeCount(userId);
  Future<bool> hasLiked(String userId)=>_service.hasLiked(userId);
  Future<void> follow(String userId)=>_service.follow(userId);
  Future<void> unfollow(String userId)=>_service.unfollow(userId);
  Future<bool> isFollowing(String userId)=>_service.isFollowing(userId);
}
