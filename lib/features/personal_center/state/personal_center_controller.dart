import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';
import '../data/personal_center_repository.dart';
import 'personal_center_state.dart';

final personalCenterControllerProvider =
    StateNotifierProvider.autoDispose<
        PersonalCenterController,
        PersonalCenterState>((ref) {
      final repository = ref.watch(personalCenterRepositoryProvider);
      final storage = ref.watch(appStorageProvider);
      return PersonalCenterController(
        repository: repository,
        storage: storage,
      );
    });

class PersonalCenterController extends StateNotifier<PersonalCenterState> {
  PersonalCenterController({
    required PersonalCenterRepository repository,
    required AppStorage storage,
  })  : _repository = repository,
        _storage = storage,
        super(
          PersonalCenterState(
            checkStatusEnabled: storage.hasCheckStatus,
          ),
        ) {
    refresh();
  }

  final PersonalCenterRepository _repository;
  final AppStorage _storage;

  Future<void> refresh() async {
    state = state.copyWith(
      loading: true,
      clearError: true,
      checkStatusEnabled: _storage.hasCheckStatus,
    );

    final info = await _repository.getMyInfo();
    if (info.code != 0) {
      state = state.copyWith(loading: false, errorMessage: info.msg);
      return;
    }

    final userMap = _parseUserMap(info.data);
    final vipRes = await _repository.vipList();
    final packages = _parseVipList(vipRes.data);

    state = PersonalCenterState(
      loading: false,
      user: userMap,
      vipPackages: packages,
      checkStatusEnabled: _storage.hasCheckStatus,
      walletText: _walletFromUser(userMap),
      pointsText: _pointsFromUser(userMap),
    );
  }

  Map<String, dynamic> _parseUserMap(dynamic data) {
    if (data is Map<String, dynamic> && data['user'] is Map) {
      return Map<String, dynamic>.from(data['user'] as Map);
    }
    return const <String, dynamic>{};
  }

  List<VipPackageRow> _parseVipList(dynamic data) {
    if (data is! List<dynamic>) {
      return const <VipPackageRow>[];
    }
    final out = <VipPackageRow>[];
    for (final item in data) {
      if (item is! Map) {
        continue;
      }
      final m = Map<String, dynamic>.from(item);
      out.add(
        VipPackageRow(
          name: m['name']?.toString() ?? '',
          description: m['description']?.toString() ?? '',
          price: m['price']?.toString() ?? '',
        ),
      );
    }
    return out;
  }

  String _walletFromUser(Map<String, dynamic> u) {
    final v = u['wallet'] ?? u['balance'];
    if (v == null) {
      return '0.00';
    }
    return v.toString();
  }

  String _pointsFromUser(Map<String, dynamic> u) {
    final v = u['points'] ?? u['integral'];
    if (v == null) {
      return '100';
    }
    return v.toString();
  }

  /// 与 1.0 一致：将到期时间转为「剩余天数」整数；无法解析时返回 null。
  int? vipDaysRemaining() {
    final raw = state.user['vipExpireDate'];
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is double) {
      return raw.round();
    }
    final s = raw.toString();
    final d = DateTime.tryParse(s);
    if (d != null) {
      return d.difference(DateTime.now()).inDays;
    }
    return int.tryParse(s);
  }

  /// 成功时 `error` 为 null 且 `url` 非空。
  Future<({String? url, String? error})> fetchQrImageUrl() async {
    final r = await _repository.myQrcode();
    if (r.code != 0) {
      return (url: null, error: r.msg);
    }
    final url = r.data?.toString() ?? '';
    if (url.isEmpty) {
      return (url: null, error: '二维码为空');
    }
    return (url: url, error: null);
  }

  /// 兑换成功返回 null，失败返回错误信息。
  Future<String?> redeemVip(String card) async {
    final trimmed = card.trim();
    if (trimmed.isEmpty) {
      return '请输入兑换码';
    }
    final r = await _repository.vipCardRedeem(trimmed);
    if (r.code != 0) {
      return r.msg;
    }
    await refresh();
    return null;
  }
}
