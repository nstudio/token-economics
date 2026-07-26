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
    HealthModule: {
      getAuthorizationStatus(callback: (result: { status: 'not_requested' | 'granted' | 'denied' }) => void): void;
      requestAuthorization(callback: (result: { status: 'not_requested' | 'granted' | 'denied' }) => void): void;
      logSteps(steps: number, callback: (result: { success: boolean; error?: string }) => void): void;
      getLast7Days(callback: (days: { date: string; steps: number }[]) => void): void;
    };
    SpeechModule: {
      getAuthorizationStatus(callback: (result: { status: 'not_requested' | 'granted' | 'denied' }) => void): void;
      requestAuthorization(callback: (result: { status: 'not_requested' | 'granted' | 'denied' }) => void): void;
      transcribeSample(): void;
    };
  }
}

export {}
