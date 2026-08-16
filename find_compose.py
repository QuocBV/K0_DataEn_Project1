"""Find docker-compose.yaml in airbytehq/airbyte-platform repo at tag v0.50.43 via GitHub API."""
import json, urllib.request

def api(url):
    req = urllib.request.Request(url, headers={"User-Agent": "python"})
    return json.load(urllib.request.urlopen(req, timeout=30))

# Get tree at tag
tree = api("https://api.github.com/repos/airbytehq/airbyte-platform/git/trees/v0.50.43?recursive=1")
print("tree sha:", tree.get("sha"))
print("truncated:", tree.get("truncated"))
count = 0
for item in tree.get("tree", []):
    p = item["path"].lower()
    if "docker-compose" in p and p.endswith((".yaml", ".yml")):
        print("MATCH:", item["path"], item.get("url", ""))
        count += 1
        if count >= 10:
            break
print("total matches:", count)