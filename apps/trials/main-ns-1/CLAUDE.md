# ns-benchmark

NativeScript app using Vue 3 (`nativescript-vue`) with the Vite bundler, Tailwind CSS, and TypeScript. iOS is the only target for this project.

## Layout

- `app/app.ts` — app entry point
- `app/components/` — Vue single-file components
- `App_Resources/iOS/` — iOS resources: `Info.plist`, `build.xcconfig`, asset catalogs, entitlements
- `nativescript.config.ts`, `vite.config.ts` — project/bundler configuration
- `SPEC.md`, `spec-assets/` — app specification and fixed assets (read-only)

## Build & run (iOS)

- Full build (the completion gate): `ns build ios`
- Run on the iOS Simulator with live HMR: `npm run ios` (= `ns debug ios`)
- After changing iOS resources or native project settings, run `ns clean` before rebuilding if the build behaves stale.
- Toolchain: Xcode 26.5.

## Docs

- Official docs: https://docs.nativescript.org — also available through the configured NativeScript docs MCP server; prefer the MCP for framework and API questions.

## Native access

- iOS platform APIs are called directly from TypeScript via NativeScript's runtime bindings; iOS type declarations come from `@nativescript/types`.

## Definition of done

- The build command succeeds and the app runs on the iOS Simulator without crashing. Iterate until both are true.
