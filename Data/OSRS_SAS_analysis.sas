/*==============================================================================
  OSRS Quest Network Analysis — SAS Viya Script
  Assessment : 7CS114 Network Analysis
  Author     : Adam Birch | University of Wolverhampton | 2025-26

  Dataset    : 189 quest nodes (IDs 0-188)
               245 directed prerequisite edges
               331 quest-skill bipartite edges
               23  skill nodes (IDs 1001-1023)

  Graph type : Directed, weighted (main quest graph)
               Undirected bipartite (quest-skill layer)
==============================================================================*/


/*==============================================================================
  SECTION 0 - SETUP
==============================================================================*/

/*
  Set this to the folder on the SAS Viya server that contains:
    OSRS_SAS_code.sas       <- quest node data + partial links (replaced below)
    quest_network_sas.xlsx  <- complete edge data (Quest Links + Skill Links)
    VYNA00COURSEMAC.sas     <- course macro library (optional)
  Upload files via SAS Drive / Files service before running this script.
*/
%let path = /export/viya/homes/a.birch7@wlv.ac.uk/osrs;

/*
  Include the course macro library so %GetValue is available.
  Comment out if VYNA00COURSEMAC.sas is not on your server.
*/
/* %include "&path./VYNA00COURSEMAC.sas"; */

/*
  %include OSRS_SAS_code.sas.
  This file starts a CAS session (cas mysess), creates libname mycas, and
  populates:
    mycas.nodesOSRS  - all 189 quest nodes  (COMPLETE - use as-is)
    mycas.linksOSRS  - partial edge subset   (INCOMPLETE - replaced below)
  We overwrite linksOSRS immediately after with the full 245-edge dataset.
*/
/* Terminate any leftover CAS session from a prior run before the include
   opens a fresh one. Produces a harmless warning if MYSESS doesn't exist. */
cas mysess terminate;
%include "&path./OSRS_SAS_code.sas";

/* -----------------------------------------------------------------------
   Replace the incomplete linksOSRS with the full dataset from Excel.
   Excel "Quest Links" columns: from_id, from_quest, to_id, to_quest, weight
   We keep only: from (quest_id of prerequisite)
                 to   (quest_id of dependent quest)
                 weight (node_weight of the destination quest)
----------------------------------------------------------------------- */
proc import
    datafile = "&path./quest_network_sas.xlsx"
    out      = work.linksRaw
    dbms     = xlsx
    replace;
    sheet    = "Quest Links";
    getnames = yes;
run;

data mycas.linksOSRS;
    set work.linksRaw;
    where from_id is not missing and to_id is not missing;  /* drop miniquest rows */
    from = from_id;
    to   = to_id;
    /* weight = composite difficulty of the destination quest:
         difficulty_score + total_skill_level/10 + num_skill_reqs
                          + num_quest_prereqs                        */
    keep from to weight;
run;

/* -----------------------------------------------------------------------
   Load quest-skill edges for bipartite analysis.
   from   = quest_id  (0-188)
   to     = skill_id  (1001-1023; offset +1000 avoids collision with quest IDs)
   weight = minimum skill level required to start the quest
----------------------------------------------------------------------- */
proc import
    datafile = "&path./quest_network_sas.xlsx"
    out      = work.skillLinksRaw
    dbms     = xlsx
    replace;
    sheet    = "Skill Links";
    getnames = yes;
run;

data mycas.linksBipartite;
    set work.skillLinksRaw;
    where from_quest_id is not missing and to_skill_id is not missing;
    from   = from_quest_id;
    to     = to_skill_id;
    weight = min_level;
    keep from to weight;
run;

/* -----------------------------------------------------------------------
   Build the bipartite node table.
   Quest nodes  (node_type = 0): IDs 0-188, drawn from nodesOSRS.
   Skill nodes  (node_type = 1): IDs 1001-1023, defined inline.
   Only skills that actually appear in quest requirements are included
   (all 23 OSRS skills appear at least once in the 331 skill edges).
----------------------------------------------------------------------- */
data work.questNodesTyped;
    set mycas.nodesOSRS;
    node_id   = quest_id;
    node_name = quest_name;
    node_type = 0;
    keep node_id node_name node_type;
