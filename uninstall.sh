#!/usr/bin/env bash
# Remove old root-level commands that have been replaced by slashdo (/do:* namespace)
set -euo pipefail

TARGET_DIR="$HOME/.claude/commands"
LIB_DIR="$HOME/.claude/lib"

COMMANDS=(cam fpr makegoals makegood pr release replan rpr review)
SUBDIRS=(claude/optimize-md)
LIBS=(code-review-checklist copilot-review-loop graphql-escaping)

removed=0

for cmd in "${COMMANDS[@]}"; do
  f="$TARGET_DIR/$cmd.md"
  if [ -f "$f" ]; then
    rm "$f"
    printf 'removed: /%s\n' "$cmd"
    removed=$((removed + 1))
  fi
done

for cmd in "${SUBDIRS[@]}"; do
  f="$TARGET_DIR/$cmd.md"
  if [ -f "$f" ]; then
    rm "$f"
    printf 'removed: /%s\n' "$(echo "$cmd" | sed 's|/|:|g')"
    removed=$((removed + 1))
    # remove parent dir if empty
    dir="$(dirname "$f")"
    rmdir "$dir" 2>/dev/null && printf 'removed empty dir: %s\n' "$dir" || true
  fi
done

for lib in "${LIBS[@]}"; do
  f="$LIB_DIR/$lib.md"
  if [ -f "$f" ]; then
    rm "$f"
    printf 'removed: lib/%s.md\n' "$lib"
    removed=$((removed + 1))
  fi
done

if [ "$removed" -eq 0 ]; then
  printf 'Nothing to remove — old commands already cleaned up.\n'
else
  printf '\n%d files removed.\n' "$removed"
  printf 'Migrate to slashdo: npx slash-do@latest\n'
fi
