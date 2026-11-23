import AppKit

enum AppIcon {
    /// Makes sure the Dock and the in-app logo show the icon even when the asset-catalog icon is not picked up
    /// (for example a fresh Xcode run before the icon cache refreshes).
    static func install() {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = image
        } else if let image = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = image
        }
    }
}
