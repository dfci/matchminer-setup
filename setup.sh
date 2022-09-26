#!/usr/bin/env bash
set -euo pipefail

# Sanity check: this must be run in bash
if test -z "${BASH_VERSION:-}"
then
  echo 'this script must be run using bash'
  exit 1
fi

# Sanity check: git is required
if ! which git >/dev/null
then
  echo 'this script requires git'
  exit 1
fi

# The repositories that we will try to pull from
declare -a GIT_REPOS=(
  'https://github.com/dfci/matchminer-setup.git'
  'git@github.com:dfci/matchminer-setup.git'
)

# Set the remote ref to check out
# You can set the environment variable MATCHMINER_GIT_REMOTE_REF to check out a different branch
GIT_REMOTE_REF="${MATCHMINER_GIT_REMOTE_REF:-origin/main}"

# Set the destination where we will put the repository
# You can set the environment variable MATCHMINER_SETUP_DIR to use somewhere else
DEST_DIR="${MATCHMINER_SETUP_DIR:-${HOME:-~}/.matchminer-setup}"

# See if we are *already* in a clone of the "matchminer-setup" repository:
LOCAL_SETUP_DIR=""
if test -n "${BASH_SOURCE[0]:-}"
then
  pushd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null
  # Ensure we are in a git repository:
  if git rev-parse --is-inside-work-tree >/dev/null 2>/dev/null
  then
    # Get list of remote URLs:
    LOCAL_GIT_REPOS="$(git remote | xargs -I'{}' git remote get-url --all '{}')"
    # For each one, see if it matches one of the $GIT_REPOS:
    while IFS= read -r LOCAL_REPO; do
      for REMOTE_REPO in "${GIT_REPOS[@]}"
      do
        if test "$LOCAL_REPO" = "$REMOTE_REPO"
        then
          # If so, set LOCAL_SETUP_DIR:
          LOCAL_SETUP_DIR="$(pwd)"
          break
        fi
      done
    done <<< "$LOCAL_GIT_REPOS"
  fi
  popd >/dev/null
fi

# If we are already in a local copy, just run the "install" script in that local clone:
if test -n "$LOCAL_SETUP_DIR"
then
  echo "Using local copy of matchminer-setup repository at: $LOCAL_SETUP_DIR"
  cd "$LOCAL_SETUP_DIR"
  echo 'Running install script'
  exec ./install
fi

# Otherwise, we'll need to clone the repository from GitHub into $DEST_DIR:
echo "Cloning matchminer-setup repository into: $DEST_DIR"
mkdir -p "$DEST_DIR"
pushd "$DEST_DIR" > /dev/null

# Set up the git repository
# The below roughly follows: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
# The advantage of this approach is that it works even if $DEST_DIR already exists
git init -q
git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git config core.autocrlf false

# Attempt to clone from each URL:
CLONE_DIR=""
for REMOTE_REPO in "${GIT_REPOS[@]}"
do
  echo "Attempting to clone from: $REMOTE_REPO"
  git config remote.origin.url "$REMOTE_REPO"
  # Attempt to fetch:
  if GIT_TERMINAL_PROMPT=0 git fetch --force origin >/dev/null 2>/dev/null
  then
    # If it succeeds, we have a $CLONE_DIR and can break the loop
    CLONE_DIR="$DEST_DIR"
    break
  else
    # Otherwise, continue trying other protocols
    echo "Clone attempt failed"
  fi
done

# Finish up after clone successful:
popd > /dev/null
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