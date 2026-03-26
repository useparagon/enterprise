"""
Convert Atlassian Document Format (ADF) JSON to Notion-flavored Markdown.

Handles:
- expand blocks → <details>/<summary> toggles
- bulletList/orderedList → - / 1. items
- codeBlock → ```lang ... ```
- tables → <table> elements
- panels → <callout> elements
- inline marks: strong, em, code, link, strikethrough, underline
- date nodes → <mention-date>
- mention nodes → plain text @Name
- inlineCard (smartlinks) → [url](url)
- headings → # / ## / ### etc.
- bodiedExtension (Page Properties macro) → skipped (properties already in DB)
"""

import json
import sys


def convert_marks(text, marks):
    """Apply inline marks (bold, italic, code, link, etc.) to text."""
    if not marks:
        return text
    result = text
    for mark in marks:
        t = mark.get("type")
        if t == "strong":
            result = f"**{result}**"
        elif t == "em":
            result = f"*{result}*"
        elif t == "code":
            result = f"`{result}`"
        elif t == "strike":
            result = f"~~{result}~~"
        elif t == "underline":
            result = f'<span underline="true">{result}</span>'
        elif t == "link":
            href = mark.get("attrs", {}).get("href", "")
            result = f"[{result}]({href})"
    return result


def convert_inline_nodes(nodes):
    """Convert a list of inline ADF nodes to a Notion markdown string."""
    parts = []
    if not nodes:
        return ""
    for node in nodes:
        ntype = node.get("type")
        if ntype == "text":
            text = node.get("text", "")
            marks = node.get("marks", [])
            parts.append(convert_marks(text, marks))
        elif ntype == "date":
            ts = node.get("attrs", {}).get("timestamp")
            if ts:
                import datetime
                dt = datetime.datetime.fromtimestamp(int(ts) / 1000, tz=datetime.timezone.utc)
                parts.append(dt.strftime("%-m/%-d/%Y"))
            else:
                parts.append("[date]")
        elif ntype == "mention":
            text = node.get("attrs", {}).get("text", "@unknown")
            parts.append(text)
        elif ntype == "inlineCard":
            url = node.get("attrs", {}).get("url", "")
            parts.append(f"[{url}]({url})")
        elif ntype == "emoji":
            shortName = node.get("attrs", {}).get("shortName", "")
            parts.append(shortName)
        elif ntype == "hardBreak":
            parts.append("<br>")
        elif ntype == "status":
            text = node.get("attrs", {}).get("text", "")
            parts.append(f"[{text}]")
        else:
            text = node.get("text", "")
            if text:
                parts.append(text)
    return "".join(parts)


def convert_block_nodes(nodes, indent_level=0):
    """
    Convert a list of ADF block nodes into Notion markdown lines.
    indent_level: number of tabs to prepend (for nesting inside toggles, list items, etc.)
    """
    lines = []
    indent = "\t" * indent_level

    for node in nodes:
        ntype = node.get("type")

        if ntype == "paragraph":
            content = node.get("content", [])
            text = convert_inline_nodes(content)
            lines.append(f"{indent}{text}")

        elif ntype == "heading":
            level = node.get("attrs", {}).get("level", 1)
            content = node.get("content", [])
            text = convert_inline_nodes(content)
            hashes = "#" * level
            lines.append(f"{indent}{hashes} {text}")

        elif ntype == "bulletList":
            for item in node.get("content", []):
                item_lines = convert_list_item(item, indent_level, ordered=False)
                lines.extend(item_lines)

        elif ntype == "orderedList":
            for i, item in enumerate(node.get("content", []), 1):
                item_lines = convert_list_item(item, indent_level, ordered=True, number=i)
                lines.extend(item_lines)

        elif ntype == "codeBlock":
            lang = node.get("attrs", {}).get("language", "")
            if lang == "shell":
                lang = "bash"
            code_text = ""
            for c in node.get("content", []):
                code_text += c.get("text", "")
            lines.append(f"{indent}```{lang}")
            for code_line in code_text.split("\n"):
                lines.append(f"{indent}{code_line}")
            lines.append(f"{indent}```")

        elif ntype == "expand":
            title = node.get("attrs", {}).get("title", "")
            content = node.get("content", [])
            lines.append(f"{indent}<details>")
            lines.append(f"{indent}<summary>{title}</summary>")
            child_lines = convert_block_nodes(content, indent_level + 1)
            lines.extend(child_lines)
            lines.append(f"{indent}</details>")

        elif ntype == "table":
            table_lines = convert_table(node, indent_level)
            lines.extend(table_lines)

        elif ntype == "panel":
            panel_type = node.get("attrs", {}).get("panelType", "info")
            icon_map = {
                "warning": "⚠️",
                "info": "ℹ️",
                "note": "📝",
                "success": "✅",
                "error": "❌",
                "tip": "💡",
            }
            color_map = {
                "warning": "yellow_bg",
                "info": "blue_bg",
                "note": "gray_bg",
                "success": "green_bg",
                "error": "red_bg",
                "tip": "purple_bg",
            }
            icon = icon_map.get(panel_type, "ℹ️")
            color = color_map.get(panel_type, "gray_bg")
            content = node.get("content", [])
            lines.append(f'{indent}<callout icon="{icon}" color="{color}">')
            child_lines = convert_block_nodes(content, indent_level + 1)
            lines.extend(child_lines)
            lines.append(f"{indent}</callout>")

        elif ntype == "bodiedExtension":
            ext_key = node.get("attrs", {}).get("extensionKey", "")
            if ext_key == "details":
                pass
            else:
                content = node.get("content", [])
                child_lines = convert_block_nodes(content, indent_level)
                lines.extend(child_lines)

        elif ntype == "rule":
            lines.append(f"{indent}---")

        elif ntype == "mediaSingle" or ntype == "mediaGroup":
            pass

        elif ntype == "blockquote":
            content = node.get("content", [])
            child_lines = convert_block_nodes(content, indent_level)
            for cl in child_lines:
                stripped = cl.lstrip("\t")
                tab_count = len(cl) - len(stripped)
                lines.append("\t" * tab_count + "> " + stripped)

        elif ntype == "taskList":
            for item in node.get("content", []):
                state = item.get("attrs", {}).get("state", "TODO")
                check = "x" if state == "DONE" else " "
                item_content = item.get("content", [])
                first_para = None
                rest = []
                for ic in item_content:
                    if ic.get("type") == "paragraph" and first_para is None:
                        first_para = ic
                    else:
                        rest.append(ic)
                if first_para:
                    text = convert_inline_nodes(first_para.get("content", []))
                    lines.append(f"{indent}- [{check}] {text}")
                if rest:
                    child_lines = convert_block_nodes(rest, indent_level + 1)
                    lines.extend(child_lines)

        else:
            content = node.get("content")
            if content and isinstance(content, list):
                child_lines = convert_block_nodes(content, indent_level)
                lines.extend(child_lines)

    return lines


