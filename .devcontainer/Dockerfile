# 1. List of all available tags: https://hub.docker.com/_/node
# 2. Debian releases: https://wiki.debian.org/DebianReleases
# 3. Information on Node versions: https://nodejs.org/en/about/previous-releases

# To find an image tag from #1:
# - Choose latest long-term-support (LTS) version of Debian from #2
# - Select the latest node version from #3 that exists in #1
FROM docker.io/library/node:24.13.0-bookworm

RUN apt-get update && apt-get install -y \
    bats \
    git \
    openssh-client \
    wget && \
    # The version of yq available in apt is very outdated so it must be manually installed
    # To find newer versions visit: https://github.com/mikefarah/yq/releases/
    wget https://github.com/mikefarah/yq/releases/download/v4.49.2/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
