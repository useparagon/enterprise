#!/usr/bin/env python3
"""Transform Confluence markdown into Notion-compatible markdown.

Rules:
1. Remove the first table (properties table)
2. Convert the Service/URL table to Notion table format
3. Convert deployment changelog entries to toggle-lists with date headers
"""
import re
import sys
import json


def extract_date_from_version(text):
    """Extract a human-readable date from version strings like 2025.0527.0604-xxx."""
    months = {
        '01': 'Jan', '02': 'Feb', '03': 'Mar', '04': 'Apr',
        '05': 'May', '06': 'Jun', '07': 'Jul', '08': 'Aug',
        '09': 'Sep', '10': 'Oct', '11': 'Nov', '12': 'Dec'
    }
    patterns = [
        r'`?(\d{4})\.(\d{2})(\d{2})\.\d{4}-[a-f0-9]+`?',  # 2025.0527.0604-hash
        r'v(\d{4})\.(\d{2})(\d{2})\.\d{4}-[a-f0-9]+',       # v2025.0527.0604-hash
        r'`?(\d{4})\.(\d{2})\.(\d{2})`?',                     # installer versions like 2026.02.17
        r'v?(\d)\.(\d+)\.(\d+)',                               # old installer versions like v2.7.0
    ]
    for p in patterns:
        m = re.search(p, text)
        if m:
            groups = m.groups()
            year = groups[0]
            if len(year) == 4 and int(year) >= 2020:
                month = groups[1]
                day = groups[2]
                if month in months and 1 <= int(day) <= 31:
                    return f"{months[month]} {int(day)}, {year}"
    return None


def clean_custom_tags(text):
    """Remove Confluence custom HTML tags."""
    text = re.sub(r'<custom data-type="date" data-id="[^"]*">', '', text)
    text = re.sub(r'<custom data-type="mention" data-id="[^"]*">', '', text)
    text = re.sub(r'<custom data-type="smartlink" data-id="[^"]*">([^<]*)</custom>', r'[\1](\1)', text)
    text = text.replace('</custom>', '')
    text = re.sub(r'!\[\]\(blob:[^\)]+\)\n?', '', text)
    return text


def parse_tables_and_content(body):
    """Parse the body into: properties table, service table, remaining content."""
    body = clean_custom_tags(body)
    lines = body.split('\n')

    tables = []
    current_table = []
    in_table = False
    non_table_before = []
    non_table_after = []
    table_positions = []

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith('|') and '|' in line[1:]:
            if not in_table:
                in_table = True
                current_table = []
            current_table.append(lines[i])
        else:
            if in_table:
                tables.append(current_table)
                table_positions.append(i - len(current_table))
                current_table = []
                in_table = False
        i += 1

    if in_table:
        tables.append(current_table)

    return tables, lines


def extract_service_table(table_lines):
    """Extract Service/URL data from a markdown table."""
    rows = []
    for line in table_lines:
        line = line.strip()
        if line.startswith('| ---') or line.startswith('|---'):
            continue
        cells = [c.strip() for c in line.split('|')[1:-1]]
        if len(cells) >= 2:
            rows.append(cells)
    return rows


def build_notion_table(rows):
    """Build a Notion-compatible table from rows."""
    if not rows:
        return ""
    result = ['<table header-row="true">']
    for row in rows:
        result.append('\t<tr>')
        for cell in row:
            cell = cell.replace('**', '')
            result.append(f'\t\t<td>{cell}</td>')
        result.append('\t</tr>')
    result.append('</table>')
    return '\n'.join(result)


def parse_changelog_entries(text):
    """Parse deployment changelog text into individual entries.
    
    Entries are separated by blank lines followed by a new top-level bullet.
    Indented content (code blocks, sub-bullets) belongs to the current entry.
    """
    entries = []
    current_entry = []
    in_code_block = False
    blank_buffer = []

    for line in text.split('\n'):
        stripped = line.strip()

        if stripped.startswith('```'):
            if blank_buffer:
                current_entry.extend(blank_buffer)
                blank_buffer = []
            in_code_block = not in_code_block
            current_entry.append(line)
            continue

        if in_code_block:
            current_entry.append(line)
            continue

        if stripped == '':
            blank_buffer.append(line)
            continue

        is_top_level_bullet = stripped.startswith('* ') and not line.startswith('    ')
        is_indented = line.startswith('    ') or line.startswith('\t')

        if blank_buffer:
            if is_indented or (not is_top_level_bullet and not stripped.startswith('# ')):
                current_entry.extend(blank_buffer)
                blank_buffer = []
                current_entry.append(line)
            elif is_top_level_bullet:
                if current_entry:
                    entries.append('\n'.join(current_entry).strip())
                current_entry = [line]
                blank_buffer = []
            else:
                if current_entry:
                    entries.append('\n'.join(current_entry).strip())
                current_entry = [line]
                blank_buffer = []
        else:
            current_entry.append(line)

    if current_entry:
        result = '\n'.join(current_entry).strip()
        if result:
            entries.append(result)

    return entries


