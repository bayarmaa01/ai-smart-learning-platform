import { describe, it, expect } from 'vitest'

describe('Example Test', () => {
  it('should pass', () => {
    expect(true).toBe(true)
  })

  it('should handle DOM elements', () => {
    document.body.innerHTML = '<div class="test">Hello</div>'
    const element = document.querySelector('.test')
    expect(element.textContent).toBe('Hello')
  })
})
