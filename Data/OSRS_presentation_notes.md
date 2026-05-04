# OSRS Quest Network — Presentation Notes
## 7CS114 Network Analysis Assessment | Adam Birch

---

## Section 1 — Network Classification & Summary
**Criterion: Classify the network and justify the choice of model**

- The graph is **directed** because the prerequisite relationship is asymmetric — Druidic Ritual being required by Heroes' Quest does not imply the reverse. Using an undirected model would lose this causal ordering and make betweenness/closeness measures meaningless.
- The graph is **weighted** using a composite node-weight formula (difficulty score + normalised skill levels + skill count + prereq count), so weighted shortest paths reflect true unlock effort rather than just hop count. A Grandmaster quest with 10 prerequisites costs far more to reach than three Novice hops.
- With 245 edges across 189 nodes the graph is **sparse** — mean out-degree below 1.3. Most quests are structural leaves: they unlock nothing further, so the graph resembles a collection of convergent chains feeding into a small number of heavily-depended-upon gateway quests.

---

## Section 2 — Centrality Analysis
**Criterion: Apply and interpret centrality measures**

- **Out-degree**: Druidic Ritual (Quest 18) has the highest out-degree at 12 — more subsequent quests depend on it than any other single quest. It is also a trivial Novice quest, which means it is the single most impactful thing a player can do early to open up content.
- **Betweenness**: High betweenness identifies bottleneck quests that sit on the shortest path between many pairs of nodes. Blocking or failing one of these quests cuts a player off from entire branches of the progression graph — more disruptive than its in-degree alone would suggest.
- **PageRank vs in-degree**: PageRank is more informative here than raw in-degree because it weights incoming links by the importance of the source. A quest required by While Guthix Sleeps (itself requiring 10 prerequisites) scores higher than one required by ten Novice quests — it correctly identifies prerequisites that sit at the root of complex chains, not just popular ones.

---

## Section 3 — Connected & Biconnected Components + Articulation Points
**Criterion: Analyse connectivity and identify structural vulnerabilities**

- The expected result is **one dominant connected component** containing most quests, with a fringe of isolated nodes — quests that have no prerequisites and nothing requires them (e.g. several recently-added Novice quests with no dependencies yet). These isolated nodes confirm the dataset is real-world rather than a synthetic toy graph.
- **Articulation points** are the most structurally critical finding: these are quests whose removal would increase the number of components, fragmenting the progression graph. In a game design context they represent single points of failure in content accessibility — if the game's quest requirement system broke for one of these quests, large sections of content would become unreachable.
- The **biconnected component** count tells us how much redundancy exists. Low counts mean most of the graph has no alternate route around any given quest — the prerequisite chains are effectively linear, which matches the game's design intent of gating content behind a clear ordered journey.

---

## Section 4 — Community Detection
**Criterion: Detect and interpret communities or clusters**

- The Louvain algorithm works purely from graph topology — it has no knowledge of quest series names or game lore. Finding clusters that align with known quest lines (Myreque, Elf, Gnome, Fremennik, Desert) would demonstrate that **quest prerequisite structure encodes narrative structure**: the designers wired quest lines together through prerequisites in a way that is statistically detectable.
- Quests with no prerequisites and nothing requiring them will each form **singleton communities**. A high singleton count compared to the total community count is a useful summary statistic: it quantifies how much of the game's quest catalogue sits outside the main interconnected web.
- Community size inequality is worth discussing: a few large clusters (major quest lines) and many small or singleton clusters is the expected shape for a real progression graph, and it contrasts with what a random graph of the same density would produce — validating that the structure is non-random and meaningful.

---

## Section 5 — Shortest Paths
**Criterion: Compute and interpret shortest paths / graph diameter**

- Starting from Druidic Ritual (the highest out-degree gateway quest), the **longest weighted shortest path** reaches a Grandmaster quest such as Dragon Slayer II or While Guthix Sleeps. That weighted distance is the "diameter candidate" — the hardest unbroken chain of content that any player following the critical path must work through.
- The **weighted path length matters more than hop count** here. Dragon Slayer II has 8 direct prerequisites, but because several of those prerequisites are themselves demanding (high node_weight), the cumulative weighted path from Druidic Ritual is far larger than 8 steps would imply. The weighting surfaces this complexity.
- Quests **unreachable from Druidic Ritual** (null path length) are those in isolated components — they have no dependency relationship with the Druidic Ritual chain at all. This complements the component analysis in Section 3 and gives a player-facing interpretation: "if you start with Druidic Ritual, these quests are in a completely separate part of the game."

---

## Section 6 — Bipartite Analysis
**Criterion: Analyse a bipartite graph and compute a projection**

- **Crafting and Agility are each required by 38 quests** — more than any other skill, and together they gate over 20% of the quest catalogue. A player who has neglected either skill faces a hard ceiling on progression that no amount of quest-specific grinding can bypass. This is the most actionable finding from the bipartite layer.
- The **skill-skill projection** shows which pairs of skills are systematically bundled in quest requirements. High co-occurrence (e.g. Agility + Thieving, or Crafting + Smithing) suggests these skills are treated as a conceptual unit by quest designers — training one without the other still leaves a player blocked. The projection edge weight is the exact count of quests requiring both simultaneously.
- The **quest-quest projection** groups quests by shared skill requirements. Quests sharing five or more required skills effectively demand the same player "build" to complete, even if they are in different parts of the game. This is analytically distinct from the main prerequisite graph: two quests can share all their skill requirements while having no direct dependency edge between them.

---

## Section 7 — Minimum Spanning Tree
**Criterion: Apply an optimisation method (graph backbone / spanning tree)**

- The MST contains the **irreducible prerequisite backbone**: the minimum set of edges that keeps all quests connected into a single structure. Every edge on the MST is load-bearing — remove any one of them and the graph fragments. Non-MST edges are redundant alternate routes that enrich the design without being structurally essential.
- The **heaviest MST edges** (those connecting prerequisites of Dragon Slayer II, While Guthix Sleeps, and Song of the Elves) mark the hardest difficulty jumps that sit on the critical path. These are the moments in the game where progression demands the most effort, and they appear on the MST precisely because there is no cheaper route around them.
- Comparing MST edge count to total edge count gives a measure of **graph redundancy**. A tree on 189 nodes has exactly 188 edges; our graph has 245. The 57 non-MST edges represent optional or alternate prerequisite paths — places where the game offers more than one route to the same destination, adding design flexibility without changing the fundamental structure.

---

## Quick-reference data points for the video

| Fact | Value |
|---|---|
| Total quest nodes | 189 |
| Directed prerequisite edges | 245 |
| Quest–skill bipartite edges | 331 |
| Skills appearing in requirements | 23 |
| Quest with most prerequisites | While Guthix Sleeps (10 direct) |
| Quest unlocking most content | Druidic Ritual (12 outgoing) |
| Heaviest quest (node_weight) | Dragon Slayer II (91.5) |
| Most required skills (tied) | Crafting, Agility (38 quests each) |
| Graph type | Directed, weighted, sparse |
