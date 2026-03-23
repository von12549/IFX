import { apiClient } from './client'
import type { CreateRoleRequest, RoleDetailDto, RoleDto } from '../types/api'

export const roleApi = {
  getAll: () =>
    apiClient.get<{ data: RoleDto[] }>('/api/v1/role/'),

  getById: (roleId: string) =>
    apiClient.get<{ data: RoleDetailDto }>(`/api/v1/role/${roleId}`),

  create: (data: CreateRoleRequest) =>
    apiClient.post('/api/v1/role/', data),

  update: (roleId: string, data: CreateRoleRequest) =>
    apiClient.put(`/api/v1/role/${roleId}`, data),

  delete: (roleId: string) =>
    apiClient.delete(`/api/v1/role/${roleId}`),

  assignPermissions: (roleId: string, permissionIds: string[]) =>
    apiClient.post(`/api/v1/role/${roleId}/permissions`, { permissionIds }),

  removePermission: (roleId: string, permissionId: string) =>
    apiClient.delete(`/api/v1/role/${roleId}/permissions/${permissionId}`),
}
