import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var cameraAvailabilityChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard
      let registrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "FlashImCameraAvailability"
      )
    else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "flash_im/camera",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "isCameraAvailable" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(UIImagePickerController.isSourceTypeAvailable(.camera))
    }
    cameraAvailabilityChannel = channel
  }
}
