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
tmpfile="$(mktemp "${PROJECT_DIRECTORY}/temp.json.XXXXXX")"

# Update the version in package.json
if jq -e .version "$PROJECT_DIRECTORY/package.json" > /dev/null; then
    # If version exists, update it
    jq ".version = \"$VERSION\"" "$PROJECT_DIRECTORY/package.json" > "$tmpfile" && mv "$tmpfile" "$PROJECT_DIRECTORY/package.json"
else
    # If version doesn't exist, add it
    jq ". + {\"version\": \"$VERSION\"}" "$PROJECT_DIRECTORY/package.json" > "$tmpfile" && mv "$tmpfile" "$PROJECT_DIRECTORY/package.json"
fi

# Create the npm package tarball
echo "Creating npm package..."
echo "[DEBUG] Running npm pack from: $(pwd)"
npm pack

# Publish to the npm registry (local or public)
echo "Publishing npm package to registry..."
npm publish --registry "$PACKAGE_REGISTRY" --access public
