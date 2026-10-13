import AVFoundation
import Foundation
import MediaPlayer
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Bridges the player to the system Now Playing infrastructure: it owns the
/// Now Playing payload and remote-command handlers so Moonfin becomes the
/// active Now Playing app. Without this, AirPods stem clicks and Control
/// Center transport controls fall through to whatever app last held the Now
/// Playing session.
///
/// Two modes:
/// - Detached (default): `MPRemoteCommandCenter.shared()` +
///   `MPNowPlayingInfoCenter.default()`, used when no AVPlayer is available
///   (software decode path, teardown).
/// - Attached: an `MPNowPlayingSession` bound to a specific `AVPlayer`.
///   Required on tvOS 26, where writes to the default info center race the
///   loopback-HLS player. `attach(player:)` must be called again on every
///   player republish. The engine swaps AVPlayer instances on internal
///   reloads and a stale session binding reintroduces the race.
@MainActor
final class NowPlayingController {
    var onPlay: (@MainActor () -> Void)?
    var onPause: (@MainActor () -> Void)?
    var onToggle: (@MainActor () -> Void)?
    var onSeek: (@MainActor (TimeInterval) -> Void)?
    var onSkip: (@MainActor (TimeInterval) -> Void)?
    var onNext: (@MainActor () -> Void)?
    var onPrevious: (@MainActor () -> Void)?

    private var commandsRegistered = false
    private var registeredTargets: [(MPRemoteCommand, Any)] = []
    private var info: [String: Any] = [:]
    private var artworkURLString: String?
    private var attachedPlayer: AVPlayer?
    private var queueHasNext = false
    private var queueHasPrevious = false

    // MPNowPlayingSession is an iOS and tvOS API. Only tvOS drives Now Playing
    // natively, so on macOS this class stays inert and the default centers
    // stand in for the session.
    #if os(iOS) || os(tvOS)
        private var session: MPNowPlayingSession?

        private var commandCenter: MPRemoteCommandCenter {
            session?.remoteCommandCenter ?? .shared()
        }

        private var infoCenter: MPNowPlayingInfoCenter {
            session?.nowPlayingInfoCenter ?? .default()
        }
    #else
        private var commandCenter: MPRemoteCommandCenter { .shared() }
        private var infoCenter: MPNowPlayingInfoCenter { .default() }
    #endif

    /// Binds Now Playing to a concrete AVPlayer via `MPNowPlayingSession`.
    /// Passing `nil` detaches and falls back to the default centers.
    /// Re-registers command handlers against the new session's command center
    /// and replays the current metadata so nothing is lost across a rebind.
    func attach(player: AVPlayer?) {
        #if os(iOS) || os(tvOS)
            if player === attachedPlayer { return }
            let wasRegistered = commandsRegistered
            if wasRegistered { unregisterCommands() }
            let savedInfo = info
            if let player {
                let newSession = MPNowPlayingSession(players: [player])
                newSession.automaticallyPublishesNowPlayingInfo = false
                session = newSession
                attachedPlayer = player
                newSession.becomeActiveIfPossible()
            } else {
                session = nil
                attachedPlayer = nil
            }
            if wasRegistered { registerCommands() }
            if !savedInfo.isEmpty {
                info = savedInfo
                infoCenter.nowPlayingInfo = info
            }
        #else
            attachedPlayer = player
        #endif
    }

    func registerCommands() {
        guard !commandsRegistered else { return }
        commandsRegistered = true
        let center = commandCenter

        addTarget(center.playCommand) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onPlay?()
                return .success
            }
        }
        addTarget(center.pauseCommand) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onPause?()
                return .success
            }
        }
        addTarget(center.togglePlayPauseCommand) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onToggle?()
                return .success
            }
        }
        addTarget(center.changePlaybackPositionCommand) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self,
                    let positionEvent = event as? MPChangePlaybackPositionCommandEvent
                else {
                    return .commandFailed
                }
                self.onSeek?(positionEvent.positionTime)
                return .success
            }
        }
        addTarget(center.skipForwardCommand) { [weak self] event in
            MainActor.assumeIsolated {
                let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 10
                self?.onSkip?(interval)
                return .success
            }
        }
        addTarget(center.skipBackwardCommand) { [weak self] event in
            MainActor.assumeIsolated {
                let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 10
                self?.onSkip?(-interval)
                return .success
            }
        }
        addTarget(center.nextTrackCommand) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onNext?()
                return .success
            }
        }
        addTarget(center.previousTrackCommand) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onPrevious?()
                return .success
            }
        }

        center.skipForwardCommand.preferredIntervals = [NSNumber(value: 10)]
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: 10)]
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.skipBackwardCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = queueHasNext
        center.previousTrackCommand.isEnabled = queueHasPrevious
    }

    func setQueueCapabilities(hasNext: Bool, hasPrevious: Bool) {
        queueHasNext = hasNext
        queueHasPrevious = hasPrevious
        let center = commandCenter
        center.nextTrackCommand.isEnabled = hasNext
        center.previousTrackCommand.isEnabled = hasPrevious
    }

    func updateMetadata(
        title: String, subtitle: String, durationSeconds: TimeInterval, artworkURL: String?
    ) {
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = subtitle
        info[MPMediaItemPropertyAlbumTitle] = subtitle
        if durationSeconds > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = durationSeconds
        }
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.video.rawValue
        infoCenter.nowPlayingInfo = info
        loadArtwork(artworkURL)
    }

    func updatePlaybackState(
        isPlaying: Bool, elapsed: TimeInterval, duration: TimeInterval, rate: Float
    ) {
        guard !info.isEmpty else { return }
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, elapsed)
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(rate <= 0 ? 1 : rate) : 0
        infoCenter.nowPlayingInfo = info
    }

    func clear() {
        info = [:]
        artworkURLString = nil
        infoCenter.nowPlayingInfo = nil
    }

    func teardown() {
        unregisterCommands()
        clear()
        #if os(iOS) || os(tvOS)
            session = nil
        #endif
        attachedPlayer = nil
    }

    private func unregisterCommands() {
        for (command, token) in registeredTargets {
            command.removeTarget(token)
        }
        registeredTargets.removeAll()
        commandsRegistered = false
    }

    private func addTarget(
        _ command: MPRemoteCommand,
        handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus
    ) {
        let token = command.addTarget(handler: handler)
        registeredTargets.append((command, token))
    }

    private func loadArtwork(_ urlString: String?) {
        guard let urlString, !urlString.isEmpty, urlString != artworkURLString,
            let url = URL(string: urlString)
        else {
            return
        }
        artworkURLString = urlString
        Task { @MainActor [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            self?.applyArtworkData(data, for: urlString)
        }
    }

    private func applyArtworkData(_ data: Data, for urlString: String) {
        #if canImport(UIKit)
            guard artworkURLString == urlString, let image = UIImage(data: data) else { return }
        #else
            guard artworkURLString == urlString, let image = NSImage(data: data) else { return }
        #endif
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
            image
        }
        infoCenter.nowPlayingInfo = info
    }
}
