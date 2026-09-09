import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/player_service.dart';
import '../models/player_model.dart';

class FuskamoLiteApp extends StatelessWidget {
  const FuskamoLiteApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FUSKAMO Lite',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green, brightness: Brightness.dark),
        home: const LiteGate(),
      );
}

class LiteGate extends StatefulWidget {
  const LiteGate({super.key});
  @override State<LiteGate> createState() => _LiteGateState();
}
class _LiteGateState extends State<LiteGate> {
  final _auth = AuthService();
  @override Widget build(BuildContext context) {
    if (!SupabaseService.isReady) return const LiteSetupScreen();
    return StreamBuilder<AuthState>(
      stream: _auth.onAuthStateChange,
      builder: (_, snap) => _auth.currentUser == null ? const LiteAuthScreen() : const LiteShell(),
    );
  }
}

class LiteSetupScreen extends StatelessWidget {
  const LiteSetupScreen({super.key});
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Padding(
    padding: EdgeInsets.all(24), child: Text('FUSKAMO Lite\n\nAdd SUPABASE_URL and SUPABASE_ANON_KEY to .env, then restart the app.', textAlign: TextAlign.center),
  )));
}

class LiteAuthScreen extends StatefulWidget {
  const LiteAuthScreen({super.key});
  @override State<LiteAuthScreen> createState() => _LiteAuthScreenState();
}
class _LiteAuthScreenState extends State<LiteAuthScreen> {
  final email = TextEditingController(); final password = TextEditingController();
  bool signUp = false, busy = false; String? error;
  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try { if (signUp) { await AuthService().signUp(email: email.text.trim(), password: password.text); } else { await AuthService().signIn(email: email.text.trim(), password: password.text); } }
    catch (e) { setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 420), child: Padding(
    padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('FUSKAMO LITE', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8), const Text('Football discovery, without the heavy parts.'), const SizedBox(height: 28),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
      const SizedBox(height: 12), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 16), SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Please wait…' : (signUp ? 'Create account' : 'Log in')))),
      TextButton(onPressed: busy ? null : () => setState(() => signUp = !signUp), child: Text(signUp ? 'Already have an account? Log in' : 'Create an account')),
    ]),
  )))));
}

class LiteShell extends StatefulWidget { const LiteShell({super.key}); @override State<LiteShell> createState() => _LiteShellState(); }
class _LiteShellState extends State<LiteShell> {
  int index = 0;
  final pages = const [LiteHome(), LiteDiscover(), LiteGroups(), LiteMessages(), LiteProfile()];
  @override Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: index, children: pages),
    bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (i) => setState(() => index = i), destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.search), label: 'Discover'),
      NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Groups'),
      NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Messages'),
      NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
    ]),
  );
}

class LiteHome extends StatefulWidget { const LiteHome({super.key}); @override State<LiteHome> createState() => _LiteHomeState(); }
class _LiteHomeState extends State<LiteHome> {
  final body = TextEditingController(); bool busy = false;
  Future<List<Map<String,dynamic>>> posts() async { if (!SupabaseService.isReady) return []; final r = await SupabaseService.client.from('social_posts').select('id,body,author_id,created_at,like_count,comment_count').eq('status','published').eq('visibility','public').order('created_at',ascending:false).limit(20); return List<Map<String,dynamic>>.from(r); }
  Future<void> createPost() async { final text=body.text.trim(); if(text.isEmpty) return; setState(()=>busy=true); try { await SupabaseService.client.from('social_posts').insert({'author_id':SupabaseService.client.auth.currentUser!.id,'body':text,'media_type':'none','visibility':'public','status':'published'}); body.clear(); setState((){}); } finally { if(mounted)setState(()=>busy=false); } }
  @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:()async=>setState((){}),child: CustomScrollView(slivers:[SliverAppBar(title:const Text('FUSKAMO Lite'),floating:true,actions:[IconButton(onPressed:()=>setState((){}),icon:const Icon(Icons.refresh))]),SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.all(12),child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[TextField(controller:body,maxLines:3,maxLength:500,decoration:const InputDecoration(hintText:'Share football news or a thought…',border:InputBorder.none)),Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:busy?null:createPost,icon:const Icon(Icons.send),label:const Text('Post')))])))),FutureBuilder<List<Map<String,dynamic>>>(future:posts(),builder:(c,s){if(s.connectionState==ConnectionState.waiting)return const SliverFillRemaining(child:Center(child:CircularProgressIndicator())); final rows=s.data??[]; if(rows.isEmpty)return const SliverFillRemaining(child:Center(child:Text('No posts yet. Be the first.'))); return SliverList.builder(itemCount:rows.length,itemBuilder:(c,i)=>_PostCard(row:rows[i]));})]));
}
class _PostCard extends StatelessWidget { final Map<String,dynamic> row; const _PostCard({required this.row}); @override Widget build(BuildContext context)=>Card(margin:const EdgeInsets.fromLTRB(12,0,12,10),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('@${(row['author_id'] as String).substring(0,8)}',style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:8),Text(row['body'] as String),const SizedBox(height:10),Text('♥ ${row['like_count']??0}   💬 ${row['comment_count']??0}',style:Theme.of(context).textTheme.bodySmall)])));
}