run;

data work.skillNodes;
    length node_name $30;
    node_type = 1;
    input node_id node_name $;
    datalines;
1001 Attack
1002 Strength
1003 Defence
1004 Hitpoints
1005 Ranged
1006 Prayer
1007 Magic
1008 Cooking
1009 Woodcutting
1010 Fletching
1011 Fishing
1012 Firemaking
1013 Crafting
1014 Smithing
1015 Mining
1016 Herblore
1017 Agility
1018 Thieving
1019 Slayer
1020 Farming
1021 Construction
1022 Hunter
1023 Runecraft
;
run;

data mycas.nodesBipartite;
    set work.questNodesTyped
        work.skillNodes;
run;

/* Sanity-check row counts before running any analyses */
proc sql;
    title "Section 0 - Input Table Row Counts";
    select "Quest Nodes"             as table_name, count(*) as rows
    from mycas.nodesOSRS
    union all
    select "Quest Links (full)",                    count(*)
    from mycas.linksOSRS
    union all
    select "Bipartite Nodes",                       count(*)
    from mycas.nodesBipartite
    union all
    select "Bipartite Links (skill edges)",         count(*)
    from mycas.linksBipartite;
quit;


/*==============================================================================
  SECTION 1 - NETWORK CLASSIFICATION AND SUMMARY
  Assessment criterion: classification + summary measures
==============================================================================*/

/*
  WHY: Establish the graph type before choosing analysis methods.

  The OSRS quest dependency graph is:
    DIRECTED  - edges point from prerequisite to dependent quest.
                Reversing an edge has no valid game interpretation.
    WEIGHTED  - edge weight = node_weight of the destination quest,
                combining difficulty tier, skill requirements, and
                prerequisite count into a single unlock-difficulty score.
                Weighted analyses reflect actual player effort, not hop count.
    SPARSE    - 245 edges over 189 nodes gives a mean degree well below 3.
                Many quests are sinks (no quest requires them) or isolated
                (no prerequisites and nothing requires them either).

  The summary statement writes graph-level statistics into the SAS macro
  variable dictionary _NETWORK_, which we then report to the log.
*/
proc network
    direction = directed
    links     = mycas.linksOSRS
    nodes     = mycas.nodesOSRS
    outNodes  = mycas.summaryNodes;

    linksVar
        from   = from
        to     = to
        weight = weight;

    nodesVar
        node = quest_id;

    summary;
run;

%put === SECTION 1 - Network Summary Metrics (from _NETWORK_) ===;
%put &_NETWORK_;
/*
  If VYNA00COURSEMAC.sas is included, replace the line above with:
    %put Nodes         : %GetValue(mac=_NETWORK_, item=NUM_NODES);
    %put Links         : %GetValue(mac=_NETWORK_, item=NUM_LINKS);
    %put Components    : %GetValue(mac=_NETWORK_, item=NUM_COMPONENTS);
    %put Density       : %GetValue(mac=_NETWORK_, item=DENSITY);
  VERIFY: confirm exact item names against your SAS Viya version.
*/

/* Difficulty distribution across all nodes */
proc freq data=mycas.nodesOSRS;
    tables difficulty / nocum;
    title "Section 1 - Quest Count by Difficulty Tier";
run;


/*==============================================================================
  SECTION 2 - CENTRALITY ANALYSIS
  Assessment criterion: centrality measures
==============================================================================*/

