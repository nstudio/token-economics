# lynx-benchmark

LynxJS app using Vue 3 (`vue-lynx`) built with rspeedy and TypeScript, hosted in a native iOS app via TikTok's Sparkling framework. iOS is the only target for this project.

## Layout

- `src/pages/<name>/{index.ts, App.vue}` — one rspeedy entry per page, emitted as `<name>.lynx.bundle`; pages and routing are registered in `app.config.ts` (navigation via `sparkling-navigation`)
- `ios/SparklingGo/` — native host app (Swift/SwiftUI + some ObjC); workspace `ios/SparklingGo.xcworkspace`, CocoaPods already installed
- `app.config.ts` — entries, bundle IDs, asset copy paths
- `SPEC.md`, `spec-assets/` — app specification and fixed assets (read-only)

## Build & run (iOS)

- JS bundles + copy into iOS resources: `npm run build`
- Full native build (the completion gate): `xcodebuild -workspace ios/SparklingGo.xcworkspace -scheme SparklingGo -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Run on the iOS Simulator: `npm run run:ios`
- `npm run autolink` regenerates native autolink glue when JS dependencies exposing native modules change.
- Toolchain: Xcode 26.5 (pinned in `.xcode-version`).

## Docs

- Lynx docs: https://lynxjs.org — also available through the configured Lynx docs MCP server; prefer the MCP for framework and API questions.
- Vue Lynx docs: https://vue.lynxjs.org
- Sparkling (host app + native bridge) docs: https://tiktok.github.io/sparkling/

## Native access

- Native capabilities are implemented in Swift/ObjC inside the host app and exposed to JS through Sparkling's method bridge (service/method registration lives in `ios/SparklingGo/SparklingGo/MethodServices/`) or via Lynx native modules.

## Definition of done

- The build command succeeds and the app runs on the iOS Simulator without crashing. Iterate until both are true.
