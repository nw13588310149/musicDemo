import AVFoundation
import Flutter
import UIKit

/// 低延迟短音播放（iPad 虚拟钢琴 / 听写 / 智能视唱伴奏）。
///
/// 架构：固定声部池 + 静态音频图。
/// - `prepare` 时一次性建好 N 个常驻 `AVAudioPlayerNode`，全部 attach + connect 到主混音器，
///   并让每个节点进入「playing-idle」状态。
/// - 播放一个音 = 在某个空闲节点上 `scheduleBuffer`，**不** attach/detach/connect，**不** start/stop 引擎。
/// - 音自然播完 = 仅把节点标记为空闲，**绝不** `stop()`/`reset()`/`detach`，因此输出端不会有图变更咔哒。
/// - 仅在「会话中断 / mediaServicesReset / playAndRecord↔playback 切换」且当前无发声时才重建图。
///
/// 长音频仍走 media_kit；AVAudioSession 类别由 Dart [NativePlaybackAudioSession] 拥有。
final class LowLatencyNoteAudio {
  private let channel: FlutterMethodChannel
  private let engine = AVAudioEngine()
  private let queue = DispatchQueue(label: "com.yyzl.music.lowLatencyNotes")
  private let decodeQueue = DispatchQueue(
    label: "com.yyzl.music.lowLatencyNotes.decode",
    qos: .utility
  )

  private var assetByKey: [String: String] = [:]
  private var buffersByKey: [String: AVAudioPCMBuffer] = [:]
  private var voices: [Voice] = []
  private var prepared = false
  private var graphBuilt = false
  /// 仅在 `mediaServicesWereReset`（CoreAudio 整体重启、所有节点/引擎失效）时置位。
  /// 普通的会话类别切换 / 路由变化**不**走整图重建，只重启引擎。
  private var engineNeedsReset = false
  /// 会话脏标记：中断 / 路由变化 / 类别切换后置 false，下一次渲染前重新
  /// `setCategory + setActive`。稳定后保持 true，使每个音符的 `play()` 不再
  /// 反复进 AVAudioSession 平台往返（这是单音延迟的主要来源之一）。
  private var shortAudioSessionReady = false
  private var sessionObservers: [NSObjectProtocol] = []
  private var playSequence: UInt64 = 0
  private var fadeGeneration = 0
  /// 会话切换 / stopAll 时递增；早于此次序号的 `play` 任务直接丢弃，避免排队迟播。
  private var operationGeneration: UInt64 = 0

  /// 声部池大小：钢琴十指 + 延音绰绰有余，超出才会触发偷取。
  private let poolSize = 24

  /// 主混音输出电平；响度交由系统音量键，软件层不做衰减。
  private let masterOutputLevel: Float = 1.0

  /// 采样尾部淡出时长，确保 buffer 末尾归零，消除「播完瞬间」的爆音/电流声。
  private let tailFadeMs: Double = 5.0

  /// 起音淡入时长，消除采样起点非零造成的咔哒（极短，不影响触感）。
  private let attackFadeMs: Double = 1.0

