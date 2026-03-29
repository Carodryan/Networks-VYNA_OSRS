import requests
import json
from bs4 import BeautifulSoup

API_URL      = "https://oldschool.runescape.wiki/api.php"
QUEST_LIST   = "https://oldschool.runescape.wiki/w/Quests/List"

HEADERS = {
    "User-Agent": "OSRS-Quest-Network-Builder/2.0 (educational use)"
}

# ── 1. Fetch quest number + difficulty from Quests/List ───────────────────────
print("Fetching quest list page …")
r = requests.get(QUEST_LIST, headers=HEADERS)
soup = BeautifulSoup(r.text, "html.parser")

quest_meta = {}   # name -> {number, difficulty}
VALID_DIFFICULTIES = {"Novice","Intermediate","Experienced","Master","Grandmaster","Special"}

for table in soup.find_all("table"):
    for row in table.find_all("tr"):
        cols = row.find_all("td")
        if len(cols) < 3:
            continue
        number_text = cols[0].get_text(strip=True)
        name_tag    = cols[1].find("a")
        diff_text   = cols[2].get_text(strip=True)
        if not name_tag or diff_text not in VALID_DIFFICULTIES:
            continue
        quest_name = name_tag.get_text(strip=True)
        # quest number can be float-like (100.1 etc.) – keep as string
        quest_meta[quest_name] = {
            "number":     number_text,
            "difficulty": diff_text
        }

print(f"  Found metadata for {len(quest_meta)} quests")

# ── 2. Fetch Module:Questreq/data ─────────────────────────────────────────────
print("Fetching quest requirements module …")
params = {
    "action":  "query",
    "prop":    "revisions",
    "titles":  "Module:Questreq/data",
    "rvprop":  "content",
    "rvslots": "main",
    "format":  "json"
}
data  = requests.get(API_URL, params=params, headers=HEADERS).json()
pages = data["query"]["pages"]
page  = next(iter(pages.values()))
content = page["revisions"][0]["slots"]["main"]["*"]

# Strip the first 30 header lines (Lua boilerplate)
lines   = content.splitlines()
content = "\n".join(lines[30:])

# ── 3. Write combined output ───────────────────────────────────────────────────
output = {
    "quest_meta":    quest_meta,
    "quest_req_lua": content
}

with open("api_raw.txt", "w", encoding="utf-8") as f:
    f.write(content)

with open("quest_meta.json", "w", encoding="utf-8") as f:
    json.dump(quest_meta, f, indent=2, ensure_ascii=False)

print("Saved  api_raw.txt  and  quest_meta.json")
print("\n=== SAMPLE quest_meta (first 5) ===")
for k, v in list(quest_meta.items())[:5]:
    print(f"  {k!r:45s} -> {v}")