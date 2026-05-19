"""
Migration script: Confluence 'Enterprise Installations' → Notion Database

This script documents and supports the migration of the Confluence page
'Enterprise Installations' (https://useparagon.atlassian.net/wiki/spaces/PARAGON/pages/92733448/Enterprise+Installations)
and its 40 child pages into a Notion database.

The Confluence page uses a 'Page Properties Report' macro that dynamically
pulls properties from child pages. Each child page represents an enterprise
installation with:
  - A properties table (Last Deployment, Last Change, Cloud, Management, SSO,
    App Version, Installer Version, K8s Version, Last Changed By, Repo)
  - A service URLs table (Dashboard, Grafana links)
  - A Deployment Changelog section

The Notion database replicates this structure with:
  - Database properties matching the Confluence page properties
  - Each row linking to a child page with the full deployment changelog content

Notion Database: https://www.notion.so/5ae3c879698e408ab84b02edff0195a6
Data Source ID: collection://8da95444-8734-47e9-a76b-40e83598d353

Database Schema:
  - Name (title)
  - Last Deployment (date)
  - Last Change (date)
  - Cloud (select: AWS, Azure, GCP)
  - Management (select: Managed, Unmanaged, Self-managed)
  - SSO (select: Yes, No)
  - App Version (rich text)
  - Installer Version (rich text)
  - K8s Version (rich text)
  - Last Changed By (rich text)
  - Repo (select: enterprise, on-prem, aws-on-prem)
"""

import re
import json


def parse_date(date_str):
    """Parse date from Confluence custom date tag or plain text to ISO-8601."""
    match = re.search(r'<custom data-type="date"[^>]*>([^<]+)</custom>', date_str)
    if match:
        date_text = match.group(1).strip()
        parts = date_text.split('/')
        if len(parts) == 3:
            month, day, year = parts
            return f"{year}-{month.zfill(2)}-{day.zfill(2)}"
    plain = date_str.strip()
    if re.match(r'\d{4}-\d{2}-\d{2}', plain):
        return plain
    return None


def parse_mention(text):
    """Extract mention name from Confluence custom mention tag."""
    match = re.search(r'<custom data-type="mention"[^>]*>@([^<]+)</custom>', text)
    if match:
        return match.group(1).strip()
    return text.strip().lstrip('@')


def clean_code_value(text):
    """Remove backticks and stray quotes from inline code values."""
    return text.strip().strip('`').strip('"').strip("'")


def parse_properties_and_content(body):
    """
    Parse the properties table and remaining content from a Confluence page body.
    Returns (properties_dict, remaining_content_string).
    """
    properties = {}
    lines = body.split('\n')

    prop_pattern = re.compile(r'^\|\s*\*\*([^*]+)\*\*\s*\|\s*(.+?)\s*\|')
    separator_pattern = re.compile(r'^\|\s*---\s*\|\s*---\s*\|')

    prop_end_idx = 0
    i = 0
    while i < len(lines):
        line = lines[i].strip()

        if separator_pattern.match(line):
            i += 1
            continue

        match = prop_pattern.match(line)
        if match:
            key = match.group(1).strip()
            value = match.group(2).strip()
            properties[key] = value
            prop_end_idx = i + 1
            i += 1
            continue

        if prop_end_idx > 0 and not line.startswith('|'):
            break

        i += 1

    remaining_lines = lines[prop_end_idx:]
    content = '\n'.join(remaining_lines).strip()

    # Remove any leading separator lines left over
    while content.startswith('| --- | --- |'):
        content = content[len('| --- | --- |'):].strip()

    parsed_props = {}
    for key, value in properties.items():
        if key == 'Last Deployment':
            parsed_props['last_deployment'] = parse_date(value)
        elif key == 'Last Change':
            parsed_props['last_change'] = parse_date(value)
        elif key == 'Cloud':
            parsed_props['cloud'] = value.strip()
        elif key == 'Management':
            parsed_props['management'] = value.strip()
        elif key == 'SSO':
            parsed_props['sso'] = value.strip()
        elif key == 'App Version':
            parsed_props['app_version'] = clean_code_value(value)
        elif key == 'Installer Version':
            parsed_props['installer_version'] = clean_code_value(value)
        elif key == 'K8s Version':
            parsed_props['k8s_version'] = clean_code_value(value)
        elif key == 'Last Changed By':
            parsed_props['last_changed_by'] = parse_mention(value)
        elif key == 'Repo':
            parsed_props['repo'] = value.strip()

    return parsed_props, content


def confluence_to_notion_markdown(content):
    """Convert Confluence markdown to Notion-flavored markdown."""
    result = content

    result = re.sub(
        r'<custom data-type="date"[^>]*>([^<]+)</custom>',
        lambda m: m.group(1),
        result
    )

    result = re.sub(
        r'<custom data-type="mention"[^>]*>@([^<]+)</custom>',
        lambda m: m.group(1),
        result
    )

    result = re.sub(
        r'<custom data-type="smartlink"[^>]*>(https?://[^<]+)</custom>',
        lambda m: f'[{m.group(1)}]({m.group(1)})',
        result
    )

    result = re.sub(r'```shell\n', '```bash\n', result)

    # Remove blob: image references (Confluence-internal)
    result = re.sub(r'!\[.*?\]\(blob:.*?\)', '', result)

    return result


