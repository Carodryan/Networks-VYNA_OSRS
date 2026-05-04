# Running OSRS_SAS_analysis.sas in SAS Studio (Learner Account)

These instructions assume you are logged into SAS Studio via a learner account
with no persistent storage between sessions. All uploaded files and CAS tables
are lost when you log out. You will need to repeat the upload steps each time.

---

## Files you need ready on your computer before starting

| File | Purpose |
|---|---|
| `OSRS_SAS_code.sas` | Quest node data (the %include source) |
| `quest_network_sas.xlsx` | Complete edge data (Quest Links + Skill Links sheets) |
| `OSRS_SAS_analysis.sas` | The main analysis script |

---

## Step 1 — Find your server-side path

You need to know where SAS Studio will put uploaded files. Run this one-liner
in a **New SAS Program** tab before doing anything else:

```sas
%put Home: %sysget(HOME);
%put Work:  %sysfunc(pathname(work));
```

The `Home:` line in the log gives you something like `/home/u1234567` or
`/home/sasdemo`. That is your upload destination. Note it down.

If `HOME` returns blank, try:

```sas
%put %sysfunc(getoption(work));
```

Use the parent folder of whatever path that returns.

---

## Step 2 — Upload the three files

1. In the **left sidebar** of SAS Studio, click the **Files** tab
   (folder icon, usually labelled *Server Files and Folders*).
2. Navigate to your home folder (the path from Step 1).
3. Optionally create a sub-folder to keep things tidy:
   right-click → **New Folder** → name it `osrs`.
4. Click the **Upload** button (upward-arrow icon in the Files toolbar).
5. Upload all three files: `OSRS_SAS_code.sas`, `quest_network_sas.xlsx`,
   and `OSRS_SAS_analysis.sas`.
6. After upload, right-click any file → **Properties** to confirm the full
   server path. It will look like `/home/u1234567/osrs`.

---

## Step 3 — Open the analysis script

Option A — Open from the Files panel:
- Double-click `OSRS_SAS_analysis.sas` in the Files panel.
  It opens in a new Program tab.

Option B — Paste manually:
- Click **New → SAS Program**.
- Copy the entire contents of `OSRS_SAS_analysis.sas` and paste in.

---

## Step 4 — Set the path and check the course macro

Find the `%let path` line near the top of the script (line 27) and update it
to match your upload location from Step 1:

```sas
%let path = /home/u1234567/osrs;   /* your actual path here */
```

**No trailing slash.** The script appends `./filename` automatically.

**Course macro file (`VYNA00COURSEMAC.sas`):**
In a SAS Viya course environment this file is usually pre-installed at a
fixed path, not in your home folder. Check your course materials or ask your
tutor for the path. If you have it, uncomment the line:

```sas
%include "&path./VYNA00COURSEMAC.sas";
```

If you do not have access to it, leave it commented out. The script will
fall back to `%put &_NETWORK_;` which dumps the same summary values to the
log — you just read them there instead of using `%GetValue`.

---

## Step 5 — Run the script

You have two options depending on how much time you have:

**Option A — Run all sections at once:**
Click **Run** (the play button, or press F3).
The entire script runs top to bottom. Results appear in the **Results** panel
as each PROC finishes. Expect a few minutes for the full run.

**Option B — Run section by section:**
Highlight one section at a time (from one `/*===` comment to the next) and
press **F3**. Useful for checking intermediate results or re-running a single
section without repeating the setup.

> **Always run Section 0 first in every session.** It starts the CAS session
> and loads all tables. Without it, every subsequent section will fail with
> "table not found" errors.

---

## Step 6 — Check the output

Results appear in tabs at the bottom of the screen:

| Tab | What to look at |
|---|---|
| **Results** | All PROC PRINT and PROC FREQ tables |
| **Log** | The `%put &_NETWORK_;` summary output and any error/warning messages |
| **Output Data** | Not used here — results go to Results or work. tables |

To inspect a CAS table interactively after running, go to:
**Libraries → mycas** in the left sidebar and double-click any table.

---

## Common problems and fixes

### "File not found" on %include or PROC IMPORT
The `%let path` does not match where you uploaded the files.
Run `%put %sysget(HOME);` again and compare to your path value.
Check for typos, missing folder name, or extra slash.

### "CAS session not started" / libname mycas does not exist
Section 0 did not finish successfully. Scroll the log to the first ERROR
and fix it before running anything else. Most common cause: a wrong path
on the `%include` line meaning OSRS_SAS_code.sas never ran.

### PROC IMPORT fails on the Excel file
Some learner environments block Excel imports. If you see an error like
`"XLSX engine not licensed"` or `"file format not supported"`, use this
workaround — replace the two `proc import` blocks in Section 0 with the
direct data steps below, then paste the raw data from the CSV exports:

```sas
/* Workaround if PROC IMPORT / XLSX is unavailable:
   Export "Quest Links" sheet from quest_network_sas.xlsx to CSV,
   upload the CSV, then use dbms=csv instead: */
proc import
    datafile = "&path./quest_links.csv"
    out      = work.linksRaw
    dbms     = csv
    replace;
    getnames = yes;
run;
```

Export each sheet from Excel as a separate .csv file (File → Save As →
CSV) and upload those instead of the .xlsx.

### PROC NETWORK centrality output columns are named differently
Print the raw output table immediately after the proc runs:

```sas
proc print data=mycas.centralityOSRS (obs=3); run;
```

Compare the column names you see to the ones used in the PROC SQL joins
below each section, and update accordingly. Variable names vary slightly
between SAS Viya release versions.

### "communityDetection: algorithm=louvain not recognized"
Try `algorithm=label` (label propagation) as a substitute, or omit the
`algorithm=` option entirely to accept the default:

```sas
communityDetection;
```

### Tables disappear between sessions
This is expected — learner accounts have no persistent storage. You must
re-run Section 0 at the start of every new session to rebuild all tables.
You do not need to re-upload files as long as you are still in the same
browser session (files on the server persist longer than CAS tables).
If you have fully logged out, repeat Steps 2–5.

---

## Recommended run order for the assessment video

If you are recording the video in one sitting:

1. Run **Section 0** — confirm row counts table shows 189 / 245 / 212 / 331.
2. Run **Section 1** — show the log for `%put &_NETWORK_;`.
3. Run **Section 2** — show the four top-10 centrality tables.
4. Run **Section 3** — show the component count and articulation points table.
5. Run **Section 4** — show the community size summary and full listing.
6. Run **Section 5** — show the longest-paths table and the hardest-quests query.
7. Run **Section 6** — show skill degree, skill projection, quest projection.
8. Run **Section 7** — show the MST edge table.
9. Run **Section 8** — show the dashboard summary tables.

You do not need to show the code in detail for each section — showing the
output table and speaking to what it means (see `OSRS_presentation_notes.md`)
is sufficient.
