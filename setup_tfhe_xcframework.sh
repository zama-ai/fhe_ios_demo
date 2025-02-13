#!/bin/bash

# Ensure the script stops on error
set -e

# Welcome message
echo "Setting up TFHE.xcframework and ConcreteMLExtensions.xcframework..."

# Define variables
TFHE_RS_DIR="tfhe-rs"
OUTPUT_DIR="tfhe_build_output"
INCLUDE_DIR="$OUTPUT_DIR/include"

CONCRETE_DIR="concrete-ml-extensions"
CONCRETE_OUTPUT_DIR="concrete_ml_extensions_output"
CONCRETE_GENERATED_DIR="GENERATED"
FRAMEWORKS_DIR="Frameworks"

# Remove previous build directories if they exist
echo "Cleaning up any previous build directories..."
rm -rf "$TFHE_RS_DIR" "$OUTPUT_DIR" "$CONCRETE_DIR" "$CONCRETE_OUTPUT_DIR" "$CONCRETE_GENERATED_DIR"

# Clone repositories
echo "Cloning TFHE‑rs repository (version tfhe‑rs‑0.7.3)..."
git clone --branch tfhe-rs-0.7.3 https://github.com/zama-ai/tfhe-rs.git "$TFHE_RS_DIR"

echo "Cloning concrete-ml-extensions repository (for concrete_ml_extensions)..."
git clone https://github.com/zama-ai/concrete-ml-extensions.git "$CONCRETE_DIR"

# Delete the cuda related features in rust/Cargo.toml (deai-dot-products)
sed -i '' '/default = \["cuda", "python"\]/d' "$CONCRETE_DIR/rust/Cargo.toml"
sed -i '' '/cuda = \[\]/d' "$CONCRETE_DIR/rust/Cargo.toml"

# Setup Python environment in the concrete-ml-extensions repository
echo "Setting up Python environment in the concrete-ml-extensions repository..."
cd "$CONCRETE_DIR"
python -m venv .venv
source .venv/bin/activate
poetry lock --no-update
poetry install
cd ..

# Get Python version from the virtual environment
echo "Detecting Python version..."
PYTHON_VERSION=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Using Python version: $PYTHON_VERSION"

# Install Rust if needed
if ! command -v rustup &> /dev/null; then
    echo "Rust not found. Installing Rust..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "Rust is already installed."
fi

# Ensure the nightly toolchain is installed
echo "Installing Rust nightly toolchain and targets (aarch64-apple-ios and aarch64-apple-ios-sim)..."
rustup toolchain install nightly
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
rustup component add rust-src --toolchain nightly

# Build TFHE from the tfhe‑rs repository for iOS and iOS Simulator
echo "Building TFHE for iOS (device target)..."
cd "$TFHE_RS_DIR"
RUSTFLAGS="" cargo +nightly build -Z build-std --release --features=aarch64-unix,high-level-c-api -p tfhe --target aarch64-apple-ios

echo "Building TFHE for iOS Simulator..."
RUSTFLAGS="" cargo +nightly build -Z build-std --release --features=aarch64-unix,high-level-c-api -p tfhe --target aarch64-apple-ios-sim
cd ..

# Build concrete_ml_extensions from the concrete-ml-extensions repository for both targets
echo "Building concrete_ml_extensions for iOS (device target)..."
cd "$CONCRETE_DIR"
export PYO3_CROSS_PYTHON_VERSION=$PYTHON_VERSION
cargo build --manifest-path rust/Cargo.toml --no-default-features --features "uniffi/cli swift_bindings" --lib --release --target aarch64-apple-ios

echo "Building concrete_ml_extensions for iOS Simulator..."
export PYO3_CROSS_PYTHON_VERSION=$PYTHON_VERSION
cargo build --manifest-path rust/Cargo.toml --no-default-features --features "uniffi/cli swift_bindings" --lib --release --target aarch64-apple-ios-sim

# Generate Swift bindings using uniffi-bindgen
echo "Generating Swift bindings for concrete_ml_extensions..."
cd "rust"
cargo run --bin uniffi-bindgen \
    --release \
    --no-default-features \
    --features "uniffi/cli swift_bindings" \
    generate --library target/aarch64-apple-ios/release/libconcrete_ml_extensions.dylib \
    --language swift \
    --out-dir "../../$CONCRETE_GENERATED_DIR"
cd ../..

# Package TFHE.xcframework
echo "Packaging TFHE.xcframework..."
mkdir -p "$INCLUDE_DIR"

echo "Copying TFHE header files..."
cp "$TFHE_RS_DIR/target/release/tfhe.h" "$INCLUDE_DIR/tfhe.h"
cp "$TFHE_RS_DIR/target/aarch64-apple-ios/release/deps/tfhe-c-api-dynamic-buffer.h" "$INCLUDE_DIR/tfhe-c-api-dynamic-buffer.h"

