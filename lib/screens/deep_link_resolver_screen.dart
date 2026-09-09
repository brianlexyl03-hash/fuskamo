import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'public_profile_screen.dart';

class DeepLinkResolverScreen extends StatefulWidget {
  final String type; final String value;
  const DeepLinkResolverScreen({super.key,required this.type,required this.value});
  @override State<DeepLinkResolverScreen> createState()=>_DeepLinkResolverScreenState();
}
class _DeepLinkResolverScreenState extends State<DeepLinkResolverScreen>{ String? error; @override void initState(){super.initState();_resolve();}
  Future<void> _resolve() async { try {
    if(!SupabaseService.isReady) throw Exception('FUSKAMO is not connected yet.');
    if(widget.type=='profile'){ final rows=await SupabaseService.client.from('profiles').select('id').eq('username',widget.value.toLowerCase()).limit(1); if(rows.isEmpty)throw Exception('Profile not found.'); if(!mounted)return; Navigator.of(context).pushReplacement(MaterialPageRoute(builder:(_)=>PublicProfileScreen(userId:rows.first['id'] as String))); return; }
    if(widget.type=='player'){ final rows=await SupabaseService.client.from('players').select('id,name').eq('id',widget.value).limit(1); if(rows.isEmpty)throw Exception('Player not found.'); }
    if(widget.type=='group'){ final rows=await SupabaseService.client.from('groups').select('id,name').eq('slug',widget.value).limit(1); if(rows.isEmpty)throw Exception('Group not found.'); }
    setState(()=>error='This link is valid, but the destination needs the feature screen to open it directly.');
  } catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}}
  @override Widget build(BuildContext context)=>Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.link,color:AppColors.green,size:54),const SizedBox(height:16),Text(error??'Opening FUSKAMO…',textAlign:TextAlign.center,style:AppTheme.body(14)),if(error!=null)...[const SizedBox(height:16),ElevatedButton(onPressed:()=>Navigator.pop(context),child:const Text('BACK'))]]))));
}
