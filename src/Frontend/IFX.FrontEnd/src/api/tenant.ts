import { apiClient } from './client'
import type { CreateTenantRequest, TenantDto } from '../types/api'

export const tenantApi = {
  getAll: () =>
    apiClient.get<{ data: TenantDto[] }>('/api/v1/tenant/'),

  getById: (tenantId: string) =>
    apiClient.get<{ data: TenantDto }>(`/api/v1/tenant/${tenantId}`),

  create: (data: CreateTenantRequest) =>
    apiClient.post('/api/v1/tenant/', data),

  update: (tenantId: string, data: CreateTenantRequest) =>
    apiClient.put(`/api/v1/tenant/${tenantId}`, data),

  delete: (tenantId: string) =>
    apiClient.delete(`/api/v1/tenant/${tenantId}`),
}
