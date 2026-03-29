# OSRS Quest Network — SAS VIYA Network Analysis Project

## Project Overview

University of Wolverhampton — Year 2 Network Analysis Assignment (2024–26).

This project builds and analyses a **directed quest dependency network** for
Old School RuneScape (OSRS). Every quest is a node; every prerequisite
relationship is a directed edge (prereq → quest). The graph is then loaded into
**SAS VIYA** and analysed using `PROC NETWORK` to explore connectivity,
centrality, and the structure of the quest progression system.

This is also a **learning project** for the SAS VIYA Network Analysis (VYNA)
course — the analyses mirror the exercises in that course.

---

## Repository Structure

```
/
├── CLAUDE.md                   ← this file
├── .gitattributes
└── Data/
    ├── api_query.py            ← Step 1: scrapes OSRS wiki → raw data files
    ├── api_raw.txt             ← Raw Lua quest requirement data (from OSRS wiki Module:Questreq/data)
    ├── quest_meta.json         ← Quest number + difficulty tier per quest (scraped from Quests/List page)
    └── Quest_Scraper.py        ← Step 2: parses Lua + meta → Excel output files
```

### Output files (generated, not committed)

```
Data/
├── quest_reference.xlsx        ← Human-readable reference table (one row per quest)
└── quest_network_sas.xlsx      ← SAS-ready file with two sheets:
    ├── Quest Nodes             ← Node table (quest_id, name, difficulty, weights)
    └── Quest Links             ← Edge list (from_id, from_quest, to_id, to_quest, weight)
```

---

## Data Pipeline

```
OSRS Wiki API
    │
    ├── Module:Questreq/data  →  api_raw.txt        (Lua: quest + skill prereqs)
    └── Quests/List page      →  quest_meta.json    (quest number + difficulty)
         │
         └── Quest_Scraper.py
                  │
                  ├── quest_reference.xlsx           (reference/audit table)
                  └── quest_network_sas.xlsx         (nodes sheet + edges sheet)
                           │
                           └── SAS VIYA / PROC NETWORK
                                    │
                                    ├── Connected Components
                                    ├── Biconnected Components
                                    ├── Articulation Points
                                    ├── Centrality (Betweenness, etc.)
                                    └── Further analyses (see Goals below)
```

---

## Data Sources & Schema

### `api_raw.txt` — Lua format
Scraped from the OSRS wiki page `Module:Questreq/data`. Contains one block per
quest/miniquest/diary structured as:

```lua
['Quest Name'] = {
    ['quests'] = { 'Prereq Quest 1', 'Prereq Quest 2' },
    ['skills'] = {
        {'SkillName', level},
        {'SkillName', level, 'boostable'},
        {'SkillName', level, 'ironman'},
        {'SkillName', level, 'ironman', 'boostable'}
    }
}
```

