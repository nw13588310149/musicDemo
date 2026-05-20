import AVFoundation
import Flutter
import UIKit

/// Low-latency short-note playback for iPad piano / dictation.
///
/// Long audio stays in media_kit / just_audio. This class caches Flutter assets
/// as AVAudioPCMBuffer and starts AVAudioEngine lazily on the first real note.
final class LowLatencyNoteAudio {
  private let channel: FlutterMethodChannel
  private let engine = AVAudioEngine()
  private let queue = DispatchQueue(label: "com.yyzl.music.lowLatencyNotes")
  private var buffersByKey: [String: AVAudioPCMBuffer] = [:]
  private var activeNodes: [AVAudioPlayerNode] = []
  private var prepared = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.yyzl.music/low_latency_notes",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "prepare":
      guard
        let args = call.arguments as? [String: Any],
        let assets = args["assets"] as? [String: String]
      else {
        result(FlutterError(code: "bad_args", message: "Missing assets", details: nil))
        return
      }
      prepare(assets: assets, result: result)
    case "play":
      guard
        let args = call.arguments as? [String: Any],
        let key = args["key"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "Missing key", details: nil))
        return
      }
      let volume = (args["volume"] as? NSNumber)?.floatValue ?? 1.0
      play(key: key, volume: volume, result: result)
    case "stopAll":
      stopAll()
      result(nil)
    case "dispose":
      dispose()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func prepare(assets: [String: String], result: @escaping FlutterResult) {
    queue.async { [weak self] in
      guard let self = self else { return }
      do {
        try self.configureSession()

        var loaded = 0
        for (key, asset) in assets {
          if self.buffersByKey[key] != nil {
            loaded += 1
            continue
          }
          guard let url = self.resolveFlutterAsset(asset) else {
            throw LowLatencyNoteAudioError.assetNotFound(asset)
          }
          self.buffersByKey[key] = try self.decodeAsset(url: url)
          loaded += 1
        }
        self.prepared = true
        DispatchQueue.main.async {
          result(["loaded": loaded])
        }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "prepare_failed",
              message: "\(error)",
              details: nil
            )
          )
        }
      }
    }
  }

  private func play(key: String, volume: Float, result: @escaping FlutterResult) {
    queue.async { [weak self] in
      guard let self = self else { return }
      do {
        guard let buffer = self.buffersByKey[key] else {
          throw LowLatencyNoteAudioError.bufferNotPrepared(key)
        }

        let node = AVAudioPlayerNode()
        node.volume = max(0, min(volume, 1))
        self.engine.attach(node)
        self.engine.connect(node, to: self.engine.mainMixerNode, format: buffer.format)
        self.activeNodes.append(node)

        try self.ensureEngineRunning()
        node.scheduleBuffer(buffer, at: nil, options: []) { [weak self, weak node] in
          guard let self = self, let node = node else { return }
          self.queue.async {
            node.stop()
            self.engine.detach(node)
            self.activeNodes.removeAll { $0 === node }
          }
        }
        node.play()

        DispatchQueue.main.async {
          result(nil)
        }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "play_failed",
              message: "\(error)",
              details: nil
            )
          )
        }
      }
    }
  }

  private func stopAll() {
    queue.async { [weak self] in
      guard let self = self else { return }
      let nodes = self.activeNodes
      self.activeNodes.removeAll()
      self.fadeOutAndDetach(nodes: nodes)
    }
  }

  private func dispose() {
    queue.async { [weak self] in
      guard let self = self else { return }
      let nodes = self.activeNodes
      self.activeNodes.removeAll()
      self.fadeOutAndDetach(nodes: nodes)
      self.buffersByKey.removeAll()
      self.prepared = false
    }
  }

  private func fadeOutAndDetach(nodes: [AVAudioPlayerNode]) {
    guard !nodes.isEmpty else { return }
    let steps = 6
    let intervalMs = 8
    for step in 1...steps {
      queue.asyncAfter(deadline: .now() + .milliseconds(step * intervalMs)) { [weak self] in
        guard let self = self else { return }
        let scale = max(0, Float(steps - step) / Float(steps))
        for node in nodes {
          node.volume = node.volume * scale
        }
        if step == steps {
          for node in nodes {
            node.stop()
            self.engine.detach(node)
          }
        }
      }
    }
  }

  private func configureSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try session.setActive(true)
  }

  private func ensureEngineRunning() throws {
    if !engine.isRunning {
      try engine.start()
    }
  }

  private func resolveFlutterAsset(_ asset: String) -> URL? {
    let lookupKey = FlutterDartProject.lookupKey(forAsset: asset)
    if let url = Bundle.main.url(forResource: lookupKey, withExtension: nil) {
      return url
    }
    if let path = Bundle.main.path(forResource: lookupKey, ofType: nil) {
      return URL(fileURLWithPath: path)
    }
    if let url = Bundle.main.url(forResource: "flutter_assets/\(asset)", withExtension: nil) {
      return url
    }
    if let url = Bundle.main.url(forResource: asset, withExtension: nil) {
      return url
    }
    return nil
  }

  private func decodeAsset(url: URL) throws -> AVAudioPCMBuffer {
    let file = try AVAudioFile(forReading: url)
    let frameCount = AVAudioFrameCount(file.length)
    guard let buffer = AVAudioPCMBuffer(
      pcmFormat: file.processingFormat,
      frameCapacity: frameCount
    ) else {
      throw LowLatencyNoteAudioError.decodeFailed(url.lastPathComponent)
    }
    try file.read(into: buffer)
    return buffer
  }
}

private enum LowLatencyNoteAudioError: Error, CustomStringConvertible {
  case assetNotFound(String)
  case decodeFailed(String)
  case bufferNotPrepared(String)

  var description: String {
    switch self {
    case .assetNotFound(let asset):
      return "Asset not found: \(asset)"
    case .decodeFailed(let asset):
      return "Failed to decode asset: \(asset)"
    case .bufferNotPrepared(let key):
      return "Buffer not prepared for key: \(key)"
    }
  }
}
