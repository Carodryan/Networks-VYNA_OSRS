cas mysess; 
libname mycas cas sessref=mysess;

data mycas.nodesOSRS;
length quest_name $100 difficulty $20;

infile datalines dlm=',' dsd truncover;

input 
    quest_id 
    quest_name :$100.
    difficulty :$20.
    difficulty_score
    num_quest_prereqs
    num_skill_reqs
    total_skill_level
    node_weight;

datalines;
0,Learning the Ropes,Novice,1,0,0,0,1
1,Cook's Assistant,Novice,1,0,0,0,1
2,Demon Slayer,Novice,1,0,0,0,1
3,The Restless Ghost,Novice,1,0,0,0,1
4,Romeo & Juliet,Novice,1,0,0,0,1
5,Sheep Shearer,Novice,1,0,0,0,1
6,Shield of Arrav,Novice,1,0,0,0,1
7,Ernest the Chicken,Novice,1,0,0,0,1
8,Vampyre Slayer,Intermediate,2,0,0,0,2
9,Imp Catcher,Novice,1,0,0,0,1
10,Prince Ali Rescue,Novice,1,0,0,0,1
11,Doric's Quest,Novice,1,0,1,15,3.5
12,Black Knights' Fortress,Intermediate,2,0,1,12,4.2
13,Witch's Potion,Novice,1,0,0,0,1
14,The Knight's Sword,Intermediate,2,0,4,50,11
15,Goblin Diplomacy,Novice,1,0,0,0,1
16,Pirate's Treasure,Novice,1,0,0,0,1
17,Dragon Slayer I,Experienced,3,0,2,40,9
18,Druidic Ritual,Novice,1,0,0,0,1
19,Lost City,Intermediate,2,0,2,67,10.7
20,Witch's House,Intermediate,2,0,0,0,2
21,Merlin's Crystal,Intermediate,2,0,0,0,2
22,Heroes' Quest,Experienced,3,5,5,236,36.6
23,Scorpion Catcher,Intermediate,2,1,1,31,7.1
24,Family Crest,Experienced,3,0,4,179,24.9
25,Tribal Totem,Intermediate,2,0,1,21,5.1
26,Fishing Contest,Novice,1,0,1,10,3
27,Monk's Friend,Novice,1,0,0,0,1
28,Temple of Ikov,Intermediate,2,0,2,82,12.2
29,Clock Tower,Novice,1,0,0,0,1
30,Holy Grail,Intermediate,2,1,1,20,6
31,Tree Gnome Village,Intermediate,2,0,0,0,2
32,Fight Arena,Intermediate,2,0,0,0,2
33,Hazeel Cult,Novice,1,0,0,0,1
34,Sheep Herder,Novice,1,0,0,0,1
35,Plague City,Novice,1,0,0,0,1
36,Sea Slug,Intermediate,2,0,1,30,6
37,Waterfall Quest,Intermediate,2,0,0,0,2
38,Biohazard,Novice,1,1,0,0,2
39,Jungle Potion,Novice,1,1,1,3,3.3
40,The Grand Tree,Intermediate,2,0,1,25,5.5
41,Shilo Village,Intermediate,2,1,3,56,11.6
42,Underground Pass,Experienced,3,1,1,25,7.5
43,Observatory Quest,Intermediate,2,0,0,0,2
44,The Tourist Trap,Intermediate,2,0,2,30,7
45,Watchtower,Intermediate,2,1,5,109,18.9
46,Dwarf Cannon,Novice,1,0,0,0,1
47,Murder Mystery,Novice,1,0,0,0,1
48,The Dig Site,Intermediate,2,1,3,45,10.5
49,Gertrude's Cat,Novice,1,0,0,0,1
50,Legends' Quest,Master,4,5,11,602,80.2
51,Rune Mysteries,Novice,1,0,0,0,1
52,Big Chompy Bird Hunting,Intermediate,2,0,3,65,11.5
53,Elemental Workshop I,Novice,1,0,4,90,14
54,Priest in Peril,Novice,1,0,0,0,1
55,Nature Spirit,Intermediate,2,2,1,18,6.8
56,Death Plateau,Novice,1,0,0,0,1
57,Troll Stronghold,Intermediate,2,1,1,15,5.5
58,Tai Bwo Wannai Trio,Intermediate,2,1,5,149,22.9
59,Regicide,Experienced,3,1,2,66,12.6
60,Eadgar's Ruse,Intermediate,2,2,1,31,8.1
61,Shades of Mort'ton,Intermediate,2,2,3,40,11
62,The Fremennik Trials,Intermediate,2,0,0,0,2
63,Horror from the Deep,Intermediate,2,1,1,35,7.5
64,Throne of Miscellania,Experienced,3,2,0,0,5
65,Monkey Madness I,Master,4,2,0,0,6
66,Haunted Mine,Experienced,3,1,1,35,8.5
67,Troll Romance,Intermediate,2,1,2,73,12.3
68,In Search of the Myreque,Intermediate,2,1,1,25,6.5
69,Creature of Fenkenstrain,Intermediate,2,2,3,49,11.9
70,Roving Elves,Experienced,3,2,1,56,11.6
71,Ghosts Ahoy,Intermediate,2,2,2,45,10.5
72,One Small Favour,Experienced,3,2,4,109,19.9
73,Mountain Daughter,Intermediate,2,0,1,20,5
74,Between a Rock...,Experienced,3,2,3,120,20
75,The Feud,Intermediate,2,0,1,30,6
76,The Golem,Intermediate,2,0,2,45,8.5
77,Desert Treasure I,Master,4,6,4,163,30.3
78,Icthlarin's Little Helper,Intermediate,2,1,0,0,3
79,Tears of Guthix,Intermediate,2,0,4,132,19.2
80,Zogre Flesh Eaters,Intermediate,2,2,3,42,11.2
81,The Lost Tribe,Intermediate,2,2,3,43,11.3
82,The Giant Dwarf,Intermediate,2,0,4,75,13.5
83,Recruitment Drive,Novice,1,2,0,0,3
84,Mourning's End Part I,Master,4,3,2,110,20
85,Forgettable Tale...,Intermediate,2,2,2,39,9.9
86,Garden of Tranquillity,Intermediate,2,1,1,25,6.5
87,A Tail of Two Cats,Intermediate,2,1,0,0,3
88,Wanted!,Intermediate,2,4,1,32,10.2
89,Mourning's End Part II,Master,4,1,0,0,5
90,Rum Deal,Experienced,3,2,5,221,32.1
91,Shadow of the Storm,Intermediate,2,2,1,30,8
92,Making History,Intermediate,2,2,0,0,4
93,Ratcatchers,Intermediate,2,2,0,0,4
94,Spirits of the Elid,Intermediate,2,0,4,144,20.4
95,Devious Minds,Experienced,3,4,3,165,26.5
96,The Hand in the Sand,Intermediate,2,0,2,66,10.6
97,Enakhra's Lament,Experienced,3,0,5,222,30.2
98,Cabin Fever,Experienced,3,2,4,177,26.7
99,Fairytale I - Growing Pains,Intermediate,2,2,0,0,4
100,Recipe for Disaster,Special,3,1,0,0,4
101,Recipe for Disaster/Another Cook's Quest,Special,3,1,1,10,6
102,Recipe for Disaster/Freeing the Mountain Dwarf,Special,3,2,0,0,5
103,Recipe for Disaster/Freeing the Goblin generals,Special,3,2,0,0,5
104,Recipe for Disaster/Freeing Pirate Pete,Special,3,1,3,104,17.4
105,Recipe for Disaster/Freeing the Lumbridge Guide,Special,3,7,1,40,15
106,Recipe for Disaster/Freeing Evil Dave,Special,3,3,1,25,9.5
107,Recipe for Disaster/Freeing King Awowogei,Special,3,2,2,118,18.8
108,Recipe for Disaster/Freeing Sir Amik Varze,Special,3,2,1,20,8
109,Recipe for Disaster/Freeing Skrach Uglogwee,Special,3,2,2,61,13.1
110,Recipe for Disaster/Defeating the Culinaromancer,Special,3,10,1,175,31.5
111,In Aid of the Myreque,Intermediate,2,1,6,138,22.8
112,A Soul's Bane,Intermediate,2,0,0,0,2
113,Rag and Bone Man I,Novice,1,0,0,0,1
114,Swan Song,Master,4,2,7,417,54.7
115,Royal Trouble,Experienced,3,1,2,80,14
116,Death to the Dorgeshuun,Intermediate,2,1,2,46,9.6
117,Fairytale II - Cure a Queen,Experienced,3,2,3,146,22.6
118,Lunar Diplomacy,Experienced,3,4,7,335,47.5
119,The Eyes of Glouphrie,Intermediate,2,1,3,64,12.4
120,Darkness of Hallowvale,Experienced,3,1,7,178,28.8
121,The Slug Menace,Intermediate,2,2,4,120,20
122,Elemental Workshop II,Intermediate,2,1,2,50,10
123,My Arm's Big Adventure,Experienced,3,3,2,39,11.9
124,Enlightened Journey,Intermediate,2,0,4,106,16.6
125,Eagles' Peak,Novice,1,0,1,27,4.7
126,Animal Magnetism,Intermediate,2,3,5,133,23.3
127,Contact!,Experienced,3,2,0,0,5
128,Cold War,Intermediate,2,0,6,169,24.9
129,The Fremennik Isles,Experienced,3,1,3,122,19.2
130,Tower of Life,Novice,1,0,1,10,3
131,The Great Brain Robbery,Experienced,3,3,3,96,18.6
132,What Lies Below,Intermediate,2,1,1,35,7.5
133,Olaf's Quest,Intermediate,2,1,2,90,14
134,Another Slice of H.A.M.,Intermediate,2,3,2,40,11
135,Dream Mentor,Master,4,2,1,85,15.5
136,Grim Tales,Master,4,2,5,285,39.5
137,King's Ransom,Experienced,3,4,2,110,20
138,Monkey Madness II,Grandmaster,5,5,6,369,52.9
139,Misthalin Mystery,Novice,1,0,0,0,1
140,Client of Kourend,Novice,1,1,0,0,2
141,Rag and Bone Man II,Experienced,3,7,2,60,18
142,Bone Voyage,Intermediate,2,1,1,100,14
143,The Queen of Thieves,Intermediate,2,1,1,20,6
144,The Depths of Despair,Intermediate,2,1,1,18,5.8
145,The Corsair Curse,Intermediate,2,0,0,0,2
146,Dragon Slayer II,Grandmaster,5,8,9,695,91.5
147,Tale of the Righteous,Intermediate,2,1,2,26,7.6
148,A Taste of Hope,Experienced,3,2,5,211,31.1
149,Making Friends with My Arm,Master,4,4,4,241,36.1
150,The Forsaken Tower,Intermediate,2,1,0,0,3
151,The Ascent of Arceuus,Intermediate,2,1,1,12,5.2
152,X Marks the Spot,Novice,1,0,0,0,1
153,Song of the Elves,Grandmaster,5,3,8,560,72
154,The Fremennik Exiles,Master,4,4,5,300,43
155,Sins of the Father,Master,4,2,7,379,50.9
156,A Porcine of Interest,Novice,1,0,0,0,1
157,Getting Ahead,Intermediate,2,0,2,56,9.6
158,Below Ice Mountain,Novice,1,0,1,16,3.6
159,A Night at the Theatre,Master,4,1,0,0,5
160,A Kingdom Divided,Experienced,3,7,7,323,49.3
161,Land of the Goblins,Experienced,3,0,0,0,3
162,Temple of the Eye,Intermediate,2,1,1,10,5
163,Beneath Cursed Sands,Master,4,0,0,0,4
164,Sleeping Giants,Intermediate,2,0,0,0,2
165,The Garden of Death,Intermediate,2,0,1,20,5
166,Secrets of the North,Master,4,4,3,189,29.9
167,Desert Treasure II - The Fallen Empire,Grandmaster,5,7,6,402,58.2
168,The Path of Glouphrie,Experienced,3,3,5,264,37.4
169,Children of the Sun,Novice,1,0,0,0,1
170,Defender of Varrock,Experienced,3,8,2,107,23.7
171,Twilight's Promise,Intermediate,2,1,0,0,3
172,At First Light,Intermediate,2,2,3,103,17.3
173,Perilous Moons,Master,4,1,5,118,21.8
174,The Ribbiting Tale of a Lily Pad Labour Dispute,Novice,1,1,1,15,4.5
175,While Guthix Sleeps,Grandmaster,5,10,7,577,79.7
176,The Heart of Darkness,Experienced,3,1,4,197,27.7
177,Death on the Isle,Intermediate,2,1,2,66,11.6
178,Meat and Greet,Experienced,3,1,0,0,4
179,Ethically Acquired Antiquities,Novice,1,2,1,25,6.5
180,The Curse of Arrav,Master,4,2,6,344,46.4
181,The Final Dawn,Master,4,0,0,0,4
182,Shadows of Custodia,Experienced,3,0,0,0,3
183,Scrambled!,Intermediate,2,0,0,0,2
184,Pandemonium,Novice,1,0,0,0,1
185,Prying Times,Intermediate,2,0,0,0,2
186,Current Affairs,Novice,1,0,0,0,1
187,Troubled Tortugans,Experienced,3,0,0,0,3
188,The Ides of Milk,Novice,1,0,0,0,1
;
run;

data mycas.linksOSRS;
input from to @@;
datalines;
17 22 18 22 19 22 21 22 6 22 21 30 18 39 38 42
18 45 18 48 24 50 22 50 41 50 42 50 37 50 18 60
57 60 54 55 3 55 42 59 39 58 56 57 18 61 54 61
62 64 22 64 40 65 31 65 54 66 57 67 55 68 54 69
3 69 59 70 37 70 54 71 3 71 51 72 41 72 46 74
;
run;