import Foundation
import OSLog
import ReplayKit

private let broadcastLogger = Logger(subsystem: "ru.boohtacord.app", category: "ScreenShareExtension")

private enum ExtensionConfiguration {
    static let appGroupIdentifier = "group.ru.boohtacord.app"
    static let socketName = "rtc_SSFD"
}

final class SampleHandler: RPBroadcastSampleHandler {
    private var clientConnection: SocketConnection?
    private var uploader: SampleUploader?
    private var connectionTimer: DispatchSourceTimer?
    private var isFinishing = false

    private var socketFilePath: String? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: ExtensionConfiguration.appGroupIdentifier)?
            .appendingPathComponent(ExtensionConfiguration.socketName)
            .path
    }

    override init() {
        super.init()
        guard let socketFilePath, let connection = SocketConnection(filePath: socketFilePath) else {
            return
        }
        clientConnection = connection
        uploader = SampleUploader(connection: connection)
        connection.didClose = { [weak self] error in
            broadcastLogger.error("Broadcast socket closed: \(String(describing: error), privacy: .public)")
            guard let self, !self.isFinishing else { return }
            let code = 10001
            let message = error?.localizedDescription ?? "Screen sharing stopped"
            self.finishBroadcastWithError(
                NSError(domain: RPRecordingErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
            )
        }
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        DarwinNotificationCenter.shared.postNotification(.broadcastStarted)
        openConnection()
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        isFinishing = true
        connectionTimer?.cancel()
        connectionTimer = nil
        DarwinNotificationCenter.shared.postNotification(.broadcastStopped)
        clientConnection?.close()
        uploader = nil
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            uploader?.send(sample: sampleBuffer, type: .video)
        case .audioApp:
            // Broadcast app playback only. The screen-share audio track must never include the mic.
            uploader?.send(sample: sampleBuffer, type: .audioApp)
        case .audioMic:
            break
        @unknown default:
            break
        }
    }

    private func openConnection() {
        guard let clientConnection else { return }
        let queue = DispatchQueue(label: "ru.boohtacord.broadcast.connect")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        connectionTimer = timer
        timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            guard self?.clientConnection?.open() == true else { return }
            self?.connectionTimer?.cancel()
            self?.connectionTimer = nil
        }
        timer.resume()
    }
}
