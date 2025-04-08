ARG VARIANT=22.14.0-bookworm
FROM docker.io/library/node:${VARIANT}

ENTRYPOINT ["/bin/bash", "-c", "mkdir -p /logs && echo \"CUSTOM_DEVCONTAINER: workflow-test-container\" > /logs/devcontainer.log && exec \"$@\"", "--"]
