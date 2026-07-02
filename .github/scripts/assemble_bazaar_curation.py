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
        title = re.sub(r'[\U00010000-\U0010ffff]|[\u2600-\u27BF]', '', title).strip()
        link = item.find("link").text
        description_html = item.find("description").text

        print(f"Latest GNOME Update: {title}")

        parser = HTMLToMarkdown()
        parser.feed(description_html)
        markdown_body = "".join(parser.markdown)

        # Strip emojis to conform with emoji-free user preferences
        markdown_body = re.sub(r'[\U00010000-\U0010ffff]|[\u2600-\u27BF]', '', markdown_body)

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
        name = re.sub(r'[\U00010000-\U0010ffff]|[\u2600-\u27BF]', '', name).strip()
        body = release.get("body", "")
        # Strip emojis from body
        body = re.sub(r'[\U00010000-\U0010ffff]|[\u2600-\u27BF]', '', body)

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

def check_url_exists(url):
    try:
        req = urllib.request.Request(url, method="HEAD")
        req.add_header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        with urllib.request.urlopen(req, timeout=5) as response:
            return response.status == 200
    except Exception:
        # Fallback to GET just in case some servers don't like HEAD
        try:
            req = urllib.request.Request(url)
            req.add_header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            with urllib.request.urlopen(req, timeout=5) as response:
                return response.status == 200
        except Exception:
            return False

def fetch_flathub_icon_url(appid):
    url = f"https://flathub.org/api/v2/appstream/{appid}"
    try:
        req = urllib.request.Request(url)
        req.add_header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                icons = data.get("icons", [])
                if icons:
                    # Find the 128x128 icon or first available remote icon
                    for icon in icons:
                        if icon.get("width") == 128 or icon.get("type") == "remote":
                            return icon.get("url")
                    return icons[0].get("url")
    except Exception as e:
        print(f"Flathub API check failed for {appid}: {e}", file=sys.stderr)
    return None

