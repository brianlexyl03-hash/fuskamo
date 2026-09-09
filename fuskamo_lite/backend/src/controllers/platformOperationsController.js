'use strict';
const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../errors/AppError');
const { getSupabaseAdmin } = require('../config/supabase');
function db(){ const c=getSupabaseAdmin(); if(!c) throw new AppError('Supabase service is not configured',503); return c; }
exports.report=asyncHandler(async(req,res)=>{const {targetType,targetId,reason,description}=req.body||{};if(!targetType||!targetId||!reason)throw new AppError('targetType, targetId and reason are required',400);let targetUserId=null;const ownerTables={post:['social_posts','author_id'],comment:['social_comments','author_id'],reel:['social_reels','author_id'],story:['social_stories','author_id'],profile:['profiles','user_id'],player:['players','submitted_by'],scout:['scouts','user_id']};if(ownerTables[targetType]){const [table,column]=ownerTables[targetType];const lookup=await db().from(table).select(column).eq('id',targetId).maybeSingle();if(lookup.error)throw new AppError(lookup.error.message,400);targetUserId=lookup.data?.[column]||null;}const {data,error}=await db().from('moderation_cases').insert({reporter_id:req.user.id,target_user_id:targetUserId,target_type:targetType,target_id:targetId,reason,description:description||null}).select('id,status,created_at').single();if(error)throw new AppError(error.message,400);res.status(201).json({success:true,data});});
exports.appeal=asyncHandler(async(req,res)=>{const {caseId,reason}=req.body||{};if(!caseId||!reason)throw new AppError('caseId and reason are required',400);const {data,error}=await db().from('moderation_appeals').insert({case_id:caseId,appellant_id:req.user.id,reason}).select('id,status,created_at').single();if(error)throw new AppError(error.message,400);res.status(201).json({success:true,data});});
exports.notifications=asyncHandler(async(req,res)=>{const {data,error}=await db().from('notification_events').select('*').eq('recipient_id',req.user.id).order('created_at',{ascending:false}).limit(100);if(error)throw new AppError(error.message,500);res.json({success:true,data});});
exports.notificationRead=asyncHandler(async(req,res)=>{const {error}=await db().from('notification_events').update({read_at:new Date().toISOString()}).eq('id',req.params.id).eq('recipient_id',req.user.id);if(error)throw new AppError(error.message,400);res.json({success:true});});
exports.analytics=asyncHandler(async(req,res)=>{const days=Math.min(Math.max(Number(req.query.days)||30,1),365);const since=new Date(Date.now()-days*86400000).toISOString();const {data,error}=await db().from('analytics_events').select('event_name,object_type,object_id,value,occurred_at,properties').eq('user_id',req.user.id).gte('occurred_at',since).order('occurred_at',{ascending:false}).limit(5000);if(error)throw new AppError(error.message,500);const summary={};for(const row of data||[])summary[row.event_name]=(summary[row.event_name]||0)+Number(row.value||1);res.json({success:true,days,summary,data});});
exports.analyticsEvent=asyncHandler(async(req,res)=>{const {eventName,objectType,objectId,value,properties,sessionId}=req.body||{};if(!eventName)throw new AppError('eventName is required',400);const {error}=await db().from('analytics_events').insert({user_id:req.user.id,session_id:sessionId||null,event_name:eventName,object_type:objectType||null,object_id:objectId||null,value:value==null?1:Number(value),properties:properties||{}});if(error)throw new AppError(error.message,400);res.status(201).json({success:true});});
exports.feedback=asyncHandler(async(req,res)=>{const {objectType,objectId,signal,weight,sessionId}=req.body||{};if(!objectType||!objectId||!signal)throw new AppError('objectType, objectId and signal are required',400);const {error}=await db().from('recommendation_feedback').insert({user_id:req.user.id,object_type:objectType,object_id:objectId,signal,weight:weight==null?1:Number(weight),session_id:sessionId||null,model_version:'unified-v2'});if(error)throw new AppError(error.message,400);res.status(201).json({success:true});});
exports.registerSession=asyncHandler(async(req,res)=>{const {deviceLabel,platform}=req.body||{};const {data,error}=await db().from('security_sessions').insert({user_id:req.user.id,device_label:deviceLabel||'FUSKAMO device',platform:platform||'mobile'}).select('id').single();if(error)throw new AppError(error.message,400);res.status(201).json({success:true,data});});

exports.securitySessions=asyncHandler(async(req,res)=>{const {data,error}=await db().from('security_sessions').select('id,device_label,platform,last_seen_at,created_at,revoked_at').eq('user_id',req.user.id).order('last_seen_at',{ascending:false});if(error)throw new AppError(error.message,500);res.json({success:true,data});});
exports.revokeSession=asyncHandler(async(req,res)=>{const {error}=await db().from('security_sessions').update({revoked_at:new Date().toISOString()}).eq('id',req.params.id).eq('user_id',req.user.id);if(error)throw new AppError(error.message,400);res.json({success:true});});
exports.securitySettings=asyncHandler(async(req,res)=>{const client=db();if(req.method==='GET'){const {data,error}=await client.from('security_settings').select('*').eq('user_id',req.user.id).maybeSingle();if(error)throw new AppError(error.message,500);return res.json({success:true,data:data||{login_alerts:true,new_device_alerts:true,message_request_filter:true,allow_search_by_email:false,allow_search_by_phone:false}});}const allowed=['login_alerts','new_device_alerts','message_request_filter','allow_search_by_email','allow_search_by_phone'];const payload={user_id:req.user.id};for(const key of allowed)if(typeof req.body?.[key]==='boolean')payload[key]=req.body[key];const {data,error}=await client.from('security_settings').upsert(payload).select('*').single();if(error)throw new AppError(error.message,400);res.json({success:true,data});});

