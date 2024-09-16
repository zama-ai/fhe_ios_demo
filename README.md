#  Welcome to FHE AppStore Demo  

Implement a bridge iOS app, which simulate a new FHE app store which runs on encrypted data

# Installation Steps
## Apple
- macOS 15 Sequoia
- Xcode 16 [from AppStore](https://apps.apple.com/fr/app/xcode/id497799835) or [developer.apple.com](https://developer.apple.com/download/applications/)
- iOS 18 SDK (additional download, from Xcode)

## Rust
- Rust via [rustup](https://rustup.rs) (currently rust 1.81.0)
- Extra Rust architectures (iOS devices & iOS simulators running on Apple Silicon Macs):
    `rustup target add aarch64-apple-ios aarch64-apple-ios-sim`
- Cbindgen to easily generate C bindings: `cargo install --force cbindgen`

# Resources
- [GitHub Repo](https://github.com/zama-ai/fhe_appstore_on_ios)
- [Huggingface Demo](https://huggingface.co/spaces/zama-fhe/encrypted_image_filtering)
- [Tutorial: Calling a Rust library from Swift](https://medium.com/@kennethyoel/a-swiftly-oxidizing-tutorial-44b86e8d84f5)


# Compile a Rust Library to use from Swift
## Create Lib
`cargo new --lib my-rust-lib`

## Annotate functions
```
#[no_mangle]
pub extern fn my_function(a: i32, b: i32) -> i32 {
```

## Cargo file: static lib
```
[lib]
crate-type = ["staticlib"]
```

## Generate modulemap
```
// File module.modulemap
module MyModule {
    header "../MyModuleSDK/MyModule.h"    
    export *
}
```

## Generate headers
`make headers`

## Compile Rust for iOS
`make ios`

## Generate xcframework to use in Xcode 
`make xcode`
