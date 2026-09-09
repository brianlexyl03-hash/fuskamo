import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'services/supabase_service.dart';
import 'lite/lite_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await SupabaseService.init();
  runApp(const FuskamoLiteApp());
}