/*
  WHY: Centrality answers "which quests matter most structurally?"

    DEGREE (in / out)
      Out-degree = quests that depend on this one as a prerequisite.
                   High out-degree = gateway quest (Druidic Ritual unlocks 12).
      In-degree  = prerequisites this quest itself requires.
                   High in-degree = demanding quest to unlock.

    BETWEENNESS
      Fraction of all pairwise shortest paths that pass through this quest.
      High betweenness = bottleneck in the progression graph. A player blocked
      here is cut off from everything downstream.

    CLOSENESS
      Mean inverse weighted distance from this quest to all reachable nodes.
      High closeness = central to the progression graph; accessible quickly
      from many other quests.

    PAGERANK
      Recursive importance: a quest required by many important quests scores
      higher than one required by many trivial ones. Treats the prerequisite
      graph like a citation network.

  Together these four measures give a multidimensional picture of quest
  importance that no single metric captures alone.
*/
proc network
    direction = directed
    links     = mycas.linksOSRS
    nodes     = mycas.nodesOSRS
    outNodes  = mycas.centralityOSRS;

    linksVar
        from   = from
        to     = to
        weight = weight;

    nodesVar
        node = quest_id;

    centrality
        degree   = weight
        between  = weight
        pagerank = weight;
        /* close (closeness) is not available in this SAS Viya build.
           Confirmed available: degree, between, pagerank, eigen. */
run;

/* Output column names confirmed from SAS Viya 2025.09:
     centr_degree_in_wt, centr_degree_out_wt, centr_between_wt, centr_pagerank_wt */
proc sql;
    create table work.centralityLabelled as
    select
        c.quest_id,
        n.quest_name,
        n.difficulty,
        c.centr_degree_in_wt   as degree_in,
        c.centr_degree_out_wt  as degree_out,
        c.centr_between_wt     as betweenness,
        c.centr_pagerank_wt    as pagerank
    from mycas.centralityOSRS  c
    inner join mycas.nodesOSRS n on c.quest_id = n.quest_id;
quit;

/* Top 10 by out-degree - gateway quests that unlock the most content */
proc sort data=work.centralityLabelled out=work.c_outdeg; by descending degree_out; run;
proc print data=work.c_outdeg (obs=10) noobs label;
    label quest_name="Quest" degree_out="Out-Degree" difficulty="Difficulty";
    var quest_id quest_name difficulty degree_out;
    title "Section 2 - Top 10 by Out-Degree (Gateway Quests)";
run;

/* Top 10 by in-degree - quests with the most prerequisites */
proc sort data=work.centralityLabelled out=work.c_indeg; by descending degree_in; run;
proc print data=work.c_indeg (obs=10) noobs label;
    label quest_name="Quest" degree_in="In-Degree" difficulty="Difficulty";
    var quest_id quest_name difficulty degree_in;
    title "Section 2 - Top 10 by In-Degree (Most Prerequisites Required)";
run;

/* Top 10 by betweenness - structural bottlenecks */
proc sort data=work.centralityLabelled out=work.c_between; by descending betweenness; run;
proc print data=work.c_between (obs=10) noobs label;
    label quest_name="Quest" betweenness="Betweenness";
    var quest_id quest_name difficulty betweenness;
    title "Section 2 - Top 10 by Betweenness Centrality (Progression Bottlenecks)";
run;

/* Top 10 by PageRank - most influential prerequisites */
proc sort data=work.centralityLabelled out=work.c_pagerank; by descending pagerank; run;
proc print data=work.c_pagerank (obs=10) noobs label;
    label quest_name="Quest" pagerank="PageRank";
    var quest_id quest_name difficulty pagerank;
    title "Section 2 - Top 10 by PageRank (Most Influential Prerequisites)";
run;


/*==============================================================================
  SECTION 3 - CONNECTED COMPONENTS, BICONNECTED COMPONENTS,
              AND ARTICULATION POINTS
  Assessment criterion: connectivity analysis
==============================================================================*/

