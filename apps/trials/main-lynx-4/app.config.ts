// @ts-nocheck
import { defineConfig } from '@lynx-js/rspeedy'
import { pluginQRCode } from '@lynx-js/qrcode-rsbuild-plugin'
import { pluginVueLynx } from 'vue-lynx/plugin'
import type { AppConfig } from 'sparkling-app-cli'

const lynxConfig = defineConfig({
  source: {
    entry: {
      main: './src/pages/main/index.ts',
      second: './src/pages/second/index.ts',
      health: './src/pages/health/index.ts',
      transcribe: './src/pages/transcribe/index.ts',
    },
  },
  output: {
    assetPrefix: 'asset:///',
    filename: {
      bundle: '[name].lynx.bundle'
    },
  },
  // pluginVueLynx only emits Lynx bundles for environments named `lynx`/`lynx-*`.
  environments: {
    lynx: {},
  },
  plugins: [
    pluginQRCode({
      schema(url: string): string {
        // We use `?fullscreen=true` to open the page in LynxExplorer in full screen mode
        return `${url}?fullscreen=true`
      },
    }),
    pluginVueLynx({
      optionsApi: false,
      enableCSSInlineVariables: true,
      enableCSSInheritance: true,
    }),
  ],
})

const config: AppConfig = {
  lynxConfig,
  appName: 'lynx-benchmark',
  platform: {
    android: {
      packageName: 'com.example.sparkling.go',
    },
    ios: {
      bundleIdentifier: 'com.example.sparkling.go',
    },
  },
  paths: {
    androidAssets: 'android/app/src/main/assets',
    iosAssets: 'ios/SparklingGo/SparklingGo/Resources/Assets',
  },
  appIcon: './resource/app_icon.png',
  router: {
    main: {
      path: './lynxPages/main',
    },
    second: {
      path: './lynxPages/second',
    },
    health: {
      path: './lynxPages/health',
    },
    transcribe: {
      path: './lynxPages/transcribe',
    },
  },
  plugin: [
    [
      'splash-screen',
      {
        backgroundColor: '#232323',
        image: './resource/app_icon.png',
        dark: {
          image: './resource/app_icon.png',
          backgroundColor: '#000000',
        },
        imageWidth: 200,
      },
    ],
  ],
};

export default config
