import { apiClient } from './client'
import type { ConfirmRequest, RegisterRequest } from '../types/api'

export const authApi = {
  register: (data: RegisterRequest) =>
    apiClient.post('/api/v1/auth/register', data),

  confirm: (data: ConfirmRequest) =>
    apiClient.post('/api/v1/auth/confirm', data),

  getLoginUrl: () => apiClient.getUri({ url: '/api/v1/auth/oauth/authorize' }),

  logout: (accessToken: string, refreshToken: string) =>
    apiClient.post('/api/v1/auth/logout', { accessToken, refreshToken }),
}