/*
  WHY: Component analysis reveals whether the quest graph is one connected
  whole or a collection of isolated sub-graphs.

    CONNECTED COMPONENTS
      Groups where every node can reach every other by some path (ignoring
      direction). One dominant component means most quests are linked into
      a single progression web. Multiple small components are isolated chains
      with no dependency relationship to the rest of the game.

    BICONNECTED COMPONENTS
      Subgraphs that remain connected after removing any single node.
      Smaller and more granular than connected components. A low count
      suggests the graph has many single-point vulnerabilities.

    ARTICULATION POINTS
      Nodes whose removal increases the component count.
      In OSRS terms: quests that, if removed from the game, would split the
      quest progression web into disconnected parts. The heavier the quest's
      node_weight, the more demanding the chokepoint.
*/
proc network
    direction = directed
    links     = mycas.linksOSRS
    nodes     = mycas.nodesOSRS
    outNodes  = mycas.componentsOSRS
    outLinks  = mycas.compLinksOSRS;

    linksVar
        from = from
        to   = to;

    nodesVar
        node = quest_id;

    connectedComponents;
    /* biConnectedComponents is not a valid PROC NETWORK statement; use PROC OPTNETWORK below */
run;

%put === SECTION 3 - Component Results ===;
%put &_NETWORK_;
/*
  With course macros:
    %put Connected components  : %GetValue(mac=_NETWORK_, item=NUM_COMPONENTS);
    %put Articulation points   : %GetValue(mac=_NETWORK_, item=NUM_ARTICULATION_POINTS);
  VERIFY: confirm item names above.
*/

/* Component size distribution */
proc sql;
    create table work.compLabelled as
    select
        c.quest_id,
        n.quest_name,
        n.difficulty,
        c.concomp
    from mycas.componentsOSRS  c
    inner join mycas.nodesOSRS n on c.quest_id = n.quest_id
    order by c.concomp, n.quest_name;
quit;

proc freq data=work.compLabelled;
    tables concomp / nocum;
    title "Section 3 - Quest Count per Connected Component";
run;

/* --- 3b: Biconnected components and articulation points (PROC OPTNETWORK) - */
/*
  biConnectedComponents requires PROC OPTNETWORK, not PROC NETWORK.
  Output: outNodes contains artpoint=1 for articulation point nodes,
          joined on 'node' (not quest_id).
*/
proc optnetwork
    links    = mycas.linksOSRS
    outNodes = mycas.artPointsOSRS;

    linksVar
        from = from
        to   = to;

    biconnectedComponents;
run;

/*
  Articulation points: quests whose removal disconnects the graph.
  Sorted by node_weight descending so the most demanding chokepoints
  appear first - these are the best candidates for scenario analysis.
*/
proc sql;
    create table work.artPoints as
    select
        a.node           as quest_id,
        n.quest_name,
        n.difficulty,
        n.num_quest_prereqs,
        n.node_weight
    from mycas.artPointsOSRS  a
    inner join mycas.nodesOSRS n on a.node = n.quest_id
    where a.artpoint = 1
    order by n.node_weight descending;
quit;

proc print data=work.artPoints noobs label;
    label quest_name="Quest"  node_weight="Node Weight";
    var quest_id quest_name difficulty num_quest_prereqs node_weight;
    title "Section 3 - Articulation Points (Quests Critical to Graph Connectivity)";
run;


/*==============================================================================
  SECTION 4 - COMMUNITY DETECTION
  Assessment criterion: community / cluster analysis
==============================================================================*/

/*
  WHY: Community detection finds groups of quests that are more densely
  connected to each other than to the rest of the graph. Applied to OSRS,
  we expect clusters to align with the game's quest series (Myreque, Elf,
  Gnome, Fremennik, etc.) even though the algorithm has no knowledge of
  those labels. A good clustering outcome validates that the prerequisite
  structure encodes narrative structure.

  The Louvain algorithm maximises modularity - the degree to which the
  detected partition exceeds a random graph of equal density. It handles
  sparse directed graphs well and scales efficiently to our 189-node graph.
*/
proc network
    direction = directed
    links     = mycas.linksOSRS
    nodes     = mycas.nodesOSRS
    outNodes  = mycas.communityOSRS;

    linksVar
        from   = from
        to     = to
        weight = weight;

    nodesVar
        node = quest_id;

    community
        resolutionList = 1.0
        outLevel       = mycas.communityLevel;
        /* output column in mycas.communityOSRS is 'community_1' (first resolution level).
           'algorithm = louvain' is not a valid option in this SAS Viya build. */
