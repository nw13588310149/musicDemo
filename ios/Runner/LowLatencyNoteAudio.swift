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
  private var voices: [VoiceNode] = []
  private var prepared = false
  private var engineNeedsReset = true
  private var fadeGeneration = 0
  private var sessionObservers: [NSObjectProtocol] = []

  private let maxPoolSize = 24
  private let fadeOutSteps = 14
  private let fadeOutStepMs = 10
  private let stealFadeSteps = 5
  private let baseNoteGain: Float = 0.38
  private let masterOutputLevel: Float = 0.88
  private let softAttackMs: Double = 2.5
  private var pendingEngineReset = false

  /// 常驻发声节点：一旦 attach + connect 到 mixer 就保持连接，
  /// 播放结束只 stop + 标记空闲，不再 detach/重连，避免修改运行中的引擎图
  /// 造成的「关闭爆音」。
  private final class VoiceNode {
    let player = AVAudioPlayerNode()
    var connectedFormat: AVAudioFormat?
    var busy = false
    var isMetronome = false
  }

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
      let metronome = (args["metronome"] as? NSNumber)?.boolValue ?? false
      play(key: key, volume: volume, metronome: metronome, result: result)
    case "reclaimEngine":
      reclaimEngine(result: result)
    case "stopMetronome":
      stopMetronomePlaybacks()
      result(nil)
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
    sessionObservers = [
      center.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: nil,
        queue: nil,
        using: { [weak self] notification in
          guard let userInfo = notification.userInfo,
                let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: rawType),
                type == .began
          else {
            return
          }
          self?.markEngineNeedsReset()
        }
      ),
      center.addObserver(
        forName: AVAudioSession.mediaServicesWereResetNotification,
        object: nil,
        queue: nil,
        using: { [weak self] _ in
          self?.markEngineNeedsReset()
        }
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
      self.tryApplyEngineResetIfNeeded()
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
        try? self.startEngineIfNeeded()
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

  private func play(
    key: String,
    volume: Float,
    metronome: Bool,
    result: @escaping FlutterResult
  ) {
    queue.async { [weak self] in
      guard let self = self else { return }
      var acquiredVoice: VoiceNode?
      do {
        guard let buffer = self.buffersByKey[key] else {
          throw LowLatencyNoteAudioError.bufferNotPrepared(key)
        }
        guard let playbackBuffer = self.copyBuffer(buffer, softAttack: !metronome) else {
          throw LowLatencyNoteAudioError.decodeFailed(key)
        }

        self.tryApplyEngineResetIfNeeded()

        // 先建好图（attach + connect）再启动引擎，避免在空图上 prepare/start。
        guard let voice = try self.borrowVoice(format: playbackBuffer.format) else {
          DispatchQueue.main.async { result(nil) }
          return
        }
        acquiredVoice = voice
        voice.isMetronome = metronome
        voice.player.volume = self.scaledVolume(requested: volume)

        try self.startEngineIfNeeded()

        do {
          try LowLatencyNoteAudioSafePlay.scheduleBuffer(
            playbackBuffer,
            on: voice.player,
            playedBackHandler: { [weak self, weak voice] in
              guard let self = self, let voice = voice else { return }
              // dataPlayedBack：音频已真正播放完毕，此时 stop 不会截断尾音，
              // 也不 detach（保持连接），下次直接复用，无图变更爆音。
              self.queue.async {
                self.releaseVoice(voice)
              }
            }
          )
        } catch {
          voice.player.stop()
          voice.busy = false
          throw LowLatencyNoteAudioError.playRejected(
            (error as NSError).localizedDescription
          )
        }

        do {
          try LowLatencyNoteAudioSafePlay.play(voice.player)
        } catch {
          voice.player.stop()
          voice.busy = false
          throw LowLatencyNoteAudioError.playRejected(
            (error as NSError).localizedDescription
          )
        }

        DispatchQueue.main.async {
          result(nil)
        }
      } catch {
        if let voice = acquiredVoice {
          voice.busy = false
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

  private func stopMetronomePlaybacks() {
    queue.async { [weak self] in
      guard let self = self else { return }
      let targets = self.voices.filter {
        $0.isMetronome && ($0.busy || $0.player.isPlaying)
      }
      self.fadeOutVoices(targets, steps: 6, stepMs: 6)
    }
  }

  private func stopAll() {
    queue.async { [weak self] in
      guard let self = self else { return }
      let targets = self.voices.filter { $0.busy || $0.player.isPlaying }
      self.fadeOutVoices(targets, steps: fadeOutSteps, stepMs: fadeOutStepMs)
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
    for voice in voices {
      voice.player.stop()
      if engine.attachedNodes.contains(voice.player) {
        engine.disconnectNodeOutput(voice.player)
        engine.detach(voice.player)
      }
    }
    voices.removeAll()

    if engine.isRunning {
      engine.stop()
    }
    engine.reset()
    engineNeedsReset = false
    pendingEngineReset = false
  }

  private func markEngineNeedsResetOnFailure() {
    engineNeedsReset = true
    if engine.isRunning {
      engine.stop()
    }
  }

  private func startEngineIfNeeded() throws {
    if !engine.isRunning {
      // prepare()/start() 在图/会话非法时会抛 NSException，必须经 ObjC 捕获，
      // 否则 Swift 捕不到会直接 abort 整个进程。
      try LowLatencyNoteAudioSafePlay.prepareAndStartEngine(engine)
    }
    engine.mainMixerNode.outputVolume = masterOutputLevel
    engineNeedsReset = false
    pendingEngineReset = false
  }

  private func activeVoiceCount() -> Int {
    voices.filter { $0.busy || $0.player.isPlaying }.count
  }

  private func scaledVolume(requested: Float) -> Float {
    let headroom = 0.9 / sqrt(Float(max(1, activeVoiceCount() + 1)))
    return max(0, min(1, requested * baseNoteGain * headroom))
  }

  private func releaseVoice(_ voice: VoiceNode) {
    if voice.player.isPlaying {
      voice.player.stop()
    }
    voice.player.reset()
    voice.player.volume = 1
    voice.busy = false
    voice.isMetronome = false
    tryApplyEngineResetIfNeeded()
  }

  private func tryApplyEngineResetIfNeeded() {
    guard engineNeedsReset || pendingEngineReset else { return }
    if activeVoiceCount() > 0 {
      pendingEngineReset = true
      return
    }
    hardResetEngine()
    pendingEngineReset = false
    engineNeedsReset = false
  }

  /// 取发声节点：优先空闲复用；池满时对旧钢琴声部极短淡出后复用。
  private func borrowVoice(format: AVAudioFormat) throws -> VoiceNode? {
    for voice in voices where !voice.busy && !voice.player.isPlaying {
      try prepareVoiceForSchedule(voice, format: format)
      voice.busy = true
      return voice
    }

    if voices.count < maxPoolSize {
      let voice = VoiceNode()
      try LowLatencyNoteAudioSafePlay.attachNode(voice.player, toEngine: engine)
      voices.append(voice)
      do {
        try prepareVoiceForSchedule(voice, format: format)
      } catch {
        voices.removeAll { $0 === voice }
        if engine.attachedNodes.contains(voice.player) {
          engine.detach(voice.player)
        }
        throw error
      }
      voice.busy = true
      return voice
    }

    guard let stolen = pickVoiceToSteal() else { return nil }
    softStealVoice(stolen)
    try prepareVoiceForSchedule(stolen, format: format)
    stolen.busy = true
    return stolen
  }

  private func prepareVoiceForSchedule(_ voice: VoiceNode, format: AVAudioFormat) throws {
    if voice.player.isPlaying {
      voice.player.stop()
    }
    voice.player.reset()
    voice.player.volume = 1
    try ensureConnected(voice, format: format)
  }

  private func pickVoiceToSteal() -> VoiceNode? {
    if let piano = voices.first(where: { ($0.busy || $0.player.isPlaying) && !$0.isMetronome }) {
      return piano
    }
    return voices.first(where: { $0.busy || $0.player.isPlaying })
  }

  private func softStealVoice(_ voice: VoiceNode) {
    let startVol = max(0, min(voice.player.volume, 1))
    for step in 1...stealFadeSteps {
      let scale = Float(stealFadeSteps - step) / Float(stealFadeSteps)
      voice.player.volume = startVol * scale
    }
    voice.player.stop()
    voice.player.reset()
    voice.player.volume = 1
    voice.busy = false
    voice.isMetronome = false
  }

  /// 仅在节点尚未连接或格式变化时才 connect，避免对运行中的图做无谓重连。
  private func ensureConnected(_ voice: VoiceNode, format: AVAudioFormat) throws {
    if let current = voice.connectedFormat, current.isEqual(format) {
      return
    }
    try LowLatencyNoteAudioSafePlay.connectNode(
      voice.player,
      toNode: engine.mainMixerNode,
      format: format,
      inEngine: engine
    )
    voice.connectedFormat = format
  }

  /// 平滑淡出并 stop（保持 attach/connect 以便复用），避免硬停爆音。
  private func fadeOutVoices(
    _ targets: [VoiceNode],
    steps: Int = 12,
    stepMs: Int = 8
  ) {
    guard !targets.isEmpty else { return }
    let generation = fadeGeneration
    let intervalMs = stepMs
    let baseVolumes = targets.map { max(0, min($0.player.volume, 1)) }
    for step in 1...steps {
      queue.asyncAfter(deadline: .now() + .milliseconds(step * intervalMs)) { [weak self] in
        guard let self = self, generation == self.fadeGeneration else { return }
        let scale = max(0, Float(steps - step) / Float(steps))
        for (index, voice) in targets.enumerated() {
          voice.player.volume = baseVolumes[index] * scale
        }
        if step == steps {
          for voice in targets {
            self.releaseVoice(voice)
          }
        }
      }
    }
  }

  /// AVAudioPCMBuffer 在 completion 前不可复用；缓存区供多次 schedule 会闪退。
  private func copyBuffer(
    _ source: AVAudioPCMBuffer,
    softAttack: Bool = true
  ) -> AVAudioPCMBuffer? {
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
      if softAttack {
        applySoftAttack(to: copy)
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
      if softAttack {
        applySoftAttackInt16(to: copy)
      }
      return copy
    }

    return nil
  }

  private func applySoftAttack(to buffer: AVAudioPCMBuffer) {
    guard let channels = buffer.floatChannelData else { return }
    let sampleRate = buffer.format.sampleRate
    let attackFrames = min(
      Int(buffer.frameLength),
      max(1, Int(softAttackMs * 0.001 * sampleRate))
    )
    for channel in 0..<Int(buffer.format.channelCount) {
      let samples = channels[channel]
      for frame in 0..<attackFrames {
        let ramp = Float(frame + 1) / Float(attackFrames)
        samples[frame] *= ramp
      }
    }
  }

  private func applySoftAttackInt16(to buffer: AVAudioPCMBuffer) {
    guard let channels = buffer.int16ChannelData else { return }
    let sampleRate = buffer.format.sampleRate
    let attackFrames = min(
      Int(buffer.frameLength),
      max(1, Int(softAttackMs * 0.001 * sampleRate))
    )
    for channel in 0..<Int(buffer.format.channelCount) {
      let samples = channels[channel]
      for frame in 0..<attackFrames {
        let ramp = Float(frame + 1) / Float(attackFrames)
        let scaled = Float(samples[frame]) * ramp
        samples[frame] = Int16(max(-32768, min(32767, scaled)))
      }
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
