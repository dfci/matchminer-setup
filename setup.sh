#!/usr/bin/env bash
set -euo pipefail


if test -z "${BASH_VERSION:-}"
then
  echo 'this script must be run using bash'
  exit 1
fi

if ! which git >/dev/null
then
  echo 'this script requires git'
  exit 1
fi

declare -a GIT_REPOS=(
  'https://github.com/dfci/matchminer-setup.gitxx' # FIXME
  'git@github.com:dfci/matchminer-setup.git'
)

export GIT_TERMINAL_PROMPT=0

# You can set the variable MATCHMINER_GIT_REMOTE_REF to check out a different branch:
GIT_REMOTE_REF="${MATCHMINER_GIT_REMOTE_REF:-origin/main}"

# First, see if setup.sh is being run from a clone of the "matchminer-setup" repository:
LOCAL_SETUP_DIR=""
if test -n "${BASH_SOURCE[0]:-}"
then
  SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
  pushd $SCRIPT_DIR >/dev/null
  if git remote >/dev/null 2>/dev/null
  then
    LOCAL_GIT_REPOS="$(git remote | xargs -I'{}' git remote get-url --all '{}')"
    while IFS= read -r LOCAL_REPO; do
      for REMOTE_REPO in "${GIT_REPOS[@]}"
      do
        if test  "$LOCAL_REPO" '=' "$REMOTE_REPO"
        then
          LOCAL_SETUP_DIR="$SCRIPT_DIR"
        fi
      done
    done <<< "$LOCAL_GIT_REPOS"
  fi
  popd >/dev/null
fi

# If so, just run the "install" script in that local clone:
if test -n "$LOCAL_SETUP_DIR"
then
  echo "Entering local copy of matchminer-setup repository at: $LOCAL_SETUP_DIR"
  cd "$LOCAL_SETUP_DIR"
  echo 'Running install script'
  exec ./install
fi

# Otherwise, we try to clone the repository from GitHub, using various protocols:

echo "Cloning matchminer-setup repository"
CLONE_DIR=""
for REMOTE_REPO in "${GIT_REPOS[@]}"
do
  echo "Attempting to clone from: $REMOTE_REPO"
  TEMP_DIR="$(mktemp -d)"
  echo "Will clone into: $TEMP_DIR"
  CLONE_ATTEMPT_DIR="$TEMP_DIR/matchminer-setup"
  mkdir "$CLONE_ATTEMPT_DIR"
  pushd "$CLONE_ATTEMPT_DIR" > /dev/null
  # This roughly follows https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  git init -q
  git config remote.origin.url "$REMOTE_REPO"
  git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git config core.autocrlf false
  if git fetch --force origin >/dev/null 2>/dev/null
  then
    CLONE_DIR="$CLONE_ATTEMPT_DIR"
    popd > /dev/null
    break
  else
    echo "Clone attempt failed"
    rm -rf "$TEMP_DIR"
    popd > /dev/null
  fi
done
if test -z "$CLONE_DIR"
then
  echo "Failed to clone repository!"
  exit 1
fi


# If the clone succeeds, we can run the install script:
echo "Entering remote copy of matchminer-setup repository at: $CLONE_DIR"
cd "$CLONE_DIR"
echo "Checking out reference: $GIT_REMOTE_REF"
git reset --quiet --hard "$GIT_REMOTE_REF"
echo "Running install script..."
exec ./install