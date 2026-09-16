import { act, render, screen, waitFor } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router-dom'
import { describe, expect, it } from 'vitest'
import { http, HttpResponse } from 'msw'
import { RoleDetailPage } from '../RoleDetailPage'
import { RoleGroupDetailPage } from '../RoleGroupDetailPage'
import { UserDetailPage } from '../UserDetailPage'
import { server } from '../../test/server'
import { mockPermissions, mockRoles, mockUser } from '../../test/handlers'

const API = 'http://localhost:5010'

describe('detail page loading', () => {
  it('loads each role route exactly once', async () => {
    const requestedIds: string[] = []
    server.use(
      http.get(`${API}/api/v1/role/:id`, ({ params }) => {
        const id = String(params.id)
        requestedIds.push(id)
        return HttpResponse.json({
          success: true,
          data: { id, name: `Role ${id}`, description: '', tenantId: 'tenant-1', tenantName: 'Tenant', permissions: [] },
        })
      }),
      http.get(`${API}/api/v1/permission/`, () => HttpResponse.json({ success: true, data: mockPermissions }))
    )
    const router = createMemoryRouter(
      [{ path: '/roles/:roleId', element: <RoleDetailPage /> }],
      { initialEntries: ['/roles/role-1'] },
    )

    render(<RouterProvider router={router} />)
    await screen.findByRole('heading', { name: 'Role role-1' })

    await act(async () => { await router.navigate('/roles/role-2') })
    await screen.findByRole('heading', { name: 'Role role-2' })
    expect(requestedIds).toEqual(['role-1', 'role-2'])
  })

  it('reloads a role group once after the route id changes', async () => {
    let groupRequests = 0
    server.use(
      http.get(`${API}/api/v1/rolegroup/`, () => {
        groupRequests += 1
        return HttpResponse.json({
          success: true,
          data: [
            { id: 'group-1', name: 'Group One', description: '', tenantId: 'tenant-1', roles: [] },
            { id: 'group-2', name: 'Group Two', description: '', tenantId: 'tenant-1', roles: [] },
          ],
        })
      }),
      http.get(`${API}/api/v1/role/`, () => HttpResponse.json({ success: true, data: mockRoles }))
    )
    const router = createMemoryRouter(
      [{ path: '/rolegroups/:roleGroupId', element: <RoleGroupDetailPage /> }],
      { initialEntries: ['/rolegroups/group-1'] },
    )

    render(<RouterProvider router={router} />)
    await screen.findByRole('heading', { name: 'Group One' })

    await act(async () => { await router.navigate('/rolegroups/group-2') })
    await screen.findByRole('heading', { name: 'Group Two' })
    expect(groupRequests).toBe(2)
  })

  it('loads each user route exactly once', async () => {
    const requestedIds: string[] = []
    server.use(
      http.get(`${API}/api/v1/usermanagement/users/:id`, ({ params }) => {
        const id = String(params.id)
        requestedIds.push(id)
        return HttpResponse.json({ success: true, data: { ...mockUser, id, displayName: `User ${id}` } })
      }),
      http.get(`${API}/api/v1/role/`, () => HttpResponse.json({ success: true, data: mockRoles })),
      http.get(`${API}/api/v1/rolegroup/`, () => HttpResponse.json({ success: true, data: [] }))
    )
    const router = createMemoryRouter(
      [{ path: '/users/:userId', element: <UserDetailPage /> }],
      { initialEntries: ['/users/user-1'] },
    )

    render(<RouterProvider router={router} />)
    await screen.findByRole('heading', { name: 'User user-1' })

    await act(async () => { await router.navigate('/users/user-2') })
    await screen.findByRole('heading', { name: 'User user-2' })
    await waitFor(() => expect(requestedIds).toEqual(['user-1', 'user-2']))
  })
})
