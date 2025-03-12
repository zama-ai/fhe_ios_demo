<p align="center">
<!-- product name logo -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/75a78517-d423-4a28-8db3-1f50e7d86925">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/674c368f-8030-4407-985b-417a09e1fe87">
  <img width=600 alt="Zama Concrete ML iOS Demos">
</picture>
</p>

<hr>

<p align="center">
  <a href="https://docs.zama.ai/concrete-ml"> 📒 Documentation</a> | <a href="https://zama.ai/community"> 💛 Community support</a> | <a href="https://github.com/zama-ai/awesome-zama"> 📚 FHE resources by Zama</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-BSD--3--Clause--Clear-%23ffb243?style=flat-square"></a>
  <a href="https://github.com/zama-ai/bounty-program"><img src="https://img.shields.io/badge/Contribute-Zama%20Bounty%20Program-%23ffd208?style=flat-square"></a>
</p>

## About

### What is Concrete ML iOS Demos?

This repository contains iOS applications that demonstrate 
how FHE can help users securely get insights based on their personal
data. The applications in this repository run on iPhones and connect to remote services that work with encrypted data. These services are implemented with **Concrete ML**.

**Concrete ML** is a Privacy-Preserving Machine Learning (PPML) open-source set of tools built by [Zama](https://github.com/zama-ai). It simplifies the use of fully homomorphic encryption (FHE) for data scientists so that they can automatically turn machine learning models into their homomorphic equivalents, and use them without knowledge of cryptography.

<br></br>

### Main features

The repository implements the **Data Vault** and several end-user demo applications. **Data Vault** is the main storage of sensitive information and two example apps that use sensitive data encrypted by the **Data Vault**.

The **Data Vault** acts like a secure enclave: it encrypts sensitive user data (sleep, weight, profile info) and stores encrypted result in a shared folder for consumption by other apps. Human readable sensitive data never leaves device or the **Data Vault** app. 

To display the insights or results obtained from encrypted data, end-user applications must request that **Data Vault** displays the information in secure widgets. 

The following demo end-user applications are available:

1. **FHE Health**: Analyzes sleep quality data and provides statistics about the user's weight, producing graphs and insights. The sleep tracking can be done by an iWatch using the dedicated [Sleep App](https://support.apple.com/guide/watch/track-your-sleep-apd830528336/watchos).
1. **FHE Ads**: Displays targeted ads based on an encrypted user-profile. Internet advertising relies on behavioral profiling through cookies, but tracking user behavior without encryption has privacy risks. With FHE, a user can manually create their profile and ads can be matched to it without actually exposing the user-profile.

For these demo end-user applications, analysis and processing of the encrypted information is done on Zama's servers. Server side functionality for these end-user applications is implemented in the [Server](Server/README.md) directory.

The **Data Vault** uses [TFHE-rs](https://github.com/zama-ai/tfhe-rs) and  [Concrete ML Extensions](https://github.com/zama-ai/concrete-ml-extensions) to encrypt and decrypt data.

# Installation Steps

<<<<<<< HEAD
## Install Apple Tools
- macOS 15 Sequoia
- Xcode 16.2 [from AppStore](https://apps.apple.com/fr/app/xcode/id497799835) or [developer.apple.com](https://developer.apple.com/download/applications/)
- iOS 18.2 SDK (additional download from Xcode)

## Install AdImages
- Simply unzip `QLAdsExtension/AdImages.zip' in place.
=======
## Apple Tool Prerequisites
- macOS 15 Sequoia (or 14 Sonoma, whatever runs Xcode 16)
- Xcode 16 [from AppStore](https://apps.apple.com/fr/app/xcode/id497799835) or [developer.apple.com](https://developer.apple.com/download/applications/)
- iOS 18 SDK (additional download from Xcode)
>>>>>>> 50ccef1 (chore: update readme)

## Compiling app dependencies for iOS and Mac simulator

### Building libraries

To build the libraries follow these steps, which are detailed below:
1. [Install Rust](#installing-rust)
1. [Compile TFHE-rs](#compiling-tfhe-rs-for-use-in-swift) 
1. [Compile Concrete ML Extensions](#compiling-concrete-ml-extensions-for-use-in-swift)

#### 1. Install Rust

1. Install latest Rust release (currently 1.81.0):
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

#### 2. Compile TFHE-rs for use in Swift.

1. Get TFHE-rs
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

5. Grab Static Librairies (.a):
The iOS simulator library needs to be FAT, even if it contains one slice (you can also add an x86-64 slice later on):
```shell
lipo -create -output $(OUTPUT)/libtfhe-ios-sim.a $(TFHE_RS_PATH)/target/aarch64-apple-ios-sim/release/libtfhe.a
```

The ios device library can be copied as is:
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

### 3. Compile Concrete ML Extensions for use in Swift

Follow the [instructions in the Concrete ML Extensions](https://github.com/zama-ai/concrete-ml-extensions?tab=readme-ov-file#from-source-for-ios) package to build additional Swift bindings that are used by **Data Vault**.

### Using pre-built TFHE-rs libraries

Instead of building the `TFHE.xcframework` from scratch, you can use a previously built version. Simply save `TFHE.xcframework` in the root directory. Inside this framework, there should be:
- `Info.plist`
- `ios-arm64`
- `ios-arm64-simulator`

# Compiling the Data Vault and end-user application

TODO

# End-user Application Server
This repo also contains the backend implementations of the end-user applications. See the [server readme](Server/README.md) for more details on how to run these backends. 

# Useful References
- [Tutorial: Calling a Rust library from Swift](https://medium.com/@kennethyoel/a-swiftly-oxidizing-tutorial-44b86e8d84f5)
- [Minimize Rust binary size](https://github.com/johnthagen/min-sized-rust)
- [Using imported C APIs in Swift](https://developer.apple.com/documentation/swift/imported-c-and-objective-c-apis)
