import { apiClient } from './client'
import type { CreatePermissionRequest, PermissionDto } from '../types/api'

export const permissionApi = {
  getAll: () =>
    apiClient.get<{ data: PermissionDto[] }>('/api/v1/permission/'),

  create: (data: CreatePermissionRequest) =>
    apiClient.post('/api/v1/permission/', data),

  update: (permissionId: string, data: CreatePermissionRequest) =>
    apiClient.put(`/api/v1/permission/${permissionId}`, data),

  delete: (permissionId: string) =>
    apiClient.delete(`/api/v1/permission/${permissionId}`),
}