def resolve_icon_from_system(appid):
    """
    Search for a .desktop file in Homebrew or system paths for the given appid,
    extract the Icon name, find the actual icon file (PNG or SVG) in system/Homebrew icon folders,
    and return its base64 encoded data URI.
    """
    print(f"Resolving icon for non-Flathub app: {appid}")

    # Paths to search for desktop files
    desktop_paths = [
        "/home/linuxbrew/.linuxbrew/share/applications",
        "/var/home/linuxbrew/.linuxbrew/share/applications",
        "/usr/share/applications",
        os.path.expanduser("~/.local/share/applications"),
    ]

    last_part = appid.split(".")[-1].lower()
    desktop_file = None

    # 1. Locate the .desktop file
    for p in desktop_paths:
        if not os.path.exists(p):
            continue
        for file in os.listdir(p):
            if file.endswith(".desktop"):
                file_lower = file.lower()
                if last_part in file_lower or appid.lower() in file_lower:
                    desktop_file = os.path.join(p, file)
                    break
        if desktop_file:
            break

    if not desktop_file:
        print(f"No .desktop file found statically for {appid}", file=sys.stderr)
        return None

    print(f"Found desktop file: {desktop_file}")

    # 2. Extract the Icon= name
    icon_name = None
    try:
        with open(desktop_file, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("Icon="):
                    icon_name = line.split("=", 1)[1].strip()
                    break
    except Exception as e:
        print(f"Error reading desktop file {desktop_file}: {e}", file=sys.stderr)
        return None

    if not icon_name:
        print(f"No Icon defined in {desktop_file}", file=sys.stderr)
        return None

    print(f"Extracted icon name: {icon_name}")

    # 3. Locate the actual icon file
    icon_search_paths = [
        "/home/linuxbrew/.linuxbrew/share/icons",
        "/var/home/linuxbrew/.linuxbrew/share/icons",
        "/usr/share/icons",
        os.path.expanduser("~/.local/share/icons"),
        "/home/linuxbrew/.linuxbrew/share/pixmaps",
        "/var/home/linuxbrew/.linuxbrew/share/pixmaps",
        "/usr/share/pixmaps",
    ]

    icon_file = None
    for p in icon_search_paths:
        if not os.path.exists(p):
            continue
        for root, dirs, files in os.walk(p):
            for file in files:
                name, ext = os.path.splitext(file)
                if name.lower() == icon_name.lower() and ext.lower() in [".png", ".svg"]:
                    icon_file = os.path.join(root, file)
                    break
            if icon_file:
                break
        if icon_file:
            break

    if not icon_file:
        print(f"Could not locate icon file for {icon_name}", file=sys.stderr)
        return None

    print(f"Located icon file: {icon_file}")

    # 4. Read and encode to base64 Data URI
    try:
        import base64
        with open(icon_file, "rb") as f:
            encoded = base64.b64encode(f.read()).decode("utf-8")
        ext = os.path.splitext(icon_file)[1].lower()
        mime = "image/png" if ext == ".png" else "image/svg+xml"
        return f"data:{mime};base64,{encoded}"
    except Exception as e:
        print(f"Error encoding icon file to base64: {e}", file=sys.stderr)
        return None

def process_static_articles():
    print("Processing static articles for non-Flathub icons...")
    articles_dir = "system_files/bluefin/etc/bazaar"
    if not os.path.exists(articles_dir):
        return

    # Find all article-*.md files
    for filename in os.listdir(articles_dir):
        if filename.startswith("article-") and filename.endswith(".md"):
            filepath = os.path.join(articles_dir, filename)
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()

                # Regex to find Flathub icon links:
                # e.g., https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/d/dev.k8slens.OpenLens.png
                pattern = r'https://dl\.flathub\.org/repo/appstream/x86_64/icons/128x128/.*?/([^/\s]+?)\.png'
                urls = re.findall(r'(https://dl\.flathub\.org/repo/appstream/x86_64/icons/128x128/.*?/[^/\s]+?\.png)', content)

                if not urls:
                    continue

                modified = False
                for url in set(urls):
                    match = re.search(pattern, url)
                    if not match:
                        continue
                    appid = match.group(1)

                    print(f"Resolving icon for {appid}...")
                    # 1. Try to fetch the live URL from the Flathub API first
                    live_url = fetch_flathub_icon_url(appid)
                    if live_url:
                        content = content.replace(url, live_url)
                        modified = True
                        print(f"Successfully updated icon for {appid} using official Flathub API: {live_url}")
                    else:
                        print(f"App {appid} is not on Flathub or API returned no icon. Falling back to Homebrew/system .desktop...")
                        # 2. Resolve from system statically (Homebrew)
                        base64_icon = resolve_icon_from_system(appid)
                        if base64_icon:
                            content = content.replace(url, base64_icon)
                            modified = True
                            print(f"Successfully replaced Flathub icon for {appid} with Homebrew base64 icon.")
                        else:
                            print(f"Warning: Could not resolve icon for non-Flathub app {appid}", file=sys.stderr)

                if modified:
                    with open(filepath, "w", encoding="utf-8") as f:
                        f.write(content)
                    print(f"Successfully updated static article: {filepath}")
            except Exception as e:
                print(f"Error processing static article {filepath}: {e}", file=sys.stderr)

def main():
    token = os.environ.get("GITHUB_TOKEN")
    gnome_ok = assemble_gnome()
    bluefin_ok = assemble_bluefin(token)
    process_static_articles()

    if not (gnome_ok and bluefin_ok):
        print("One or more assembly tasks failed.", file=sys.stderr)
        # Let's not fail the whole process if one is a temporary network error
        # but return appropriate exit code if both failed
        if not gnome_ok and not bluefin_ok:
            sys.exit(1)

if __name__ == "__main__":
    main()