echo "Creating module.modulemap for TFHE..."
cat <<EOL > "$INCLUDE_DIR/module.modulemap"
module TFHE {
    header "tfhe.h"
    header "tfhe-c-api-dynamic-buffer.h"
    export *
}
EOL

echo "Creating FAT library for TFHE (iOS Simulator)..."
lipo -create -output "$OUTPUT_DIR/libtfhe-ios-sim.a" "$TFHE_RS_DIR/target/aarch64-apple-ios-sim/release/libtfhe.a"

echo "Copying static library for TFHE (iOS device)..."
cp "$TFHE_RS_DIR/target/aarch64-apple-ios/release/libtfhe.a" "$OUTPUT_DIR/libtfhe-ios.a"

mkdir -p "$FRAMEWORKS_DIR"
# Remove any pre-existing TFHE.xcframework to avoid conflicts
echo "Removing existing TFHE.xcframework if it exists..."
rm -rf "$FRAMEWORKS_DIR/TFHE.xcframework"

echo "Creating TFHE.xcframework..."
xcodebuild -create-xcframework \
    -library "$OUTPUT_DIR/libtfhe-ios.a" \
    -headers "$INCLUDE_DIR/" \
    -library "$OUTPUT_DIR/libtfhe-ios-sim.a" \
    -headers "$INCLUDE_DIR/" \
    -output "$FRAMEWORKS_DIR/TFHE.xcframework"

# Package ConcreteMLExtensions.xcframework
echo "Packaging ConcreteMLExtensions.xcframework..."
# Move the uniffi-generated header and module map into an include folder.
mkdir -p "$CONCRETE_GENERATED_DIR/include"
mv "$CONCRETE_GENERATED_DIR/concrete_ml_extensionsFFI.modulemap" "$CONCRETE_GENERATED_DIR/include/module.modulemap"
mv "$CONCRETE_GENERATED_DIR/concrete_ml_extensionsFFI.h" "$CONCRETE_GENERATED_DIR/include/concrete_ml_extensionsFFI.h"

# Remove any pre-existing ConcreteMLExtensions.xcframework to avoid conflicts
echo "Removing existing ConcreteMLExtensions.xcframework if it exists..."
rm -rf "$FRAMEWORKS_DIR/ConcreteMLExtensions.xcframework"

echo "Creating ConcreteMLExtensions.xcframework..."
xcodebuild -create-xcframework \
    -library "$CONCRETE_DIR/rust/target/aarch64-apple-ios/release/libconcrete_ml_extensions.a" \
    -headers "$CONCRETE_GENERATED_DIR/include/" \
    -library "$CONCRETE_DIR/rust/target/aarch64-apple-ios-sim/release/libconcrete_ml_extensions.a" \
    -headers "$CONCRETE_GENERATED_DIR/include/" \
    -output "$FRAMEWORKS_DIR/ConcreteMLExtensions.xcframework"

echo "Wrapping ConcreteMLExtensions headers to avoid module map conflicts..."
mkdir -p "$FRAMEWORKS_DIR/ConcreteMLExtensions.xcframework/ios-arm64/Headers/concreteHeaders"
mkdir -p "$FRAMEWORKS_DIR/ConcreteMLExtensions.xcframework/ios-arm64-simulator/Headers/concreteHeaders"
mv "$FRAMEWORKS_DIR/ConcreteMLExtensions.xcframework/ios-arm64/Headers/concrete_ml_extensionsFFI.h" \
   "$FRAMEWORKS_DIR/ConcreteMLExtensions.xcframework/ios-arm64/Headers/module.modulemap" \
   "$FRAMEWORKS_DIR/ConcreteMLExtensions.xcframework/ios-arm64/Headers/concreteHeaders" 2>/dev/null || true
mv "$FRAMEWORKS_DIR/ConcreteMLExtensions.xcframework/ios-arm64-simulator/Headers/concrete_ml_extensionsFFI.h" \
   "$FRAMEWORKS_DIR/ConcreteMLExtensions.xcframework/ios-arm64-simulator/Headers/module.modulemap" \
   "$FRAMEWORKS_DIR/ConcreteMLExtensions.xcframework/ios-arm64-simulator/Headers/concreteHeaders" 2>/dev/null || true

# Final cleanup
echo "Cleaning up intermediate build directories..."
rm -rf "$TFHE_RS_DIR" "$OUTPUT_DIR" "$CONCRETE_DIR"

echo "Setup complete!"
echo "• TFHE.xcframework and ConcreteMLExtensions.xcframework are available in the '$FRAMEWORKS_DIR' directory."
echo "• Remember to add 'concrete_ml_extensions.swift' (from the '$CONCRETE_GENERATED_DIR' folder) to your Xcode project for Swift integration."