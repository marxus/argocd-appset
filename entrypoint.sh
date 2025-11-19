#!/bin/bash
# Git server mode
if [ "$1" == "servegit" ]; then
  (
    cd repo
    touch .gitkeep
    # Continuously refresh git repo with new commits
    while true; do
      rm -rf .git
      git init
      git add .gitkeep
      git commit -m "$(date)"
      sleep "$APPSET_REFRESH_INTERVAL"
    done
  ) &

  exec servegit.go
fi

# Default CMP server mode, Track appset applications using a background subshell
(
  cd list
  # Find and track all appset plugin applications
  argocd app list -o yaml |
    yq '.[] | select(.spec.source.plugin.name == "appset").metadata | .namespace + "_" + .name' |
    xargs -r touch
  # Periodically refresh tracked applications
  while true; do
    for FILENAME in $(ls -1); do
      APPNAME="$(echo "$FILENAME" | tr _ /)"
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Refreshing $APPNAME"
      timeout -k 30 15 argocd app get "$APPNAME" --refresh 1>/dev/null || rm "$FILENAME"
    done
    sleep "$APPSET_REFRESH_INTERVAL"
  done
) &

# Start CMP server
exec /var/run/argocd/argocd-cmp-server
