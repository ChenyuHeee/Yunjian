# 云简 icon 方案（SVG）

所有方案均为 **1024×1024**、**单色线性**（黑色描边、无填充），适合作为 App Icon 的基础稿（后续可在导出时上色/加背景）。

- `v1-doc-fold.svg`：折角文档（最“写作/文档”直觉）
- `v2-cloud-doc.svg`：云 + 文档（对应“云简”含义）
- `v2a-cloud-doc-balanced.svg`：v2 变体（更均衡、文档更清晰）
- `v2b-cloud-doc-geometric.svg`：v2 变体（更几何、识别度强）
- `v2c-cloud-doc-front.svg`：v2 变体（文档在前、层次更明显）
- `v3-y-monogram.svg`：Y 字母单线（更偏品牌/极简）
- `v4-pen-nib.svg`：笔尖（表达写作/编辑）
- `v5-lines.svg`：三行文本（表达“简洁记录”）

## 预览
VS Code 直接打开 SVG 即可预览。

## 用作 App Icon 的建议
- 如果你希望 **macOS 图标有底**：可以在导出 PNG 时加底色/渐变；这些 SVG 当前是纯线稿。
- 需要生成 `.icns` / `AppIcon.appiconset` 时，可以把 SVG 导出成 1024 PNG，再用 Xcode 的 Asset Catalog 生成多尺寸。
