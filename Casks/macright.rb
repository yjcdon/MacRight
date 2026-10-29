cask "macright" do
  version "0.1.2"
  sha256 "28ab11dd01ff2f54ba648bbaa2961735285302d370bc02573062ab56387e9b90"

  url "https://github.com/yjcdon/MacRight/releases/download/v#{version}/MacRight-#{version}-macos-arm64.zip"
  name "MacRight"
  desc "Finder context menu for creating files, copying paths and opening terminals"
  homepage "https://github.com/yjcdon/MacRight"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "MacRight.app"
end
