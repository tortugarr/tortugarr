import AVFoundation
import Foundation

// Plays the core's interleaved S16 stereo output through an AVAudioSourceNode.
// The ring buffer doubles as the emulation clock: GameSession blocks while the
// ring holds more than its pacing threshold, so audio drives frame timing.
final class GameAudioOutput {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private(set) var sampleRate: Double = 0

    // Interleaved stereo S16 ring, ~250 ms.
    nonisolated(unsafe) private var ring: [Int16] = []
    nonisolated(unsafe) private var readIndex = 0
    nonisolated(unsafe) private var writeIndex = 0
    nonisolated(unsafe) private var storedSamples = 0
    nonisolated private let lock = NSLock()

    func start(sampleRate: Double) -> Bool {
        self.sampleRate = sampleRate
        let capacityFrames = Int(sampleRate * 0.25)
        ring = [Int16](repeating: 0, count: capacityFrames * 2)
        readIndex = 0
        writeIndex = 0
        storedSamples = 0

        guard
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                channels: 2, interleaved: false)
        else { return false }

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            self?.render(frameCount: Int(frameCount), audioBufferList: audioBufferList)
            return noErr
        }
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    func stop() {
        engine.stop()
        if let node = sourceNode {
            engine.detach(node)
            sourceNode = nil
        }
    }

    func setPaused(_ paused: Bool) {
        if paused {
            engine.pause()
        } else {
            try? engine.start()
        }
    }

    // Seconds of buffered audio; the session's pacing loop blocks on this.
    nonisolated var bufferedSeconds: Double {
        lock.lock()
        let frames = storedSamples / 2
        lock.unlock()
        guard sampleRate > 0 else { return 0 }
        return Double(frames) / sampleRate
    }

    // Core audio callback (emulation thread). Drops samples when full (fast-forward).
    nonisolated func push(_ data: UnsafePointer<Int16>, frames: Int) {
        lock.lock()
        defer { lock.unlock() }
        let capacity = ring.count
        guard capacity > 0 else { return }
        let samples = min(frames * 2, capacity - storedSamples)
        ring.withUnsafeMutableBufferPointer { buf in
            for i in 0..<samples {
                buf[writeIndex] = data[i]
                writeIndex = (writeIndex + 1) % capacity
            }
        }
        storedSamples += samples
    }

    nonisolated private func render(frameCount: Int, audioBufferList: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        guard buffers.count >= 2,
            let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
            let right = buffers[1].mData?.assumingMemoryBound(to: Float.self)
        else { return }

        lock.lock()
        let capacity = ring.count
        let available = storedSamples / 2
        let toCopy = min(frameCount, available)
        ring.withUnsafeBufferPointer { buf in
            for i in 0..<toCopy {
                left[i] = Float(buf[readIndex]) / 32768.0
                right[i] = Float(buf[(readIndex + 1) % capacity]) / 32768.0
                readIndex = (readIndex + 2) % capacity
            }
        }
        storedSamples -= toCopy * 2
        lock.unlock()

        for i in toCopy..<frameCount {
            left[i] = 0
            right[i] = 0
        }
    }
}
