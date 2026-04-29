import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'core/providers/app_providers.dart';
import 'core/storage/app_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final storage = await AppStorage.create();
  final cid = Uri.base.queryParameters['cid'];
  if (cid != null && cid.isNotEmpty) {
    await storage.savePushId(cid);
  }

  runApp(
    ProviderScope(
      overrides: [appStorageProvider.overrideWithValue(storage)],
      child: const MyApp(),
    ),
  );
}
