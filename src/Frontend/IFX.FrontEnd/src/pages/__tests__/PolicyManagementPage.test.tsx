import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { PolicyManagementPage } from '../PolicyManagementPage'
import { server } from '../../test/server'
import { http, HttpResponse } from 'msw'

const authState = vi.hoisted(() => ({ selectedTenantId: 'tenant-1' }))

vi.mock('../../contexts/AuthContext', () => ({
  useAuth: () => ({ selectedTenantId: authState.selectedTenantId, isGlobalUser: false }),
}))

const API = 'http://localhost:5010'

function renderPage() {
  return render(<MemoryRouter><PolicyManagementPage /></MemoryRouter>)
}

describe('PolicyManagementPage', () => {
  beforeEach(() => { authState.selectedTenantId = 'tenant-1' })

  it('renders policy table with Name, Resource Type, Action columns', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Read Own Profile')).toBeInTheDocument())
    expect(screen.getByText('user')).toBeInTheDocument()
    expect(screen.getByText('read')).toBeInTheDocument()
  })

  it('tenant override rows show Edit and Delete buttons', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Read Own Profile')).toBeInTheDocument())
    expect(screen.getByRole('button', { name: /edit/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /delete/i })).toBeInTheDocument()
  })

  it('platform default rows show Override badge and Override button, no Delete', async () => {
    server.use(
      http.get(`${API}/api/v1/policy/`, () =>
        HttpResponse.json({
          success: true,
          data: [{
            id: null,
            tenantId: 'tenant-1',
            name: 'Read Document (Platform Default)',
            resourceType: 'document',
            action: 'read',
            conditions: [{ templateName: 'SameTenant', parameters: null }],
            isActive: true,
            isPlatformDefault: true,
            updatedAt: '2026-03-25T10:00:00Z',
          }],
        })
      )
    )
    renderPage()
    await waitFor(() => expect(screen.getByText('Platform Default')).toBeInTheDocument())
    expect(screen.getByRole('button', { name: /override/i })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /^delete$/i })).not.toBeInTheDocument()
  })

  it('opens Create Policy modal when clicking + Create Policy', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Read Own Profile')).toBeInTheDocument())
    await userEvent.click(screen.getByRole('button', { name: /create policy/i }))
    expect(screen.getByText('Create Policy')).toBeInTheDocument()
    expect(screen.getByPlaceholderText(/e\.g\. user/i)).toBeInTheDocument()
  })

  it('submit is disabled when no conditions selected', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Read Own Profile')).toBeInTheDocument())
    await userEvent.click(screen.getByRole('button', { name: /create policy/i }))
    const saveButton = screen.getByRole('button', { name: /^save/i })
    expect(saveButton).toBeDisabled()
  })

  it('opens Edit modal when clicking Edit on a tenant override row', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Read Own Profile')).toBeInTheDocument())
    await userEvent.click(screen.getByRole('button', { name: /edit/i }))
    expect(screen.getByText('Edit Policy')).toBeInTheDocument()
  })

  it('shows delete confirmation dialog with revert message', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Read Own Profile')).toBeInTheDocument())
    await userEvent.click(screen.getByRole('button', { name: /delete/i }))
    const revertMsg = screen.getByText(/revert to the platform default/i)
    expect(revertMsg).toBeInTheDocument()
    expect(revertMsg.closest('.modal')).toHaveTextContent('Read Own Profile')
  })

  it('calls delete API and reloads after confirming delete', async () => {
    let deleted = false
    server.use(
      http.delete(`${API}/api/v1/policy/:id`, () => {
        deleted = true
        return HttpResponse.json({ success: true })
      })
    )
    renderPage()
    await waitFor(() => expect(screen.getByText('Read Own Profile')).toBeInTheDocument())
    await userEvent.click(screen.getByRole('button', { name: /delete/i }))
    const modal = screen.getByText(/revert to the platform default/i).closest('.modal')!
    await userEvent.click(within(modal as HTMLElement).getByRole('button', { name: /^delete$/i }))
    await waitFor(() => expect(deleted).toBe(true))
  })

  it('shows empty state message when no policies', async () => {
    server.use(
      http.get(`${API}/api/v1/policy/`, () =>
        HttpResponse.json({ success: true, data: [] })
      )
    )
    renderPage()
    await waitFor(() => expect(screen.getByText(/no policies found/i)).toBeInTheDocument())
  })

  it('reloads once when the selected tenant changes and not on an equivalent rerender', async () => {
    let policyRequests = 0
    server.use(
      http.get(`${API}/api/v1/policy/`, () => {
        policyRequests += 1
        return HttpResponse.json({ success: true, data: [] })
      })
    )

    const view = renderPage()
    await waitFor(() => expect(policyRequests).toBe(1))

    view.rerender(<MemoryRouter><PolicyManagementPage /></MemoryRouter>)
    await new Promise(resolve => setTimeout(resolve, 0))
    expect(policyRequests).toBe(1)

    authState.selectedTenantId = 'tenant-2'
    view.rerender(<MemoryRouter><PolicyManagementPage /></MemoryRouter>)
    await waitFor(() => expect(policyRequests).toBe(2))
  })
})
