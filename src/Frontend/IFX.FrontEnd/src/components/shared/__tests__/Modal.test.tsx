import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { Modal } from '../Modal'

describe('Modal', () => {
  it('renders title and children', () => {
    render(<Modal title="Test Modal" onClose={() => {}}><p>Modal body</p></Modal>)
    expect(screen.getByText('Test Modal')).toBeInTheDocument()
    expect(screen.getByText('Modal body')).toBeInTheDocument()
  })

  it('calls onClose when × button is clicked', async () => {
    const onClose = vi.fn()
    render(<Modal title="Test" onClose={onClose}><span /></Modal>)
    await userEvent.click(screen.getByRole('button', { name: '×' }))
    expect(onClose).toHaveBeenCalledTimes(1)
  })

  it('calls onClose when Escape key is pressed', async () => {
    const onClose = vi.fn()
    render(<Modal title="Test" onClose={onClose}><span /></Modal>)
    await userEvent.keyboard('{Escape}')
    expect(onClose).toHaveBeenCalledTimes(1)
  })

  it('renders optional footer', () => {
    render(
      <Modal title="Test" onClose={() => {}} footer={<button>Save</button>}>
        <span />
      </Modal>
    )
    expect(screen.getByRole('button', { name: 'Save' })).toBeInTheDocument()
  })

  it('does not render footer section when footer prop is absent', () => {
    const { container } = render(<Modal title="Test" onClose={() => {}}><span /></Modal>)
    expect(container.querySelector('.modal-footer')).not.toBeInTheDocument()
  })
})
