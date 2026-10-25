import Flutter
import UIKit
import AVFoundation

private let waterPourAsset = "assets/audio/pour_bottle_clean.mp3"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let gameAudioEngine = AVAudioEngine()
  private let gameAudioPlayer = AVAudioPlayerNode()
  private var waterPourPlayer: AVAudioPlayer?
  private var waterPourStopWorkItem: DispatchWorkItem?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.colorlab/game_audio",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "play",
            let arguments = call.arguments as? [String: Any],
            let effect = arguments["effect"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      let amount = arguments["amount"] as? Int ?? 2
      let durationMs = arguments["durationMs"] as? Int
      guard let self, self.playGameSound(effect, amount: amount, durationMs: durationMs) else {
        result(FlutterError(code: "unknown_effect", message: "Unsupported game sound", details: nil))
        return
      }
      result(nil)
    }
  }

  private func playGameSound(
    _ effect: String,
    amount: Int = 2,
    durationMs: Int? = nil
  ) -> Bool {
    if effect == "waterPour" {
      return playWaterPour(amount: amount, durationMs: durationMs)
    }
    let notes: [(Double, Double)]
    switch effect {
    case "tap": notes = [(640, 0.045)]
    case "invalid": notes = [(190, 0.09)]
    case "pour": notes = [(520, 0.055), (430, 0.075), (360, 0.095)]
    case "move": notes = [(720, 0.055), (900, 0.07)]
    case "shoot": notes = [(300, 0.055), (900, 0.12)]
    case "stick": notes = [(260, 0.05), (150, 0.09)]
    case "pop": notes = [(520, 0.05), (800, 0.065), (1100, 0.09)]
    case "fall": notes = [(720, 0.065), (360, 0.15)]
    case "swap": notes = [(600, 0.045), (880, 0.065)]
    case "lose": notes = [(392, 0.11), (330, 0.11), (262, 0.14), (196, 0.22)]
    case "row": notes = [(210, 0.1), (130, 0.13)]
    case "win": notes = [(523, 0.105), (659, 0.105), (784, 0.105), (1047, 0.22)]
    default: return false
    }
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      if !gameAudioEngine.attachedNodes.contains(gameAudioPlayer) {
        gameAudioEngine.attach(gameAudioPlayer)
        gameAudioEngine.connect(gameAudioPlayer, to: gameAudioEngine.mainMixerNode, format: nil)
      }
      if !gameAudioEngine.isRunning { try gameAudioEngine.start() }
      let sampleRate = 24000.0
      let totalFrames = AVAudioFrameCount(notes.reduce(0) { $0 + Int($1.1 * sampleRate) })
      guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames),
            let channel = buffer.floatChannelData?[0] else { return false }
      buffer.frameLength = totalFrames
      var frame = 0
      for (frequency, duration) in notes {
        let count = Int(duration * sampleRate)
        for i in 0..<count {
          let attack = min(1.0, Double(i) / (sampleRate * 0.008))
          let release = min(1.0, Double(count - i) / (sampleRate * 0.025))
          let envelope = min(attack, release)
          channel[frame] = Float(sin(2.0 * .pi * frequency * Double(i) / sampleRate) * envelope * 0.60)
          frame += 1
        }
      }
      gameAudioPlayer.scheduleBuffer(buffer, at: nil)
      if !gameAudioPlayer.isPlaying { gameAudioPlayer.play() }
      return true
    } catch {
      return false
    }
  }

  private func playWaterPour(amount: Int, durationMs: Int?) -> Bool {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      let boundedAmount = min(4, max(1, amount))
      let fallbackDurationMs = 450 + boundedAmount * 260
      let boundedDurationMs = min(1_490, max(710, durationMs ?? fallbackDurationMs))
      let key = FlutterDartProject.lookupKey(forAsset: waterPourAsset)
      guard let url = Bundle.main.url(forResource: key, withExtension: nil) else {
        return false
      }

      waterPourStopWorkItem?.cancel()
      waterPourPlayer?.stop()

      let player = try AVAudioPlayer(contentsOf: url)
      player.volume = 1
      player.prepareToPlay()
      guard player.play() else { return false }
      waterPourPlayer = player

      let stopWorkItem = DispatchWorkItem { [weak self, weak player] in
        guard let self = self,
              let player = player,
              self.waterPourPlayer === player else { return }
        player.stop()
        self.waterPourPlayer = nil
        self.waterPourStopWorkItem = nil
      }
      waterPourStopWorkItem = stopWorkItem
      DispatchQueue.main.asyncAfter(
        deadline: .now() + .milliseconds(boundedDurationMs),
        execute: stopWorkItem
      )
      return true
    } catch {
      return false
    }
  }
}
