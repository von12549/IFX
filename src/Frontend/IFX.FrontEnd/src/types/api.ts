// API response wrapper
export interface ApiResponse<T> {
  success: boolean
  data?: T
  error?: string
}

// Auth
export interface TokenSet {
  accessToken: string
  idToken: string
  refreshToken: string
  expiresIn: number
  tokenType: string
}

export interface RegisterRequest {
  email: string
  password: string
  firstName: string
  lastName: string
}

export interface ConfirmRequest {
  email: string
  confirmationCode: string
}

// RBAC
export interface RoleDto {
  id: string
  name: string
  description: string
  tenantName: string
}

export interface RoleDetailDto extends RoleDto {
  permissions: PermissionDto[]
}

export interface RoleGroupDto {
  id: string
  name: string
  description: string
  tenantName: string
  roles: RoleDto[]
}

export interface PermissionDto {
  id: string
  name: string
  description: string
}

// User
export interface UserProfileDto {
  id: string
  email: string
  displayName: string
  firstName: string
  lastName: string
  birthDate: string
  phoneNumber: string
  emailVerified: boolean
  isActive: boolean
  issuer: string
  roles: RoleDto[]
  roleGroups: RoleGroupDto[]
  primaryTenantId: string | null
  tenants: TenantDto[]
  departments: DepartmentDto[]
  createdAt: string
}

export interface UpdateProfileRequest {
  firstName?: string
  lastName?: string
  phoneNumber?: string
  email?: string
}

export interface PagedResult<T> {
  items: T[]
  totalCount: number
  pageNumber: number
  pageSize: number
  totalPages: number
}

// IdP
export interface IdpDto {
  id: string
  name: string
  issuer: string
  description: string
  loginUrl: string
  idpType: number
  isPrimary: boolean
  enabled: boolean
  autoProvisionEnabled: boolean
  authority: string
  expectedAudiences: string
  allowedAlgs: string
  requiredScopes: string
  claimMapping: string
  clockSkewSeconds: number
  tenantName: string
}

export interface CreateIdpRequest {
  name: string
  issuer: string
  authority: string
  description: string
  loginUrl: string
  idpType: number
  isPrimary: boolean
  enabled: boolean
  autoProvisionEnabled: boolean
  expectedAudiences: string
  allowedAlgs: string
  requiredScopes: string
  claimMapping: string
  clockSkewSeconds: number
}

export interface TenantDto {
  id: string
  name: string
  description: string
}

export interface DepartmentDto {
  id: string
  name: string
  description: string
  tenantId: string
  tenantName: string
}

export interface CreateRoleRequest {
  name: string
  description: string
  tenantId: string
}

export interface CreateRoleGroupRequest {
  name: string
  description: string
  tenantId: string
}

export interface CreatePermissionRequest {
  name: string
  description: string
}

export interface CreateTenantRequest {
  name: string
  description: string
}

export interface CreateDepartmentRequest {
  name: string
  description: string
  tenantId: string
}

// ABAC Policies
export interface PolicyConditionDto {
  templateName: string
  parameters?: Record<string, unknown> | null
}

export interface PolicyDefinitionDto {
  id: string | null
  tenantId: string
  name: string
  resourceType: string
  action: string
  conditions: PolicyConditionDto[]
  isActive: boolean
  isPlatformDefault: boolean
  updatedAt: string
}

export interface TemplateDto {
  name: string
  description: string
}

export interface CreatePolicyRequest {
  name: string
  resourceType: string
  action: string
  conditions: PolicyConditionDto[]
}

export interface UpdatePolicyRequest {
  name: string
  conditions: PolicyConditionDto[]
}
