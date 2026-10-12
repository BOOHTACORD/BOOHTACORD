import CoreImage
import CoreFoundation
import Foundation
import ImageIO
import ReplayKit

private enum UploaderLimits {
    static let writeChunkBytes = 16 * 1024
    static let queuedBytes = 4 * 1024 * 1024
    static let maximumPacketBytes = 32 * 1024 * 1024
}

private enum SampleKind {
    case video
    case audio
}

private struct PendingPacket {
    let data: Data
    let kind: SampleKind
}

final class SampleUploader {
    private static let imageContext = CIContext(options: nil)

    private let connection: SocketConnection
    private let queue = DispatchQueue(label: "ru.boohtacord.broadcast.uploader")
    private var pending: [PendingPacket] = []
    private var pendingByteCount = 0
    private var currentPacket: Data?
    private var currentOffset = 0

    init(connection: SocketConnection) {
        self.connection = connection
        connection.didOpen = { [weak self] in
            self?.queue.async { self?.pump() }
        }
        connection.streamHasSpaceAvailable = { [weak self] in
            self?.queue.async { self?.pump() }
        }
    }

    func send(sample buffer: CMSampleBuffer, type: RPSampleBufferType) {
        let packet: PendingPacket?
        switch type {
        case .video:
            packet = prepareVideo(sample: buffer).map { PendingPacket(data: $0, kind: .video) }
        case .audioApp:
            packet = prepareAudio(sample: buffer).map { PendingPacket(data: $0, kind: .audio) }
        default:
            packet = nil
        }
        guard let packet else { return }

        queue.async { [weak self] in
            self?.enqueue(packet)
            self?.pump()
        }
    }

    private func enqueue(_ packet: PendingPacket) {
        guard packet.data.count <= UploaderLimits.maximumPacketBytes else { return }
        while pendingByteCount + packet.data.count > UploaderLimits.queuedBytes {
            guard let videoIndex = pending.firstIndex(where: { $0.kind == .video }) else {
                if packet.kind == .audio, let oldest = pending.firstIndex(where: { $0.kind == .audio }) {
                    pendingByteCount -= pending.remove(at: oldest).data.count
                    continue
                }
                return
            }
            pendingByteCount -= pending.remove(at: videoIndex).data.count
        }

        // Keep audio close to its capture time when queued video is waiting.
        if packet.kind == .audio, let firstVideo = pending.firstIndex(where: { $0.kind == .video }) {
            pending.insert(packet, at: firstVideo)
        } else {
            pending.append(packet)
        }
        pendingByteCount += packet.data.count
    }

    private func pump() {
        while true {
            if currentPacket == nil {
                guard !pending.isEmpty else { return }
                let next = pending.removeFirst()
                pendingByteCount -= next.data.count
                currentPacket = next.data
                currentOffset = 0
            }

            guard let currentPacket else { return }
            let remaining = currentPacket.count - currentOffset
            let count = min(remaining, UploaderLimits.writeChunkBytes)
            let written = currentPacket.withUnsafeBytes { bytes -> Int in
                guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return connection.writeToStream(
                    buffer: baseAddress.advanced(by: currentOffset),
                    maxLength: count
                )
            }
            guard written > 0 else { return }
            currentOffset += written
            if currentOffset == currentPacket.count {
                self.currentPacket = nil
                currentOffset = 0
            }
        }
    }

    private func prepareVideo(sample buffer: CMSampleBuffer) -> Data? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let orientation = CMGetAttachment(buffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil)?
            .uintValue ?? 0
        let image = CIImage(cvPixelBuffer: imageBuffer)
        guard let colorSpace = image.colorSpace,
              let jpeg = Self.imageContext.jpegRepresentation(
                of: image,
                colorSpace: colorSpace,
                options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.9]
              ) else { return nil }

        return serialize(
            jpeg,
            contentType: "image/jpeg",
            headers: [
                "Buffer-Width": String(width),
                "Buffer-Height": String(height),
                "Buffer-Orientation": String(orientation),
            ]
        )
    }

    private func prepareAudio(sample buffer: CMSampleBuffer) -> Data? {
        var sampleRate: Int32 = 0
        var channels = 0
        var frames = 0
        guard let pcm = FlutterScreenAudioPCMDataFromSampleBuffer(
            buffer,
            &sampleRate,
            &channels,
            &frames
        ), sampleRate > 0, channels > 0, frames > 0 else { return nil }

        return serialize(
            pcm as Data,
            contentType: "audio/x-pcm-s16le",
            headers: [
                "Buffer-Sample-Rate": String(sampleRate),
                "Buffer-Channels": String(channels),
                "Buffer-Frames": String(frames),
            ]
        )
    }

    private func serialize(_ body: Data, contentType: String, headers: [String: String]) -> Data? {
        let response = CFHTTPMessageCreateResponse(nil, 200, nil, kCFHTTPVersion1_1).takeRetainedValue()
        CFHTTPMessageSetHeaderFieldValue(response, "Content-Length" as CFString, String(body.count) as CFString)
        CFHTTPMessageSetHeaderFieldValue(response, "Content-Type" as CFString, contentType as CFString)
        for (key, value) in headers {
            CFHTTPMessageSetHeaderFieldValue(response, key as CFString, value as CFString)
        }
        CFHTTPMessageSetBody(response, body as CFData)
        return CFHTTPMessageCopySerializedMessage(response)?.takeRetainedValue() as Data?
    }
}
