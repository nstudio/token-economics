You are working in the Expo (React Native) app in the current directory.

Read SPEC.md fully. Sections 1 and 2 apply to all work. Implement ONLY section 5 (Transcribe / Speech). Sections 3 and 4 are already implemented. Do not implement any other section. Do not modify SPEC.md or anything under spec-assets/.

Use the expo MCP server for framework and API questions.

Build with:

    npx expo prebuild --platform ios && xcodebuild -workspace ios/ExpoBenchmark.xcworkspace -scheme ExpoBenchmark -configuration Debug -destination "generic/platform=iOS Simulator" build

and fix errors until the build succeeds. The task is complete only when the build passes.

Do not launch, install, or drive the app on a simulator, and do not use UI automation tools (idb, simctl, xcrun simctl, or similar). The build command above is your only verification. Complete the task by reading the spec, writing the code, and making the build pass.
