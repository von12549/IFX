import { apiClient } from './client'
import type { PagedResult, UserProfileDto } from '../types/api'

export const userManagementApi = {
  getAll: (page = 1, pageSize = 50) =>
    apiClient.get<{ data: PagedResult<UserProfileDto> }>(
      `/api/v1/usermanagement/users?page=${page}&pageSize=${pageSize}`
    ),

  getById: (userId: string) =>
    apiClient.get<{ data: UserProfileDto }>(`/api/v1/usermanagement/users/${userId}`),

  assignRoles: (userId: string, roleIds: string[]) =>
    apiClient.post(`/api/v1/usermanagement/users/${userId}/roles`, { roleIds }),

  removeRole: (userId: string, roleId: string) =>
    apiClient.delete(`/api/v1/usermanagement/users/${userId}/roles/${roleId}`),

  assignRoleGroups: (userId: string, roleGroupIds: string[]) =>
    apiClient.post(`/api/v1/usermanagement/users/${userId}/rolegroups`, { roleGroupIds }),

  removeRoleGroup: (userId: string, roleGroupId: string) =>
    apiClient.delete(`/api/v1/usermanagement/users/${userId}/rolegroups/${roleGroupId}`),
}
