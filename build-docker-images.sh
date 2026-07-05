#!/bin/sh
set -eu

IMAGE_NAME="${IMAGE_NAME:-jinqians/snell-server}"
LATEST_CHANNEL="${LATEST_CHANNEL:-v5}"
PUSH="${PUSH:-0}"
USE_BUILDX="${USE_BUILDX:-0}"
PROVENANCE="${PROVENANCE:-false}"
DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}"
export DOCKER_BUILDKIT

V4_LATEST="${V4_VERSION:-v4.1.1}"
V5_LATEST="${V5_VERSION:-v5.0.1}"
V6_LATEST="${V6_VERSION:-v6.0.0b4}"
V4_VERSIONS="${V4_VERSIONS:-v4.0.0 v4.0.1 v4.1.0 v4.1.1}"
V5_VERSIONS="${V5_VERSIONS:-v5.0.0 v5.0.1}"
V6_VERSIONS="${V6_VERSIONS:-v6.0.0b1 v6.0.0b2 v6.0.0b3 v6.0.0b4}"
SHADOWTLS_VERSION="${SHADOWTLS_VERSION:-v0.2.25}"

V4_PLATFORMS="${V4_PLATFORMS:-linux/amd64,linux/arm64,linux/arm/v7}"
V5_PLATFORMS="${V5_PLATFORMS:-linux/amd64,linux/arm64,linux/arm/v7}"
V6_PLATFORMS="${V6_PLATFORMS:-linux/amd64,linux/arm64}"

require_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker is not installed." >&2
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        echo "Docker daemon is not running." >&2
        exit 1
    fi
}

tag_args() {
    channel="$1"
    version="$2"
    latest_version="$3"

    printf ' -t %s:%s' "$IMAGE_NAME" "$version"
    if [ "$version" = "$latest_version" ]; then
        printf ' -t %s:%s' "$IMAGE_NAME" "$channel"
    fi
    if [ "$channel" = "$LATEST_CHANNEL" ] && [ "$version" = "$latest_version" ]; then
        printf ' -t %s:latest' "$IMAGE_NAME"
    fi
}

build_one() {
    channel="$1"
    version="$2"
    platforms="$3"
    latest_version="$4"

    echo "==> Building ${IMAGE_NAME} ${channel} (${version})"

    if [ "$USE_BUILDX" = "1" ]; then
        output="--load"
        if [ "$PUSH" = "1" ]; then
            output="--push"
        elif echo "$platforms" | grep -q ','; then
            echo "buildx cannot --load multiple platforms. Set PUSH=1 or use a single platform." >&2
            exit 1
        fi

        # shellcheck disable=SC2086
        docker buildx build \
            --platform "$platforms" \
            --provenance="$PROVENANCE" \
            --build-arg "SNELL_VERSION=$version" \
            --build-arg "SNELL_VER=$channel" \
            --build-arg "SHADOWTLS_VERSION=$SHADOWTLS_VERSION" \
            $(tag_args "$channel" "$version" "$latest_version") \
            $output \
            .
    else
        # shellcheck disable=SC2086
        docker build \
            --build-arg "SNELL_VERSION=$version" \
            --build-arg "SNELL_VER=$channel" \
            --build-arg "SHADOWTLS_VERSION=$SHADOWTLS_VERSION" \
            $(tag_args "$channel" "$version" "$latest_version") \
            .
    fi
}

build_versions() {
    channel="$1"
    versions="$2"
    latest_version="$3"
    platforms="$4"

    for version in $versions; do
        build_one "$channel" "$version" "$platforms" "$latest_version"
    done
}

main() {
    require_docker

    build_versions "v4" "$V4_VERSIONS" "$V4_LATEST" "$V4_PLATFORMS"
    build_versions "v5" "$V5_VERSIONS" "$V5_LATEST" "$V5_PLATFORMS"
    build_versions "v6" "$V6_VERSIONS" "$V6_LATEST" "$V6_PLATFORMS"

    echo
    echo "Built images:"
    docker images "$IMAGE_NAME" --format '  {{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}'
}

main "$@"
