#  Welcome to FHE iOS Demo  

Implements 2 iOS apps: a DataVault app and a User app. The User app uses data from the DataVault, ie can only manipulate encrypted data. The DataVault app generates the private keys and decrypt the final results the user app want the user to see, without returning clear results to the user app.

# Useful Links

- [GitHub Repo](https://github.com/zama-ai/fhe_ios_demo)
- [Canva exploration](https://www.canva.com/design/DAGUeG30ET0/Yy1lAaapPuLDaMJEukOM3Q/edit)
- [Google Docs UI Feedbacks](https://docs.google.com/document/d/1VOvwO9D7kKKPg0mRWacHJUfFZYBwRZezs_tmD3H6384/)
- [THFE-rs doc](https://docs.zama.ai/tfhe-rs/get-started/quick_start)
- [Huggingface Demo](https://huggingface.co/spaces/zama-fhe/encrypted_image_filtering)
- [Tutorial: Calling a Rust library from Swift](https://medium.com/@kennethyoel/a-swiftly-oxidizing-tutorial-44b86e8d84f5)
- [Minimize Rust binary size](https://github.com/johnthagen/min-sized-rust)
- [Using imported C APIs in Swift](https://developer.apple.com/documentation/swift/imported-c-and-objective-c-apis)
- [Learn Swift - Official  Guide](https://docs.swift.org/swift-book/documentation/the-swift-programming-language)
- [Learn Swift UI - Official  Guide](https://developer.apple.com/tutorials/swiftui)

# Installation Steps

## Apple Tools
- macOS 15 Sequoia (or 14 Sonoma, whatever runs Xcode 16)
- Xcode 16 [from AppStore](https://apps.apple.com/fr/app/xcode/id497799835) or [developer.apple.com](https://developer.apple.com/download/applications/)
- iOS 18 SDK (additional download from Xcode)

## Having TFHE libraries for iOS and mac simulator

There are two ways to obtain those libraries:
- the first one is the easiest: ask someone who has already built the libraries to send them to you; we don't store them in GitHub since they are about 340 MB, but clearly not everyone needs to build them
- the second one is needed at least for new TFHE-rs versions, or when one can't receive binaries made from others

### Getting libraries from others

Simply save `TFHE.xcframework in the root directory. Inside this framework, there should be:
- `Info.plist`
- `ios-arm64`
- `ios-arm64-simulator`

### Building libraries

There are several steps involved:
- Installing Rust
- Compiling TFHE-rs

#### Installing Rust

- Install latest Rust release (currently 1.81.0):
```shell
    curl https://sh.rustup.rs -sSf | sh
``` 

- Install extra target architectures (for iOS devices & iOS simulators running on Apple Silicon Macs):
```shell
    rustup target add aarch64-apple-ios aarch64-apple-ios-sim
```

- Install nightly Rust toolchain (a TFHE-rs requirement):
```shell
rustup toolchain install nightly
```

- Install Rust source so as to cross compile `std` lib (a TFHE-rs requirement):
```shell
rustup component add rust-src --toolchain nightly-aarch64-apple-darwin
```

#### Compiling TFHE-rs for use in Swift.

##### Get TFHE-rs (currently 0.7.3):
```shell
git clone --branch tfhe-rs-0.7.3 https://github.com/zama-ai/tfhe-rs.git
```

##### Compile for both iOS and iOS simulator targets:
```shell
RUSTFLAGS="" cargo +nightly build -Zbuild-std --release --features=aarch64-unix,high-level-c-api -p tfhe --target aarch64-apple-ios
RUSTFLAGS="" cargo +nightly build -Zbuild-std --release --features=aarch64-unix,high-level-c-api -p tfhe --target aarch64-apple-ios-sim
```

##### Grab generated headers (.h):
```shell
cp $(TFHE_RS_PATH)/target/release/tfhe.h $(OUTPUT)/include/tfhe.h
cp $(TFHE_RS_PATH)/target/aarch64-apple-ios/release/deps/tfhe-c-api-dynamic-buffer.h $(OUTPUT)/include/tfhe-c-api-dynamic-buffer.h
```

##### Create a Module Map:
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

##### Grab Static Librairies (.a):
The iOS simulator library needs to be FAT, even if it contains one slice (you can also add an x86-64 slice later on):
```shell
lipo -create -output $(OUTPUT)/libtfhe-ios-sim.a $(TFHE_RS_PATH)/target/aarch64-apple-ios-sim/release/libtfhe.a
```

The ios device library can be copied as is:
```shell
cp $(TFHE_RS_PATH)/target/aarch64-apple-ios/release/libtfhe.a $(OUTPUT)/libtfhe-ios.a
```

##### Package everything into an .xcframework:
```shell
xcodebuild -create-xcframework \
    -library $(OUTPUT)/libtfhe-ios.a \
    -headers $(OUTPUT)/include/ \
    -library $(OUTPUT)/libtfhe-ios-sim.a \
    -headers $(OUTPUT)/include/ \
    -output $(OUTPUT)/TFHE.xcframework
```

##### Save

Finally, move the `TFHE.xcframework` directory into the root directory of the iOS project. Inside this directory, there should be:
- `Info.plist`
- `ios-arm64`
- `ios-arm64-simulator`


# Running the Server
Follow steps in Server/README.md
