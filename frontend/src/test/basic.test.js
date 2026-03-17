import { describe, it, expect } from 'vitest'

describe('Basic Tests', () => {
  it('should pass basic math test', () => {
    expect(2 + 2).toBe(4)
  })

  it('should handle string operations', () => {
    const str = 'hello'
    expect(str.toUpperCase()).toBe('HELLO')
  })

  it('should handle array operations', () => {
    const arr = [1, 2, 3]
    expect(arr.length).toBe(3)
    expect(arr.includes(2)).toBe(true)
  })
})
