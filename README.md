# kuro

A small Bash CLI for Termux (Android) that fetches GitHub user profiles and repositories through the GitHub REST API and prints them as clean, aligned plain text.

- Author: [Haitham Aouati](https://github.com/haithamaouati)

## Features

- Fetch a full GitHub user profile
- List all public repositories, with automatic pagination
- Save the fetched data as `<username>.json`
- Self-update from GitHub with `git`
- Plain text output, with no colors or decorative symbols
- Clear error handling for network failures, 404 (user not found), 403/429 (rate limit), malformed JSON and file write failures
- Optional `GITHUB_TOKEN` support for a higher API rate limit

## Requirements

| Tool | Termux package | Needed for |
| --- | --- | --- |
| `curl` | `curl` | API requests |
| `jq` | `jq` | JSON parsing |
| `column` | `util-linux` | Table alignment |
| `git` | `git` | `--update` only |

## Installation

```bash
pkg install curl jq util-linux git

git clone https://github.com/haithamaouati/kuro
cd kuro
chmod +x kuro
ln -s "$PWD/kuro" "$PREFIX/bin/kuro"
```

Use a symlink rather than copying the file, so `--update` can find the git clone.

## Usage

```text
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
```

### Examples

```bash
kuro -u haithamaouati                      # profile
kuro -u haithamaouati -r                   # profile + repositories
kuro -u haithamaouati --json               # also writes ./haithamaouati.json
kuro --username haithamaouati --repo --json
kuro -v                                    # prints: 1.0.0
kuro --update                              # pull the latest version
```

## Output

Profile fields shown: login, name, ID, type, bio, company, location, blog, email, Twitter, repos, gists, followers, following, created and updated dates, and profile URL. Empty fields display as `N/A`.

With `-r`, repositories are listed in a table, most recently pushed first:

```text
NAME   STARS  FORKS  LANG  PUSHED
...
```

## JSON output

`--json` writes to `./<username>.json` in the current directory:

- Without `-r`: the raw user object.
- With `-r`: `{ "user": { ... }, "repos": [ ... ] }`.

## Rate limits

Unauthenticated requests are limited to 60 per hour. To raise the limit to 5000 per hour, export a personal access token:

```bash
export GITHUB_TOKEN=ghp_xxx
```

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | Usage error (bad or missing arguments) |
| 2 | Missing dependency |
| 3 | Network error |
| 4 | HTTP error (for example 404) |
| 5 | Rate limit or forbidden (403/429) |
| 6 | Malformed JSON |
| 7 | File write failure |
| 8 | Update failure |

## Updating

```bash
kuro --update
```

This runs `git pull --ff-only` in the clone. It refuses to run if you have local changes, and it fails if kuro was not installed from a git clone.

## Author

Haitham Aouati: [github.com/haithamaouati](https://github.com/haithamaouati)
