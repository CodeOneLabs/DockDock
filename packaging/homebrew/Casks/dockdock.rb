cask "dockdock" do
  version "0.1.0"
  sha256 "REPLACE_WITH_RELEASE_ZIP_SHA256"

  url "https://github.com/jiwonsong95/DockDock/releases/download/v#{version}/DockDock-#{version}.zip"
  name "DockDock"
  desc "Open the auto-hidden macOS Dock before the pointer reaches the last screen pixel"
  homepage "https://github.com/jiwonsong95/DockDock"

  app "DockDock.app"

  zap trash: [
    "~/Library/Preferences/com.local.DockDock.plist",
  ]
end
