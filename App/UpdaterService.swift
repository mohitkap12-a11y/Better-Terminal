import AppKit
import Combine
import Sparkle

/// In-app updates through Sparkle. The feed (`SUFeedURL`) is the newest GitHub release's `appcast.xml`, and every
/// update archive is verified against the EdDSA public key in `SUPublicEDKey`.
///
/// Sparkle only runs from a packaged release that carries a real public key. Local Xcode builds have none, so the
/// updater stays off there and Settings says so instead of failing.
///
/// Preview builds: a Mac with the hidden `receivePreviewBuilds` default reads `appcast-beta.xml` instead.
///
///     defaults write com.better.terminal receivePreviewBuilds -bool YES     # opt in
///     defaults delete com.better.terminal receivePreviewBuilds              # back to stable
@MainActor
final class UpdaterService: NSObject, ObservableObject, SPUUpdaterDelegate {
    nonisolated static let previewBuildsKey = "receivePreviewBuilds"

    @Published private(set) var receivesPreviewBuilds = UserDefaults.standard.bool(forKey: UpdaterService.previewBuildsKey)

    /// True when this build can check for updates (packaged app with a real `SUPublicEDKey`).
    let isAvailable: Bool
    @Published private(set) var canCheckForUpdates = false
    @Published var automaticallyChecks: Bool {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }
    @Published var automaticallyDownloads: Bool {
        didSet { controller?.updater.automaticallyDownloadsUpdates = automaticallyDownloads }
    }

    private var controller: SPUStandardUpdaterController?
    private var cancellable: AnyCancellable?

    override init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        isAvailable = Bundle.main.bundleURL.pathExtension == "app" && !key.isEmpty && !key.hasPrefix("$(") && !key.hasPrefix("__")
        automaticallyChecks = false
        automaticallyDownloads = false
        super.init()
        guard isAvailable else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        automaticallyDownloads = controller.updater.automaticallyDownloadsUpdates
        cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.canCheckForUpdates = value }
    }

    func checkForUpdates() { controller?.checkForUpdates(nil) }

    /// Leave the preview feed. Sparkle never downgrades, so the preview stays until a newer stable release.
    func stopPreviewBuilds() {
        UserDefaults.standard.removeObject(forKey: Self.previewBuildsKey)
        receivesPreviewBuilds = false
    }

    // MARK: SPUUpdaterDelegate

    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        guard UserDefaults.standard.bool(forKey: Self.previewBuildsKey) else { return nil }
        return Bundle.main.object(forInfoDictionaryKey: "BetterTerminalPreviewFeedURL") as? String
    }
}
