# AGENTS.md — CodeGraph for Godot

This repo is the CodeGraph editor plugin. `addons/codegraph/` is the addon that users
copy into their own Godot project, so **everything they see is user-facing text**.

## Layout

- `addons/codegraph/backend/graph.py` — the whole engine: SQLite index, parser, all CLI
  subcommands (`kg` / `kg.bat` wraps it), and the `update` self-updater.
- `addons/codegraph/codegraph_dock.gd` + `.tscn` — the `@tool` editor dock (all UI).
- `addons/codegraph/plugin.cfg` — `version` here is what `kg update` compares against.
- `version.json` (repo root) — the version we publish: `"version"` + `"tag"` must match a
  git tag. `kg update` reads this file; a tag alone is enough if the file is missing.
- Benchmarks, previews and scratch files: keep them out of the addon folder.

## Release = three numbers in step, then one tag

`plugin.cfg version` == `version.json "version"` == `version.json "tag"` without the `v`.
Do that bump in its own commit (no other edits in it), then tag that commit:

```
# commit the bump + the fixes it covers, then:
git tag v1.1.1
git push origin main --tags
```

Users get the amber chip within a minute; no GitHub Release is needed (GitHub's own
`archive/refs/tags/v1.1.0.zip` is what the updater installs). Ship each commit as its own
tag — an update never rewrites files outside `addons/codegraph/`, but it does rewrite the
agent block in a project's `AGENTS.md`/`CLAUDE.md` when that block still matches what we
generated, so a tag that mixes features with unrelated rewrites pushes those rewrites to
every user. `README.md` → "Staying up to date" documents the whole flow; keep that section
correct when the mechanism changes. Broken release: delete the tag, bump a patch number,
fix forward.

## Rules for changes here

- UI text exists in **both** `en` and `no` blocks in `codegraph_dock.gd` (STRINGS). Keep the
  key sets identical — no key in one language only. Norwegian is Nynorsk-flavoured Bokmål,
  matching the existing strings.
- `.codegraph/` (index, cache, update state) must never be committed; agent files
  (`AGENTS.md` and friends) are meant to be committed.
- Never let `kg update --apply` run inside this repo while it has uncommitted work: the
  `main` archive would overwrite local edits. Test updates in a throwaway project dir.
- Anything that writes into a user's files (`kg agents`, the update's agent refresh) must
  leave hand-edited blocks alone unless `--force` is passed.

## Checking your work (Godot 4.7.2 mono is the reference build)

```
godot --headless --path . --check-only --script res://addons/codegraph/codegraph_dock.gd
python -m py_compile addons/codegraph/backend/graph.py
python addons/codegraph/backend/graph.py --path . selftest
```

Do not round-trip `.gd`/`.tscn` files through PowerShell text pipelines — it mangles the
emoji and the encoding. Edit them as files.
