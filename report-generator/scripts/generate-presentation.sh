#!/bin/bash
# 精美簡報 PDF 生成器
# 用法：
#   bash generate-presentation.sh "input.md" "output.pdf"
#   bash generate-presentation.sh "input.html" "output.pdf"
#
# 支援 Markdown（自動轉 HTML）或直接 HTML 輸入
# 使用 presentation.html 簡報模板（16:9 橫式、漸層、卡片排版）
# Mermaid 圖表自動渲染為 PNG

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates"
TEMPLATE="$TEMPLATE_DIR/presentation.html"

INPUT="$1"
OUTPUT="$2"

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
    echo "用法：bash $0 <input.md|input.html> <output.pdf>"
    echo ""
    echo "input 可以是 .md（Markdown）或 .html（HTML 片段）"
    echo "output 必須是 .pdf"
    echo ""
    echo "Markdown 中使用以下標記來建立投影片："
    echo "  ---        分隔投影片"
    echo "  # 標題     投影片標題"
    echo "  ## 小標題   投影片小標題"
    echo ""
    echo "HTML 中直接使用 <div class=\"slide slide-content\"> 等 class"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "❌ 找不到輸入檔案：$INPUT"
    exit 1
fi

# Determine input type
EXT="${INPUT##*.}"
TEMP_DIR=$(mktemp -d)
WORK_HTML="$TEMP_DIR/presentation.html"

echo "🎨 生成精美簡報..."

if [ "$EXT" = "html" ]; then
    # Direct HTML - inject into template
    CONTENT=$(cat "$INPUT")
    TITLE=$(echo "$CONTENT" | grep -o '<h1[^>]*>[^<]*</h1>' | head -1 | sed 's/<[^>]*>//g' || echo "簡報")
    sed "s|{{TITLE}}|$TITLE|g" "$TEMPLATE" | sed "s|{{CONTENT}}|<!-- content injected -->|g" > "$WORK_HTML"
    # Replace the placeholder with actual content
    python3 -c "
import sys
template = open('$WORK_HTML', 'r').read()
content = open('$INPUT', 'r').read()
result = template.replace('<!-- content injected -->', content)
open('$WORK_HTML', 'w').write(result)
"
else
    # Markdown - convert to HTML slides
    echo "  📝 轉換 Markdown → HTML 投影片..."

    python3 -c "
import re, sys

with open('$INPUT', 'r') as f:
    md = f.read()

# Extract title
title_match = re.search(r'^#\s+(.+)', md, re.MULTILINE)
title = title_match.group(1) if title_match else '簡報'

# Process Mermaid blocks - render to PNG
import subprocess, base64, os, tempfile

mermaid_count = 0
def render_mermaid(match):
    global mermaid_count
    mermaid_count += 1
    code = match.group(1)
    mmd_file = os.path.join('$TEMP_DIR', f'mermaid_{mermaid_count}.mmd')
    png_file = os.path.join('$TEMP_DIR', f'mermaid_{mermaid_count}.png')

    with open(mmd_file, 'w') as f:
        f.write(code)

    try:
        subprocess.run(['mmdc', '-i', mmd_file, '-o', png_file, '-t', 'neutral', '-b', 'white', '-w', '800'],
                      capture_output=True, timeout=30)
        if os.path.exists(png_file):
            with open(png_file, 'rb') as f:
                b64 = base64.b64encode(f.read()).decode()
            return f'<div style=\"text-align:center;margin:15px 0\"><img src=\"data:image/png;base64,{b64}\" style=\"max-width:90%;max-height:350px;border-radius:8px\"></div>'
    except:
        pass
    return f'<pre><code>{code}</code></pre>'

md = re.sub(r'\x60\x60\x60mermaid\n(.*?)\n\x60\x60\x60', render_mermaid, md, flags=re.DOTALL)

if mermaid_count > 0:
    print(f'  Processed {mermaid_count} mermaid blocks', file=sys.stderr)

# Split by --- or # (slide separators)
# Strategy: split by '---' on its own line, or by '# ' at start of line
slides_raw = re.split(r'\n---\n', md)

