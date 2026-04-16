---
name: document-processing
description: "文書處理與格式轉換。支援 Markdown、PDF、Excel、Word、HTML、圖片等格式的轉換和處理。當用戶要求轉檔、匯出報告、處理表格、生成 PDF 時使用。"
---

# 文書處理與格式轉換技能

## 可用工具

### 1. Pandoc（已安裝）— 萬能文件轉換器
```bash
# Markdown → PDF（需配合 Playwright）
pandoc input.md -o output.html --standalone && # 再用瀏覽器轉 PDF

# Markdown → HTML
pandoc input.md -o output.html --standalone --metadata title="報告標題"

# Markdown → Word (.docx)
pandoc input.md -o output.docx

# Word → Markdown
pandoc input.docx -o output.md

# HTML → Markdown
pandoc input.html -o output.md -f html -t markdown

# Markdown → EPUB
pandoc input.md -o output.epub --metadata title="書名"
```

### 2. PDF 生成（Playwright，已安裝）
```bash
# 最佳 PDF 生成方式：HTML → PDF（支援中文、圖表、美觀排版）
bash /Users/halu_1/openClaw/agent-skills/report-generator/scripts/generate-pdf.sh input.md output.pdf
```

### 3. Excel 處理（Python，已安裝）
```python
# 讀取 Excel (.xlsx)
import openpyxl
wb = openpyxl.load_workbook('file.xlsx')
ws = wb.active
for row in ws.iter_rows(values_only=True):
    print(row)

# 讀取舊版 Excel (.xls)
import xlrd
wb = xlrd.open_workbook('file.xls')

# 寫入 Excel
wb = openpyxl.Workbook()
ws = wb.active
ws.append(['標題1', '標題2', '標題3'])
ws.append([100, 200, 300])
wb.save('output.xlsx')

# CSV → Excel
import csv
wb = openpyxl.Workbook()
ws = wb.active
with open('data.csv') as f:
    for row in csv.reader(f):
        ws.append(row)
wb.save('output.xlsx')
```

### 4. 圖片處理（Pillow，已安裝）
```python
from PIL import Image
# 調整大小
img = Image.open('input.png')
img = img.resize((800, 600))
img.save('output.png')

# 格式轉換
img = Image.open('input.png')
img.save('output.jpg', 'JPEG', quality=85)

# 截圖轉 PDF
images = [Image.open(f) for f in ['page1.png', 'page2.png']]
images[0].save('output.pdf', save_all=True, append_images=images[1:])
```

### 5. Mermaid 圖表（mmdc，已安裝）
```bash
# Mermaid 語法 → PNG
echo 'graph TD; A-->B' | mmdc -i - -o output.png -t neutral -b white

# Mermaid 語法 → SVG
mmdc -i diagram.mmd -o output.svg -t neutral -b white
```

### 6. 影片/音訊（ffmpeg，已安裝）
```bash
# 影片轉換格式
ffmpeg -i input.mp4 -c:v libx264 output.mp4

# 提取音訊
ffmpeg -i video.mp4 -vn -acodec mp3 audio.mp3

# 影片轉 GIF
ffmpeg -i input.mp4 -vf "fps=10,scale=320:-1" output.gif
```

## 檔案傳送到 Telegram
產出檔案後，使用 Hermes 的 message tool 傳送：
- 小檔案（<20MB）直接傳送
- 報告優先傳 PDF 格式（手機閱讀最佳）
- 表格數據傳 Excel 格式
