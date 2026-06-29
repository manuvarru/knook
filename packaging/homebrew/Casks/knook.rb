cask "knook" do
  version "0.3.1"
  sha256 "23c55261080954c2b5cd0d15b098592862d6f745592972a9ce3cc1e66c4c8fba"

  url "https://github.com/manuvarru/knook/releases/download/v#{version}/knook-#{version}.dmg"
  name "Knook Ita"
  desc "Fork italiano di knook per promemoria pausa su macOS"
  homepage "https://github.com/manuvarru/knook"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "Knook Ita.app"

  zap trash: [
    "~/Library/Application Support/knook-ita",
    "~/Library/Application Support/knook",
    "~/Library/Application Support/nook",
    "~/Library/Application Support/Nook",
    "~/Library/Preferences/io.github.manuvarru.knook-ita.plist",
    "~/Library/Saved Application State/io.github.manuvarru.knook-ita.savedState",
    "~/Library/Preferences/io.github.preetsuthar17.knook.plist",
    "~/Library/Saved Application State/io.github.preetsuthar17.knook.savedState",
  ]
end
