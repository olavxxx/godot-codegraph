# 🌐 Godot CodeGraph (`kg`)

[![Godot Engine](https://img.shields.io/badge/Godot-4.x-blue?logo=godotengine)](https://godotengine.org)
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

*(On Windows, you can also use `addons\codegraph\backend\kg.bat <command>`).*

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

*Requirement: Python 3.10 or newer must be installed and accessible in your system's `PATH`.*

---

## 📜 License & Credits

Created by **Olav Alexander Mjelde and Olai Sundal Mjelde**.  
Licensed under the [MIT License](LICENSE).
