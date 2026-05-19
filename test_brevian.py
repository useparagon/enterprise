"""Quick test: fetch the Brevian ADF we already have and convert it."""
import json
import sys
sys.path.insert(0, ".")
from adf_to_notion import adf_to_notion_markdown

# The ADF body from the Confluence API response - read from file
with open("/workspace/brevian_adf.json", "r") as f:
    adf = json.load(f)

result = adf_to_notion_markdown(adf)
print(result)
