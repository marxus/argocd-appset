FROM alpine:3.20 AS build
ARG TARGETARCH
RUN apk add --no-cache curl
COPY entrypoint.sh servegit.go /appset/
RUN chmod +x /appset/* \
&&  cd /tmp \
&&  mkdir repo \ 
&&  ln -s /var/run/argocd/argocd-cmp-server argocd \
&&  curl -L "https://github.com/traefik/yaegi/releases/download/v0.16.1/yaegi_v0.16.1_linux_$TARGETARCH.tar.gz" | tar -xvz \
&&  curl -L "https://github.com/mikefarah/yq/releases/download/v4.44.1/yq_linux_$TARGETARCH.tar.gz" | tar -xz && mv "yq_linux_$TARGETARCH" yq \
&&  cp -r repo argocd yaegi yq /appset

FROM alpine:3.20
COPY --from=build /appset /appset
ENV PATH="/appset:$PATH" HOME=/home/argocd
RUN apk add --no-cache bash gcompat git-daemon
COPY plugin.yaml /home/argocd/cmp-server/config/
RUN chown 999 /appset/repo /home/argocd \
&&  git config --global user.email - \
&&  git config --global user.name appset-cmp \
&&  git config --global init.defaultBranch master
ENTRYPOINT ["/appset/entrypoint.sh"]