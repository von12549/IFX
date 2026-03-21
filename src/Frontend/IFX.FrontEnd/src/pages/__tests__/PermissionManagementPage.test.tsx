import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { describe, expect, it } from 'vitest'
import { PermissionManagementPage } from '../PermissionManagementPage'
import { server } from '../../test/server'
import { http, HttpResponse } from 'msw'

const API = 'http://localhost:5010'

function renderPage() {
  return render(<MemoryRouter><PermissionManagementPage /></MemoryRouter>)
}

describe('PermissionManagementPage', () => {
  it('renders permission list', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Users.Read')).toBeInTheDocument())
    expect(screen.getByText('Roles.Write')).toBeInTheDocument()
  })

  it('default sort is by Name ascending (Roles.Write before Users.Read)', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Users.Read')).toBeInTheDocument())
    const rows = screen.getAllByRole('row').slice(1)
    expect(rows[0]).toHaveTextContent('Roles.Write')
    expect(rows[1]).toHaveTextContent('Users.Read')
  })

  it('clicking Name header toggles to descending (Users.Read before Roles.Write)', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Users.Read')).toBeInTheDocument())
    await userEvent.click(screen.getByText(/^Name/))
    const rows = screen.getAllByRole('row').slice(1)
    expect(rows[0]).toHaveTextContent('Users.Read')
  })

  it('switches sort to Description column and shows sort-active', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Users.Read')).toBeInTheDocument())
    await userEvent.click(screen.getByText(/^Description/))
    const descHeader = screen.getByRole('columnheader', { name: /Description/ })
    expect(descHeader.querySelector('.sort-active')).toBeInTheDocument()
  })

  it('opens Create Permission modal', async () => {
    renderPage()
    await waitFor(() => expect(screen.getByText('Users.Read')).toBeInTheDocument())
    await userEvent.click(screen.getByRole('button', { name: /create permission/i }))
    expect(screen.getByText('Create Permission')).toBeInTheDocument()
  })

  it('calls permissionApi.create when saving new permission', async () => {
    let created = false
    server.use(
      http.post(`${API}/api/v1/permission`, () => {
        created = true
        return HttpResponse.json({ success: true, data: { id: 'x', name: 'Test.Perm', description: 'desc' } }, { status: 201 })
      })
    )
    renderPage()
    await waitFor(() => expect(screen.getByText('Users.Read')).toBeInTheDocument())
    await userEvent.click(screen.getByRole('button', { name: /create permission/i }))

    // Modal is open — type into the inputs (no for/htmlFor, use getAllByRole)
    const inputs = screen.getAllByRole('textbox')
    await userEvent.type(inputs[0], 'Test.Perm')
    await userEvent.type(inputs[1], 'desc')
    await userEvent.click(screen.getByRole('button', { name: /^save/i }))
    await waitFor(() => expect(created).toBe(true))
  })

  it('opens delete confirmation modal and calls delete', async () => {
    let deleted = false
    server.use(
      http.delete(`${API}/api/v1/permission/:id`, () => {
        deleted = true
        return HttpResponse.json({ success: true })
      })
    )
    renderPage()
    await waitFor(() => expect(screen.getByText('Users.Read')).toBeInTheDocument())
    const deleteButtons = screen.getAllByRole('button', { name: /delete/i })
    await userEvent.click(deleteButtons[0])
    const confirmModal = screen.getByText(/are you sure/i).closest('.modal')!
    expect(confirmModal).toBeInTheDocument()
    await userEvent.click(within(confirmModal as HTMLElement).getByRole('button', { name: /^delete$/i }))
    await waitFor(() => expect(deleted).toBe(true))
  })
})
