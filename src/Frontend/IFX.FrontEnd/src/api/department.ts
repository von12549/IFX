import { apiClient } from './client'
import type { CreateDepartmentRequest, DepartmentDto } from '../types/api'

export const departmentApi = {
  getAll: (tenantId?: string) =>
    apiClient.get<{ data: DepartmentDto[] }>('/api/v1/department/', {
      params: tenantId ? { tenantId } : undefined,
    }),

  getById: (departmentId: string) =>
    apiClient.get<{ data: DepartmentDto }>(`/api/v1/department/${departmentId}`),

  create: (data: CreateDepartmentRequest) =>
    apiClient.post('/api/v1/department/', data),

  update: (departmentId: string, data: { name: string; description: string }) =>
    apiClient.put(`/api/v1/department/${departmentId}`, data),

  delete: (departmentId: string) =>
    apiClient.delete(`/api/v1/department/${departmentId}`),
}
