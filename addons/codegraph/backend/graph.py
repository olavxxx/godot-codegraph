#!/usr/bin/env python3
"""
kg — Godot-kodelager for AI-agenter og mennesker. Kun standardbibliotek.

Indexerer .gd / .tscn / .tres / .gdshader / project.godot til SQLite
(.codegraph/graph.db, én per git worktree) og gir presise spørringer i
stedet for at en agent grep-seger 159 000 linjer.

   python addons/codegraph/backend/graph.py index
   python addons/codegraph/backend/graph.py callers take_damage
   python addons/codegraph/backend/graph.py signal mission_completed
   python addons/codegraph/backend/graph.py html --open

Fremtidig vedlikehold: alle regexer står i R-tabellen under. Endres en
regel, må fixtures/ få én miniatyrfil som treffer den (kjør `selftest`).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# Windows-konsoll er cp1252 som standard: tåler ikke æøå eller piler.
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

SCHEMA_VERSION = 12
DB_DIR = ".codegraph"

# Verktøyet sin eiga mappe, uavhengig av kor det ligg i prosjektet
# (addons/codegraph/backend/ som plugin, eller tools/codegraph/ som CLI).
# Addonen ligg éitt steg opp for backend-mappa, så då er det heile addonet
# som skal halde seg ute av grafen — elles trugar fixture-filene til
# sjølve spelet i søk og autocomplete når brukaren slår på --addons.
BACKEND_DIR = Path(__file__).resolve().parent
TOOL_DIR = Path(__file__).resolve().parent
if TOOL_DIR.name == "backend":
    TOOL_DIR = TOOL_DIR.parent
DB_NAME = "graph.db"

INCLUDE_EXT = {".gd", ".tscn", ".tres", ".gdshader"}
EXCLUDE_DIRS = {
    ".git", ".godot", ".vs", ".idea", ".next", "build", "builds", "dist",
    "node_modules", "scratch", "temp_godotsteam", "__pycache__",
}

# --- Regler: én kilde til sannhet. Legg til regex + fixture sammen. ---------
R = {
    "extends":     re.compile(r'^[ \t]*extends[ \t]+(?:"([^"]+)"|([A-Za-z_][\w.]*))'),
    "class_name":  re.compile(r'^[ \t]*class_name[ \t]+([A-Za-z_]\w*)'),
    "inner_class": re.compile(r'^[ \t]*class[ \t]+([A-Za-z_]\w*)[ \t]*(?:extends[ \t]+([A-Za-z_]\w*))?[ \t]*:'),
    "signal":      re.compile(r'^[ \t]*signal[ \t]+([A-Za-z_]\w*)[ \t]*(\(.*\))?\s*(?:#.*)?$'),
    "func":        re.compile(r'^[ \t]*(static[ \t]+)?func[ \t]+([A-Za-z_]\w*)[ \t]*(\(.*\))?'),
    "var":         re.compile(r'^[ \t]*(?:@(export|onready|tool)[ \t]*)*(?:@(export|onready|tool)[ \t]*)*(?:export[ \t]*(?:\([^)]*\))?[ \t]*)?(?:onready[ \t]+)?var[ \t]+([A-Za-z_]\w*)[ \t]*(?::[ \t]*([^#=\n]*))?'),
    "const":       re.compile(r'^[ \t]*const[ \t]+([A-Za-z_]\w*)'),
    "enum":        re.compile(r'^[ \t]*enum[ \t]+([A-Za-z_]\w*)?[ \t]*\{?'),
    "emit":        re.compile(r'emit_signal[ \t]*\([ \t]*["\']([A-Za-z_]\w*)["\']|([A-Za-z_]\w*)\.emit[ \t]*(?:\(|,)'),
    "connect":     re.compile(r'([A-Za-z_$%][\w$.%]*)\.connect[ \t]*\(([^)]*)'),
    "preload":     re.compile(r'\b(preload|load)[ \t]*\([ \t]*["\'](res://[^"\']+)["\']'),
    "res":         re.compile(r'["\'](res://[^"\']+)["\']'),
    "get_node":    re.compile(r'get_node(?:_path)?[ \t]*\([ \t]*["\']([^"\']+)["\']|\$(?:"([^"]+)"|([A-Za-z_]\w*(?:/[A-Za-z_]\w*)*))|%([A-Za-z_]\w*)'),
    "group":       re.compile(r'\b(add_to_group|remove_from_group)[ \t]*\([ \t]*["\']([^"\']+)["\']'
                              r'|\b(call_(?:deferred_)?group)[ \t]*\([ \t]*["\']([^"\']+)["\'][ \t]*,[ \t]*["\']([A-Za-z_]\w*)["\']'
                              r'|\b(is_in_group|get_nodes_in_group|get_first_node_in_group)[ \t]*\([ \t]*["\']([^"\']+)["\']'),
    "singleton":   re.compile(r'get_singleton[ \t]*\([ \t]*["\']([A-Za-z]\w*)["\']'),
    "singleton_attr": None,  # bygget nedenfor ut fra GODOT_SINGLETONS
    "typeref":     re.compile(r'(?::|->)[ \t]*([A-Z]\w*)'),
    "rpc":         re.compile(r'@[ \t]*rpc\b'),
    # heil annotasjonslinje:  @rpc("any_peer", "call_remote")  /  @warning_ignore(...)
    "ann":         re.compile(r'^[ \t]*@[ \t]*([A-Za-z_]\w*)?[ \t]*(\(.*\))?[ \t]*$'),
    "call":        re.compile(r'(?:(\w+)[ \t]*\.[ \t]*)?([A-Za-z_]\w*)[ \t]*\('),
}

# Node-/kant-typer som bygges av resolve-passets (slettes og bygges på nytt
# hver gang) mot setet som bygges ved parse (per fil, bevart).
CROSS_KINDS = (
    "extends", "calls", "emits", "connects_to", "references", "preloads",
    "instantiates", "uses_autoload", "references_node", "calls_group", "in_group",
    "queries_group",
)

BUILTIN_CALLS = set("""
print print_rich push_error push_warning str int float len range abs min max sign pow sqrt clamp clampf clampi
lerp lerpf lerpi round roundi floor floori ceil ceili snapped snapf isnan is_inf is_equal_approx absf absi deg_to_rad rad_to_deg
maxf mini maxi smoothstep wrapi wrapf posmod move_toward step_decimals randomize seed randi randf randf_range randi_range
pick_random weakref typeof type_string get_class is_instance_valid duplicate deep_duplicate inst_to_dict dict_to_inst
add_to_group remove_from_group is_in_group get_nodes_in_group get_first_node_in_group get_groups call_group call_deferred_group
preload load resource_exists str_to_var var_to_str json_to_str str_to_json format_latin_number
Array Dictionary Vector2 Vector3 Vector4 Color Rect2 Rect3 Transform2D Transform3D Basis Quaternion AABB Plane
Node2D Node3D Control Node Resource PackedScene StringName StringName Signal Callable Callable Variant
get_node get_node_or_null get_parent get_children get_child get_index get_tree get_viewport get_node_count set_name set_owner
add_child add_child.callable remove_child reparent move_child print_can_change_bounds queue_free free is_inside_tree request_redraw
set_process set_physics_process set_process_input set_process_unhandled_input set_process_internal set_physics_process_internal
set_meta get_meta has_meta has_method call can_call_deferred call_deferred create_timer reset_physics_interpolation
connect disconnect is_connected emit_signal call_group rpc rpc_config rpcp get_signal_signal_list get_script set_script
global_position position global_rotation rotation scale size velocity delta offset pivot_point look_at rotate_x rotate_y rotate_z
translate translate_object_local apply_force apply_impulse set_axis_velocity move_and_slide move_and_collide
is_network_master multiplayer multiplayer_rpc_config set_multiplayer_authority get_multiplayer_authority
get_viewport get_window get_screen_size get_content_scale_factor get_theme default_font
emit connect disconnect new get set has size is_empty append push_back pop_back pop_front insert erase clear
find count keys values has_all has_any duplicate reduce map filter any all max min sort_custom sort
to_lower to_upper begins_with ends_with replace split join trim_edges left right repeat lpad rpad to_int to_float
set_deferred set_block_size set_position set_rotation set_scale set_modulate set_visible set_texture set_sprite
draw_rect draw_line draw_circle draw_string draw_polyline draw_colored_polygon draw_arc draw_texture draw_set_color
draw_set_font draw_string_outline draw_colored_polygon draw_primitives draw_mesh draw_primitive draw_texture_rect
add_theme_color_override add_theme_font_size_override add_theme_constant_override add_theme_stylebox_override
add_theme_font_override add_theme_font_color_override add_theme_stylebox
sin cos tan atan atan2 asin acos exp log sqrt absf signf floorf ceilf roundf fposmod wrapf move_toward
instantiate distance_to distance_squared_to direction_to angle_to rotated interpolated_with
tween_property tween_callback tween_interval create_tween interpolate_property
""".split())

KEYWORDS = set("""
if elif else and or not in is as return pass break continue while for match var const signal enum class func static
await assert yield self super true false null void PI TAU new get set from then do end try catch finally where
""".split())

GODOT_SINGLETONS = set("""
Engine OS Time Input InputMap RenderingServer PhysicsServer2D PhysicsServer3D AudioServer
ProjectSettings ResourceLoader ResourceSaver DirAccess FileAccess ClassDB EngineDebug
Performance DisplayServer NavigationServer2D NavigationServer3D XRServer ProfilerManager
""".split())

GD_TYPES = set("""
void bool int float String StringName NodePath Color Rect2 Rect2i Rect3 Rect3i Vector2 Vector2i Vector3 Vector3i Vector4
Transform2D Transform3D Basis AABB Plane Quaternion Array Dictionary Variant Signal Callable Node Object RefCounted Resource
""".split())

# Farger delt mellom CLI-JSON og HTML-visningen.
KIND_COLOR = {
    "file": "#5f6b7a", "gd": "#4fb3ff", "scene": "#ffb347", "class": "#8ce56c",
    "fn": "#c792ea", "signal": "#ff6b81", "var": "#7f8fa6", "const": "#a3b18a",
    "enum": "#d4a373", "autoload": "#ffd166", "group": "#ef767a",
    "builtin": "#3b4552", "resource": "#c3a6ff", "shader": "#66d9b1",
    "node_path": "#616e7c", "scene_node": "#9aa5b1",
}
EDGE_COLOR = {
    "extends": "#8ce56c", "calls": "#4fb3ff", "emits": "#ff6b81",
    "connects_to": "#ff6b81", "references": "#a3b18a", "preloads": "#ffb347",
    "instantiates": "#ffb347", "uses_autoload": "#ffd166", "references_node": "#616e7c",
    "calls_group": "#ef767a", "in_group": "#ef767a", "queries_group": "#b26b6e",
    "contains": "#242c36",
    "has_node": "#2f3a45", "has_script": "#ffb347", "attaches_script": "#ffb347",
}

# Én kombinert regex for `Engine.`, `Time.`, `Input.` … (bygget fra listen over)
R["singleton_attr"] = re.compile(r'\b(' + "|".join(sorted(GODOT_SINGLETONS)) + r')[ \t]*\.[ \t]*([a-z_]\w*)')


# --------------------------------------------------------------------------
# Hjelpefunksjoner
# --------------------------------------------------------------------------
def log(msg: str) -> None:
    print(msg, file=sys.stderr)


def find_root(start: str | None) -> Path:
    p = Path(start).resolve() if start else Path.cwd().resolve()
    if p.is_file():
        p = p.parent
    cur = p
    while True:
        if (cur / "project.godot").is_file():
            return cur
        if cur.parent == cur:
            break
        cur = cur.parent
    if (p / "project.godot").is_file():
        return p
    sys.exit(f"Finner ikke project.godot opp fra {p} (pek med --path)")


def strip_comment(line: str) -> str:
    """Fjern # kommando, men ikke inne i strenger."""
    out, q, esc = [], None, False
    for ch in line:
        if esc:
            out.append(ch)
            esc = False
            continue
        if q:
            out.append(ch)
            if ch == q:
                q = None
            continue
        if ch in "\"'":
            q = ch
            out.append(ch)
            continue
        if ch == "#":
            break
        out.append(ch)
    return "".join(out)


def list_files(root: Path, want_web: bool = False, want_addons: bool = False) -> list[str]:
    """git ls-files + filwalk, union, bare include-utvidelser og uten EXCLUDE_DIRS."""
    rels: set[str] = set()

    # Eiga backend + testfixtures er ikkje spelkode, sjølv om brukaren slår på --addons.
    own_rel = ""
    try:
        own_rel = TOOL_DIR.relative_to(Path(root).resolve()).as_posix() + "/"
    except (ValueError, OSError):
        pass

    def keep(rel: str) -> bool:
        parts = rel.replace("\\", "/").split("/")
        if any(p in EXCLUDE_DIRS for p in parts):
            return False
        if own_rel and rel.startswith(own_rel) and root.name != "fixtures":
            return False
        if not want_web and rel.startswith("web/"):
            return False
        if not want_addons and rel.startswith("addons/"):
            return False
        name = parts[-1]
        if name == "project.godot" and len(parts) == 1:
            return True
        return os.path.splitext(name)[1] in INCLUDE_EXT

    try:
        r = subprocess.run(["git", "-C", str(root), "ls-files"],
                           capture_output=True, text=True, timeout=60)
        if r.returncode == 0:
            for line in r.stdout.splitlines():
                rel = line.replace("\\", "/")
                if keep(rel):
                    rels.add(rel)
    except Exception as e:  # git borta eller sandbox: fall tilbake til filwalk
        log(f"(git ls-files utilgjengelig: {e})")

    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for fn in filenames:
            full = Path(dirpath) / fn
            rel = full.relative_to(root).as_posix()
            if keep(rel):
                rels.add(rel)
    return sorted(rels)


# --------------------------------------------------------------------------
# DB
# --------------------------------------------------------------------------
def scope_str(want_web: bool = False, want_addons: bool = False) -> str:
    """Kva filutval indeksen er bygd på. Endrar utvalet seg, må indeksen byggjast på nytt."""
    return f"web={int(bool(want_web))};addons={int(bool(want_addons))}"


def open_db(root: Path) -> sqlite3.Connection:
    d = root / DB_DIR
    d.mkdir(exist_ok=True)
    con = sqlite3.connect(d / DB_NAME)
    con.execute("PRAGMA journal_mode=MEMORY")
    con.execute("PRAGMA foreign_keys=ON")
    # Ny (eller half tod) database: tabellene må finnast før første spørring.
    # ensure_fresh les meta-tabellen før index() eventuelt byggjer alt, og
    # makker ein 0-byte fil utan skjema til sqlite3.OperationalError.
    if not con.execute("SELECT name FROM sqlite_master WHERE name='nodes'").fetchone():
        con.executescript(SCHEMA)
    return con


SCHEMA = """
CREATE TABLE IF NOT EXISTS files(
  path TEXT PRIMARY KEY, kind TEXT, sha TEXT, lines INTEGER, bytes INTEGER, mtime REAL, addons INTEGER);
CREATE TABLE IF NOT EXISTS nodes(
  id INTEGER PRIMARY KEY, key TEXT UNIQUE NOT NULL, kind TEXT NOT NULL, name TEXT NOT NULL,
  file TEXT, line INTEGER, sig TEXT, meta TEXT);
CREATE TABLE IF NOT EXISTS edges(
  id INTEGER PRIMARY KEY, src INTEGER NOT NULL, dst INTEGER NOT NULL, kind TEXT NOT NULL,
  line INTEGER, note TEXT, weight INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS refs(
  file TEXT, kind TEXT, name TEXT, receiver TEXT, arg TEXT, path TEXT, line INTEGER, owner TEXT);
CREATE TABLE IF NOT EXISTS unresolved(
  file TEXT, kind TEXT, name TEXT, receiver TEXT, line INTEGER, reason TEXT);
CREATE INDEX IF NOT EXISTS nodes_name ON nodes(name);
CREATE INDEX IF NOT EXISTS nodes_file ON nodes(file);
CREATE INDEX IF NOT EXISTS edges_src ON edges(src);
CREATE INDEX IF NOT EXISTS edges_dst ON edges(dst);
CREATE INDEX IF NOT EXISTS edges_kind ON edges(kind);
CREATE UNIQUE INDEX IF NOT EXISTS edges_uniq ON edges(src,dst,kind,ifnull(line,0),ifnull(note,''));
CREATE INDEX IF NOT EXISTS refs_file ON refs(file);
CREATE TABLE IF NOT EXISTS search_fts(rowid INTEGER PRIMARY KEY, text);
CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT);
"""


