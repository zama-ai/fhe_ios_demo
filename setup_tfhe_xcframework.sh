#!/bin/bash

# Ensure the script stops on error
set -e

# Welcome message
echo "Setting up TFHE.xcframework..."

# Define variables
TFHE_RS_DIR="tfhe-rs"
OUTPUT_DIR="tfhe_build_output"
INCLUDE_DIR="$OUTPUT_DIR/include"

# Remove previous build directories if they exist
echo "Cleaning up any previous build directories..."
rm -rf "$TFHE_RS_DIR" "$OUTPUT_DIR"

# Clone TFHE-rs repository
echo "Cloning TFHE-rs repository..."
git clone --branch tfhe-rs-0.7.3 https://github.com/zama-ai/tfhe-rs.git "$TFHE_RS_DIR"

# Install Rust if needed
if ! command -v rustup &> /dev/null; then
    echo "Installing Rust..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "Rust is already installed."
fi

# Ensure the nightly toolchain is installed
echo "Installing Rust nightly toolchain and components..."
rustup toolchain install nightly
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
rustup component add rust-src --toolchain nightly

# Build TFHE-rs for iOS and iOS simulator
echo "Building TFHE-rs for iOS..."
cd "$TFHE_RS_DIR"
RUSTFLAGS="" cargo +nightly build -Z build-std --release --features=aarch64-unix,high-level-c-api -p tfhe --target aarch64-apple-ios

echo "Building TFHE-rs for iOS Simulator..."
RUSTFLAGS="" cargo +nightly build -Z build-std --release --features=aarch64-unix,high-level-c-api -p tfhe --target aarch64-apple-ios-sim

# Create output directories
echo "Setting up output directories..."
cd ..
mkdir -p "$INCLUDE_DIR"

# Copy headers
echo "Copying headers..."
cp "$TFHE_RS_DIR/target/release/tfhe.h" "$INCLUDE_DIR/tfhe.h"
cp "$TFHE_RS_DIR/target/aarch64-apple-ios/release/deps/tfhe-c-api-dynamic-buffer.h" "$INCLUDE_DIR/tfhe-c-api-dynamic-buffer.h"

# Create Module Map
echo "Creating module map..."
cat <<EOL > "$INCLUDE_DIR/module.modulemap"
module TFHE {
    header "tfhe.h"
    header "tfhe-c-api-dynamic-buffer.h"
    export *
}
EOL

# Create FAT library for iOS Simulator
echo "Creating FAT library for iOS Simulator..."
lipo -create -output "$OUTPUT_DIR/libtfhe-ios-sim.a" "$TFHE_RS_DIR/target/aarch64-apple-ios-sim/release/libtfhe.a"

# Copy library for iOS
echo "Copying static library for iOS..."
cp "$TFHE_RS_DIR/target/aarch64-apple-ios/release/libtfhe.a" "$OUTPUT_DIR/libtfhe-ios.a"

# Package into .xcframework
echo "Packaging into .xcframework..."
xcodebuild -create-xcframework \
    -library "$OUTPUT_DIR/libtfhe-ios.a" \
    -headers "$INCLUDE_DIR/" \
    -library "$OUTPUT_DIR/libtfhe-ios-sim.a" \
    -headers "$INCLUDE_DIR/" \
    -output "TFHE.xcframework"

# Clean up build directories
echo "Cleaning up..."
rm -rf "$TFHE_RS_DIR" "$OUTPUT_DIR"

echo "Setup complete! The TFHE.xcframework is now available in the current directory."