import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// 显式 FlutterEngine：避免 implicit engine + Storyboard 在 ProMotion iPad
  /// （iOS 18+）冷启动时 viewDidLoad 早于 engine 就绪，触发 VSyncClient 空指针闪退。
  lazy var flutterEngine = FlutterEngine(name: "music_road_engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// 让 App 在 iPad 上以沉浸式 / 全屏方式呈现：
/// - 隐藏顶部状态栏；
/// - 隐藏底部 home 指示条（无 home 键设备）；
/// - 延后系统底部上滑手势，避免误触退出。
@objc(RootFlutterViewController)
class RootFlutterViewController: FlutterViewController {
  init(engine: FlutterEngine, nibName: String?, bundle: Bundle?) {
    super.init(engine: engine, nibName: nibName, bundle: bundle)
  }

  @available(*, unavailable)
  required init(coder: NSCoder) {
    fatalError("RootFlutterViewController must be created with an explicit FlutterEngine")
  }

  /// 与 Info.plist 一致，仅横屏；竖握 iPad 时系统不旋转为竖屏 UI。
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return [.landscapeLeft, .landscapeRight]
  }

  override var prefersStatusBarHidden: Bool {
    return true
  }

  override var prefersHomeIndicatorAutoHidden: Bool {
    return true
  }

  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    return [.bottom]
  }
}
