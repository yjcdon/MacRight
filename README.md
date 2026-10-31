# MacRight

MacRight 是使用 Swift 编写的轻量 macOS Finder 右键工具。在当前文件夹新建文件、复制完整路径，或打开你选择的终端。

[下载最新版本](https://github.com/yjcdon/MacRight/releases/latest) · [问题反馈](https://github.com/yjcdon/MacRight/issues)

## 功能

- Finder 和桌面右键入口，每种新建文件都有对应图标。
- 新建时自动避开同名文件，并在 Finder 中选中新文件。
- 复制文件或文件夹的完整路径；多选时每行一个路径。
- “在此打开终端”：通过系统应用选择窗口自由选择终端应用，配置自动保存并即时生效。
- 新建文件和打开终端共用应用访问身份；桌面、文稿等受保护目录由 macOS 统一询问访问权限。
- 简体中文、英文界面；关闭设置窗口后，右键扩展继续工作。

新建文件固定为以下五种：

| 类型 | 扩展名 | 初始内容 |
| --- | --- | --- |
| 文本 | `.txt` | 空文件 |
| Markdown | `.md` | 空文件 |
| Word | `.docx` | 内置空白模板 |
| Excel | `.xlsx` | 内置空白模板 |
| PowerPoint | `.pptx` | 内置空白模板 |

三个 Office 模板随应用打包，不需要安装 Microsoft Office，也不依赖桌面上的模板文件。生成文件已在 WPS 中验证可正常打开。

## 下载与安装

当前版本：**v0.1.3**。发布包为 **Apple Silicon（arm64）**，最低部署版本为 **macOS 13 Ventura**；实际运行验证环境为 macOS 27.2 / Apple Silicon。尚未在 macOS 13 实机、Intel Mac、云盘及网络卷完成验证。

### Homebrew

```sh
brew tap yjcdon/macright https://github.com/yjcdon/MacRight
brew install --cask yjcdon/macright/macright
```

如果 Homebrew 提示尚未信任此安装项，先执行以下命令，再重新安装：

```sh
brew trust --cask yjcdon/macright/macright
```

已手动安装相同版本时，可使用 `brew install --cask --adopt yjcdon/macright/macright` 接管内容完全相同的现有应用；内容不同时 Homebrew 会拒绝接管。

升级与卸载：

```sh
brew update
brew upgrade --cask yjcdon/macright/macright
brew uninstall --cask yjcdon/macright/macright
```

安装后打开 MacRight，按指引启用 Finder 扩展。Homebrew 与手动下载使用相同的 Release ZIP 和 SHA-256，普通卸载保留终端偏好及目录授权数据。

### 手动下载

1. 在 [Releases](https://github.com/yjcdon/MacRight/releases/latest) 下载 `MacRight-0.1.3-macos-arm64.zip`，解压后将 `MacRight.app` 拖入“应用程序”。
2. 打开 MacRight，点击“扩展设置…”，在系统设置中启用 MacRight Finder 扩展。不同 macOS 版本的设置位置可能不同。
3. 回到 Finder，在文件夹空白处或项目上右键使用。

当前发布包使用 Apple Development 证书签名，未经 Developer ID 签名或 Apple 公证。如果 macOS 阻止启动，请先确认下载来源，并参考 Apple 的[安全打开 App 说明](https://support.apple.com/zh-cn/102445)，在“系统设置 → 隐私与安全性”中处理提示。

从旧版临时签名升级后，macOS 可能再次请求桌面等受保护目录的访问权限；请按实际使用选择允许。

Release 同时提供 `.sha256` 文件，可在下载目录校验：

```sh
shasum -a 256 -c MacRight-0.1.3-macos-arm64.zip.sha256
```

## 使用方式

点击“在此打开终端”会直接将 Finder 本次目标目录交给所选终端；随应用打包的后台启动器负责执行，完成后退出。新建文件与打开终端由同一后台组件执行，复用 macOS 对该组件的目录访问决定。新建文件直接使用 Finder 目标目录。Office 文件直接复制内置模板，原模板不会被修改。

多选时可一次复制所有完整路径，每行一个。新建文件自动避开重名并选中新文件。关闭最后一个指引窗口即退出主应用，右键扩展独立运行，不会自动添加登录项。

在主应用在终端应用分组点击“选择…”即可选择已安装的 `.app`，默认使用系统 Terminal。所选应用需要支持 macOS 的目录打开请求；已验证系统 Terminal 和 Ghostty。取消选择会保留原配置，移动或卸载所选应用后需重新选择。

出现重复右键菜单时，请在系统设置中停用重复的 Finder 扩展。MacRight 仅提供右键入口，不添加 Finder 工具栏按钮。

## 本地构建

需要 macOS、Swift 6 编译器及 macOS SDK，可使用 Xcode Command Line Tools，无第三方依赖。

```sh
bash scripts/verify.sh
bash scripts/build.sh
bash scripts/install.sh
```

构建产物位于 `build/arm64/MacRight.app`，安装脚本安装到 `/Applications/MacRight.app`，替换的旧版本保存在废纸篓。本地构建默认使用钥匙串中唯一的 Apple Development 证书，让更新前后的隐私权限具有稳定应用身份。存在多个证书或使用其他签名身份时，通过 `MACRIGHT_SIGN_IDENTITY` 指定；临时构建可显式设置为 `-` 使用 ad-hoc 签名，其权限可能在更新后需要重新允许。当前完成运行验证的架构是 Apple Silicon，部署目标为 macOS 13，实际验证系统及剩余事项见验证记录。

发布包生成命令：

```sh
bash scripts/package.sh
```

ZIP 与 SHA-256 文件位于 `dist/`。当前构建未经 Developer ID 公证，不将本地签名校验等同于公证或所有系统上的兼容性验证。

Homebrew 安装定义维护在 [Casks/macright.rb](Casks/macright.rb)。每次发布新版时，同步更新其中的 `version` 与 Release ZIP 的 `sha256`；`livecheck` 仅检查最新 Release，不自动更新安装定义。

构建目录中的 `.app` 也可能被系统索引。安装后可将 `build/arm64/MacRight.app` 移入废纸篓，保留“应用程序”中的正式副本；再次打包前需重新构建。

## 设计与验证

- [产品方案](docs/01-产品方案.md)
- [技术方案](docs/02-技术方案.md)
- [任务清单](docs/03-任务清单.md)
- [验证记录](docs/04-验证记录.md)
- [资源来源与校验](Resources/README.md)

已验证五种文件真实右键创建、Office 模板字节一致及 WPS 打开、Ghostty 目录启动、重名避让、主程序退出及 Finder 重启后的授权复用；多选复制路径经用户实测通过。受保护目录访问拒绝、菜单切换和卷变化的完整界面回归仍待补齐，详见验证记录。

本机短时采样中，右键扩展约占 8.8 MiB 物理内存、空闲 CPU 为 0%；这不是跨设备性能保证或长期内存泄漏测试。

许可采用 [GNU GPL v3](LICENSE)，资源归属说明见 [NOTICE](NOTICE)。
