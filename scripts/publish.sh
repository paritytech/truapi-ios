#!/bin/sh
# Publish the locally built truapi_server.xcframework as a GitHub release asset
# and point Package.swift at it (URL + checksum).
#
# Build first with scripts/rebuild.sh, then:
#   ./scripts/publish.sh <version>    e.g. ./scripts/publish.sh 0.1.0
#
# Releases are tagged "v<version>" on paritytech/truapi-ios so SPM consumers
# can pin by semver. Ordering matters: the asset is uploaded first, then the
# Package.swift bump is committed and pushed, and finally the tag is moved
# onto that commit. Branch consumers therefore never resolve a manifest whose
# asset is not live yet, and the tagged manifest always references its own
# asset.
set -eu

if [ $# -ne 1 ]; then
    echo "usage: $0 <version>" >&2
    exit 64
fi

VERSION="$1"
TAG="v${VERSION}"
TITLE="TrUAPIHost ${VERSION}"
REPO="paritytech/truapi-ios"
PACKAGE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCFRAMEWORK="$PACKAGE_ROOT/Binaries/truapi_server.xcframework"
BRANCH="$(git -C "$PACKAGE_ROOT" rev-parse --abbrev-ref HEAD)"

if [ "$BRANCH" = "HEAD" ]; then
    echo "error: detached HEAD — check out the branch to publish from" >&2
    exit 65
fi

if [ ! -d "$XCFRAMEWORK" ]; then
    echo "error: $XCFRAMEWORK not found — run scripts/rebuild.sh first" >&2
    exit 66
fi

if ! git -C "$PACKAGE_ROOT" diff --quiet -- Package.swift; then
    echo "error: Package.swift has uncommitted changes — commit or revert them first" >&2
    exit 65
fi

STAGING="$(mktemp -d)"
ZIP="$STAGING/truapi_server.xcframework.zip"
trap 'rm -rf "$STAGING"' EXIT

ditto -c -k --keepParent "$XCFRAMEWORK" "$ZIP"
CHECKSUM="$(cd "$PACKAGE_ROOT" && swift package compute-checksum "$ZIP")"

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" "$ZIP" --repo "$REPO" --clobber
else
    gh release create "$TAG" "$ZIP" \
        --repo "$REPO" \
        --target "$BRANCH" \
        --title "$TITLE" \
        --notes "truapi_server.xcframework for the TrUAPIHost Swift package."
fi

URL="https://github.com/${REPO}/releases/download/${TAG}/truapi_server.xcframework.zip"
MANIFEST="$PACKAGE_ROOT/Package.swift"
sed -i '' -E "s|^let publishedBinaryURL = .*|let publishedBinaryURL = \"$URL\"|" "$MANIFEST"
sed -i '' -E "s|^let publishedBinaryChecksum = .*|let publishedBinaryChecksum = \"$CHECKSUM\"|" "$MANIFEST"

if git -C "$PACKAGE_ROOT" diff --quiet -- Package.swift; then
    echo "Package.swift already points at the $TAG asset."
else
    git -C "$PACKAGE_ROOT" commit \
        -m "Point Package.swift at the $TAG xcframework release" \
        -- Package.swift
    git -C "$PACKAGE_ROOT" push origin "$BRANCH"
fi

# Move the tag onto the manifest-bump commit so `from: "<version>"` checks out
# a manifest that references its own (already uploaded) asset. The release and
# its assets stay attached to the tag name when the tag moves.
git -C "$PACKAGE_ROOT" tag -f "$TAG"
git -C "$PACKAGE_ROOT" push -f origin "refs/tags/$TAG"

echo "Published $TAG ($CHECKSUM)"
