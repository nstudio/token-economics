// Copyright (c) 2025 TikTok Pte. Ltd.
// Licensed under the Apache License Version 2.0 that can be found in the
// LICENSE file in the root directory of this source tree.
declare module '@lynx-js/types' {
  interface GlobalProps {
    preferredTheme?: string;
    theme: string;
    isNotchScreen: boolean;
  }

  interface NativeModules {
    HealthKitModule: {
      getAuthorizationStatus(callback: (status: string) => void): void;
      requestAuthorization(callback: (result: { status: string; error?: string }) => void): void;
      logSteps(steps: number, callback: (result: { success: boolean; error?: string }) => void): void;
      getLast7Days(
        callback: (result: { success: boolean; error?: string; days?: { dateMs: number; steps: number; isToday: boolean }[] }) => void,
      ): void;
    };
    SpeechModule: {
      getAuthorizationStatus(callback: (status: string) => void): void;
      requestAuthorization(callback: (result: { status: string; error?: string }) => void): void;
      transcribeSample(
        callback: (result: { event: 'partial' | 'final' | 'error'; transcript?: string; error?: string }) => void,
      ): void;
    };
  }
}

export {}
