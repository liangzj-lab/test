#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH="$(git branch --show-current)"
  if [ -n "$BRANCH" ] && git remote get-url origin >/dev/null 2>&1; then
    if ! git diff --quiet || ! git diff --cached --quiet; then
      echo "Local git changes detected. Commit or stash them before auto-updating." >&2
      exit 1
    fi

    echo "Checking GitHub updates for origin/$BRANCH..."
    git fetch origin "$BRANCH"

    LOCAL_COMMIT="$(git rev-parse "$BRANCH")"
    REMOTE_COMMIT="$(git rev-parse "origin/$BRANCH")"

    if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
      echo "Remote updates found. Pulling latest code and model files..."
      git pull --ff-only origin "$BRANCH"
    else
      echo "No remote updates found."
    fi
  else
    echo "Git remote or branch is not configured. Skipping auto-update."
  fi
else
  echo "Git is not available or this directory is not a git worktree. Skipping auto-update."
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed or not available in PATH." >&2
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "Docker Compose is not installed. Install Docker Compose v2 or docker-compose." >&2
  exit 1
fi

if [ ! -f "models/mnist_cnn.pt" ]; then
  echo "Model file not found: models/mnist_cnn.pt" >&2
  exit 1
fi

$COMPOSE up -d --build --force-recreate

echo "MNIST service is starting."
echo "Health check: curl http://127.0.0.1:8000/health"
echo "API docs:     http://127.0.0.1:8000/docs"
