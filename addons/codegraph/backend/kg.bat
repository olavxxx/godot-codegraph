@echo off
rem Runner for the codegraph tool. Works from any folder in the repo.
rem Example:  addons\codegraph\backend\kg.bat callers take_damage
python "%~dp0graph.py" %*
