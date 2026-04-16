#!/usr/bin/env python3
"""Post-process SVG: ensure white backgrounds + dark text for readability"""
import sys, re

svg_file = sys.argv[1]
with open(svg_file) as f:
    content = f.read()

# 1. Fix global CSS fill in <style> blocks: change fill:#000000 to fill:#1a1a1a (for text)
#    but this won't affect background - backgrounds use explicit fill attributes
content = re.sub(r'(#my-svg\s*\{[^}]*?)fill:\s*#000000;', r'\1fill:#1a1a1a;', content)

# 2. Ensure background rect stays white
content = re.sub(r'(class="background"\s+fill=")([^"]*)"', r'\1#ffffff"', content)

# 3. Ensure SVG root background-color is white
content = re.sub(r'(background-color:\s*)(white|#[0-9a-fA-F]+)', r'\1white', content)

# 4. Fix text elements to dark color (handle both attribute and style)
def fix_text_fill(match):
    tag = match.group(0)
    # Replace fill attribute on text/tspan
    tag = re.sub(r'fill="[^"]*"', 'fill="#1a1a1a"', tag)
    return tag

content = re.sub(r'<text[^>]*>', fix_text_fill, content)
content = re.sub(r'<tspan[^>]*>', fix_text_fill, content)

# 5. Fix foreignObject div text colors (mindmap uses these)
# Use negative lookbehind to avoid matching "background-color"
content = re.sub(r'(?<!background-)(color:\s*)(?:white|#fff(?:fff)?|rgb\(255,\s*255,\s*255\))', r'\1#1a1a1a', content)

# 5b. Force ALL divs inside foreignObject to have dark text
# Mindmap nodes use <div> with various color settings - force them all to black
content = re.sub(r'(<div[^>]*style="[^"]*?)(?:color:\s*[^;"]+)', r'\1color:#1a1a1a', content)
# For divs without inline color, add it
content = re.sub(r'(<section[^>]*style="[^"]*?)(?:color:\s*[^;"]+)', r'\1color:#1a1a1a', content)

# 5c. Also fix any span elements with light colors
content = re.sub(r'(<span[^>]*style="[^"]*?)(?:color:\s*(?:white|#[fF]{3,6}|rgb\(2[0-5]\d,\s*2[0-5]\d,\s*2[0-5]\d\)))', r'\1color:#1a1a1a', content)

# 6. For pie/xychart - fix the state-start fill that creates dark circles
content = re.sub(r'(\.state-start\s*\{\s*fill:\s*)#000000', r'\1#2a6496', content)

with open(svg_file, 'w') as f:
    f.write(content)
