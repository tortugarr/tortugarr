import Accelerate
import Flutter
import Foundation

// Converts the core's software framebuffer into BGRA CVPixelBuffers served to
// Flutter as an external texture. Called from the emulation thread.
final class GameVideoOutput: NSObject, FlutterTexture {
    nonisolated(unsafe) private let textures: FlutterTextureRegistry
    nonisolated(unsafe) private(set) var textureId: Int64 = -1

    // libretro pixel formats (retro_pixel_format raw values)
    static let format0RGB1555: UInt32 = 0
    static let formatXRGB8888: UInt32 = 1
    static let formatRGB565: UInt32 = 2

    nonisolated(unsafe) var pixelFormat: UInt32 = GameVideoOutput.format0RGB1555

    nonisolated(unsafe) private var pool: CVPixelBufferPool?
    nonisolated(unsafe) private var poolWidth = 0
    nonisolated(unsafe) private var poolHeight = 0
    nonisolated(unsafe) private var currentFrame: CVPixelBuffer?
    nonisolated(unsafe) private var alive = true
    nonisolated private let lock = NSLock()

    init(textures: FlutterTextureRegistry) {
        self.textures = textures
        super.init()
        textureId = textures.register(self)
    }

    nonisolated func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        guard alive, let frame = currentFrame else { return nil }
        return Unmanaged.passRetained(frame)
    }

    // data == nil is a dupe frame (RETRO_ENVIRONMENT_GET_CAN_DUPE): re-signal the last one.
    nonisolated func pushFrame(_ data: UnsafeRawPointer?, width: Int, height: Int, pitch: Int) {
        guard width > 0, height > 0 else { return }
        guard let data else {
            signal()
            return
        }
        if pool == nil || poolWidth != width || poolHeight != height {
            pool = Self.makePool(width: width, height: height)
            poolWidth = width
            poolHeight = height
        }
        guard let pool else { return }
        var pbOut: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut) == kCVReturnSuccess,
            let pb = pbOut
        else { return }

        CVPixelBufferLockBaseAddress(pb, [])
        if let dst = CVPixelBufferGetBaseAddress(pb) {
            let dstStride = CVPixelBufferGetBytesPerRow(pb)
            convert(
                src: data, srcPitch: pitch, dst: dst, dstStride: dstStride,
                width: width, height: height)
        }
        CVPixelBufferUnlockBaseAddress(pb, [])

        lock.lock()
        if alive { currentFrame = pb }
        lock.unlock()
        signal()
    }

    nonisolated private func signal() {
        let tid = textureId
        lock.lock()
        let isAlive = alive
        lock.unlock()
        guard isAlive else { return }
        DispatchQueue.main.async { [weak self] in
            self?.textures.textureFrameAvailable(tid)
        }
    }

    nonisolated private func convert(
        src: UnsafeRawPointer, srcPitch: Int, dst: UnsafeMutableRawPointer, dstStride: Int,
        width: Int, height: Int
    ) {
        switch pixelFormat {
        case Self.formatXRGB8888:
            // Little-endian XRGB8888 is byte-order B,G,R,X - already BGRA layout; force alpha.
            for row in 0..<height {
                let s = src.advanced(by: row * srcPitch).assumingMemoryBound(to: UInt32.self)
                let d = dst.advanced(by: row * dstStride).assumingMemoryBound(to: UInt32.self)
                for x in 0..<width {
                    d[x] = s[x] | 0xFF00_0000
                }
            }
        case Self.formatRGB565:
            var srcBuf = vImage_Buffer(
                data: UnsafeMutableRawPointer(mutating: src),
                height: vImagePixelCount(height), width: vImagePixelCount(width),
                rowBytes: srcPitch)
            var dstBuf = vImage_Buffer(
                data: dst, height: vImagePixelCount(height), width: vImagePixelCount(width),
                rowBytes: dstStride)
            vImageConvert_RGB565toBGRA8888(255, &srcBuf, &dstBuf, vImage_Flags(kvImageNoFlags))
        default:
            // 0RGB1555 (rare; scalar conversion is fine at these resolutions)
            for row in 0..<height {
                let s = src.advanced(by: row * srcPitch).assumingMemoryBound(to: UInt16.self)
                let d = dst.advanced(by: row * dstStride).assumingMemoryBound(to: UInt32.self)
                for x in 0..<width {
                    let p = UInt32(s[x])
                    let r = (p >> 10) & 0x1F
                    let g = (p >> 5) & 0x1F
                    let b = p & 0x1F
                    d[x] = 0xFF00_0000
                        | ((r << 3 | r >> 2) << 16)
                        | ((g << 3 | g >> 2) << 8)
                        | (b << 3 | b >> 2)
                }
            }
        }
    }

    nonisolated private static func makePool(width: Int, height: Int) -> CVPixelBufferPool? {
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pool)
        return pool
    }

    func teardown() {
        lock.lock()
        alive = false
        currentFrame = nil
        lock.unlock()
        textures.unregisterTexture(textureId)
    }
}
