#!/usr/bin/env bash
set -euo pipefail

REQUIRED_NAME="gitbyul"
REQUIRED_EMAIL="gitbyul@gmail.com"
HEADER_PATTERN='^(feat|fix|docs|chore|refactor|test|ci)\([a-z][a-z0-9-]*\): .+$'

print_policy() {
  cat <<'POLICY'
Required git identity:
  gitbyul <gitbyul@gmail.com>

Required commit message:
  type(scope): 한글 제목

  - 한글 bullet body

Allowed types:
  feat, fix, docs, chore, refactor, test, ci

Required rules:
  - type is required and must be one of the allowed types.
  - scope is required and must be lowercase kebab-case.
  - subject must include Korean text.
  - body is required.
  - the second line must be empty.
  - every body line must start with "- ".
  - empty lines inside the body are not allowed.
  - author and committer must both be gitbyul <gitbyul@gmail.com>.
POLICY
}

die() {
  echo "git policy failed: $1" >&2
  echo >&2
  print_policy >&2
  exit 1
}

is_zero_sha() {
  case "$1" in
    0000000000000000000000000000000000000000) return 0 ;;
    *) return 1 ;;
  esac
}

check_config_identity() {
  local name
  local email

  name="$(git config --get user.name || true)"
  email="$(git config --get user.email || true)"

  if [ "$name" != "$REQUIRED_NAME" ] || [ "$email" != "$REQUIRED_EMAIL" ]; then
    die "local git config must be '$REQUIRED_NAME <$REQUIRED_EMAIL>' but is '${name:-<empty>} <${email:-empty}>'.
Run:
  git config user.name \"$REQUIRED_NAME\"
  git config user.email \"$REQUIRED_EMAIL\""
  fi
}

clean_message_file() {
  local src="$1"
  local dst="$2"

  awk '
    /^#/ { next }
    {
      lines[++n] = $0
      if ($0 != "") {
        last = n
      }
    }
    END {
      for (i = 1; i <= last; i++) {
        print lines[i]
      }
    }
  ' "$src" > "$dst"
}

validate_message_file() {
  local message_file="$1"
  local label="${2:-commit message}"
  local cleaned
  local line_count
  local header
  local second_line

  cleaned="$(mktemp)"
  clean_message_file "$message_file" "$cleaned"

  line_count="$(awk 'END { print NR + 0 }' "$cleaned")"
  header="$(sed -n '1p' "$cleaned")"
  second_line="$(sed -n '2p' "$cleaned")"

  if [ "$line_count" -lt 3 ]; then
    rm -f "$cleaned"
    die "$label must have a header, one blank separator line, and a bullet body."
  fi

  if ! printf '%s\n' "$header" | grep -Eq "$HEADER_PATTERN"; then
    rm -f "$cleaned"
    die "$label header must match 'type(scope): 한글 제목'. Found: $header"
  fi

  if ! printf '%s\n' "$header" | grep -Eq '[가-힣]'; then
    rm -f "$cleaned"
    die "$label subject must include Korean text. Found: $header"
  fi

  if [ -n "$second_line" ]; then
    rm -f "$cleaned"
    die "$label line 2 must be exactly one blank line."
  fi

  if ! awk '
    NR >= 3 && $0 == "" {
      printf("empty body line at line %d\n", NR) > "/dev/stderr"
      exit 1
    }
    NR >= 3 && $0 !~ /^- .+/ {
      printf("body line %d must start with \"- \"\n", NR) > "/dev/stderr"
      exit 1
    }
  ' "$cleaned"; then
    rm -f "$cleaned"
    die "$label body must be contiguous Korean bullet lines."
  fi

  if ! sed -n '3,$p' "$cleaned" | grep -Eq '[가-힣]'; then
    rm -f "$cleaned"
    die "$label body must include Korean text."
  fi

  rm -f "$cleaned"
}

validate_identity_values() {
  local label="$1"
  local author_name="$2"
  local author_email="$3"
  local committer_name="$4"
  local committer_email="$5"

  if [ "$author_name" != "$REQUIRED_NAME" ] || [ "$author_email" != "$REQUIRED_EMAIL" ]; then
    die "$label author must be '$REQUIRED_NAME <$REQUIRED_EMAIL>' but is '$author_name <$author_email>'."
  fi

  if [ "$committer_name" != "$REQUIRED_NAME" ] || [ "$committer_email" != "$REQUIRED_EMAIL" ]; then
    die "$label committer must be '$REQUIRED_NAME <$REQUIRED_EMAIL>' but is '$committer_name <$committer_email>'."
  fi
}

validate_commit() {
  local sha="$1"
  local message
  local author_name
  local author_email
  local committer_name
  local committer_email
  local short_sha

  short_sha="$(git rev-parse --short "$sha")"
  author_name="$(git show -s --format='%an' "$sha")"
  author_email="$(git show -s --format='%ae' "$sha")"
  committer_name="$(git show -s --format='%cn' "$sha")"
  committer_email="$(git show -s --format='%ce' "$sha")"

  validate_identity_values "commit $short_sha" "$author_name" "$author_email" "$committer_name" "$committer_email"

  message="$(mktemp)"
  git show -s --format='%B' "$sha" > "$message"
  validate_message_file "$message" "commit $short_sha message"
  rm -f "$message"
}

validate_range() {
  local base="$1"
  local head="$2"
  local commits
  local sha

  if is_zero_sha "$head"; then
    die "head SHA is empty."
  fi

  if is_zero_sha "$base"; then
    commits="$(git rev-list --reverse "$head")"
  else
    commits="$(git rev-list --reverse "$base..$head")"
  fi

  if [ -z "$commits" ]; then
    echo "No commits to validate."
    return 0
  fi

  while IFS= read -r sha; do
    [ -n "$sha" ] || continue
    validate_commit "$sha"
  done <<EOF
$commits
EOF
}

case "${1:-}" in
  --check-config)
    check_config_identity
    ;;
  --message-file)
    [ "${2:-}" ] || die "missing commit message file."
    check_config_identity
    validate_message_file "$2"
    ;;
  --commit)
    [ "${2:-}" ] || die "missing commit SHA."
    validate_commit "$2"
    ;;
  --range)
    [ "${2:-}" ] || die "missing base SHA."
    [ "${3:-}" ] || die "missing head SHA."
    validate_range "$2" "$3"
    ;;
  --help|-h)
    print_policy
    ;;
  *)
    echo "Usage:" >&2
    echo "  $0 --check-config" >&2
    echo "  $0 --message-file <path>" >&2
    echo "  $0 --commit <sha>" >&2
    echo "  $0 --range <base-sha> <head-sha>" >&2
    exit 2
    ;;
esac
