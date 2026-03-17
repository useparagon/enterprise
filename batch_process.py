#!/usr/bin/env python3
"""Batch process all Confluence pages: write raw bodies to files and transform them."""
import json
import os
import sys

sys.path.insert(0, '/workspace')
from transform_confluence import transform_page

MAPPING = {
    "1080524856": "32661d1e-b9a8-81bb-acc3-e0f52c003169",
    "1425866753": "32661d1e-b9a8-812f-a0de-f0eac69695c5",
    "1473609730": "32661d1e-b9a8-8107-8b04-c8854bab6dd9",
    "1308917761": "32661d1e-b9a8-8131-a7be-c1f1b4229a25",
    "758546433": "32661d1e-b9a8-8145-af75-ce931e6707ef",
    "1548517382": "32661d1e-b9a8-8177-a125-c3bd7a71c475",
    "1459191809": "32661d1e-b9a8-81a1-bbce-c766df745cca",
    "1523154945": "32661d1e-b9a8-817e-9040-ca8138c4dc68",
    "613351425": "32661d1e-b9a8-8162-85a4-f75e358985ca",
    "996704257": "32661d1e-b9a8-81af-b884-e39762c8aea4",
    "538837137": "32661d1e-b9a8-8171-939e-d84e03176dce",
    "2003599361": "32661d1e-b9a8-810a-ab0c-c86b82ce81ed",
    "2003664897": "32661d1e-b9a8-81e0-a8b7-c64fbabdae11",
    "1990524929": "32661d1e-b9a8-81b4-a183-e8f690996e76",
    "1772191745": "32661d1e-b9a8-81f6-b4a2-dd9350135961",
    "1367638017": "32661d1e-b9a8-81ca-83f3-ccb140db5ddd",
    "1367801857": "32661d1e-b9a8-8151-b64d-e62908a58860",
    "1260388353": "32661d1e-b9a8-81b9-ad4a-eba90277ece3",
    "1367867393": "32661d1e-b9a8-8183-9e10-f8647a94b315",
    "1612775425": "32661d1e-b9a8-8160-b65d-c19e7020cf4e",
    "1994981377": "32661d1e-b9a8-818a-a940-d611e33c1318",
    "1899102209": "32661d1e-b9a8-8195-9959-de61f1a08a0c",
    "1574731778": "32661d1e-b9a8-81fe-819c-f156b81d0db1",
    "1629487105": "32661d1e-b9a8-8151-801f-de0bb8cc90c0",
    "1552580610": "32661d1e-b9a8-81a0-8e18-d2a256708d7a",
    "933560321": "32661d1e-b9a8-8145-b344-f7469900c2e8",
    "1267400705": "32661d1e-b9a8-814d-84ce-d8aa1bb3ca55",
    "1067679745": "32661d1e-b9a8-81da-9326-ca2c13dc660d",
    "1543897089": "32661d1e-b9a8-81ac-b961-eba961fead88",
    "1523351553": "32661d1e-b9a8-8182-bfbf-fe9b1374404f",
    "1709178881": "32661d1e-b9a8-816f-bfdd-c5288bd64f7f",
    "1297842177": "32661d1e-b9a8-81db-939e-d454808a9579",
    "979861508": "32661d1e-b9a8-81c8-baa1-f8420d46f096",
    "1354268674": "32661d1e-b9a8-819e-bbe3-e56badb8ec25",
    "1764556801": "32661d1e-b9a8-81b3-beab-ff2f48b46e94",
    "1963130881": "32661d1e-b9a8-81ba-be7f-d311ce71b2c3",
    "1563459588": "32661d1e-b9a8-8161-a1eb-fc55103829ec",
    "1630076929": "32661d1e-b9a8-818e-bc47-cb3fd3fec0d8",
    "2032566273": "32661d1e-b9a8-8187-af4f-c1829c9e06c0",
    "2032893953": "32661d1e-b9a8-8119-b8f3-f94866c35465",
}

RAW_DIR = "/workspace/raw_pages"
CLEAN_DIR = "/workspace/clean_pages"


def process_raw_file(confluence_id):
    """Transform a raw Confluence page file into a clean Notion-ready file."""
    raw_path = os.path.join(RAW_DIR, f"{confluence_id}.md")
    clean_path = os.path.join(CLEAN_DIR, f"{confluence_id}.md")

    if not os.path.exists(raw_path):
        return False

    with open(raw_path) as f:
        body = f.read()

    result = transform_page(body)

    with open(clean_path, 'w') as f:
        f.write(result)

    return True


def process_all():
    """Process all raw files."""
    os.makedirs(CLEAN_DIR, exist_ok=True)
    processed = 0
    for cid in MAPPING:
        if process_raw_file(cid):
            processed += 1
    print(f"Processed {processed}/{len(MAPPING)} pages")


def list_pending():
    """List Confluence IDs that don't have raw files yet."""
    os.makedirs(RAW_DIR, exist_ok=True)
    pending = []
    for cid in MAPPING:
        raw_path = os.path.join(RAW_DIR, f"{cid}.md")
        if not os.path.exists(raw_path):
            pending.append(cid)
    print(json.dumps(pending))
    return pending


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'process'
    if cmd == 'pending':
        list_pending()
    elif cmd == 'process':
        process_all()
    elif cmd == 'list-mapping':
        for cid, nid in MAPPING.items():
            clean_path = os.path.join(CLEAN_DIR, f"{cid}.md")
            exists = os.path.exists(clean_path)
            print(f"{cid} -> {nid} {'READY' if exists else 'PENDING'}")
