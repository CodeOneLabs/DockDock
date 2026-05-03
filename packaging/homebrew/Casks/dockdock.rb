cask "dockdock" do
  version "0.1.6"
  sha256 "74f82baf18d25b8c659b40410b4c313611433532d3481dce4dd78efbcf81c22c"

  url "https://github.com/CodeOneLabs/DockDock/releases/download/v#{version}/DockDock-#{version}.zip"
  name "DockDock"
  desc "Open the auto-hidden macOS Dock before the pointer reaches the last screen pixel"
  homepage "https://github.com/CodeOneLabs/DockDock"

  app "DockDock.app"

  zap trash: [
    "~/Library/Preferences/com.local.DockDock.plist",
  ]
end
