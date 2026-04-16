# Hermes 技能包 — 簡報 + 服務建議書

## 包含內容

### 1. report-generator/ — 報告與簡報生成技能
- `SKILL.md` — PDF 報告生成說明（A4 直式，專業排版）
- `SKILL-presentation.md` — 簡報生成說明（16:9 橫式投影片）
- `scripts/generate-pdf.sh` — Markdown → PDF 報告
- `scripts/generate-presentation.sh` — Markdown → 簡報 PDF
- `templates/standard.html` — 報告 HTML 模板
- `templates/presentation.html` — 簡報 HTML 模板

### 2. knowledge/ — 工程投標知識
- `服務建議書編寫框架與評委攻略.md` — 完整服務建議書撰寫框架（388行）
  - 章節架構與配分攻略
  - 評委偏好與得分技巧
  - 簡報製作與答詢準備
  - 常見扣分錯誤清單

### 3. document-processing-SKILL.md — 文件轉換技能
- Markdown ↔ PDF/Word/HTML/EPUB 轉換

## 安裝方式

1. 將 `report-generator/` 資料夾複製到 Hermes 的 workspace skills 目錄
2. 將 `knowledge/` 內容放入 Hermes 可讀取的知識庫
3. 確保系統有安裝：npx playwright, npx mmdc (mermaid-cli), pandoc

## 使用範例

```bash
# 生成 PDF 報告
bash report-generator/scripts/generate-pdf.sh "input.md" "output.pdf"

# 生成簡報 PDF
bash report-generator/scripts/generate-presentation.sh "input.md" "output.pdf"
```
