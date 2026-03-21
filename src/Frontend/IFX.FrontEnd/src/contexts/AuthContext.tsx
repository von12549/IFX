import { createContext, useCallback, useContext, useEffect, useState } from 'react'
import { tokenStorage } from '../api/client'
import { userApi } from '../api/user'
import type { UserProfileDto } from '../types/api'

interface AuthContextValue {
  user: UserProfileDto | null
  isAuthenticated: boolean
  isLoading: boolean
  login(tokens: { accessToken: string; refreshToken: string; idToken: string; expiresIn: number }): Promise<void>
  logout(): void
  refreshUser(): Promise<void>
}

const AuthContext = createContext<AuthContextValue>(null!)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<UserProfileDto | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  const loadProfile = useCallback(async () => {
    try {
      const resp = await userApi.getProfile()
      setUser(resp.data?.data ?? null)
    } catch {
      setUser(null)
    }
  }, [])

  // Restore session on mount
  useEffect(() => {
    const token = tokenStorage.getAccessToken()
    if (token) {
      loadProfile().finally(() => setIsLoading(false))
    } else {
      setIsLoading(false)
    }
  }, [loadProfile])

  const login = useCallback(async (tokens: { accessToken: string; refreshToken: string; idToken: string; expiresIn: number }) => {
    tokenStorage.save(tokens)
    await loadProfile()
  }, [loadProfile])

  const logout = useCallback(() => {
    tokenStorage.clear()
    setUser(null)
  }, [])

  const refreshUser = useCallback(async () => {
    await loadProfile()
  }, [loadProfile])

  return (
    <AuthContext.Provider value={{ user, isAuthenticated: !!user, isLoading, login, logout, refreshUser }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
