#!/usr/bin/env bash
set -euo pipefail

# new_post.sh — create/edit a Hugo post, then auto-commit & push.
# Usage:
#   scripts/new_post.sh "My Post Title"
#   scripts/new_post.sh --draft "My Draft Title"
#   scripts/new_post.sh --no-edit "Quick Post"
# Options:
#   --draft     Create the post as draft: true (won't publish until you flip it)
#   --no-edit   Do not open an editor; just create (or use existing), commit & push
#   --help      Show help

repo_root="$(cd "$(dirname "$0")"/.. && pwd)"
content_dir="$repo_root/content/posts"
mkdir -p "$content_dir"

show_help() {
  sed -n '1,20p' "$0"
}

draft_flag=false
no_edit=false

# Parse flags
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --draft)
      draft_flag=true; shift ;;
    --no-edit)
      no_edit=true; shift ;;
    --help|-h)
      show_help; exit 0 ;;
    *)
      args+=("$1"); shift ;;
  esac
done

# Title (required unless --no-edit and file exists)
if [[ ${#args[@]} -eq 0 ]]; then
  echo "Enter post title:" >&2
  read -r TITLE
  if [[ -z "$TITLE" ]]; then
    echo "Error: Title is required." >&2
    exit 1
  fi
else
  TITLE="${args[0]}"
fi

# slugify title → filename
slugify() {
  local s="$1"
  # lowercase
  s="${s,,}"
  # replace non-alnum with hyphens
  s="$(echo "$s" | sed 's/[^a-z0-9]+/-/g; s/[^a-z0-9]/-/g')"
  # collapse multiple hyphens
  s="$(echo "$s" | sed 's/-\{2,\}/-/g')"
  # trim leading/trailing hyphens
  s="$(echo "$s" | sed 's/^-\+//; s/-\+$//')"
  echo "$s"
}

slug="$(slugify "$TITLE")"
post_path="$content_dir/$slug.md"

# Create front matter if new
if [[ ! -f "$post_path" ]]; then
  NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  {
    echo "---"
    echo "title: \"$TITLE\""
    echo "date: $NOW"
    if $draft_flag; then echo "draft: true"; else echo "draft: false"; fi
    echo "---"
    echo
    echo "<!-- Write your post below. -->"
    echo
  } > "$post_path"
  echo "Created: $post_path"
else
  echo "Editing existing: $post_path"
fi

open_editor() {
  local f="$1"
  # Prefer VISUAL/EDITOR, else VS Code, else nano, else macOS TextEdit
  if [[ -n "${VISUAL:-}" ]]; then
    "$VISUAL" "$f"
  elif [[ -n "${EDITOR:-}" ]]; then
    "$EDITOR" "$f"
  elif command -v code >/dev/null 2>&1; then
    code -w "$f"
  elif command -v nano >/dev/null 2>&1; then
    nano "$f"
  elif [[ "$(uname)" == "Darwin" ]]; then
    # -W waits until the app is closed; -t opens in default text editor
    open -W -t "$f"
  else
    echo "No editor detected; set $VISUAL or $EDITOR, or install 'code'." >&2
    exit 1
  fi
}

# Open editor unless --no-edit
if ! $no_edit; then
  open_editor "$post_path"
fi

# Add, commit, push
branch="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)"
(
  cd "$repo_root"
  git add "$post_path"
  git commit -m "Add post: $TITLE"
  git push origin "$branch"
)

echo "Post committed and pushed. GitHub Actions will deploy shortly."