html_slides = []
for slide_md in slides_raw:
    slide_md = slide_md.strip()
    if not slide_md:
        continue

    # Determine slide type
    slide_class = 'slide-content'
    if re.match(r'^#\s+.+\n\n(?:.*\n)*?(?:CORPORATE|公司簡介|封面)', slide_md, re.IGNORECASE):
        slide_class = 'slide-cover'
    elif re.match(r'^#\s+(?:聯絡|Contact|感謝|Thank)', slide_md, re.IGNORECASE):
        slide_class = 'slide-dark'

    # Convert markdown to HTML
    lines = slide_md.split('\n')
    html_lines = []
    in_table = False
    in_list = False

    for line in lines:
        # Headers
        if line.startswith('### '):
            if in_list: html_lines.append('</ul>'); in_list = False
            html_lines.append(f'<h3>{line[4:]}</h3>')
        elif line.startswith('## '):
            if in_list: html_lines.append('</ul>'); in_list = False
            html_lines.append(f'<h2>{line[3:]}</h2>')
        elif line.startswith('# '):
            if in_list: html_lines.append('</ul>'); in_list = False
            html_lines.append(f'<h1>{line[2:]}</h1>')
        # Table
        elif '|' in line and line.strip().startswith('|'):
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            if all(c.replace('-','').replace(':','') == '' for c in cells):
                continue  # separator row
            if not in_table:
                html_lines.append('<table>')
                html_lines.append('<tr>' + ''.join(f'<th>{c}</th>' for c in cells) + '</tr>')
                in_table = True
            else:
                html_lines.append('<tr>' + ''.join(f'<td>{c}</td>' for c in cells) + '</tr>')
        elif in_table and '|' not in line:
            html_lines.append('</table>')
            in_table = False
        # Bullet list
        elif line.strip().startswith('- ') or line.strip().startswith('• '):
            if not in_list:
                html_lines.append('<ul>')
                in_list = True
            content = line.strip().lstrip('-•').strip()
            # Bold
            content = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', content)
            html_lines.append(f'<li>{content}</li>')
        elif in_list and not line.strip():
            html_lines.append('</ul>')
            in_list = False
        # Blockquote
        elif line.startswith('> '):
            html_lines.append(f'<blockquote>{line[2:]}</blockquote>')
        # Empty line
        elif not line.strip():
            if in_list: html_lines.append('</ul>'); in_list = False
            html_lines.append('')
        # Already HTML (img, div, etc.)
        elif line.strip().startswith('<'):
            html_lines.append(line)
        # Regular paragraph
        else:
            content = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', line)
            html_lines.append(f'<p>{content}</p>')

    if in_table: html_lines.append('</table>')
    if in_list: html_lines.append('</ul>')

    slide_html = '\n'.join(html_lines)
    html_slides.append(f'<div class=\"slide {slide_class}\">\n<div class=\"top-bar\"></div>\n{slide_html}\n</div>')

content = '\n\n'.join(html_slides)

# Build final HTML
with open('$TEMPLATE', 'r') as f:
    template = f.read()

result = template.replace('{{TITLE}}', title).replace('{{CONTENT}}', content)

with open('$WORK_HTML', 'w') as f:
    f.write(result)

print(f'  Generated {len(html_slides)} slides', file=sys.stderr)
" 2>&1 | grep -v "^$"
fi

# Convert to PDF using Playwright
echo "  📄 生成 PDF..."

# Find playwright
PLAYWRIGHT_DIR=""
for dir in \
    "/Users/halu_1/openClaw/workspaces/intelligence/node_modules" \
    "/Users/halu_1/.hermes/hermes-agent/node_modules" \
    "/Users/halu_1/openClaw/workspaces/intelligence/skills/browser-automation/node_modules"; do
    if [ -d "$dir/playwright" ]; then
        PLAYWRIGHT_DIR="$dir"
        break
    fi
done

if [ -z "$PLAYWRIGHT_DIR" ]; then
    echo "❌ 找不到 Playwright，請先安裝"
    exit 1
fi

NODE_PATH="$PLAYWRIGHT_DIR" node -e "
const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage();
    await page.goto('file://$WORK_HTML');
    await page.waitForTimeout(2000);
    await page.pdf({
        path: '$OUTPUT',
        format: 'A4',
        landscape: true,
        printBackground: true,
        margin: { top: '0', bottom: '0', left: '0', right: '0' }
    });
    await browser.close();
    const fs = require('fs');
    const size = fs.statSync('$OUTPUT').size;
    console.log('✅ 簡報 PDF 生成完成：$OUTPUT (' + (size/1024/1024).toFixed(1) + ' MB)');
})().catch(e => { console.error('❌', e.message); process.exit(1); });
" 2>&1

# Cleanup
rm -rf "$TEMP_DIR"