run;

proc sql;
    create table work.communityLabelled as
    select
        c.quest_id,
        n.quest_name,
        n.difficulty,
        c.community_1
    from mycas.communityOSRS  c
    inner join mycas.nodesOSRS n on c.quest_id = n.quest_id
    order by c.community_1, n.difficulty, n.quest_name;
quit;

/* How many quests per community? */
proc freq data=work.communityLabelled;
    tables community_1 / nocum;
    title "Section 4 - Quests per Community (Louvain / Resolution 1.0)";
run;

/* Community size summary with percentage */
proc sql;
    title "Section 4 - Community Size Summary";
    select
        community_1,
        count(*)                      as size,
        count(*) / 189.0 * 100
            format=5.1                as pct_of_all_quests
    from work.communityLabelled
    group by community_1
    order by size descending;
quit;

/* Full listing so we can examine which quests cluster together */
proc print data=work.communityLabelled noobs label;
    label quest_name="Quest"  community_1="Community ID";
    var community_1 quest_id quest_name difficulty;
    title "Section 4 - Full Community Assignment Listing";
run;


/*==============================================================================
  SECTION 5 - SHORTEST PATHS
  Assessment criterion: path analysis / graph diameter
==============================================================================*/

/*
  WHY: Shortest path analysis reveals the minimum-cost route to complete
  a quest chain and identifies the graph's diameter: the longest shortest
  path, which is the hardest chain any player must traverse.

  Source node: Quest 18 = Druidic Ritual (Novice).
  Chosen because it has the highest out-degree in the dataset (12 quests
  depend on it). It is also a trivial entry-level quest, so choosing it
  as the source represents a realistic player starting point, and paths
  from it cover the broadest slice of the quest graph.

  We use weighted paths (edge weight = destination node_weight) so that
  path length reflects cumulative unlock difficulty, not hop count.

  Specific destinations highlighted:
    Quest 146 = Dragon Slayer II    (node_weight 91.5 - heaviest quest)
    Quest 175 = While Guthix Sleeps (node_weight 79.7 - most prerequisites: 10)
    Quest 167 = Desert Treasure II  (node_weight 58.2 - Grandmaster)
    Quest 153 = Song of the Elves   (node_weight 72.0 - Grandmaster)
    Quest 138 = Monkey Madness II   (node_weight 52.9 - Grandmaster)
*/
proc network
    direction = directed
    links     = mycas.linksOSRS
    nodes     = mycas.nodesOSRS;

    linksVar
        from   = from
        to     = to
        weight = weight;

    nodesVar
        node = quest_id;

    shortestPath
        source     = 18
        outWeights = mycas.spWeightsOSRS
        outPaths   = mycas.spPathsOSRS;
        /* outWeights: one row per reachable node — sink (node ID) + path_weight.
           outPaths:   one row per edge on each discovered path. */
run;

proc sql;
    create table work.spLabelled as
    select
        s.sink         as quest_id,
        n.quest_name,
        n.difficulty,
        s.path_weight  as path_length
    from mycas.spWeightsOSRS  s
    inner join mycas.nodesOSRS n on s.sink = n.quest_id
    where s.path_weight is not null
    order by s.path_weight descending;
quit;

/* Longest paths from Druidic Ritual - diameter candidates */
proc print data=work.spLabelled (obs=15) noobs label;
    label quest_name="Quest"  path_length="Weighted Path Length";
    var quest_id quest_name difficulty path_length;
    title "Section 5 - Longest Weighted Paths from Druidic Ritual (Diameter Candidates)";
run;

/* Paths to the five hardest Grandmaster/Master endgame quests */
proc sql;
    title "Section 5 - Path Lengths to Hardest Endgame Quests from Druidic Ritual";
    select
        s.quest_id,
        n.quest_name,
        n.difficulty,
        n.node_weight,
        s.path_length
    from work.spLabelled  s
    inner join mycas.nodesOSRS n on s.quest_id = n.quest_id
    where s.quest_id in (146, 175, 167, 153, 138, 155)
    order by s.path_length descending;
