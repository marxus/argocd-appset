FROM alpine:3.22 AS download
ARG TARGETARCH
RUN apk add --no-cache curl
WORKDIR /cmp

# Download and extract all tools
RUN true \
    && curl -L "https://github.com/traefik/yaegi/releases/download/v0.16.1/yaegi_v0.16.1_linux_$TARGETARCH.tar.gz" | tar -xvz \
    && curl -L "https://github.com/mikefarah/yq/releases/download/v4.44.1/yq_linux_$TARGETARCH.tar.gz" | tar -xz && mv "yq_linux_$TARGETARCH" yq

# Move all tools to /cmp/bin and make them executable
RUN mkdir bin && mv yaegi yq bin

FROM alpine:3.22

# Setup environment as required by ArgoCD
COPY plugin.yaml /home/argocd/cmp-server/config/
ENV HOME=/home/argocd
RUN chown 999 /home/argocd

# Copy tools from the download stage and install more tools via package manager
# `gcompat` is needed for compatibility with glibc-based binaries (on alpine based images)
RUN apk add --no-cache gcompat bash git-daemon
COPY --from=download /cmp/bin /cmp/bin
COPY entrypoint.sh servegit.go /cmp/bin/
ENV PATH="/cmp/bin:$PATH"
WORKDIR /cmp
RUN chmod +x bin/*

# AppSet runtime setup
# `argocd` symlinks to existing binary, when called as `argocd` it performs as the "cli" and not as the "cmp-server"
RUN ln -s /var/run/argocd/argocd-cmp-server bin/argocd

# `repo` and `list` are directories used during runtime
RUN mkdir repo list && chown 999 repo list

# Git client config needed for "fake" git repository during runtime
RUN true \
    && git config --global user.email - \
    && git config --global user.name appset \
    && git config --global init.defaultBranch master

USER 999
ENTRYPOINT ["entrypoint.sh"]
