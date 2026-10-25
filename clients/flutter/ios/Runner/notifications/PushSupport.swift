import Flutter
import UserNotifications

final class PushSupport: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "boohtacord/notifications", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(PushSupport(), channel: channel)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "clearRemoteCards" else { result(FlutterMethodNotImplemented); return }
    let arguments = call.arguments as? [String: Any]
    guard let binding = arguments?["binding_ref"] as? String else { result(nil); return }
    UNUserNotificationCenter.current().getDeliveredNotifications { cards in
      let ids = cards.filter {
        guard let text = $0.request.content.userInfo["boohtacord"] as? String,
          let data = text.data(using: .utf8),
          let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return false }
        return payload["binding_ref"] as? String == binding
      }.map { $0.request.identifier }
      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
      DispatchQueue.main.async { result(nil) }
    }
  }
}
