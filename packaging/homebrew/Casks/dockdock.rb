cask "dockdock" do
  version "0.1.2"
  sha256 "310a6b539b7047e6f68d0b8e564f85b6440675a68ab04d342001026dd2ce5e3e"

  url "https://github.com/CodeOneLabs/DockDock/releases/download/v#{version}/DockDock-#{version}.zip"
  name "DockDock"
  desc "Open the auto-hidden macOS Dock before the pointer reaches the last screen pixel"
  homepage "https://github.com/CodeOneLabs/DockDock"

  app "DockDock.app"

  zap trash: [
    "~/Library/Preferences/com.local.DockDock.plist",
  ]
end
