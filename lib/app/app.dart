import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_providers.dart';
import '../core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'router/route_paths.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(appStorageProvider);
    final initialRoute = storage.token.isEmpty
        ? RoutePaths.login
        : RoutePaths.home;

    return MaterialApp(
      title: '音乐之路',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
