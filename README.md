# 🌐 Godot CodeGraph (`kg`)

[![Godot Engine](https://img.shields.io/badge/Godot-4.x-blue?logo=godotengine)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Python: 3.10+](https://img.shields.io/badge/Python-3.10+-yellow.svg?logo=python)](https://python.org)

**CodeGraph** is a high-performance architecture indexer, code knowledge graph, and symbol navigator for Godot 4. 

It connects what regular text search and Godot's built-in tools miss: **`.tscn` scene signal wires**, **`@rpc` multiplayer topologies**, **Autoload dependencies**, and **cross-script callers**.

Available both as a **Godot Editor Plugin (Bottom Panel Dock)** and as a **lightning-fast CLI (`kg`)** engineered for human developers and AI coding agents.

---

## ✨ Features

* 🚀 **Zero External Dependencies:** Pure Python 3 standard library + SQLite (FTS5). No `pip install` required.
* 🖥️ **Integrated Godot Editor Dock:** Runs right inside the Godot Editor. Click any file or line in the results to jump directly to it in Godot's script editor.
* 🌐 **Interactive Visual Graph (HTML):** Single-click interactive node/canvas graph of your entire game's architecture that opens offline in your web browser.
* 📡 **Full `@rpc` Visibility:** Automatically tracks network authority (`authority`, `any_peer`), transfer modes (`call_local`, `reliable`), and caller counts across your multiplayer game.
* ⚡ **`.tscn` Scene Signal Resolution:** Resolves signals wired in Godot's scene tree (`[connection]`) directly to receiver scripts and methods.
* 💥 **Impact Analysis (`impact`):** Answer *"If I change this method, which files and functions will be affected across the whole project?"* in milliseconds.
* 🤖 **AI-Agent Optimized:** Token-efficient output formatting (summary-first + grouped callers) designed to save thousands of LLM context tokens for AI pair-programmers (Cursor, Antigravity, Claude, Copilot).

---

## 📦 Installation

### Option 1: Via Godot Asset Library
1. Open Godot, click on the **AssetLib** tab at the top.
2. Search for **CodeGraph**.
3. Click **Download** and **Install**.
4. Go to **Project > Project Settings > Plugins** and enable **CodeGraph**.

### Option 2: Manual Installation
1. Clone or download this repository.
2. Copy the `addons/codegraph` folder into your Godot project's `addons/` directory.
3. Enable the plugin under **Project Settings > Plugins**.

*Requirement: Python 3.10 or newer must be in your system's `PATH`.*

---

## 🎮 In-Editor Usage

Once enabled, a new **CodeGraph** tab appears in your bottom panel (next to *Output* and *Debugger*):

1. Select a mode from the dropdown (`find`, `outline`, `callers`, `signal`, `@rpc`, `impact`, `deps`, `status`).
2. Type your query and press **Enter** (or click **Søk**).
3. Click any highlighted file and line number in the results to immediately open that script and jump to the exact line!
4. Click **🌐 Visuell Graf** to view the interactive relationship canvas in your browser.

---

## 💻 CLI Usage (`kg`)

You can also run CodeGraph directly from the terminal (useful for scripts, CI/CD, and AI agents):

```bash
# Windows
addons\codegraph\backend\kg.bat status

# Or directly with Python on any OS:
python addons/codegraph/backend/graph.py find spawn_vehicle
python addons/codegraph/backend/graph.py outline PlayerController
python addons/codegraph/backend/graph.py callers take_damage
python addons/codegraph/backend/graph.py signal mission_completed
python addons/codegraph/backend/graph.py rpc
python addons/codegraph/backend/graph.py impact GameState --depth 2
python addons/codegraph/backend/graph.py html --open
```

### Self-Refreshing Index
CodeGraph automatically checks file hashes (`.gd`, `.tscn`, `.tres`) upon every invocation. If any file changed, it updates incrementally in ~30 ms. There is no background watcher process needed.

---

## 📜 License & Credits

Created by **Olav Alexander Mjelde & Sotra Shitty Devs**.  
Licensed under the [MIT License](LICENSE).
