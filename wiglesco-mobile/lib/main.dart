import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'models/history_item.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Hive: persistent local render history ────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(HistoryItemAdapter());
  await Hive.openBox<HistoryItem>('history');

  runApp(
    const ProviderScope(
      child: WiglescoApp(),
    ),
  );
}

class WiglescoApp extends StatelessWidget {
  const WiglescoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Wiglesco',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
