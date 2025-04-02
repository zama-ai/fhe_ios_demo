# Compiling app dependencies for iOS and Mac simulator

## 1. Install Rust

1. Install the latest Rust release (currently 1.81.0):
```shell
    curl https://sh.rustup.rs -sSf | sh
``` 

2.  Install extra target architectures (for iOS devices & iOS simulators running on Apple Silicon Macs):
```shell
    rustup target add aarch64-apple-ios aarch64-apple-ios-sim
```

3. Install nightly Rust toolchain (a TFHE-rs requirement):
```shell
rustup toolchain install nightly
```

4. Install Rust source so as to cross compile `std` lib (a TFHE-rs requirement):
```shell
rustup component add rust-src --toolchain nightly-aarch64-apple-darwin
```

## 2. Compile TFHE-rs for use in Swift

1. Get TFHE-rs:
```shell
git clone --branch https://github.com/zama-ai/tfhe-rs.git
```

2. Compile for both iOS and iOS simulator targets:
```shell
RUSTFLAGS="" cargo +nightly build -Zbuild-std --release --features=aarch64-unix,high-level-c-api -p tfhe --target aarch64-apple-ios
RUSTFLAGS="" cargo +nightly build -Zbuild-std --release --features=aarch64-unix,high-level-c-api -p tfhe --target aarch64-apple-ios-sim
```

3. Grab generated headers (.h):
```shell
cp $(TFHE_RS_PATH)/target/release/tfhe.h $(OUTPUT)/include/tfhe.h
cp $(TFHE_RS_PATH)/target/aarch64-apple-ios/release/deps/tfhe-c-api-dynamic-buffer.h $(OUTPUT)/include/tfhe-c-api-dynamic-buffer.h
```

4. Create a Module Map:
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

5. Grab static librairies (.a):
The iOS simulator library needs to be FAT, even if it contains one slice (you can also add an x86-64 slice later on):
```shell
lipo -create -output $(OUTPUT)/libtfhe-ios-sim.a $(TFHE_RS_PATH)/target/aarch64-apple-ios-sim/release/libtfhe.a
```

The iOS device library can be copied this way:
```shell
cp $(TFHE_RS_PATH)/target/aarch64-apple-ios/release/libtfhe.a $(OUTPUT)/libtfhe-ios.a
```

6. Package everything into an .xcframework:
```shell
xcodebuild -create-xcframework \
    -library $(OUTPUT)/libtfhe-ios.a \
    -headers $(OUTPUT)/include/ \
    -library $(OUTPUT)/libtfhe-ios-sim.a \
    -headers $(OUTPUT)/include/ \
    -output $(OUTPUT)/TFHE.xcframework
```

Finally, move the `TFHE.xcframework` directory into the root directory of the iOS project. 

## 3. Compile Concrete ML Extensions for use in Swift

Follow the [instructions in the Concrete ML Extensions](https://github.com/zama-ai/concrete-ml-extensions?tab=readme-ov-file#from-source-for-ios) package to build additional Swift bindings that are used by **Data Vault**.
