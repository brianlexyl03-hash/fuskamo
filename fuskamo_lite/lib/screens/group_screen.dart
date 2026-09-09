import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_colors.dart';
import '../models/group_model.dart';
import '../providers/group_provider.dart';
import '../repositories/group_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/group_avatar.dart';
import '../widgets/group_poll_card.dart';
import '../services/supabase_service.dart';
import 'group_admin_screen.dart';

class GroupScreen extends StatelessWidget {
  final FuskamoGroup group;
  const GroupScreen({super.key, required this.group});
  @override Widget build(BuildContext context) {
    final tabs=<Tab>[const Tab(text:'MEMBER CHAT')]; if(group.isStaff)tabs.add(const Tab(text:'HOST CHAT'));
    return DefaultTabController(length:tabs.length,child:Scaffold(
      appBar:AppBar(leading:const BackButton(),titleSpacing:0,title:Row(children:[GroupAvatar(group:group,size:38),const SizedBox(width:10),Flexible(child:Text(group.name,maxLines:1,overflow:TextOverflow.ellipsis,style:AppTheme.display(20))),if(group.verified)const Padding(padding:EdgeInsets.only(left:5),child:Icon(Icons.verified,size:17,color:AppColors.green))]),
      actions:[if(group.isStaff)IconButton(tooltip:'Group admin',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>GroupAdminScreen(group:group))),icon:const Icon(Icons.admin_panel_settings_outlined)),if(group.isStaff)IconButton(tooltip:'Create invite',onPressed:()=>_createInvite(context),icon:const Icon(Icons.person_add_alt_1_outlined)),IconButton(onPressed:()=>Share.share('Join ${group.name} on FUSKAMO: @${group.slug}'),icon:const Icon(Icons.ios_share)),PopupMenuButton<String>(onSelected:(v){if(v=='rules')_showRules(context);if(v=='leave')context.read<GroupProvider>().leave(group.id).then((_) {if(context.mounted)Navigator.pop(context);});},itemBuilder:(_)=>const[PopupMenuItem(value:'rules',child:Text('Group rules')),PopupMenuItem(value:'leave',child:Text('Leave group'))])],
      bottom:PreferredSize(preferredSize:const Size.fromHeight(48),child:TabBar(tabs:tabs,isScrollable:true,indicatorColor:AppColors.green,labelColor:AppColors.text,unselectedLabelColor:AppColors.sub))),
      body:TabBarView(children:[GroupChannelView(group:group,channel:'member'),if(group.isStaff)GroupChannelView(group:group,channel:'host')]),
    ));
  }

  Future<void> _showRules(BuildContext context) async => showDialog(context:context,builder:(_)=>AlertDialog(title:Text('GROUP RULES',style:AppTheme.display(20)),content:SizedBox(width:460,child:SingleChildScrollView(child:Text(group.rules.isEmpty?'No special rules published.':group.rules,style:AppTheme.body(14)))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('CLOSE'))]));

  Future<void> _createInvite(BuildContext context) async {
    try { final code=await GroupRepository().createInvite(group.id); if(!context.mounted)return; await showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('INVITE CREATED'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Share this code with the person you want to invite.',style:AppTheme.body(13)),const SizedBox(height:14),SelectableText(code,style:AppTheme.display(28,color:AppColors.green))]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('CLOSE')),ElevatedButton(onPressed:(){Share.share('You are invited to ${group.name} on FUSKAMO. Invite code: $code');Navigator.pop(context);},child:const Text('SHARE'))])); } catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not create invite: $e')));}
  }
}

