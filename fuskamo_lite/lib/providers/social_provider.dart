import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/social_models.dart';
import '../repositories/social_repository.dart';
class SocialProvider extends ChangeNotifier {
 final SocialRepository _repo=SocialRepository();
 SocialRepository get repository => _repo; List<SocialPost> posts=[]; List<SocialStory> stories=[]; List<SocialReel> reels=[]; bool loading=false; String? error; StreamSubscription<List<SocialPost>>? _sub;
 Future<void> load() async {loading=true;error=null;notifyListeners();try{final r=await Future.wait([_repo.feed(),_repo.stories(),_repo.reels()]);posts=r[0] as List<SocialPost>;stories=r[1] as List<SocialStory>;reels=r[2] as List<SocialReel>;}catch(e){error=e.toString();}finally{loading=false;notifyListeners();}}
 void realtime(){_sub?.cancel();_sub=_repo.feedStream().listen((v){posts=v;notifyListeners();});}
 Future<void> createPost(String body)=>_repo.createPost(body).then((_){load();});
 Future<void> toggleLike(String id) async {await _repo.likePost(id);await load();}
 Future<bool> savePost(String id)=>_repo.savePost(id);
 Future<String?> repost(String id,{String? quote})=>_repo.repost(id,quote:quote);
 Future<void> addComment(String id,String body) async {await _repo.addComment(id,body);await load();}
 Future<void> createStory(String url,String caption,{String visibility='followers'})=>_repo.createStory(url,caption:caption,visibility:visibility).then((_){load();});
 Future<void> createReel(String url,String caption)=>_repo.createReel(url,caption:caption).then((_){load();});
 Future<void> toggleReelLike(String id) async {await _repo.likeReel(id);await load();} Future<void> addReelComment(String id,String body) async {await _repo.addReelComment(id,body);await load();}
 @override void dispose(){_sub?.cancel();super.dispose();}
}
