#  Welcome to FHE iOS Enclave Demo  

Implement a bridge iOS app and a user app. The user app uses our new FHE enclave principle, ie can only manipulate encrypted data. The bridge app generates the private keys and decrypt the final results the user app want the user to see, without returning clear results to the user app.

# Installation Steps
## Apple Tools
- macOS 15 Sequoia
- Xcode 16 [from AppStore](https://apps.apple.com/fr/app/xcode/id497799835) or [developer.apple.com](https://developer.apple.com/download/applications/)
- iOS 18 SDK (additional download from Xcode)

## Rust
- Install latest Rust release (currently 1.81.0)
```shell
    curl https://sh.rustup.rs -sSf | sh
``` 

- Install extra target architectures (iOS devices & iOS simulators running on Apple Silicon Macs):
```shell
    rustup target add aarch64-apple-ios aarch64-apple-ios-sim
```

- (Optional) Install Cbindgen to manually generate C bindings:
```shell
cargo install --force cbindgen
```

- Install nightly Rust toolchain (TFHE-rs requirement)
```shell
rustup toolchain install nightly
```

- Install Rust source so as to cross compile std lib (TFHE-rs requirement)
```shell
rustup component add rust-src --toolchain nightly-aarch64-apple-darwin
```

# Useful Links
- [GitHub Repo](https://github.com/zama-ai/fhe_appstore_on_ios)
- [Huggingface Demo](https://huggingface.co/spaces/zama-fhe/encrypted_image_filtering)
- [Tutorial: Calling a Rust library from Swift](https://medium.com/@kennethyoel/a-swiftly-oxidizing-tutorial-44b86e8d84f5)
- [Minimize Rust binary size](https://github.com/johnthagen/min-sized-rust)
- [Using imported C APIs in Swift](https://developer.apple.com/documentation/swift/imported-c-and-objective-c-apis)


# Compile TFHE-rs for use in Swift.

## Compile for both iOS and iOS sim targets
```shell
RUSTFLAGS="" cargo +nightly build -Zbuild-std --release --features=aarch64-unix,high-level-c-api -p tfhe` --target aarch64-apple-ios
RUSTFLAGS="" cargo +nightly build -Zbuild-std --release --features=aarch64-unix,high-level-c-api -p tfhe` --target aarch64-apple-ios-sim
```

## Grab generated headers (.h)
```shell
cp $(TFHE_RS_PATH)/target/release/tfhe.h $(OUTPUT)/include/tfhe.h
cp $(TFHE_RS_PATH)/target/aarch64-apple-ios/release/deps/tfhe-c-api-dynamic-buffer.h $(OUTPUT)/include/tfhe-c-api-dynamic-buffer.h
```

## Create a Module Map
```shell
touch $(OUTPUT)/include/module.modulemap
```

```swift
module TFHE {
  header "tfhe.h"
  header "tfhe-c-api-dynamic-buffer.h"
  export *
}
```

## Grab static libs (.a)
The ios simulator one needs to be FAT, even if it contains one slice. (You can also add an x86-64 slice later on)
```shell
lipo -create -output $(OUTPUT)/libtfhe-ios-sim.a $(TFHE_RS_PATH)/target/aarch64-apple-ios-sim/release/libtfhe.a
```

The ios device one can be copied as is:
```shell
cp $(TFHE_RS_PATH)/target/aarch64-apple-ios/release/libtfhe.a $(OUTPUT)/libtfhe-ios.a
```

## Package all that in a .xcframework
```shell
xcodebuild -create-xcframework \
    -library $(OUTPUT)/libtfhe-ios.a \
    -headers $(OUTPUT)/include/ \
    -library $(OUTPUT)/libtfhe-ios-sim.a \
    -headers $(OUTPUT)/include/ \
    -output $(OUTPUT)/TFHE.xcframework
```
