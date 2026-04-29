import 'dart:typed_data';

import 'avatar_picker_stub.dart'
    if (dart.library.html) 'avatar_picker_web.dart'
    if (dart.library.io) 'avatar_picker_io.dart';

/// 选择本地图片文件，返回字节流和文件名；用户取消或当前平台不支持时返回 null。
///
/// 在 Web 上通过隐藏的 `<input type="file" accept="image/*">` 实现，
/// IO（移动端 / 桌面）上当前没有依赖图片选择器，先返回 null，由调用方提示用户。
Future<({Uint8List bytes, String filename})?> pickAvatarFile() =>
    pickAvatarFileImpl();
