import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../storage/app_storage.dart';

final appStorageProvider = Provider<AppStorage>((ref) {
  throw UnimplementedError('AppStorage provider must be overridden in main().');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(appStorageProvider);
  return ApiClient(storage: storage);
});
