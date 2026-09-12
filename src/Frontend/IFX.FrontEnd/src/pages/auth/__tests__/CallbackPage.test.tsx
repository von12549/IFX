import { render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { CallbackPage } from '../CallbackPage'

const mockLogin = vi.fn()
const mockNavigate = vi.fn()

vi.mock('../../../contexts/AuthContext', () => ({
  useAuth: () => ({ login: mockLogin }),
}))

vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual<typeof import('react-router-dom')>('react-router-dom')
  return { ...actual, useNavigate: () => mockNavigate }
})

function renderWithHash(hash: string) {
  window.location.hash = hash
  return render(<MemoryRouter><CallbackPage /></MemoryRouter>)
}

describe('CallbackPage', () => {
  beforeEach(() => {
    mockLogin.mockReset()
    mockNavigate.mockReset()
    mockLogin.mockResolvedValue(undefined)
  })

  it('shows spinner while processing', () => {
    mockLogin.mockReturnValue(new Promise(() => {})) // never resolves
    renderWithHash('#access_token=tok&expires_in=3600')
    expect(screen.getByText(/signing you in/i)).toBeInTheDocument()
  })

  it('calls login with parsed tokens and navigates to /profile', async () => {
    renderWithHash('#access_token=mytoken&id_token=idtok&refresh_token=reftok&expires_in=1800')
    await waitFor(() => expect(mockNavigate).toHaveBeenCalledWith('/profile', { replace: true }))
    expect(mockLogin).toHaveBeenCalledWith({
      accessToken: 'mytoken',
      idToken: 'idtok',
      refreshToken: 'reftok',
      expiresIn: 1800,
    })
  })

  it('defaults expiresIn to 3600 when missing', async () => {
    renderWithHash('#access_token=mytoken')
    await waitFor(() => expect(mockNavigate).toHaveBeenCalled())
    expect(mockLogin).toHaveBeenCalledWith(expect.objectContaining({ expiresIn: 3600 }))
  })

  it('shows error when error param is in hash', async () => {
    renderWithHash('#error=access_denied&error_description=User+denied+access')
    await waitFor(() => expect(screen.getByText('User denied access')).toBeInTheDocument())
  })

  it('shows error when no access_token in hash', async () => {
    renderWithHash('#id_token=only')
    await waitFor(() => expect(screen.getByText(/no access token/i)).toBeInTheDocument())
  })

  it('shows error when login throws', async () => {
    mockLogin.mockRejectedValue(new Error('Profile failed'))
    renderWithHash('#access_token=tok')
    await waitFor(() => expect(screen.getByText(/failed to load your profile/i)).toBeInTheDocument())
  })
})