class LiteDiscover extends StatefulWidget { const LiteDiscover({super.key}); @override State<LiteDiscover> createState()=>_LiteDiscoverState(); }
class _LiteDiscoverState extends State<LiteDiscover>{final q=TextEditingController(); List<Player> players=[]; bool busy=false; Future<void> search()async{setState(()=>busy=true);try{players=await PlayerService().searchApprovedPlayers(q.text);}finally{if(mounted)setState(()=>busy=false);}} @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Discover')),body:Padding(padding:const EdgeInsets.all(12),child:Column(children:[TextField(controller:q,onSubmitted:(_)=>search(),decoration:InputDecoration(hintText:'Search players',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(onPressed:search,icon:const Icon(Icons.arrow_forward)))),const SizedBox(height:12),Expanded(child:busy?const Center(child:CircularProgressIndicator()):players.isEmpty?const Center(child:Text('Search approved players.')):ListView.builder(itemCount:players.length,itemBuilder:(c,i){final p=players[i];return ListTile(leading:CircleAvatar(child:Text(p.initials)),title:Text(p.name),subtitle:Text('${p.position.dbValue} • ${p.country} • ${p.age}'),trailing:p.isFeatured?const Icon(Icons.star):null);}))])));}

class LiteGroups extends StatefulWidget { const LiteGroups({super.key}); @override State<LiteGroups> createState()=>_LiteGroupsState(); }
class _LiteGroupsState extends State<LiteGroups>{List<Map<String,dynamic>> groups=[]; bool busy=true; @override void initState(){super.initState();load();} Future<void> load()async{setState(()=>busy=true);try{final r=await SupabaseService.client.from('groups').select('id,name,description,privacy,member_count,verified').eq('privacy','public').order('last_activity_at',ascending:false).limit(30);groups=List<Map<String,dynamic>>.from(r);}catch(_){groups=[];}finally{if(mounted)setState(()=>busy=false);}} @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Groups'),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),body:busy?const Center(child:CircularProgressIndicator()):groups.isEmpty?const Center(child:Text('No public groups yet.')):ListView.builder(itemCount:groups.length,itemBuilder:(c,i){final g=groups[i];return Card(margin:const EdgeInsets.fromLTRB(12,0,12,10),child:ListTile(leading:CircleAvatar(child:Text((g['name'] as String).substring(0,1).toUpperCase())),title:Text(g['name'] as String),subtitle:Text('${g['member_count']??0} members • ${g['description']??''}'),trailing:const Icon(Icons.chevron_right)));}));}

class LiteMessages extends StatelessWidget { const LiteMessages({super.key}); @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Messages')),body:const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Your secure conversations appear here.\n\nLite keeps messaging text-first to save data and storage.',textAlign:TextAlign.center)))); }

class LiteProfile extends StatefulWidget { const LiteProfile({super.key}); @override State<LiteProfile> createState()=>_LiteProfileState(); }
class _LiteProfileState extends State<LiteProfile>{Map<String,dynamic>? profile; bool busy=true; @override void initState(){super.initState();load();} Future<void> load()async{try{final u=SupabaseService.client.auth.currentUser!;final r=await SupabaseService.client.from('profiles').select('display_name,username,bio,role,verified,badge_type').eq('user_id',u.id).maybeSingle();profile=r;}catch(_){ }finally{if(mounted)setState(()=>busy=false);}} @override Widget build(BuildContext c){final u=SupabaseService.client.auth.currentUser;return Scaffold(appBar:AppBar(title:const Text('Profile')),body:busy?const Center(child:CircularProgressIndicator()):Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const CircleAvatar(radius:34,child:Icon(Icons.person,size:34)),const SizedBox(height:14),Text(profile?['display_name']??'FUSKAMO member',style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),if(profile?['username']!=null)Text('@${profile!['username']}'),if(profile?['verified']==true)const Padding(padding:EdgeInsets.only(top:8),child:Text('✓ Verified',style:TextStyle(fontWeight:FontWeight.bold))),const SizedBox(height:8),Text(profile?['bio']??'No bio yet.'),const Spacer(),Text(u?.email??''),const SizedBox(height:10),OutlinedButton.icon(onPressed:()async{await AuthService().signOut();},icon:const Icon(Icons.logout),label:const Text('Log out'))]));}}