def build_notion_properties(parsed_props):
    """Build the Notion create-pages properties dict from parsed properties."""
    props = {}
    if 'last_deployment' in parsed_props and parsed_props['last_deployment']:
        props['date:Last Deployment:start'] = parsed_props['last_deployment']
        props['date:Last Deployment:is_datetime'] = 0
    if 'last_change' in parsed_props and parsed_props['last_change']:
        props['date:Last Change:start'] = parsed_props['last_change']
        props['date:Last Change:is_datetime'] = 0
    if 'cloud' in parsed_props:
        props['Cloud'] = parsed_props['cloud']
    if 'management' in parsed_props:
        props['Management'] = parsed_props['management']
    if 'sso' in parsed_props:
        props['SSO'] = parsed_props['sso']
    if 'app_version' in parsed_props:
        props['App Version'] = parsed_props['app_version']
    if 'installer_version' in parsed_props:
        props['Installer Version'] = parsed_props['installer_version']
    if 'k8s_version' in parsed_props:
        props['K8s Version'] = parsed_props['k8s_version']
    if 'last_changed_by' in parsed_props:
        props['Last Changed By'] = parsed_props['last_changed_by']
    if 'repo' in parsed_props:
        props['Repo'] = parsed_props['repo']
    return props


CONFLUENCE_CHILD_PAGES = [
    {"id": "1080524856", "title": "Aidentified - Enterprise"},
    {"id": "1425866753", "title": "Appsmith - Enterprise"},
    {"id": "1473609730", "title": "Boosted - Enterprise"},
    {"id": "1308917761", "title": "Brevian - Enterprise"},
    {"id": "758546433", "title": "Buildertrend - Enterprise"},
    {"id": "1548517382", "title": "Colab - Enterprise"},
    {"id": "1459191809", "title": "Copy.ai - Enterprise"},
    {"id": "1523154945", "title": "CrewAI - Enterprise"},
    {"id": "613351425", "title": "Dragos - Enterprise"},
    {"id": "996704257", "title": "Famly - Enterprise"},
    {"id": "538837137", "title": "FINTRX - Enterprise"},
    {"id": "2003599361", "title": "Five9 - EU - Enterprise"},
    {"id": "2003664897", "title": "Five9 - UK - Enterprise"},
    {"id": "1990524929", "title": "Five9 - US - Enterprise"},
    {"id": "1772191745", "title": "Five9 Non-Prod - Enterprise"},
    {"id": "1367638017", "title": "ISMS.online AP - Enterprise"},
    {"id": "1367801857", "title": "ISMS.online EU - Enterprise"},
    {"id": "1260388353", "title": "ISMS.online UK - Enterprise"},
    {"id": "1367867393", "title": "ISMS.online US - Enterprise"},
    {"id": "1612775425", "title": "Jasper - Enterprise"},
    {"id": "1994981377", "title": "Maze HQ - Enterprise"},
    {"id": "1899102209", "title": "Meisterplan - Enterprise"},
    {"id": "1574731778", "title": "MileIQ - Enterprise"},
    {"id": "1629487105", "title": "Nuwacom - Enterprise"},
    {"id": "1552580610", "title": "Observe.ai EU - Enterprise"},
    {"id": "933560321", "title": "Observe.ai Main Line - Enterprise"},
    {"id": "1267400705", "title": "Observe.ai Restricted US - Enterprise"},
    {"id": "1067679745", "title": "Paragon EU - Enterprise"},
    {"id": "1543897089", "title": "Pipedrive EU - Enterprise"},
    {"id": "1523351553", "title": "Pipedrive US - Enterprise"},
    {"id": "1709178881", "title": "Postman US - Enterprise"},
    {"id": "1297842177", "title": "Sinch - Enterprise"},
    {"id": "979861508", "title": "SoSafe - Enterprise"},
    {"id": "1354268674", "title": "Supper - Enterprise"},
    {"id": "1764556801", "title": "Swoogo - Enterprise"},
    {"id": "1963130881", "title": "Syslea - Enterprise"},
    {"id": "1563459588", "title": "Upsales - Enterprise"},
    {"id": "1630076929", "title": "Xace - Enterprise"},
    {"id": "2032566273", "title": "Zendesk EU - Enterprise"},
    {"id": "2032893953", "title": "Zendesk US - Enterprise"},
]

if __name__ == '__main__':
    print(f"Total child pages to migrate: {len(CONFLUENCE_CHILD_PAGES)}")
    print("\nConfluence Parent Page: https://useparagon.atlassian.net/wiki/spaces/PARAGON/pages/92733448/Enterprise+Installations")
    print("Notion Database: https://www.notion.so/5ae3c879698e408ab84b02edff0195a6")
    print(f"\nChild pages:")
    for page in CONFLUENCE_CHILD_PAGES:
        print(f"  - {page['title']} (Confluence ID: {page['id']})")
