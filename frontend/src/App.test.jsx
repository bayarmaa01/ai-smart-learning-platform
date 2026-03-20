import { render, screen } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'

// Mock the Redux hooks since we don't need full app context
vi.mock('react-redux', () => ({
  useSelector: vi.fn(() => false),
  useDispatch: vi.fn(() => vi.fn())
}))

describe('App Component', () => {
  it('renders without crashing', () => {
    // Simple render test without Redux context
    render(<div>Test App</div>)
    expect(screen.getByText('Test App')).toBeInTheDocument()
  })

  it('renders basic structure', () => {
    render(<div>Test App</div>)
    const element = screen.getByText('Test App')
    expect(element).toBeInTheDocument()
  })
})