def get_entry_date(entry_text):
    """Extract a date from a changelog entry's version numbers."""
    app_patterns = [
        r'`?[v]?(\d{4}\.\d{4}\.\d{4}-[a-f0-9]+)`?',
        r'`?[v]?(\d{4}\.\d{2}\.\d{2})`?',
    ]

    for p in app_patterns:
        match = re.search(p, entry_text)
        if match:
            version = match.group(1)
            date = extract_date_from_version(version)
            if date:
                return date

    date_match = re.search(r'(\d{1,2}/\d{1,2}/\d{4})', entry_text)
    if date_match:
        return date_match.group(1)

    return None


def build_toggle(summary, content):
    """Build a Notion toggle block."""
    indented = '\n'.join('\t' + line for line in content.split('\n'))
    return f'<details>\n<summary>{summary}</summary>\n{indented}\n</details>'


def transform_page(body):
    """Transform a full Confluence page body into Notion-compatible markdown."""
    body = clean_custom_tags(body)
    body = body.replace('\u200c', '')

    lines = body.split('\n')
    tables = []
    current_table_lines = []
    in_table = False
    sections = []
    current_section = []

    for line in lines:
        stripped = line.strip()
        is_table_line = stripped.startswith('|') and '|' in stripped[1:]

        if is_table_line:
            if not in_table:
                if current_section:
                    sections.append(('text', '\n'.join(current_section)))
                    current_section = []
                in_table = True
                current_table_lines = []
            current_table_lines.append(line)
        else:
            if in_table:
                tables.append(current_table_lines)
                sections.append(('table', len(tables) - 1))
                current_table_lines = []
                in_table = False
            current_section.append(line)

    if in_table:
        tables.append(current_table_lines)
        sections.append(('table', len(tables) - 1))
    if current_section:
        sections.append(('text', '\n'.join(current_section)))

    output_parts = []
    table_count = 0
    changelog_started = False

    for section_type, section_data in sections:
        if section_type == 'table':
            table_count += 1
            tbl = tables[section_data]
            if table_count == 1:
                continue
            elif table_count == 2:
                rows = extract_service_table(tbl)
                if rows:
                    output_parts.append(build_notion_table(rows))
            else:
                rows = extract_service_table(tbl)
                if rows:
                    output_parts.append(build_notion_table(rows))
        else:
            text = section_data.strip()
            if not text:
                continue

            changelog_match = re.search(r'###?\s*(Deployment\s+Change\s*[Ll]og|Change\s*[Ll]og)', text)
            if changelog_match:
                heading_end = text.find('\n', changelog_match.start())
                heading = text[changelog_match.start():heading_end].strip() if heading_end > 0 else text[changelog_match.start():].strip()
                before_heading = text[:changelog_match.start()].strip()
                after_heading = text[heading_end:].strip() if heading_end > 0 else ""

                if before_heading:
                    output_parts.append(before_heading)

                output_parts.append(heading)

                if after_heading:
                    entries = parse_changelog_entries(after_heading)
                    entry_counter = 0
                    for entry in entries:
                        entry_counter += 1
                        date = get_entry_date(entry)
                        if date:
                            summary = date
                        else:
                            summary = f"Entry {entry_counter}"
                        output_parts.append(build_toggle(summary, entry))
                changelog_started = True
            elif changelog_started:
                entries = parse_changelog_entries(text)
                entry_counter = 0
                for entry in entries:
                    entry_counter += 1
                    date = get_entry_date(entry)
                    if date:
                        summary = date
                    else:
                        summary = f"Entry {entry_counter}"
                    output_parts.append(build_toggle(summary, entry))
            else:
                output_parts.append(text)

    return '\n\n'.join(output_parts)


if __name__ == '__main__':
    if len(sys.argv) > 1:
        with open(sys.argv[1]) as f:
            body = f.read()
    else:
        body = sys.stdin.read()

    result = transform_page(body)
    print(result)
