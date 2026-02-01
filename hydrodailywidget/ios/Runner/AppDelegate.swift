import UIKit
import Flutter
import WidgetKit
import UserNotifications
import Firebase
import FirebaseMessaging


@UIApplicationMain
class AppDelegate: FlutterAppDelegate {

  let appGroupId = "group.com.efeapps.hydrodaily"
  let channelName = "hydrodaily/appgroup"
  let sharedKey = "text_from_flutter_app"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Push olaylarını yakalamak için delegate
    UNUserNotificationCenter.current().delegate = self

    // İzin iste
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, error in
      if let error = error {
        print("push auth error: \(error)")
        return
      }
      if granted {
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
      } else {
        print("push permissions denied")
      }
    }

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }

      switch call.method {
      case "reloadWidget":
          if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: "MyHomeWidget")
          }
          result(true)
      case "setShared":
        guard
          let args = call.arguments as? [String: Any],
          let key = args["key"] as? String,
          let value = args["value"] as? String
        else {
          result(FlutterError(code: "bad_args",
                              message: "Invalid arguments",
                              details: nil))
          return
        }

        self.mergeAndWriteSharedJSON(newJsonString: value, forKey: key)

        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadTimelines(ofKind: "MyHomeWidget")
        }

        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }


  // 📌 Cihaz APNS token register oldu mu?
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
      let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
      print("📲 APNS TOKEN:", tokenString)
      
      Messaging.messaging().apnsToken = deviceToken 
  }


  override func application(
  _ application: UIApplication,
  didReceiveRemoteNotification userInfo: [AnyHashable : Any],
  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {

  if let note = userInfo["note"] as? String {
    let defs = UserDefaults(suiteName: appGroupId)
    let payload = "{\"note\":\"\(note)\"}"
    defs?.set(payload, forKey: sharedKey)
    defs?.synchronize()

    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadTimelines(ofKind: "MyHomeWidget")
    }
  }

  completionHandler(.newData)
}



  // MARK: - App Group JSON merge
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
