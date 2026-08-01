# Expo baseline template inventory

## Current baseline — `--template blank-typescript` (adopted 2026-08-01)

Chosen after the pilot showed the DEFAULT template made phase 1 measure template
demolition rather than shell construction: the Expo agent deleted 745 lines of demo
components (+118/-745 across 14 files) where the NativeScript agent deleted 14.
Both v1.0 baselines were near-blank (NativeScript 3 app files, Lynx 13), so the blank
template restores the precedent and keeps phase 1 measuring the same activity on both
arms. Neither baseline ships navigation now, which is itself closer parity.
Evidence retained: results/ns-vs-expo/pilot-expo-1 (flagged `superseded`).

## Versions
- expo: ~57.0.9
- react-native: 0.86.2
- react: 19.2.3

## Agent-facing files the template ships (removed at baseline — PLAN-EXPO §2.7)
Both the default and blank templates ship these; both are normalized identically.
```
AGENTS.md:  # Expo HAS CHANGED / Read the exact versioned docs at https://docs.expo.dev/versions/v57.0.0/ before writing any code.
CLAUDE.md:  @AGENTS.md
.claude/settings.json:  {"enabledPlugins": {"expo@claude-plugins-official": true}}
```

## App files the blank template ships (kept as-scaffolded)
```
  .gitignore
  .vscode/extensions.json
  .vscode/settings.json
  LICENSE
  README.md
  app.json
  assets/expo.icon/Assets/expo-symbol 2.svg
  assets/expo.icon/Assets/grid.png
  assets/expo.icon/icon.json
  assets/images/android-icon-background.png
  assets/images/android-icon-foreground.png
  assets/images/android-icon-monochrome.png
  assets/images/expo-badge-white.png
  assets/images/expo-badge.png
  assets/images/expo-logo.png
  assets/images/favicon.png
  assets/images/icon.png
  assets/images/logo-glow.png
  assets/images/react-logo.png
  assets/images/react-logo@2x.png
  assets/images/react-logo@3x.png
  assets/images/splash-icon.png
  assets/images/tabIcons/explore.png
  assets/images/tabIcons/explore@2x.png
  assets/images/tabIcons/explore@3x.png
  assets/images/tabIcons/home.png
  assets/images/tabIcons/home@2x.png
  assets/images/tabIcons/home@3x.png
  assets/images/tutorial-web.png
  modules/health-kit/LICENSE
  modules/health-kit/expo-module.config.json
  modules/health-kit/ios/HealthKitModule.podspec
  modules/health-kit/ios/HealthKitModule.swift
  modules/health-kit/src/HealthKitModule.ts
  modules/health-kit/src/HealthKitModule.types.ts
  modules/health-kit/src/HealthKitModule.web.ts
  modules/speech-kit/LICENSE
  modules/speech-kit/expo-module.config.json
  modules/speech-kit/ios/SpeechKitModule.podspec
  modules/speech-kit/ios/SpeechKitModule.swift
  modules/speech-kit/ios/assets/sample.wav
  modules/speech-kit/src/SpeechKitModule.ts
  modules/speech-kit/src/SpeechKitModule.types.ts
  modules/speech-kit/src/SpeechKitModule.web.ts
  package-lock.json
  package.json
  scripts/reset-project.js
  src/app/_layout.tsx
  src/app/health.tsx
  src/app/index.tsx
  src/app/transcribe.tsx
  src/components/animated-icon.tsx
  src/components/animated-icon.web.tsx
  src/components/themed-text.tsx
  src/components/themed-view.tsx
  src/constants/theme.ts
  src/global.css
  src/hooks/use-color-scheme.ts
  src/hooks/use-color-scheme.web.ts
  src/hooks/use-theme.ts
  tsconfig.json
```