def db_ready(con: sqlite3.Connection) -> bool:
    row = con.execute("SELECT name FROM sqlite_master WHERE name='nodes'").fetchone()
    if not row:
        return False
    ver = con.execute("PRAGMA user_version").fetchone()[0]
    return ver == SCHEMA_VERSION


def init_db(con: sqlite3.Connection) -> None:
    ver = con.execute("PRAGMA user_version").fetchone()[0]
    if ver != SCHEMA_VERSION:
        con.executescript("""
          DROP TABLE IF EXISTS files; DROP TABLE IF EXISTS nodes; DROP TABLE IF EXISTS edges;
          DROP TABLE IF EXISTS refs; DROP TABLE IF EXISTS unresolved;
          DROP TABLE IF EXISTS search_fts; DROP TABLE IF EXISTS meta;
        """)
        con.execute(f"PRAGMA user_version={SCHEMA_VERSION}")
    con.executescript(SCHEMA)


def has_fts(con: sqlite3.Connection) -> bool:
    try:
        con.execute("SELECT count(*) FROM search_fts")
        return True
    except Exception:
        return False


# --------------------------------------------------------------------------
# Parsers
# --------------------------------------------------------------------------
def annotations_before(lines: list[str], idx: int) -> list[str]:
    """Annotasjonslinjene (@rpc(...), @export, ...) som står heilt over linje idx.
    GDScript krev annotasjon på si eiga linje, så @rpc må lesast baklengs."""
    out: list[str] = []
    k, blank = idx - 1, 0
    while k >= 1 and blank <= 2:
        raw = strip_comment(lines[k - 1]).strip()
        if not raw:
            blank += 1
            k -= 1
            continue
        m = R["ann"].match(raw)
        if m and m.group(1):
            out.append(raw)
            k -= 1
            continue
        break
    return out[::-1]


def parse_gd(text: str) -> tuple[list[dict], list[dict]]:
    """Returner (deklarasjoner, referanser) for én GDScript-fil."""
    decls, refs = [], []
    lines = text.splitlines()
    scope_stack: list[tuple[int, str | None, str | None]] = [(-1, None, None)]  # (indent, klasse, funksjon)
    owner_at: dict[int, str | None] = {}

    def indent_of(s: str) -> int:
        return len(s) - len(s.lstrip(" \t"))

    for i, raw in enumerate(lines, 1):
        line = strip_comment(raw)
        if not line.strip():
            continue
        ind = indent_of(line)
        while len(scope_stack) > 1 and ind <= scope_stack[-1][0]:
            scope_stack.pop()
        owner_class = scope_stack[-1][1]
        owner_at[i] = scope_stack[-1][2]
        s = line.strip()
        if s.endswith("\\") or (s.count("(") > s.count(")")):
            merged = s
            k = i
            while (merged.count("(") > merged.count(")")) and k < len(lines):
                k += 1
                merged += " " + strip_comment(lines[k - 1]).strip()
            s = merged[:600]

        m = R["ann"].match(s)
        if m and m.group(1):
            # heil annotasjonslinje (@rpc / @export / @warning_ignore) — handsamast
            # saman med deklarasjonen under i annotations_before()
            continue
        m = R["class_name"].match(s)
        if m:
            decls.append(dict(kind="class", name=m.group(1), line=i, sig=s[:200], cls=None))
            continue
        m = R["inner_class"].match(s)
        if m:
            decls.append(dict(kind="class", name=m.group(1), line=i, sig=s[:200], cls=owner_class,
                              parent=m.group(2)))
            scope_stack.append((ind, m.group(1), None))
            if m.group(2):
                refs.append(dict(kind="extends", name=m.group(2), receiver=None, arg=None, path=None, line=i))
            continue
        m = R["extends"].match(s)
        if m and not s.startswith("class "):
            if m.group(1):
                refs.append(dict(kind="preloads", name=None, receiver=None, arg="extends",
                                 path=m.group(1), line=i))
            elif m.group(2):
                refs.append(dict(kind="extends", name=m.group(2), receiver=None, arg=None, path=None, line=i))
            continue
        m = R["signal"].match(s)
        if m:
            decls.append(dict(kind="signal", name=m.group(1), line=i, sig=(m.group(2) or "").strip()[:200], cls=owner_class))
            continue
        m = R["func"].match(s)
        if m:
            sig = (m.group(3) or "").strip()
            anns = [] if R["rpc"].search(s) else annotations_before(lines, i)
            is_rpc = R["rpc"].search(s) is not None or any(a.startswith("@rpc") for a in anns)
            sigtxt = (("static " if m.group(1) else "") + m.group(2) + "(" + sig.strip("()") + ")")
            if is_rpc:
                sigtxt += "   " + next((a for a in anns if a.startswith("@rpc")), "@rpc")
            decls.append(dict(kind="fn", name=m.group(2), line=i, sig=sigtxt[:300], cls=owner_class,
                              meta="rpc" if is_rpc else None))
            scope_stack.append((ind, owner_class, m.group(2)))
            continue
        m = R["const"].match(s)
        if m:
            decls.append(dict(kind="const", name=m.group(1), line=i, sig=s[:200], cls=owner_class))
            continue
        m = R["enum"].match(s)
        if m:
            decls.append(dict(kind="enum", name=m.group(1) or "(anon)", line=i, sig=s[:120], cls=owner_class))
            continue
        m = R["var"].match(s)
        if m:
            ann = (m.group(4) or "").strip()
            vname = m.group(3)
            decls.append(dict(kind="var", name=vname, line=i, sig=s[:200], cls=owner_class,
                              meta="export" if (m.group(1) or m.group(2) or "export" in s.split("var")[0]) else None))
            if ann and re.fullmatch(r"[A-Z]\w*", ann) and ann not in GD_TYPES:
                refs.append(dict(kind="references", name=ann, receiver=None, arg="var", path=None, line=i))
                refs.append(dict(kind="vartype", name=ann, receiver=vname, arg=None, path=None, line=i))
            pm = R["preload"].search(s)
            if pm:
                refs.append(dict(kind="varfile", name=None, receiver=vname, arg=pm.group(1),
                                 path=pm.group(2), line=i))
            # fell gjennom: kroppen på linjen kan også innehalde kall
        for mm in R["emit"].finditer(s):
            nm = mm.group(1) or mm.group(2)
            if nm:
                refs.append(dict(kind="emits", name=nm, receiver=None, arg=None, path=None, line=i))
        for mm in R["connect"].finditer(s):
            recv, arg = mm.group(1), (mm.group(2) or "").strip()
            sig_name = recv.split(".")[-1].lstrip("$%")
            handler = None
            hm = re.search(r'["\']([A-Za-z_]\w*)["\']', arg) or re.search(r'\b([a-z_]\w*)\b', arg)
            if hm:
                handler = hm.group(1)
            refs.append(dict(kind="connects", name=sig_name, receiver=recv, arg=handler, path=None, line=i))
        for mm in R["preload"].finditer(s):
            refs.append(dict(kind="preloads", name=None, receiver=mm.group(1), arg=None, path=mm.group(2), line=i))
        for mm in R["group"].finditer(s):
            # gruppene blir tre heilt ulike kantar: medlemskap, spørring og gruppekall
            if mm.group(1):                      # add_to_group / remove_from_group
                refs.append(dict(kind="group", name=mm.group(2), receiver=mm.group(1),
                                 arg="member", path=None, line=i))
            elif mm.group(3):                    # call_group("g", "metode")
                refs.append(dict(kind="group", name=mm.group(4), receiver=mm.group(3),
                                 arg=mm.group(5), path=None, line=i))
            elif mm.group(6):                    # is_in_group / get_nodes_in_group / get_first_node_in_group
                refs.append(dict(kind="group", name=mm.group(7), receiver=mm.group(6),
                                 arg="query", path=None, line=i))
        for mm in R["singleton"].finditer(s):
            refs.append(dict(kind="singleton", name=mm.group(1), receiver=None, arg="get_singleton", path=None, line=i))
        for mm in R["singleton_attr"].finditer(s):
            refs.append(dict(kind="singleton", name=mm.group(1), receiver=mm.group(2), arg=None, path=None, line=i))
        for mm in R["get_node"].finditer(s):
            p = mm.group(1) or mm.group(2) or mm.group(3) or mm.group(4)
            if p and len(p) >= 2:
                refs.append(dict(kind="node_path", name=p, receiver=None, arg=None, path=p, line=i))
        for mm in R["call"].finditer(s):
            recv, nm = mm.group(1), mm.group(2)
            if not nm or len(nm) < 2 or nm in BUILTIN_CALLS or nm in KEYWORDS or nm.isupper():
                continue
            if recv == "self":
                recv = None
            refs.append(dict(kind="calls", name=nm, receiver=recv, arg=None, path=None, line=i))
        for mm in R["typeref"].finditer(s):
            nm = mm.group(1)
            if nm and nm not in GD_TYPES and nm == nm.upper()[:1] + nm[1:]:
                refs.append(dict(kind="references", name=nm, receiver=None, arg="type", path=None, line=i))
    for r in refs:
        r["owner"] = owner_at.get(r["line"])
    return decls, refs


NODE_RE = re.compile(r'^\[node[ \t]+(.*)\]$')
ATTR_RE = re.compile(r'(\w+)[ \t]*=[ \t]*"([^"]*)"')
ATTR_RAW_RE = re.compile(r'(\w+)[ \t]*=[ \t]*(ExtResource[ \t]*\([^)]*\)|[A-Za-z_][\w.]*)')
EXT_RE = re.compile(r'^\[ext_resource[ \t]+(.*)\]$')
CONN_RE = re.compile(r'^\[connection[ \t]+(.*)\]$')
EXTID_RE = re.compile(r'ExtResource[ \t]*\([ \t]*"?([\w]+)"?[ \t]*\)')


def parse_tscn(text: str) -> tuple[list[dict], list[dict]]:
    decls, refs = [], []
    ext: dict[str, dict] = {}
    in_node: str | None = None
    root_seen = False
    for i, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        m = EXT_RE.match(line)
        if m:
            at = dict(ATTR_RE.findall(m.group(1)))
            eid = at.get("id")
            if eid and at.get("path"):
                ext[eid] = at
                refs.append(dict(kind="preloads" if at.get("type") != "PackedScene" else "instantiates",
                                 name=None, receiver=at.get("type"), arg=None, path=at["path"], line=i))
            continue
        m = CONN_RE.match(line)
        if m:
            at = dict(ATTR_RE.findall(m.group(1)))
            refs.append(dict(kind="tscn_conn", name=at.get("signal"), receiver=at.get("from"),
                             arg=at.get("method"), path=at.get("to"), line=i))
            continue
        m = NODE_RE.match(line)
        if m:
            body = m.group(1)
            at = dict(ATTR_RE.findall(body))
            for k, v in ATTR_RAW_RE.findall(body):
                at.setdefault(k, v)
            name = at.get("name", "?")
            parent = at.get("parent")
            path = name if parent in (None, ".") else parent + "/" + name
            inst = at.get("instance", "")
            if parent in (None, ".") and not root_seen:
                root_seen = True
                refs.append(dict(kind="scene_root", name=path, receiver=at.get("type"),
                                 arg=None, path=None, line=i))
            decls.append(dict(kind="scene_node", name=path, line=i,
                              sig=(at.get("type", "instanced") + (f" inst={inst}" if inst else ""))[:200],
                              cls=None, meta=inst or None))
            in_node = path
            m2 = EXTID_RE.search(inst)
            if m2 and m2.group(1) in ext and ext[m2.group(1)].get("path"):
                refs.append(dict(kind="instantiates", name=path, receiver=at.get("type"), arg=None,
                                 path=ext[m2.group(1)]["path"], line=i))
            continue
        if line.startswith("["):
            in_node = None
            continue
        if in_node is not None and line.startswith("script"):
            m2 = EXTID_RE.search(line)
            if m2 and m2.group(1) in ext and ext[m2.group(1)].get("path", "").endswith(".gd"):
                refs.append(dict(kind="has_script", name=in_node, receiver=None, arg=None,
                                 path=ext[m2.group(1)]["path"], line=i))
    return decls, refs


def parse_tres(text: str) -> tuple[list[dict], list[dict]]:
    decls, refs = [], []
    ext: dict[str, str] = {}
    for i, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        m = EXT_RE.match(line)
        if m:
            at = dict(ATTR_RE.findall(m.group(1)))
            if at.get("id") and at.get("path"):
                ext[at["id"]] = at.get("path", "")
                refs.append(dict(kind="preloads", name=None, receiver=at.get("type"), arg=None,
                                 path=at["path"], line=i))
            continue
        if line.startswith("script"):
            m2 = EXTID_RE.search(line)
            if m2 and m2.group(1) in ext and ext[m2.group(1)].endswith(".gd"):
                refs.append(dict(kind="has_script", name=None, receiver=None, arg=None,
                                 path=ext[m2.group(1)], line=i))
    return decls, refs


def parse_project_godot(text: str) -> tuple[list[dict], list[dict]]:
    decls, refs = [], []
    in_auto = False
    for i, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if line.startswith("["):
            in_auto = line == "[autoload]"
            continue
        if not in_auto or not line or line.startswith(";"):
            continue
        m = re.match(r'([A-Za-z_]\w*)[ \t]*=[ \t]*"(\*?)(res://[^"]+)"', line)
        if m:
            # sjølve autoload-noden blir laga i resolve() (nøkel = autoload:<navn>)
            refs.append(dict(kind="autoload_of", name=m.group(1), receiver=None, arg=m.group(2),
                             path=m.group(3), line=i))
    return decls, refs


def parse_shader(text: str) -> tuple[list[dict], list[dict]]:
    decls, refs = [], []
    for i, raw in enumerate(text.splitlines(), 1):
        s = strip_comment(raw).strip()
        m = re.match(r'shading_type[ \t]+(\w+)', s)
        if m:
            decls.append(dict(kind="const", name=m.group(1), line=i, sig=s[:120], cls=None))
        m = re.match(r'uniform[ \t]+\w+[ \t]+(\w+)', s)
        if m:
            decls.append(dict(kind="var", name=m.group(1), line=i, sig="uniform " + s[:120], cls=None,
                              meta="uniform"))
        m = re.match(r'void[ \t]+(\w+)', s)
        if m:
            decls.append(dict(kind="fn", name=m.group(1), line=i, sig=s[:120], cls=None))
        for mm in re.finditer(r'(?:vertex|fragment|light)_[a-z_]+', s):
            pass
    return decls, refs


PARSERS = {".gd": parse_gd, ".tscn": parse_tscn, ".tres": parse_tres, ".gdshader": parse_shader}


# --------------------------------------------------------------------------
# Indexering
# --------------------------------------------------------------------------
def file_kind(rel: str) -> str:
    ext = os.path.splitext(rel)[1]
    return {".gd": "gd", ".tscn": "scene", ".tres": "resource", ".gdshader": "shader"}.get(ext, "file")


