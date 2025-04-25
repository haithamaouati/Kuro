#!/bin/bash

# Author: Haitham Aouati
# GitHub: github.com/haithamaouati

# Text format
normal="\e[0m"
bold="\e[1m"
result="\e[1;32m"
faint="\e[2m"
underlined="\e[4m"

# Dependencies check
dependencies=(curl jq)
for cmd in "${dependencies[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "Error: '$cmd' is required but not installed. Please install it and try again."
    exit 1
  fi
done

print_banner() {
  clear
  echo -e "${result}$(figlet -f standard "Kuro")${normal}"
  echo -e "Fetch GitHub User Info\n"
  echo -e " Author: Haitham Aouati"
  echo -e " GitHub: ${underlined}github.com/haithamaouati${normal}\n"
}

print_banner

API_URL="https://api.github.com/users"

show_help() {
  echo "Usage: $0 -u <USERNAME> [-r]"
  echo
  echo "Options:"
  echo "  -u, --username   Specify the GitHub username to fetch info (required)"
  echo "  -r, --repo       Fetch all repositories"
  echo -e "  -h, --help       Show this help message\n"
}

# Parse args
FETCH_REPOS=false
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -u|--username)
      if [[ -z "$2" || "$2" == -* ]]; then
        echo -e "Error: Missing username for -u|--username\n"
        show_help
        exit 1
      fi
      USERNAME="$2"
      shift 2
      ;;
    -r|--repo)
      FETCH_REPOS=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown parameter: $1"
      show_help
      exit 1
      ;;
  esac
done

if [[ -z "$USERNAME" ]]; then
  echo -e "Error: username is required.\n"
  show_help
  exit 1
fi

# Call API to get user info
RESPONSE=$(curl -s "${API_URL}/${USERNAME}")

# Check if user exists
if [[ "$(echo "$RESPONSE" | jq -r '.message')" == "Not Found" ]]; then
  echo -e "Error: User '$USERNAME' not found.\n"
  exit 1
fi

# Extract user info (all available fields)
ID=$(echo "$RESPONSE" | jq -r '.id')
LOGIN=$(echo "$RESPONSE" | jq -r '.login')
NAME=$(echo "$RESPONSE" | jq -r '.name')
BIO=$(echo "$RESPONSE" | jq -r '.bio')
LOCATION=$(echo "$RESPONSE" | jq -r '.location')
COMPANY=$(echo "$RESPONSE" | jq -r '.company')
EMAIL=$(echo "$RESPONSE" | jq -r '.email')
BLOG=$(echo "$RESPONSE" | jq -r '.blog')
HIREABLE=$(echo "$RESPONSE" | jq -r '.hireable')
PUBLIC_REPOS=$(echo "$RESPONSE" | jq -r '.public_repos')
PRIVATE_REPOS=$(echo "$RESPONSE" | jq -r '.total_private_repos')
FOLLOWERS=$(echo "$RESPONSE" | jq -r '.followers')
FOLLOWING=$(echo "$RESPONSE" | jq -r '.following')
AVATAR_URL=$(echo "$RESPONSE" | jq -r '.avatar_url')
CREATED_AT=$(echo "$RESPONSE" | jq -r '.created_at')
UPDATED_AT=$(echo "$RESPONSE" | jq -r '.updated_at')
TYPE=$(echo "$RESPONSE" | jq -r '.type')
PUBLIC_GISTS=$(echo "$RESPONSE" | jq -r '.public_gists')
SUSPENDED_AT=$(echo "$RESPONSE" | jq -r '.suspended_at // "N/A"')
PLAN_NAME=$(echo "$RESPONSE" | jq -r '.plan.name')
PLAN_SPACE=$(echo "$RESPONSE" | jq -r '.plan.space')
PLAN_COLLABORATORS=$(echo "$RESPONSE" | jq -r '.plan.collaborators')
PLAN_PRIVATE_REPOS=$(echo "$RESPONSE" | jq -r '.plan.private_repos')

# Output basic user info
echo -e "Fetching GitHub User Info for: ${result}$USERNAME${normal}\n"
echo -e "ID:${result} $ID${normal}"
echo -e "Username:${result} $LOGIN${normal}"
echo -e "Name:${result} $NAME${normal}"
echo -e "Bio:${result} $BIO${normal}"
echo -e "Location:${result} $LOCATION${normal}"
echo -e "Company:${result} $COMPANY${normal}"
echo -e "Email:${result} $EMAIL${normal}"
echo -e "Blog:${result} $BLOG${normal}"
echo -e "Hireable:${result} $HIREABLE${normal}"
echo -e "Public Repositories:${result} $PUBLIC_REPOS${normal}"
echo -e "Private Repositories:${result} $PRIVATE_REPOS${normal}"
echo -e "Followers:${result} $FOLLOWERS${normal}"
echo -e "Following:${result} $FOLLOWING${normal}"
echo -e "Avatar URL:${result} $AVATAR_URL${normal}"
echo -e "Created At:${result} $CREATED_AT${normal}"
echo -e "Last Updated At:${result} $UPDATED_AT${normal}"
echo -e "Account Type:${result} $TYPE${normal}"
echo -e "Public Gists:${result} $PUBLIC_GISTS${normal}"
echo -e "Suspended At:${result} $SUSPENDED_AT${normal}"
echo -e "Plan Name:${result} $PLAN_NAME${normal}"
echo -e "Plan Space (MB):${result} $PLAN_SPACE${normal}"
echo -e "Plan Collaborators:${result} $PLAN_COLLABORATORS${normal}"
echo -e "Plan Private Repos:${result} $PLAN_PRIVATE_REPOS${normal}\n"

# Fetch repositories if the -r or --repo flag is set
if $FETCH_REPOS; then
  echo -e "Fetching repositories for user ${result}$USERNAME${normal}\n"
  
  REPO_URLS=$(curl -s "${API_URL}/${USERNAME}/repos?per_page=100" | jq -r '.[].html_url')

  if [[ -z "$REPO_URLS" ]]; then
    echo -e "No repositories found for this user.\n"
  else
    echo -e "Repositories:"
    COUNTER=1
    echo "$REPO_URLS" | while read -r repo; do
      echo -e "${normal}$(printf "%2d" "$COUNTER"):${result} $repo${normal}"
      ((COUNTER++))
    done
  fi
fi
