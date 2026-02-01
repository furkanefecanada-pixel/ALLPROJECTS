import UIKit
import Flutter
import WidgetKit

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {

  let appGroupId = "group.com.efeapps.hydrodaily"
  let channelName = "hydrodaily/appgroup"
  let sharedKey = "text_from_flutter_app"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }

      switch call.method {

      case "setShared":
        guard
          let args = call.arguments as? [String: Any],
          let key = args["key"] as? String,
          let value = args["value"] as? String
        else {
          result(
            FlutterError(
              code: "bad_args",
              message: "Invalid arguments",
              details: nil
            )
          )
          return
        }

        self.mergeAndWriteSharedJSON(newJsonString: value, forKey: key)

        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadTimelines(ofKind: "MyHomeWidget")
          WidgetCenter.shared.reloadAllTimelines()
        }

        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - JSON merge (App Group)

  private func mergeAndWriteSharedJSON(newJsonString: String, forKey key: String) {
    guard let defs = UserDefaults(suiteName: appGroupId) else { return }

    var merged: [String: Any] = [:]

    if
      let oldStr = defs.string(forKey: key),
      let oldData = oldStr.data(using: .utf8),
      let oldObj = try? JSONSerialization.jsonObject(with: oldData) as? [String: Any]
    {
      merged = oldObj
    }

    if
      let newData = newJsonString.data(using: .utf8),
      let newObj = try? JSONSerialization.jsonObject(with: newData) as? [String: Any]
    {
      for (k, v) in newObj {
        merged[k] = v
      }
    }

    if
      let finalData = try? JSONSerialization.data(withJSONObject: merged, options: []),
      let finalStr = String(data: finalData, encoding: .utf8)
    {
      defs.setValue(finalStr, forKey: key)
      defs.synchronize()
    }
  }
}
