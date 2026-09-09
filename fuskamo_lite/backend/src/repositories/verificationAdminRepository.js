const dns=require('node:dns').promises;
const { getSupabaseAdmin } = require('../config/supabase');
const AppError = require('../errors/AppError');
const { auditLog } = require('../utils/auditLogger');

class VerificationAdminRepository {
  _client(){ const c=getSupabaseAdmin(); if(!c) throw new AppError('Supabase is not configured',503); return c; }
  async listPending(){
    const {data,error}=await this._client().from('verification_applications').select('*').in('status',['pending','needs_more_info']).order('submitted_at',{ascending:true});
    if(error) throw new AppError(error.message,400); return data||[];
  }
  async verifyDomain(id, adminContext){
    const db=this._client();
    const {data:c,error}=await db.from('verification_domain_challenges').select('*').eq('application_id',id).is('verified_at',null).order('created_at',{ascending:false}).limit(1).maybeSingle();
    if(error) throw new AppError(error.message,400);
    if(!c) throw new AppError('No active domain challenge found',404);
    if(new Date(c.expires_at)<new Date()) throw new AppError('Domain challenge has expired',400);
    const host=`_fuskamo-verify.${c.domain}`;
    let txt=[];
    try { const records=await dns.resolveTxt(host); txt=records.flat(); } catch(e) { throw new AppError(`DNS TXT lookup failed for ${host}`,400); }
    if(!txt.includes(c.token)) throw new AppError('TXT record does not match the FUSKAMO challenge token',400);
    const {data:updated,error:ue}=await db.from('verification_domain_challenges').update({verified_at:new Date().toISOString()}).eq('id',c.id).select().single();
    if(ue) throw new AppError(ue.message,400);
    await db.from('verification_applications').update({risk_score:Math.max(0,Number((await db.from('verification_applications').select('risk_score').eq('id',id).single()).data?.risk_score||0)-20),updated_at:new Date().toISOString()}).eq('id',id);
    await auditLog({actor:adminContext.email||'unknown-admin',adminId:adminContext.id,ip:adminContext.ip,userAgent:adminContext.userAgent,sessionId:adminContext.sessionId,action:'verification.domain_verified',targetType:'verification_application',targetId:id,metadata:{domain:c.domain,host}});
    return updated;
  }

  async review(id, decision, reason, adminContext){
    if(!['approved','rejected','needs_more_info','revoked'].includes(decision)) throw new AppError('Invalid decision',400);
    const db=this._client();
    const {data:a,error:e}=await db.from('verification_applications').select('*').eq('id',id).single();
    if(e||!a) throw new AppError(e?.message||'Application not found',404);
    const badge=a.applicant_role==='club'?'gold':a.applicant_role==='scout'?'blue':'black';
    const verified=decision==='approved';
    const {data:updated,error:ue}=await db.from('verification_applications').update({status:decision,review_notes:decision==='needs_more_info'?reason:a.review_notes,rejection_reason:['rejected','revoked'].includes(decision)?reason:null,reviewed_at:new Date().toISOString(),reviewed_by:adminContext.id,updated_at:new Date().toISOString()}).eq('id',id).select().single();
    if(ue) throw new AppError(ue.message,400);
    const {error:pe}=await db.from('profiles').update({verified,badge_type:verified?badge:'none',verification_status:decision,verification_method:verified?'human_review':null,verification_reason:reason||null,verified_at:verified?new Date().toISOString():null,verification_expires_at:verified?new Date(Date.now()+365*86400000).toISOString():null,updated_at:new Date().toISOString()}).eq('user_id',a.user_id);
    if(pe) throw new AppError(pe.message,400);
    const code=a.applicant_role==='club'?'club_confirmed':a.applicant_role==='scout'?'scout_confirmed':a.applicant_role==='coach'?'coach_confirmed':'player_confirmed';
    if(verified){
      const {data:ach}=await db.from('badge_achievements').select('id').eq('code',code).single();
      if(ach) await db.from('profile_achievements').upsert({user_id:a.user_id,achievement_id:ach.id,awarded_reason:'Identity/organization verification approved',source:'admin'});
    }
    await db.from('verification_events').insert({user_id:a.user_id,application_id:a.id,event_type:'admin_review',old_status:a.status,new_status:decision,old_badge:null,new_badge:verified?badge:'none',actor_id:adminContext.id,reason:reason||null,metadata:{admin_email:adminContext.email}});
    await auditLog({actor:adminContext.email||'unknown-admin',adminId:adminContext.id,ip:adminContext.ip,userAgent:adminContext.userAgent,sessionId:adminContext.sessionId,action:`verification.${decision}`,targetType:'verification_application',targetId:id,metadata:{userId:a.user_id,role:a.applicant_role,claimedName:a.claimed_name,badge:verified?badge:'none'}});
    return updated;
  }
}
module.exports=new VerificationAdminRepository();
