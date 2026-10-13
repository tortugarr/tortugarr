import Flutter
import Foundation
import UIKit

// Flutter bridge for native retro-game playback. One live session at a time;
// libretro's global C callbacks make multiple sessions unsound (see LibretroBridge).
@MainActor
final class AppleTvGameChannel: NSObject, FlutterStreamHandler {
    private let control: FlutterMethodChannel
    private let events: FlutterEventChannel
    private let textures: FlutterTextureRegistry
    private weak var rootViewController: UIViewController?
    nonisolated(unsafe) private var eventSink: FlutterEventSink?

    private var session: GameSession?
    private var inputVC: AppleTvGameInputViewController?

    init(
        messenger: FlutterBinaryMessenger, textures: FlutterTextureRegistry,
        rootViewController: UIViewController
    ) {
        control = FlutterMethodChannel(
            name: "moonfin/appletv_game_control", binaryMessenger: messenger)
        events = FlutterEventChannel(
            name: "moonfin/appletv_game_events", binaryMessenger: messenger)
        self.textures = textures
        self.rootViewController = rootViewController
        super.init()
        control.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(nil)
                return
            }
            Task { @MainActor in self.handle(call, result: result) }
        }
        events.setStreamHandler(self)
    }

    nonisolated func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink)
        -> FlutterError?
    {
        self.eventSink = eventSink
        return nil
    }

    nonisolated func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    nonisolated private func send(_ payload: [String: Any]) {
        eventSink?(payload)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "load":
            load(args, result: result)
        case "start":
            session?.startRunLoop()
            presentInputCapture()
            result(nil)
        case "pause":
            session?.setPaused(true)
            result(nil)
        case "resume":
            session?.setPaused(false)
            result(nil)
        case "restart":
            session?.reset()
            result(nil)
        case "stop":
            stopSession()
            result(nil)
        case "saveState":
            guard let session else {
                result(FlutterError(code: "no_session", message: nil, details: nil))
                return
            }
            session.saveState { data in
                DispatchQueue.main.async {
                    if let data {
                        result(FlutterStandardTypedData(bytes: data))
                    } else {
                        result(FlutterError(code: "serialize_failed", message: nil, details: nil))
                    }
                }
            }
        case "loadState":
            guard let session,
                let typed = args["data"] as? FlutterStandardTypedData
            else {
                result(false)
                return
            }
            session.loadState(typed.data) { ok in
                DispatchQueue.main.async { result(ok) }
            }
        case "setFastForward":
            let factor = (args["factor"] as? NSNumber)?.intValue ?? 1
            session?.setFastForward(factor)
            result(nil)
        case "pulseButton":
            let index = (args["index"] as? NSNumber)?.intValue ?? -1
            let durationMs = (args["durationMs"] as? NSNumber)?.intValue ?? 150
            session?.input.pulse(index: index, durationMs: durationMs)
            result(nil)
        case "getOptions":
            result(session?.getOptions() ?? [])
        case "setOption":
            if let id = args["id"] as? String, let value = args["value"] as? String {
                session?.setOption(id: id, value: value)
            }
            result(nil)
        case "getCurrentOptions":
            result(session?.currentOptions() ?? [:])
        case "controllerCount":
            result(session?.input.controllerCount ?? 0)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func load(_ args: [String: Any], result: @escaping FlutterResult) {
        guard
            let core = args["core"] as? String,
            let romPath = args["romPath"] as? String,
            let systemDir = args["systemDir"] as? String,
            let saveDir = args["saveDir"] as? String,
            let gameId = args["gameId"] as? String
        else {
            result(FlutterError(code: "bad_args", message: nil, details: nil))
            return
        }
        stopSession()

        let options = (args["options"] as? [String: String]) ?? [:]
        try? FileManager.default.createDirectory(
            atPath: saveDir, withIntermediateDirectories: true)

        let session = GameSession(
            coreId: core, romPath: romPath, systemDir: systemDir, saveDir: saveDir,
            gameId: gameId, options: options, textures: textures)
        session.onEvent = { [weak self] payload in self?.send(payload) }
        session.input.onMenuPressed = { [weak self] in self?.send(["event": "menuPressed"]) }
        session.input.onButton = { [weak self] index, pressed in
            self?.send(["event": "button", "index": index, "pressed": pressed])
        }
        session.input.onControllersChanged = { [weak self] count in
            self?.send(["event": "controllersChanged", "count": count])
        }

        do {
            let av = try session.load()
            self.session = session
            result([
                "textureId": session.video.textureId,
                "width": av.width,
                "height": av.height,
                "aspect": av.aspect,
                "fps": av.fps,
                "sampleRate": av.sampleRate,
            ])
        } catch {
            session.stop()
            result(FlutterError(
                code: "load_failed", message: "\(error)", details: nil))
        }
    }

    private func presentInputCapture() {
        guard inputVC == nil, let root = rootViewController else { return }
        let vc = AppleTvGameInputViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.onRemotePress = { [weak self] key in
            self?.send(["event": "remotePress", "key": key])
        }
        inputVC = vc
        root.present(vc, animated: false)
    }

    private func stopSession() {
        session?.stop()
        session = nil
        if let vc = inputVC {
            vc.dismiss(animated: false)
            inputVC = nil
        }
    }
}
