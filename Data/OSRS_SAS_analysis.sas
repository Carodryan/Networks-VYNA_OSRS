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
%let path = /home/u12345678/osrs;   /* <-- UPDATE THIS */

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
        degree      /* in-degree and out-degree for directed graph */
        betweenness /* betweenness on weighted shortest paths      */
        closeness   /* closeness centrality                        */
        pagerank;   /* VERIFY: keyword may be 'pageRank'           */
run;

/*
  Join centrality scores to quest names.
  VERIFY the output variable names below against your outNodes table -
  print mycas.centralityOSRS to inspect column names if needed.

  Expected names based on current SAS Viya PROC NETWORK documentation:
    cent_degree_in   cent_degree_out   (directed degree)
    cent_between                       (betweenness)
    cent_close_in    cent_close_out    (directed closeness)
    cent_pagerank                      (PageRank)
*/
proc sql;
    create table work.centralityLabelled as
    select
        c.quest_id,
        n.quest_name,
        n.difficulty,
        c.cent_degree_in    as degree_in,
        c.cent_degree_out   as degree_out,
        c.cent_between      as betweenness,
        c.cent_close_in     as closeness_in,
        c.cent_pagerank     as pagerank
    from mycas.centralityOSRS  c
    inner join mycas.nodesOSRS n on c.quest_id = n.quest_id;
quit;

/* If the column names above do not exist, run this to see what is available: */
/* proc print data=mycas.centralityOSRS (obs=3); run; */

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

/* Top 10 by closeness */
proc sort data=work.centralityLabelled out=work.c_close; by descending closeness_in; run;
proc print data=work.c_close (obs=10) noobs label;
    label quest_name="Quest" closeness_in="Closeness (In)";
    var quest_id quest_name difficulty closeness_in;
    title "Section 2 - Top 10 by Closeness Centrality";
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
    biConnectedComponents;
run;

%put === SECTION 3 - Component Results ===;
%put &_NETWORK_;
/*
  With course macros:
    %put Connected components  : %GetValue(mac=_NETWORK_, item=NUM_COMPONENTS);
    %put Biconnected components: %GetValue(mac=_NETWORK_, item=NUM_BICOMPONENTS);
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
        c.concomp   /* connected component ID; VERIFY variable name */
    from mycas.componentsOSRS  c
    inner join mycas.nodesOSRS n on c.quest_id = n.quest_id
    order by c.concomp, n.quest_name;
quit;

proc freq data=work.compLabelled;
    tables concomp / nocum;
    title "Section 3 - Quest Count per Connected Component";
run;

/*
  Articulation points: quests whose removal disconnects the graph.
  Sorted by node_weight descending so the most demanding chokepoints
  appear first - these are the best candidates for scenario analysis.
  VERIFY: biConnectedComponents writes artpoint=1 for articulation nodes.
*/
proc sql;
    create table work.artPoints as
    select
        c.quest_id,
        n.quest_name,
        n.difficulty,
        n.num_quest_prereqs,
        n.node_weight
    from mycas.componentsOSRS  c
    inner join mycas.nodesOSRS n on c.quest_id = n.quest_id
    where c.artpoint = 1
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

    communityDetection
        algorithm = louvain
        outLevel  = mycas.communityLevel;
        /*
          VERIFY: 'louvain' is the correct algorithm keyword.
          Alternative: algorithm=label  (label propagation, faster but less stable).
          outLevel stores the Louvain hierarchy - one row per node per resolution level.
          The community variable in outNodes holds the final partition assignment.
          VERIFY: output variable may be named 'community' or 'comm_id'.
        */
run;

proc sql;
    create table work.communityLabelled as
    select
        c.quest_id,
        n.quest_name,
        n.difficulty,
        c.community   /* VERIFY: variable name */
    from mycas.communityOSRS  c
    inner join mycas.nodesOSRS n on c.quest_id = n.quest_id
    order by c.community, n.difficulty, n.quest_name;
quit;

/* How many quests per community? */
proc freq data=work.communityLabelled;
    tables community / nocum;
    title "Section 4 - Quests per Community (Louvain Algorithm)";
run;

/* Community size summary with percentage */
proc sql;
    title "Section 4 - Community Size Summary";
    select
        community,
        count(*)                      as size,
        count(*) / 189.0 * 100
            format=5.1                as pct_of_all_quests
    from work.communityLabelled
    group by community
    order by size descending;
quit;

/* Full listing so we can examine which quests cluster together */
proc print data=work.communityLabelled noobs label;
    label quest_name="Quest"  community="Community ID";
    var community quest_id quest_name difficulty;
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
    nodes     = mycas.nodesOSRS
    outNodes  = mycas.spOSRS;

    linksVar
        from   = from
        to     = to
        weight = weight;

    nodesVar
        node = quest_id;

    shortestPath
        source        = 18
        outPathsLinks = mycas.spLinksOSRS;
        /*
          VERIFY: 'outPathsLinks' stores one row per edge on each discovered path.
          The source= option computes single-source shortest paths to all nodes.
          Confirm parameter name against your SAS Viya PROC NETWORK documentation.
        */
