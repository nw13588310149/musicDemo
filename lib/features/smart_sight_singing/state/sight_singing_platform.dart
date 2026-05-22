import 'sight_singing_platform_stub.dart'
    if (dart.library.io) 'sight_singing_platform_io.dart';

/// 智能视唱平台能力（iPad 默认无声跟唱，避免外放串音）。
abstract final class SightSingingPlatform {
  static bool get isIosTablet => isIosTabletImpl;

  /// iPad 上默认不播放扬声器伴奏，仅按音符条跟唱。
  static bool get defaultsToVisualOnlyMode => isIosTablet;
}
