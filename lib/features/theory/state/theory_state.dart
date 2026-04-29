import 'package:flutter/foundation.dart';

@immutable
class TheoryPageArgs {
  const TheoryPageArgs({required this.id, this.type});

  final int id;
  final String? type;

  factory TheoryPageArgs.fromRaw(dynamic raw) {
    if (raw is TheoryPageArgs) {
      return raw;
    }
    if (raw is Map) {
      final id = int.tryParse(raw['id']?.toString() ?? '') ?? 0;
      final typeRaw = raw['type']?.toString();
      final type = (typeRaw == null || typeRaw.isEmpty) ? null : typeRaw;
      return TheoryPageArgs(id: id, type: type);
    }
    return const TheoryPageArgs(id: 0);
  }

  @override
  bool operator ==(Object other) {
    return other is TheoryPageArgs && other.id == id && other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, type);
}

@immutable
class TheoryDetail {
  const TheoryDetail({
    required this.id,
    required this.title,
    required this.firstMenu,
    required this.vipOnly,
    required this.htmlContent,
    required this.pdfUrl,
    required this.assignmentImages,
    required this.answerImages,
  });

  final int id;
  final String title;
  final int firstMenu;
  final bool vipOnly;
  final String htmlContent;
  final String pdfUrl;
  final List<String> assignmentImages;
  final List<String> answerImages;

  bool get hasPdf => pdfUrl.isNotEmpty;
  bool get hasAssignmentImages => assignmentImages.isNotEmpty;
  bool get hasAnswerImages => answerImages.isNotEmpty;
  bool get showsAssignmentButton => firstMenu != 6;
  bool get hasHtmlContent => htmlContent.trim().isNotEmpty;
}

@immutable
class TheoryState {
  const TheoryState({
    required this.args,
    required this.loading,
    required this.detail,
    required this.errorMessage,
  });

  final TheoryPageArgs args;
  final bool loading;
  final TheoryDetail? detail;
  final String errorMessage;

  bool get hasDetail => detail != null;

  TheoryState copyWith({
    TheoryPageArgs? args,
    bool? loading,
    TheoryDetail? detail,
    bool clearDetail = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return TheoryState(
      args: args ?? this.args,
      loading: loading ?? this.loading,
      detail: clearDetail ? null : (detail ?? this.detail),
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
    );
  }

  static TheoryState initial(TheoryPageArgs args) => TheoryState(
    args: args,
    loading: true,
    detail: null,
    errorMessage: '',
  );
}
