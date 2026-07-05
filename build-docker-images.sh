#!/bin/sh
set -eu

IMAGE_NAME="${IMAGE_NAME:-jinqians/snell-server}"
LATEST_CHANNEL="${LATEST_CHANNEL:-v5}"
PUSH="${PUSH:-0}"
USE_BUILDX="${USE_BUILDX:-0}"
PROVENANCE="${PROVENANCE:-false}"
DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}"
export DOCKER_BUILDKIT

V4_VERSION="${V4_VERSION:-v4.1.1}"
V5_VERSION="${V5_VERSION:-v5.0.1}"
V6_VERSION="${V6_VERSION:-v6.0.0b2}"

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

    printf ' -t %s:%s -t %s:%s' "$IMAGE_NAME" "$version" "$IMAGE_NAME" "$channel"
    if [ "$channel" = "$LATEST_CHANNEL" ]; then
        printf ' -t %s:latest' "$IMAGE_NAME"
    fi
}

build_one() {
    channel="$1"
    version="$2"
    platforms="$3"

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
            $(tag_args "$channel" "$version") \
            $output \
            .
    else
        # shellcheck disable=SC2086
        docker build \
            --build-arg "SNELL_VERSION=$version" \
            --build-arg "SNELL_VER=$channel" \
            $(tag_args "$channel" "$version") \
            .
    fi
}

main() {
    require_docker

    build_one "v4" "$V4_VERSION" "$V4_PLATFORMS"
    build_one "v5" "$V5_VERSION" "$V5_PLATFORMS"
    build_one "v6" "$V6_VERSION" "$V6_PLATFORMS"

    echo
    echo "Built images:"
    docker images "$IMAGE_NAME" --format '  {{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}'
}

main "$@"
