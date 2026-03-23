import { apiClient } from './client'
import type { CreateRoleGroupRequest, RoleGroupDto } from '../types/api'

export const roleGroupApi = {
  getAll: () =>
    apiClient.get<{ data: RoleGroupDto[] }>('/api/v1/rolegroup/'),

  create: (data: CreateRoleGroupRequest) =>
    apiClient.post('/api/v1/rolegroup/', data),

  update: (roleGroupId: string, data: CreateRoleGroupRequest) =>
    apiClient.put(`/api/v1/rolegroup/${roleGroupId}`, data),

  delete: (roleGroupId: string) =>
    apiClient.delete(`/api/v1/rolegroup/${roleGroupId}`),

  assignRoles: (roleGroupId: string, roleIds: string[]) =>
    apiClient.post(`/api/v1/rolegroup/${roleGroupId}/roles`, { roleIds }),

  removeRole: (roleGroupId: string, roleId: string) =>
    apiClient.delete(`/api/v1/rolegroup/${roleGroupId}/roles/${roleId}`),
}
