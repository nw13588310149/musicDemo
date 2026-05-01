import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config_repository.dart';
import '../core/providers/app_providers.dart';
import '../core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'router/route_paths.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // 已经登录过的用户冷启动时，异步刷新一次文件服务器配置；游客 token
    // （如 "youke"）也走相同路径，确保拿到最新的 fileBaseUrl。
    final storage = ref.read(appStorageProvider);
    if (storage.token.isNotEmpty) {
      final repo = ref.read(appConfigRepositoryProvider);
      unawaited(repo.refreshFileBaseUrl());
    }
  }

  @override
  Widget build(BuildContext context) {
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
