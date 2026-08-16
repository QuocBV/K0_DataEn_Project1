"""Fetch full content of airbyte-platform docker-compose.yaml at tag v0.50.43."""
import json, urllib.request

def api(url):
    req = urllib.request.Request(url, headers={"User-Agent": "python"})
    return json.load(urllib.request.urlopen(req, timeout=30))

# Get blob content for docker-compose.yaml
blob_url = "https://api.github.com/repos/airbytehq/airbyte-platform/git/blobs/e55b6131b18a11503266cdea5b388d186eea2e82"
blob = api(blob_url)
content = blob.get("content", "")
import base64
yaml_text = base64.b64decode(content).decode("utf-8")
print("SIZE:", len(yaml_text))
open("airbyte-compose-official.yaml", "w", encoding="utf-8").write(yaml_text)
print("=== HEAD ===")
print(yaml_text[:1500])