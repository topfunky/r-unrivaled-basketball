#!/bin/bash

# Install system dependencies required for R packages in this project
# This script installs:
#   - libfribidi-dev, libharfbuzz-dev: Required for textshaping package
#   - libtiff-dev, libwebp-dev: Required for ragg package
#   - libx11-dev: Required for clipr package
#   - libssl-dev, libssl3: Required for openssl R package (dependency of credentials, gert, usethis, wehoop)
#   - pandoc: Required for knitr, reprex, and rmarkdown packages

set -e  # Exit on error

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges. Using sudo..."
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

echo "Updating package lists..."
$SUDO_CMD apt-get update

echo "Installing system dependencies..."

# Install all required packages
$SUDO_CMD apt-get install -y \
    libfribidi-dev \
    libharfbuzz-dev \
    libtiff-dev \
    libwebp-dev \
    libx11-dev \
    libgit2-dev \
    libssl-dev \
    libssl3 \
    pandoc

# Try to install libssl1.1 if available (for older R openssl packages)
# This may fail on newer Ubuntu versions, which is okay
$SUDO_CMD apt-get install -y libssl1.1 || echo "libssl1.1 not available, will use libssl3"

echo "System dependencies installed successfully!"
