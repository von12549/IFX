import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { LoginPage } from '../LoginPage'
import { server } from '../../../test/server'
import { http, HttpResponse } from 'msw'

const API = 'http://localhost:5010'

function renderPage() {
  return render(<MemoryRouter><LoginPage /></MemoryRouter>)
}

describe('LoginPage', () => {
  let originalLocation: Location

  beforeEach(() => {
    originalLocation = window.location
    Object.defineProperty(window, 'location', {
      writable: true,
      value: { href: 'http://localhost:3000/' },
    })
  })

  afterEach(() => {
    Object.defineProperty(window, 'location', {
      writable: true,
      value: originalLocation,
    })
  })

  it('renders sign in button', () => {
    renderPage()
    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument()
  })

  it('redirects to authorization URL on button click', async () => {
    renderPage()
    await userEvent.click(screen.getByRole('button', { name: /sign in/i }))
    await waitFor(() => expect(window.location.href).toBe('https://auth.example.com/login'))
  })

  it('shows "Redirecting..." while waiting for API', async () => {
    server.use(
      http.get(`${API}/api/v1/auth/oauth/authorize`, () => new Promise(() => {}))
    )
    renderPage()
    await userEvent.click(screen.getByRole('button', { name: /sign in/i }))
    expect(screen.getByRole('button', { name: /redirecting/i })).toBeInTheDocument()
  })

  it('shows error when API call fails', async () => {
    server.use(
      http.get(`${API}/api/v1/auth/oauth/authorize`, () =>
        HttpResponse.json({}, { status: 500 })
      )
    )
    renderPage()
    await userEvent.click(screen.getByRole('button', { name: /sign in/i }))
    await waitFor(() => expect(screen.getByText(/failed to connect/i)).toBeInTheDocument())
  })

  it('shows error when API returns no authorization URL', async () => {
    server.use(
      http.get(`${API}/api/v1/auth/oauth/authorize`, () =>
        HttpResponse.json({ success: true, data: {} })
      )
    )
    renderPage()
    await userEvent.click(screen.getByRole('button', { name: /sign in/i }))
    await waitFor(() => expect(screen.getByText(/failed to get authorization url/i)).toBeInTheDocument())
  })
})
