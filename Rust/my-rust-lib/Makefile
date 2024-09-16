headers:
	@cbindgen --lang c --output include/myRustLib.h

ios:
	@cargo build --release --lib --target aarch64-apple-ios
	@cargo build --release --lib --target aarch64-apple-ios-sim
	@$(RM) -rf libs/libmy_rust_lib-ios.a
	@$(RM) -rf libs/libmy_rust_lib-ios-sim.a
	@cp target/aarch64-apple-ios/release/libmy_rust_lib.a libs/libmy_rust_lib-ios.a
	@lipo -create -output libs/libmy_rust_lib-ios-sim.a \
		target/aarch64-apple-ios-sim/release/libmy_rust_lib.a

# If sim lib has just one arch (no x64), let's remove lipo ?

xcode:
	@$(RM) -rf MyRustLib.xcframework
	@xcodebuild -create-xcframework \
		-library libs/libmy_rust_lib-ios-sim.a \
		-headers ./include/ \
		-library libs/libmy_rust_lib-ios.a \
		-headers ./include/ \
		-output MyRustLib.xcframework