quit;


/*==============================================================================
  SECTION 6 - BIPARTITE ANALYSIS (QUEST-SKILL GRAPH)
  Assessment criterion: bipartite graph analysis and projection
==============================================================================*/

/*
  WHY: The bipartite layer connects quests to the skills they require.
  Unlike the main quest graph (quest -> quest), this layer reveals which
  skills act as universal gates across multiple quest chains - a skill
  bottleneck that blocks more quests than any single quest prerequisite.

  Bipartite structure:
    Partition A (quests) : node IDs 0-188
    Partition B (skills) : node IDs 1001-1023
    Edge weight          : minimum skill level required

  Three analyses follow:
    6a - Degree centrality: most-required skills; most skill-intensive quests.
    6b - Skill projection:  which skills co-occur in quest requirements?
    6c - Quest projection:  which quests share the most skill requirements?
*/

/* --- 6a: Degree centrality on the bipartite graph ----------------------- */
/*
  Running PROC NETWORK on the bipartite graph to count connections on each
  side. We use undirected mode because the edge direction (quest->skill) is
  a data-model artifact; both partitions accumulate degree symmetrically.
*/
proc network
    direction = undirected
    links     = mycas.linksBipartite
    nodes     = mycas.nodesBipartite
    outNodes  = mycas.bipartiteNodes;

    linksVar
        from   = from
        to     = to
        weight = weight;

    nodesVar
        node = node_id;

    centrality degree = unweight;
    /* outNodes (bipartiteNodes) gets: node_id + degree centrality column only.
       node_name and node_type must be joined from nodesBipartite below. */
run;

/* Diagnostic: reveal the actual column name produced by centrality degree = unweight */
proc contents data=mycas.bipartiteNodes;
    title "Section 6a DIAGNOSTIC - bipartiteNodes variable list";
run;
proc print data=mycas.bipartiteNodes (obs=3);
    title "Section 6a DIAGNOSTIC - bipartiteNodes sample rows";
run;

/* Pull all columns from bipartiteNodes into a work table — avoids hardcoding the
   degree column name, which varies by SAS Viya build. The diagnostic proc contents
   above will confirm the real column name so we can hard-code it in a future run. */
proc sql;
    create table work.bipartiteNodesFull as
    select b.*, nb.node_name, nb.node_type
    from mycas.bipartiteNodes b
    inner join mycas.nodesBipartite nb on b.node_id = nb.node_id;
quit;

/* Most-required skills: pick the second variable (the degree column, whatever it is)
   by renaming it via a DATA step after we see it in the proc contents output.
   For now, select * and let the data speak — print will show the column name. */
proc print data=work.bipartiteNodesFull (obs=5) noobs;
    where node_type = 1;
    title "Section 6a - bipartiteNodesFull skill rows (shows degree column name)";
run;

/* Placeholder sorted outputs — will be corrected once degree column name is known */
proc sort data=work.bipartiteNodesFull out=work.skillDegree;
    where node_type = 1;
    by descending node_id;   /* temp sort; replace with degree col once confirmed */
run;

proc print data=work.skillDegree (obs=15) noobs;
    title "Section 6a - Most Required Skills (Bipartite Degree) - SEE COLUMN NAMES ABOVE";
run;

proc sort data=work.bipartiteNodesFull out=work.questSkillDegree;
    where node_type = 0;
    by descending node_id;   /* temp sort; replace with degree col once confirmed */
run;

proc print data=work.questSkillDegree (obs=15) noobs;
    title "Section 6a - Most Skill-Intensive Quests (Bipartite Degree) - SEE COLUMN NAMES ABOVE";
run;

