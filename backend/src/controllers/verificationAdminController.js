const repository=require('../repositories/verificationAdminRepository');
const asyncHandler=require('../utils/asyncHandler');
exports.listPending=asyncHandler(async(req,res)=>res.json({success:true,applications:await repository.listPending()}));
exports.verifyDomain=asyncHandler(async(req,res)=>res.json({success:true,challenge:await repository.verifyDomain(req.params.id,{id:req.adminUser.id,email:req.adminUser.email,...req.adminContext})}));
exports.review=asyncHandler(async(req,res)=>{const a=await repository.review(req.params.id,req.body.decision,req.body.reason,{id:req.adminUser.id,email:req.adminUser.email,...req.adminContext});res.json({success:true,application:a});});
