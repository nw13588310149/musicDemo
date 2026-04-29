import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return AiChatRepository(client: client);
});

class AiChatRepository {
  AiChatRepository({required this.client});

  final ApiClient client;

  Future<ApiResponse> getSessionList({
    int current = 1,
    int size = 50,
    String robot = 'deepseek',
  }) {
    return client.post(
      '/app/user/chat-gpt/sessionList',
      data: <String, dynamic>{'current': current, 'size': size, 'robot': robot},
    );
  }

  Future<ApiResponse> createSession({
    required String title,
    String robot = 'deepseek',
  }) {
    return client.post(
      '/app/user/chat-gpt/sessionCreate',
      data: <String, dynamic>{'robot': robot, 'title': title},
    );
  }

  Future<ApiResponse> deleteSession(String sessionId) {
    return client.post(
      '/app/user/chat-gpt/sessionDelete',
      data: <String, dynamic>{'id': sessionId},
    );
  }

  Future<ApiResponse> getMessages(String sessionId, {int size = 100}) {
    return client.post(
      '/app/user/chat-gpt/msgList',
      data: <String, dynamic>{
        'sessionId': sessionId,
        'offsetId': 0,
        'size': size,
        'isDesc': false,
      },
    );
  }

  Future<ApiResponse> sendMessage({
    required String sessionId,
    required String content,
    required bool isDeep,
    required String model,
    required String systemPrompt,
  }) {
    return client.post(
      '/app/user/chat-gpt/send',
      data: <String, dynamic>{
        'sessionId': sessionId,
        'content': content,
        'isDeep': isDeep,
        'model': model,
        'systemPrompt': systemPrompt,
        'system': systemPrompt,
      },
      timeout: const Duration(seconds: 120),
    );
  }
}
