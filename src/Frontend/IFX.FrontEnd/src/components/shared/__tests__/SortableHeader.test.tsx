import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { SortableHeader } from '../SortableHeader'

function renderInTable(ui: React.ReactNode) {
  return render(<table><thead><tr>{ui}</tr></thead></table>)
}

describe('SortableHeader', () => {
  it('renders the label', () => {
    renderInTable(<SortableHeader label="Name" col="name" sortCol="name" sortDir="asc" onSort={() => {}} />)
    expect(screen.getByText(/Name/)).toBeInTheDocument()
  })

  it('shows up arrow when active and ascending', () => {
    renderInTable(<SortableHeader label="Name" col="name" sortCol="name" sortDir="asc" onSort={() => {}} />)
    expect(screen.getByRole('columnheader')).toHaveTextContent('↑')
  })

  it('shows down arrow when active and descending', () => {
    renderInTable(<SortableHeader label="Name" col="name" sortCol="name" sortDir="desc" onSort={() => {}} />)
    expect(screen.getByRole('columnheader')).toHaveTextContent('↓')
  })

  it('shows neutral icon when column is not active', () => {
    renderInTable(<SortableHeader label="Name" col="name" sortCol="other" sortDir="asc" onSort={() => {}} />)
    expect(screen.getByRole('columnheader')).toHaveTextContent('↕')
  })

  it('applies sort-active class to the sort icon span when column is active', () => {
    const { container } = renderInTable(
      <SortableHeader label="Name" col="name" sortCol="name" sortDir="asc" onSort={() => {}} />
    )
    expect(container.querySelector('.sort-active')).toBeInTheDocument()
  })

  it('does not apply sort-active when column is not active', () => {
    const { container } = renderInTable(
      <SortableHeader label="Name" col="name" sortCol="other" sortDir="asc" onSort={() => {}} />
    )
    expect(container.querySelector('.sort-active')).not.toBeInTheDocument()
  })

  it('calls onSort with column name when clicked', async () => {
    const onSort = vi.fn()
    renderInTable(<SortableHeader label="Name" col="name" sortCol="other" sortDir="asc" onSort={onSort} />)
    await userEvent.click(screen.getByRole('columnheader'))
    expect(onSort).toHaveBeenCalledWith('name')
  })
})
