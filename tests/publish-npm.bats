#!/usr/bin/env bats

setup() {
    export TEMP_DIR="$(mktemp -d)"
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../publish-npm.sh"
    export PACKAGE_REGISTRY="http://actions-publish-npm-registry:4873"

    # Auth for Verdaccio
    encoded_pass=$(echo -n 'testpassword' | base64)

cat > ~/.npmrc <<EOF
//actions-publish-npm-registry:4873/:username=testuser
//actions-publish-npm-registry:4873/:_password=${encoded_pass}
//actions-publish-npm-registry:4873/:email=testuser@example.com
always-auth=true
registry=http://actions-publish-npm-registry:4873
EOF

    create_project() {
        local project_directory="${1:-testproject}"
        local root_path="${2:-${TEMP_DIR}}"

        if [ -z "$root_path" ]; then
            echo "TEMP_DIR is not set and no root path provided" >&2
            return 1
        fi

        local full_path="${root_path}/${project_directory}"
        mkdir -p "$full_path" || {
            echo "Failed to create project directory: $full_path" >&2
            return 1
        }

        cd "$full_path" || {
            echo "Failed to cd into project directory: $full_path" >&2
            return 1
        }

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

        run bash "${SCRIPT_PATH}"
        if [ "$status" -ne 0 ]; then
            echo "Script failed with status $status"
            echo "$output"
            return 1
        fi
    }

    assert_package_created() {
        local project_directory="$1"
        local version="${2:-1.0.0}"

        grep -q "\"version\": \"${version}\"" "${project_directory}/package.json" || {
            echo "Expected version ${version} not found in package.json"
            return 1
        }

        local name
        name=$(jq -r .name "${project_directory}/package.json")
        if [ -z "$name" ] || [ "$name" = "null" ]; then
            echo "Failed to read package name from package.json"
            return 1
        fi

        npm view "$name" version --registry "$PACKAGE_REGISTRY" | grep -q "$version" || {
            echo "Version ${version} of ${name} not found in registry"
            return 1
        }
    }
}

teardown() {
    # Clear Verdaccio storage (container must allow write access)
    docker exec actions-publish-npm-registry rm -rf /verdaccio/storage/*
    rm -rf "${TEMP_DIR}"
}

@test "publish-npm fails when project package.json file doesn't exist" {
    cd "${TEMP_DIR}"
    run_script "NonExistentFolder" "1.0.0"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "publish-npm adds Version tag if none exists" {
    local project_directory
    project_directory=$(create_project) || return 1

    local version="1.2.3"
    run_script "$project_directory" "$version"
    assert_package_created "$project_directory" "$version"
}

@test "publish-npm updates existing Version tag" {
    local project_directory
    project_directory=$(create_project) || return 1

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
    project_directory=$(create_project) || return 1

    local version="1.0.0-beta.1+build.123"
    run_script "$project_directory" "$version"
    # npm strips build metadata (+build.123) from version during publish
    assert_package_created "$project_directory" "1.0.0-beta.1"
}

@test "publish-npm handles project file in subdirectory" {
    local project_directory
    project_directory=$(create_project "SubdirLib" "${TEMP_DIR}/nested") || return 1

    local version="1.5.0"
    run_script "$project_directory" "$version"
    assert_package_created "$project_directory" "$version"
}

@test "publish-npm handles absolute path to project file" {
    local project_directory
    project_directory=$(create_project "AbsoluteLib" "${TEMP_DIR}/absolute") || return 1

    local version="2.0.0"
    mkdir -p "$TEMP_DIR/other"
    cd "$TEMP_DIR/other"

    run_script "$project_directory" "$version"
    assert_package_created "$project_directory" "$version"
}
