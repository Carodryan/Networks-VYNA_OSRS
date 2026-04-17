import re, json, openpyxl

# ── Load inputs ────────────────────────────────────────────────────────────────
raw        = open("api_raw.txt").read()
quest_meta = json.load(open("quest_meta.json"))          # name -> {number, difficulty}

# ── Quest ID normalisation ─────────────────────────────────────────────────────
# Recipe for Disaster sub-quests are numbered 100.1–100.10 in the wiki.
# To keep all IDs as integers in SAS/Excel:
#   100.x  →  100 + x          (so 100.1→101, 100.10→110)
#   n≥101  →  n + 10           (shift everything after RfD up by 10)
#   otherwise unchanged
def to_int_id(number_str):
    s = str(number_str)
    if not s:
        return s
    if '.' in s:
        parts = s.split('.')
        try:
            return int(parts[0]) + int(parts[1])
        except ValueError:
            return s
    try:
        n = int(s)
        return n + 10 if n >= 101 else n
    except ValueError:
        return s

# ── Difficulty tier -> numeric score ──────────────────────────────────────────
DIFFICULTY_SCORE = {
    "Novice":       1,
    "Intermediate": 2,
    "Experienced":  3,
    "Special":      3,
    "Master":       4,
    "Grandmaster":  5,
}

# ── Skill name -> numeric ID ──────────────────────────────────────────────────
# Canonical OSRS skill list (23 skills) + special pseudo-skills
SKILL_ID = {
    "Attack":        1,  "Hitpoints":   2,  "Mining":      3,
    "Strength":      4,  "Agility":     5,  "Smithing":    6,
    "Defence":       7,  "Herblore":    8,  "Fishing":     9,
    "Ranged":       10,  "Thieving":   11,  "Cooking":    12,
    "Prayer":       13,  "Crafting":   14,  "Firemaking":  15,
    "Magic":        16,  "Fletching":  17,  "Woodcutting": 18,
    "Runecraft":    26,  "Slayer":     19,  "Farming":     20,
    "Construction": 21,  "Hunter":     22,
    # Pseudo-skills
    "Quest point":  23,  "Kudos":      24,  "Combat":      25,
}

# ── Parse Lua quest blocks ─────────────────────────────────────────────────────
def extract_quest_blocks(text):
    blocks = []
    pat = re.compile(r"\['((?:[^'\\]|\\.)*)'\]\s*=\s*\{")
    i = 0
    while i < len(text):
        m = pat.search(text, i)
        if not m:
            break
        name  = m.group(1).replace("\\'", "'")
        start = m.end()
        depth, j = 1, start
        while j < len(text) and depth > 0:
            if   text[j] == '{': depth += 1
            elif text[j] == '}': depth -= 1
            j += 1
        blocks.append((name, text[start:j-1]))
        i = j
    return blocks

def parse_block(block):
    # Quest prerequisites
    qm = re.search(r"\['quests'\]\s*=\s*\{(.*?)\}", block, re.DOTALL)
    quest_reqs = []
    if qm:
        quest_reqs = [q.replace("\\'", "'")
                      for q in re.findall(r"'((?:[^'\\]|\\.)*)'", qm.group(1))]

    # Skill prerequisites
    sm = re.search(r"\['skills'\]\s*=\s*\{(.*)\}", block, re.DOTALL)
    skill_reqs = []                    # list of (skill_name, level, skill_id)
    if sm:
        for sk in re.finditer(r"\{([^}]+)\}", sm.group(1)):
            parts = [p.strip().strip("'") for p in sk.group(1).split(',')]
            if len(parts) >= 2:
                try:
                    sname = parts[0]
                    level = int(parts[1])
                    sid   = SKILL_ID.get(sname, 0)
                    skill_reqs.append((sname, level, sid))
                except ValueError:
                    pass
    return quest_reqs, skill_reqs

# ── Weight formula ─────────────────────────────────────────────────────────────
# weight(dest_quest) = difficulty_score
#                    + sum_of_skill_levels / 10     (normalised)
#                    + num_skill_reqs
#                    + num_quest_prereqs
#
# Each directed edge  prereq -> dest  carries this weight.
# It represents "how hard is it to unlock dest_quest overall?"

