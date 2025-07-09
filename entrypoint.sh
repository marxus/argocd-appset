#!/bin/bash
(
  cd /appset/repo
  touch .gitkeep
  while true; do
    rm -rf .git
    git init
    git add .gitkeep
    git commit -m "$(date)"
    sleep "$APPSET_CMP_REFRESH_INTERVAL"
  done
) &

/appset/servegit.go &

/var/run/argocd/argocd-cmp-server
