import UIKit

/// iOS 前台截屏 / 录屏防护。
///
/// 原理：将 `UIWindow.layer` 挂到 `isSecureTextEntry` UITextField 的安全渲染子树下，
/// 系统合成截屏/录屏时会跳过该层（截图黑屏、录屏黑屏）。
///
/// 必须在 `RootFlutterViewController.viewDidAppear` 且 window 就绪后调用；
/// 不可在 Flutter 插件注册阶段启用（与显式 FlutterEngine + SceneDelegate 冲突会黑屏）。
final class ScreenCaptureGuard {
  static let shared = ScreenCaptureGuard()

  private var secureField: UITextField?
  private weak var protectedWindow: UIWindow?
  private var recordingOverlay: UIView?
  private var recordingObserver: NSObjectProtocol?

  private init() {}

  func enable(on window: UIWindow) {
    guard secureField == nil else { return }
    guard window.rootViewController != nil else { return }

    let field = UITextField()
    field.isSecureTextEntry = true
    field.isUserInteractionEnabled = false
    if #available(iOS 16.0, *) {
      field.overrideUserInterfaceStyle = .light
    }

    window.addSubview(field)
    field.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      field.centerXAnchor.constraint(equalTo: window.centerXAnchor),
      field.centerYAnchor.constraint(equalTo: window.centerYAnchor),
      field.widthAnchor.constraint(equalToConstant: 1),
      field.heightAnchor.constraint(equalToConstant: 1),
    ])
    window.layoutIfNeeded()

    guard let superlayer = window.layer.superlayer else {
      field.removeFromSuperview()
      return
    }
    superlayer.addSublayer(field.layer)

    let secureSublayer: CALayer?
    if #available(iOS 17.0, *) {
      secureSublayer = field.layer.sublayers?.last ?? field.layer.sublayers?.first
    } else {
      secureSublayer = field.layer.sublayers?.first ?? field.layer.sublayers?.last
    }

    guard let secureSublayer else {
      field.layer.removeFromSuperlayer()
      field.removeFromSuperview()
      return
    }

    secureSublayer.addSublayer(window.layer)

    secureField = field
    protectedWindow = window
    observeScreenRecording(on: window)
  }

  private func observeScreenRecording(on window: UIWindow) {
    guard recordingObserver == nil else { return }

    recordingObserver = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self, weak window] _ in
      guard let self, let window else { return }
      if UIScreen.main.isCaptured {
        self.showRecordingOverlay(on: window)
      } else {
        self.hideRecordingOverlay()
      }
    }

    if UIScreen.main.isCaptured {
      showRecordingOverlay(on: window)
    }
  }

  private func showRecordingOverlay(on window: UIWindow) {
    guard recordingOverlay == nil else { return }

    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = .black
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.isUserInteractionEnabled = false
    window.addSubview(overlay)
    recordingOverlay = overlay
  }

  private func hideRecordingOverlay() {
    recordingOverlay?.removeFromSuperview()
    recordingOverlay = nil
  }
}
