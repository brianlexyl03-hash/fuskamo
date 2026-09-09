import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_colors.dart';
import '../providers/group_provider.dart';
import '../repositories/group_repository.dart';
import '../models/group_model.dart';
import '../theme/app_theme.dart';
import '../widgets/group_card.dart';
import 'create_group_screen.dart';
import 'group_screen.dart';

class GroupsScreen extends StatefulWidget { const GroupsScreen({super.key}); @override State<GroupsScreen> createState()=>_GroupsScreenState(); }
class _GroupsScreenState extends State<GroupsScreen> {
  final _inviteController = TextEditingController();
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>context.read<GroupProvider>().load());}
  @override void dispose(){_inviteController.dispose();super.dispose();}
  Future<void> _create() async { await Navigator.push(context,MaterialPageRoute(builder:(_)=>const CreateGroupScreen())); if(mounted)context.read<GroupProvider>().load(); }

  Future<void> _join(FuskamoGroup group) async {
    final provider = context.read<GroupProvider>();
    try {
      final details = await provider.getDetails(group);
      if (!mounted) return;
      final agreed = await _showRules(details);
      if (!agreed || !mounted) return;
      final result = await provider.join(details);
      if (!mounted) return;
      if (result == 'joined') {
        final joined = provider.joined.where((x)=>x.id==group.id).toList();
        if (joined.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder:(_)=>GroupScreen(group:joined.first)));
      } else if (result == 'requested') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join request sent to the group staff.')));
      }
    } catch (e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not join: $e'))); }
  }

  Future<bool> _showRules(FuskamoGroup group) async {
    final hasRules = group.rules.trim().isNotEmpty;
    var accepted = false;
    return await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder:(ctx,setState)=>AlertDialog(
      title: Row(children:[const Icon(Icons.rule_folder_outlined,color:AppColors.green),const SizedBox(width:8),Expanded(child:Text('BEFORE YOU JOIN',style:AppTheme.display(20)))]),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(group.name,style:AppTheme.display(24)),
        const SizedBox(height:6),
        Text('${group.memberCount} members · ${group.privacy.toUpperCase()}',style:AppTheme.body(12,color:AppColors.sub)),
        const SizedBox(height:16),
        Text('GROUP RULES',style:AppTheme.display(16,color:AppColors.green)),
        const SizedBox(height:8),
        Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:AppColors.border)),child:Text(hasRules?group.rules:'This group has not published any special rules yet. You still agree to follow FUSKAMO\'s community standards.',style:AppTheme.body(13))),
        const SizedBox(height:12),
        CheckboxListTile(contentPadding:EdgeInsets.zero,value:accepted,onChanged:(v)=>setState(()=>accepted=v??false),title:const Text('I have read and agree to these rules'),controlAffinity:ListTileControlAffinity.leading),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('CANCEL')),ElevatedButton(onPressed:accepted?()=>Navigator.pop(ctx,true):null,child:Text(group.privacy=='private'?'REQUEST TO JOIN':'JOIN GROUP'))],
    ))) ?? false;
  }

  Future<void> _enterInvite() async {
    _inviteController.clear();
    await showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('JOIN BY INVITE'),content:TextField(controller:_inviteController,autocapitalize:TextCapitalization.characters,decoration:const InputDecoration(labelText:'Invite code',hintText:'ABC123DEF456')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('CANCEL')),ElevatedButton(onPressed:() async {final code=_inviteController.text.trim();if(code.isEmpty)return;Navigator.pop(ctx);await _acceptInvite(code);},child:const Text('CONTINUE'))]));
  }
  Future<void> _acceptInvite(String code) async {
    try {
      final repo=GroupRepository(); final preview=await repo.previewInvite(code);
      if(!mounted)return;
      if(preview==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('That invite is invalid, expired, or already used.')));return;}
      final accepted=await showDialog<bool>(context:context,builder:(ctx){var checked=false;return StatefulBuilder(builder:(ctx,setState)=>AlertDialog(title:Text(preview.name,style:AppTheme.display(22)),content:SizedBox(width:460,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('You were invited to this group.',style:AppTheme.body(13)),const SizedBox(height:14),Text('RULES',style:AppTheme.display(16,color:AppColors.green)),const SizedBox(height:7),Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.all(Radius.circular(14))),child:Text(preview.rules.isEmpty?'No special rules published.':preview.rules)),CheckboxListTile(contentPadding:EdgeInsets.zero,value:checked,onChanged:(v)=>setState(()=>checked=v??false),title:const Text('I agree to the group rules'),controlAffinity:ListTileControlAffinity.leading)])),),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('CANCEL')),ElevatedButton(onPressed:checked?()=>Navigator.pop(ctx,true):null,child:const Text('JOIN'))]));});
      if(accepted!=true||!mounted)return;
      final result=await repo.acceptInvite(code); await context.read<GroupProvider>().load();
      if(!mounted)return; final joined=context.read<GroupProvider>().joined.where((g)=>g.id==preview.groupId).toList();
      if(joined.isNotEmpty)Navigator.push(context,MaterialPageRoute(builder:(_)=>GroupScreen(group:joined.first)));
      else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result=='already_member'?'You are already a member.':'Joined ${preview.name}.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Invite failed: $e')));}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<GroupProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: provider.load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: _buildSlivers(context, provider),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildSlivers(BuildContext context, GroupProvider provider) {
    final slivers = <Widget>[
      SliverToBoxAdapter(child: _header(context)),
    ];
    if (provider.error != null) {
      slivers.add(SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), child: Text(provider.error!, style: AppTheme.body(12, color: AppColors.red)))));
    }
    if (provider.joined.isNotEmpty) {
      slivers.add(SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final group = provider.joined[index];
              return GroupCard(group: group, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupScreen(group: group))));
            },
            childCount: provider.joined.length,
          ),
        ),
      ));
    }
    slivers.add(SliverToBoxAdapter(child: _recommendedHeader(context, provider)));
    if (provider.recommended.isEmpty && !provider.loading) {
      slivers.add(SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(30), child: Center(child: Text('No new communities yet.', style: AppTheme.body(13, color: AppColors.sub))))));
    }
    slivers.add(SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final group = provider.recommended[index];
            return GroupCard(group: group, showJoin: true, onJoin: () => _join(group));
          },
          childCount: provider.recommended.length,
        ),
      ),
    ));
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 30)));
    return slivers;
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MY CHATS', style: AppTheme.display(30)),
          Text('Football communities you belong to', style: AppTheme.body(12, color: AppColors.sub)),
        ])),
        IconButton(onPressed: _enterInvite, tooltip: 'Join by invite', icon: const Icon(Icons.vpn_key_outlined)),
        IconButton(onPressed: _create, style: IconButton.styleFrom(backgroundColor: AppColors.green), color: AppColors.black, icon: const Icon(Icons.add)),
      ]),
    );
  }

  Widget _recommendedHeader(BuildContext context, GroupProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Row(children: [
        Expanded(child: Text('RECOMMENDED', style: AppTheme.display(27))),
        TextButton(
          onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _DiscoverySheet(groups: provider.recommended, onJoin: _join)),
          child: const Text('View all'),
        ),
      ]),
    );
  }

}

class _DiscoverySheet extends StatelessWidget { final List<FuskamoGroup> groups; final Future<void> Function(FuskamoGroup) onJoin; const _DiscoverySheet({required this.groups,required this.onJoin}); @override Widget build(BuildContext context)=>SafeArea(child:DraggableScrollableSheet(expand:false,builder:(_,c)=>ListView(controller:c,padding:const EdgeInsets.all(14),children:[Text('DISCOVER GROUPS',style:AppTheme.display(26)),const SizedBox(height:12),...groups.map((g)=>GroupCard(group:g,showJoin:true,onJoin:()=>onJoin(g)))]))); }
