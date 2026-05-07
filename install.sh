#!/bin/sh
set -e

REPO="rustycode-ai/rustycode"
CHANNEL="stable"

for arg in "$@"; do
    case "$arg" in
        --nightly) CHANNEL="nightly" ;;
        --stable) CHANNEL="stable" ;;
    esac
done

echo "RustyCode Installer (${CHANNEL})"
echo "==============================="

# Detect platform
OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" = "Darwin" ]; then
    case "$ARCH" in
        arm64) PLATFORM="macos-arm64"; EXT="tar.gz" ;;
        x86_64) PLATFORM="macos-x64"; EXT="tar.gz" ;;
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
elif [ "$OS" = "Linux" ]; then
    case "$ARCH" in
        x86_64|amd64) PLATFORM="linux-x64"; EXT="tar.gz" ;;
        aarch64|arm64) PLATFORM="linux-arm64"; EXT="tar.gz" ;;
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
else
    echo "Unsupported OS: $OS. Use install.ps1 for Windows."
    exit 1
fi

# Get release
echo "Fetching latest ${CHANNEL} release..."
if [ "$CHANNEL" = "stable" ]; then
    RELEASE_URL="https://api.github.com/repos/${REPO}/releases/latest"
else
    # For nightly, list releases and pick the first prerelease
    RELEASE_URL="https://api.github.com/repos/${REPO}/releases?per_page=10"
fi

RELEASE_JSON=$(curl -fsSL "$RELEASE_URL")

if [ "$CHANNEL" = "nightly" ]; then
    # Extract first prerelease from the list
    ASSET_URL=$(echo "$RELEASE_JSON" | python3 -c "
import json, sys
releases = json.load(sys.stdin)
for r in releases:
    if r.get('prerelease'):
        for a in r.get('assets', []):
            if '${PLATFORM}' in a['name'] and a['name'].endswith('.${EXT}'):
                print(a['browser_download_url'])
                sys.exit(0)
sys.exit(1)
" 2>/dev/null || echo "")
else
    ASSET_URL=$(echo "$RELEASE_JSON" | grep -o "\"browser_download_url\": \"[^\"]*${PLATFORM}[^\"]*\\.${EXT}\"" | head -1 | sed 's/.*: "\(.*\)"/\1/')
fi

if [ -z "$ASSET_URL" ]; then
    echo "Error: No ${PLATFORM} ${CHANNEL} binary found."
    echo "Build from source: cargo install --git https://github.com/${REPO}"
    exit 1
fi

# Download and extract
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading ${PLATFORM} binary..."
curl -fsSL -o "${TMPDIR}/rustycode.${EXT}" "$ASSET_URL"

echo "Extracting..."
cd "$TMPDIR"
if [ "$EXT" = "tar.gz" ]; then
    tar xzf "rustycode.${EXT}"
else
    unzip "rustycode.${EXT}"
fi

# Find the binary
BINARY_PATH=$(find . -name "rustycode-cli" -o -name "rustycode" -type f -perm -u+x | head -1)

if [ -z "$BINARY_PATH" ]; then
    echo "Error: Binary not found in archive."
    exit 1
fi

# Install
INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"
cp "$BINARY_PATH" "${INSTALL_DIR}/rustycode"
chmod +x "${INSTALL_DIR}/rustycode"

echo ""
echo "Installed to ${INSTALL_DIR}/rustycode"

# Check PATH
case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
        echo ""
        echo "Add to your shell profile:"
        echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
        ;;
esac

echo ""
echo "Run 'rustycode --help' to get started."
