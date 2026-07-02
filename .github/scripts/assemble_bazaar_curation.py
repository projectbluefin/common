#!/usr/bin/env python3
import os
import re
import sys
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
import urllib.request
import json
from datetime import datetime

class HTMLToMarkdown(HTMLParser):
    def __init__(self, base_url="https://thisweek.gnome.org"):
        super().__init__()
        self.base_url = base_url
        self.markdown = []
        self.list_depth = 0
        self.in_blockquote = False
        self.current_link = None
        self.link_text = []
        self.in_header = False
        self.header_level = 0
        self.in_pre = False

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        if tag in ["h1", "h2", "h3", "h4", "h5", "h6"]:
            self.in_header = True
            self.header_level = int(tag[1])
            self.markdown.append("\n\n" + "#" * self.header_level + " ")
        elif tag == "p":
            if not self.in_blockquote:
                self.markdown.append("\n\n")
            else:
                self.markdown.append("\n> ")
        elif tag == "blockquote":
            self.in_blockquote = True
            self.markdown.append("\n\n")
        elif tag == "a":
            href = attrs_dict.get("href", "")
            if href.startswith("/"):
                href = self.base_url + href
            self.current_link = href
            self.link_text = []
        elif tag == "img":
            src = attrs_dict.get("src", "")
            if src.startswith("/"):
                src = self.base_url + src
            alt = attrs_dict.get("alt", "Image")
            self.markdown.append(f"\n\n![{alt}]({src})\n\n")
        elif tag == "pre":
            self.in_pre = True
            self.markdown.append("\n\n```\n")
        elif tag == "code":
            if not self.in_pre:
                self.markdown.append("`")
        elif tag == "ul":
            self.list_depth += 1
            self.markdown.append("\n")
        elif tag == "li":
            self.markdown.append("\n" + "  " * (self.list_depth - 1) + "* ")

    def handle_endtag(self, tag):
        if tag in ["h1", "h2", "h3", "h4", "h5", "h6"]:
            self.in_header = False
            self.markdown.append("\n\n")
        elif tag == "blockquote":
            self.in_blockquote = False
            self.markdown.append("\n\n")
        elif tag == "a":
            link_str = "".join(self.link_text).strip()
            if self.current_link:
                self.markdown.append(f"[{link_str}]({self.current_link})")
            else:
                self.markdown.append(link_str)
            self.current_link = None
            self.link_text = []
        elif tag == "pre":
            self.in_pre = False
            self.markdown.append("\n```\n\n")
        elif tag == "code":
            if not self.in_pre:
                self.markdown.append("`")
        elif tag == "ul":
            self.list_depth -= 1
            self.markdown.append("\n")

    def handle_data(self, data):
        if self.current_link is not None:
            self.link_text.append(data)
        else:
            if self.in_blockquote:
                # Add blockquote marker after newlines in blockquote data
                lines = data.split("\n")
                cleaned_data = "\n> ".join(lines)
                self.markdown.append(cleaned_data)
            else:
                self.markdown.append(data)

def fetch_url(url, token=None):
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    if token:
        req.add_header("Authorization", f"token {token}")
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            return response.read()
    except Exception as e:
        print(f"Error fetching {url}: {e}", file=sys.stderr)
        return None

def assemble_gnome():
    print("Fetching GNOME RSS Feed...")
    feed_data = fetch_url("https://thisweek.gnome.org/index.xml")
    if not feed_data:
        print("Failed to fetch GNOME RSS feed.", file=sys.stderr)
        return False

    try:
        root = ET.fromstring(feed_data)
        item = root.find(".//item")
        if item is None:
            print("No items found in GNOME RSS feed.", file=sys.stderr)
            return False

        title = item.find("title").text
        link = item.find("link").text
        description_html = item.find("description").text

        print(f"Latest GNOME Update: {title}")

        parser = HTMLToMarkdown()
        parser.feed(description_html)
        markdown_body = "".join(parser.markdown)

        # Post-processing to clean up multiple newlines and spaces
        markdown_body = re.sub(r'\n{3,}', '\n\n', markdown_body)

        output_path = "system_files/bluefin/etc/bazaar/article-gnome-notes.md"
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        header_comment = f"""# {title}

**Published on This Week in GNOME:** [{link}]({link})

---
"""
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(header_comment + markdown_body)

        print(f"Successfully generated {output_path}")
        return True
    except Exception as e:
        print(f"Error assembling GNOME article: {e}", file=sys.stderr)
        return False

def assemble_bluefin(token=None):
    print("Fetching Bluefin Release Info...")
    url = "https://api.github.com/repos/projectbluefin/bluefin/releases/latest"
    release_data = fetch_url(url, token)
    if not release_data:
        # Try fallback to releases list
        print("Latest release endpoint failed. Trying releases list...", file=sys.stderr)
        url = "https://api.github.com/repos/projectbluefin/bluefin/releases"
        releases_list = fetch_url(url, token)
        if releases_list:
            try:
                releases = json.loads(releases_list.decode("utf-8"))
                if releases:
                    release = releases[0]
                else:
                    return False
            except Exception as e:
                print(f"Error parsing releases list: {e}", file=sys.stderr)
                return False
        else:
            return False
    else:
        try:
            release = json.loads(release_data.decode("utf-8"))
        except Exception as e:
            print(f"Error parsing latest release json: {e}", file=sys.stderr)
            return False

    try:
        tag_name = release.get("tag_name", "stable")
        name = release.get("name", "Project Bluefin Release")
        body = release.get("body", "")

        output_path = "system_files/bluefin/etc/bazaar/article-bluefin-notes.md"
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        header = f"# {name} ({tag_name})\n\n"

        # Clean up release body reference paths if needed
        cleaned_body = re.sub(r'src="/', 'src="https://github.com/', body)

        with open(output_path, "w", encoding="utf-8") as f:
            f.write(header + cleaned_body)

        print(f"Successfully generated {output_path}")
        return True
    except Exception as e:
        print(f"Error assembling Bluefin release notes: {e}", file=sys.stderr)
        return False

def main():
    token = os.environ.get("GITHUB_TOKEN")
    gnome_ok = assemble_gnome()
    bluefin_ok = assemble_bluefin(token)

    if not (gnome_ok and bluefin_ok):
        print("One or more assembly tasks failed.", file=sys.stderr)
        # Let's not fail the whole process if one is a temporary network error
        # but return appropriate exit code if both failed
        if not gnome_ok and not bluefin_ok:
            sys.exit(1)

if __name__ == "__main__":
    main()
