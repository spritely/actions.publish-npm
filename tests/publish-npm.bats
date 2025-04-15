#!/usr/bin/env bats

setup() {
    export TEMP_DIR="$(mktemp -d)"
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../publish-npm.sh"
    export PACKAGE_REGISTRY="http://actions-publish-npm-registry:4873"
    export PACKAGE_AUTH_TOKEN=$(echo -n 'testpassword' | base64)
    cd "$TEMP_DIR"

    create_project() {
        local project_directory="${1:-testproject}"
        local root_path="${2:-${TEMP_DIR}}"

        local full_path="${root_path}/${project_directory}"
        mkdir -p "$full_path" || {
            echo "Failed to create project directory: $full_path" >&2
            return 1
        }

        cd "$full_path"

        npm set registry "$PACKAGE_REGISTRY" > /dev/null 2>&1

        if ! npm init -y > /dev/null 2>&1; then
            echo "npm init failed in $full_path" >&2
            return 1
        fi

        local project_file="${full_path}/package.json"
        if [ ! -f "$project_file" ]; then
            echo "Failed to create package.json in ${full_path}" >&2
            return 1
        fi

        echo "$full_path"
    }

    run_script() {
        export PROJECT_DIRECTORY="$1"
        export VERSION="${2:-1.0.0}"
        local allow_failure="${3:-false}"

        cd "$TEMP_DIR" || {
            echo "FAILED TO cd INTO TEMP_DIR: $TEMP_DIR"
            return 1
        }

        run bash "${SCRIPT_PATH}"

        if [ "$status" -ne 0 ] && [ "$allow_failure" != "true" ]; then
            echo "Script failed with status $status"
            echo "$output"
            return 1
        fi
    }

    assert_package_created() {
        local project_directory="$1"
        local published_version="$2"
        local package_version="${3:-$2}"  # Optional: if different than published

        local package_json="${project_directory}/package.json"
        [ -f "$package_json" ] || {
            echo "package.json not found in $project_directory"
            return 1
        }

        # Check the version in package.json matches expected version
        grep -q "\"version\": \"${package_version}\"" "$package_json" || {
            echo "Expected version ${package_version} not found in package.json"
            return 1
        }

        local name
        name=$(jq -r .name "$package_json")
        if [ -z "$name" ] || [ "$name" = "null" ]; then
            echo "Failed to read package name from package.json"
            return 1
        fi

        npm view "$name" version --registry "$PACKAGE_REGISTRY" | grep -q "$published_version" || {
            echo "Version ${published_version} of ${name} not found in registry"
            return 1
        }
    }
}

teardown() {
    rm -rf "${TEMP_DIR}"
    find /src/tests/verdaccio-storage -type f -name '*.tgz' -exec dirname {} \; | xargs rm -rf
}

@test "publish-npm fails when project package.json file doesn't exist" {
    run_script "NonExistentFolder" "1.0.0" "true"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "publish-npm adds Version tag if none exists" {
    local project_directory
    project_directory=$(create_project)

    local version="1.2.3"
    run_script "$project_directory" "$version"
    assert_package_created "$project_directory" "$version"
}

@test "publish-npm updates existing Version tag" {
    local project_directory
    project_directory=$(create_project)

    local version="3.0.0"
    sed -i "s#\"version\": \"1.0.0\"#\"version\": \"$version\"#" "$project_directory/package.json" || {
        echo "Failed to set initial version in package.json"
        return 1
    }

    run_script "$project_directory" "$version"
    assert_package_created "$project_directory" "$version"
}

@test "publish-npm handles complex semantic versions" {
    local project_directory
    project_directory=$(create_project)

    # npm strips build metadata (+build.123) from version during publish
    local full_version="1.0.0-beta.1+build.123"
    local normalized_version="1.0.0-beta.1"

    run_script "$project_directory" "$full_version"
    assert_package_created "$project_directory" "$normalized_version" "$full_version"
}

@test "publish-npm handles project file in subdirectory" {
    local project_directory
    project_directory=$(create_project "subdirlib" "${TEMP_DIR}/nested")

    local version="1.5.0"
    run_script "$project_directory" "$version"
    assert_package_created "$project_directory" "$version"
}

@test "publish-npm handles absolute path to project file" {
    local project_directory
    project_directory=$(create_project "absolutelib" "${TEMP_DIR}/absolute")

    local version="2.0.0"
    mkdir -p "$TEMP_DIR/other"
    cd "$TEMP_DIR/other"

    run_script "$project_directory" "$version"
    assert_package_created "$project_directory" "$version"
}

@test "publish-npm handles scoped package names" {
    local project_directory
    project_directory=$(create_project "scopedpkg")

    local version="4.2.0"

    # Update the package name to use a scope
    jq '.name = "@myscope/scopedpkg"' "$project_directory/package.json" > "$project_directory/tmp.json"
    mv "$project_directory/tmp.json" "$project_directory/package.json"

    run_script "$project_directory" "$version"
    assert_package_created "$project_directory" "$version"
}
