"""
Batch conversion helper: reads ADF JSON files from adf_pages/ directory,
converts each to Notion markdown, and writes to notion_pages/ directory.
"""
import json
import os
import sys
sys.path.insert(0, ".")
from adf_to_notion import adf_to_notion_markdown

ADF_DIR = "/workspace/adf_pages"
NOTION_DIR = "/workspace/notion_pages"

os.makedirs(NOTION_DIR, exist_ok=True)

for fname in sorted(os.listdir(ADF_DIR)):
    if not fname.endswith(".json"):
        continue
    page_id = fname.replace(".json", "")
    with open(os.path.join(ADF_DIR, fname), "r") as f:
        data = json.load(f)
    
    body = data.get("body", data)
    title = data.get("title", page_id)
    
    notion_md = adf_to_notion_markdown(body)
    
    out_path = os.path.join(NOTION_DIR, f"{page_id}.md")
    with open(out_path, "w") as f:
        f.write(notion_md)
    
    print(f"Converted: {title} ({page_id}) -> {out_path}")

print(f"\nDone. Converted {len(os.listdir(NOTION_DIR))} pages.")
