import { http, HttpResponse } from 'msw'

const API = 'http://localhost:5010'

export const mockUser = {
  id: 'user-1',
  email: 'test@example.com',
  displayName: 'Test User',
  firstName: 'Test',
  lastName: 'User',
  birthDate: '',
  phoneNumber: '',
  emailVerified: true,
  isActive: true,
  issuer: 'https://cognito.example.com',
  roles: [],
  roleGroups: [],
  createdAt: '2024-01-01T00:00:00Z',
}

export const mockRoles = [
  { id: 'role-1', name: 'Admin', description: 'Administrator role' },
  { id: 'role-2', name: 'Viewer', description: 'Read-only access' },
]

export const mockPermissions = [
  { id: 'perm-1', name: 'Users.Read', description: 'Read users' },
  { id: 'perm-2', name: 'Roles.Write', description: 'Manage roles' },
]

export const handlers = [
  http.get(`${API}/api/v1/user/profile`, () =>
    HttpResponse.json({ success: true, data: mockUser })
  ),

  http.get(`${API}/api/v1/role`, () =>
    HttpResponse.json({ success: true, data: mockRoles })
  ),

  http.post(`${API}/api/v1/role`, () =>
    HttpResponse.json({ success: true, data: { id: 'role-new', name: 'New Role', description: '' } }, { status: 201 })
  ),

  http.get(`${API}/api/v1/permission`, () =>
    HttpResponse.json({ success: true, data: mockPermissions })
  ),

  http.post(`${API}/api/v1/permission`, () =>
    HttpResponse.json({ success: true, data: { id: 'perm-new', name: 'New.Perm', description: '' } }, { status: 201 })
  ),

  http.put(`${API}/api/v1/permission/:id`, () =>
    HttpResponse.json({ success: true })
  ),

  http.delete(`${API}/api/v1/permission/:id`, () =>
    HttpResponse.json({ success: true })
  ),

  http.post(`${API}/api/v1/auth/refresh`, () =>
    HttpResponse.json({
      success: true,
      data: { accessToken: 'new-access-token', refreshToken: 'new-refresh-token', idToken: '', expiresIn: 3600 },
    })
  ),

  http.get(`${API}/api/v1/auth/oauth/authorize`, () =>
    HttpResponse.json({ success: true, data: { authorizationUrl: 'https://auth.example.com/login', state: 'abc' } })
  ),
]
