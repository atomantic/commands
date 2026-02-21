#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$REPO_DIR/commands"
TARGET_DIR="$HOME/.claude/commands"

usage() {
    printf 'Usage: %s [options] [command ...]\n\n' "$(basename "$0")"
    printf 'Install or update Claude Code slash commands from this repo to ~/.claude/commands/\n\n'
    printf 'Options:\n'
    printf '  --list      Show all commands and their install status\n'
    printf '  --dry-run   Preview changes without applying them\n'
    printf '  --help      Show this help message\n\n'
    printf 'Examples:\n'
    printf '  %s                    # install/update all commands\n' "$(basename "$0")"
    printf '  %s cam pr             # install/update specific commands\n' "$(basename "$0")"
    printf '  %s --list             # show commands and install status\n' "$(basename "$0")"
    printf '  %s --dry-run          # preview changes without applying\n' "$(basename "$0")"
    printf '  %s --dry-run cam      # preview specific command\n' "$(basename "$0")"
}

# Extract description from YAML frontmatter or first markdown heading
get_description() {
    local file="$1"
    local desc=""
    local in_frontmatter=0
    local line_num=0
    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        if [ "$line_num" -eq 1 ] && [ "$line" = "---" ]; then
            in_frontmatter=1
            continue
        fi
        if [ "$in_frontmatter" -eq 1 ]; then
            if [ "$line" = "---" ]; then
                in_frontmatter=0
                continue
            fi
            case "$line" in
                description:*)
                    desc="${line#description:}"
                    desc="${desc# }"
                    printf '%s' "$desc"
                    return
                    ;;
            esac
            continue
        fi
        case "$line" in
            "# "*)
                desc="${line#\# }"
                printf '%s' "$desc"
                return
                ;;
        esac
    done < "$file"
    printf '(no description)'
}

# Get relative path of a command file (e.g. cam.md, claude/optimize-md.md)
get_rel_path() {
    local file="$1"
    printf '%s' "${file#"$SRC_DIR"/}"
}

# Get display name from relative path (e.g. cam, claude/optimize-md -> claude:optimize-md)
get_display_name() {
    local rel="$1"
    local name="${rel%.md}"
    printf '%s' "$name" | sed 's|/|:|g'
}

# Collect command files, optionally filtered by name args
collect_files() {
    local filter_names=("$@")
    local files=()
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$SRC_DIR" -name '*.md' -type f -print0 | sort -z)

    if [ "${#filter_names[@]}" -eq 0 ]; then
        printf '%s\n' "${files[@]}"
        return
    fi

    local file rel name matched
    for file in "${files[@]}"; do
        rel="$(get_rel_path "$file")"
        name="$(get_display_name "$rel")"
        matched=0
        for filter in "${filter_names[@]}"; do
            if [ "$name" = "$filter" ] || [ "$rel" = "$filter" ] || [ "$rel" = "$filter.md" ]; then
                matched=1
                break
            fi
        done
        if [ "$matched" -eq 1 ]; then
            printf '%s\n'  "$file"
        fi
    done
}

do_list() {
    printf '%-25s %-12s %s\n' "COMMAND" "STATUS" "DESCRIPTION"
    printf '%-25s %-12s %s\n' "-------" "------" "-----------"
    while IFS= read -r -d '' file; do
        local rel name target desc status
        rel="$(get_rel_path "$file")"
        name="$(get_display_name "$rel")"
        target="$TARGET_DIR/$rel"
        desc="$(get_description "$file")"
        if [ ! -f "$target" ]; then
            status="not installed"
        elif diff -q "$file" "$target" >/dev/null 2>&1; then
            status="up to date"
        else
            status="changed"
        fi
        printf '%-25s %-12s %s\n' "/$name" "$status" "$desc"
    done < <(find "$SRC_DIR" -name '*.md' -type f -print0 | sort -z)
}

do_install() {
    local dry_run="$1"
    shift
    local filter_names=("$@")

    local installed=0
    local updated=0
    local up_to_date=0

    local file
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local rel name target target_dir
        rel="$(get_rel_path "$file")"
        name="$(get_display_name "$rel")"
        target="$TARGET_DIR/$rel"
        target_dir="$(dirname "$target")"

        if [ ! -f "$target" ]; then
            if [ "$dry_run" -eq 1 ]; then
                printf 'would install: /%s\n' "$name"
            else
                mkdir -p "$target_dir"
                cp "$file" "$target"
                printf 'installed: /%s\n' "$name"
            fi
            installed=$((installed + 1))
        elif diff -q "$file" "$target" >/dev/null 2>&1; then
            printf 'up to date: /%s\n' "$name"
            up_to_date=$((up_to_date + 1))
        else
            if [ "$dry_run" -eq 1 ]; then
                printf 'would update: /%s\n' "$name"
                diff -u "$target" "$file" || true
                printf '\n'
            else
                cp "$file" "$target"
                printf 'updated: /%s\n' "$name"
            fi
            updated=$((updated + 1))
        fi
    done < <(collect_files ${filter_names[@]+"${filter_names[@]}"})

    printf '\n%d installed, %d updated, %d up to date\n' "$installed" "$updated" "$up_to_date"
}

# Parse arguments
dry_run=0
list_mode=0
names=()

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --list)
            list_mode=1
            ;;
        --dry-run)
            dry_run=1
            ;;
        -*)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
        *)
            names+=("$1")
            ;;
    esac
    shift
done

if [ "$list_mode" -eq 1 ]; then
    do_list
else
    do_install "$dry_run" ${names[@]+"${names[@]}"}
fi
