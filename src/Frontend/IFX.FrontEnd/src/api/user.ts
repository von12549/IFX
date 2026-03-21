import { apiClient } from './client'
import type { UpdateProfileRequest, UserProfileDto } from '../types/api'

export const userApi = {
  getProfile: () =>
    apiClient.get<{ data: UserProfileDto }>('/api/v1/user/profile'),

  updateProfile: (data: UpdateProfileRequest) =>
    apiClient.put('/api/v1/user/profile', data),
}
