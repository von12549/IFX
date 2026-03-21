import { act, render, screen, waitFor } from '@testing-library/react'
import { beforeEach, describe, expect, it } from 'vitest'
import { AuthProvider, useAuth } from '../AuthContext'
import { tokenStorage } from '../../api/client'
import { server } from '../../test/server'
import { http, HttpResponse } from 'msw'

const API = 'http://localhost:5010'

function TestConsumer() {
  const { user, isAuthenticated, isLoading } = useAuth()
  if (isLoading) return <span>loading</span>
  return (
    <div>
      <span data-testid="auth">{isAuthenticated ? 'yes' : 'no'}</span>
      <span data-testid="email">{user?.email ?? ''}</span>
    </div>
  )
}

describe('AuthContext', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('starts unauthenticated when no token in storage', async () => {
    render(<AuthProvider><TestConsumer /></AuthProvider>)
    await waitFor(() => expect(screen.queryByText('loading')).not.toBeInTheDocument())
    expect(screen.getByTestId('auth').textContent).toBe('no')
  })

  it('restores session on mount when token exists', async () => {
    tokenStorage.save({ accessToken: 'at', refreshToken: 'rt', idToken: 'it', expiresIn: 3600 })
    render(<AuthProvider><TestConsumer /></AuthProvider>)
    await waitFor(() => expect(screen.queryByText('loading')).not.toBeInTheDocument())
    expect(screen.getByTestId('auth').textContent).toBe('yes')
    expect(screen.getByTestId('email').textContent).toBe('test@example.com')
  })

  it('sets unauthenticated when profile fetch fails', async () => {
    server.use(
      http.get(`${API}/api/v1/user/profile`, () => HttpResponse.json({}, { status: 401 }))
    )
    tokenStorage.save({ accessToken: 'at', refreshToken: 'rt', idToken: 'it', expiresIn: 3600 })
    render(<AuthProvider><TestConsumer /></AuthProvider>)
    await waitFor(() => expect(screen.queryByText('loading')).not.toBeInTheDocument())
    expect(screen.getByTestId('auth').textContent).toBe('no')
  })

  it('login saves tokens and fetches profile', async () => {
    function LoginButton() {
      const { login, isAuthenticated } = useAuth()
      return (
        <div>
          <button onClick={() => login({ accessToken: 'new-at', refreshToken: 'new-rt', idToken: '', expiresIn: 3600 })}>
            Login
          </button>
          <span data-testid="auth">{isAuthenticated ? 'yes' : 'no'}</span>
        </div>
      )
    }

    render(<AuthProvider><LoginButton /></AuthProvider>)
    await waitFor(() => expect(screen.getByTestId('auth')).toBeInTheDocument())

    await act(async () => {
      screen.getByRole('button', { name: 'Login' }).click()
    })

    await waitFor(() => expect(screen.getByTestId('auth').textContent).toBe('yes'))
    expect(tokenStorage.getAccessToken()).toBe('new-at')
  })

  it('logout clears tokens and sets unauthenticated', async () => {
    tokenStorage.save({ accessToken: 'at', refreshToken: 'rt', idToken: 'it', expiresIn: 3600 })

    function LogoutButton() {
      const { logout, isAuthenticated, isLoading } = useAuth()
      if (isLoading) return <span>loading</span>
      return (
        <div>
          <button onClick={logout}>Logout</button>
          <span data-testid="auth">{isAuthenticated ? 'yes' : 'no'}</span>
        </div>
      )
    }

    render(<AuthProvider><LogoutButton /></AuthProvider>)
    await waitFor(() => expect(screen.queryByText('loading')).not.toBeInTheDocument())
    expect(screen.getByTestId('auth').textContent).toBe('yes')

    await act(async () => {
      screen.getByRole('button', { name: 'Logout' }).click()
    })

    expect(screen.getByTestId('auth').textContent).toBe('no')
    expect(tokenStorage.getAccessToken()).toBeNull()
  })
})
