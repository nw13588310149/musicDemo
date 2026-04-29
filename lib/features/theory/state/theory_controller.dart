import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_response.dart';
import '../data/theory_repository.dart';
import 'theory_state.dart';

final theoryControllerProvider = StateNotifierProvider.autoDispose
    .family<TheoryController, TheoryState, TheoryPageArgs>((ref, args) {
      final repository = ref.watch(theoryRepositoryProvider);
      return TheoryController(repository: repository, args: args);
    });

class TheoryController extends StateNotifier<TheoryState> {
  TheoryController({
    required this.repository,
    required TheoryPageArgs args,
  }) : super(TheoryState.initial(args)) {
    unawaited(_initialize());
  }

  final TheoryRepository repository;
  bool _answerRecordSaved = false;

  Future<void> _initialize() async {
    try {
      await loadDetail(state.args.id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        errorMessage: '页面初始化失败，请稍后重试',
      );
    }
  }

  Future<void> loadDetail(int id) async {
    if (id <= 0) {
      state = state.copyWith(
        loading: false,
        errorMessage: '教材参数无效，无法打开乐理页面',
      );
      return;
    }

    state = state.copyWith(loading: true, clearErrorMessage: true);

    final responses = await Future.wait<ApiResponse>(<Future<ApiResponse>>[
      repository.getDetail(id),
      repository.getMyInfo(),
    ]);
    if (!mounted) {
      return;
    }

    final detailResponse = responses[0];
    final infoResponse = responses[1];

    if (!detailResponse.isSuccess ||
        detailResponse.data is! Map<String, dynamic>) {
      state = state.copyWith(
        loading: false,
        errorMessage: detailResponse.msg.isEmpty
            ? '加载乐理详情失败'
            : detailResponse.msg,
      );
      return;
    }

    final detailMap = detailResponse.data as Map<String, dynamic>;
    final detail = _parseDetail(detailMap);

    if (detail.vipOnly && !_hasVipAccess(infoResponse.data)) {
      state = state.copyWith(
        loading: false,
        errorMessage: '当前内容需要会员权限，请先开通或续费会员',
      );
      return;
    }

    _answerRecordSaved = false;
    state = state.copyWith(
      loading: false,
      detail: detail,
      clearErrorMessage: true,
    );
  }

  /// 用户点击"查看答案"时调用，记录学习行为（与 1.0 保持一致）。
  Future<void> markAnswerOpened() async {
    final detail = state.detail;
    if (detail == null || _answerRecordSaved) {
      return;
    }
    _answerRecordSaved = true;
    unawaited(repository.saveStudyRecord(detail.id));
  }

  void clearError() {
    if (state.errorMessage.isEmpty) {
      return;
    }
    state = state.copyWith(clearErrorMessage: true);
  }

  TheoryDetail _parseDetail(Map<String, dynamic> raw) {
    final id = int.tryParse(raw['id']?.toString() ?? '') ?? 0;
    final firstMenu = int.tryParse(raw['firstMenu']?.toString() ?? '') ?? 0;
    final title = raw['title']?.toString().trim().isNotEmpty == true
        ? raw['title'].toString().trim()
        : '未命名教材';

    final pdfUrl = _resolvePdfUrl(raw);

    return TheoryDetail(
      id: id,
      title: title,
      firstMenu: firstMenu,
      vipOnly: raw['vip']?.toString() == '1',
      htmlContent: raw['longText1']?.toString() ?? '',
      pdfUrl: pdfUrl,
      assignmentImages: _parseImageList(raw['img1']),
      answerImages: _parseImageList(raw['img2']),
    );
  }

  /// 与 1.0 一致：依次检查 file1/file2/file3，取第一个 PDF 字段。
  String _resolvePdfUrl(Map<String, dynamic> raw) {
    for (final field in const <String>['file1', 'file2', 'file3']) {
      final value = raw[field];
      if (value == null) {
        continue;
      }
      final url = _firstPdfFromRaw(value);
      if (url.isNotEmpty) {
        return url;
      }
    }
    return '';
  }

  String _firstPdfFromRaw(dynamic raw) {
    final values = _normalizeToList(raw);
    if (values.isEmpty) {
      final url = _resolveMediaUrl(raw?.toString() ?? '');
      return _isPdfUrl(url) ? url : '';
    }
    for (final entry in values) {
      String? candidate;
      if (entry is Map<String, dynamic>) {
        candidate = entry['url']?.toString() ?? entry['fileUrl']?.toString();
      } else {
        final decoded = _decodeJsonLike(entry);
        if (decoded is Map<String, dynamic>) {
          candidate = decoded['url']?.toString();
        } else {
          candidate = entry?.toString();
        }
      }
      final resolved = _resolveMediaUrl(candidate ?? '');
      if (_isPdfUrl(resolved)) {
        return resolved;
      }
    }
    return '';
  }

  bool _isPdfUrl(String url) {
    if (url.isEmpty) {
      return false;
    }
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf') || lower.contains('.pdf?');
  }

  List<String> _parseImageList(dynamic raw) {
    final values = _normalizeToList(raw);
    final result = <String>[];
    for (final entry in values) {
      if (entry is Map<String, dynamic>) {
        final url = _resolveMediaUrl(
          entry['url']?.toString() ?? entry['img']?.toString() ?? '',
        );
        if (url.isNotEmpty) {
          result.add(url);
        }
        continue;
      }
      final decoded = _decodeJsonLike(entry);
      if (decoded is Map<String, dynamic>) {
        final url = _resolveMediaUrl(decoded['url']?.toString() ?? '');
        if (url.isNotEmpty) {
          result.add(url);
        }
        continue;
      }
      final url = _resolveMediaUrl(entry?.toString() ?? '');
      if (url.isNotEmpty) {
        result.add(url);
      }
    }
    return result;
  }

  List<dynamic> _normalizeToList(dynamic raw) {
    if (raw == null) {
      return const <dynamic>[];
    }
    final decoded = _decodeJsonLike(raw);
    if (decoded is List) {
      if (decoded.length == 1 && decoded.first is List) {
        return List<dynamic>.from(decoded.first as List);
      }
      return List<dynamic>.from(decoded);
    }
    if (decoded is Map<String, dynamic>) {
      return <dynamic>[decoded];
    }
    final text = raw.toString().trim();
    if (text.isEmpty) {
      return const <dynamic>[];
    }
    return <dynamic>[raw];
  }

  dynamic _decodeJsonLike(dynamic value) {
    if (value is List || value is Map<String, dynamic>) {
      return value;
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return value;
    }
    try {
      return jsonDecode(text);
    } catch (_) {
      return value;
    }
  }

  String _resolveMediaUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return 'https:$value';
    }
    final normalized = value.startsWith('/') ? value : '/$value';
    return '${AppConstants.apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}$normalized';
  }

  bool _hasVipAccess(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return false;
    }
    // myInfo 接口返回结构：{ user: { vipExpireDate, ... }, ... }
    final user = data['user'];
    final source = user is Map<String, dynamic> ? user : data;
    final raw = source['vipExpireDate']?.toString() ?? '';
    if (raw.trim().isEmpty) {
      return false;
    }
    final expire = DateTime.tryParse(raw.replaceAll('/', '-'));
    if (expire == null) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final vipDate = DateTime(expire.year, expire.month, expire.day);
    return !vipDate.isBefore(today);
  }
}
