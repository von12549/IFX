import { createContext, useCallback, useContext, useEffect, useState } from 'react'
import { tokenStorage } from '../api/client'
import { userApi } from '../api/user'
import type { UserProfileDto } from '../types/api'

interface AuthContextValue {
  user: UserProfileDto | null
  isAuthenticated: boolean
  isLoading: boolean
  selectedTenantId: string | null
  setSelectedTenantId(id: string): void
  login(tokens: { accessToken: string; refreshToken: string; idToken: string; expiresIn: number }): Promise<void>
  logout(): void
  refreshUser(): Promise<void>
}

const AuthContext = createContext<AuthContextValue>(null!)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<UserProfileDto | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [selectedTenantId, setSelectedTenantId] = useState<string | null>(null)

  const loadProfile = useCallback(async () => {
    const resp = await userApi.getProfile()
    const profile = resp.data?.data ?? null
    setUser(profile)
    setSelectedTenantId(prev =>
      prev ?? (profile?.primaryTenantId ?? profile?.tenants?.[0]?.id ?? null)
    )
  }, [])

  // Restore session on mount
  useEffect(() => {
    const token = tokenStorage.getAccessToken()
    if (token) {
      loadProfile()
        .catch(() => { setUser(null); tokenStorage.clear() })
        .finally(() => setIsLoading(false))
    } else {
      setIsLoading(false)
    }
  }, [loadProfile])

  const login = useCallback(async (tokens: { accessToken: string; refreshToken: string; idToken: string; expiresIn: number }) => {
    tokenStorage.save(tokens)
    try {
      await loadProfile()
    } catch {
      tokenStorage.clear()
      throw new Error('Failed to load profile')
    }
  }, [loadProfile])

  const logout = useCallback(() => {
    tokenStorage.clear()
    setUser(null)
    setSelectedTenantId(null)
  }, [])

  const refreshUser = useCallback(async () => {
    await loadProfile()
  }, [loadProfile])

  return (
    <AuthContext.Provider value={{ user, isAuthenticated: !!user, isLoading, selectedTenantId, setSelectedTenantId, login, logout, refreshUser }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
