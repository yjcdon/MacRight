# MacRight 资源

## Office 模板

| 内置资源 | 用户提供的原文件 | 用途 |
| --- | --- | --- |
| `Templates/Office/Blank.docx` | `untitled.docx` | 新建 Word 文档 |
| `Templates/Office/Blank.xlsx` | `untitled.xlsx` | 新建 Excel 工作簿 |
| `Templates/Office/Blank.pptx` | `untitled.pptx` | 新建 PowerPoint 演示文稿 |

资源取自用户提供的三个空白文档，格式中记录的生成应用为 WPS。后续新建文件直接复制这些资源，不依赖用户桌面路径，也不重新拼装 Office 内部 XML。

为公开发布，仓库副本删除 `docProps/core.xml` 的作者及最后修改者字段、`docProps/custom.xml` 中的 `ICV` 文档标识，并将 Word 的生成应用描述简化为 `WPS Office`。Excel 计算设置等其他自定义属性保留。桌面原件未修改。

2026-10-25 已完成的检查：

- ZIP CRC 正常，所有 XML/关系文件可解析。
- 未发现非空正文文本、单元格值/公式、幻灯片文字、宏、批注、嵌入对象或外部关系链接。
- 清理仅涉及 manifest 列出的元数据项，其余 ZIP 条目与原件逐字节一致。
- 尚未在 WPS 或 Microsoft Office 中打开验证；该项已列入任务清单。

文件大小、原件与资源副本的 SHA-256、修改条目见 [Templates/manifest.json](Templates/manifest.json)。哈希用于固定资源版本；不是运行时可配置的任意模板目录。

## 应用图标

`Assets.xcassets/AppIcon.appiconset` 原样复制自 MacNewFile 的 `MacNewFile/Assets.xcassets/AppIcon.appiconset`，以本地提交 `9fd2a1b4a18d606701bd57fd8acca94c26b6268d` 为参考。

现有 Contents.json 为两个 512 像素文件配置了槽位。实现阶段验证构建与不同尺寸显示；需要补齐时基于同一原图生成，不改变图案。

来源：[GarfieldFluffJr/MacNewFile](https://github.com/GarfieldFluffJr/MacNewFile)，许可见仓库根目录 [LICENSE](../LICENSE) 与 [NOTICE](../NOTICE)。

