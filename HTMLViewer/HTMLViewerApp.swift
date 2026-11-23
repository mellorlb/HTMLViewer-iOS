import SwiftUI
import UIKit

@main
struct HTMLViewerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var library = SiteLibrary()
    @StateObject private var sharing = LANShareManager()
    @StateObject private var downloads = DownloadLibrary()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .environmentObject(sharing)
                .environmentObject(downloads)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationControl.allowed
    }
}

enum OrientationControl {
    static var allowed: UIInterfaceOrientationMask = .allButUpsideDown

    @MainActor
    static func apply(_ preference: SiteOrientation) {
        switch preference {
        case .automatic: allowed = .allButUpsideDown
        case .portrait: allowed = .portrait
        case .landscape: allowed = .landscape
        }

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            if #available(iOS 16.0, *) {
                windowScene.requestGeometryUpdate(
                    UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: allowed)
                ) { error in
                    // Multitasking and device restrictions may reject orientation requests.
                    NSLog("Orientation update was not applied: %@", error.localizedDescription)
                }
            }
        }
    }
}
