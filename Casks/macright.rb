cask "macright" do
  version "0.1.0"
  sha256 "01fdaf4a48be55bc44a2e20a80c8b2285d635c82d835114e919638b5fa11298a"

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