  /// 所有采样统一为该格式，保证整条图 connect 格式恒定，运行期不改格式。
  private let standardFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: 44100,
    channels: 2,
    interleaved: false
  )!

  /// 常驻发声节点。
  private final class Voice {
    let player = AVAudioPlayerNode()
    var busy = false
    var isMetronome = false
    var sequence: UInt64 = 0
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

  // MARK: - Flutter channel

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
      let waitUntilFinished = (args["waitUntilFinished"] as? NSNumber)?.boolValue ?? false
      play(
        key: key,
        volume: volume,
        metronome: metronome,
        waitUntilFinished: waitUntilFinished,
        result: result
      )
    case "reclaimEngine":
      reclaimEngine(result: result)
    case "stopMetronome":
      queue.async { [weak self] in self?.stopVoices(metronomeOnly: true, fadeMs: 35) }
      result(nil)
    case "stopAll":
      queue.async { [weak self] in
        guard let self = self else { return }
        self.operationGeneration &+= 1
        self.stopVoices(metronomeOnly: false, fadeMs: 90)
      }
      result(nil)
    case "dispose":
      queue.async { [weak self] in self?.teardown() }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Session observers

  private func registerSessionObservers() {
    let center = NotificationCenter.default
    sessionObservers = [
      center.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: nil,
        queue: nil,
        using: { [weak self] notification in
          guard
            let userInfo = notification.userInfo,
            let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType),
            type == .began
          else { return }
          // 系统会在中断开始时停掉引擎；不重建整图，下一次渲染前 lazy 重启即可。
          self?.markSessionDirty()
        }
      ),
      center.addObserver(
        forName: AVAudioSession.mediaServicesWereResetNotification,
        object: nil,
        queue: nil,
        using: { [weak self] _ in self?.markEngineNeedsReset() }
      ),
      center.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: nil,
        queue: nil,
        // 路由变化（插拔耳机 / 蓝牙）只需重启引擎并续接常驻节点，
        // 我们的 player→mainMixer 连接用固定 standardFormat，无需断开重连。
        using: { [weak self] _ in self?.markSessionDirty(restart: true) }
      ),
      center.addObserver(
        forName: .AVAudioEngineConfigurationChange,
        object: engine,
        queue: nil,
        // 引擎级配置变化（设备 / 采样率切换）后，AVAudioEngine 会停止。
        // 仅重启 + 续接节点，整图重建留给 mediaServicesWereReset。
        using: { [weak self] _ in self?.markSessionDirty(restart: true) }
      ),
    ]
  }

  private func unregisterSessionObservers() {
    let center = NotificationCenter.default
    for token in sessionObservers { center.removeObserver(token) }
    sessionObservers.removeAll()
  }

  /// CoreAudio 整体重启：所有节点 / 引擎失效，须整图重建。
  private func markEngineNeedsReset() {
    queue.async { [weak self] in
      guard let self = self else { return }
      self.engineNeedsReset = true
      self.shortAudioSessionReady = false
    }
  }

  /// 会话被打断 / 路由变化：标记会话脏；可选地在当前无发声时立即重启引擎，
  /// 避免下一次按键才恢复造成的迟播。
  private func markSessionDirty(restart: Bool = false) {
    queue.async { [weak self] in
      guard let self = self else { return }
      self.shortAudioSessionReady = false
      guard restart, self.prepared, self.graphBuilt else { return }
      do {
        try self.startEngineAndResumeNodes()
      } catch {
        debugPrint("LowLatencyNoteAudio restart after route/config change failed: \(error)")
      }
    }
  }

  /// Dart 在 AVAudioSession 类别切换后调用：会话变化不会发系统通知，
  /// 因此这里强制标记需要重建——会话切换会改硬件 IO 格式，必须重连图，
  /// 否则 player 在新会话下静默或 scheduleBuffer 失败（智能视唱试听/跟唱切换）。
  private func reclaimEngine(result: @escaping FlutterResult) {
    queue.async { [weak self] in
      guard let self = self else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      self.operationGeneration &+= 1
      self.fadeGeneration &+= 1
      self.forceStopAllVoicesImmediate()
      // 会话类别在 Dart 侧已切换。轻量重连：刷新会话 + 重启引擎并续接常驻节点，
      // **不**逐节点 detach/reset 整图（那是 musicPlay / 音乐伴侣首音慢的主因）。
      // 仅当轻量路径抛错（极少数图损坏）才回退到整图重建。
      self.shortAudioSessionReady = false
      do {
        try self.ensureSessionCanRenderShortAudio()
        if self.prepared {
          try self.ensureGraphReady()
        }
      } catch {
        debugPrint("LowLatencyNoteAudio reclaim light path failed, rebuilding: \(error)")
        self.rebuildGraph()
        if self.prepared {
          try? self.buildGraph()
        }
      }
      DispatchQueue.main.async { result(nil) }
    }
  }

  /// 立即静音所有声部（无淡出），用于会话 handoff / reclaim。
  private func forceStopAllVoicesImmediate() {
    for voice in voices {
      if voice.player.isPlaying {
        voice.player.stop()
      }
      voice.player.volume = 1
      voice.busy = false
      voice.isMetronome = false
      if graphBuilt, engine.isRunning {
        try? LowLatencyNoteAudioSafePlay.play(voice.player)
      }
    }
  }

  // MARK: - Prepare / decode

  private func prepare(assets: [String: String], result: @escaping FlutterResult) {
    queue.async { [weak self] in
      guard let self = self else { return }
      do {
        var registered = 0
        var decodeBatch: [(String, String)] = []
        for (key, asset) in assets {
          guard self.resolveFlutterAsset(asset) != nil else {
            throw LowLatencyNoteAudioError.assetNotFound(asset)
          }
          self.assetByKey[key] = asset
          registered += 1
          if self.buffersByKey[key] == nil {
            decodeBatch.append((key, asset))
          }
        }
        self.prepared = true
        try self.ensureGraphReady()
        self.scheduleBackgroundDecode(decodeBatch)
        DispatchQueue.main.async { result(["loaded": registered]) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "prepare_failed", message: "\(error)", details: nil))
        }
      }
    }
  }

  private func scheduleBackgroundDecode(_ batch: [(String, String)]) {
    guard !batch.isEmpty else { return }
    for (key, asset) in batch {
      decodeQueue.async { [weak self] in
        guard let self = self else { return }
        do {
          guard let url = self.resolveFlutterAsset(asset) else { return }
          let buffer = try self.decodeAsset(url: url)
          self.queue.async { [weak self] in
            guard let self = self else { return }
            guard self.assetByKey[key] == asset else { return }
            if self.buffersByKey[key] == nil {
              self.buffersByKey[key] = buffer
            }
          }
        } catch {
          debugPrint("LowLatencyNoteAudio background decode failed for \(key): \(error)")
        }
      }
    }
  }

  // MARK: - Play

  private func play(
    key: String,
    volume: Float,
    metronome: Bool,
    waitUntilFinished: Bool,
    result: @escaping FlutterResult
  ) {
    queue.async { [weak self] in
      guard let self = self else { return }
      let generation = self.operationGeneration
      do {
        try self.ensureSessionCanRenderShortAudio()
        let source = try self.bufferForPlayback(key: key)
        guard let buffer = self.copyBufferWithEnvelope(source) else {
          throw LowLatencyNoteAudioError.decodeFailed(key)
        }

        try self.ensureGraphReady()
        guard generation == self.operationGeneration else {
          DispatchQueue.main.async { result(nil) }
          return
        }

        let voice = self.acquireVoice()
        voice.busy = true
        voice.isMetronome = metronome
        self.playSequence &+= 1
        let seq = self.playSequence
        voice.sequence = seq
        voice.player.volume = max(0, min(1, volume))

        // 听写 waitUntilFinished 须在播完后才回 Dart，但不能 semaphore.wait 占住串行队列，
        // 否则 musicPlay 钢琴 tryPlay 会排队数秒才响。
        var waitReplySent = false
        let sendWaitReply: () -> Void = {
          if waitReplySent { return }
          waitReplySent = true
          guard generation == self.operationGeneration else {
            DispatchQueue.main.async { result(nil) }
            return
          }
          DispatchQueue.main.async { result(nil) }
        }

        try LowLatencyNoteAudioSafePlay.scheduleBuffer(
          buffer,
          on: voice.player,
          playedBackHandler: { [weak self, weak voice] in
            // 数据真正播完后回调：只标记空闲，不 stop/不改图 → 无尾音爆音。
            self?.queue.async {
              guard let voice = voice, voice.sequence == seq else { return }
              voice.busy = false
              if waitUntilFinished {
                sendWaitReply()
              }
            }
          }
        )

        if !voice.player.isPlaying {
          try LowLatencyNoteAudioSafePlay.play(voice.player)
        }

        // 兜底：若 playedBack 回调未触发（极少数情况），按采样时长 + 余量释放 busy，
        // 避免 busy 卡死导致 activeVoiceCount 永不归零、引擎无法在会话切换后重建。
        let durationMs = max(
          400,
          Int(Double(buffer.frameLength) / buffer.format.sampleRate * 1000) + 200
        )
        self.queue.asyncAfter(deadline: .now() + .milliseconds(durationMs)) {
          [weak voice] in
          guard let voice = voice, voice.sequence == seq, voice.busy else { return }
          voice.busy = false
          if waitUntilFinished {
            sendWaitReply()
          }
        }

        guard generation == self.operationGeneration else {
          DispatchQueue.main.async { result(nil) }
          return
        }
        if !waitUntilFinished {
          DispatchQueue.main.async { result(nil) }
        }
      } catch {
        self.engineNeedsReset = true
        guard generation == self.operationGeneration else {
          DispatchQueue.main.async { result(nil) }
          return
        }
        DispatchQueue.main.async {
          result(FlutterError(code: "play_failed", message: "\(error)", details: nil))
        }
      }
    }
  }

  private func bufferForPlayback(key: String) throws -> AVAudioPCMBuffer {
    if let cached = buffersByKey[key] {
      return cached
    }
    guard let asset = assetByKey[key] else {
      throw LowLatencyNoteAudioError.bufferNotPrepared(key)
    }
    guard let url = resolveFlutterAsset(asset) else {
      throw LowLatencyNoteAudioError.assetNotFound(asset)
    }
    let buffer = try decodeAsset(url: url)
    buffersByKey[key] = buffer
    return buffer
  }

  /// 取一个发声节点：优先空闲；全忙时偷取序号最旧的非节拍器声部（极罕见）。
  private func acquireVoice() -> Voice {
    if let free = voices.first(where: { !$0.busy }) {
      return free
    }
    let victim =
      voices.min(by: { $0.sequence < $1.sequence }) ?? voices[0]
    // 偷取前先 stop 旧缓冲（仅在 >poolSize 个音同时发声时发生）。
    victim.player.stop()
    victim.busy = false
    return victim
  }

  // MARK: - Stop（淡出，绝不硬停）

  private func stopVoices(metronomeOnly: Bool, fadeMs: Int) {
    // 只淡出真正在播 buffer 的 busy 节点；其余 playing-idle 节点不动。
    let targets = voices.filter {
      $0.busy && (!metronomeOnly || $0.isMetronome)
    }
    guard !targets.isEmpty else { return }

    fadeGeneration += 1
    let generation = fadeGeneration
    let steps = 12
    let stepMs = max(1, fadeMs / steps)
    let baseVolumes = targets.map { max(0, min($0.player.volume, 1)) }

    for step in 1...steps {
      queue.asyncAfter(deadline: .now() + .milliseconds(step * stepMs)) { [weak self] in
        guard let self = self, generation == self.fadeGeneration else { return }
        let scale = max(0, Float(steps - step) / Float(steps))
        for (index, voice) in targets.enumerated() {
          voice.player.volume = baseVolumes[index] * scale
        }
        guard step == steps else { return }
        // 音量已降到 0，此时 stop 不会有可闻咔哒；随后恢复到 playing-idle 以便复用。
        for voice in targets {
          voice.player.stop()
          voice.player.volume = 1
          voice.busy = false
          voice.isMetronome = false
          if self.graphBuilt, self.engine.isRunning {
            try? LowLatencyNoteAudioSafePlay.play(voice.player)
          }
        }
        self.applyPendingResetIfIdle()
      }
    }
  }

  // MARK: - 静态音频图：构建 / 重建

  private func ensureGraphReady() throws {
    if engineNeedsReset && activeVoiceCount() == 0 {
      rebuildGraph()
    }
    if !graphBuilt {
      try buildGraph()
      return
    }
    if !engine.isRunning {
      try startEngineAndResumeNodes()
    }
  }

  private func buildGraph() throws {
    try ensureSessionCanRenderShortAudio()
    detachAllVoices()
    voices.removeAll()

    let mixer = engine.mainMixerNode
    for _ in 0..<poolSize {
      let voice = Voice()
      try LowLatencyNoteAudioSafePlay.attachNode(voice.player, toEngine: engine)
      try LowLatencyNoteAudioSafePlay.connectNode(
        voice.player,
        toNode: mixer,
        format: standardFormat,
        inEngine: engine
      )
      voices.append(voice)
    }

    try LowLatencyNoteAudioSafePlay.prepareAndStartEngine(engine)
    engine.mainMixerNode.outputVolume = masterOutputLevel

    for voice in voices {
      try? LowLatencyNoteAudioSafePlay.play(voice.player)
    }

    graphBuilt = true
    engineNeedsReset = false
  }

  private func startEngineAndResumeNodes() throws {
    try ensureSessionCanRenderShortAudio()
    try LowLatencyNoteAudioSafePlay.prepareAndStartEngine(engine)
    engine.mainMixerNode.outputVolume = masterOutputLevel
    for voice in voices where !voice.player.isPlaying {
      try? LowLatencyNoteAudioSafePlay.play(voice.player)
    }
    engineNeedsReset = false
  }

  private func rebuildGraph() {
    fadeGeneration += 1
    detachAllVoices()
    voices.removeAll()
    if engine.isRunning { engine.stop() }
    engine.reset()
    graphBuilt = false
    engineNeedsReset = false
  }

  private func detachAllVoices() {
    for voice in voices {
      if voice.player.isPlaying { voice.player.stop() }
      if engine.attachedNodes.contains(voice.player) {
        engine.disconnectNodeOutput(voice.player)
        engine.detach(voice.player)
      }
    }
  }

  private func applyPendingResetIfIdle() {
    guard engineNeedsReset else { return }
    guard activeVoiceCount() == 0 else { return }
    rebuildGraph()
    try? buildGraph()
  }

  /// 真正在发声的音数量：固定池中所有节点常驻 playing-idle，
  /// 故 `player.isPlaying` 恒为 true 不可用于判断；只数显式 busy。
  private func activeVoiceCount() -> Int {
    voices.filter { $0.busy }.count
  }

  private func teardown() {
    fadeGeneration += 1
    detachAllVoices()
    voices.removeAll()
    if engine.isRunning { engine.stop() }
    engine.reset()
    assetByKey.removeAll()
    buffersByKey.removeAll()
    graphBuilt = false
    prepared = false
    engineNeedsReset = false
  }

  // MARK: - Buffer 处理

  /// 拷贝采样并加首尾极短淡入/淡出（保证归零，消除播放起止咔哒）。
  /// AVAudioPCMBuffer 在 completion 前不可复用，故每次播放独立拷贝。
  @discardableResult
  private func ensureSessionCanRenderShortAudio() throws -> Bool {
    let session = AVAudioSession.sharedInstance()
    let category = session.category

    // 快路径：会话已是可渲染短音的类别（playback / playAndRecord）且带 mixWithOthers，
    // 且我们已确认激活过——直接复用，避免每个音符都进 setCategory / setActive 平台往返。
    // 会话所有权归 Dart 侧 NativePlaybackAudioSession；这里只在它尚未配置或被
    // 中断 / 路由变化弄脏时兜底配置一次。
    let compatible =
      (category == .playback || category == .playAndRecord) &&
      session.categoryOptions.contains(.mixWithOthers)
    if shortAudioSessionReady && compatible {
      return false
    }

    let previousCategory = session.category
    let previousMode = session.mode
    let previousOptions = session.categoryOptions

    if category == .playAndRecord {
      var options: AVAudioSession.CategoryOptions = [
        .defaultToSpeaker,
        .allowBluetooth,
        .mixWithOthers,
      ]
      if #available(iOS 10.0, *) {
        options.insert(.allowBluetoothA2DP)
      }
      try session.setCategory(.playAndRecord, mode: session.mode, options: options)
    } else {
      var options: AVAudioSession.CategoryOptions = [
        .mixWithOthers,
        .defaultToSpeaker,
      ]
      if #available(iOS 10.0, *) {
        options.insert(.allowAirPlay)
      }
      try session.setCategory(.playback, mode: .default, options: options)
    }

    try? session.setPreferredSampleRate(44_100)
    try? session.setPreferredIOBufferDuration(0.005)
    try session.setActive(true)

    shortAudioSessionReady = true

    // 类别切换不强制整图重建：AVAudioEngine 只需重启（见 ensureGraphReady 中的
    // `!engine.isRunning` 分支），节点与 player→mixer 连接（固定 standardFormat）仍有效。
    let changed =
      previousCategory != session.category ||
      previousMode != session.mode ||
      previousOptions != session.categoryOptions
    return changed
  }

  private func copyBufferWithEnvelope(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard
      let copy = AVAudioPCMBuffer(
        pcmFormat: source.format,
        frameCapacity: source.frameLength
      ),
      let src = source.floatChannelData,
      let dst = copy.floatChannelData
    else {
      return nil
    }
    copy.frameLength = source.frameLength

    let channels = Int(source.format.channelCount)
    let frames = Int(source.frameLength)
    let byteCount = frames * MemoryLayout<Float>.size
    for channel in 0..<channels {
      memcpy(dst[channel], src[channel], byteCount)
    }

    let sampleRate = source.format.sampleRate
    let attackFrames = min(frames / 4, max(1, Int(attackFadeMs * 0.001 * sampleRate)))
    let releaseFrames = min(frames / 4, max(1, Int(tailFadeMs * 0.001 * sampleRate)))

    for channel in 0..<channels {
      let samples = dst[channel]
      if attackFrames > 1 {
        for i in 0..<attackFrames {
          samples[i] *= Float(i) / Float(attackFrames)
        }
      }
      if releaseFrames > 1 {
        for i in 0..<releaseFrames {
          let frame = frames - releaseFrames + i
          samples[frame] *= Float(releaseFrames - 1 - i) / Float(releaseFrames)
        }
      }
    }

    return copy
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
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: file.processingFormat,
        frameCapacity: frameCount
      )
    else {
      throw LowLatencyNoteAudioError.decodeFailed(url.lastPathComponent)
    }
    try file.read(into: buffer)
    return try convertToStandardFormat(buffer)
  }

  /// 统一解码结果到 standardFormat（float32/44100/stereo），保证连接格式恒定。
  private func convertToStandardFormat(_ source: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
    if source.format.isEqual(standardFormat) {
      return source
    }
    guard let converter = AVAudioConverter(from: source.format, to: standardFormat) else {
      throw LowLatencyNoteAudioError.decodeFailed("converter")
    }
    let ratio = standardFormat.sampleRate / source.format.sampleRate
    let outFrames = AVAudioFrameCount(Double(source.frameLength) * ratio + 64)
    guard
      let output = AVAudioPCMBuffer(pcmFormat: standardFormat, frameCapacity: outFrames)
    else {
      throw LowLatencyNoteAudioError.decodeFailed("output")
    }

    var consumed = false
    var error: NSError?
    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
      if consumed {
        outStatus.pointee = .noDataNow
        return nil
      }
      consumed = true
      outStatus.pointee = .haveData
      return source
    }
    converter.convert(to: output, error: &error, withInputFrom: inputBlock)
    if let error { throw error }
    return output
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
