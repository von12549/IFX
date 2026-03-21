import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { describe, expect, it, vi } from 'vitest'
import { ProtectedRoute } from '../ProtectedRoute'

vi.mock('../../../contexts/AuthContext', () => ({
  useAuth: vi.fn(),
}))

import { useAuth } from '../../../contexts/AuthContext'
const mockUseAuth = vi.mocked(useAuth)

describe('ProtectedRoute', () => {
  it('shows spinner while loading', () => {
    mockUseAuth.mockReturnValue({ isAuthenticated: false, isLoading: true } as any)
    const { container } = render(
      <MemoryRouter><ProtectedRoute><p>Content</p></ProtectedRoute></MemoryRouter>
    )
    expect(container.querySelector('.spinner')).toBeInTheDocument()
    expect(screen.queryByText('Content')).not.toBeInTheDocument()
  })

  it('renders children when authenticated', () => {
    mockUseAuth.mockReturnValue({ isAuthenticated: true, isLoading: false } as any)
    render(
      <MemoryRouter><ProtectedRoute><p>Protected Content</p></ProtectedRoute></MemoryRouter>
    )
    expect(screen.getByText('Protected Content')).toBeInTheDocument()
  })

  it('redirects to /login when not authenticated', () => {
    mockUseAuth.mockReturnValue({ isAuthenticated: false, isLoading: false } as any)
    render(
      <MemoryRouter initialEntries={['/dashboard']}>
        <ProtectedRoute><p>Protected Content</p></ProtectedRoute>
      </MemoryRouter>
    )
    expect(screen.queryByText('Protected Content')).not.toBeInTheDocument()
  })
})
