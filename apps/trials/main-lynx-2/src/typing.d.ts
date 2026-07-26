// Copyright (c) 2025 TikTok Pte. Ltd.
// Licensed under the Apache License Version 2.0 that can be found in the
// LICENSE file in the root directory of this source tree.
declare module '@lynx-js/types' {
  interface GlobalProps {
    preferredTheme?: string;
    theme: string;
    isNotchScreen: boolean;
  }
}

declare global {
  type HealthAccessStatus = 'notDetermined' | 'authorized' | 'denied';
  type SpeechAccessStatus = 'notDetermined' | 'authorized' | 'denied';

  interface HealthKitDayEntry {
    text: string;
    isToday: boolean;
  }

  let NativeModules: {
    HealthKitModule: {
      getAuthorizationStatus(callback: (result: { status: HealthAccessStatus }) => void): void;
      requestAuthorization(
        callback: (result: { status: HealthAccessStatus; error: string | null }) => void,
      ): void;
      logSteps(steps: number, callback: (result: { success: boolean; error: string | null }) => void): void;
      getLast7Days(callback: (days: HealthKitDayEntry[]) => void): void;
    };
    SpeechModule: {
      getAuthorizationStatus(callback: (result: { status: SpeechAccessStatus }) => void): void;
      requestAuthorization(
        callback: (result: { status: SpeechAccessStatus; error: string | null }) => void,
      ): void;
      transcribe(
        callback: (result: { success: boolean; transcript: string | null; error: string | null }) => void,
      ): void;
    };
  };
}

export {}
