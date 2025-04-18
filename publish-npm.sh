#!/usr/bin/env bash
# Exit immediately if any command including those in a piped sequence exits with a non-zero status
set -euo pipefail

# Check if package.json exists
if [ ! -f "${PROJECT_DIRECTORY}/package.json" ]; then
  echo "Error: Package.json file '${PROJECT_DIRECTORY}/package.json' not found" >&2
  exit 1
fi

cd "$PROJECT_DIRECTORY" || {
    echo "Failed to cd into $PROJECT_DIRECTORY"
    exit 1
}

echo "Updating version in ${PROJECT_DIRECTORY} to ${VERSION}"

# Create a temp file inside the project directory
tmpfile="$(mktemp "temp.json.XXXXXX")"

# Update the version in package.json
if jq -e .version "package.json" > /dev/null; then
    # If version exists, update it
    jq ".version = \"$VERSION\"" "package.json" > "$tmpfile" && mv "$tmpfile" "package.json"
else
    # If version doesn't exist, add it
    jq ". + {\"version\": \"$VERSION\"}" "package.json" > "$tmpfile" && mv "$tmpfile" "package.json"
fi


# Remove http(s):// prefix from registry name for assigning npm credentials config
PACKAGE_REGISTRY_HOST=$(echo "$PACKAGE_REGISTRY" | sed -E 's|^https?://||' | sed -E 's|/.*$||')

# Configure npm registry and credentials for publishing
npm set registry "$PACKAGE_REGISTRY"
npm config set "//$PACKAGE_REGISTRY_HOST/:_auth" "$(echo -n "${PACKAGE_REGISTRY_USERNAME}:${PACKAGE_REGISTRY_PASSWORD}" | base64)"

# Create the npm package tarball
echo "Creating npm package..."
echo "[DEBUG] Running npm pack from: $(pwd)"
npm pack

# Publish to the npm registry (local or public)
echo "Publishing npm package to registry..."
npm publish --registry "$PACKAGE_REGISTRY"
