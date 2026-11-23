import AppKit
import Combine
import Sparkle

/// In-app updates through Sparkle. The stable feed (`SUFeedURL`) is the newest GitHub release's `appcast.xml`; every
/// update archive is verified against the EdDSA public key in `SUPublicEDKey`.
///
/// Channels: **Stable** (default) or **Beta**, chosen in Settings → Updates. Beta reads `appcast-beta.xml` (a fixed
/// pre-release, `BetterTerminalPreviewFeedURL`), which every beta and every stable release refreshes, so a Mac on Beta
/// also gets stable releases. Sparkle never downgrades: switching back to Stable keeps the installed beta until the
/// next stable release is newer.
///
/// Sparkle only runs from a packaged release that carries a real public key. Local Xcode builds have none, so the
/// updater stays off there and Settings says so instead of failing.
enum UpdateChannel: String, CaseIterable, Sendable {
    case stable, beta
    var title: String { self == .stable ? "Stable" : "Beta" }
}

@MainActor
final class UpdaterService: NSObject, ObservableObject, SPUUpdaterDelegate {
    /// UserDefaults flag behind the channel (also settable with `defaults write com.better.terminal receivePreviewBuilds -bool YES`).
    nonisolated static let previewBuildsKey = "receivePreviewBuilds"

    @Published var channel: UpdateChannel = UserDefaults.standard.bool(forKey: UpdaterService.previewBuildsKey) ? .beta : .stable {
        didSet { UserDefaults.standard.set(channel == .beta, forKey: Self.previewBuildsKey) }
    }

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

    // MARK: SPUUpdaterDelegate

    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        guard UserDefaults.standard.bool(forKey: Self.previewBuildsKey) else { return nil }
        return Bundle.main.object(forInfoDictionaryKey: "BetterTerminalPreviewFeedURL") as? String
    }
}
