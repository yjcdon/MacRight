cask "macright" do
  version "0.1.1"
  sha256 "b2587b5baf20dd7c264bb9c56cc7bed35ab9c9112eb6fadc8495af97c54d123c"

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
