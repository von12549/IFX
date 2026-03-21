import { apiClient } from './client'
import type { ConfirmRequest, RegisterRequest } from '../types/api'

export const authApi = {
  register: (data: RegisterRequest) =>
    apiClient.post('/api/v1/auth/register', data),

  confirm: (data: ConfirmRequest) =>
    apiClient.post('/api/v1/auth/confirm', data),

  getAuthorizeUrl: () =>
    apiClient.get<{ data: { authorizationUrl: string; state: string } }>(
      '/api/v1/auth/oauth/authorize?response_mode=json'
    ),

  logout: (accessToken: string, refreshToken: string) =>
    apiClient.post('/api/v1/auth/logout', { accessToken, refreshToken }),
}
