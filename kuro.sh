#!/usr/bin/env bash
# kuro - GitHub profile & repository fetcher for Termux
# Deps: curl, jq, column (util-linux), git (only for --update)

set -u
set -o pipefail

readonly VERSION="1.0.0"
readonly PROG="kuro"
readonly API="https://api.github.com/users"
readonly REPO_URL="https://github.com/haithamaouati/kuro"   # used by --update hints
readonly PER_PAGE=100                                        # GitHub's max page size
readonly MAX_PAGES=30                                        # safety cap on pagination

# Exit codes
readonly EX_USAGE=1 EX_DEPS=2 EX_NET=3 EX_HTTP=4 EX_RATE=5 EX_JSON=6 EX_FILE=7 EX_UPDATE=8

# Runtime state
USERNAME=""
OPT_REPO=0
OPT_HELP=0
OPT_VERSION=0
OPT_UPDATE=0
OPT_JSON=0
USER_JSON=""
REPOS_JSON="[]"
HTTP_BODY=""
HTTP_CODE=""

# ---------- helpers ----------

info() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }

# die <exit-code> <message...>: print plain error to stderr and exit
die() {
  local code=$1; shift
  printf 'Error: %s\n' "$*" >&2
  exit "$code"
}

# Clean exit on Ctrl+C
trap 'printf "\n" >&2; exit 130' INT

# ---------- UI ----------