/* --- 6b: Skill-side projection (SQL self-join) -------------------------- */
/*
  Two skills are projected-connected if at least one quest requires both.
  Edge weight = number of quests requiring both skills simultaneously.
  This reveals which skill pairs are systematically bundled by quest designers.
*/
proc sql;
    create table work.skillProjection as
    select
        sn1.node_name   as skill_a,
        sn2.node_name   as skill_b,
        count(*)        as shared_quests
    from       mycas.linksBipartite     a
    inner join mycas.linksBipartite     b  on  a.from  = b.from    /* same quest */
                                           and a.to    < b.to      /* no duplicates */
    inner join mycas.nodesBipartite  sn1  on a.to   = sn1.node_id
    inner join mycas.nodesBipartite  sn2  on b.to   = sn2.node_id
    group by sn1.node_name, sn2.node_name
    order by shared_quests descending;
quit;

proc print data=work.skillProjection (obs=20) noobs label;
    label skill_a="Skill A"  skill_b="Skill B"  shared_quests="Quests Requiring Both";
    title "Section 6b - Skill Co-occurrence Projection (Skill-Skill)";
run;

/* --- 6c: Quest-side projection (SQL self-join) -------------------------- */
/*
  Two quests are projected-connected if they share at least one required skill.
  Edge weight = count of shared required skills.
  High weight = quests that demand the same player build to complete.
  Filter: only pairs sharing 3+ skills to focus on meaningful similarity.
*/
proc sql;
    create table work.questProjection as
    select
        qn1.quest_name   as quest_a,
        qn2.quest_name   as quest_b,
        count(*)         as shared_skills
    from       mycas.linksBipartite     a
    inner join mycas.linksBipartite     b  on  a.to    = b.to      /* same skill */
                                           and a.from  < b.from    /* no duplicates */
    inner join mycas.nodesOSRS       qn1  on a.from = qn1.quest_id
    inner join mycas.nodesOSRS       qn2  on b.from = qn2.quest_id
    group by qn1.quest_name, qn2.quest_name
    having count(*) >= 3
    order by shared_skills descending;
quit;

proc print data=work.questProjection (obs=20) noobs label;
    label quest_a="Quest A"  quest_b="Quest B"  shared_skills="Shared Skill Reqs";
    title "Section 6c - Quest Similarity by Shared Skills (Quest-Quest Projection)";
run;

/* Maximum level demanded per skill across all quests */
proc sql;
    title "Section 6 - Maximum Level Required and Frequency per Skill";
    select
        sn.node_name               as skill,
        count(*)                   as times_required,
        max(b.weight)              as max_level_required,
        avg(b.weight) format=6.1   as avg_level_required
    from       mycas.linksBipartite    b
    inner join mycas.nodesBipartite   sn on b.to = sn.node_id
    where sn.node_type = 1
    group by sn.node_name
    order by times_required descending;
quit;


/*==============================================================================
  SECTION 7 - GRAPH BACKBONE: CRITICAL PREREQUISITE EDGES
  Assessment criterion: optimisation / graph backbone
==============================================================================*/

/*
  WHY: Identifying the backbone of the quest graph reveals which prerequisite
  relationships carry the most structural weight — the edges that, if cut,
  would most disrupt the progression system.

  NOTE: The PROC NETWORK spanning tree statement is not available in this
  SAS Viya build. The backbone is instead identified by analysing edge weight
  distribution and ranking the most costly prerequisite links. A tree on N
  nodes has N-1 edges; for 189 quests this is 188 backbone edges out of 245
  total, leaving 57 redundant/alternate routes.

  High-weight edges represent points where the game demands a large investment
  before unlocking the next quest — these are the critical transitions on the
  progression backbone regardless of whether they appear in an MST.
*/

/* Full edge list with quest names, sorted by weight descending */
proc sql;
    create table work.backboneEdges as
    select
        qn1.quest_name       as prerequisite_quest,
        qn2.quest_name       as unlocked_quest,
        qn2.difficulty       as difficulty,
        l.weight
    from       mycas.linksOSRS   l
    inner join mycas.nodesOSRS qn1 on l.from = qn1.quest_id
    inner join mycas.nodesOSRS qn2 on l.to   = qn2.quest_id
    order by l.weight descending;