def compute_weight(difficulty, skill_reqs, quest_reqs):
    d_score  = DIFFICULTY_SCORE.get(difficulty, 2)
    sk_sum   = sum(level for _, level, _ in skill_reqs) / 10
    sk_count = len(skill_reqs)
    q_count  = len(quest_reqs)
    return round(d_score + sk_sum + sk_count + q_count, 2)

# ── Build data ─────────────────────────────────────────────────────────────────
# Parse ALL Lua blocks across both sections; quest_meta is the authority on
# which entries are real quests — miniquests/diaries are filtered out below.
lua_blocks = dict(extract_quest_blocks(raw))   # name -> block_text

rows_ref  = []   # reference table rows
rows_link = []   # SAS edge-list rows
rows_node = []   # node table (one row per quest)

# Warn about quests that have no entry in the Lua requirements module.
no_lua_data = [n for n in quest_meta if n not in lua_blocks]
if no_lua_data:
    print(f"WARNING: {len(no_lua_data)} quest(s) have no data in api_raw.txt "
          f"(no prerequisite edges will be generated for them):")
    for n in sorted(no_lua_data):
        print(f"  - {n}")

# Iterate over quest_meta so every known quest becomes a node, even those
# absent from the Lua module (they just have no prerequisites).
for name, meta in quest_meta.items():
    block = lua_blocks.get(name, "")
    qr, sr = parse_block(block)
    q_num  = to_int_id(meta.get("number", ""))
    diff   = meta.get("difficulty", "Intermediate")
    weight = compute_weight(diff, sr, qr)

    # ── Reference table row ───────────────────────────────────────────────────
    skill_str = "; ".join(f"{sname} {lvl} (ID:{sid})" for sname, lvl, sid in sr)
    rows_ref.append([
        q_num,
        name,
        diff,
        "; ".join(qr),
        skill_str,
        len(qr),
        len(sr),
        sum(lvl for _, lvl, _ in sr),   # total skill level sum
        weight,
    ])

    # ── Node table row ────────────────────────────────────────────────────────
    rows_node.append([
        q_num,
        name,
        diff,
        DIFFICULTY_SCORE.get(diff, 2),
        len(qr),
        len(sr),
        sum(lvl for _, lvl, _ in sr),
        weight,
    ])

    # ── Edge list rows ────────────────────────────────────────────────────────
    for prereq in qr:
        prereq_lookup = prereq.removeprefix("Started:")
        prereq_num = to_int_id(quest_meta.get(prereq_lookup, {}).get("number", ""))
        rows_link.append([
            prereq_num,   # from node ID
            prereq,       # from label
            q_num,        # to node ID
            name,         # to label
            weight,       # edge weight (difficulty of destination quest)
        ])

# ── Write File 1 : Quest Reference ────────────────────────────────────────────
wb1 = openpyxl.Workbook()
ws1 = wb1.active
ws1.title = "Quest Reference"
ws1.append([
    "Quest Number", "Quest Name", "Difficulty",
    "Quest Requirements", "Skill Requirements (with IDs)",
    "Num Quest Reqs", "Num Skill Reqs",
    "Total Skill Level Sum", "Edge Weight"
])
for row in rows_ref:
    ws1.append(row)

# ── Write File 2 : SAS Node table ─────────────────────────────────────────────
wb2 = openpyxl.Workbook()
ws2 = wb2.active
ws2.title = "Quest Nodes"
ws2.append([
    "quest_id", "quest_name", "difficulty",
    "difficulty_score", "num_quest_prereqs", "num_skill_reqs",
    "total_skill_level", "node_weight"
])
for row in rows_node:
    ws2.append(row)

# Second sheet: edge list
ws3 = wb2.create_sheet("Quest Links")
ws3.append(["from_id", "from_quest", "to_id", "to_quest", "weight"])
for row in rows_link:
    ws3.append(row)

# Auto-fit columns
def autofit(ws):
    for col in ws.columns:
        w = max((len(str(c.value or "")) for c in col), default=8)
        ws.column_dimensions[col[0].column_letter].width = min(w + 2, 80)

for ws in [ws1, ws2, ws3]:
    autofit(ws)

wb1.save("quest_reference.xlsx")
wb2.save("quest_network_sas.xlsx")

print(f"Done — {len(rows_node)} quests, {len(rows_link)} directed edges")
print(f"Saved: quest_reference.xlsx  |  quest_network_sas.xlsx")