cask "better-terminal" do
  version "0.1.0"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/mohitkap12-a11y/Better-Terminal/releases/download/v#{version}/BetterTerminal-#{version}.dmg"
  name "Better Terminal"
  desc "Modern native terminal with workspaces, pane layouts and per-tab history"
  homepage "https://github.com/mohitkap12-a11y/Better-Terminal"

  depends_on macos: ">= :sonoma"

  app "Better Terminal.app"

  zap trash: [
    "~/Library/Application Support/BetterTerminal",
    "~/Library/Preferences/com.better.terminal.plist",
  ]
end