def index(root: Path, force: bool = False, want_web: bool = False, want_addons: bool = False) -> dict:
    t0 = time.time()
    con = open_db(root)
    init_db(con)
    rels = list_files(root, want_web, want_addons)
    stored = {p: (sha, mtime, size) for p, sha, mtime, size in
              con.execute("SELECT path, sha, mtime, bytes FROM files")}
    changed, added = [], []
    for rel in rels:
        fp = root / rel
        try:
            st = fp.stat()
        except OSError:
            continue
        prev = stored.get(rel)
        # snarveg: er tidsstempel og storleik uendra, trur vi at fila er uendra.
        # --force hoppa over snarvegen og hashar alle filane på nytt.
        if (not force) and prev is not None and prev[1] == st.st_mtime and prev[2] == st.st_size:
            continue
        digest = hashlib.sha256(fp.read_bytes()).hexdigest()
        if prev is None:
            added.append(rel)
        elif prev[0] != digest:
            changed.append(rel)
    gone = sorted(set(stored) - set(rels))
    if not force and not changed and not added and not gone:
        n = con.execute("SELECT count(*) FROM nodes").fetchone()[0]
        e = con.execute("SELECT count(*) FROM edges").fetchone()[0]
        con.execute("INSERT INTO meta(k,v) VALUES('checked_at',?) ON CONFLICT(k) DO UPDATE SET v=excluded.v",
                    (time.strftime("%Y-%m-%d %H:%M:%S"),))
        con.commit()
        con.close()
        return dict(unchanged=True, nodes=n, edges=e, seconds=round(time.time() - t0, 2))

    for rel in gone + changed:
        con.execute("DELETE FROM refs WHERE file=?", (rel,))
        con.execute("DELETE FROM unresolved WHERE file=?", (rel,))
        ids = [r[0] for r in con.execute("SELECT id FROM nodes WHERE file=?", (rel,))]
        if ids:
            q = ",".join("?" * len(ids))
            con.execute(f"DELETE FROM edges WHERE src IN ({q}) OR dst IN ({q})", ids + ids)
            con.execute(f"DELETE FROM nodes WHERE file=?", (rel,))
    for rel in gone:
        con.execute("DELETE FROM files WHERE path=?", (rel,))

    prog_file = root / DB_DIR / "progress.json"
    def write_prog(phase: str, current: int, total: int, msg: str = "", pct: int = 0):
        try:
            prog_file.parent.mkdir(parents=True, exist_ok=True)
            prog_file.write_text(json.dumps({
                "phase": phase, "current": current, "total": total,
                "msg": msg, "pct": pct
            }), encoding="utf-8")
        except Exception:
            pass

    to_process = added + changed
    total_files = len(to_process)
    write_prog("start", 0, total_files, "Starter indeksering...", 0)

    parse_errors = 0
    for idx, rel in enumerate(to_process, 1):
        if idx % 5 == 0 or idx == total_files:
            pct = int((idx / max(1, total_files)) * 80)
            write_prog("parsing", idx, total_files, rel, pct)
        fp = root / rel
        try:
            text = fp.read_text(encoding="utf-8-sig", errors="replace")
        except Exception as e:
            parse_errors += 1
            log(f"lesefeil {rel}: {e}")
            continue
        ext = os.path.splitext(rel)[1]
        if rel == "project.godot":
            decls, refs = parse_project_godot(text)
        else:
            fn = PARSERS.get(ext)
            if not fn:
                continue
            try:
                decls, refs = fn(text)
            except Exception as e:
                parse_errors += 1
                log(f"parsefeil {rel}: {e}")
                continue
        st = fp.stat()
        con.execute("INSERT OR REPLACE INTO files(path,kind,sha,lines,bytes,mtime,addons) VALUES(?,?,?,?,?,?,?)",
                    (rel, file_kind(rel), hashlib.sha256(fp.read_bytes()).hexdigest(),
                     text.count("\n") + 1, st.st_size, st.st_mtime, 1 if rel.startswith("addons/") else 0))
        fcur = con.execute("INSERT OR IGNORE INTO nodes(key,kind,name,file,line) VALUES(?,?,?,?,?)",
                           ("file:" + rel, "file", os.path.basename(rel), rel, 1))
        fid = fcur.lastrowid or con.execute("SELECT id FROM nodes WHERE key=?", ("file:" + rel,)).fetchone()[0]
        for d in decls:
            key = f"{d['kind']}:{rel}#{d['name']}@{d['line']}"
            cur = con.execute("INSERT OR IGNORE INTO nodes(key,kind,name,file,line,sig,meta) VALUES(?,?,?,?,?,?,?)",
                              (key, d["kind"], d["name"], rel, d["line"], d.get("sig"), d.get("meta")))
            nid = cur.lastrowid
            if cur.rowcount and nid:
                con.execute("INSERT OR IGNORE INTO edges(src,dst,kind,line,note) VALUES(?,?,?,?,?)",
                            (fid, nid, "contains", d["line"], ""))
        for r in refs:
            con.execute("INSERT INTO refs(file,kind,name,receiver,arg,path,line,owner) VALUES(?,?,?,?,?,?,?,?)",
                        (rel, r["kind"], r.get("name"), r.get("receiver"), r.get("arg"), r.get("path"),
                         r["line"], r.get("owner")))

    write_prog("resolving", total_files, total_files, "Løser kryssreferanser, signaler og @rpc...", 85)
    resolve(con)
    write_prog("search", total_files, total_files, "Bygger søkeindeks...", 95)
    rebuild_search(con)
    write_prog("done", total_files, total_files, "Ferdig!", 100)
    try:
        prog_file.unlink(missing_ok=True)
    except Exception:
        pass
    now = time.strftime("%Y-%m-%d %H:%M:%S")
    con.execute("INSERT INTO meta(k,v) VALUES('indexed_at',?) ON CONFLICT(k) DO UPDATE SET v=excluded.v", (now,))
    con.execute("INSERT INTO meta(k,v) VALUES('checked_at',?) ON CONFLICT(k) DO UPDATE SET v=excluded.v", (now,))
    con.execute("INSERT INTO meta(k,v) VALUES('scope',?) ON CONFLICT(k) DO UPDATE SET v=excluded.v",
                (scope_str(want_web, want_addons),))
    con.commit()
    try:
        sym_rows = con.execute("""
            SELECT DISTINCT name, kind FROM nodes 
            WHERE kind IN ('class','fn','signal','autoload','group')
            ORDER BY length(name) ASC, name ASC
            LIMIT 5000
        """).fetchall()
        sym_file = root / DB_DIR / "symbols.json"
        sym_file.write_text(json.dumps([{"n": r[0], "k": r[1]} for r in sym_rows], ensure_ascii=False), encoding="utf-8")
    except Exception:
        pass
    out = dict(
        nodes=con.execute("SELECT count(*) FROM nodes").fetchone()[0],
        edges=con.execute("SELECT count(*) FROM edges").fetchone()[0],
        files=len(rels), changed=len(changed), added=len(added), removed=len(gone),
        parse_errors=parse_errors, seconds=round(time.time() - t0, 2),
    )
    con.close()
    return out


def node_id(con, key: str, create: bool = False, kind: str = "builtin", name: str | None = None) -> int | None:
    row = con.execute("SELECT id FROM nodes WHERE key=?", (key,)).fetchone()
    if row:
        return row[0]
    if create:
        cur = con.execute("INSERT OR IGNORE INTO nodes(key,kind,name) VALUES(?,?,?)",
                          (key, kind, name or key.split("#")[-1]))
        return cur.lastrowid
    return None


def resolve(con: sqlite3.Connection) -> None:
    """Bygg kryssfiler-kanter fra refs-tabellen. billig og fullstendig hver runde."""
    q = ",".join("?" * len(CROSS_KINDS))
    con.execute(f"DELETE FROM edges WHERE kind IN ({q})", CROSS_KINDS)
    con.execute("DELETE FROM unresolved")

    fileid = {p: node_id(con, "file:" + p, True, "file", os.path.basename(p))
              for (p,) in con.execute("SELECT path FROM files")}
    for f, fid in fileid.items():
        # kind heldst i files-tabellen; noden beheld typen 'file' (slik filtre og md-slutt fungerer)
        con.execute("UPDATE nodes SET name=?, file=? WHERE id=?", (os.path.basename(f), f, fid))

    classes: dict[str, list[int]] = {}
    fns: dict[str, list[tuple[int, str]]] = {}
    sigs: dict[str, list[int]] = {}
    fn_by_file: dict[tuple[str, str], int] = {}
    for nid, kind, name, file in con.execute("SELECT id,kind,name,file FROM nodes WHERE kind IN ('class','fn','signal')"):
        if kind == "class":
            classes.setdefault(name, []).append(nid)
        elif kind == "fn":
            fns.setdefault(name, []).append((nid, file or ""))
            fn_by_file[(file or "", name)] = nid
        elif kind == "signal":
            sigs.setdefault(name, []).append(nid)
    autoloads = {n: f for n, f in con.execute(
        "SELECT n.name, m.path FROM nodes n JOIN refs m ON m.name=n.name WHERE n.kind='autoload' AND m.kind='autoload_of'")}
    # scene-noder per scene-sti, for å løse get_node-stier
    nodes_by_path: dict[str, int] = {}
    for nid, name, file in con.execute("SELECT id,name,file FROM nodes WHERE kind='scene_node'"):
        nodes_by_path[name] = nid
    # scene → rot-node, node → script, node → instansiert scene.
    # Brukt til å slå opp KVEN som tek imot ei .tscn-kopling (to="-attributtet).
    root_of: dict[str, str] = {}
    node_script: dict[tuple[str, str], str] = {}
    node_inst: dict[tuple[str, str], str] = {}
    for f, name in con.execute("SELECT file,name FROM refs WHERE kind='scene_root' AND name IS NOT NULL"):
        root_of.setdefault(f, name)
    for f, name, path in con.execute("SELECT file,name,path FROM refs WHERE kind='has_script' AND name IS NOT NULL"):
        tgt = (path or "").replace("res://", "").lstrip("/")
        if name and tgt:
            node_script[(f, name)] = tgt
    for f, name, path in con.execute("SELECT file,name,path FROM refs WHERE kind='instantiates' AND name IS NOT NULL"):
        tgt = (path or "").replace("res://", "").lstrip("/")
        if name and tgt:
            node_inst[(f, name)] = tgt
    # fil → basisklasse (frå refs, ikkje edges — edges blir bygde i denne passet)
    ext_ref: dict[str, str] = {}
    for f, name in con.execute("SELECT file,name FROM refs WHERE kind='extends' AND name IS NOT NULL"):
        ext_ref[f] = name
    class_file: dict[str, str] = {}
    for name, f in con.execute("SELECT name,file FROM nodes WHERE kind='class' AND file IS NOT NULL"):
        class_file.setdefault(name, f)
    # filclass: fil → class_name (brukes til å slå opp mottakertype)
    file_class: dict[str, str] = {}
    for name, file in con.execute("SELECT name,file FROM nodes WHERE kind='class' AND file IS NOT NULL"):
        file_class.setdefault(file, name)
    # typa felt og preload-felt per fil, for å løse `fienden.take_damage()`
    var_type: dict[str, dict[str, str]] = {}
    var_file: dict[str, dict[str, str]] = {}

    def add_edge(src, dst, kind, line, note=None, weight=1):
        if src is None or dst is None or src == dst:
            return
        con.execute("INSERT OR IGNORE INTO edges(src,dst,kind,line,note,weight) VALUES(?,?,?,?,?,?)",
                    (src, dst, kind, line, note or "", weight))

    def unp(file, kind, name, receiver, line, reason):
        con.execute("INSERT INTO unresolved(file,kind,name,receiver,line,reason) VALUES(?,?,?,?,?,?)",
                    (file, kind, name, receiver, line, reason))

    def same_dir(a: str, b: str) -> bool:
        return a.rsplit("/", 1)[0] == b.rsplit("/", 1)[0]

    def pick(dct, name, file):
        """Plukk kandidat: same-file > same mappe > global unik. Returner (id, merkelapp)."""
        cands = dct.get(name)
        if not cands:
            return None, None
        ids = [(c[0], c[1]) if isinstance(c, tuple) else (c, None) for c in cands]
        if len(ids) == 1:
            return ids[0][0], None
        here = [c for c in ids if c[1] == file]
        if len(here) == 1:
            return here[0][0], "same-file"
        near = [c for c in ids if c[1] and file and same_dir(c[1], file)]
        if near:
            return near[0][0], f"same-mappe,{len(ids)} kandidatar"
        return ids[0][0], f"ambiguous:{len(ids)}"

    def node_script_of(scene: str, node: str | None, depth: int = 6) -> str | None:
        """Kva script filen 'scene' sin node 'node' faktisk køyrer.
        '.' = rota. Følgjer instansieringskjeda (instance=ExtResource) oppover."""
        cur_scene = scene
        cur_node = root_of.get(scene) if node in (".", "", None) else node
        seen: set[tuple[str, str]] = set()
        for _ in range(depth):
            if not cur_node or (cur_scene, cur_node) in seen:
                return None
            seen.add((cur_scene, cur_node))
            s = node_script.get((cur_scene, cur_node))
            if s:
                return s
            nxt = node_inst.get((cur_scene, cur_node))
            if not nxt:
                return None
            cur_scene, cur_node = nxt, root_of.get(nxt)
        return None

    def find_method(script_file: str, method: str, depth: int = 8):
        """Finn fn-node for 'method' i scriptet, og følgjer extends-kjeda oppover.
        Returner (id, merkelapp) — merkelappa seier kven som faktisk definerer."""
        cur, chain = script_file, []
        for _ in range(depth):
            nid = fn_by_file.get((cur, method))
            if nid:
                return nid, ("eige script" if not chain else f"arva i {cur}")
            base = ext_ref.get(cur)
            nxt = class_file.get(base) if base else None
            if not nxt or nxt in chain:
                return None, None
            chain.append(cur)
            cur = nxt
        return None, None

    def resolve_target(name: str, receiver: str | None, file: str, path: str | None):
        """receiver → (fil, merkelapp) dersom typen kan anslåast."""
        if not receiver:
            return file, None
        if receiver in autoloads:
            return autoloads[receiver].replace("res://", "").lstrip("/"), f"{receiver} (autoload)"
        t = var_type.get(file, {}).get(receiver)
        if t and t in file_class:
            return file_class[t] and next((f for f, c in file_class.items() if c == t), file), f"{receiver}: {t}"
        if receiver in file_class.values():
            return next((f for f, c in file_class.items() if c == receiver), file), f"{receiver} (klasse)"
        t2 = var_file.get(file, {}).get(receiver)
        if t2:
            return t2.replace("res://", "").lstrip("/"), f"{receiver} = preload"
        return file, None

    NOISE_PREFIX = ("set_", "get_", "is_", "has_", "can_", "to_", "with_", "queue_", "as_", "reset_", "clear_")

    for f, kind, name, receiver, arg, path, line, owner in con.execute(
            "SELECT file,kind,name,receiver,arg,path,line,owner FROM refs"):
        fid = fileid.get(f)
        # utgangspunkt: kant frå den faktiske funksjonen der referansen står
        src = fn_by_file.get((f, owner)) if owner else None
        src_kind_ok = src is not None
        if src is None:
            src = fid
        if kind == "preloads":
            tgt = fileid.get((path or "").replace("res://", "").lstrip("/")) if path else None
            if tgt:
                add_edge(src, tgt, "preloads", line, arg or "load")
                if arg == "extends":
                    add_edge(fid, tgt, "extends", line, "script-path")
        elif kind == "instantiates":
            tgt = fileid.get((path or "").replace("res://", "").lstrip("/"))
            if tgt:
                add_edge(fid, tgt, "instantiates", line)
            if name and name in nodes_by_path:
                add_edge(fid, nodes_by_path[name], "has_node", line)
        elif kind == "has_script":
            tgt = fileid.get((path or "").replace("res://", "").lstrip("/"))
            if tgt and fid:
                con.execute("INSERT OR IGNORE INTO edges(src,dst,kind,line,note) VALUES(?,?,?,?,?)",
                            (fid, tgt, "has_script", line, name))
        elif kind == "autoload_of":
            aid = node_id(con, f"autoload:{name}", True, "autoload", name)
            con.execute("UPDATE nodes SET file=?, line=?, sig=? WHERE id=?", (f, line, path, aid))
            tgt = fileid.get((path or "").replace("res://", "").lstrip("/"))
            add_edge(aid, tgt, "uses_autoload", line, "defines")
        elif kind == "extends":
            if name in classes:
                add_edge(fid, classes[name][0], "extends", line)
            else:
                bid = node_id(con, "builtin:" + name, True, "builtin", name)
                add_edge(fid, bid, "extends", line, "engine-base")
        elif kind == "emits":
            sid, note = pick(sigs, name, f)
            if sid:
                add_edge(src, sid, "emits", line, note)
            else:
                unp(f, "emits", name, receiver, line, "signal-not-found")
        elif kind == "connects":
            sid, note = pick(sigs, name, f)
            if sid is None:
                # motor-/node-signal (.connect("pressed", ...) i kode) — same behandling
                # som for .tscn-koplingar, elles forsvinn handlaren
                sid = node_id(con, "signal:" + (name or "?"), True, "signal", name or "?")
                note = "engine-signal"
            add_edge(src, sid, "references", line, "connect-target")
            if arg:
                hid, hnote = pick(fns, arg, f)
                if hid:
                    add_edge(sid, hid, "connects_to", line, (receiver or "") + (" " + hnote if hnote else ""))
                else:
                    unp(f, "connects_to", arg, name, line, "handler-not-found")
        elif kind == "tscn_conn":
            sid, note = pick(sigs, name, f)
            if sid is None:
                # nær sagt alle .tscn-koplingar brukar motor-/node-signal
                # (pressed, body_entered, value_changed …) som ingen skript erklærer.
                # Desse får ein eigen global signal-node, elles forsvinn heile koplinga.
                sid = node_id(con, "signal:" + (name or "?"), True, "signal", name or "?")
                note = "engine-signal"
            add_edge(fid, sid, "references", line, f"from={receiver}")
            to = path or "."
            hid, hnote = None, None
            script = node_script_of(f, to)
            if script:
                hid, hnote = find_method(script, arg or "")
                if hid is None:
                    unp(f, "connects_to", arg, name, line,
                        f"method-not-in-{script}-eller-basisklasse")
                    continue
                add_edge(sid, hid, "connects_to", line,
                         f"tscn from={receiver} to={to} ({hnote})")
            else:
                hid, hnote = pick(fns, arg or "", f)
                if hid:
                    add_edge(sid, hid, "connects_to", line,
                             f"tscn from={receiver} to={to} namngiss:" + (hnote or "unik"))
                else:
                    unp(f, "connects_to", arg, name, line, "tscn-node-utan-script")
        elif kind == "vartype":
            var_type.setdefault(f, {})[receiver] = name
            if name in classes:
                add_edge(fid, classes[name][0], "references", line, "felt-type")
        elif kind == "varfile":
            var_file.setdefault(f, {})[receiver] = (path or "").replace("res://", "").lstrip("/")
        elif kind == "references":
            if name in classes:
                add_edge(src, classes[name][0], "references", line, arg)
            elif name in fns:
                add_edge(src, fns[name][0][0], "references", line, arg)
            else:
                unp(f, "references", name, receiver, line, "type-not-project-class")
        elif kind == "calls":
            tfile, tnote = resolve_target(name, receiver, f, path)
            cands = [nid for nid, fl in fns.get(name, []) if fl == tfile]
            if cands:
                add_edge(src, cands[0], "calls", line, tnote)
                if tnote and "(autoload)" in tnote:
                    add_edge(src, node_id(con, f"autoload:{receiver}", True, "autoload", receiver),
                             "uses_autoload", line)
                continue
            cid, note = pick(fns, name, f)
            if cid:
                add_edge(src, cid, "calls", line, note)
            elif name.startswith(NOISE_PREFIX) or name in GODOT_SINGLETONS:
                pass  # arva motor-/Node-metode: verken kant eller støy
            elif name[:1].isupper():
                unp(f, "calls", name, receiver, line, "konstruktør/motortype")
            else:
                unp(f, "calls", name, receiver, line, "ikkje prosjektfunksjon")
        elif kind == "group":
            gid = node_id(con, "group:" + name, True, "group", name)
            if receiver and receiver.startswith("call_"):
                hid, hnote = pick(fns, arg or "", f)
                if hid:
                    add_edge(src, hid, "calls_group", line, f"group={name}")
                else:
                    add_edge(src, gid, "calls_group", line, f"method={arg}")
            elif arg == "query":
                add_edge(src, gid, "queries_group", line, receiver)
            else:
                add_edge(src, gid, "in_group", line, receiver)
        elif kind == "singleton":
            add_edge(src, node_id(con, "builtin:" + name, True, "builtin", name), "references", line, "engine-singleton")
        elif kind == "node_path":
            hit = None
            for p, nid in nodes_by_path.items():
                if p == name or p.endswith("/" + (name or "")):
                    hit = nid
                    break
            if hit:
                add_edge(src, hit, "references_node", line, name)
            else:
                unp(f, "node_path", name, None, line, "dynamic-path")


