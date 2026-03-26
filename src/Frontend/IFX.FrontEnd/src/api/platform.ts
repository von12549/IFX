import { apiClient } from './client'
import type { GlobalRoleDto, PolicyDefinitionDto } from '../types/api'

export const platformApi = {
  getGlobalRoles: () =>
    apiClient.get<{ data: GlobalRoleDto[] }>('/api/v1/platform/globalroles'),

  getPolicies: () =>
    apiClient.get<{ data: PolicyDefinitionDto[] }>('/api/v1/platform/policy'),
}
