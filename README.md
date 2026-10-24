# 🌐 Godot CodeGraph (`kg`)

[![Godot Engine](https://img.shields.io/badge/Godot-4.4%2B-blue?logo=godotengine)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Python: 3.10+](https://img.shields.io/badge/Python-3.10+-yellow.svg?logo=python)](https://python.org)

**CodeGraph** is a high-performance architecture indexer, code knowledge graph, and symbol navigator tailored specifically for **Godot 4**.

It bridges what standard text searches (grep) and built-in editor tools miss: **`.tscn` scene signal wires**, **`@rpc` multiplayer topologies**, **Autoload dependencies**, and **cross-script callers**.

Available both as a **Godot Editor Plugin (Bottom Panel Dock)** and as an ultra-fast **CLI (`kg`)** engineered for human developers and AI coding agents.

---

## ⚡ What Makes CodeGraph Different?

In Godot, game architecture is split between `.gd` code, `.tscn` scene trees, `project.godot` Autoloads, and runtime networking. Traditional code indexers fail to connect these pieces.

* 📡 **Full `@rpc` Visibility:** Tracks network authority (`authority`, `any_peer`), transfer modes (`call_local`, `reliable`, `unreliable`), and caller counts across your multiplayer game.
* ⚡ **`.tscn` Scene Signal Resolution:** Resolves signals wired in Godot's scene tree (`[connection]`) directly to their receiver scripts and methods.
* 💥 **Impact Analysis (`impact`):** Answer *"If I change this method, which files and functions will be affected across the whole project?"* in milliseconds.
* 🤖 **AI-Agent & Context Optimized:** Output is structured with summary-first counts and grouped caller lines, saving thousands of LLM context tokens for AI assistants (Cursor, Antigravity, Claude, Copilot).
* 🌐 **Interactive Visual Graph (HTML):** Single-click interactive node/canvas graph of your entire game's architecture that opens offline in your web browser.
* 🚀 **Zero External Dependencies:** Built with pure Python 3 standard library + SQLite (FTS5). No `pip install`, no C-compilers, no bloat.

---

## 📊 Benchmark & Performance

Tested on a developer workstation running the real-world production game project ***Sotra Shitty*** (543 files, 155,000+ lines of GDScript, 230+ scenes, 147 `@rpc` endpoints).

### Benchmark Comparison (8 Real Architectural Queries)

We evaluated CodeGraph against two grep models:
* **Grep Naive:** Regular text search + reading ±25 lines around every match (typical naive bot behavior).
* **Grep Competent:** Targeted file list counts (`rg -l -c`), followed by reading ±25 lines in only the top 3 files (skilled developer/agent behavior).

| # | Task / Question | Grep Naive (Tokens) | Grep Competent (Tokens) | Competent Time | CodeGraph Time (Cold/Warm) | CodeGraph (Tokens) | Token Efficiency | Time Saved |
|---|---|---|---|---|---|---|---|---|
| 1 | Who emits `mission_completed`, and who listens? | 34,064 | 1,930 | 91.3 ms | 27.8 / 1.7 ms | 560 | **3.4× fewer** | +89.7 ms (98%) |
| 2 | File outline without opening (`BeatMakerUI.gd`) | 3,056 | 319 | 0.4 ms | 2.4 / 0.4 ms | 533 | 0.6× | +0.0 ms (5%) |
| 3 | Who calls `take_damage`? (53 methods, 191 calls) | 76,340 | 2,308 | 186.0 ms | 26.4 / 3.7 ms | 1,434 | **1.6× fewer** | +182.3 ms (98%) |
| 4 | Which scene connections lead to `close()`? | 1,340 | 1,352 | 107.8 ms | 4.5 / 0.2 ms | 656 | **2.1× fewer** | +107.6 ms (100%) |
| 5 | Who receives `pressed` in `.tscn` files? | 6,702 | 1,976 | 86.0 ms | 16.5 / 3.9 ms | 1,840 | **1.1× fewer** | +82.0 ms (95%) |
| 6 | Where do `@rpc` functions exist, and who calls them? | 32,016 | 1,932 | 103.7 ms | 157.6 / 14.9 ms | 856 | **2.3× fewer** | +88.8 ms (86%) |
| 7 | What is impacted by changing `GameState`? | 574,486 | 3,544 | 172.8 ms | 19.5 / 10.7 ms | 780 | **4.5× fewer** | +162.1 ms (94%) |
| 8 | Who uses group `'civilians'`? (membership vs query) | 25,549 | 1,703 | 92.2 ms | 7.8 / 6.7 ms | 358 | **4.8× fewer** | +85.5 ms (93%) |

* **Total Tokens:** Naive Grep: 753,553 · Competent Grep: 15,064 · **CodeGraph: 7,017**
* **Time Saved:** **95% time reduction** (798 ms saved out of 840 ms; average ~42 ms query time warm).
* **Accuracy:** In tasks 4, 5, and 6, grep cannot resolve the receiving script behind scene connections or distinguish RPC authority modes. CodeGraph provides complete and resolved answers.

> [!NOTE]
> **Benchmark Disclaimer & Real-World Expectations**  
> These benchmarks were measured on a specific developer workstation in a large-scale indie game project (*Sotra Shitty*).  
> * Results will vary depending on your CPU, disk speed, and codebase size.  
> * **Smaller projects** (e.g. game jams or prototypes with only a few scenes/scripts) will experience smaller or negligible performance gains, since basic editor search is already near-instantaneous there.  
> * **Medium-to-large projects**, multiplayer games, complex UI hierarchies, and workflows utilizing AI coding assistants will see the most significant gains in speed, accuracy, and token economics.

---

## 🎮 Godot Editor Usage

Once enabled, a new **CodeGraph** dock appears in your bottom panel (next to *Output* and *Debugger*):

1. **Select Mode:** Choose from `find`, `outline`, `callers`, `signal`, `@rpc`, `impact`, `deps`, or `status`.
2. **Search:** Type your symbol or method and press **Enter**.
3. **One-Click Jump:** Click any highlighted `res://...` file and line link to immediately open the script in Godot's editor and scroll directly to that line!
4. **🌐 Visual Graph:** Click to generate and open the interactive canvas in your web browser.

---

## 💻 CLI Usage (`kg`)

You can run CodeGraph directly from your terminal or command prompt:

```bash
# Outline all functions & signals in a script without reading the whole file
python addons/codegraph/backend/graph.py outline PlayerController

# See who calls take_damage grouped by file
python addons/codegraph/backend/graph.py callers take_damage

# Trace signal declarations, emitters, and scene receivers
python addons/codegraph/backend/graph.py signal mission_completed

# Audit multiplayer RPC endpoints and caller counts
python addons/codegraph/backend/graph.py rpc

# Check impact before modifying a class or autoload
python addons/codegraph/backend/graph.py impact GameState --depth 2

# Open interactive visual node graph in browser
python addons/codegraph/backend/graph.py html --open
```

*(Windows: `addons\codegraph\backend\kg.bat <command>` · Linux/macOS: `./addons/codegraph/backend/kg <command>`).*

Every query re-checks file hashes first, so the index is never stale and no background watcher is needed. The index lives in `.codegraph/graph.db` at your project root.

### Output built for AI agents

`callers`, `impact`, `deps` and friends print a **count summary first**, then group hits per file (`scripts/combat/Bullet.gd — 4 calls at L23, L55, ...`). Pass `--all` for one edge per line. Third-party code is out of the way by default:

| Flag | Effect |
|---|---|
| *(default)* | `addons/` and `web/` are **excluded** — the graph is your game logic |
| `--addons` | include `addons/` (also use it if your own code lives there) |
| `--web` | include a JS/`web/` app |
| `--limit N` / `--all` | trim or expand one query |
| `--path DIR` | point at any project root |

`kg symbols` dumps the symbol list as JSON (this is what the editor's autocomplete reads), and `kg verify` runs reindex + the parser selftest — handy in CI.

### Self-Refreshing Index
CodeGraph automatically checks file hashes (`.gd`, `.tscn`, `.tres`) upon invocation. If any file changed, it updates incrementally in ~30 ms. There is no background watcher process or daemon required.

---

## 📦 Installation

### Option 1: Via Godot Asset Library
1. In the Godot Editor, open the **AssetLib** tab at the top.
2. Search for **CodeGraph**.
3. Click **Download** and **Install**.
4. Go to **Project > Project Settings > Plugins** and enable **CodeGraph**.

### Option 2: Manual Installation
1. Clone or download this repository.
2. Copy the `addons/codegraph` folder into your Godot project's `addons/` directory.
3. Enable the plugin under **Project Settings > Plugins**.

### Requirements

| Requirement | Notes |
|---|---|
| **Godot 4.4 or newer** | Tested on 4.7.2. The dock uses `add_control_to_bottom_panel()`, which is deprecated but still present in 4.4–4.7. |
| **Python 3.10+** on `PATH` | Standard library only — no `pip install`. The plugin checks `python`, `python3` and `py`. If none is found, the buttons are disabled and the status bar tells you what to install. Windows: tick **“Add python.exe to PATH”** in the installer. |

CodeGraph writes its index (`graph.db`, `bench.json`, `symbols.json`, `progress.json`) into a `.codegraph/` folder at **your** project root. Add it to your `.gitignore`:

```gitignore
# Godot CodeGraph index (generated, machine specific)
.codegraph/
```

Nothing in `.codegraph/` is meant to be committed, and the plugin never touches your source files.

### Step 3 — teach your AI agent about it (one command, optional)

A plugin is invisible to an AI agent working in the repo. One command fixes that:

```powershell
python addons/codegraph/backend/graph.py agents                # what is installed?
python addons/codegraph/backend/graph.py agents --install      # write the block
python addons/codegraph/backend/graph.py agents --install --tools claude,copilot,cursor
python addons/codegraph/backend/graph.py agents --remove       # undo
```

It writes a block delimited by `<!-- BEGIN CODEGRAPH -->` / `<!-- END CODEGRAPH -->` into your **`AGENTS.md`** (created if missing), telling agents to use `kg` before grep — with *your* project's own numbers (files, functions, signals, autoloads) and the exact command lines. `--tools` adds pointer files for tools that do not read `AGENTS.md`: `CLAUDE.md`, `.github/copilot-instructions.md`, `.cursor/rules/codegraph.mdc`.

Guarantees: everything is inside the markers, so your own text is never touched; a file you already wrote is skipped, not overwritten; re-running only updates the block; `--remove` takes it all out again (and deletes pointer files that contained nothing else). These files are meant to be committed.

No terminal needed: open the **🤖 Agents & Info** tab in the dock and tick **“Teach my AI agents about CodeGraph”** (the same tick box also sits on the search toolbar and on the welcome card). That tab also spells out exactly which files are written, tells you to run the benchmark first if the project is small, and links to the repository and the issue tracker. While nothing is installed, `kg status` prints a one-line hint about the command.

---

## 🔁 Staying up to date (`kg update`)

The plugin checks for a newer version by itself, at most once a day, and shows the result as a small chip on the **⚙️ Machine requirements and updates** card: green `✓ latest`, amber `⚠ 1.1.0 out`, or grey `– no releases yet`. Press **🔍 Check for update** to ask right now; press **⬇ Update to &lt;version&gt;** (twice — the second press is the confirmation) to install it.

Same commands in a terminal:

```powershell
python addons/codegraph/backend/graph.py update              # read-only check, prints the answer
python addons/codegraph/backend/graph.py update --json       # one line for scripts and AI agents
python addons/codegraph/backend/graph.py update --apply      # install (asks for approval in AGENTS.md)
python addons/codegraph/backend/graph.py update --restore    # undo with the newest backup
```

How it works, and why it needs no GitHub token, no release uploads and no AssetLib:

- **Version source:** `version.json` in the repo root on `main` (fetched from raw.githubusercontent.com). If that file is missing, the newest **tag** is used instead, so `git tag v1.1.0 && git push --tags` is all a release has to be. GitHub automatically produces the archive `…/archive/refs/tags/v1.1.0.zip` for every tag — the same artifact the AssetLib downloads — and that zip is what gets installed. Only a real network answer is cached for 24 hours; re-reading a cached answer never refreshes that clock.
- **Nothing is written without permission.** `update` with no flags only reads; the answer (including *when* it last checked) is cached in `.codegraph/update.json` for 24 hours.
- **Install is done by the standalone Python backend, never by the addon itself.** If a new file somehow fails to load in the editor, `kg update --restore` (and a `restore.bat` / `restore.sh` next to the backup) still works.
- **Backup lives outside the project:** `~/.codegraph_backups/<project>-<hash>/<timestamp>/codegraph`, so it is never committed and survives replacing the addon folder. Only files under `addons/codegraph/` are replaced; `__pycache__` and your `.codegraph/` index are left alone. After an install, reload the project in Godot.
- **Agents:** the block `kg agents --install` writes into `AGENTS.md` now tells agents that `kg update` is safe to run, but that `kg update --apply` requires asking you first.
- **Forks:** set `KG_REPO=youruser/yourrepo` and everything (version file, tag list, zip) comes from your fork instead.
- **Your `AGENTS.md` is kept in step.** After an install, the *new* `graph.py` rewrites the CodeGraph block in `AGENTS.md` (and `CLAUDE.md`, `.github/copilot-instructions.md`, `.cursor/rules/codegraph.mdc` if they exist) — nothing is toggled off, and a block you have hand-edited is left alone.
- **Your index stays out of git.** The same card checks that `.gitignore` has a rule for `.codegraph/` (the database, cache and update state are machine-local, and `kg update` refuses to touch them). Missing? One press adds the rule at the end of the file and leaves everything else in it alone.

### Versioning and tagging, in one minute

| what | where | who reads it |
| --- | --- | --- |
| `version = "1.1.0"` | `addons/codegraph/plugin.cfg` | the plugin itself — this is what `kg update` compares against |
| `"version": "1.1.0", "tag": "v1.1.0"` | `version.json` in the repo root, on `main` | `kg update` — the published version, and which zip to download |
| `v1.1.0` | a git **tag** pushed to the repo | the fallback when `version.json` is missing, and the source of the zip |

The three must agree. Numbers compare **numerically** (`1.10.0` is newer than `1.9.0`), so use plain `major.minor.patch`: patch = fixes only, minor = new buttons/commands, major = something moved or the index format changed (`SCHEMA_VERSION` in `graph.py` — bump it and the plugin reindexes by itself next time).

To ship a release:

```powershell
# 1. set the same number in addons/codegraph/plugin.cfg and version.json ("version" + "tag")
# 2. commit and tag:
git add -A
git commit -m "release: 1.1.0"
git tag v1.1.0
git push origin main --tags
```

That is the whole release. Within a minute every project on an older version shows the amber `⚠ 1.1.0 out` chip. No GitHub Release is required — if you do publish one, point `"notes"` at it and the dock shows the link. If a release turns out broken: `git tag -d v1.1.0`, fix forward with a new patch number, and users can always `kg update --restore`.

## 📜 License & Credits

Created by **Olav Alexander Mjelde and Olai Sundal Mjelde**.  
Licensed under the [MIT License](LICENSE).
