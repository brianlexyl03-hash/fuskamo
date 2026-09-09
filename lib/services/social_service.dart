import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/social_models.dart';
import 'supabase_service.dart';

class SocialService {
  SupabaseClient get _db=>SupabaseService.client;
  String get _me=>_db.auth.currentUser!.id;
  String _session()=> '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1<<30)}';

  Future<List<SocialPost>> feed({int limit=30}) async {
    final rows=await _db.rpc('get_social_feed',params:{'p_limit':limit});
    return rows.map((r)=>SocialPost.fromJson(Map<String,dynamic>.from(r))).toList();
  }
  Stream<List<SocialPost>> feedStream()=>_db.from('social_posts').stream(primaryKey:['id']).eq('status','published').order('created_at',ascending:false).limit(50).map((rows)=>rows.where((r)=>r['visibility']=='public').map((r)=>SocialPost.fromJson(Map<String,dynamic>.from(r))).toList());
  Future<String> createPost(String body,{String? mediaUrl,String mediaType='none',String visibility='public'}) async {
    final text=body.trim();
    final r=await _db.from('social_posts').insert({'author_id':_me,'body':text,'media_url':mediaUrl,'media_type':mediaType,'visibility':visibility}).select('id').single();
    final postId=r['id'] as String;
    final tags=RegExp(r'(?<![A-Za-z0-9_])#([A-Za-z0-9_]{1,50})').allMatches(text).map((m)=>m.group(1)!.toLowerCase()).toSet();
    for(final tag in tags){
      final row=await _db.from('social_hashtags').upsert({'tag':tag},onConflict:'tag').select('id').single();
      await _db.from('social_post_hashtags').upsert({'post_id':postId,'hashtag_id':row['id']},onConflict:'post_id,hashtag_id');
    }
    final mentions=RegExp(r'@([a-z][a-z0-9_]{2,19})').allMatches(text).map((m)=>m.group(1)!.toLowerCase()).toSet();
    for(final username in mentions){
      final profile=await _db.from('profiles').select('user_id').eq('username',username).maybeSingle();
      if(profile!=null && profile['user_id']!=_me){ await _db.from('social_post_mentions').upsert({'post_id':postId,'mentioned_user_id':profile['user_id']},onConflict:'post_id,mentioned_user_id'); }
    }
    return postId;
  }
  Future<bool> likePost(String id)=>_db.rpc('toggle_post_like',params:{'p_post':id}).then((v)=>v as bool);
  Future<bool> savePost(String id)=>_db.rpc('toggle_post_save',params:{'p_post':id}).then((v)=>v as bool);
  Future<String?> repost(String id,{String? quote})=>_db.rpc('create_repost',params:{'p_post':id,'p_quote':quote}).then((v)=>v as String?);
  Future<void> viewPost(String id,{int watchMs=0})=>_db.rpc('record_post_view',params:{'p_post':id,'p_session':_session(),'p_watch_ms':watchMs});
  Future<List<SocialComment>> comments(String postId) async { final rows=await _db.from('social_comments').select().eq('post_id',postId).eq('status','published').order('created_at'); return rows.map((r)=>SocialComment.fromJson(Map<String,dynamic>.from(r))).toList(); }
  Future<void> addComment(String postId,String body,{String? parentId}) async { await _db.from('social_comments').insert({'post_id':postId,'author_id':_me,'parent_id':parentId,'body':body.trim()}); await _db.rpc('refresh_social_post_counts',params:{'p_post':postId}); }
  Future<bool> likeComment(String id) async { final existing=await _db.from('social_comment_likes').select().eq('comment_id',id).eq('user_id',_me).maybeSingle(); if(existing!=null){await _db.from('social_comment_likes').delete().eq('comment_id',id).eq('user_id',_me);return false;} await _db.from('social_comment_likes').insert({'comment_id':id,'user_id':_me}); return true; }
  Future<String> createStory(String mediaUrl,{String caption='',String mediaType='image',String visibility='followers'}) async { final r=await _db.from('social_stories').insert({'author_id':_me,'media_url':mediaUrl,'caption':caption,'media_type':mediaType,'visibility':visibility}).select('id').single();return r['id'] as String; }
  Future<List<SocialStory>> stories() async { final rows=await _db.from('social_stories').select().eq('status','published').gt('expires_at',DateTime.now().toUtc().toIso8601String()).order('created_at',ascending:false).limit(50);return rows.map((r)=>SocialStory.fromJson(Map<String,dynamic>.from(r))).toList(); }
  Future<void> viewStory(String id)=>_db.rpc('record_story_view',params:{'p_story':id});
  Future<String> createReel(String videoUrl,{String caption='',String? thumbnailUrl,int durationMs=0,String visibility='public'}) async { final r=await _db.from('social_reels').insert({'author_id':_me,'video_url':videoUrl,'caption':caption,'thumbnail_url':thumbnailUrl,'duration_ms':durationMs,'visibility':visibility}).select('id').single();return r['id'] as String; }
  Future<List<SocialReel>> reels({int limit=30}) async { final rows=await _db.rpc('get_social_reels',params:{'p_limit':limit});return rows.map((r)=>SocialReel.fromJson(Map<String,dynamic>.from(r))).toList(); }
  Future<bool> likeReel(String id)=>_db.rpc('toggle_reel_like',params:{'p_reel':id}).then((v)=>v as bool);
  Future<bool> saveReel(String id)=>_db.rpc('toggle_reel_save',params:{'p_reel':id}).then((v)=>v as bool);
  Future<void> shareReel(String id,{String channel='share'})=>_db.rpc('record_reel_share',params:{'p_reel':id,'p_channel':channel});
  Future<void> reelFeedback(String id,String feedback) async { await _db.from('social_reel_feedback').upsert({'reel_id':id,'user_id':_me,'feedback':feedback}); } Future<List<Map<String,dynamic>>> reelComments(String id) async { final rows=await _db.from('social_reel_comments').select().eq('reel_id',id).eq('status','published').order('created_at'); return rows.map<Map<String,dynamic>>((r)=>Map<String,dynamic>.from(r)).toList(); } Future<void> addReelComment(String id,String body,{String? parentId}) async {await _db.from('social_reel_comments').insert({'reel_id':id,'author_id':_me,'parent_id':parentId,'body':body.trim()});await _db.rpc('refresh_social_reel_counts',params:{'p_reel':id});}
  Future<void> viewReel(String id,{required int watchMs,required bool completed,int rewatch=0})=>_db.rpc('record_reel_view',params:{'p_reel':id,'p_session':_session(),'p_watch_ms':watchMs,'p_completed':completed,'p_rewatch':rewatch});
  Future<List<Map<String,dynamic>>> search(String q) async { final rows=await _db.rpc('search_fuskamo_v2',params:{'p_query':q,'p_limit':40});return rows.map<Map<String,dynamic>>((r)=>Map<String,dynamic>.from(r)).toList(); }
  Future<List<CreatorMetric>> analytics({int days=30}) async { final rows=await _db.rpc('get_creator_analytics',params:{'p_days':days});return rows.map((r)=>CreatorMetric.fromJson(Map<String,dynamic>.from(r))).toList(); }
  Future<void> report({required String targetType,required String targetId,required String reason,String details=''})=>_db.from('content_reports').insert({'reporter_id':_me,'target_type':targetType,'target_id':targetId,'reason':reason,'details':details});
}
