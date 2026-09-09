import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/messaging_models.dart';
import '../models/badge_models.dart';
import '../repositories/badge_repository.dart';
import '../repositories/messaging_repository.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/affiliation_banner.dart';
import '../widgets/verified_badge.dart';
import 'conversation_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});
  @override State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _messages = MessagingRepository();
  final _badges = BadgeRepository();
  late Future<PublicProfile?> _future;
  bool _following = false;
  bool _liked = false;
  bool _busy = false;
  late Future<List<BadgeAchievement>> _awardsFuture;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _awardsFuture = _badges.achievements(widget.userId);
  }

  Future<PublicProfile?> _load() async {
    final p = await _messages.getProfile(widget.userId);
    final me = SupabaseService.client.auth.currentUser?.id;
    if (p != null && p.userId != me) {
      _following = await _badges.isFollowing(widget.userId);
      _liked = await _badges.hasLiked(widget.userId);
    }
    return p;
  }


  Future<void> _follow(PublicProfile p) async {
    setState(() => _busy = true);
    try {
      if (_following) await _badges.unfollow(p.userId); else await _badges.follow(p.userId);
      setState(() => _following = !_following);
      _future = _messages.getProfile(p.userId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update follow: $e')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _like(PublicProfile p) async {
    setState(() => _busy = true);
    try {
      if (_liked) await _badges.unlikeProfile(p.userId); else await _badges.likeProfile(p.userId);
      setState(() => _liked = !_liked);
      _future = _messages.getProfile(p.userId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update like: $e')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _message(PublicProfile p) async {
    try {
      final id = await _messages.getOrCreateConversation(p.userId);
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationScreen(conversationId: id, other: p)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Messaging unavailable: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('PROFILE', style: AppTheme.display(21))),
    body: FutureBuilder<PublicProfile?>(future: _future,builder:(context,s){
      if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      final p=s.data;if(p==null)return const Center(child:Text('Profile not found.'));
      return ListView(padding:const EdgeInsets.all(18),children:[
        Center(child:CircleAvatar(radius:52,backgroundImage:p.avatarUrl!=null&&p.avatarUrl!.isNotEmpty?NetworkImage(p.avatarUrl!):null,backgroundColor:AppColors.card,child:p.avatarUrl==null||p.avatarUrl!.isEmpty?Text(p.initials,style:AppTheme.display(28,color:AppColors.green)):null)),
        const SizedBox(height:14),
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[Flexible(child:Text(p.displayName,style:AppTheme.display(27),textAlign:TextAlign.center)),const SizedBox(width:7),VerifiedBadge.forProfile(p,size:19)]),
        const SizedBox(height:3),
        Text('@${p.username??'member'} · ${p.role.toUpperCase()}',style:AppTheme.body(12,color:AppColors.sub),textAlign:TextAlign.center),
        if(p.identityClaim!=null&&p.identityClaim!.isNotEmpty) ...[const SizedBox(height:10),AffiliationBanner(notice:p.affiliationNotice)],
        const SizedBox(height:16),
        Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[_stat('FOLLOWERS',p.followersCount),_stat('LIKES',p.profileLikesCount),_stat('AWARD PTS',p.achievementPoints),_stat('SCORE',p.scoreboardScore.toStringAsFixed(0))]),
        const SizedBox(height:18),
        Row(children:[Expanded(child:ElevatedButton(onPressed:_busy?null:()=>_follow(p),child:Text(_following?'FOLLOWING':'FOLLOW'))),const SizedBox(width:8),Expanded(child:OutlinedButton(onPressed:_busy?null:()=>_like(p),child:Text(_liked?'LIKED':'LIKE'))),const SizedBox(width:8),IconButton.filled(onPressed:_busy?null:()=>_message(p),icon:const Icon(Icons.chat_bubble_outline))]),
        if(p.bio.isNotEmpty) ...[const SizedBox(height:18),Text('ABOUT',style:AppTheme.display(18)),const SizedBox(height:6),Text(p.bio,style:AppTheme.body(13))],
        const SizedBox(height:18),
        Text('AWARDS & ACHIEVEMENTS',style:AppTheme.display(18)),
        const SizedBox(height:8),
        FutureBuilder<List<BadgeAchievement>>(future:_awardsFuture,builder:(context,a){final awards=a.data??const <BadgeAchievement>[];if(awards.isEmpty)return Text('Recognition is earned through authentic activity and verified contributions.',style:AppTheme.body(11,color:AppColors.sub));return Wrap(spacing:7,runSpacing:7,children:awards.map((x)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:7),decoration:BoxDecoration(color:AppColors.card,borderRadius:BorderRadius.circular(12),border:Border.all(color:AppColors.border)),child:Text('${x.icon} ${x.name} · ${x.points} pts',style:AppTheme.body(10)))).toList());}),
        const SizedBox(height:18),
        Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppColors.card,borderRadius:BorderRadius.circular(14),border:Border.all(color:AppColors.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('FUSKAMO SCORE',style:AppTheme.display(17)),const SizedBox(height:5),Text('Trust ${p.trustScore.toStringAsFixed(0)}/100 · Profile ${p.profileCompletion.toStringAsFixed(0)}% · Momentum ${p.momentumScore.toStringAsFixed(0)}/100',style:AppTheme.body(11,color:AppColors.sub)),const SizedBox(height:8),Text('A score is a reputation summary, not a verification decision.',style:AppTheme.body(10,color:AppColors.sub))])),
      ]);
    }),
  );

  Widget _stat(String label,Object value)=>Column(children:[Text('$value',style:AppTheme.display(17)),Text(label,style:AppTheme.body(8,color:AppColors.sub))]);
}
