import AVFoundation
import Flutter
import UIKit

/// Low-latency short-note playback for iPad piano / dictation / smart sight singing.
///
/// Long audio stays in media_kit. Session category is owned by Dart
/// [NativePlaybackAudioSession]; this class resets the engine when the session
/// changes (playAndRecord ↔ playback) so AVAudioPlayerNode.play() does not abort.
final class LowLatencyNoteAudio {
  private let channel: FlutterMethodChannel
  private let engine = AVAudioEngine()
  private let queue = DispatchQueue(label: "com.yyzl.music.lowLatencyNotes")
  private var buffersByKey: [String: AVAudioPCMBuffer] = [:]
  private var activeNodes: [AVAudioPlayerNode] = []
  private var playerNodePool: [AVAudioPlayerNode] = []
  private var prepared = false
  private var engineNeedsReset = true
  private var fadeGeneration = 0
  private var sessionObservers: [NSObjectProtocol] = []

  private let maxPoolSize = 8

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.yyzl.music/low_latency_notes",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    registerSessionObservers()
  }

  deinit {
    unregisterSessionObservers()
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
    case "reclaimEngine":
      reclaimEngine(result: result)
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

  private func registerSessionObservers() {
    let center = NotificationCenter.default
    let handler: (Notification) -> Void = { [weak self] _ in
      self?.markEngineNeedsReset()
    }
    sessionObservers = [
      center.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: nil,
        queue: nil,
        using: handler
      ),
      center.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: nil,
        queue: nil,
        using: handler
      ),
      center.addObserver(
        forName: AVAudioSession.mediaServicesWereResetNotification,
        object: nil,
        queue: nil,
        using: handler
      ),
    ]
  }

  private func unregisterSessionObservers() {
    let center = NotificationCenter.default
    for token in sessionObservers {
      center.removeObserver(token)
    }
    sessionObservers.removeAll()
  }

  private func markEngineNeedsReset() {
    queue.async { [weak self] in
      self?.engineNeedsReset = true
    }
  }

  private func reclaimEngine(result: @escaping FlutterResult) {
    queue.async { [weak self] in
      guard let self = self else { return }
      self.hardResetEngine()
      DispatchQueue.main.async {
        result(nil)
      }
    }
  }

  private func prepare(assets: [String: String], result: @escaping FlutterResult) {
    queue.async { [weak self] in
      guard let self = self else { return }
      do {
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
      var borrowedNode: AVAudioPlayerNode?
      do {
        guard let buffer = self.buffersByKey[key] else {
          throw LowLatencyNoteAudioError.bufferNotPrepared(key)
        }
        guard let playbackBuffer = self.copyBuffer(buffer) else {
          throw LowLatencyNoteAudioError.decodeFailed(key)
        }

        if self.engineNeedsReset {
          self.hardResetEngine()
        }

        let node = self.borrowPlayerNode()
        borrowedNode = node
        node.volume = max(0, min(volume, 1))

        try self.attachAndStartIfNeeded(node: node)
        self.activeNodes.append(node)

        node.scheduleBuffer(playbackBuffer, at: nil, options: []) { [weak self, weak node] in
          guard let self = self, let node = node else { return }
          self.queue.async {
            self.activeNodes.removeAll { $0 === node }
            self.returnPlayerNode(node)
          }
        }

        do {
          try LowLatencyNoteAudioSafePlay.playNode(node)
        } catch {
          self.activeNodes.removeAll { $0 === node }
          self.returnPlayerNode(node)
          throw LowLatencyNoteAudioError.playRejected(
            (error as NSError).localizedDescription
          )
        }

        DispatchQueue.main.async {
          result(nil)
        }
      } catch {
        if let node = borrowedNode {
          self.activeNodes.removeAll { $0 === node }
          self.returnPlayerNode(node)
        }
        self.markEngineNeedsResetOnFailure()
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
      self.hardResetEngine()
      self.buffersByKey.removeAll()
      self.prepared = false
    }
  }

  private func hardResetEngine() {
    fadeGeneration += 1
    let nodes = activeNodes
    activeNodes.removeAll()
    for node in nodes {
      node.stop()
      detachIfAttached(node)
    }
    for node in playerNodePool {
      node.stop()
      detachIfAttached(node)
    }
    playerNodePool.removeAll()

    if engine.isRunning {
      engine.stop()
    }
    engine.reset()
    engineNeedsReset = true
  }

  private func markEngineNeedsResetOnFailure() {
    engineNeedsReset = true
    if engine.isRunning {
      engine.stop()
    }
  }

  private func borrowPlayerNode() -> AVAudioPlayerNode {
    while let node = playerNodePool.popLast() {
      if !node.isPlaying {
        return node
      }
      node.stop()
      detachIfAttached(node)
    }
    return AVAudioPlayerNode()
  }

  private func returnPlayerNode(_ node: AVAudioPlayerNode) {
    node.stop()
    detachIfAttached(node)
    guard playerNodePool.count < maxPoolSize else { return }
    playerNodePool.append(node)
  }

  private func detachIfAttached(_ node: AVAudioPlayerNode) {
    if engine.attachedNodes.contains(node) {
      engine.disconnectNodeOutput(node)
      engine.detach(node)
    }
  }

  private func attachAndStartIfNeeded(node: AVAudioPlayerNode) throws {
    if engine.isRunning {
      engine.pause()
    }

    if !engine.attachedNodes.contains(node) {
      engine.attach(node)
    }
    engine.connect(node, to: engine.mainMixerNode, format: nil)

    engine.prepare()
    try engine.start()
    engineNeedsReset = false
  }

  private func fadeOutAndDetach(nodes: [AVAudioPlayerNode]) {
    guard !nodes.isEmpty else { return }
    let generation = fadeGeneration
    let steps = 6
    let intervalMs = 8
    for step in 1...steps {
      queue.asyncAfter(deadline: .now() + .milliseconds(step * intervalMs)) { [weak self] in
        guard let self = self, generation == self.fadeGeneration else { return }
        let scale = max(0, Float(steps - step) / Float(steps))
        for node in nodes {
          node.volume = node.volume * scale
        }
        if step == steps {
          for node in nodes {
            node.stop()
            self.detachIfAttached(node)
            if self.playerNodePool.count < self.maxPoolSize {
              self.playerNodePool.append(node)
            }
          }
        }
      }
    }
  }

  /// AVAudioPCMBuffer 在 completion 前不可复用；缓存区供多次 schedule 会闪退。
  private func copyBuffer(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard
      let copy = AVAudioPCMBuffer(
        pcmFormat: source.format,
        frameCapacity: source.frameLength
      )
    else {
      return nil
    }
    copy.frameLength = source.frameLength

    if
      let src = source.floatChannelData,
      let dst = copy.floatChannelData
    {
      let channels = Int(source.format.channelCount)
      let frames = Int(source.frameLength)
      let byteCount = frames * MemoryLayout<Float>.size
      for channel in 0..<channels {
        memcpy(dst[channel], src[channel], byteCount)
      }
      return copy
    }

    if
      let src = source.int16ChannelData,
      let dst = copy.int16ChannelData
    {
      let channels = Int(source.format.channelCount)
      let frames = Int(source.frameLength)
      let byteCount = frames * MemoryLayout<Int16>.size
      for channel in 0..<channels {
        memcpy(dst[channel], src[channel], byteCount)
      }
      return copy
    }

    return nil
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
  case playRejected(String)

  var description: String {
    switch self {
    case .assetNotFound(let asset):
      return "Asset not found: \(asset)"
    case .decodeFailed(let asset):
      return "Failed to decode asset: \(asset)"
    case .bufferNotPrepared(let key):
      return "Buffer not prepared for key: \(key)"
    case .playRejected(let reason):
      return "Play rejected: \(reason)"
    }
  }
}
