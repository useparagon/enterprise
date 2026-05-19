"""
Read a Confluence API response JSON from a file, extract the ADF body,
convert to Notion markdown, and write to output file.
Usage: python3 process_adf_response.py <response.json> <output.md>
"""
import json
import sys
sys.path.insert(0, "/workspace")
from adf_to_notion import adf_to_notion_markdown

if len(sys.argv) < 3:
    print("Usage: python3 process_adf_response.py <response.json> <output.md>")
    sys.exit(1)

with open(sys.argv[1], "r") as f:
    data = json.load(f)

body = data.get("body", data)
title = data.get("title", "unknown")
result = adf_to_notion_markdown(body)

with open(sys.argv[2], "w") as f:
    f.write(result)

print(f"Converted: {title} -> {sys.argv[2]} ({len(result)} chars)")
