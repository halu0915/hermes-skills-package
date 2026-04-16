#!/bin/bash
# Report PDF Generator with Mermaid support
# Usage: ./generate-pdf.sh <input.md> [output.pdf] [template]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$SKILL_DIR/templates"
PLAYWRIGHT_DIR="/Users/halu_1/openClaw/workspaces/intelligence/skills/browser-automation"

INPUT="$1"
OUTPUT="${2:-${INPUT%.md}.pdf}"
TEMPLATE="${3:-standard}"

if [ -z "$INPUT" ] || [ ! -f "$INPUT" ]; then
  echo "Usage: $0 <input.md> [output.pdf] [template]"
  exit 1
fi

TEMPLATE_FILE="$TEMPLATE_DIR/${TEMPLATE}.html"
TITLE=$(grep -m1 '^# ' "$INPUT" | sed 's/^# //')
[ -z "$TITLE" ] && TITLE=$(basename "$INPUT" .md)

TEMP_DIR=$(mktemp -d)

# Step 1: Pre-process Mermaid blocks - convert to SVG images
python3 << 'PYEOF' - "$INPUT" "$TEMP_DIR"
import sys, re, subprocess, os

input_file = sys.argv[1]
temp_dir = sys.argv[2]

with open(input_file) as f:
    content = f.read()

# Find all mermaid code blocks and replace with SVG images
mermaid_pattern = re.compile(r'```mermaid\n(.*?)```', re.DOTALL)
count = 0

def replace_mermaid(match):
    global count
    count += 1
    mermaid_code = match.group(1).strip()
    mmd_file = os.path.join(temp_dir, f'mermaid_{count}.mmd')
    svg_file = os.path.join(temp_dir, f'mermaid_{count}.svg')

    with open(mmd_file, 'w') as f:
        f.write(mermaid_code)

    # Create custom theme config for better contrast
    config_file = os.path.join(temp_dir, 'mermaid-config.json')
    with open(config_file, 'w') as cf:
        cf.write('''{
  "theme": "base",
  "themeVariables": {
    "primaryColor": "#dce8f5",
    "primaryTextColor": "#1a3a5c",
    "primaryBorderColor": "#2a6496",
    "lineColor": "#2a6496",
    "secondaryColor": "#e8f4fd",
    "secondaryTextColor": "#1a3a5c",
    "tertiaryColor": "#f0f7ff",
    "tertiaryTextColor": "#1a3a5c",
    "noteBkgColor": "#fff8e1",
    "noteTextColor": "#333333",
    "nodeBorder": "#2a6496",
    "clusterBkg": "#f0f7ff",
    "clusterBorder": "#2a6496",
    "titleColor": "#1a3a5c",
    "edgeLabelBackground": "#ffffff",
    "pie1": "#1a3a5c",
    "pie2": "#2a6496",
    "pie3": "#4a90c4",
    "pie4": "#6db3e8",
    "pie5": "#94c9f0",
    "pie6": "#bddcf5",
    "pie7": "#d6ebfa",
    "pie8": "#eaf4fd",
    "pieTitleTextSize": "16px",
    "pieTitleTextColor": "#1a3a5c",
    "pieSectionTextSize": "13px",
    "pieSectionTextColor": "#ffffff",
    "pieOuterStrokeColor": "#1a3a5c",
    "pieOuterStrokeWidth": "2px",
    "fontFamily": "PingFang TC, Noto Sans TC, Helvetica Neue, sans-serif",
    "fontSize": "13px"
  }
}''')

    # Use colorful config for pie charts, neutral for others
    pie_config = '/Users/halu_1/openClaw/agent-skills/report-generator/scripts/mermaid-pie-config.json'
    is_pie = 'pie ' in mermaid_code or 'pie\n' in mermaid_code

    # Output as PNG for reliable rendering (SVG has color issues when embedded in HTML→PDF)
    png_file = os.path.join(temp_dir, f'mermaid_{count}.png')

    try:
        cmd = ['mmdc', '-i', mmd_file, '-o', png_file, '-t', 'neutral', '-b', 'white', '-w', '800', '-H', '600']
        if is_pie and os.path.exists(pie_config):
            cmd = ['mmdc', '-i', mmd_file, '-o', png_file, '-t', 'default', '-b', 'white', '-w', '800', '-H', '600', '-c', pie_config]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0 and os.path.exists(png_file):
            import base64
            with open(png_file, 'rb') as pf:
                png_b64 = base64.b64encode(pf.read()).decode()
            return f'<div style="text-align:center;margin:20px 0;padding:16px;background:#ffffff;border-radius:8px;"><img src="data:image/png;base64,{png_b64}" style="max-width:100%;height:auto;" /></div>'
    except Exception as e:
        print(f"Mermaid conversion failed for block {count}: {e}", file=sys.stderr)

    return f'<pre><code>{mermaid_code}</code></pre>'

processed = mermaid_pattern.sub(replace_mermaid, content)

output_file = os.path.join(temp_dir, 'processed.md')
with open(output_file, 'w') as f:
    f.write(processed)

print(f"Processed {count} mermaid blocks")
PYEOF

# Step 2: Convert processed markdown to HTML
PROCESSED_MD="$TEMP_DIR/processed.md"
[ ! -f "$PROCESSED_MD" ] && PROCESSED_MD="$INPUT"

BODY_HTML=$(pandoc "$PROCESSED_MD" -f markdown -t html5 --wrap=none 2>/dev/null)

# Step 3: Build final HTML with template
TEMP_HTML="$TEMP_DIR/report.html"

python3 << PYEOF
import re

with open('$TEMPLATE_FILE') as f:
    template = f.read()

body = """$BODY_HTML"""

# Replace placeholders
result = template.replace('{{TITLE}}', """$TITLE""")
result = result.replace('{{CONTENT}}', body)

with open('$TEMP_HTML', 'w') as f:
    f.write(result)
PYEOF

# Step 4: Convert HTML to PDF using Playwright
cd "$PLAYWRIGHT_DIR"
node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto('file://$TEMP_HTML', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(1000);
  await page.pdf({
    path: '$OUTPUT',
    format: 'A4',
    margin: { top: '20mm', bottom: '25mm', left: '15mm', right: '15mm' },
    printBackground: true,
    displayHeaderFooter: true,
    headerTemplate: '<div></div>',
    footerTemplate: '<div style=\"font-size:9px;color:#999;width:100%;text-align:center;padding:0 20px;\"><span class=\"pageNumber\"></span> / <span class=\"totalPages\"></span></div>'
  });
  await browser.close();
  console.log('PDF generated: $OUTPUT');
})();
" 2>&1

rm -rf "$TEMP_DIR"
