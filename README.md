<p align="center">
<!-- product name logo -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://private-user-images.githubusercontent.com/157474013/423544917-a87b457c-ecdb-4a2d-9579-0779065c7d4d.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NDM1MTAyMTgsIm5iZiI6MTc0MzUwOTkxOCwicGF0aCI6Ii8xNTc0NzQwMTMvNDIzNTQ0OTE3LWE4N2I0NTdjLWVjZGItNGEyZC05NTc5LTA3NzkwNjVjN2Q0ZC5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjUwNDAxJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI1MDQwMVQxMjE4MzhaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT02OTE2YzkzN2U1YWNjZWVjOWZjNzI4OThjMGJhYzdlODgwYzZkZTg1MDg4MTMxY2EyYzg5ZmEwNzdkMjcxOGJmJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.NCOTx6WIZAhRt36BXXfn5N3b7tHG0lz1d0viZxckS9A">
  <source media="(prefers-color-scheme: light)" srcset="https://private-user-images.githubusercontent.com/157474013/423470937-e0c82afa-97a2-414f-b219-52ea5d40c055.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NDM1MTAyMTgsIm5iZiI6MTc0MzUwOTkxOCwicGF0aCI6Ii8xNTc0NzQwMTMvNDIzNDcwOTM3LWUwYzgyYWZhLTk3YTItNDE0Zi1iMjE5LTUyZWE1ZDQwYzA1NS5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjUwNDAxJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI1MDQwMVQxMjE4MzhaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1kOTgyYzllMmY3ZTUzOGU5OTYyNGJhNDgxYTFmY2IxODViZWIwYThkMDI3ODIwZGQ4MDBkZWRlZWNiYTA4NDk3JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.4rtWKDzofPWNvY6rOhrMc1UfXGc3UeXdEfZdqkaxkAE">
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

## Installation Steps

<<<<<<< HEAD
<<<<<<< HEAD
## Install Apple Tools
- macOS 15 Sequoia
- Xcode 16.2 [from AppStore](https://apps.apple.com/fr/app/xcode/id497799835) or [developer.apple.com](https://developer.apple.com/download/applications/)
- iOS 18.2 SDK (additional download from Xcode)

## Install AdImages
- Simply unzip `QLAdsExtension/AdImages.zip' in place.
=======
## Apple Tool Prerequisites
=======
### Apple Tool Prerequisites
>>>>>>> f188baf (chore: indenting of readme sections)
- macOS 15 Sequoia (or 14 Sonoma, whatever runs Xcode 16)
- Xcode 16 [from AppStore](https://apps.apple.com/fr/app/xcode/id497799835) or [developer.apple.com](https://developer.apple.com/download/applications/)
- iOS 18 SDK (additional download from Xcode)
>>>>>>> 50ccef1 (chore: update readme)

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

## Compiling the Data Vault and end-user application

Now you can open your Xcode IDE, open this directory and start building the apps.

## End-user Application Server
This repo also contains the backend implementations of the end-user applications. See the [server readme](Server/README.md) for more details on how to run these backends. 

## Useful References
- [Tutorial: Calling a Rust library from Swift](https://medium.com/@kennethyoel/a-swiftly-oxidizing-tutorial-44b86e8d84f5)
- [Minimize Rust binary size](https://github.com/johnthagen/min-sized-rust)
- [Using imported C APIs in Swift](https://developer.apple.com/documentation/swift/imported-c-and-objective-c-apis)