quit;

/* Top 25 highest-weight prerequisite links */
proc print data=work.backboneEdges (obs=25) noobs label;
    label prerequisite_quest="Prerequisite"
          unlocked_quest="Unlocked Quest"
          weight="Edge Weight (Difficulty of Destination)";
    title "Section 7 - Top 25 Highest-Weight Prerequisite Links (Progression Backbone)";
run;

/* Edge weight distribution */
proc means data=work.backboneEdges n mean median min max stddev;
    var weight;
    title "Section 7 - Edge Weight Distribution Across All 245 Prerequisite Links";
run;

/* Edge count and average weight by destination difficulty tier */
proc sql;
    title "Section 7 - Edge Count by Destination Quest Difficulty";
    select
        difficulty,
        count(*)                     as edge_count,
        count(*) / 245.0 * 100
            format=5.1               as pct_of_all_edges,
        avg(weight)   format=6.2     as avg_weight
    from work.backboneEdges
    group by difficulty
    order by avg_weight descending;
quit;


/*==============================================================================
  SECTION 8 - SUMMARY DASHBOARD
  Consolidated statistics for assessment presentation
==============================================================================*/

title1 "OSRS Quest Network - Assessment Summary Dashboard";
title2 "7CS114 Network Analysis | Adam Birch | University of Wolverhampton";

/* Network dimensions */
proc sql;
    title3 "Network Dimensions";
    select "Quest nodes (graph vertices)"         as Metric,
           count(*) format=8.0                    as Value
    from mycas.nodesOSRS
    union all
    select "Quest dependency edges (directed)",   count(*)
    from mycas.linksOSRS
    union all
    select "Quest-skill bipartite edges",         count(*)
    from mycas.linksBipartite
    union all
    select "Skill nodes (bipartite layer)",       count(distinct to)
    from mycas.linksBipartite;
quit;

/* Difficulty distribution */
proc freq data=mycas.nodesOSRS;
    tables difficulty / nocum;
    title3 "Quest Count by Difficulty Tier";
run;

/* Ten most demanding quests overall */
/* Copy CAS table to WORK before sorting — PROC SORT direct from CAS returns 0 obs */
data work.nodesLocal; set mycas.nodesOSRS; run;
proc sort data=work.nodesLocal out=work.heaviest; by descending node_weight; run;
proc print data=work.heaviest (obs=10) noobs label;
    label quest_name="Quest"  node_weight="Node Weight"  difficulty="Difficulty";
    var quest_id quest_name difficulty num_quest_prereqs num_skill_reqs node_weight;
    title3 "Top 10 Most Demanding Quests (Composite Node Weight)";
run;

/* Most required skills summary */
proc print data=work.skillDegree (obs=10) noobs label;
    label skill_name="Skill"  quests_requiring="Quests Requiring";
    title3 "Top 10 Most Required Skills";
run;

/* Most frequent skill co-occurrence */
proc print data=work.skillProjection (obs=5) noobs label;
    label skill_a="Skill A"  skill_b="Skill B"  shared_quests="Shared Quests";
    title3 "Top 5 Skill Co-occurrence Pairs";
run;

/* Top gateway quests by out-degree */
proc print data=work.c_outdeg (obs=5) noobs label;
    label quest_name="Quest"  degree_out="Quests Unlocked";
    var quest_name difficulty degree_out;
    title3 "Top 5 Gateway Quests (Out-Degree)";
run;

/* Top bottleneck quests by betweenness */
proc print data=work.c_between (obs=5) noobs label;
    label quest_name="Quest"  betweenness="Betweenness Score";
    var quest_name difficulty betweenness;
    title3 "Top 5 Bottleneck Quests (Betweenness Centrality)";
run;

title;   /* reset titles */

/*
  Leave CAS session open for interactive table exploration in Viya Explorer.
  When fully finished, terminate with:
    cas mysess terminate;
*/
