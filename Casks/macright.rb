cask "macright" do
  version "0.1.3"
  sha256 "2e3d9eabaf76c5a386b12380655b6a574c4fa8985a6435e7b7dbaf2d0145fef6"

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