def convert_list_item(item, indent_level, ordered=False, number=1):
    """Convert a single listItem ADF node."""
    lines = []
    indent = "\t" * indent_level
    content = item.get("content", [])
    
    first_para = None
    rest = []
    for child in content:
        if child.get("type") == "paragraph" and first_para is None:
            first_para = child
        else:
            rest.append(child)

    prefix = f"{number}." if ordered else "-"
    
    if first_para:
        text = convert_inline_nodes(first_para.get("content", []))
        lines.append(f"{indent}{prefix} {text}")
    else:
        if rest and rest[0].get("type") == "codeBlock":
            lines.append(f"{indent}{prefix} ")
        else:
            lines.append(f"{indent}{prefix} ")

    for child in rest:
        child_lines = convert_block_nodes([child], indent_level + 1)
        lines.extend(child_lines)

    return lines


def convert_table(node, indent_level):
    """Convert an ADF table node to Notion <table> markdown."""
    indent = "\t" * indent_level
    lines = []
    
    rows = node.get("content", [])
    has_header = False
    if rows:
        first_row = rows[0]
        cells = first_row.get("content", [])
        if cells and cells[0].get("type") == "tableHeader":
            has_header = True
    
    header_attr = ' header-row="true"' if has_header else ""
    lines.append(f'{indent}<table{header_attr}>')
    
    for row in rows:
        lines.append(f"{indent}\t<tr>")
        for cell in row.get("content", []):
            cell_content = cell.get("content", [])
            cell_texts = []
            for block in cell_content:
                if block.get("type") == "paragraph":
                    cell_texts.append(convert_inline_nodes(block.get("content", [])))
                else:
                    sub = convert_block_nodes([block], 0)
                    cell_texts.append("\n".join(sub))
            cell_text = "\n".join(cell_texts)
            lines.append(f"{indent}\t\t<td>{cell_text}</td>")
        lines.append(f"{indent}\t</tr>")
    
    lines.append(f"{indent}</table>")
    return lines


def adf_to_notion_markdown(adf_body):
    """
    Convert an ADF document body to Notion-flavored markdown.
    adf_body: the 'body' field from the Confluence API (dict with 'type': 'doc', 'content': [...])
    Returns a string of Notion markdown.
    """
    if isinstance(adf_body, str):
        return adf_body
    
    content = adf_body.get("content", [])
    
    skip_properties = True
    filtered = []
    for node in content:
        if skip_properties and node.get("type") == "bodiedExtension":
            ext_key = node.get("attrs", {}).get("extensionKey", "")
            if ext_key == "details":
                continue
        skip_properties = False
        filtered.append(node)
    
    lines = convert_block_nodes(filtered, 0)
    
    result = "\n".join(lines)
    
    while "\n\n\n" in result:
        result = result.replace("\n\n\n", "\n\n")
    
    return result.strip()


if __name__ == "__main__":
    if len(sys.argv) > 1:
        with open(sys.argv[1], "r") as f:
            data = json.load(f)
        body = data.get("body", data)
        print(adf_to_notion_markdown(body))
    else:
        print("Usage: python adf_to_notion.py <adf_json_file>")
        print("  Reads an ADF JSON file and outputs Notion-flavored markdown.")