def rebuild_search(con: sqlite3.Connection) -> None:
    try:
        con.execute("DELETE FROM search_fts")
        rows = con.execute(
            "SELECT rowid, name||' '||COALESCE(file,'')||' '||COALESCE(sig,'') FROM nodes WHERE kind IN ('class','fn','signal','var','const','autoload','scene_node','enum')")
        con.executemany("INSERT INTO search_fts(rowid,text) VALUES(?,?)", rows)
    except Exception:
        pass


def ensure_fresh(con: sqlite3.Connection, root: Path, quiet: bool = True,
                 want_web: bool = False, want_addons: bool = False) -> None:
    need = scope_str(want_web, want_addons)
    have = con.execute("SELECT v FROM meta WHERE k='scope'").fetchone()
    if not db_ready(con) or (have is not None and have[0] != need):
        if not quiet and have is not None:
            log(f"(endrar filutval: {have[0]} → {need}, bygger på nytt …)")
        index(root, force=True, want_web=want_web, want_addons=want_addons)
        return
    want = {p: hashlib.sha256((root / p).read_bytes()).hexdigest()
            for p in list_files(root, want_web, want_addons) if (root / p).exists()}
    have_f = {p: s for p, s in con.execute("SELECT path, sha FROM files")}
    if set(want) != set(have_f) or any(want[p] != have_f[p] for p in set(want) & set(have_f)):
        if not quiet:
            log("(indeksen er utdatert, bygger på nytt …)")
        index(root, want_web=want_web, want_addons=want_addons)


def db(ctx):
    con = open_db(ctx["root"])
    ensure_fresh(con, ctx["root"], want_web=ctx.get("web", False), want_addons=ctx.get("addons", False))
    return con


# --------------------------------------------------------------------------
# Spørringer
# --------------------------------------------------------------------------
def node_row(con, name: str) -> list[sqlite3.Row]:
    con.row_factory = sqlite3.Row
    return list(con.execute(
        "SELECT id,kind,name,file,line,sig,meta FROM nodes WHERE name=? AND kind NOT IN ('node_path') "
        "ORDER BY CASE kind WHEN 'class' THEN 0 WHEN 'signal' THEN 1 WHEN 'fn' THEN 2 ELSE 3 END", (name,)))


def show(n) -> str:
    tag = {"class": "class", "fn": "fn", "signal": "signal", "var": "var", "const": "const",
           "autoload": "autoload", "group": "group", "builtin": "engine", "enum": "enum"}.get(n["kind"], n["kind"])
    loc = f'{n["file"]}:{n["line"]}' if n["file"] else "-"
    extra = f'  {n["sig"]}' if n["sig"] else ""
    meta = f'  [{n["meta"]}]' if n["meta"] else ""
    return f'{tag:7} {n["name"]:34} {loc:48}{extra}{meta}'


def cmd_find(con, name: str, limit: int = 60) -> int:
    con.row_factory = sqlite3.Row
    rows = list(con.execute(
        "SELECT id,kind,name,file,line,sig,meta FROM nodes WHERE name LIKE ? "
        "AND kind IN ('class','fn','signal','var','const','autoload','group','enum') ORDER BY kind,name LIMIT ?",
        (f"%{name}%", limit)))
    if not rows:
        print(f"ingen treff på {name!r}")
        return 1
    for r in rows:
        print(show(r))
    print(f"\n{len(rows)} treff" + (" (flere — bruk mer spesifikt navn)" if len(rows) == limit else ""))
    return 0


def cmd_outline(con, target: str) -> int:
    con.row_factory = sqlite3.Row
    rows = list(con.execute(
        "SELECT id,kind,name,file,line,sig,meta FROM nodes WHERE kind='class' AND name=? ", (target,)))
    if not rows:
        rel = target.replace("\\", "/").lstrip("./")
        f = con.execute("SELECT path FROM files WHERE path=?", (rel,)).fetchone() \
            or con.execute("SELECT path FROM files WHERE path LIKE ?", (f"%{rel}%",)).fetchone() \
            or con.execute("SELECT file FROM nodes WHERE kind='autoload' AND name=?", (target,)).fetchone()
        if not f:
            print(f"fant ikke klassen eller filen {target!r}")
            return 1
        rows = [dict(id=None, kind="file", name=os.path.basename(f[0]), file=f[0], line=1,
                     sig=f"fil {f[0]}", meta=None)]
    for r in rows:
        print(show(r))
        file = r["file"]
        items = list(con.execute(
            "SELECT kind,name,line,sig,meta FROM nodes WHERE file=? AND kind IN "
            "('signal','fn','var','const','enum','autoload') ORDER BY CASE kind WHEN 'signal' THEN 0 "
            "WHEN 'var' THEN 1 ELSE 2 END, line", (file,)))
        sig = [i for i in items if i["kind"] == "signal"]
        var = [i for i in items if i["kind"] in ("var", "const", "enum")]
        fn = [i for i in items if i["kind"] in ("fn", "autoload")]
        if sig:
            print("  signaler:")
            for i in sig:
                print(f"    L{i['line']:<5} {i['name']} {i['sig'] or ''}")
        if var:
            print(f"  felt/konstanter: {', '.join(i['name'] for i in var[:40])}" + (" …" if len(var) > 40 else ""))
        print(f"  funksjoner ({len(fn)}):")
        for i in fn:
            print(f"    L{i['line']:<5} {i['name']}{(i['sig'] or '()').split(i['name'],1)[-1] if i['sig'] else '()'}"
                  + ("  [rpc]" if i["meta"] == "rpc" else ""))
    return 0


def top_files(rows: list, k: int = 8) -> str:
    """`fil:antall` for dei tyngste filane — brukast i summert utskrift."""
    c: dict[str, int] = {}
    for r in rows:
        c[(r["file"] or "-")] = c.get((r["file"] or "-"), 0) + 1
    return ", ".join(f"{f.rsplit('/', 1)[-1]}:{n}" for f, n in sorted(c.items(), key=lambda kv: -kv[1])[:k])


def hint(more: int, cmd: str, limit: int) -> None:
    if more > 0:
        print(f"    … {more} fleire  (vis alle: --limit {more + limit})")


def L(a) -> int:
    """Grense på utskrift frå argumentpara: --all slapar fri."""
    return 10 ** 9 if getattr(a, "all", False) else a.limit


def cmd_signal(con, name: str, limit: int = 25) -> int:
    rows = node_row(con, name)
    sig = [r for r in rows if r["kind"] == "signal"]
    if not sig:
        print(f"ingen signal erklært med navn {name!r}. Prøv: kg find {name}")
        for r in rows[:limit]:
            print(show(r))
        if len(rows) > limit:
            hint(len(rows) - limit, f"find {name}", limit)
        return 1
    con.row_factory = sqlite3.Row
    for s in sig:
        stad = f"erklært {s['file']}:{s['line']}" if s["file"] else "MOTORSIGNAL (ikkje erklært i prosjektmanus)"
        print(f"signal {s['name']}{s['sig'] or ''}  —  {stad}")
        sid = s["id"]
        em = list(con.execute(
            "SELECT f.kind AS sk,f.name AS src,f.file,e.line AS ln FROM edges e JOIN nodes f ON f.id=e.src "
            "WHERE e.dst=? AND e.kind='emits' ORDER BY f.file,e.line", (sid,)))
        print(f"\n  emitterer: {len(em)} i {len({r['file'] for r in em})} filer  [{top_files(em)}]")
        for r in em[:limit]:
            who = f"{r['src']}()" if r["sk"] == "fn" else "(toppnivå)"
            print(f"    {r['file']}:{r['ln']}  i {who}")
        hint(len(em) - limit, "signal", limit)
        rec = list(con.execute(
            "SELECT n.name,n.file,n.line,e.note FROM edges e JOIN nodes n ON n.id=e.dst "
            "WHERE e.src=? AND e.kind='connects_to' ORDER BY n.file", (sid,)))
        print(f"\n  mottakarar: {len(rec)} i {len({r['file'] for r in rec})} filer  [{top_files(rec)}]")
        for r in rec[:limit]:
            print(f"    {r['name']:34} {r['file']}:{r['line']}   ({r['note'] or ''})")
        hint(len(rec) - limit, "signal", limit)
        where = list(con.execute("SELECT f.file,e.line AS ln FROM edges e JOIN nodes f ON f.id=e.src "
                                 "WHERE e.dst=? AND e.kind='references' AND e.note='connect-target' "
                                 "ORDER BY f.file,e.line", (sid,)))
        tscn = list(con.execute("SELECT f.file,e.line AS ln,e.note FROM edges e JOIN nodes f ON f.id=e.src "
                                "WHERE e.dst=? AND e.kind='references' AND e.note LIKE 'from=%' ORDER BY f.line", (sid,)))
        if where:
            print(f"\n  .connect()-kallepunkt utan løst mottaksmål: {len(where)}  [{top_files(where)}]")
            for r in where[:limit]:
                print(f"    {r['file']}:{r['ln']}")
            hint(len(where) - limit, "signal", limit)
        if tscn:
            print(f"\n  .tscn-koblingar: {len(tscn)} i {len({r['file'] for r in tscn})} scener  [{top_files(tscn)}]")
            for r in tscn[:limit]:
                print(f"    {r['file']}:{r['ln']}  {r['note']}")
            hint(len(tscn) - limit, "signal", limit)
    unres = list(con.execute(
        "SELECT file,line,reason FROM unresolved WHERE name=? AND (kind LIKE '%connect%' OR kind='emits')", (name,)))
    if unres:
        print(f"\n  uavklarte: {len(unres)}")
        for r in unres[:limit]:
            print(f"    {r['file']}:{r['line']}  {r['reason']}")
        hint(len(unres) - limit, "signal", limit)
    return 0


