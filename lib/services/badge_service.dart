import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/badge_models.dart';
import 'supabase_service.dart';

class BadgeService {
  SupabaseClient get _db => SupabaseService.client;

  Future<List<BadgeAchievement>> achievements(String userId) async {
    final rows = await _db.from('profile_achievements').select('awarded_at,awarded_reason,badge_achievements(id,code,name,description,icon,points)').eq('user_id', userId).order('awarded_at', ascending: false);
    return rows.map((r) => BadgeAchievement.fromJson(Map<String,dynamic>.from(r['badge_achievements'] as Map))).toList();
  }

  Future<List<VerificationApplication>> myApplications() async {
    final rows = await _db.from('verification_applications').select().eq('user_id', _db.auth.currentUser!.id).order('submitted_at', ascending: false);
    return rows.map((r)=>VerificationApplication.fromJson(Map<String,dynamic>.from(r))).toList();
  }

  Future<VerificationApplication> submit({required String role,required String claimedName,String? organizationName,String? country,String? website,String? email,String? domain,String? registrationNumber,String? governingBody,String? license,List<String> evidenceUrls=const [],List<String> socialLinks=const [],String? identityDocumentRef,String? organizationDocumentRef}) async {
    final row = await _db.rpc('submit_verification_application', params:{
      'p_role':role,'p_claimed_name':claimedName,'p_organization_name':organizationName,'p_country':country,'p_official_website':website,'p_official_email':email,'p_official_domain':domain,'p_registration_number':registrationNumber,'p_governing_body':governingBody,'p_professional_license':license,'p_evidence_urls':evidenceUrls,'p_social_links':socialLinks,'p_identity_document_ref':identityDocumentRef,'p_organization_document_ref':organizationDocumentRef,
    });
    return VerificationApplication.fromJson(Map<String,dynamic>.from(row as Map));
  }

  Future<Map<String,dynamic>?> domainChallenge(String applicationId) async {
    final row=await _db.from('verification_domain_challenges').select('domain,token,method,expires_at,verified_at').eq('application_id',applicationId).order('created_at',ascending:false).limit(1).maybeSingle();
    return row==null?null:Map<String,dynamic>.from(row);
  }

  Future<Map<String,dynamic>> refreshTrust() async {
    final row = await _db.rpc('refresh_my_trust_score');
    await _db.rpc('refresh_my_achievements');
    return Map<String,dynamic>.from(row as Map);
  }

  Future<void> likeProfile(String userId) async => _db.from('profile_likes').upsert({'user_id':userId,'liker_id':_db.auth.currentUser!.id});
  Future<void> unlikeProfile(String userId) async => _db.from('profile_likes').delete().eq('user_id',userId).eq('liker_id',_db.auth.currentUser!.id);
  Future<void> setIdentityClaim(String? claim) async { await _db.rpc('set_identity_claim', params: {'p_identity_claim': claim}); }

  Future<int> likeCount(String userId) async { final rows=await _db.from('profile_likes').select('liker_id').eq('user_id',userId); return rows.length; }
  Future<bool> hasLiked(String userId) async => (await _db.from('profile_likes').select('user_id').eq('user_id',userId).eq('liker_id',_db.auth.currentUser!.id).maybeSingle()) != null;
  Future<void> follow(String userId) async => _db.from('profile_follows').upsert({'follower_id':_db.auth.currentUser!.id,'followed_id':userId});
  Future<void> unfollow(String userId) async => _db.from('profile_follows').delete().eq('follower_id',_db.auth.currentUser!.id).eq('followed_id',userId);
  Future<bool> isFollowing(String userId) async => (await _db.from('profile_follows').select('follower_id').eq('follower_id',_db.auth.currentUser!.id).eq('followed_id',userId).maybeSingle()) != null;
}
