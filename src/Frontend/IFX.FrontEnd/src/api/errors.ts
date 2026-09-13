import { isAxiosError } from 'axios'

export function apiErrorMessage(error: unknown, fallback: string): string {
  if (isAxiosError<{ error?: unknown }>(error)) {
    const message = error.response?.data?.error
    if (typeof message === 'string' && message.length > 0) return message
  }
  return fallback
}
