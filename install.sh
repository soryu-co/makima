#!/bin/bash
set -e

# Makima CLI Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/soryu-co/makima/master/install.sh | bash
#        curl -fsSL https://raw.githubusercontent.com/soryu-co/makima/master/install.sh | INSTALL_DIR=/opt/bin bash

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
BINARY_NAME="makima"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_info() {
    echo "$1"
}

# Check for required tools
check_dependencies() {
    local missing=""

    if ! command -v curl &> /dev/null; then
        missing="$missing curl"
    fi

    if ! command -v tar &> /dev/null; then
        missing="$missing tar"
    fi

    if [ -n "$missing" ]; then
        print_error "Missing required tools:$missing"
        print_info "Please install the missing tools and try again."
        exit 1
    fi
}

# Detect operating system
detect_os() {
    local os
    os="$(uname -s)"

    case "$os" in
        Linux*)
            echo "linux"
            ;;
        Darwin*)
            echo "macos"
            ;;
        *)
            print_error "Unsupported operating system: $os"
            print_info "Supported: Linux, macOS"
            exit 1
            ;;
    esac
}

# Detect CPU architecture
detect_arch() {
    local arch
    arch="$(uname -m)"

    case "$arch" in
        x86_64|amd64)
            echo "x86_64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            print_info "Supported: x86_64, arm64"
            exit 1
            ;;
    esac
}

# Get the latest release tag from GitHub
get_latest_tag() {
    local tag
    tag=$(curl -fsSL "https://api.github.com/repos/soryu-co/makima/releases/latest" 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')

    if [ -z "$tag" ]; then
        print_error "Failed to determine latest release tag from GitHub"
        print_info "Please check your internet connection or try again later."
        exit 1
    fi

    echo "$tag"
}

# Construct the download URL for the binary
get_download_url() {
    local os=$1
    local arch=$2
    local tag=$3
    echo "https://github.com/soryu-co/makima/releases/download/${tag}/makima-${tag}-${os}-${arch}.tar.gz"
}

# Download and install the binary
install_binary() {
    local url=$1
    local tmpdir
    tmpdir=$(mktemp -d)
    local tarball="$tmpdir/makima.tar.gz"

    print_info "Downloading from: $url"

    if ! curl -fsSL "$url" -o "$tarball"; then
        print_error "Failed to download from: $url"
        print_info "Please check if the binary is available for your platform."
        rm -rf "$tmpdir"
        exit 1
    fi

    if [ ! -f "$tarball" ] || [ ! -s "$tarball" ]; then
        print_error "Downloaded file is empty or missing"
        rm -rf "$tmpdir"
        exit 1
    fi

    # Extract the tarball
    print_info "Extracting archive..."
    if ! tar xzf "$tarball" -C "$tmpdir"; then
        print_error "Failed to extract archive"
        rm -rf "$tmpdir"
        exit 1
    fi

    local binary="$tmpdir/$BINARY_NAME"
    if [ ! -f "$binary" ]; then
        print_error "Binary '$BINARY_NAME' not found in archive"
        rm -rf "$tmpdir"
        exit 1
    fi

    chmod +x "$binary"

    # Create install directory if needed
    if [ ! -d "$INSTALL_DIR" ]; then
        print_info "Creating directory: $INSTALL_DIR"
        if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
            print_warning "Cannot create $INSTALL_DIR, trying with sudo..."
            sudo mkdir -p "$INSTALL_DIR"
        fi
    fi

    # Install
    print_info "Installing to: $INSTALL_DIR/$BINARY_NAME"
    if ! mv "$binary" "$INSTALL_DIR/$BINARY_NAME" 2>/dev/null; then
        print_warning "Cannot write to $INSTALL_DIR, trying with sudo..."
        sudo mv "$binary" "$INSTALL_DIR/$BINARY_NAME"
    fi

    rm -rf "$tmpdir"
}

# Verify installation
verify_installation() {
    if [ -x "$INSTALL_DIR/$BINARY_NAME" ]; then
        print_success "Successfully installed $BINARY_NAME to $INSTALL_DIR/$BINARY_NAME"

        # Check if install dir is in PATH
        if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
            print_warning "Note: $INSTALL_DIR is not in your PATH"
            print_info "Add it with: export PATH=\"$INSTALL_DIR:\$PATH\""
        fi

        # Show version if possible
        if command -v "$BINARY_NAME" &> /dev/null; then
            print_info ""
            print_info "Installed version:"
            "$BINARY_NAME" --version 2>/dev/null || true
        fi
    else
        print_error "Installation failed - binary not found at $INSTALL_DIR/$BINARY_NAME"
        exit 1
    fi
}

# Main installation flow
main() {
    print_info "Makima CLI Installer"
    print_info "===================="
    print_info ""

    check_dependencies

    local os arch tag
    os=$(detect_os)
    arch=$(detect_arch)
    print_info "Detected platform: $os-$arch"

    print_info "Fetching latest release..."
    tag=$(get_latest_tag)
    print_info "Latest release: $tag"

    local url
    url=$(get_download_url "$os" "$arch" "$tag")

    print_info ""
    install_binary "$url"

    print_info ""
    verify_installation

    print_info ""
    print_success "Installation complete!"
}

main "$@"
