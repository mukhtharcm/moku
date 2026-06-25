import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var importChannel: FlutterMethodChannel?
  private var pendingImportPaths: [String] = []

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    configureImportChannelIfNeeded()
    receiveImportURLs(connectionOptions.urlContexts.map { $0.url })
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    configureImportChannelIfNeeded()
    receiveImportURLs(URLContexts.map { $0.url })
  }

  private func configureImportChannelIfNeeded() {
    guard importChannel == nil,
          let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.moku/imports",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result([])
        return
      }

      switch call.method {
      case "takePendingImportPaths":
        let paths = self.pendingImportPaths
        self.pendingImportPaths.removeAll()
        result(paths)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    importChannel = channel
  }

  private func receiveImportURLs(_ urls: [URL]) {
    guard !urls.isEmpty else { return }

    let copiedPaths = urls.compactMap { copyImportURL($0) }
    guard !copiedPaths.isEmpty else { return }

    pendingImportPaths.append(contentsOf: copiedPaths)
    configureImportChannelIfNeeded()
    importChannel?.invokeMethod("importsAvailable", arguments: nil)
  }

  private func copyImportURL(_ url: URL) -> String? {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
      if didAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let fileManager = FileManager.default
    let importsDirectory = fileManager.temporaryDirectory
      .appendingPathComponent("moku_incoming", isDirectory: true)
    let originalName = url.lastPathComponent.isEmpty ? "book" : url.lastPathComponent
    let destination = importsDirectory
      .appendingPathComponent("\(UUID().uuidString)-\(originalName)")

    do {
      try fileManager.createDirectory(
        at: importsDirectory,
        withIntermediateDirectories: true
      )

      var copiedPath: String?
      var coordinationError: NSError?
      NSFileCoordinator(filePresenter: nil).coordinate(
        readingItemAt: url,
        options: [],
        error: &coordinationError
      ) { coordinatedURL in
        do {
          if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
          }
          try fileManager.copyItem(at: coordinatedURL, to: destination)
          copiedPath = destination.path
        } catch {
          NSLog("Moku failed to copy imported file: \(error.localizedDescription)")
        }
      }

      if let coordinationError = coordinationError {
        NSLog("Moku failed to coordinate imported file: \(coordinationError.localizedDescription)")
      }
      return copiedPath
    } catch {
      NSLog("Moku failed to prepare imported file: \(error.localizedDescription)")
      return nil
    }
  }
}
