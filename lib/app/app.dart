import 'package:flutter/material.dart';
import '../config/brand_config.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';
class FreiraumApp extends StatelessWidget{const FreiraumApp({super.key});@override Widget build(BuildContext context)=>MaterialApp.router(title:BrandConfig.name,theme:appTheme(),debugShowCheckedModeBanner:false,routerConfig:router);}
