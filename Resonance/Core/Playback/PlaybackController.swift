import AVFoundation
import Combine
import Foundation
import MediaPlayer
import UIKit

enum PlaybackState: Equatable, Sendable {
    case idle
    case loading(Track)
    case playing(Track)
    case paused(Track)
    case error(String)
}

@MainActor
final class PlaybackController: ObservableObject {
    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var queue: [Track] = []
    @Published private(set) var index: Int = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private let resolver: any StreamResolving
    private weak var historyRecorder: (any HistoryRecording)?
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var hasReportedCurrent = false

    init(resolver: any StreamResolving, historyRecorder: (any HistoryRecording)?) {
        self.resolver = resolver
        self.historyRecorder = historyRecorder
        configureSession()
        configureRemoteCommands()
        observeInterruptions()
    }

    deinit {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        if let routeChangeObserver { NotificationCenter.default.removeObserver(routeChangeObserver) }
    }

    func play(_ track: Track, in queue: [Track] = []) {
        var resolvedQueue = queue
        if !queue.contains(where: { $0.videoID == track.videoID }) {
            resolvedQueue.append(track)
        }
        self.queue = resolvedQueue
        if let position = resolvedQueue.firstIndex(of: track) {
            self.index = position
        }
        Task { await loadAndPlay(track) }
    }

    func enqueueNext(_ track: Track) {
        if queue.isEmpty { queue = [track] }
        else { queue.insert(track, at: min(index + 1, queue.count)) }
    }

    func enqueueLater(_ track: Track) {
        queue.append(track)
    }

    func togglePlayPause() {
        switch state {
        case .playing:
            player?.pause()
        case .paused:
            player?.play()
        case .idle, .loading, .error:
            break
        }
    }

    func next() {
        guard index + 1 < queue.count else { return }
        index += 1
        if case .playing = state {} else { Task { await loadAndPlay(queue[index]) } }
    }

    func previous() {
        guard index > 0 else { return }
        index -= 1
        Task { await loadAndPlay(queue[index]) }
    }

    func seek(to seconds: TimeInterval) {
        guard let player else { return }
        player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600))
    }

    var currentTrack: Track? {
        guard queue.indices.contains(index) else { return nil }
        return queue[index]
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            state = .error("Audio session error: \(error.localizedDescription)")
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
            Task { @MainActor in
                switch type {
                case .began:
                    self?.player?.pause()
                case .ended:
                    if let options = info[AVAudioSessionInterruptionOptionKey] as? UInt,
                       AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                        self?.player?.play()
                    }
                @unknown default:
                    break
                }
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if AVAudioSession.sharedInstance().currentRoute.outputs.contains(where: { $0.portType == .headphones }) {
                    self.player?.pause()
                }
            }
        }
    }

    private func loadAndPlay(_ track: Track) async {
        state = .loading(track)
        hasReportedCurrent = false
        elapsed = 0
        duration = track.duration ?? 0
        do {
            let stream = try await resolver.resolve(videoID: track.videoID)
            let item = AVPlayerItem(url: stream.url)
            let player = AVPlayer(playerItem: item)
            self.player = player
            if let timeObserver { player.removeTimeObserver(timeObserver) }
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
                Task { @MainActor in
                    guard let self else { return }
                    self.elapsed = time.seconds
                    if let total = self.player?.currentItem?.duration.seconds, total.isFinite, total > 0 {
                        self.duration = total
                    }
                    self.updateNowPlaying()
                }
            }
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.handleTrackFinished() }
            }
            player.play()
            state = .playing(track)
            updateNowPlaying()
        } catch {
            state = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func handleTrackFinished() {
        if let track = currentTrack {
            historyRecorder?.recordPlayed(track)
        }
        if index + 1 < queue.count {
            index += 1
            Task { await loadAndPlay(queue[index]) }
        } else {
            state = .idle
        }
    }

    private func updateNowPlaying() {
        guard let track = currentTrack, let player else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artistText,
            MPMediaItemPropertyPlaybackDuration: player.currentItem?.duration.seconds ?? track.duration ?? 0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime().seconds,
            MPNowPlayingInfoPropertyPlaybackRate: player.rate
        ]
        if let album = track.album { info[MPMediaItemPropertyAlbumTitle] = album.title }
        if let artworkURL = track.artworkURL {
            Task {
                if let data = try? Data(contentsOf: artworkURL), let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                    current[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                }
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