The file is divided into sections:
- **Quests** (top section, before miniquest divider)
- **Miniquests** (e.g. Alfred Grimhand's Barcrawl, Enter the Abyss)
- **Unofficial Miniquests** (e.g. Barbarian Training sub-activities)
- **Achievement Diaries** (e.g. Easy Ardougne Diary)

`Quest_Scraper.py` currently only parses the **Quests** section.

### `quest_meta.json` — JSON format
```json
{
  "Quest Name": {
    "number": "77",
    "difficulty": "Master"
  }
}
```

Difficulty tiers: `Novice`, `Intermediate`, `Experienced`, `Special`, `Master`, `Grandmaster`

### Edge List Schema (`Quest Links` sheet)
| Column | Description |
|---|---|
| `from_id` | Quest number of the prerequisite |
| `from_quest` | Name of the prerequisite quest |
| `to_id` | Quest number of the quest being unlocked |
| `to_quest` | Name of the quest being unlocked |
| `weight` | Difficulty weight of the destination quest (see Weight Formula) |

### Node Table Schema (`Quest Nodes` sheet)
| Column | Description |
|---|---|
| `quest_id` | Quest number (from wiki, e.g. "77", "100.1") |
| `quest_name` | Full quest name |
| `difficulty` | Difficulty tier string |
| `difficulty_score` | Numeric score (1–5, see below) |
| `num_quest_prereqs` | Count of quest prerequisites |
| `num_skill_reqs` | Count of skill requirements |
| `total_skill_level` | Sum of all required skill levels |
| `node_weight` | Composite weight (see formula below) |

---

## Key Calculations

### Difficulty Score Mapping
| Difficulty | Score |
|---|---|
| Novice | 1 |
| Intermediate | 2 |
| Experienced | 3 |
| Special | 3 |
| Master | 4 |
| Grandmaster | 5 |

### Edge/Node Weight Formula
```
weight = difficulty_score
       + (sum of all skill level requirements / 10)
       + number of skill requirements
       + number of quest prerequisites
```

This represents how demanding a quest is to unlock overall — used as the edge
weight on each directed edge pointing **into** that quest.

### Skill ID Mapping (from `Quest_Scraper.py`)
23 canonical OSRS skills are mapped to numeric IDs (Attack=1 through Hunter=22),
plus pseudo-skills: Quest point=23, Kudos=24, Combat=25.

---

## SAS VIYA Course Context (VYNA)

This project is built alongside the **SAS Visual Network Analysis (VYNA)** course.
The analyses practised in the course are applied directly to the OSRS quest graph.

### Course Concepts Covered

#### 1. Graph / Network Fundamentals
- Nodes (vertices) and links (edges)
- Directed vs undirected graphs
- Weighted vs unweighted networks
- Subgraphs

#### 2. Data Preparation for Networks
- Edge list format (`from`, `to`)
- Node-level vs link-level tables
- Creating CAS tables via DATA step
- `libname ... cas` and CAS sessions

#### 3. PROC NETWORK Basics
```sas
proc network
  links    = mycas.inputLinks
  nodes    = mycas.inputNodes
  outNodes = mycas.outputNodes
  outLinks = mycas.outputLinks;
run;
```
- `summary` statement
- `_NETWORK_` macro variable dictionary
- `%GetValue(mac=_NETWORK_, item=NUM_COMPONENTS)` helper macro

#### 4. Connected Components
- Definition: groups where every node can reach every other
- `connectedComponents` statement
- Output variable: `concomp`
- Macro item: `NUM_COMPONENTS`

#### 5. Biconnected Components
- Stronger than connected: graph stays connected even if one node is removed
- `biConnectedComponents` statement
- Macro item: `NUM_COMPONENTS` (reused, context-dependent)

#### 6. Articulation Points
- A node whose removal disconnects the graph
- Output variable: `artpoint = 1`
- Macro item: `NUM_ARTICULATION_POINTS`

#### 7. Network Modification & Scenario Testing
- Filter edges with DATA step (`if from^=X and to^=X`)
- Simulate node/quest removal
- Re-run PROC NETWORK to compare before/after structure

#### 8. Centrality Measures
- **Betweenness centrality** — how often a node lies on shortest paths
  - `centrality between = unweight;`
- **Degree centrality** — number of direct connections
- **Closeness centrality** — average distance to all other nodes
- **Eigenvector centrality** — importance based on neighbour importance

#### 9. BY-Group Analysis
- `by concomp;` — run analysis per connected component
- Compute centrality separately within each component

#### 10. Output Interpretation
- `outNodes=` — node-level results (artpoint, centrality scores, concomp)
- `outLinks=` — link-level results (component labels)
- Identifying structurally important quests

#### 11. Macro Integration
```sas
%let n = %GetValue(mac=_NETWORK_, item=NUM_COMPONENTS);
%put There are &n connected components;
```

#### 12. CAS Environment
```sas
cas mysess;
libname mycas cas sessref=mysess;
%include "&path./VYNA00COURSEMAC.sas";
```

---

## Project Goals

### What We Are Trying to Achieve

1. **Map the full quest dependency graph** — visualise how quests chain together
   from simple Novice quests all the way to Grandmaster completions.

2. **Find structurally critical quests (articulation points)** — identify which
   quests, if blocked, would lock a player out of the largest number of
   subsequent quests.

3. **Measure quest importance (centrality)** — rank quests by how central they
   are to the progression network (betweenness, degree, closeness).

4. **Analyse connectivity** — how many connected components exist? Are there
   isolated quest chains with no dependencies on the main graph?

5. **Simulate quest removal** — model what happens to the network if a key
   quest is removed (e.g. "What if Priest in Peril didn't exist?").

6. **Apply VYNA course techniques** — use this real-world dataset to practise
   every concept in the SAS VIYA Network Analysis course with meaningful,
   interesting data rather than toy examples.

---

## SAS Code Patterns Used in This Project

### Standard Session Setup
```sas
cas mysess;
libname mycas cas sessref=mysess;
%include "&path./VYNA00COURSEMAC.sas";
```

### Load Edge List into CAS
```sas
proc import
  datafile = "&path./quest_network_sas.xlsx"
  out      = mycas.questLinks
  dbms     = xlsx replace;
  sheet    = "Quest Links";
run;
```

### Connected + Biconnected Components in One Step
```sas
proc network
  links = mycas.questLinks;
  summary
    connectedComponents
    biConnectedComponents
  out = mycas.questComponents;
run;
```

### Find Articulation Points
```sas
proc network
  links    = mycas.questLinks
  outNodes = mycas.questNodes;
  biconnectedComponents;
run;

proc print data=mycas.questNodes;
  where artpoint = 1;
run;
```

### Betweenness Centrality by Component
```sas
proc network
  links    = mycas.questLinks
  outNodes = mycas.questCentrality;
  centrality
    between = unweight;
  by concomp;
run;
```

---

## Important Notes & Quirks

- **Quest numbers** can be decimals — Recipe for Disaster sub-quests use
  `100.1`, `100.2`, etc. SAS handles these as strings in the node/link tables.

- **"Started:" prefix** — some prerequisites in `api_raw.txt` are listed as
  `'Started:Quest Name'` meaning only partial completion is needed.
  The scraper currently includes these as-is; they may need cleaning.

- **Skill prerequisites** are captured in the reference table but are **not**
  modelled as nodes in the network — only quest-to-quest edges are used in
  PROC NETWORK.

- **`Quest_Scraper.py` only parses the Quests section** of `api_raw.txt`.
  Miniquests and Achievement Diaries are present in the raw data but excluded
  from the current output.

- **Ironman-only requirements** — some skill requirements have an `'ironman'`
  tag meaning they only apply to ironman accounts. These are currently included
  in the skill sum but not filtered.

---

## Python Environment

- **`api_query.py`** requires: `requests`, `beautifulsoup4`
- **`Quest_Scraper.py`** requires: `openpyxl`
- No virtual environment is set up — install with `pip install requests beautifulsoup4 openpyxl`

---

## Potential Next Steps

- [ ] Extend scraper to include Miniquests and Achievement Diaries as nodes
- [ ] Clean "Started:" prefixes from quest prerequisite names
- [ ] Add quest region / area metadata as a node attribute
- [ ] Build SAS PROC NETWORK analyses for each VYNA course chapter
- [ ] Visualise the network graph (SAS Visual Analytics or external tool)
- [ ] Filter ironman-only skill requirements for a standard account view
- [ ] Investigate which quests have the highest betweenness centrality
- [ ] Identify which Grandmaster quests have the deepest prerequisite chains
