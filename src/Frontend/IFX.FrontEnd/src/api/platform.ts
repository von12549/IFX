import { apiClient } from './client'
import type {
  GlobalRoleDto,
  PolicyDefinitionDto,
  CrossTenantResultDto,
  UserProfileDto,
  RoleDto,
  RoleGroupDto,
  DepartmentDto,
  IdpDto,
} from '../types/api'

export const platformApi = {
  getGlobalRoles: () =>
    apiClient.get<{ data: GlobalRoleDto[] }>('/api/v1/platform/globalroles'),

  getPolicies: () =>
    apiClient.get<{ data: PolicyDefinitionDto[] }>('/api/v1/platform/policy'),

  getAllUsersAcrossTenants: () =>
    apiClient.get<{ data: CrossTenantResultDto<UserProfileDto> }>('/api/v1/platform/cross-tenant/users'),

  getAllRolesAcrossTenants: () =>
    apiClient.get<{ data: CrossTenantResultDto<RoleDto> }>('/api/v1/platform/cross-tenant/roles'),

  getAllRoleGroupsAcrossTenants: () =>
    apiClient.get<{ data: CrossTenantResultDto<RoleGroupDto> }>('/api/v1/platform/cross-tenant/rolegroups'),

  getAllDepartmentsAcrossTenants: () =>
    apiClient.get<{ data: CrossTenantResultDto<DepartmentDto> }>('/api/v1/platform/cross-tenant/departments'),

  getAllIdpsAcrossTenants: () =>
    apiClient.get<{ data: CrossTenantResultDto<IdpDto> }>('/api/v1/platform/cross-tenant/idps'),
}
