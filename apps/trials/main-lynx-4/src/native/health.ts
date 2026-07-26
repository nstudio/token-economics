import pipe from 'sparkling-method'

export type HealthAccessStatus = 'notRequested' | 'granted' | 'denied'

export interface HealthDay {
  year: number
  month: number
  day: number
  /** 1 = Sunday ... 7 = Saturday, matching Foundation's `Calendar.component(.weekday)`. */
  weekday: number
  steps: number
}

interface PipeRawResponse<T> {
  code: number
  msg?: string
  data?: T & { __status_message__?: string }
}

function callHealthMethod<T>(method: string): Promise<T> {
  return new Promise((resolve, reject) => {
    pipe.call(`health.${method}`, {}, (v: unknown) => {
      const response = v as PipeRawResponse<T>
      // LynxPipeStatusCode.succeeded === 1
      if (response?.code === 1) {
        resolve(response.data as T)
      } else {
        reject(new Error(response?.data?.__status_message__ || response?.msg || 'Unknown error'))
      }
    })
  })
}

export function getHealthStatus(): Promise<HealthAccessStatus> {
  return callHealthMethod<{ status: HealthAccessStatus }>('getStatus').then((data) => data.status)
}

export function requestHealthAccess(): Promise<HealthAccessStatus> {
  return callHealthMethod<{ status: HealthAccessStatus }>('requestAccess').then((data) => data.status)
}

export function logSteps(): Promise<void> {
  return callHealthMethod<Record<string, never>>('logSteps').then(() => undefined)
}

export function getLastSevenDays(): Promise<HealthDay[]> {
  return callHealthMethod<{ days: HealthDay[] }>('getLastSevenDays').then((data) => data.days)
}
