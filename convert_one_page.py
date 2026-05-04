"""
Convert a single page's ADF JSON file to Notion markdown.
Usage: python3 convert_one_page.py <input_adf.json> <output_notion.md>
"""
import json
import sys
sys.path.insert(0, "/workspace")
from adf_to_notion import adf_to_notion_markdown

if len(sys.argv) < 3:
    print("Usage: python3 convert_one_page.py <input.json> <output.md>")
    sys.exit(1)

with open(sys.argv[1], "r") as f:
    data = json.load(f)

body = data.get("body", data)
result = adf_to_notion_markdown(body)

with open(sys.argv[2], "w") as f:
    f.write(result)

print(f"Converted {sys.argv[1]} -> {sys.argv[2]} ({len(result)} chars)")
