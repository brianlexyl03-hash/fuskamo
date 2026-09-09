import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/social_models.dart';
import '../providers/social_provider.dart';
import '../theme/app_theme.dart';
import 'story_settings_screen.dart';

class SocialFeedScreen extends StatefulWidget { const SocialFeedScreen({super.key}); @override State<SocialFeedScreen> createState()=>_SocialFeedScreenState(); }
class _SocialFeedScreenState extends State<SocialFeedScreen> {
 final _composer=TextEditingController();
 @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_) {final p=context.read<SocialProvider>();p.load();p.realtime();});}
 @override void dispose(){_composer.dispose();super.dispose();}
 Future<void> _post() async {final text=_composer.text.trim();if(text.isEmpty)return;_composer.clear();await context.read<SocialProvider>().createPost(text);} Future<void> _storyDialog() async {final url=TextEditingController();final caption=TextEditingController();String visibility='followers';final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('CREATE STORY'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:url,decoration:const InputDecoration(labelText:'Image/video URL')),TextField(controller:caption,decoration:const InputDecoration(labelText:'Caption')),DropdownButtonFormField<String>(value:visibility,decoration:const InputDecoration(labelText:'Audience'),items:const [DropdownMenuItem(value:'public',child:Text('Public')),DropdownMenuItem(value:'followers',child:Text('Followers')),DropdownMenuItem(value:'close_friends',child:Text('Close Friends'))],onChanged:(v){if(v!=null)visibility=v;})]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('CANCEL')),ElevatedButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('POST'))]));if(ok==true&&url.text.trim().isNotEmpty){await context.read<SocialProvider>().createStory(url.text.trim(),caption.text.trim(),visibility:visibility);}}
 @override Widget build(BuildContext context){return Consumer<SocialProvider>(builder:(context,p,_){return Column(children:[
   Padding(padding:const EdgeInsets.fromLTRB(16,14,16,8),child:Row(children:[Expanded(child:Text('FUSKAMO SOCIAL',style:AppTheme.display(28))),IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const StorySettingsScreen())),icon:const Icon(Icons.visibility_outlined)),IconButton(onPressed:p.load,icon:const Icon(Icons.refresh))])),
   SizedBox(height:92,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:14),itemCount:p.stories.length+1,itemBuilder:(_,i)=>i==0?_AddStory(onTap:()=>_storyDialog()):_StoryBubble(story:p.stories[i-1]),separatorBuilder:(_,__)=>const SizedBox(width:12))),
   Padding(padding:const EdgeInsets.all(12),child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[Expanded(child:TextField(controller:_composer,maxLines:4,minLines:1,decoration:const InputDecoration(hintText:'Share football news, thoughts or scouting insight…'))),const SizedBox(width:8),IconButton(onPressed:_post,style:IconButton.styleFrom(backgroundColor:AppColors.green,foregroundColor:AppColors.black),icon:const Icon(Icons.send))])),
   const Divider(height:1,color:AppColors.border),
   Expanded(child:p.loading&&p.posts.isEmpty?const Center(child:CircularProgressIndicator(color:AppColors.green)):RefreshIndicator(onRefresh:p.load,child:ListView.builder(padding:const EdgeInsets.all(12),itemCount:p.posts.length,itemBuilder:(_,i)=>_PostCard(post:p.posts[i]))))
 ]);});}
}
class _AddStory extends StatelessWidget{final VoidCallback onTap;const _AddStory({required this.onTap});@override Widget build(BuildContext context)=>GestureDetector(onTap:onTap,child:Column(children:[CircleAvatar(radius:30,backgroundColor:AppColors.surface,child:const Icon(Icons.add,color:AppColors.green)),const SizedBox(height:3),Text('Add story',style:AppTheme.body(10,color:AppColors.sub))]));}
class _StoryBubble extends StatelessWidget{final SocialStory story;const _StoryBubble({required this.story});@override Widget build(BuildContext context)=>Column(children:[CircleAvatar(radius:30,backgroundColor:AppColors.green,backgroundImage:NetworkImage(story.mediaUrl)),SizedBox(width:70,child:Text('Story',overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:AppTheme.body(10,color:AppColors.sub))) ]);}
class _PostCard extends StatefulWidget{final SocialPost post;const _PostCard({required this.post});@override State<_PostCard> createState()=>_PostCardState();}
class _PostCardState extends State<_PostCard>{bool liked=false; bool saved=false;final _comment=TextEditingController();@override void dispose(){_comment.dispose();super.dispose();}
 Future<void> _report()async{final reason=await showDialog<String>(context:context,builder:(ctx)=>SimpleDialog(title:const Text('REPORT POST'),children:['spam','harassment','impersonation','scam','hate','sexual','violence','other'].map((r)=>SimpleDialogOption(onPressed:()=>Navigator.pop(ctx,r),child:Text(r))).toList()));if(reason!=null){await context.read<SocialProvider>().repository.report(targetType:'post',targetId:widget.post.id,reason:reason);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Report submitted.')));}}
 Future<void> _comments() async {
  final repo=context.read<SocialProvider>();
  final comments=await repo.repository.comments(widget.post.id);
  if(!mounted)return;
  showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:AppColors.surface,builder:(_)=>Padding(
    padding:EdgeInsets.only(bottom:MediaQuery.of(context).viewInsets.bottom),
    child:StatefulBuilder(builder:(ctx,setState)=>SizedBox(height:MediaQuery.of(context).size.height*.72,child:Column(children:[
      Padding(padding:const EdgeInsets.all(16),child:Text('COMMENTS',style:AppTheme.display(22))),
      Expanded(child:ListView(children:comments.map((c)=>ListTile(title:Text(c.body),subtitle:Text(c.authorId),leading:const CircleAvatar(child:Icon(Icons.person)))).toList())),
      Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:TextField(controller:_comment,decoration:const InputDecoration(hintText:'Write a comment…'))),IconButton(onPressed:()async{final t=_comment.text.trim();if(t.isEmpty)return;await repo.addComment(widget.post.id,t);_comment.clear();setState((){});},icon:const Icon(Icons.send,color:AppColors.green))]))
    ])))
  ));
 }
 @override Widget build(BuildContext context){final p=widget.post;return Card(color:AppColors.card,margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const CircleAvatar(child:Icon(Icons.person)),const SizedBox(width:10),Expanded(child:Text('@${p.authorId.substring(0,8)}',style:AppTheme.body(13,weight:FontWeight.bold))),Text(_age(p.createdAt),style:AppTheme.body(10,color:AppColors.sub)),PopupMenuButton<String>(onSelected:(v)=>v=='report'?_report():null,itemBuilder:(_)=>const [PopupMenuItem(value:'report',child:Text('Report post'))])]),if(p.body.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(p.body,style:AppTheme.body(14))),if(p.mediaUrl!=null&&p.mediaType=='image')ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.network(p.mediaUrl!,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(height:80,child:Center(child:Icon(Icons.broken_image))))),Row(children:[IconButton(onPressed:()async{await context.read<SocialProvider>().toggleLike(p.id);setState(()=>liked=!liked);},icon:Icon(liked?Icons.favorite:Icons.favorite_border,color:liked?AppColors.red:null)),Text('${p.likeCount}'),IconButton(onPressed:_comments,icon:const Icon(Icons.comment_outlined)),Text('${p.commentCount}'),IconButton(onPressed:()async{await context.read<SocialProvider>().repost(p.id);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Reposted.')));},icon:const Icon(Icons.repeat)),IconButton(onPressed:()async{await context.read<SocialProvider>().savePost(p.id);if(mounted)setState(()=>saved=!saved);},icon:Icon(saved?Icons.bookmark:Icons.bookmark_border,color:saved?AppColors.green:null))])])));}
 String _age(DateTime d){final m=DateTime.now().difference(d).inMinutes;return m<60?'${m}m':m<1440?'${m~/60}h':'${m~/1440}d';}
}