show_banner() {
  [[ -t 1 ]] && clear
  cat <<'EOF'
 __  __
/\ \/\ \
\ \ \/'/'    __  __   _ __    ___
 \ \ , <    /\ \/\ \ /\`'__\ / __`\
  \ \ \\`\  \ \ \_\ \\ \ \/ /\ \L\ \
   \ \_\ \_\ \ \____/ \ \_\ \ \____/
    \/_/\/_/  \/___/   \/_/  \/___/
EOF
  printf '\n'
  printf ' GitHub profile and repository fetcher\n\n'
  printf ' Author: Haitham Aouati\n'
  # Underline the URL only on a terminal, so piped output stays clean
  if [[ -t 1 ]]; then
    printf ' GitHub: \e[4mhttps://github.com/haithamaouati\e[0m\n\n'
  else
    printf ' GitHub: https://github.com/haithamaouati\n\n'
  fi
}

show_help() {
  cat <<'EOF'
USAGE:
  kuro -u <username> [-r] [--json]
  kuro --update
  kuro -h | -v

OPTIONS:
  -h, --help                  Show this help menu and exit
  -u, --username <username>   GitHub username to fetch
  -r, --repo                  List the user's public repositories
  -v, --version               Print the version number and exit
      --update                Update kuro from GitHub using git
      --json                  Save fetched data to ./<username>.json
                              (user data; includes repos when -r is set)

EXAMPLES:
  kuro -u haithamaouati
  kuro -u haithamaouati -r
  kuro --username haithamaouati --repo --json
  kuro --update

ENVIRONMENT:
  GITHUB_TOKEN                Optional token to raise the API rate limit
EOF
}

# ---------- checks ----------

# check_deps [extra tools...]: verify required binaries exist (silent when all present)
check_deps() {
  local -a missing=() pkgs=()
  local tool
  for tool in curl jq column "$@"; do
    command -v "$tool" >/dev/null 2>&1 && continue
    missing+=("$tool")
    # Map binary to Termux package name (column ships in util-linux)
    case $tool in
      column) pkgs+=("util-linux") ;;
      *)      pkgs+=("$tool") ;;
    esac
  done
  if ((${#missing[@]} > 0)); then
    printf 'Error: missing required tool(s): %s\n' "${missing[*]}" >&2
    printf 'Install with: pkg install %s\n' "${pkgs[*]}" >&2
    exit "$EX_DEPS"
  fi
}

# need_arg <flag> <value>: ensure an option has a value (not empty / not another flag)
need_arg() {
  if [[ -z ${2-} || ${2-} == -* ]]; then
    die "$EX_USAGE" "option '$1' requires an argument. See: $PROG --help"
  fi
}

parse_args() {
  while (($#)); do
    case $1 in
      -h|--help)      OPT_HELP=1 ;;
      -v|--version)   OPT_VERSION=1 ;;
      -r|--repo)      OPT_REPO=1 ;;
      --update)       OPT_UPDATE=1 ;;
      --json)         OPT_JSON=1 ;;
      -u|--username)  need_arg "$1" "${2-}"; USERNAME=$2; shift ;;
      --username=*)   USERNAME=${1#*=} ;;
      *)              die "$EX_USAGE" "unknown option: $1. See: $PROG --help" ;;
    esac
    shift
  done
}

validate_args() {
  # GitHub usernames: alphanumeric or hyphens, max 39 chars, no leading/trailing hyphen
  local re='^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$'
  [[ -n $USERNAME ]] || die "$EX_USAGE" "missing username. Use -u <username>."
  [[ $USERNAME =~ $re ]] || die "$EX_USAGE" "invalid GitHub username: '$USERNAME'"
}

# ---------- HTTP ----------

# http_get <url>: sets globals HTTP_BODY and HTTP_CODE (call directly, not in a subshell)
http_get() {
  local url=$1 resp rc
  local -a hdr=(
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2022-11-28"
    -H "User-Agent: $PROG/$VERSION"
  )
  # Optional auth to avoid the low anonymous rate limit
  [[ -n ${GITHUB_TOKEN:-} ]] && hdr+=(-H "Authorization: Bearer $GITHUB_TOKEN")

  # -w appends the status code on its own last line; body stays intact above it
  resp=$(curl -s --connect-timeout 10 --max-time 30 "${hdr[@]}" -w $'\n%{http_code}' "$url")
  rc=$?
  ((rc == 0)) || die "$EX_NET" "connection failed (curl exit $rc). Check your internet connection."

  HTTP_CODE=${resp##*$'\n'}
  HTTP_BODY=${resp%$'\n'*}
}

# check_http <label>: map HTTP status to a meaningful error and exit code
check_http() {
  local what=$1 msg
  msg=$(jq -r '.message? // empty' <<<"$HTTP_BODY" 2>/dev/null)
  case $HTTP_CODE in
    2??) return 0 ;;
    404) die "$EX_HTTP" "$what not found (HTTP 404)." ;;
    401) die "$EX_HTTP" "unauthorized (HTTP 401). Check your GITHUB_TOKEN." ;;
    403|429)
      die "$EX_RATE" "forbidden or rate limit exceeded (HTTP $HTTP_CODE).${msg:+ $msg} Wait a while or set GITHUB_TOKEN." ;;
    *)   die "$EX_HTTP" "unexpected HTTP $HTTP_CODE${msg:+: $msg}" ;;
  esac
}

# ---------- fetch ----------

fetch_user() {
  info "Fetching profile for $USERNAME..."
  http_get "$API/$USERNAME"
  check_http "user '$USERNAME'"
  # Make sure we really got a user object back
  jq -e 'type == "object" and has("login")' >/dev/null 2>&1 <<<"$HTTP_BODY" \
    || die "$EX_JSON" "malformed JSON received for user profile."
  USER_JSON=$HTTP_BODY
}

fetch_repos() {
  local page=1 count all='[]'
  info "Fetching repositories for $USERNAME..."
  while ((page <= MAX_PAGES)); do
    http_get "$API/$USERNAME/repos?per_page=$PER_PAGE&page=$page&sort=pushed"
    check_http "repositories of '$USERNAME'"
    jq -e 'type == "array"' >/dev/null 2>&1 <<<"$HTTP_BODY" \
      || die "$EX_JSON" "malformed JSON received for repositories (page $page)."

    # Merge via stdin (large payloads can exceed argv limits)
    all=$(printf '%s\n%s\n' "$all" "$HTTP_BODY" | jq -cs '.[0] + .[1]') \
      || die "$EX_JSON" "failed to merge repository pages."

    count=$(jq 'length' <<<"$HTTP_BODY")
    ((count < PER_PAGE)) && break   # last page reached
    ((page++))
  done
  ((page > MAX_PAGES)) && warn "stopped at $MAX_PAGES pages; list may be incomplete."
  REPOS_JSON=$all
}

# ---------- output ----------

print_user() {
  printf '\nPROFILE\n'
  jq -r '
    # Normalize: null/empty -> "N/A", flatten control whitespace
    def s: if . == null or . == "" then "N/A"
           else (tostring | gsub("[\n\r\t]+"; " ")) end;
    [
      ["Login",     .login],
      ["Name",      .name],
      ["ID",        .id],
      ["Type",      .type],
      ["Bio",       .bio],
      ["Company",   .company],
      ["Location",  .location],
      ["Blog",      .blog],
      ["Email",     .email],
      ["Twitter",   .twitter_username],
      ["Repos",     .public_repos],
      ["Gists",     .public_gists],
      ["Followers", .followers],
      ["Following", .following],
      ["Created",   (.created_at // "")[:10]],
      ["Updated",   (.updated_at // "")[:10]],
      ["URL",       .html_url]
    ] | .[] | [.[0], (.[1] | s)] | @tsv' <<<"$USER_JSON" \
    | column -t -s $'\t' | sed 's/^/  /'
}

print_repos() {
  local total
  total=$(jq 'length' <<<"$REPOS_JSON")
  printf '\nREPOSITORIES (%s)\n' "$total"
  if ((total == 0)); then
    printf '  No public repositories.\n'
    return
  fi
  jq -r '
    def s: if . == null or . == "" then "-"
           else (tostring | gsub("[\n\r\t]+"; " ")) end;
    ["NAME","STARS","FORKS","LANG","PUSHED"],
    (sort_by(.pushed_at) | reverse | .[]
      | [(.name | s), .stargazers_count, .forks_count, (.language | s),
         ((.pushed_at // "")[:10] | s)])
    | @tsv' <<<"$REPOS_JSON" \
    | column -t -s $'\t' | sed 's/^/  /'
}

# save_json: write fetched data to ./<username>.json (pretty-printed)
save_json() {
  local file="./$USERNAME.json"
  [[ -w . ]] || die "$EX_FILE" "current directory is not writable."
  [[ -e $file && ! -w $file ]] && die "$EX_FILE" "file is not writable: $file"

  if ((OPT_REPO)); then
    # With -r, keep both user and repos in one document
    printf '%s\n%s\n' "$USER_JSON" "$REPOS_JSON" \
      | jq -s '{user: .[0], repos: .[1]}' > "$file" 2>/dev/null \
      || die "$EX_FILE" "failed to write $file"
  else
    printf '%s\n' "$USER_JSON" | jq '.' > "$file" 2>/dev/null \
      || die "$EX_FILE" "failed to write $file"
  fi
  printf '\nSaved JSON to %s\n' "$file"
}

# ---------- update ----------

update_script() {
  local src dir before after
  # Resolve symlinks so a link in $PREFIX/bin still finds the git clone
  src=$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null) || src=${BASH_SOURCE[0]}
  dir=$(dirname -- "$src")

  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "$EX_UPDATE" "not running from a git clone. Install with: git clone $REPO_URL"

  # Refuse to pull over local edits
  if [[ -n $(git -C "$dir" status --porcelain --untracked-files=no) ]]; then
    die "$EX_UPDATE" "local changes detected in $dir. Commit or stash them first."
  fi

  info "Updating from $(git -C "$dir" remote get-url origin 2>/dev/null || echo "$REPO_URL")..."
  before=$(git -C "$dir" rev-parse HEAD)
  git -C "$dir" pull --ff-only --quiet \
    || die "$EX_UPDATE" "git pull failed (network issue or diverged branch)."
  after=$(git -C "$dir" rev-parse HEAD)

  chmod +x "$src" 2>/dev/null
  if [[ $before == "$after" ]]; then
    info "Already up to date."
  else
    info "Updated ${before:0:7} to ${after:0:7}."
  fi
}

# ---------- main ----------

main() {
  # No arguments: show help as a usage error
  if (($# == 0)); then
    show_banner
    show_help
    exit "$EX_USAGE"
  fi

  parse_args "$@"

  # --version prints the raw number only, without clearing the screen
  if ((OPT_VERSION)); then
    printf '%s\n' "$VERSION"
    exit 0
  fi

  show_banner

  if ((OPT_HELP)); then
    show_help
    exit 0
  fi

  if ((OPT_UPDATE)); then
    check_deps git
    update_script
    exit 0
  fi

  check_deps
  validate_args

  fetch_user
  ((OPT_REPO)) && fetch_repos

  print_user
  ((OPT_REPO)) && print_repos
  ((OPT_JSON)) && save_json
  exit 0
}

main "$@"
