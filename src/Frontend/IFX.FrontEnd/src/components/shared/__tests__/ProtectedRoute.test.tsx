import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { describe, expect, it, vi } from 'vitest'
import { ProtectedRoute } from '../ProtectedRoute'

vi.mock('../../../contexts/AuthContext', () => ({
  useAuth: vi.fn(),
}))

import { useAuth } from '../../../contexts/AuthContext'
const mockUseAuth = vi.mocked(useAuth)

function authState(isAuthenticated: boolean, isLoading: boolean): ReturnType<typeof useAuth> {
  return {
    user: null,
    isAuthenticated,
    isLoading,
    selectedTenantId: null,
    setSelectedTenantId: vi.fn(),
    login: vi.fn(async () => {}),
    logout: vi.fn(),
    refreshUser: vi.fn(async () => {}),
    globalRoles: [],
    isGlobalUser: false,
    isGlobalAdmin: false,
    hasGlobalRole: vi.fn(() => false),
  }
}

describe('ProtectedRoute', () => {
  it('shows spinner while loading', () => {
    mockUseAuth.mockReturnValue(authState(false, true))
    const { container } = render(
      <MemoryRouter><ProtectedRoute><p>Content</p></ProtectedRoute></MemoryRouter>
    )
    expect(container.querySelector('.spinner')).toBeInTheDocument()
    expect(screen.queryByText('Content')).not.toBeInTheDocument()
  })

  it('renders children when authenticated', () => {
    mockUseAuth.mockReturnValue(authState(true, false))
    render(
      <MemoryRouter><ProtectedRoute><p>Protected Content</p></ProtectedRoute></MemoryRouter>
    )
    expect(screen.getByText('Protected Content')).toBeInTheDocument()
  })

  it('redirects to /login when not authenticated', () => {
    mockUseAuth.mockReturnValue(authState(false, false))
    render(
      <MemoryRouter initialEntries={['/dashboard']}>
        <ProtectedRoute><p>Protected Content</p></ProtectedRoute>
      </MemoryRouter>
    )
    expect(screen.queryByText('Protected Content')).not.toBeInTheDocument()
  })
})
