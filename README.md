# MacRight

MacRight 是使用 Swift 实现的 macOS Finder 右键工具，支持新建文件、复制完整路径和在目录打开终端。

新建文件固定为五种：文本（`.txt`）、Markdown（`.md`）、Word（`.docx`）、Excel（`.xlsx`）、PowerPoint（`.pptx`）。Office 文档直接复制内置空白模板。

**当前状态：0.1.0 功能已实现，应用已构建安装，真实界面验收待完成，尚未发布 Release。**

## 使用方式

打开 MacRight，按应用指引在系统设置中启用 Finder 扩展，然后在 Finder 或桌面右键使用。首次新建文件或打开终端时，通过系统窗口授权目标目录或其上级目录。

多选时可一次复制所有完整路径，每行一个。新建文件自动避开重名并选中新文件。关闭主应用不关闭右键功能，也不会自动添加登录项。

## 本地构建

需要 macOS、Swift 6 编译器及 macOS SDK，可使用 Xcode Command Line Tools，无第三方依赖。

```sh
bash scripts/verify.sh
bash scripts/build.sh
bash scripts/install.sh
```

构建产物位于 `build/arm64/MacRight.app`，安装脚本安装到 `/Applications/MacRight.app`，替换的旧版本保存在废纸篓。应用及扩展默认使用 ad-hoc 签名；指定身份时可使用 `MACRIGHT_SIGN_IDENTITY` 命令级环境变量。当前完成运行验证的架构是 Apple Silicon，部署目标为 macOS 13，实际验证系统及剩余事项见验证记录。

发布包生成命令：

```sh
bash scripts/package.sh
```

ZIP 与 SHA-256 文件位于 `dist/`。当前构建未经 Developer ID 公证，不将本地签名校验等同于公证或所有系统上的兼容性验证。

## 设计与验证

- [产品方案](docs/01-产品方案.md)
- [技术方案](docs/02-技术方案.md)
- [任务清单](docs/03-任务清单.md)
- [验证记录](docs/04-验证记录.md)
- [资源来源与校验](Resources/README.md)

应用图标复用现有 MacNewFile 的 AppIcon。Finder 仅提供右键入口。MacRight 与 MacNewFile 可并存；使用 MacRight 后，可在系统扩展设置中停用旧扩展以避免重复菜单。

参考项目：[GarfieldFluffJr/MacNewFile](https://github.com/GarfieldFluffJr/MacNewFile)。许可采用 [GNU GPL v3](LICENSE)，复用内容说明见 [NOTICE](NOTICE)。
