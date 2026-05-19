"""
Batch processor: Fetch Confluence ADF pages, convert to Notion markdown, and
update corresponding Notion pages.

Supports two modes:
  1. API mode (default): uses Confluence REST API + Notion API
  2. Local mode: reads saved ADF JSON files from adf_pages/ directory

Usage:
  # API mode (requires ATLASSIAN_TOKEN and NOTION_TOKEN env vars)
  python process_pages.py

  # Local mode (reads from adf_pages/<confluence_id>.json)
  python process_pages.py --local

  # Save fetched ADF to disk without updating Notion
  python process_pages.py --save-adf

  # Process a single page by Confluence ID
  python process_pages.py --page 2003599361
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error

sys.path.insert(0, os.path.dirname(__file__))
from adf_to_notion import adf_to_notion_markdown


CLOUD_ID = "f25fd3e2-c93b-4c7f-bcea-d3027d2fa860"

PAGES = [
    {"confluence_id": "2003599361", "notion_id": "32661d1e-b9a8-8164-a5f7-d26fc7d89421", "title": "Five9 EU"},
    {"confluence_id": "2003664897", "notion_id": "32661d1e-b9a8-817d-950e-ca8f615ac683", "title": "Five9 UK"},
    {"confluence_id": "1990524929", "notion_id": "32661d1e-b9a8-81e5-9e1c-c71adf941772", "title": "Five9 US"},
    {"confluence_id": "1772191745", "notion_id": "32661d1e-b9a8-8194-82ab-ec46b16bfb0f", "title": "Five9 Non-Prod"},
    {"confluence_id": "1367638017", "notion_id": "32661d1e-b9a8-816c-a297-d8ed086ec139", "title": "ISMS AP"},
    {"confluence_id": "1367801857", "notion_id": "32661d1e-b9a8-8109-8994-d4546a8baab9", "title": "ISMS EU"},
    {"confluence_id": "1260388353", "notion_id": "32661d1e-b9a8-81a8-b31a-e72b663c168e", "title": "ISMS UK"},
    {"confluence_id": "1367867393", "notion_id": "32661d1e-b9a8-8198-b744-dafad9641127", "title": "ISMS US"},
    {"confluence_id": "1612775425", "notion_id": "32661d1e-b9a8-8123-a92c-e7fecc063451", "title": "Jasper"},
    {"confluence_id": "1994981377", "notion_id": "32661d1e-b9a8-8153-8087-eb92faa3596c", "title": "Maze HQ"},
]


def fetch_confluence_adf(confluence_id, token=None):
    """Fetch a Confluence page body in ADF format via REST API v2."""
    url = (
        f"https://api.atlassian.com/ex/confluence/{CLOUD_ID}"
        f"/wiki/api/v2/pages/{confluence_id}?body-format=atlas_doc_format"
    )
    req = urllib.request.Request(url)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
        adf_body = data.get("body", {}).get("atlas_doc_format", {}).get("value")
        if isinstance(adf_body, str):
            adf_body = json.loads(adf_body)
        return adf_body
    except urllib.error.HTTPError as e:
        print(f"  HTTP {e.code}: {e.reason}")
        return None
    except Exception as e:
        print(f"  Error fetching: {e}")
        return None


def load_local_adf(confluence_id):
    """Load ADF JSON from a local file."""
    path = os.path.join(os.path.dirname(__file__), "adf_pages", f"{confluence_id}.json")
    if not os.path.exists(path):
        print(f"  Local file not found: {path}")
        return None
    with open(path, "r") as f:
        return json.load(f)


def update_notion_page(notion_id, markdown_content, token=None):
    """Update a Notion page content via the Notion API."""
    url = f"https://api.notion.com/v1/pages/{notion_id}"
    payload = json.dumps({
        "command": "replace_content",
        "content": markdown_content,
    }).encode()

    req = urllib.request.Request(url, data=payload, method="PATCH")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    req.add_header("Notion-Version", "2022-06-28")

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return True
    except urllib.error.HTTPError as e:
        print(f"  Notion HTTP {e.code}: {e.reason}")
        return False
    except Exception as e:
        print(f"  Error updating Notion: {e}")
        return False


def process_page(page, local_mode=False, save_adf=False, dry_run=False):
    """Process a single page: fetch ADF, convert, update Notion."""
    cid = page["confluence_id"]
    nid = page["notion_id"]
    title = page["title"]

    print(f"\n{'='*60}")
    print(f"Processing: {title}")
    print(f"  Confluence ID: {cid}")
    print(f"  Notion ID:     {nid}")

    if local_mode:
        print("  Fetching ADF from local file...")
        adf_body = load_local_adf(cid)
    else:
        print("  Fetching ADF from Confluence API...")
        token = os.environ.get("ATLASSIAN_TOKEN")
        adf_body = fetch_confluence_adf(cid, token)

    if not adf_body:
        print("  FAILED: Could not fetch ADF body")
        return False

    if save_adf:
        adf_dir = os.path.join(os.path.dirname(__file__), "adf_pages")
        os.makedirs(adf_dir, exist_ok=True)
        adf_path = os.path.join(adf_dir, f"{cid}.json")
        with open(adf_path, "w") as f:
            json.dump(adf_body, f, indent=2)
        print(f"  Saved ADF to {adf_path}")

    print("  Converting ADF to Notion markdown...")
    notion_md = adf_to_notion_markdown(adf_body)

    if not notion_md.strip():
        print("  WARNING: Conversion produced empty markdown")
        return False

    md_dir = os.path.join(os.path.dirname(__file__), "notion_pages")
    os.makedirs(md_dir, exist_ok=True)
    md_path = os.path.join(md_dir, f"{cid}.md")
    with open(md_path, "w") as f:
        f.write(notion_md)
    print(f"  Saved markdown to {md_path}")

    preview = notion_md[:200].replace("\n", "\\n")
    print(f"  Preview: {preview}...")

    if dry_run:
        print("  DRY RUN: Skipping Notion update")
        return True

    print("  Updating Notion page...")
    notion_token = os.environ.get("NOTION_TOKEN")
    success = update_notion_page(nid, notion_md, notion_token)

    if success:
        print("  SUCCESS")
    else:
        print("  FAILED: Could not update Notion page")
    return success


def main():
    parser = argparse.ArgumentParser(description="Confluence ADF → Notion page updater")
    parser.add_argument("--local", action="store_true", help="Read ADF from local files")
    parser.add_argument("--save-adf", action="store_true", help="Save fetched ADF to disk")
    parser.add_argument("--dry-run", action="store_true", help="Convert but don't update Notion")
    parser.add_argument("--page", help="Process only this Confluence page ID")
    args = parser.parse_args()

    pages_to_process = PAGES
    if args.page:
        pages_to_process = [p for p in PAGES if p["confluence_id"] == args.page]
        if not pages_to_process:
            print(f"Page {args.page} not found in mapping")
            sys.exit(1)

    print(f"Processing {len(pages_to_process)} pages")
    if args.local:
        print("Mode: local (reading from adf_pages/)")
    else:
        print("Mode: API")
        if not os.environ.get("ATLASSIAN_TOKEN"):
            print("WARNING: ATLASSIAN_TOKEN not set - API calls may fail")
        if not os.environ.get("NOTION_TOKEN") and not args.dry_run:
            print("WARNING: NOTION_TOKEN not set - Notion updates may fail")

    results = {}
    for page in pages_to_process:
        success = process_page(
            page,
            local_mode=args.local,
            save_adf=args.save_adf,
            dry_run=args.dry_run,
        )
        results[page["title"]] = success

    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    succeeded = [t for t, s in results.items() if s]
    failed = [t for t, s in results.items() if not s]
    print(f"Total:     {len(results)}")
    print(f"Succeeded: {len(succeeded)}")
    print(f"Failed:    {len(failed)}")
    if succeeded:
        print("\nSuccessfully processed:")
        for t in succeeded:
            print(f"  ✓ {t}")
    if failed:
        print("\nFailed:")
        for t in failed:
            print(f"  ✗ {t}")


if __name__ == "__main__":
    main()
