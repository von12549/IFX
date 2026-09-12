import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { tokenStorage } from '../client'

describe('tokenStorage', () => {
  beforeEach(() => localStorage.clear())
  afterEach(() => localStorage.clear())

  it('saves and retrieves access token', () => {
    tokenStorage.save({ accessToken: 'at', refreshToken: 'rt', idToken: 'it', expiresIn: 3600 })
    expect(tokenStorage.getAccessToken()).toBe('at')
  })

  it('saves and retrieves refresh token', () => {
    tokenStorage.save({ accessToken: 'at', refreshToken: 'rt', idToken: 'it', expiresIn: 3600 })
    expect(tokenStorage.getRefreshToken()).toBe('rt')
  })

  it('returns null when no token is stored', () => {
    expect(tokenStorage.getAccessToken()).toBeNull()
  })

  it('clear removes all tokens', () => {
    tokenStorage.save({ accessToken: 'at', refreshToken: 'rt', idToken: 'it', expiresIn: 3600 })
    tokenStorage.clear()
    expect(tokenStorage.getAccessToken()).toBeNull()
    expect(tokenStorage.getRefreshToken()).toBeNull()
  })

  it('sets expiry in the future', () => {
    const before = Date.now()
    tokenStorage.save({ accessToken: 'at', refreshToken: 'rt', idToken: 'it', expiresIn: 3600 })
    const expiry = Number(localStorage.getItem('ifx_token_expiry'))
    expect(expiry).toBeGreaterThan(before)
    expect(expiry).toBeLessThanOrEqual(before + 3600 * 1000 + 100)
  })
})
