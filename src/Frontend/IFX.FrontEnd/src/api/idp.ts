import { apiClient } from './client'
import type { CreateIdpRequest, IdpDto } from '../types/api'

export const idpApi = {
  getAll: (tenantId?: string) =>
    apiClient.get<{ data: IdpDto[] }>('/api/v1/idp/', { params: tenantId ? { tenantId } : undefined }),

  getById: (idpId: string) =>
    apiClient.get<{ data: IdpDto }>(`/api/v1/idp/${idpId}`),

  create: (data: CreateIdpRequest) =>
    apiClient.post('/api/v1/idp/', data),

  update: (idpId: string, data: Partial<CreateIdpRequest>) =>
    apiClient.put(`/api/v1/idp/${idpId}`, data),
}
