import 'package:go_router/go_router.dart';
import '../screens/root_shell_screen.dart';
import '../screens/deep_link_resolver_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const root='/';
  static final GoRouter router=GoRouter(initialLocation:root,routes:[
    GoRoute(path:root,builder:(context,state)=>const RootShellScreen()),
    GoRoute(path:'/@:username',builder:(context,state)=>DeepLinkResolverScreen(type:'profile',value:state.pathParameters['username']!)),
    GoRoute(path:'/player/:id',builder:(context,state)=>DeepLinkResolverScreen(type:'player',value:state.pathParameters['id']!)),
    GoRoute(path:'/club/:id',builder:(context,state)=>DeepLinkResolverScreen(type:'club',value:state.pathParameters['id']!)),
    GoRoute(path:'/scout/:id',builder:(context,state)=>DeepLinkResolverScreen(type:'scout',value:state.pathParameters['id']!)),
    GoRoute(path:'/coach/:id',builder:(context,state)=>DeepLinkResolverScreen(type:'coach',value:state.pathParameters['id']!)),
    GoRoute(path:'/post/:id',builder:(context,state)=>DeepLinkResolverScreen(type:'post',value:state.pathParameters['id']!)),
    GoRoute(path:'/reel/:id',builder:(context,state)=>DeepLinkResolverScreen(type:'reel',value:state.pathParameters['id']!)),
    GoRoute(path:'/story/:id',builder:(context,state)=>DeepLinkResolverScreen(type:'story',value:state.pathParameters['id']!)),
    GoRoute(path:'/group/:id',builder:(context,state)=>DeepLinkResolverScreen(type:'group',value:state.pathParameters['id']!)),
    GoRoute(path:'/invite/:code',builder:(context,state)=>DeepLinkResolverScreen(type:'invite',value:state.pathParameters['code']!)),
  ]);
}
