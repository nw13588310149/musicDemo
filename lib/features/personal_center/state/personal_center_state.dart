import 'package:flutter/foundation.dart';

@immutable
class VipPackageRow {
  const VipPackageRow({
    required this.name,
    required this.description,
    required this.price,
  });

  final String name;
  final String description;
  final String price;
}

@immutable
class PersonalCenterState {
  const PersonalCenterState({
    this.loading = true,
    this.errorMessage,
    this.user = const <String, dynamic>{},
    this.vipPackages = const <VipPackageRow>[],
    this.checkStatusEnabled = false,
    this.walletText = '0.00',
    this.pointsText = '100',
  });

  final bool loading;
  final String? errorMessage;
  final Map<String, dynamic> user;
  final List<VipPackageRow> vipPackages;
  final bool checkStatusEnabled;
  final String walletText;
  final String pointsText;

  PersonalCenterState copyWith({
    bool? loading,
    String? errorMessage,
    bool clearError = false,
    Map<String, dynamic>? user,
    List<VipPackageRow>? vipPackages,
    bool? checkStatusEnabled,
    String? walletText,
    String? pointsText,
  }) {
    return PersonalCenterState(
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      user: user ?? this.user,
      vipPackages: vipPackages ?? this.vipPackages,
      checkStatusEnabled: checkStatusEnabled ?? this.checkStatusEnabled,
      walletText: walletText ?? this.walletText,
      pointsText: pointsText ?? this.pointsText,
    );
  }
}
