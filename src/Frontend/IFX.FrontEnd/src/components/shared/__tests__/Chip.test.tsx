import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { Chip } from '../Chip'

describe('Chip', () => {
  it('renders the label', () => {
    render(<Chip label="Admin" />)
    expect(screen.getByText('Admin')).toBeInTheDocument()
  })

  it('does not render remove button when onRemove is not provided', () => {
    render(<Chip label="Admin" />)
    expect(screen.queryByRole('button')).not.toBeInTheDocument()
  })

  it('renders remove button when onRemove is provided', () => {
    render(<Chip label="Admin" onRemove={() => {}} />)
    expect(screen.getByRole('button')).toBeInTheDocument()
  })

  it('calls onRemove when remove button is clicked', async () => {
    const onRemove = vi.fn()
    render(<Chip label="Admin" onRemove={onRemove} />)
    await userEvent.click(screen.getByRole('button'))
    expect(onRemove).toHaveBeenCalledTimes(1)
  })
})
