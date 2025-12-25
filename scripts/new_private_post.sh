#!/usr/bin/env bash
set -euo pipefail

# new_private_post.sh — create/edit a local-only Hugo post in content/private
# These files are gitignored and won't deploy to GitHub Pages.
# Usage:
#   scripts/new_private_post.sh "My Private Note"
#   scripts/new_private_post.sh --draft "My Draft Private"
#   scripts/new_private_post.sh --no-edit "Quick Private"

repo_root="$(cd "$(dirname "$0")"/.. && pwd)"
private_dir="$repo_root/content/private"
mkdir -p "$private_dir"

slugify() {
  local s="$1"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
  s="$(printf '%s' "$s" | sed -E 's/[^a-z0-9]+/-/g')"
  s="$(printf '%s' "$s" | sed -E 's/^-+//; s/-+$//')"
  echo "$s"
}

show_help() {
  sed -n '1,20p' "$0"
}

draft_flag=false
no_edit=false
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --draft) draft_flag=true; shift ;;
    --no-edit) no_edit=true; shift ;;
    --help|-h) show_help; exit 0 ;;
    *) args+=("$1"); shift ;;
  esac
done

if [[ ${#args[@]} -eq 0 ]]; then
  echo "Enter private post title:" >&2
  read -r TITLE
  [[ -z "$TITLE" ]] && echo "Error: Title is required." >&2 && exit 1
else
  TITLE="${args[0]}"
fi

slug="$(slugify "$TITLE")"
post_path="$private_dir/$slug.md"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ ! -f "$post_path" ]]; then
  {
    echo "---"
    echo "title: \"$TITLE\""
    echo "date: $NOW"
    if $draft_flag; then echo "draft: true"; else echo "draft: false"; fi
    echo "tags: [private]"
    echo "---"
    echo
    echo "<!-- Local-only, not committed. -->"
    echo
  } > "$post_path"
  echo "Created private: $post_path"
else
  echo "Editing private: $post_path"
fi

open_editor() {
  local f="$1"
  if [[ -n "${VISUAL:-}" ]]; then "$VISUAL" "$f"
  elif [[ -n "${EDITOR:-}" ]]; then "$EDITOR" "$f"
  elif command -v code >/dev/null 2>&1; then code -w "$f"
  elif command -v nano >/dev/null 2>&1; then nano "$f"
  elif [[ "$(uname)" == "Darwin" ]]; then open -W -t "$f"
  else
    echo "No editor detected; set $VISUAL or $EDITOR, or install 'code'." >&2
    exit 1
  fi
}

if ! $no_edit; then
  open_editor "$post_path"
fi

echo "Private post ready locally at /private/$slug/ when running:"
echo "  hugo server -D"