run;

proc sql;
    create table work.spLabelled as
    select
        s.quest_id,
        n.quest_name,
        n.difficulty,
        s.sppathlen   as path_length   /* VERIFY: weighted path length variable */
    from mycas.spOSRS     s
    inner join mycas.nodesOSRS n on s.quest_id = n.quest_id
    where s.sppathlen is not null
    order by s.sppathlen descending;
    /*
      If the variable is not named sppathlen, inspect mycas.spOSRS:
        proc print data=mycas.spOSRS (obs=5); run;
      Common alternatives: spdist, sp_path_length.
    */
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

    centrality degree;
    /* VERIFY: undirected degree output variable name is 'cent_degree' */
run;

/* Most-required skills (skill side of bipartite graph) */
proc sql;
    create table work.skillDegree as
    select
        node_id                 as skill_id,
        node_name               as skill_name,
        cent_degree             as quests_requiring
        /* VERIFY: variable name cent_degree */
    from mycas.bipartiteNodes
    where node_type = 1
    order by cent_degree descending;
quit;

proc print data=work.skillDegree noobs label;
    label skill_name="Skill"  quests_requiring="Quests Requiring This Skill";
    title "Section 6a - Most Required Skills (Bipartite Degree)";
run;

/* Most skill-intensive quests (quest side of bipartite graph) */
proc sql;
    create table work.questSkillDegree as
    select
        node_id                 as quest_id,
        node_name               as quest_name,
        cent_degree             as distinct_skills_required
    from mycas.bipartiteNodes
    where node_type = 0 and cent_degree > 0
    order by cent_degree descending;
quit;

proc print data=work.questSkillDegree (obs=15) noobs label;
    label quest_name="Quest"  distinct_skills_required="Distinct Skills Required";
    title "Section 6a - Most Skill-Intensive Quests (Bipartite Degree)";
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
  SECTION 7 - MINIMUM SPANNING TREE  (Optional / Optimisation)
  Assessment criterion: optimisation / graph backbone
==============================================================================*/

/*
  WHY: The minimum spanning tree (MST) finds the smallest-weight subset of
  edges that keeps all quest nodes connected in a single tree. In OSRS terms
  this is the "backbone" of the progression system: the irreducible set of
  prerequisite relationships from which everything else follows.

  MST is analytically useful here because:
    - MST edges are the non-redundant prerequisites. Non-MST edges are
      alternate routes that add depth to the graph but are not essential.
    - High-weight MST edges mark the hardest difficulty jumps on the
      critical progression path - the points where the game demands the
      most from a player before unlocking the next chapter.
    - The MST visual is a clean tree layout of the quest spine, useful for
      presentation and for explaining the graph's structure.

  PROC NETWORK requires an undirected graph for MST. We convert by keeping
  unique unordered node pairs, taking the maximum weight where both
  directions exist (conservative: represents the harder direction).

  VERIFY: the MST statement name. It may be 'minSpanTree' or 'spanningTree'.
  Check the SAS Viya PROC NETWORK documentation for your release.
*/

/* Convert to undirected - keep unique pairs with max weight */
proc sql;
    create table work.linksUndirected as
    select
        min(from, to)   as from,
        max(from, to)   as to,
        max(weight)     as weight
    from mycas.linksOSRS
    group by min(from, to), max(from, to);
quit;

data mycas.linksUndirected;
    set work.linksUndirected;
run;

proc network
    direction = undirected
    links     = mycas.linksUndirected
    nodes     = mycas.nodesOSRS
    outLinks  = mycas.mstLinks;

    linksVar
        from   = from
        to     = to
        weight = weight;

    nodesVar
        node = quest_id;

    minSpanTree;   /* VERIFY: may be 'spanningTree' in your Viya version */
run;

/*
  Display MST edges with quest names, heaviest first.
  VERIFY: the outLinks table variable indicating MST membership.
  Common names: mst (= 1 for selected edges), spanning_tree.
  If unsure, inspect with: proc print data=mycas.mstLinks (obs=3); run;
*/
proc sql;
    create table work.mstLabelled as
    select
        qn1.quest_name   as prerequisite_quest,
        qn2.quest_name   as unlocked_quest,
        m.weight
    from       mycas.mstLinks    m
    inner join mycas.nodesOSRS qn1 on m.from = qn1.quest_id
    inner join mycas.nodesOSRS qn2 on m.to   = qn2.quest_id
    where m.mst = 1    /* VERIFY: filter for MST-selected edges */
    order by m.weight descending;
quit;

proc print data=work.mstLabelled (obs=25) noobs label;
    label prerequisite_quest="Prerequisite"
          unlocked_quest="Unlocked Quest"
          weight="Edge Weight";
    title "Section 7 - Minimum Spanning Tree: Quest Progression Backbone";
run;

/* MST weight distribution - shows where the hardest difficulty jumps are */
proc means data=work.mstLabelled n mean median min max;
    var weight;
    title "Section 7 - MST Edge Weight Distribution";
run;


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
proc sort data=mycas.nodesOSRS out=work.heaviest; by descending node_weight; run;
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