class GroupChannelView extends StatefulWidget { final FuskamoGroup group; final String channel; const GroupChannelView({super.key,required this.group,required this.channel}); @override State<GroupChannelView> createState()=>_GroupChannelViewState(); }
class _GroupChannelViewState extends State<GroupChannelView> {
  late final GroupChatProvider _provider; final _controller=TextEditingController(); final _scroll=ScrollController();
  @override void initState(){super.initState();_provider=GroupChatProvider(groupId:widget.group.id,channel:widget.channel);_provider.start();}
  @override void dispose(){_controller.dispose();_scroll.dispose();_provider.dispose();super.dispose();}
  Future<void> _send() async {final text=_controller.text.trim();if(text.isEmpty)return;_controller.clear();await _provider.send(text);}
  Future<void> _newPoll() async {final q=TextEditingController();final opts=[TextEditingController(),TextEditingController()];final result=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Create poll'),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:q,decoration:const InputDecoration(labelText:'Question')),const SizedBox(height:10),...opts.asMap().entries.map((e)=>Padding(padding:const EdgeInsets.only(bottom:8),child:TextField(controller:e.value,decoration:InputDecoration(labelText:'Option ${e.key+1}'))))]),),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Create'))]));if(result==true)await _provider.createPoll(q.text,opts.map((o)=>o.text).where((x)=>x.trim().isNotEmpty).toList());q.dispose();for(final o in opts)o.dispose();}
  @override Widget build(BuildContext context)=>ChangeNotifierProvider.value(value:_provider,child:Consumer<GroupChatProvider>(builder:(context,p,_)=>Column(children:[
    if(p.messages.any((m)=>m.isPinned)) _PinnedBar(messages:p.messages.where((m)=>m.isPinned).toList()),
    if(widget.channel=='member'&&p.polls.isNotEmpty)SizedBox(height:190,child:ListView.builder(scrollDirection:Axis.horizontal,itemCount:p.polls.length,itemBuilder:(_,i)=>SizedBox(width:360,child:GroupPollCard(poll:p.polls[i],canPin:widget.group.isStaff,onTogglePin:()=>p.togglePollPin(p.polls[i]),onVote:(id)=>p.vote(p.polls[i].id,id,multipleChoice:p.polls[i].multipleChoice))))),
    Expanded(child:p.loading?const Center(child:CircularProgressIndicator()):p.messages.isEmpty?Center(child:Text(widget.channel=='host'?'Host coordination starts here.':'Be the first to start the conversation.',style:AppTheme.body(14,color:AppColors.sub))):ListView.builder(controller:_scroll,padding:const EdgeInsets.fromLTRB(12,14,12,12),itemCount:p.messages.length,itemBuilder:(ctx,i)=>_MessageBubble(message:p.messages[i],canPin:widget.group.isStaff,onReact:(emoji)=>p.react(p.messages[i].id,emoji),onDelete:()=>p.delete(p.messages[i].id),onTogglePin:()=>p.toggleMessagePin(p.messages[i])))),
    SafeArea(top:false,child:Padding(padding:const EdgeInsets.fromLTRB(10,6,10,10),child:Row(children:[if(widget.channel=='host')IconButton(onPressed:_newPoll,icon:const Icon(Icons.poll_outlined,color:AppColors.green)),Expanded(child:TextField(controller:_controller,minLines:1,maxLines:5,textInputAction:TextInputAction.new,decoration:InputDecoration(hintText:widget.channel=='host'?'Post to hosts…':'Message the group…',suffixIcon:IconButton(onPressed:_send,icon:const Icon(Icons.send)))),)]))),
  ])));
}

class _PinnedBar extends StatelessWidget { final List<GroupMessage> messages; const _PinnedBar({required this.messages}); @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),decoration:BoxDecoration(color:AppColors.surface,border:Border(bottom:BorderSide(color:AppColors.border))),child:Row(children:[const Icon(Icons.push_pin,color:AppColors.green,size:18),const SizedBox(width:8),Expanded(child:Text(messages.last.content,maxLines:1,overflow:TextOverflow.ellipsis,style:AppTheme.body(13,weight:FontWeight.w700))),Text('${messages.length} pinned',style:AppTheme.body(10,color:AppColors.sub))])); }

class _MessageBubble extends StatelessWidget { final GroupMessage message; final VoidCallback onDelete; final Future<void> Function(String) onReact; final bool canPin; final Future<void> Function() onTogglePin; const _MessageBubble({required this.message,required this.onDelete,required this.onReact,required this.canPin,required this.onTogglePin});
  @override Widget build(BuildContext context){final mine=message.senderId==(SupabaseService.isReady?SupabaseService.client.auth.currentUser?.id:null);return Align(alignment:mine?Alignment.centerRight:Alignment.centerLeft,child:Padding(padding:const EdgeInsets.only(bottom:10),child:GestureDetector(onLongPress:()=>_menu(context),child:Container(constraints:const BoxConstraints(maxWidth:360),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppColors.card,borderRadius:BorderRadius.circular(16),border:Border.all(color:message.isPinned?AppColors.green:AppColors.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(message.senderName,style:AppTheme.display(14,color:AppColors.green))),if(message.isPinned)const Icon(Icons.push_pin,size:15,color:AppColors.green)]),const SizedBox(height:4),Text(message.content,style:AppTheme.body(14)),const SizedBox(height:4),Text(_time(message.createdAt),style:AppTheme.body(10,color:AppColors.sub))])))));}
  Future<void> _menu(BuildContext context)=>showModalBottomSheet(context:context,builder:(_)=>SafeArea(child:Wrap(children:[ListTile(title:const Text('👍'),onTap:(){Navigator.pop(context);onReact('👍');}),ListTile(title:const Text('🔥'),onTap:(){Navigator.pop(context);onReact('🔥');}),if(canPin)ListTile(leading:Icon(message.isPinned?Icons.push_pin:Icons.push_pin_outlined),title:Text(message.isPinned?'Unpin message':'Pin message'),onTap:(){Navigator.pop(context);onTogglePin();}),ListTile(title:const Text('Delete message'),onTap:(){Navigator.pop(context);onDelete();})])));
  String _time(DateTime d)=>'${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}
