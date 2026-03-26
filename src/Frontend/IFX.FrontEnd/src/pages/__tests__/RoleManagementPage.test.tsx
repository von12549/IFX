import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { describe, expect, it, vi } from 'vitest'
import { RoleManagementPage } from '../RoleManagementPage'
import { server } from '../../test/server'
import { http, HttpResponse } from 'msw'

vi.mock('../../contexts/AuthContext', () => ({
  useAuth: () => ({ selectedTenantId: 'test-tenant-id', isGlobalUser: false }),
}))

const API = 'http://localhost:5010'

function renderPage() {
  return render(<MemoryRouter><RoleManagementPage /></MemoryRouter>)
}

describe('RoleManagementPage', () => {
  it('shows spinner while loading', () => {
    server.use(http.get(`${API}/api/v1/role`, () => new Promise(() => {})))
    renderPage()
    expect(document.querySelector('.spinner')).toBeInTheDocument()
  })

  it('renders role list from API response', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument())
    expect(screen.getByText('Viewer')).toBeInTheDocument()
  })

  it('shows error alert on API failure', async () => {
    server.use(http.get(`${API}/api/v1/role`, () => HttpResponse.json({}, { status: 500 })))
    renderPage()
    await waitFor(() => expect(screen.getByText(/failed to load roles/i)).toBeInTheDocument())
  })

  it('default sort is by Name ascending (Admin before Viewer)', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument())
    const rows = screen.getAllByRole('row').slice(1) // skip header
    expect(rows[0]).toHaveTextContent('Admin')
    expect(rows[1]).toHaveTextContent('Viewer')
  })

  it('clicking Name header once toggles to descending (Viewer before Admin)', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument())
    await userEvent.click(screen.getByText(/^Name/))
    const rows = screen.getAllByRole('row').slice(1)
    expect(rows[0]).toHaveTextContent('Viewer')
    expect(rows[1]).toHaveTextContent('Admin')
  })

  it('clicking Name header twice returns to ascending', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument())
    await userEvent.click(screen.getByText(/^Name/))
    await userEvent.click(screen.getByText(/^Name/))
    const rows = screen.getAllByRole('row').slice(1)
    expect(rows[0]).toHaveTextContent('Admin')
    expect(rows[1]).toHaveTextContent('Viewer')
  })

  it('switching to Description column resets direction to ascending and sets sort-active', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument())
    await userEvent.click(screen.getByText(/^Name/)) // now name desc
    await userEvent.click(screen.getByText(/^Description/)) // switch to desc asc
    const { container } = { container: document.body }
    const descHeader = screen.getByRole('columnheader', { name: /Description/ })
    expect(descHeader.querySelector('.sort-active')).toBeInTheDocument()
    expect(descHeader).toHaveTextContent('↑')
  })

  it('opens Create Role modal when button clicked', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument())
    await userEvent.click(screen.getByRole('button', { name: /create role/i }))
    expect(screen.getByText('Create Role')).toBeInTheDocument()
  })
})
