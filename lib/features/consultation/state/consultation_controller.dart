import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/consultation_repository.dart';
import 'consultation_state.dart';

/// 资讯接口暂未联动用户省份，先按 1.0 默认值传「甘肃」。
const String _kDefaultProvince = '甘肃';

final consultationControllerProvider = StateNotifierProvider.autoDispose
    .family<ConsultationController, ConsultationState, ConsultationPageArgs>((
      ref,
      args,
    ) {
      final repo = ref.watch(consultationRepositoryProvider);
      return ConsultationController(repository: repo, args: args);
    });

class ConsultationController extends StateNotifier<ConsultationState> {
  ConsultationController({
    required ConsultationRepository repository,
    required ConsultationPageArgs args,
  }) : _repository = repository,
       _args = args,
       super(ConsultationState.initial) {
    unawaited(refresh());
  }

  final ConsultationRepository _repository;
  final ConsultationPageArgs _args;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearErrorMessage: true);

    if (_args.schoolMode) {
      final schoolResponse = await _repository.getSchoolList(
        province: _kDefaultProvince,
      );
      if (!mounted) return;

      if (schoolResponse.isSuccess) {
        final schoolItems = _parseItems(schoolResponse.data);
        if (schoolItems.isNotEmpty) {
          state = state.copyWith(loading: false, items: schoolItems);
          return;
        }
      }
    }

    final response = await _repository.getList(province: _kDefaultProvince);
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        items: const <ConsultationItem>[],
        errorMessage: response.msg.isEmpty ? '资讯加载失败' : response.msg,
      );
      return;
    }

    state = state.copyWith(
      loading: false,
      items: _parseItems(response.data),
    );
  }

  List<ConsultationItem> _parseItems(dynamic raw) {
    if (raw is! List) {
      return const <ConsultationItem>[];
    }

    final items = <ConsultationItem>[];
    for (final node in raw) {
      if (node is Map) {
        items.add(ConsultationItem.fromJson(node));
      }
    }
    return items;
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }
}