exports.syncOperations = asyncHandler(async (req,res)=>{
  const ops=Array.isArray(req.body?.operations)?req.body.operations.slice(0,100):[];
  if(!ops.length) return res.json({success:true,applied:[],failed:[],conflicts:[]});
  const client=db(); const applied=[],failed=[],conflicts=[];
  for(const op of ops){
    try{
      if(!op?.clientOperationId||!op?.operationType) throw new Error('Invalid operation');
      const base={user_id:req.user.id,client_operation_id:String(op.clientOperationId),operation_type:op.operationType,target_type:op.targetType||null,target_id:op.targetId||null,payload:op.payload||{},status:'processing',attempt_count:1};
      const ins=await client.from('offline_operations').upsert(base,{onConflict:'user_id,client_operation_id'}).select('id,status').single();
      if(ins.error) throw ins.error;
      if(ins.data.status==='applied'){ applied.push(op.clientOperationId); continue; }
      const p=op.payload||{};
      switch(op.operationType){
        case 'follow': { const r=await client.from('profile_follows').insert({follower_id:req.user.id,followed_id:op.targetId}); if(r.error && r.error.code!=='23505')throw r.error; break; }
        case 'unfollow': { const r=await client.from('profile_follows').delete().eq('follower_id',req.user.id).eq('followed_id',op.targetId); if(r.error)throw r.error; break; }
        case 'like': { const r=await client.from('social_post_likes').insert({post_id:op.targetId,user_id:req.user.id}); if(r.error && r.error.code!=='23505')throw r.error; break; }
        case 'unlike': { const r=await client.from('social_post_likes').delete().eq('post_id',op.targetId).eq('user_id',req.user.id); if(r.error)throw r.error; break; }
        case 'create_comment': { const r=await client.from('social_comments').insert({post_id:op.targetId,author_id:req.user.id,body:String(p.body||'').slice(0,5000),parent_id:p.parentId||null}); if(r.error)throw r.error; break; }
        case 'send_message': { const r=await client.from('direct_messages').insert({conversation_id:op.targetId,sender_id:req.user.id,body:String(p.body||'').slice(0,4000),reply_to_id:p.replyToId||null}); if(r.error)throw r.error; break; }
        case 'join_group': { const r=await client.rpc('join_group',{p_group_id:op.targetId,p_display_name:String(p.displayName||'Member').slice(0,60)}); if(r.error)throw r.error; break; }
        case 'leave_group': { const r=await client.from('group_members').delete().eq('group_id',op.targetId).eq('user_id',req.user.id); if(r.error)throw r.error; break; }
        case 'vote_poll': { const r=await client.from('group_poll_votes').insert({poll_id:op.targetId,option_id:p.optionId,user_id:req.user.id}); if(r.error && r.error.code!=='23505')throw r.error; break; }
        case 'save': { const r=await client.from('saved_players').insert({user_id:req.user.id,player_id:op.targetId}); if(r.error && r.error.code!=='23505')throw r.error; break; }
        case 'unsave': { const r=await client.from('saved_players').delete().eq('user_id',req.user.id).eq('player_id',op.targetId); if(r.error)throw r.error; break; }
        case 'analytics': { const r=await client.from('analytics_events').insert({user_id:req.user.id,event_name:p.eventName,object_type:p.objectType||null,object_id:p.objectId||null,value:p.value??1,properties:p.properties||{}}); if(r.error)throw r.error; break; }
        case 'recommendation_feedback': { const r=await client.from('recommendation_feedback').insert({user_id:req.user.id,object_type:p.objectType,object_id:p.objectId,signal:p.signal,weight:p.weight??1,model_version:'unified-v2'}); if(r.error)throw r.error; break; }
        default: throw new Error(`Unsupported operation: ${op.operationType}`);
      }
      await client.from('offline_operations').update({status:'applied',updated_at:new Date().toISOString()}).eq('id',ins.data.id);
      applied.push(op.clientOperationId);
    }catch(e){
      const message=e.message||String(e); const conflict=/duplicate|unique|already|conflict/i.test(message);
      if(op.clientOperationId) await client.from('offline_operations').update({status:conflict?'conflict':'failed',last_error:message,updated_at:new Date().toISOString()}).eq('user_id',req.user.id).eq('client_operation_id',String(op.clientOperationId));
      (conflict?conflicts:failed).push({clientOperationId:op.clientOperationId,error:message});
    }
  }
  res.json({success:true,applied,failed,conflicts});
});
