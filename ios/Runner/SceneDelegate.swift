import Flutter
import UIKit

/// 使用 AppDelegate 中已 run 的显式 FlutterEngine 挂载 RootFlutterViewController。
/// 见 flutter/flutter#183900（ProMotion iPad VSyncClient SIGSEGV）。
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

    let flutterViewController = RootFlutterViewController(
      engine: appDelegate.flutterEngine,
      nibName: nil,
      bundle: nil
    )

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = flutterViewController
    window.makeKeyAndVisible()
    self.window = window
  }
}
