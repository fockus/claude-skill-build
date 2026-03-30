#!/usr/bin/env python3
"""Merge skill hooks into ~/.claude/settings.json without overwriting existing hooks."""
import json
import sys

def merge_hooks(settings_path: str, hooks_path: str) -> None:
    with open(settings_path) as f:
        settings = json.load(f)

    with open(hooks_path) as f:
        new_hooks = json.load(f)

    existing_hooks = settings.setdefault("hooks", {})

    for event, entries in new_hooks.items():
        if event not in existing_hooks:
            existing_hooks[event] = entries
            continue

        # Deduplicate: check if hook command already exists
        existing_commands = set()
        for entry in existing_hooks[event]:
            if isinstance(entry, dict):
                for h in entry.get("hooks", []):
                    if isinstance(h, dict):
                        existing_commands.add(h.get("command", ""))

        for entry in entries:
            if isinstance(entry, dict):
                hook_cmds = [h.get("command", "") for h in entry.get("hooks", []) if isinstance(h, dict)]
                if not any(cmd in existing_commands for cmd in hook_cmds):
                    existing_hooks[event].append(entry)

    settings["hooks"] = existing_hooks

    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <settings.json> <hooks.json>")
        sys.exit(1)
    merge_hooks(sys.argv[1], sys.argv[2])
