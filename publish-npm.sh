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

# Update the version in package.json using sed
if grep -q '"version"' package.json; then
    # Update existing "version" field
    sed -i.bak -E "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"${VERSION}\"/" package.json
else
    # Add version field after the first opening brace
    sed -i.bak "0,/^{/s//{\n  \"version\": \"${VERSION}\",/" package.json
fi

# Remove http(s):// prefix from registry name for assigning npm credentials config
PACKAGE_REGISTRY_HOST=$(echo "$PACKAGE_REGISTRY" | sed -E 's|^https?://||' | sed -E 's|/.*$||')

# Configure npm registry and credentials for publishing
npm set registry "$PACKAGE_REGISTRY"
echo "//${PACKAGE_REGISTRY_HOST}/:_authToken=${PACKAGE_REGISTRY_TOKEN}" >> ~/.npmrc

# Create the npm package tarball
echo "Creating npm package..."
echo "[DEBUG] Running npm pack from: $(pwd)"
npm pack

# Publish to the npm registry (local or public)
echo "Publishing npm package to registry..."

# Extract prerelease tag from semantic version (e.g., "beta" from "1.0.0-beta.1+build.123")
if [[ "$VERSION" =~ -([a-zA-Z]+) ]]; then
    TAG="${BASH_REMATCH[1]}"
    echo "Detected prerelease version, publishing with --tag $TAG"
    npm publish --registry "$PACKAGE_REGISTRY" --tag "$TAG"
else
    npm publish --registry "$PACKAGE_REGISTRY"
fi
