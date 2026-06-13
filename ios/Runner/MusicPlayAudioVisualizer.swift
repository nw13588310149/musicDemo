import AVFoundation
import Flutter

/// 与主播放器并行运行的静音探针引擎：从 PCM tap 提取 46 段 RMS 能量，
/// 经 EventChannel 推送给 Flutter 可视化条（不接管主输出）。
final class MusicPlayAudioVisualizer: NSObject {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?

  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let queue = DispatchQueue(label: "com.yyzl.music.musicPlayVisualizer")

  private var audioFile: AVAudioFile?
  private var attachedUrl: String?
  private var currentFrame: AVAudioFramePosition = 0
  private var isPlaying = false
  private var tapInstalled = false

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "com.yyzl.music/music_play_visualizer",
      binaryMessenger: messenger
    )
    eventChannel = FlutterEventChannel(
      name: "com.yyzl.music/music_play_visualizer/bands",
      binaryMessenger: messenger
    )
    super.init()
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    eventChannel.setStreamHandler(self)
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "attach":
      guard let args = call.arguments as? [String: Any],
            let url = args["url"] as? String else {
        result(FlutterError(code: "bad_args", message: "Missing url", details: nil))
        return
      }
      queue.async { [weak self] in
        self?.attach(urlString: url)
        DispatchQueue.main.async { result(nil) }
      }
    case "updateAndroidSession":
      result(nil)
    case "syncTransport":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "Missing args", details: nil))
        return
      }
      let playing = (args["playing"] as? NSNumber)?.boolValue ?? false
      let positionMs = (args["positionMs"] as? NSNumber)?.int64Value ?? 0
      queue.async { [weak self] in
        self?.syncTransport(playing: playing, positionMs: positionMs)
        DispatchQueue.main.async { result(nil) }
      }
    case "detach":
      queue.async { [weak self] in
        self?.detach()
        DispatchQueue.main.async { result(nil) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func attach(urlString: String) {
    detachInternal()
    attachedUrl = urlString
    guard let url = URL(string: urlString) else {
      emitIdle()
      return
    }
    do {
      let localUrl: URL
      if url.isFileURL {
        localUrl = url
      } else {
        let data = try Data(contentsOf: url)
        let temp = FileManager.default.temporaryDirectory
          .appendingPathComponent("music_play_visualizer_\(UUID().uuidString).m4a")
        try data.write(to: temp)
        localUrl = temp
      }
      audioFile = try AVAudioFile(forReading: localUrl)
      try configureGraph()
    } catch {
      emitIdle()
    }
  }

  private func configureGraph() throws {
    engine.stop()
    engine.reset()
    if engine.attachedNodes.contains(player) {
      engine.detach(player)
    }
    engine.attach(player)
    let mixer = engine.mainMixerNode
    mixer.outputVolume = 0
    engine.connect(player, to: mixer, format: audioFile?.processingFormat)
    installTapIfNeeded()
    try engine.start()
  }

  private func installTapIfNeeded() {
    guard !tapInstalled else { return }
    let mixer = engine.mainMixerNode
    let format = mixer.outputFormat(forBus: 0)
    mixer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
      guard let self, self.isPlaying else { return }
      let bands = self.process(buffer: buffer)
      guard !bands.isEmpty else { return }
      DispatchQueue.main.async {
        self.eventSink?(bands)
      }
    }
    tapInstalled = true
  }

  private func syncTransport(playing: Bool, positionMs: Int64) {
    guard audioFile != nil else { return }
    isPlaying = playing
    let sampleRate = audioFile?.processingFormat.sampleRate ?? 44100
    currentFrame = AVAudioFramePosition(Double(positionMs) / 1000.0 * sampleRate)

    if playing {
      scheduleFromCurrentFrame()
      if !player.isPlaying {
        player.play()
      }
      if !engine.isRunning {
        try? engine.start()
      }
    } else {
      player.pause()
    }
  }

  private func scheduleFromCurrentFrame() {
    guard let file = audioFile else { return }
    player.stop()
    let frameCount = AVAudioFrameCount(max(0, file.length - currentFrame))
    if frameCount <= 0 {
      emitIdle()
      return
    }
    player.schedule(
      segment: AVAudioSegment(
        file: file,
        startingFrame: currentFrame,
        frameCount: frameCount,
        loopCount: 0
      ),
      at: nil
    )
  }

  private func process(buffer: AVAudioPCMBuffer) -> [Double] {
    guard isPlaying,
          let channel = buffer.floatChannelData?[0] else { return [] }
    let frames = Int(buffer.frameLength)
    guard frames >= 128 else { return [] }

    let n = min(frames, 1024)
    let bands = 46
    let sampleRate = buffer.format.sampleRate
    var result = [Double](repeating: 0, count: bands)

    for b in 0..<bands {
      let k = melBinIndex(b: b, bands: bands, n: n, sampleRate: sampleRate)
      let omega = 2.0 * Double.pi * Double(k) / Double(n)
      let coeff = 2.0 * cos(omega)
      var s0 = 0.0
      var s1 = 0.0
      var s2 = 0.0
      for i in 0..<n {
        s0 = Double(channel[i]) + coeff * s1 - s2
        s2 = s1
        s1 = s0
      }
      let power = s1 * s1 + s2 * s2 - coeff * s1 * s2
      result[b] = sqrt(max(0, power)) / Double(n)
    }
    return result
  }

  private func melBinIndex(b: Int, bands: Int, n: Int, sampleRate: Double) -> Int {
    let minHz = 50.0
    let maxHz = 14000.0
    let minMel = hzToMel(minHz)
    let maxMel = hzToMel(maxHz)
    let mel = minMel + (maxMel - minMel) * Double(b) / Double(bands)
    let hz = melToHz(mel)
    let k = Int(hz / sampleRate * Double(n))
    return max(1, min(n / 2 - 1, k))
  }

  private func hzToMel(_ hz: Double) -> Double {
    2595.0 * log10(1.0 + hz / 700.0)
  }

  private func melToHz(_ mel: Double) -> Double {
    700.0 * (pow(10.0, mel / 2595.0) - 1.0)
  }

  private func detach() {
    detachInternal()
    emitIdle()
  }

  private func detachInternal() {
    isPlaying = false
    attachedUrl = nil
    player.stop()
    if tapInstalled {
      engine.mainMixerNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    engine.stop()
    audioFile = nil
    currentFrame = 0
  }

  private func emitIdle() {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?([])
    }
  }
}

extension MusicPlayAudioVisualizer: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

private struct AVAudioSegment {
  let file: AVAudioFile
  let startingFrame: AVAudioFramePosition
  let frameCount: AVAudioFrameCount
  let loopCount: Int
}

private extension AVAudioPlayerNode {
  func schedule(segment: AVAudioSegment, at when: AVAudioTime?) {
    scheduleSegment(
      segment.file,
      startingFrame: segment.startingFrame,
      frameCount: segment.frameCount,
      at: when,
      completionHandler: nil
    )
  }
}
