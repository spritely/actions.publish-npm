FROM docker.io/library/node:22.22.0-bookworm

ENTRYPOINT ["/bin/bash", "-c", "mkdir -p /logs && echo \"CUSTOM_DEVCONTAINER: workflow-test-container\" > /logs/devcontainer.log && exec \"$@\"", "--"]
