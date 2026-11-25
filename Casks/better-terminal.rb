cask "better-terminal" do
  version "0.2.0"
  sha256 "a432935079234e32f58aa0a8cca2ec6ad2bf16e06653a1adf8188cfad2875f4a"

  url "https://github.com/mohitkap12-a11y/Better-Terminal/releases/download/v#{version}/BetterTerminal-#{version}.dmg"
  name "Better Terminal"
  desc "Modern native terminal with workspaces, pane layouts and per-tab history"
  homepage "https://github.com/mohitkap12-a11y/Better-Terminal"

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "Better Terminal.app"

  zap trash: [
    "~/Library/Application Support/BetterTerminal",
    "~/Library/Preferences/com.better.terminal.plist",
  ]
end
