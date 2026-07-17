import 'package:go_router/go_router.dart';import '../features/discovery/presentation/discovery_screen.dart';import '../features/launch/launch_screen.dart';
final router=GoRouter(routes:[GoRoute(path:'/',builder:(c,s)=>const LaunchScreen()),GoRoute(path:'/discover',builder:(c,s)=>const DiscoveryScreen()),GoRoute(path:'/search',builder:(c,s)=>const DiscoveryScreen(results:true))]);
