import 'package:flutter/material.dart';

import 'core/platform/cross_platform_channel.dart';
import 'features/pdf/ui/pdf_test_page.dart';
import 'features/piano/ui/piano_page.dart';

/// 第一阶段入口：验证工程可运行，并演示跨平台通道封装（原生未实现时仍可启动）。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MusicPerfDemoApp());
}

class MusicPerfDemoApp extends StatelessWidget {
  const MusicPerfDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '音乐艺考性能 Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  String _platformLabel = '检测中…';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _probePlatform();
  }

  /// 通过 [CrossPlatformChannel] 读取宿主标识；无原生实现时回退为 Flutter 枚举描述。
  Future<void> _probePlatform() async {
    final String label = await CrossPlatformChannel.getHostPlatformLabel();
    if (!mounted) return;
    setState(() {
      _platformLabel = label;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('音乐艺考性能 Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              '当前已接入：\n'
              '1）跨平台通道骨架（Android / iOS / 鸿蒙可扩展）；\n'
              '2）钢琴复刻页（UI/交互对齐 uniapp 版本）；\n'
              '3）音频引擎已替换为 flutter_soloud 并支持并发播放。',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                title: const Text('宿主平台标识'),
                subtitle: Text(_loading ? '…' : _platformLabel),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loading ? null : _probePlatform,
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PianoPage(),
                  ),
                );
              },
              icon: const Icon(Icons.piano),
              label: const Text('进入钢琴测试页（Flutter 复刻）'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PdfTestPage(),
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('进入 PDF 测试页（网络加载/缩放）'),
            ),
            const Spacer(),
            Text(
              '通道名：${CrossPlatformChannel.kChannelName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
