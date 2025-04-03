<p align="center">
<!-- product name logo -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://private-user-images.githubusercontent.com/157474013/429096066-74d7197d-ff76-4b1f-90d3-6840daa5f42c.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NDM2NjYyODUsIm5iZiI6MTc0MzY2NTk4NSwicGF0aCI6Ii8xNTc0NzQwMTMvNDI5MDk2MDY2LTc0ZDcxOTdkLWZmNzYtNGIxZi05MGQzLTY4NDBkYWE1ZjQyYy5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjUwNDAzJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI1MDQwM1QwNzM5NDVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT0yODJiMWE5M2QxMWUwYmZlZGQ4MjliYzk3YWNmOTRjZWRjOTVlZTgyZmMzMzFjMWFmZDNkZDg5NGE2ZDNlMzgxJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.-3nYml0BGWzZt2FHqiF3dZfzP7FqgwuHJlzNC4B4C-k">
  <source media="(prefers-color-scheme: light)" srcset="https://private-user-images.githubusercontent.com/157474013/429096062-58e09820-d52c-4095-b143-0ac9f9d0939f.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NDM2NjYyODUsIm5iZiI6MTc0MzY2NTk4NSwicGF0aCI6Ii8xNTc0NzQwMTMvNDI5MDk2MDYyLTU4ZTA5ODIwLWQ1MmMtNDA5NS1iMTQzLTBhYzlmOWQwOTM5Zi5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjUwNDAzJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI1MDQwM1QwNzM5NDVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT03MGJiM2JiMWVlODBjNGE1ZGRmZTA5YTFjOTQ5OWJlODk0NzI3ZDAwZjkxOWMwZDlkOWFlYzg3YzBiMDEwNzgxJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.IyHCK8qC34ODHQqoXrMcq3psdnEws3v_mttfi3c3ZOA">
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

**Concrete ML** is a Privacy-Preserving Machine Learning (PPML) open-source set of tools built by [Zama](https://github.com/zama-ai). It simplifies the use of Fully Homomorphic Encryption (FHE) for data scientists so that they can automatically turn machine learning models into their homomorphic equivalents, and use them without knowledge of cryptography.

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

## Setup

### Install Apple Tools
- macOS 15 Sequoia
- Xcode 16.2 [from AppStore](https://apps.apple.com/fr/app/xcode/id497799835) or [developer.apple.com](https://developer.apple.com/download/applications/)
- iOS 18.2 SDK (additional download from Xcode)

### Install AdImages
- Simply unzip `QLAdsExtension/AdImages.zip' in place.

### Compiling app dependencies for iOS and Mac simulator

#### Building libraries

The easiest way to build all dependencies is to execute [the dedicated script](./setup_tfhe_xcframework.sh). 

To manually build the libraries follow the instructions in the [compilation guide](./COMPILING.md). The main steps are:

1. [Install Rust](COMPILING.md#1-install-rust)
1. [Compile TFHE-rs](COMPILING.md#2-compile-tfhe-rs-for-use-in-swift) 
1. [Compile Concrete ML Extensions](COMPILING.md#3-compile-concrete-ml-extensions-for-use-in-swift)

#### Using pre-built TFHE-rs libraries

Instead of building the `TFHE.xcframework` from scratch, you can use a previously built version. Simply save `TFHE.xcframework` in the root directory. Inside this framework, there should be:
- `Info.plist`
- `ios-arm64`
- `ios-arm64-simulator`

## Data Vault and end-user application compilation

Now you can open your Xcode IDE, open this directory and start building the apps.

## End-user Application Server
This repo also contains the backend implementations of the end-user applications. See the [server readme](Server/README.md) for more details on how to run these backends. 

## Resources
- [Tutorial: Calling a Rust library from Swift](https://medium.com/@kennethyoel/a-swiftly-oxidizing-tutorial-44b86e8d84f5)
- [Minimize Rust binary size](https://github.com/johnthagen/min-sized-rust)
- [Using imported C APIs in Swift](https://developer.apple.com/documentation/swift/imported-c-and-objective-c-apis)
- [Concrete ML Documentation](https://docs.zama.ai/concrete-ml)

## License

This software is distributed under the **BSD-3-Clause-Clear** license. Read [this](LICENSE) for more details.

## FAQ

**Is Zama’s technology free to use?**

> Zama’s libraries are free to use under the BSD 3-Clause Clear license only for development, research, prototyping, and experimentation purposes. However, for any commercial use of Zama's open source code, companies must purchase Zama’s commercial patent license.
>
> All our work is open source and we strive for full transparency about Zama's IP strategy. To know more about what this means for Zama product users, read about how we monetize our open source products in [this blog post](https://www.zama.ai/post/open-source).

**What do I need to do if I want to use Zama’s technology for commercial purposes?**

> To commercially use Zama’s technology you need to be granted Zama’s patent license. Please contact us at hello@zama.ai for more information.

**Do you file IP on your technology?**

> Yes, all of Zama’s technologies are patented.

**Can you customize a solution for my specific use case?**

> We are open to collaborating and advancing the FHE space with our partners. If you have specific needs, please email us at hello@zama.ai.

<p align="right">
  <a href="#about" > ↑ Back to top </a>
</p>

## Support

<a target="_blank" href="https://zama.ai/community-channels">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/zama-ai/concrete-ml/assets/157474013/86502167-4ea4-49e9-a881-0cf97d141818">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/zama-ai/concrete-ml/assets/157474013/3dcf41e2-1c00-471b-be53-2c804879b8cb">
  <img alt="Support">
</picture>
</a>

🌟 If you find this project helpful or interesting, please consider giving it a star on GitHub! Your support helps to grow the community and motivates further development.