import Foundation

// Typed entry points into one libretro core dylib, dlopen'd from an embedded signed
// framework (Frameworks/<core>_libretro.framework). RTLD_LOCAL keeps each core's
// identical retro_* exports isolated; nothing links against the cores.
//
// libretro's C callbacks carry no user-data pointer, so dispatch goes through the
// module-global `LibretroBridge.session`. The channel enforces a single live session.

enum LibretroBridge {
    nonisolated(unsafe) static weak var session: GameSession?
}

final class LibretroCore {
    typealias EnvironmentFn = @convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool
    typealias VideoRefreshFn = @convention(c) (UnsafeRawPointer?, UInt32, UInt32, Int) -> Void
    typealias AudioSampleFn = @convention(c) (Int16, Int16) -> Void
    typealias AudioBatchFn = @convention(c) (UnsafePointer<Int16>?, Int) -> Int
    typealias InputPollFn = @convention(c) () -> Void
    typealias InputStateFn = @convention(c) (UInt32, UInt32, UInt32, UInt32) -> Int16

    typealias VoidFn = @convention(c) () -> Void
    typealias SetEnvFn = @convention(c) (EnvironmentFn) -> Void
    typealias SetVideoFn = @convention(c) (VideoRefreshFn) -> Void
    typealias SetAudioFn = @convention(c) (AudioSampleFn) -> Void
    typealias SetAudioBatchFn = @convention(c) (AudioBatchFn) -> Void
    typealias SetInputPollFn = @convention(c) (InputPollFn) -> Void
    typealias SetInputStateFn = @convention(c) (InputStateFn) -> Void
    typealias GetInfoFn = @convention(c) (UnsafeMutablePointer<retro_system_info>) -> Void
    typealias GetAvInfoFn = @convention(c) (UnsafeMutablePointer<retro_system_av_info>) -> Void
    typealias LoadGameFn = @convention(c) (UnsafePointer<retro_game_info>?) -> Bool
    typealias SizeFn = @convention(c) () -> Int
    typealias SerializeFn = @convention(c) (UnsafeMutableRawPointer?, Int) -> Bool
    typealias UnserializeFn = @convention(c) (UnsafeRawPointer?, Int) -> Bool
    typealias MemoryDataFn = @convention(c) (UInt32) -> UnsafeMutableRawPointer?
    typealias MemorySizeFn = @convention(c) (UInt32) -> Int

    private var handle: UnsafeMutableRawPointer?

    let setEnvironment: SetEnvFn
    let setVideoRefresh: SetVideoFn
    let setAudioSample: SetAudioFn
    let setAudioSampleBatch: SetAudioBatchFn
    let setInputPoll: SetInputPollFn
    let setInputState: SetInputStateFn
    let retroInit: VoidFn
    let retroDeinit: VoidFn
    let getSystemInfo: GetInfoFn
    let getSystemAvInfo: GetAvInfoFn
    let loadGame: LoadGameFn
    let unloadGame: VoidFn
    let run: VoidFn
    let reset: VoidFn
    let serializeSize: SizeFn
    let serialize: SerializeFn
    let unserialize: UnserializeFn
    let getMemoryData: MemoryDataFn
    let getMemorySize: MemorySizeFn

    enum CoreError: Error {
        case frameworkMissing(String)
        case dlopenFailed(String)
        case symbolMissing(String)
    }

    init(coreId: String) throws {
        let name = "\(coreId)_libretro"
        guard
            let url = Bundle.main.privateFrameworksURL?
                .appendingPathComponent("\(name).framework")
                .appendingPathComponent(name),
            FileManager.default.fileExists(atPath: url.path)
        else {
            throw CoreError.frameworkMissing(name)
        }
        guard let h = dlopen(url.path, RTLD_NOW | RTLD_LOCAL) else {
            let msg = dlerror().map { String(cString: $0) } ?? "unknown dlopen error"
            throw CoreError.dlopenFailed(msg)
        }
        handle = h

        func sym<T>(_ symbol: String, as type: T.Type) throws -> T {
            guard let ptr = dlsym(h, symbol) else {
                throw CoreError.symbolMissing(symbol)
            }
            return unsafeBitCast(ptr, to: T.self)
        }

        setEnvironment = try sym("retro_set_environment", as: SetEnvFn.self)
        setVideoRefresh = try sym("retro_set_video_refresh", as: SetVideoFn.self)
        setAudioSample = try sym("retro_set_audio_sample", as: SetAudioFn.self)
        setAudioSampleBatch = try sym("retro_set_audio_sample_batch", as: SetAudioBatchFn.self)
        setInputPoll = try sym("retro_set_input_poll", as: SetInputPollFn.self)
        setInputState = try sym("retro_set_input_state", as: SetInputStateFn.self)
        retroInit = try sym("retro_init", as: VoidFn.self)
        retroDeinit = try sym("retro_deinit", as: VoidFn.self)
        getSystemInfo = try sym("retro_get_system_info", as: GetInfoFn.self)
        getSystemAvInfo = try sym("retro_get_system_av_info", as: GetAvInfoFn.self)
        loadGame = try sym("retro_load_game", as: LoadGameFn.self)
        unloadGame = try sym("retro_unload_game", as: VoidFn.self)
        run = try sym("retro_run", as: VoidFn.self)
        reset = try sym("retro_reset", as: VoidFn.self)
        serializeSize = try sym("retro_serialize_size", as: SizeFn.self)
        serialize = try sym("retro_serialize", as: SerializeFn.self)
        unserialize = try sym("retro_unserialize", as: UnserializeFn.self)
        getMemoryData = try sym("retro_get_memory_data", as: MemoryDataFn.self)
        getMemorySize = try sym("retro_get_memory_size", as: MemorySizeFn.self)
    }

    func close() {
        if let h = handle {
            dlclose(h)
            handle = nil
        }
    }

    // MARK: - C callback trampolines (installed once per session by GameSession)

    static let environmentTrampoline: EnvironmentFn = { cmd, data in
        LibretroBridge.session?.handleEnvironment(cmd, data) ?? false
    }
    static let videoRefreshTrampoline: VideoRefreshFn = { data, width, height, pitch in
        LibretroBridge.session?.handleVideoRefresh(data, Int(width), Int(height), pitch)
    }
    static let audioSampleTrampoline: AudioSampleFn = { left, right in
        var frame = [left, right]
        _ = LibretroBridge.session?.handleAudioBatch(&frame, 1)
    }
    static let audioBatchTrampoline: AudioBatchFn = { data, frames in
        LibretroBridge.session?.handleAudioBatch(data, frames) ?? frames
    }
    static let inputPollTrampoline: InputPollFn = {}
    static let inputStateTrampoline: InputStateFn = { port, device, index, id in
        LibretroBridge.session?.handleInputState(
            port: port, device: device, index: index, id: id) ?? 0
    }
}
