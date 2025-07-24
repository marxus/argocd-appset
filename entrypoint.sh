#!/bin/bash
if [ "$1" == "servegit" ]; then
  (
    cd /appset/repo
    touch .gitkeep
    while true; do
      rm -rf .git
      git init
      git add .gitkeep
      git commit -m "$(date)"
      sleep "$APPSET_REFRESH_INTERVAL"
    done
  ) &

  exec /appset/servegit.go
fi

(
  cd /appset/list
  argocd --core app list -o yaml |
    yq '.[] | select(.spec.source.plugin.name == "appset").metadata | .namespace + ":" + .name' |
    xargs -r touch
  while true; do
    for FILENAME in $(ls -1); do
      APPNAME="$(echo "$FILENAME" | tr : /)"
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Refreshing $APPNAME"
      timeout -k 30 15 argocd --core app get "$APPNAME" --refresh 1>/dev/null || rm "$FILENAME"
    done
    sleep "$APPSET_REFRESH_INTERVAL"
  done
) &

exec /var/run/argocd/argocd-cmp-server