def _dir(con, name: str, want: str, limit: int = 25, flat: bool = False) -> int:
    """callers/callees. Summert per fil frå standard (limit = antal filgrupper);
    --all gjev den gamle utskrifta kant for kant."""
    rows = node_row(con, name)
    if not rows:
        print(f"fant ikke {name!r}  —  kg find {name}")
        return 1
    con.row_factory = sqlite3.Row
    q = ("SELECT DISTINCT n.kind,n.name,n.file,n.line,e.line AS at,e.kind AS ek,e.note FROM edges e "
         "JOIN nodes n ON n.id=e.src WHERE e.dst=? ORDER BY ek,n.file,e.line") if want == "callers" else \
        ("SELECT DISTINCT n.kind,n.name,n.file,n.line,e.line AS at,e.kind AS ek,e.note FROM edges e "
         "JOIN nodes n ON n.id=e.dst WHERE e.src=? ORDER BY ek,n.name")
    per: dict[int, list] = {r["id"]: [x for x in con.execute(q, (r["id"],)) if x["ek"] not in ("contains",)]
                            for r in rows}
    rang = sorted(rows, key=lambda r: -len(per[r["id"]]))
    maxc = len(rows) if flat else max(1, min(8, limit // 3))
    tot = sum(len(v) for v in per.values())
    if len(rows) > 1:
        print(f"{want} for {name!r}: {len(rows)} kandidatar i {len({r['file'] for r in rows})} filer, "
              f"{tot} kantar totalt — utvidar dei {min(maxc, len(rows))}aste, resten som éin linje")
    for r in rang[:maxc]:
        alle = per[r["id"]]
        print(f"[{r['kind']}] {r['name']}  {r['file'] or '-'}:{r['line'] or '-'}")
        if not alle:
            print("   0 kantar  (ingen kanter)")
            continue
        telj: dict[str, int] = {}
        for x in alle:
            telj[x["ek"]] = telj.get(x["ek"], 0) + 1
        print(f"   {len(alle)} kantar  [" + ", ".join(f"{k}:{v}" for k, v in
              sorted(telj.items(), key=lambda kv: -kv[1])) + "]")
        if flat:
            for x in alle:
                der = f"{x['file'] or '-'}:{x['line'] or '-'}"
                kall = f"   (kalla {x['at']})" if x["at"] and x["at"] != x["line"] else ""
                print(f"   {x['ek']:12} {x['kind']:7} {x['name']:34} {der}{kall}"
                      + (f"  [{x['note']}]" if x["note"] and x["note"] != "same-file" else ""))
            continue
        # grupper per fil: fil, kantslag, kva funksjonar, og kalla linjer
        gr: dict[str, dict] = {}
        for x in alle:
            f = x["file"] or "-"
            g = gr.setdefault(f, dict(n=0, ek={}, namn=[], linjer=[]))
            g["n"] += 1
            g["ek"][x["ek"]] = g["ek"].get(x["ek"], 0) + 1
            if want == "callers":
                if x["kind"] == "fn" and x["name"] not in g["namn"]:
                    g["namn"].append(x["name"])
                ln = x["at"] or x["line"]
            else:
                if x["name"] not in g["namn"]:
                    g["namn"].append(x["name"])
                ln = x["line"]
            if ln and ln not in g["linjer"]:
                g["linjer"].append(ln)
        print(f"   {len(gr)} filar  (visar topp {min(limit, len(gr))}, gruppert per fil; "
              f"kant for kant: --all)")
        for f, g in sorted(gr.items(), key=lambda kv: (-kv[1]["n"], kv[0]))[:limit]:
            ek = "  [" + ", ".join(f"{k}:{v}" for k, v in sorted(g["ek"].items(), key=lambda kv: -kv[1])) + "]" \
                 if len(g["ek"]) > 1 else ""
            lbl = "kalla frå" if want == "callers" else "kallar"
            namn = ", ".join(g["namn"][:6]) + (f" +{len(g['namn']) - 6}" if len(g["namn"]) > 6 else "")
            ln = ", ".join(f"L{i}" for i in sorted(g["linjer"])[:10]) + \
                 (f" +{len(g['linjer']) - 10}" if len(g["linjer"]) > 10 else "")
            print(f"   {g['n']:4}  {f:52}{ek}")
            print(f"         {lbl}: {namn}" + (f"   linjer: {ln}" if ln else ""))
        if len(gr) > limit:
            print(f"    … {len(gr) - limit} fleire filar  (vis alle: --limit {len(gr)})")
    rest = rang[maxc:]
    med = [r for r in rest if per[r["id"]]]
    if med:
        print(f"\n  {len(med)} kandidatar til med kantar (berre teljing):")
        for r in med[:limit]:
            print(f"   {len(per[r['id']]):4}  {r['file'] or '-'}:{r['line'] or '-'}")
        if len(med) > limit:
            print(f"    … {len(med) - limit} fleire  (vis alle: --limit {len(med)})")
    utan = [r for r in rest if not per[r["id"]]]
    if utan:
        print(f"  {len(utan)} kandidatar utan kantar: "
              + ", ".join(f"{(r['file'] or '-').rsplit('/', 1)[-1]}:{r['line']}" for r in utan[:10])
              + (f" +{len(utan) - 10} til" if len(utan) > 10 else ""))
    return 0


def cmd_impact(con, name: str, depth: int, limit: int = 25) -> int:
    rows = node_row(con, name)
    if not rows:
        print(f"fant ikke {name!r}")
        return 1
    start = {r["id"] for r in rows}
    seen: dict[int, int] = {s: 0 for s in start}
    frontier = set(start)
    d = 0
    while frontier and d < depth:
        q = ",".join("?" * len(frontier))
        nxt = set()
        for nid, eid in con.execute(f"SELECT src,dst FROM edges WHERE dst IN ({q}) AND kind IN "
                                    "('calls','connects_to','emits','extends','references','uses_autoload','instantiates','has_script')",
                                    list(frontier)):
            if nid not in seen:
                seen[nid] = d + 1
                nxt.add(nid)
        frontier = nxt
        d += 1
    con.row_factory = sqlite3.Row
    out = list(con.execute(f"SELECT id,kind,name,file,line FROM nodes WHERE id IN ({','.join(str(i) for i in seen)}) "
                           "ORDER BY file,line"))
    relevante = [r for r in out if r["kind"] not in ("file", "builtin")]
    medFIL = [r for r in relevante if r["file"]]
    hubar = [r for r in relevante if not r["file"]]
    telj = {}
    for r in medFIL:
        telj[r["file"]] = telj.get(r["file"], 0) + 1
    byfile = sorted(telj.items(), key=lambda kv: -kv[1])
    ledd: dict[int, int] = {}
    for r in out:
        ledd[seen[r["id"]]] = ledd.get(seen[r["id"]], 0) + 1
    print(f"påverknad av {name!r}: {len(medFIL)} symbol i {len(byfile)} filer  "
          + "  ".join(f"ledd{k}:{v}" for k, v in sorted(ledd.items())))
    print("\n  berørte filer (tyngste først):")
    for f, n in byfile[:limit]:
        print(f"   {n:4}  {f}")
    if len(byfile) > limit:
        hint(len(byfile) - limit, "impact", limit)
    sym = [r for r in medFIL if r["kind"] in ("class", "fn", "signal", "autoload")]
    print(f"\n  symbol ({len(sym)} totalt, topp {min(limit, len(sym))}):")
    for r in sym[:limit]:
        print(f"   {r['kind']:7} {r['name']:32} {r['file'] or '-'}:{r['line'] or '-'}")
    hint(len(sym) - limit, "impact", limit)
    if hubar:
        print(f"  + {len(hubar)} globale hubbar utan fil (motorsignal/gruppenamn) — tellar ikkje som testbare stader")
    return 0


def cmd_path(con, a: str, b: str) -> int:
    ra, rb = node_row(con, a), node_row(con, b)
    if not ra or not rb:
        print("fant ikke ett av navnene")
        return 1
    src, dst = ra[0]["id"], rb[0]["id"]
    prev = {src: None}
    frontier = [src]
    while frontier:
        q = ",".join("?" * len(frontier))
        nxt = []
        for s, d in con.execute(f"SELECT src,dst FROM edges WHERE src IN ({q})", frontier):
            if d not in prev:
                prev[d] = s
                if d == dst:
                    chain, cur = [], dst
                    while cur is not None:
                        cur2 = prev[cur]
                        row = con.execute("SELECT kind,name,file,line FROM nodes WHERE id=?", (cur,)).fetchone()
                        chain.append(f"{row[1]} ({row[2]}:{row[3]})")
                        cur = cur2
                    print(" → ".join(reversed(chain)))
                    return 0
                nxt.append(d)
        frontier = nxt
    print(f"ingen kantsti {a} → {b}")
    return 1


def cmd_deps(con, target: str, reverse: bool = False, limit: int = 25) -> int:
    rel = target.replace("\\", "/").lstrip("./")
    f = con.execute("SELECT id,file FROM nodes WHERE kind='file' AND file=?", (rel,)).fetchone() \
        or con.execute("SELECT id,file FROM nodes WHERE kind='file' AND file LIKE ?", (f"%{rel}%",)).fetchone()
    if not f:
        print(f"ukjent fil {target!r}")
        return 1
    q = ("SELECT n.kind,n.name,n.file,n.line,e.line AS at,e.kind AS ek,e.note FROM edges e JOIN nodes n ON n.id=e.dst "
         "WHERE e.src=? ORDER BY ek,n.kind,n.name") if not reverse else \
        ("SELECT n.kind,n.name,n.file,n.line,e.line AS at,e.kind AS ek,e.note FROM edges e JOIN nodes n ON n.id=e.src "
         "WHERE e.dst=? ORDER BY ek,n.kind,n.name")
    con.row_factory = sqlite3.Row
    rows = [r for r in con.execute(q, (f[0],)) if r["ek"] != "contains"]
    telj: dict[str, int] = {}
    for r in rows:
        telj[r["ek"]] = telj.get(r["ek"], 0) + 1
    print(f"{f[1]}  {'avhenger av' if not reverse else 'brukes av'}  "
          f"({len(rows)} kantar: " + ", ".join(f"{k}:{v}" for k, v in sorted(telj.items(), key=lambda kv: -kv[1])) + ")")
    for r in rows[:limit]:
        der = f"{r['file']}:{r['line']}" if r["file"] else "(motor)"
        kall = f"   (lenje {r['at']})" if r["at"] else ""
        print(f"   {r['ek']:13} {r['kind']:7} {r['name']:32} {der}{kall}")
    hint(len(rows) - limit, "deps", limit)
    return 0


def cmd_unresolved(con, top: int) -> int:
    rows = list(con.execute("SELECT kind,name,reason,count(*) c FROM unresolved GROUP BY kind,name,reason "
                            "ORDER BY c DESC LIMIT ?", (top,)))
    tot = con.execute("SELECT count(*) FROM unresolved").fetchone()[0]
    print(f"{tot} uavklarte referanser totalt (top {top}):")
    for k, n, r, c in rows:
        print(f"  {c:5}  {k:12} {n:34} {r}")
    return 0


def cmd_rpc(con, pattern: str | None, limit: int = 25) -> int:
    """Alle @rpc-funksjonar, med kor mange stader dei blir kalla frå.
    Multispelar-kontrakt: dette er kryssinga klient ↔ vert."""
    con.row_factory = sqlite3.Row
    where = " AND (n.name LIKE ? OR n.file LIKE ?)" if pattern else ""
    args = (f"%{pattern}%", f"%{pattern}%") if pattern else ()
    rows = con.execute(
        f"SELECT n.name, n.file, n.line, n.sig, COALESCE(x.ncall,0) AS ncall "
        f"FROM nodes n LEFT JOIN (SELECT dst, count(*) AS ncall FROM edges WHERE kind='calls' GROUP BY dst) x ON x.dst=n.id "
        f"WHERE n.kind='fn' AND n.meta='rpc'{where} ORDER BY n.file, n.line", args).fetchall()
    print(f"@rpc-funksjonar: {len(rows)} i {len({r['file'] for r in rows})} filer  [{top_files(rows)}]")
    print(f"  direkte kall totalt: {sum(r['ncall'] for r in rows)}  "
          f"( {sum(1 for r in rows if not r['ncall'])} utan direkte kall = berre RPC-kall over nett )")
    byfile: dict[str, list] = {}
    for r in rows:
        byfile.setdefault(r["file"], []).append(r)
    vist = 0
    for f, rs in sorted(byfile.items(), key=lambda kv: -len(kv[1])):
        print(f"  {f}  ({len(rs)})")
        for r in rs[:max(1, limit // max(1, min(len(byfile), 6)))]:
            mode = ""
            if r["sig"] and "@rpc" in r["sig"]:
                mode = r["sig"].split("@rpc", 1)[1].strip()
            tail = f"   kalla {r['ncall']} stad(er)" if r["ncall"] else "   [ingen direkte kall]"
            print(f"     :{r['line']:<6} {r['name']}  {mode}{tail}")
            vist += 1
        if len(rs) > max(1, limit // max(1, min(len(byfile), 6))):
            print(f"     … {len(rs) - (limit // max(1, min(len(byfile), 6)))} fleire i denne fila")
    if vist < len(rows):
        print(f"  (visar {vist} av {len(rows)} — alle: --limit {len(rows)})")
    return 0


def cmd_status(con, root: Path) -> int:
    n = dict(con.execute("SELECT kind, count(*) FROM nodes GROUP BY kind"))
    e = dict(con.execute("SELECT kind, count(*) FROM edges GROUP BY kind"))
    fl = dict(con.execute("SELECT kind, count(*) FROM files GROUP BY kind"))
    un = con.execute("SELECT count(*) FROM unresolved").fetchone()[0]
    stamps = dict(con.execute("SELECT k,v FROM meta"))
    print(f"index: {root / DB_DIR / DB_NAME}")
    print(f"bygget: {stamps.get('indexed_at','(ikkje en full build enno)')}   "
          f"sist sjekka: {stamps.get('checked_at','-')}   schema v{SCHEMA_VERSION}   "
          f"filutval: {stamps.get('scope', scope_str())}")
    print("filer: " + "  ".join(f"{k}={v}" for k, v in sorted(fl.items())))
    print("noder: " + "  ".join(f"{k}={v}" for k, v in sorted(n.items(), key=lambda kv: -kv[1])))
    print("kanter: " + "  ".join(f"{k}={v}" for k, v in sorted(e.items(), key=lambda kv: -kv[1])))
    print(f"uavklart: {un}")
    agents_f = root / "AGENTS.md"
    if not agents_f.exists() or not _has_block(_read_keep(agents_f)[0]):
        print("tips:   kg agents --install   # gjer AI-agentane i prosjektet kjende med dette verktøyet")
    return 0


AGENTS_BEGIN = "<!-- BEGIN CODEGRAPH (generated by kg agents --install; do not edit inside) -->"
AGENTS_END = "<!-- END CODEGRAPH -->"


def refresh_agent_files_after_update(root: Path, as_json: bool) -> list[str]:
    """`kg update --apply` kallar dette etter at add-onen er bytta. Berre inne i
    dei markerte blokkene, berre på filer som alt har blokk, og den NYE
    graph.py-en tek over - slik får brukaren den nye versjonen sin versjon av
    instruksjonane automatisk, utan å måtte skru av/på noko."""
    targets = [root / rel for rel in ["AGENTS.md"] + list(POINTER_TARGETS.values())]
    touched: list[str] = []
    for p in targets:
        if not p.exists():
            continue
        txt, _eol, _bom = _read_keep(p)
        if AGENTS_BEGIN in txt and AGENTS_END in txt:
            touched.append(str(p.relative_to(root)).replace("\\", "/"))
    if not touched:
        return []
    new_script = TOOL_DIR / "backend" / "graph.py"
    if not new_script.exists():
        return touched
    try:
        r = subprocess.run([sys.executable, str(new_script), "--path", str(root),
                            "agents", "--install"], capture_output=True, text=True, timeout=120)
        note = "oppdatert" if r.returncode == 0 else "kunne ikkje oppdaterast"
    except Exception:                                          # noqa: BLE001
        note = "kunne ikkje oppdaterast"
    if not as_json:
        print(f"  agentfilene ({', '.join(touched)}) blei skrive på nytt av den nye versjonen: {note}")
    return touched


AGENTS_END = "<!-- END CODEGRAPH -->"

# Peikefilar for agentverktøy som ikkje les AGENTS.md av seg sjølv.
POINTER_TARGETS = {
    "claude": "CLAUDE.md",
    "copilot": ".github/copilot-instructions.md",
    "cursor": ".cursor/rules/codegraph.mdc",
}


def agents_targets(tools: str | None) -> list[str]:
    wanted = ["agents"]
    if tools:
        for t in tools.replace(" ", "").lower().split(","):
            if t and t != "agents" and t in POINTER_TARGETS:
                wanted.append(t)
    return wanted


def kg_rel(root: Path) -> str:
    """Verktøyet sin sti relativt til prosjektróta (alltid / )."""
    try:
        return BACKEND_DIR.relative_to(root).as_posix()
    except ValueError:
        return "addons/codegraph/backend"


def _read_keep(p: Path) -> tuple[str, str, str]:
    """Les som (tekst med \\n, linjeskiftstil, BOM). Skilnaden på LF og CRLF må
    followe med att, elles ser ein `git diff` 389 endra linjer i ei uendra fil."""
    data = p.read_bytes()
    bom = "\ufeff" if data.startswith(b"\xef\xbb\xbf") else ""
    eol = "\r\n" if b"\r\n" in data else "\n"
    txt = data.decode("utf-8-sig", errors="replace").replace("\r\n", "\n")
    return txt, eol, bom


def _write_keep(p: Path, txt: str, eol: str = "\n", bom: str = "") -> None:
    """Skriv byte for byte med same linjeskiftstil som opphavet."""
    out = txt.replace("\n", "\r\n") if eol == "\r\n" else txt
    p.write_bytes((bom.encode("utf-8") if bom else b"") + out.encode("utf-8"))


def agents_block(root: Path) -> str:
    """Instruksjonsblokk for agentar. Engelsk, fordi dei fleste repo og agentverktøy
    er engelske. Utan prosjekttal: blokken blir committa og tala sluttar stemme -
    `kg status` gir levande tal i staden."""
    kg = kg_rel(root)
    lines = [
        AGENTS_BEGIN,
        "## ⚡ MANDATORY: CodeGraph — query the graph before ANY grep or file reading",
        "",
        "CRITICAL WORKFLOW RULE FOR AI AGENTS:",
        "Do NOT use `grep_search` across the codebase or read entire `.gd` files into context.",
        f"ALWAYS query `{kg}/kg.bat` (or `./{kg}/kg` on Linux/macOS) first for symbol lookup, class"
        f"outlines, callers, signals, rpc handlers and dependencies. The graph in `.codegraph/graph.db`"
        "is **always current** — never run an `index` command first. `kg status` prints live counts"
        "and which folders are in scope (some are out by default).",
        "",
        "### Intent -> Command Cheat Sheet:",
        "```",
        f"Find a class, function, or signal:         {kg}/kg.bat find <name>",
        f"Inspect a file (WITHOUT reading it all):   {kg}/kg.bat outline <script>",
        f"Find who calls a method across files:      {kg}/kg.bat callers <method>",
        f"Trace signal emitters & .tscn listeners:   {kg}/kg.bat signal <signal>",
        f"Check network RPC handlers:                {kg}/kg.bat rpc",
        f"Check impact BEFORE editing a class:       {kg}/kg.bat impact <class> --depth 2",
        f"See what depends on a file:                {kg}/kg.bat deps <file> --reverse",
        f"Get a token-budgeted repo map:             {kg}/kg.bat md --budget 1200",
        f"Check graph status and counts:             {kg}/kg.bat status",
        "```",
        "",
        "### Updating the plugin (only if the user asks for it):",
        "```",
        f"{kg}/kg.bat update               # safe, read-only: is a newer CodeGraph out?",
        f"{kg}/kg.bat update --apply       # installs it — ASK THE USER FIRST, needs a Godot reload",
        f"{kg}/kg.bat update --restore     # undo (backup lives outside the project, in ~/{BACKUP_DIRNAME}/)",
        "```",
        "",
        "Candidates, not proof: dynamic calls (`get_node(var)`, `%UniqueName`, string-named groups, lambda `connect()`)",
        "are verified with targeted grep + `godot --headless --check-only` + an actual run.",
        f"On Linux/macOS use `./{kg}/kg` instead of `kg.bat`.",
        AGENTS_END,
    ]
    return "\n".join(lines) + "\n"


def _wrap(text: str) -> str:
    """Peikefil: berre blokkmerke + to linjer, så --remove kan kjenne att fila som vår."""
    return (AGENTS_BEGIN + "\n# AI agents: DO NOT grep or read full files. Read `AGENTS.md` in this folder first —\n"
            "# it documents the CodeGraph indexer (`kg.bat`) which you MUST query before any file inspection.\n" + AGENTS_END + "\n")


def _inner(txt: str) -> str:
    """Innhaldet MELLOM merka (utan merka), skjerda for mellomrom - brukt til å
    sjå om brukaren har redigert blokka vår. Merka åleine tel ikkje som endring,
    for `_splice_block` fjernar éin linjeskift etter sluttmerket, og elles ville
    kvar einaste `--install` sett ha sett av ein falsk «redigert for hand»-alarm.
    Tekst utan merke blir berre skjerda for mellomrom (blokker vi lagar sjølve)."""
    if not _has_block(txt):
        return txt.strip()
    return txt[txt.index(AGENTS_BEGIN) + len(AGENTS_BEGIN):txt.index(AGENTS_END)].strip()


def _has_block(txt: str) -> bool:
    return AGENTS_BEGIN in txt and AGENTS_END in txt


def _splice_block(txt: str, block: str) -> str:
    """Set inn / bytt ut blokken. Alt utanfor merka er urørt."""
    if _has_block(txt):
        a = txt.index(AGENTS_BEGIN)
        b = txt.index(AGENTS_END) + len(AGENTS_END)
        return txt[:a] + block.rstrip("\n") + txt[b:]
    sep = "" if txt.endswith("\n") or not txt else "\n"
    return txt + sep + ("\n" if txt else "") + block


def _drop_block(txt: str) -> str:
    """Fjern blokken utan å røre resten. `--install` la nøyaktig éin tom linje før
    merket og éitt linjeskift etter sluttmerket - berre det takast, slik at
    install + remove gir byte-identisk fil att."""
    if not _has_block(txt):
        return txt
    a = txt.index(AGENTS_BEGIN)
    b = txt.index(AGENTS_END) + len(AGENTS_END)
    if b < len(txt) and txt[b] == "\n":
        b += 1
    if txt[:a].endswith("\n\n"):
        a -= 1
    out = txt[:a] + txt[b:]
    return out if out.strip() else ""


def cmd_agents(con, root: Path, install: bool, remove: bool, tools: str | None, force: bool = False) -> int:
    """Skriv/les agentinstruksjonar i prosjektróta. Alt ligg inne i merka blokker."""
    targets = agents_targets(tools)
    paths = ["AGENTS.md"] + [POINTER_TARGETS[t] for t in targets if t != "agents"]

    if remove:
        # remove og status ser ALLE mål - brukaren treng ikkje hugse kva --tools han brukte
        for rel in ["AGENTS.md"] + list(POINTER_TARGETS.values()):
            p = root / rel
            if not p.exists():
                continue
            txt, eol, bom = _read_keep(p)
            if _has_block(txt) and _drop_block(txt).strip() == "":
                # Heile fila var berre vårt eget tjuvstart-avtrykk.
                p.unlink()
                print(f"  sletta {rel} (var berre CodeGraph-blokken)")
                # Tomme mapper vi laga (.cursor/rules/) follows med.
                up = p.parent
                while up != root and up.exists() and not any(up.iterdir()):
                    up.rmdir()
                    up = up.parent
            elif _has_block(txt):
                _write_keep(p, _drop_block(txt), eol, bom)
                print(f"  tok ut CodeGraph-blokken frå {rel}")
        return 0

    if install:
        block = agents_block(root)
        for rel in paths:
            p = root / rel
            if rel == "AGENTS.md":
                txt, eol, bom = _read_keep(p) if p.exists() else ("", "\n", "")
                if _has_block(txt) and _inner(txt) == _inner(block):
                    print(f"  {rel}: allereie installert (rør ikkje)")
                    continue
                # Blokk som er redigert for hand, blir verna utan --force.
                if _has_block(txt) and not force and _inner(txt) != _inner(block):
                    print(f"  {rel}: blokken er redigert for hand - bruk --force for å skrive over")
                    continue
                p.parent.mkdir(parents=True, exist_ok=True)
                _write_keep(p, _splice_block(txt, block), eol, bom)
            else:
                if p.exists():
                    txt, eol, bom = _read_keep(p)
                    if not _has_block(txt):
                        print(f"  hoppar over {rel}: brukaren har allereie ei anna fil der")
                        continue
                    # Peikefiler har berre merke + to linjer, så det er INNER
                    # i desse filene som samanliknast - ikkje heile AGENTS.md-blokka.
                    want = _inner(_wrap(""))
                    if _inner(txt) == want:
                        print(f"  {rel}: allereie installert (rør ikkje)")
                        continue
                    if not force:
                        print(f"  {rel}: blokken er redigert for hand - bruk --force for å skrive over")
                        continue
                    _write_keep(p, _wrap(""), eol, bom)
                    print(f"  skreiv {rel}")
                    continue
                else:
                    eol, bom = ("\r\n" if os.name == "nt" else "\n"), ""
                p.parent.mkdir(parents=True, exist_ok=True)
                _write_keep(p, _wrap(""), eol, bom)
            print(f"  skreiv {rel}")
        print("Desse filane er ment å committast. Angre: kg agents --remove")
        return 0

    # status (default)
    alle = ["AGENTS.md"] + list(POINTER_TARGETS.values())
    funnen = [rel for rel in alle if (root / rel).exists() and _has_block(_read_keep(root / rel)[0])]
    print("agentinstruksjonar: " + ("installert (" + ", ".join(funnen) + ")" if funnen else "ikkje installert"))
    if not funnen:
        print("  kg agents --install          # AGENTS.md")
        print("  kg agents --install --tools claude,copilot,cursor")
    return 0


def cmd_agents_standalone(root: Path, force: bool = False) -> int:
    """Same job som `kg agents`, men utan SQLite-eiga. Brukt av `kg update --apply`
    etter at filene er bytta: da er det DEN NYE graph.py som skriv blokkene, og
    tellinger + peikefiler blir som brukaren hadde dem frå før."""
    tools = None
    if (root / POINTER_TARGETS["claude"]).exists():
        tools = "claude"
        if (root / POINTER_TARGETS["copilot"]).exists():
            tools += ",copilot"
        if (root / POINTER_TARGETS["cursor"]).exists():
            tools += ",cursor"
    ctx = _Ctx(root)
    ctx.quiet, ctx.addons, ctx.web = True, False, False
    return cmd_agents(None, root, True, False, tools, force)


def cmd_symbols(con, limit: int = 5000) -> int:
    """JSON-liste av symbolnamn på same format som .codegraph/symbols.json.
    Editoren brukar dette til autocomplete utan å kjenne SQLite-skjemaet."""
    rows = con.execute(
        """SELECT DISTINCT name, kind FROM nodes
           WHERE kind IN ('class','fn','signal','autoload','group')
           ORDER BY length(name) ASC, name ASC LIMIT ?""", (limit,)).fetchall()
    print(json.dumps([{"n": r[0], "k": r[1]} for r in rows], ensure_ascii=False))
    return 0


def cmd_md(con, scope: str | None, budget: int | None, rank: bool, show_signals: bool) -> int:
    """Menneske- og agentlesbar Markdown. Rekkfølge = rekkevidde (Aider-stil)."""
    con.row_factory = sqlite3.Row
    deg: dict[int, int] = {}
    for s, d in con.execute("SELECT src,dst FROM edges WHERE kind NOT IN ('contains','has_node')"):
        deg[s] = deg.get(s, 0) + 1
        deg[d] = deg.get(d, 0) + 1
    sql = ("SELECT n.id,n.kind,n.name,n.file,n.line,n.sig,n.meta,f.kind AS fkind,f.addons "
           "FROM nodes n LEFT JOIN files f ON f.path=n.file WHERE n.kind='file'")
    args: list = []
    if scope:
        sql += " AND (n.name LIKE ? OR n.file LIKE ?)"
        args += [f"%{scope}%", f"%{scope}%"]
    rows = list(con.execute(sql + " ORDER BY n.file", args))
    info: dict[str, dict] = {}
    for r in rows:
        info[r["file"]] = dict(funcs=0, signals=0, cls="", ext="", auto="", snodes=0, script="", addons=r["addons"] or 0)
    for cls, file in con.execute("SELECT name,file FROM nodes WHERE kind='class' AND file IS NOT NULL"):
        i = info.get(file)
        if i and not i["cls"]:
            i["cls"] = cls
    for f, nm in con.execute("SELECT a.file, b.name FROM edges e JOIN nodes a ON a.id=e.src "
                             "JOIN nodes b ON b.id=e.dst WHERE e.kind='extends'"):
        i = info.get(f)
        if i and nm and not i["ext"]:
            i["ext"] = nm
    for f, c in con.execute("SELECT file, count(*) FROM nodes WHERE kind='fn' GROUP BY file"):
        if f in info:
            info[f]["funcs"] = c
    for f, c in con.execute("SELECT file, count(*) FROM nodes WHERE kind='signal' GROUP BY file"):
        if f in info:
            info[f]["signals"] = c
    for f, c in con.execute("SELECT file, count(*) FROM nodes WHERE kind='scene_node' GROUP BY file"):
        if f in info:
            info[f]["snodes"] = c
    for f, nm in con.execute("SELECT a.file, b.name FROM edges e JOIN nodes a ON a.id=e.src "
                             "JOIN nodes b ON b.id=e.dst WHERE e.kind='has_script'"):
        i = info.get(f)
        if i:
            i["script"] = nm
    for nm, path in con.execute("SELECT n.name, m.path FROM nodes n JOIN refs m ON m.name=n.name "
                                "WHERE n.kind='autoload' AND m.kind='autoload_of'"):
        p = path.replace("res://", "").lstrip("/")
        if p in info:
            info[p]["auto"] = nm
    ranked = sorted(rows, key=lambda r: -(deg.get(r["id"], 0) + info.get(r["file"], {}).get("funcs", 0)))
    if not rank:
        ranked = sorted(rows, key=lambda r: r["file"])
    out = ["# Repo-kart (generert av CodeGraph — graph.py, ikkje handredigert)",
           "kolonar: fil | class | extends | funcs | signaler | scenenoder | script | autoload | grader", ""]
    if show_signals:
        out.append("## Signaler")
        for nm, file, line in con.execute("SELECT name,file,line FROM nodes WHERE kind='signal' ORDER BY name"):
            out.append(f"- `{nm}` — {file}:{line}")
        out.append("")
    lines = []
    for r in ranked:
        i = info.get(r["file"], {})
        g = deg.get(r["id"], 0)
        addons = " (addon)" if i.get("addons") else ""
        lines.append(f"{r['file']}{addons} | {i.get('cls','')} | {i.get('ext','')} | {i.get('funcs',0)} | "
                     f"{i.get('signals',0)} | {i.get('snodes',0)} | {i.get('script','')} | {i.get('auto','')} | {g}")
    if budget:
        approx = budget
        acc, kept = 0, []
        for l in lines:
            acc += len(l) // 3 + 1
            if acc > approx:
                kept.append(f"… {len(lines) - len(kept)} filer utelatt (bruk --scope <ord> eller --budget)")
                break
            kept.append(l)
        lines = kept
    out += lines
    print("\n".join(out))
    return 0


# --------------------------------------------------------------------------
# HTML-visning
# --------------------------------------------------------------------------
def gather_view(con, view: str, ego: str | None, depth: int, limit: int) -> dict:
    con.row_factory = sqlite3.Row
    deg: dict[int, int] = {}
    for s, d in con.execute("SELECT src,dst FROM edges"):
        deg[s] = deg.get(s, 0) + 1
        deg[d] = deg.get(d, 0) + 1

    keep_ids: set[int] = set()
    pre_links = None
    if view == "files":
        # alle kantar går no frå funksjonsnoder — aggreger opp til filnivå att,
        # medan autoload/motor/gruppe-hubbar beheld seg sjølve som endepunkt
        meta = {r["id"]: (r["kind"], r["file"])
                for r in con.execute("SELECT id,kind,file FROM nodes")}
        fid_of = {r["file"]: r["id"]
                  for r in con.execute("SELECT id,file FROM nodes WHERE kind='file'")}
        addons_files = {r[0] for r in con.execute("SELECT path FROM files WHERE addons=1")}

        def up(nid):
            kind, file = meta.get(nid, (None, None))
            if kind in ("autoload", "builtin", "group"):
                return nid
            return fid_of.get(file, nid)

        acc: dict[tuple[int, int, str], int] = {}
        for s, d, k in con.execute("SELECT src,dst,kind FROM edges WHERE kind NOT IN ('contains','has_node')"):
            a, b = up(s), up(d)
            if a is None or b is None or a == b:
                continue
            fa = meta.get(a, (None, None))[1]
            fb = meta.get(b, (None, None))[1]
            if fa in addons_files or fb in addons_files:
                continue
            acc[(a, b, k)] = acc.get((a, b, k), 0) + 1
        pre_links = [dict(s=a, t=b, k=k, w=w, color=EDGE_COLOR.get(k, "#444"))
                     for (a, b, k), w in acc.items()]
        for l in pre_links:
            keep_ids.add(l["s"])
            keep_ids.add(l["t"])
    elif view == "signals":
        for r in con.execute("SELECT id FROM nodes WHERE kind='signal'"):
            keep_ids.add(r["id"])
        for r in con.execute("SELECT DISTINCT src AS id FROM edges WHERE kind IN ('emits','references') AND dst IN "
                             "(SELECT id FROM nodes WHERE kind='signal')"):
            keep_ids.add(r["id"])
        for r in con.execute("SELECT DISTINCT e.dst AS id FROM edges e WHERE e.kind='connects_to' AND e.src IN "
                             "(SELECT id FROM nodes WHERE kind='signal')"):
            keep_ids.add(r["id"])
    else:  # ego
        rows = node_row(con, ego or "")
        if not rows:
            sys.exit(f"fant ikke {ego!r} — bruk kg find")
        keep_ids = {r["id"] for r in rows}
        # utvid ego-et: fil/autoload/klasse → ta med alt den deklarerer (funksjonar/signal)
        for sid in list(keep_ids):
            nrow = con.execute("SELECT kind FROM nodes WHERE id=?", (sid,)).fetchone()
            if not nrow or nrow[0] not in ("file", "autoload", "class"):
                continue
            tgt = sid
            if nrow[0] == "autoload":
                t = con.execute("SELECT dst FROM edges WHERE src=? AND kind='uses_autoload'", (sid,)).fetchone()
                tgt = t[0] if t else sid
            keep_ids.add(tgt)
            for m in con.execute("SELECT dst AS id FROM edges WHERE src=? AND kind='contains'", (tgt,)):
                keep_ids.add(m["id"])
        frontier = set(keep_ids)
        d = 0
        while frontier and d < depth:
            q = ",".join("?" * len(frontier))
            nxt = set()
            for s, t in con.execute(f"SELECT src,dst FROM edges WHERE (src IN ({q}) OR dst IN ({q})) AND kind NOT IN ('contains','has_node')",
                                    list(frontier) + list(frontier)):
                for x in (s, t):
                    if x not in keep_ids:
                        nxt.add(x)
            keep_ids |= nxt
            frontier = nxt
            d += 1
    if len(keep_ids) > limit:
        keep_ids = set(sorted(keep_ids, key=lambda i: -deg.get(i, 0))[:limit])
    if not keep_ids:
        return dict(view=view, ego=ego, nodes=[], links=[], adj={},
                    colors=KIND_COLOR, edge_colors=EDGE_COLOR)
    q = ",".join(str(i) for i in keep_ids)
    nodes = []
    for r in con.execute(f"SELECT n.id,n.kind,n.name,n.file,n.line,n.sig,n.meta,f.kind AS fkind "
                         f"FROM nodes n LEFT JOIN files f ON f.path=n.file WHERE n.id IN ({q})"):
        fk = r["fkind"] or r["kind"]
        nodes.append(dict(id=r["id"], kind=r["kind"], name=r["name"], file=r["file"], line=r["line"],
                          sig=r["sig"], meta=r["meta"], deg=deg.get(r["id"], 0),
                          color=KIND_COLOR.get(fk, KIND_COLOR.get(r["kind"], "#888")),
                          folder=(r["file"] or "").split("/")[0] if r["file"] else ""))
    if pre_links is not None:
        links = [l for l in pre_links if l["s"] in keep_ids and l["t"] in keep_ids]
    else:
        agg: dict[tuple[int, int, str], dict] = {}
        for r in con.execute(f"SELECT src,dst,kind,count(*) c, min(line) ln FROM edges WHERE src IN ({q}) AND dst IN ({q}) "
                             "AND kind NOT IN ('contains') GROUP BY src,dst,kind"):
            agg[(r["src"], r["dst"], r["kind"])] = dict(s=r["src"], t=r["dst"], k=r["kind"], w=r["c"],
                                                        color=EDGE_COLOR.get(r["kind"], "#444"), line=r["ln"])
        links = list(agg.values())
    adj: dict[int, list] = {}
    for l in links:
        adj.setdefault(l["s"], []).append([l["t"], l["k"], "ut"])
        adj.setdefault(l["t"], []).append([l["s"], l["k"], "inn"])
    return dict(view=view, ego=ego, nodes=nodes, links=links, adj=adj,
                colors=KIND_COLOR, edge_colors=EDGE_COLOR)


def cmd_html(con, root: Path, view: str, ego: str | None, depth: int, limit: int, open_it: bool, out: str | None) -> int:
    tpl = Path(__file__).with_name("viewer_template.html")
    if not tpl.is_file():
        sys.exit(f"template missing: {tpl}")
    data = gather_view(con, view, ego, depth, limit)
    lang = "en"
    lang_file = root / DB_DIR / "lang.txt"
    if lang_file.is_file():
        try:
            saved = lang_file.read_text(encoding="utf-8").strip().lower()
            if saved in ("en", "no"):
                lang = saved
        except Exception:
            pass
    data["lang"] = lang
    html = tpl.read_text(encoding="utf-8").replace("__DATA_JSON__", json.dumps(data, ensure_ascii=False))
    target = Path(out) if out else root / DB_DIR / f"graph_{view}.html"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(html, encoding="utf-8")
    print(f"wrote {target}  ({len(data['nodes'])} nodes, {len(data['links'])} edges, {len(html)//1024} KB)")
    if open_it:
        import webbrowser
        webbrowser.open(target.as_uri())
    return 0


# --------------------------------------------------------------------------
# selftest
# --------------------------------------------------------------------------
def cmd_selftest() -> int:
    fx = Path(__file__).with_name("fixtures")
    if not (fx / "project.godot").is_file():
        print(f"fixtures mangler: {fx}")
        return 1
    old_db = fx / DB_DIR / DB_NAME
    if old_db.exists():
        old_db.unlink()
    index(fx, force=True)
    con = open_db(fx)

    def edge(kind: str, src_name: str, dst_name: str, src_file: str | None = None) -> int:
        # src kan vera filnoden eller funksjonen referansen står i — begge er gyldige
        sql = ("SELECT count(*) FROM edges e JOIN nodes a ON a.id=e.src JOIN nodes b ON b.id=e.dst "
               "WHERE e.kind=? AND b.name=? AND (a.name=? OR a.file LIKE ?)")
        args: list = [kind, dst_name, src_name, f"%{src_name}"]
        if src_file:
            sql += " AND a.file LIKE ?"
            args.append(f"%{src_file}")
        return con.execute(sql, args).fetchone()[0]

    def meta_of(name: str) -> str:
        r = con.execute("SELECT COALESCE(meta,'') FROM nodes WHERE kind='fn' AND name=?", (name,)).fetchone()
        return r[0] if r else "(finst ikkje)"

    def utskrift(fn, *a) -> str:
        import contextlib, io
        b = io.StringIO()
        with contextlib.redirect_stdout(b):
            fn(con, *a)
        return b.getvalue()

    checks = [
        ("extends: Player.gd → BaseVehicle (prosjektklasse)", edge("extends", "Player.gd", "BaseVehicle")),
        ("extends: Bullet.gd → Area2D (engine-base)",         edge("extends", "Bullet.gd", "Area2D")),
        ("autoload: Bus → Bus.gd",                            edge("uses_autoload", "Bus", "Bus.gd")),
        ("calls: Player.gd → spawn_vehicle",                  edge("calls", "Player.gd", "spawn_vehicle", "Player.gd")),
        ("calls via autoload: Hurtbox.gd → Bus.spawn_vehicle", edge("calls", "Hurtbox.gd", "spawn_vehicle", "Hurtbox.gd")),
        ("emits: Player.gd → hp_changed",                     edge("emits", "Player.gd", "hp_changed")),
        ("connects_to: hp_changed → _on_hp_changed",          edge("connects_to", "hp_changed", "_on_hp_changed")),
        ("preloads: Player.gd → Bullet.gd",                   edge("preloads", "Player.gd", "Bullet.gd")),
        ("instantiates: Player.tscn → Bullet.tscn",           edge("instantiates", "Player.tscn", "Bullet.tscn")),
        ("has_script: Player.tscn → Player.gd",               edge("has_script", "Player.tscn", "Player.gd")),
        ("tscn-signal: died → on_enemy_died",                 edge("connects_to", "died", "on_enemy_died")),
        ("in_group: Hurtbox.gd → enemies",                    edge("in_group", "Hurtbox.gd", "enemies")),
        ("calls_group: Hurtbox.gd → take_damage",             edge("calls_group", "Hurtbox.gd", "take_damage")),
        ("references_node: $Hurtbox/CollisionShape2D",        edge("references_node", "Player.gd", "Hurtbox/CollisionShape2D")),
        ("engine singleton: Hurtbox.gd → Engine",             edge("references", "Hurtbox.gd", "Time")),
        ("inner class: Player.gd → SaveSlot",                 edge("contains", "Player.gd", "SaveSlot")),
        # --- regelverket som kom etter gjennomgang (rpøe: @rpc, gruppetyper, .tscn→script) ---
        ("@rpc på eiga linje: net_ping meta=rpc",             1 if meta_of("net_ping") == "rpc" else 0),
        ("@rpc-config i sig: any_peer",                       1 if "any_peer" in (con.execute(
                                                                  "SELECT sig FROM nodes WHERE name='net_ping'").fetchone() or [""])[0] else 0),
        ("ikkje @rpc: this_is_not_rpc utan meta",             1 if meta_of("this_is_not_rpc") == "" else 0),
        ("in_group = medlemskap: RpcNet.gd → bandits",        edge("in_group", "RpcNet.gd", "bandits")),
        ("queries_group = spørring: RpcNet.gd → bandits",     edge("queries_group", "RpcNet.gd", "bandits")),
        (".tscn via instans + arv: body_entered → on_hit",    edge("connects_to", "body_entered", "on_hit")),
        ("motor-signal i kode: pressed → _on_ui_pressed",     edge("connects_to", "pressed", "_on_ui_pressed")),
        ("summert utskrift: tell først, kutt med --limit",     1 if ("fleire" in utskrift(cmd_signal, "hp_changed", 1)
                                                                     and "mottakarar:" in utskrift(cmd_signal, "hp_changed", 1)) else 0),
        ("gruppe-API ikkje støy: ingen 'add_to_group'-call",   1 if con.execute(
                                                                  "SELECT count(*) FROM unresolved WHERE name='add_to_group'").fetchone()[0] == 0 else 0),
        ("motor-signal får eigen node (body_entered)",        1 if con.execute(
                                                                  "SELECT count(*) FROM nodes WHERE kind='signal' AND name='body_entered'").fetchone()[0] else 0),
        # --- regelverket som kom etter gjennomgang 2: gruppert callers/callees + filutval ---
        ("gruppert callers-utskrift: fil + kalla linjer",      1 if ("gruppert per fil" in (g := utskrift(_dir, "take_damage", "callers", 3))
                                                                     and "linjer: L" in g and "kalla frå" in g) else 0),
        ("--all på callers: kant for kant (ingen gruppering)",  1 if "gruppert per fil" not in utskrift(_dir, "take_damage", "callers", 3, True) else 0),
        ("addons/ er utelata i standardfilutvalet",            1 if not any(p.startswith("addons/") for p in list_files(fx)) else 0),
        ("--addons tek med addon-fila",                        1 if any(p.startswith("addons/") for p in list_files(fx, want_addons=True)) else 0),
    ]
    ok = True
    for label, n in checks:
        print(f"  {'ok  ' if n else 'FEIL'}  {label}")
        ok = ok and bool(n)
    auto = con.execute("SELECT count(*) FROM nodes WHERE kind='autoload'").fetchone()[0]
    print(f"  {'ok  ' if auto >= 2 else 'FEIL'}  autoloads funnet ({auto})")
    ok = ok and auto >= 2
    pe = con.execute("SELECT count(*) FROM unresolved WHERE reason='signal-not-found' AND name='hp_changed'").fetchone()[0]
    print(f"  {'ok  ' if pe == 0 else 'FEIL'}  hp_changed ikke rapportert som uavklart")
    con.close()
    print("selftest:", "OK" if ok else "FEIL — en parser-regel treffer ikke fixtureen. "
                                      "Legg til regex + ny fixture, ikke ny sjekk.")
    return 0 if ok else 1


def cmd_verify(ctx) -> int:
    root = ctx["root"]
    res = index(root, want_web=ctx.get("web", False), want_addons=ctx.get("addons", False))
    con = open_db(root)
    pe = 0
    st = cmd_status(con, root)
    con.close()
    print()
    rc = cmd_selftest()
    if rc:
        print("\nFEIL: selftest — parser-regler treffer ikke fixtures")
        return 1
    print("\nverify OK")
    return st or pe


# --------------------------------------------------------------------------
# Oppdateringskontroll — `kg update`
#
# Versjonen ligg i version.json i rota på repoet, så dette krev korkje
# API-nøkkel, upload eller kvote. Er versjonen tagast (v1.0.1) finst
# arkiv-zippen automatisk på GitHub - nøyaktig den same zippen Godot AssetLib
# lastar ned. Utan tags fell vi på main.
#
# Utskiftinga skjer i denne eigenståande prosessen, ALDRI i editoren: dersom
# den nye filen ikkje ein gong lastar, står `kg update --restore` att likevel.
# Backupen hamnar utanfor prosjektet (~/.codegraph_backups/<prosjekt>/), så ho
# blir verken committa eller borte når addon-mappa byter innhald.
# --------------------------------------------------------------------------
REPO = os.environ.get("KG_REPO", "olavxxx/godot-codegraph")   # KG_REPO for forkar
VERSION_URL = f"https://raw.githubusercontent.com/{REPO}/main/version.json"
UPDATE_FILE = ".codegraph/update.json"
BACKUP_DIRNAME = ".codegraph_backups"
CHECK_TTL_H = 24.0


def _http_get(url: str, timeout: int = 15) -> tuple[int, bytes]:
    """Standardbibliotek åleine. Returnerer (status, body) - 404 og nettverksfeil
    er vanlege svarte i dette verktøyet, så her kastar vi ikkje."""
    import urllib.error
    import urllib.request
    req = urllib.request.Request(url, headers={"User-Agent": "codegraph-kg update"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return int(getattr(r, "status", 200) or 200), r.read()
    except urllib.error.HTTPError as e:
        return int(e.code), b""
    except Exception as e:                                    # noqa: BLE001
        return 0, str(e).encode("utf-8", "replace")


def local_version() -> str:
    """Versjonen pluginen sjølv trur han er (plugin.cfg ved sidan av graph.py)."""
    cfg = TOOL_DIR / "plugin.cfg"
    if not cfg.exists():
        return ""
    m = re.search(r'version\s*=\s*"([^"]+)"', cfg.read_text(encoding="utf-8", errors="replace"))
    return m.group(1) if m else ""


def ver_key(v: str) -> tuple:
    """1.10.2 > 1.9.9: samanlikn tal, ikkje strenger."""
    nums = tuple(int(x) for x in re.findall(r"\d+", v or ""))
    return nums or (0,)


def _slug(root: Path) -> str:
    h = hashlib.sha1(str(root).lower().encode("utf-8")).hexdigest()[:8]
    name = re.sub(r"[^a-z0-9]+", "-", root.name.lower()).strip("-") or "prosjekt"
    return f"{name}-{h}"


def backups_root(root: Path) -> Path:
    return Path.home() / BACKUP_DIRNAME / _slug(root)


def read_update_state(root: Path) -> dict:
    p = root / UPDATE_FILE
    if not p.exists():
        return {}
    try:
        d = json.loads(p.read_text(encoding="utf-8-sig", errors="replace"))
        return d if isinstance(d, dict) else {}
    except Exception:
        return {}


def write_update_state(root: Path, data: dict) -> None:
    p = root / UPDATE_FILE
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def remote_release() -> dict:
    json_code, body = _http_get(VERSION_URL)
    if json_code == 200:
        try:
            d = json.loads(body.decode("utf-8", "replace"))
            if isinstance(d, dict) and d.get("version"):
                return {"version": str(d["version"]), "tag": str(d.get("tag", "")).strip(),
                        "notes": str(d.get("notes", "")), "source": "version.json", "http": 200,
                        "json_http": 200, "reason": ""}
        except Exception:
            pass                                    # øydelagd JSON → prøv tags i staden
    code, body = _http_get(f"https://api.github.com/repos/{REPO}/tags?per_page=1")
    if code == 200:
        try:
            tags = json.loads(body.decode("utf-8", "replace"))
            if isinstance(tags, list) and tags:
                tag = str(tags[0].get("name", ""))
                return {"version": re.sub(r"^v", "", tag), "tag": tag,
                        "notes": f"https://github.com/{REPO}/releases", "source": "tags",
                        "http": 200, "json_http": json_code}
        except Exception:
            pass
    return {"version": "", "tag": "", "notes": "", "source": "",
            "http": code, "json_http": json_code,
            "reason": "no_release" if (json_code == 200 and code == 200) else "network"}


def zip_url(tag: str) -> str:
    if tag:
        return f"https://github.com/{REPO}/archive/refs/tags/{tag}.zip"
    return f"https://github.com/{REPO}/archive/refs/heads/main.zip"


def _write_restore_script(bdir: Path, addon: Path) -> Path:
    """Gjenopprettinga må verke utan pluginen, utan Python og utan git."""
    if os.name == "nt":
        p = bdir / "restore.bat"
        p.write_text("@echo off\r\nrem Attstill CodeGraph-pluginen til versjonen i denne mappa\r\n"
                     f'xcopy /E /Y /I "%~dp0codegraph" "{addon}"\r\n'
                     "echo CodeGraph er attendestilt. Last prosjektet pa nytt i Godot.\r\n",
                     encoding="ascii")
    else:
        p = bdir / "restore.sh"
        p.write_text("#!/bin/sh\n# Attstill CodeGraph-pluginen til versjonen i denne mappa\n"
                     f'cp -a "$(dirname "$0")/codegraph/." "{addon}"\n'
                     "echo 'CodeGraph er gjenopprettet. Last prosjektet pa nytt i Godot.'\n",
                     encoding="ascii")
        p.chmod(0o755)
    return p


def restore_backup(root: Path, addon: Path, as_json: bool) -> int:
    base = backups_root(root)
    if not base.exists():
        print(f"Ingen backupar her: {base}")
        return 1
    latest = max([d for d in base.iterdir() if d.is_dir()], key=lambda d: d.name, default=None)
    if latest is None:
        print(f"Tom backupmappe: {base}")
        return 1
    src = latest / "codegraph"
    if not src.exists():
        print(f"Backupen manglar codegraph-mappe: {latest}")
        return 1
    shutil.copytree(src, addon, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("__pycache__", ".codegraph"))
    if as_json:
        print(json.dumps({"restored_from": str(latest), "addon": str(addon)}, ensure_ascii=False))
    else:
        print(f"Attstilte frå {latest}")
        print(f"Addon: {addon}")
        print("Last prosjektet på nytt i Godot (Prosjekt → Last inn noverande prosjekt på nytt).")
    return 0


def _apply_update(root: Path, addon: Path, info: dict, force: bool, as_json: bool) -> int:
    if not addon.exists():
        print(f"FEIL: fann ikkje addon-mappa {addon}")
        return 1
    if not info.get("update_available") and not force:
        print(f"Allereie nyaste versjon ({info.get('current') or '?'}). --apply --force skriv på nytt.")
        return 0
    want = str(info.get("latest") or "")
    url = zip_url(str(info.get("tag") or ""))
    code, blob = _http_get(url, timeout=120)
    if code != 200 or not blob:
        info["apply_error"] = f"nedlasting av {url} feila (http {code})"
        write_update_state(root, info)
        print(f"FEIL: {info['apply_error']}")
        return 1
    tmp = Path(tempfile.mkdtemp(prefix="codegraph_update_"))
    try:
        zp = tmp / "pkg.zip"
        zp.write_bytes(blob)
        import zipfile
        with zipfile.ZipFile(zp) as z:
            names = [n for n in z.namelist() if "/addons/codegraph/" in n and "__pycache__" not in n]
            if not names:
                print("FEIL: zippen inneheld ikkje addons/codegraph - avbryt, ingenting erendra.")
                return 1
            stage = tmp / "stage"
            z.extractall(stage, members=names)
            pre = names[0].split("/addons/codegraph/")[0]
            src = stage / pre / "addons" / "codegraph"
            new_ver = ""
            if (src / "plugin.cfg").exists():
                m = re.search(r'version\s*=\s*"([^"]+)"',
                              (src / "plugin.cfg").read_text(encoding="utf-8", errors="replace"))
                new_ver = m.group(1) if m else ""
            if want and new_ver and new_ver != want and not force:
                print(f"FEIL: zippen for {want} inneheld plugin.cfg {new_ver} - avbryt. "
                      "Oppdater version.json i repoen.")
                return 1
        # Backup FØRST, utanfor prosjektet.
        stamp = time.strftime("%Y%m%d-%H%M%S")
        bdir = backups_root(root) / stamp
        bdir.mkdir(parents=True, exist_ok=True)
        shutil.copytree(addon, bdir / "codegraph", dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("__pycache__", ".codegraph"))
        script = _write_restore_script(bdir, addon)
        changed: list[str] = []
        added: list[str] = []
        for p in sorted(src.rglob("*")):
            if p.is_dir() or "__pycache__" in p.parts:
                continue
            rel = p.relative_to(src).as_posix()
            dst = addon / rel
            if not dst.exists():
                added.append(rel)
            elif dst.read_bytes() != p.read_bytes():
                changed.append(rel)
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(p.read_bytes())
        info.update({
            "applied_from": info.get("current", ""), "applied_to": new_ver or want,
            "applied_at": time.time(),
            "applied_at_iso": time.strftime("%Y-%m-%d %H:%M", time.localtime()),
            "backup": str(bdir), "restore": str(script),
            "changed": changed, "added": added,
        })
        # 4. nye versjonen sine agentfilversjonar (kun der blokk alt finst)
        info["agent_files"] = refresh_agent_files_after_update(root, as_json)
        write_update_state(root, info)
        if as_json:
            print(json.dumps(info, ensure_ascii=False))
        else:
            print(f"CodeGraph {info['applied_from']} → {info['applied_to']}")
            print(f"  endra filer: {len(changed)}, nye filer: {len(added)}")
            for f in changed[:25]:
                print("   endra:", f)
            for f in added[:15]:
                print("   ny   :", f)
            print(f"Backup: {bdir}")
            print(f"Angre:  {script}   (eller: kg update --restore)")
            print("No må du laste prosjektet på nytt i Godot: Prosjekt → Last inn noverande prosjekt på nytt.")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def cmd_update(root: Path, do_apply: bool = False, restore: bool = False,
               force: bool = False, as_json: bool = False) -> int:
    addon = root / "addons" / "codegraph"
    cur = local_version()
    if restore:
        return restore_backup(root, addon, as_json)
    state = read_update_state(root)
    age_h = 0.0
    if state.get("checked_at"):
        try:
            age_h = (time.time() - float(state["checked_at"])) / 3600.0
        except Exception:
            age_h = 0.0
    cached = bool(state) and not force and age_h < CHECK_TTL_H and bool(state.get("asked_net"))
    if not cached:
        rel = remote_release()
        state = {
            "checked_at": time.time(),
            "checked_at_iso": time.strftime("%Y-%m-%d %H:%M", time.localtime()),
            "latest": rel["version"], "tag": rel["tag"], "notes": rel["notes"],
            "source": rel["source"], "http": rel["http"],
            # skilnadar «spørde nettverket» frå «berre las svaret frå før» -
            # elles ville kvar cache-treff forny TTL-en for alltid
            "asked_net": True,
            "update_available": bool(rel["version"]) and ver_key(rel["version"]) > ver_key(cur),
            "reason": rel.get("reason", "") if not rel["version"] else "",
            "error": "" if rel["version"] else (
                "repoen har korkje version.json i main (http %s) eller nokon tag (http %s) enno"
                % (rel.get("json_http", "?"), rel.get("http", "?"))),
        }
        write_update_state(root, state)
    state["current"] = cur
    state["cached"] = cached
    state["age_h"] = round(age_h, 1)
    state["addon_found"] = addon.exists()
    state.setdefault("checked_at_iso", "")
    if as_json:
        print(json.dumps(state, ensure_ascii=False))
    else:
        print(f"CodeGraph  installert: {cur or 'ukjend'}")
        print(f"           nyaste kjende: {state.get('latest') or '—'}"
              f"  (kjelde: {state.get('source') or '—'}, sjekka: {state.get('checked_at_iso') or '—'})")
        if state.get("update_available"):
            print(f" → ny versjon finst: {state['latest']}.  Kør:  kg update --apply")
        elif state.get("error"):
            print(f" → {state['error']}")
        else:
            print(" → allereie nyaste versjon.")
        if cached:
            print(f"   (cache: svar frå nettverket for {state['age_h']} timar sidan; --force spør på nytt)")
    if do_apply:
        return _apply_update(root, addon, state, force, as_json)
    return 0 if not state.get("error") else 2


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="kg", description="Godot-kodelager (GDScript + scenes)")
    ap.add_argument("--path", help="prosjektrot (default: opp fra cwd til project.godot)")
    ap.add_argument("--addons", action="store_true",
                    help="ta med addons/ (tredjepart) — utelata som standard")
    ap.add_argument("--web", action="store_true",
                    help="ta med web/ (JS-app) — utelata som standard")
    sub = ap.add_subparsers(dest="cmd")

    p = sub.add_parser("index", help="bygg/oppdater indexen")
    p.add_argument("--force", action="store_true")
    sub.add_parser("status", help="helse: tellinger og parse-feil")
    sub.add_parser("verify", help="reindex + selftest (for build_release.ps1 / CI)")
    sub.add_parser("selftest", help="kjør fixtures")
    def add_lim(p: argparse.ArgumentParser, default: int = 25) -> argparse.ArgumentParser:
        p.add_argument("--limit", type=int, default=default,
                       help="maks rader (default %(default)s). Summert teljing kjør alltid først.")
        p.add_argument("--all", action="store_true", help="vis alle rader (forstyrrar utskrifta)")
        return p

    q = add_lim(sub.add_parser("symbols", help="JSON-liste av symbol (autocomplete for editoren)"), 5000)
    q = sub.add_parser("agents", help="skriv/fjern agentinstruksjonar i prosjektróta (merkt blokk)")
    q.add_argument("--install", action="store_true", help="installer eller oppdater blokkene")
    q.add_argument("--remove", action="store_true", help="ta blokkene vekk att")
    q.add_argument("--tools", help="peikefilar for verktøy som ikkje les AGENTS.md: claude,copilot,cursor")
    q.add_argument("--force", action="store_true", help="skriv over blokka sjølv om ho er redigert for hand")
    q = add_lim(sub.add_parser("find"), 40)
    q.add_argument("name")
    q = add_lim(sub.add_parser("outline"))
    q.add_argument("name")
    q = add_lim(sub.add_parser("signal"))
    q.add_argument("name")
    q = add_lim(sub.add_parser("rpc", help="alle @rpc-funksjonar (nettverkskontrakt), valdig filter"))
    q.add_argument("name", nargs="?")
    for c in ("callers", "callees", "deps", "impact"):
        q = add_lim(sub.add_parser(c), 15 if c in ("callers", "callees") else 25)
        q.add_argument("name")
        if c == "impact":
            q.add_argument("--depth", type=int, default=2)
        if c == "deps":
            q.add_argument("--reverse", action="store_true")
    q = sub.add_parser("path")
    q.add_argument("a")
    q.add_argument("b")
    q = sub.add_parser("unresolved", help="hva grafen IKKE kunne løse (viktig: kandidater, ikke fasit)")
    q.add_argument("--top", type=int, default=25)
    q = sub.add_parser("md", help="repo-kart som markdown (--files er default)")
    q.add_argument("--scope")
    q.add_argument("--budget", type=int, default=0)
    q.add_argument("--rank", action="store_true", help="rangert etter grader (Aider-stil)")
    q.add_argument("--signals", action="store_true", help="legg til signal-indeks")
    q = sub.add_parser("html", help="interaktiv grafvisning i nettleser")
    q.add_argument("--view", choices=["files", "signals", "ego"], default="files")
    q.add_argument("--ego")
    q.add_argument("--depth", type=int, default=2)
    q.add_argument("--limit", type=int, default=900)
    q.add_argument("--out")
    q.add_argument("--open", action="store_true")
    q = sub.add_parser("watch", help="valgfritt: poll og reindexer (egentlig unødvendig, index er selvforfriskende)")
    q.add_argument("--interval", type=float, default=2.0)

    q = sub.add_parser("update", help="sjekk om nyare CodeGraph-versjon finst (lesing åleine, trygt)")
    q.add_argument("--apply", action="store_true",
                   help="INSTALLER nyaste versjon: skriv addons/codegraph/ (backup lagast utanfor "
                        "prosjektet) - agentar må spørje brukaren om løyve før dette")
    q.add_argument("--restore", action="store_true", help="attstill siste backup av addonen")
    q.add_argument("--force", action="store_true", help="hopp over 24-timers cache / tillat same versjon")
    q.add_argument("--json", action="store_true", help="maskinlesbart eittlinje-JSON")

    a = ap.parse_args()
    root = find_root(a.path)
    ctx = dict(root=root, web=a.web, addons=a.addons)
    if a.cmd in ("index",):
        print(json.dumps(index(root, a.force, a.web, a.addons), ensure_ascii=False, indent=2))
        return 0
    if a.cmd == "selftest":
        return cmd_selftest()
    if a.cmd == "verify":
        return cmd_verify(ctx)
    if a.cmd == "watch":
        while True:
            r = index(root, want_web=a.web, want_addons=a.addons)
            if not r.get("unchanged"):
                log(f"reindexed: {r}")
            time.sleep(a.interval)
    if a.cmd == "update":
        return cmd_update(root, do_apply=a.apply, restore=a.restore, force=a.force, as_json=a.json)
    con = db(ctx)
    try:
        if a.cmd in (None, "status"):
            return cmd_status(con, root)
        if a.cmd == "symbols":
            return cmd_symbols(con, L(a))
        if a.cmd == "agents":
            return cmd_agents(con, root, a.install, a.remove, a.tools, a.force)
        if a.cmd == "find":
            return cmd_find(con, a.name, L(a))
        if a.cmd == "outline":
            return cmd_outline(con, a.name)
        if a.cmd == "signal":
            return cmd_signal(con, a.name, L(a))
        if a.cmd == "rpc":
            return cmd_rpc(con, a.name, L(a))
        if a.cmd == "callers":
            return _dir(con, a.name, "callers", L(a), flat=a.all)
        if a.cmd == "callees":
            return _dir(con, a.name, "callees", L(a), flat=a.all)
        if a.cmd == "deps":
            return cmd_deps(con, a.name, a.reverse, L(a))
        if a.cmd == "impact":
            return cmd_impact(con, a.name, a.depth, L(a))
        if a.cmd == "path":
            return cmd_path(con, a.a, a.b)
        if a.cmd == "unresolved":
            return cmd_unresolved(con, a.top)
        if a.cmd == "md":
            return cmd_md(con, a.scope, a.budget or None, a.rank, a.signals)
        if a.cmd == "html":
            return cmd_html(con, root, a.view, a.ego, a.depth, a.limit,
                            open_it=a.open, out=a.out)
    finally:
        con.close()
    ap.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
