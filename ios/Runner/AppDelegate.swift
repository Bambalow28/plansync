import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications so notifications present while the
    // app is in the foreground on iOS 10+.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // iCloud backup: the Dart side reads/writes plain files in the app's
    // ubiquity container; this only resolves its path and kicks off downloads
    // of files another install uploaded (they sit as placeholders until asked).
    let iCloudChannel = FlutterMethodChannel(
      name: "plansync/icloud",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    iCloudChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "containerPath":
        // url(forUbiquityContainerIdentifier:) can block — keep it off the main
        // thread and hop back before replying.
        DispatchQueue.global(qos: .utility).async {
          let documents = FileManager.default
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
          if let documents = documents {
            try? FileManager.default.createDirectory(
              at: documents, withIntermediateDirectories: true)
          }
          DispatchQueue.main.async { result(documents?.path) }
        }
      case "startDownload":
        guard let path = call.arguments as? String else {
          result(FlutterError(code: "bad_args", message: "expected a path string", details: nil))
          return
        }
        DispatchQueue.global(qos: .utility).async {
          try? FileManager.default.startDownloadingUbiquitousItem(at: URL(fileURLWithPath: path))
          DispatchQueue.main.async { result(nil) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
