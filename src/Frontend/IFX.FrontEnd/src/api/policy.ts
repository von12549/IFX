import { apiClient } from './client'
import type { PolicyDefinitionDto, CreatePolicyRequest, UpdatePolicyRequest, TemplateDto } from '../types/api'

export const policyApi = {
  getAll: () =>
    apiClient.get<{ data: PolicyDefinitionDto[] }>('/api/v1/policy/'),

  getTemplates: () =>
    apiClient.get<{ data: TemplateDto[] }>('/api/v1/policy/templates'),

  create: (data: CreatePolicyRequest) =>
    apiClient.post('/api/v1/policy/', data),

  update: (policyId: string, data: UpdatePolicyRequest) =>
    apiClient.put(`/api/v1/policy/${policyId}`, data),

  delete: (policyId: string) =>
    apiClient.delete(`/api/v1/policy/${policyId}`),
}
