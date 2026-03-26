import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
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
  globalRoles: string[]
  isGlobalUser: boolean
  isGlobalAdmin: boolean
  hasGlobalRole(role: string): boolean
}

const AuthContext = createContext<AuthContextValue>(null!)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<UserProfileDto | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [selectedTenantId, setSelectedTenantIdState] = useState<string | null>(
    () => tokenStorage.getSelectedTenantId()
  )

  const setSelectedTenantId = useCallback((id: string) => {
    tokenStorage.setSelectedTenantId(id)
    setSelectedTenantIdState(id)
  }, [])

  const loadProfile = useCallback(async () => {
    const resp = await userApi.getProfile()
    const profile = resp.data?.data ?? null
    setUser(profile)
    setSelectedTenantIdState(prev => {
      const resolved = prev ?? (profile?.primaryTenantId ?? profile?.tenants?.[0]?.id ?? null)
      tokenStorage.setSelectedTenantId(resolved)
      return resolved
    })
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
    setSelectedTenantIdState(null)
  }, [])

  const refreshUser = useCallback(async () => {
    await loadProfile()
  }, [loadProfile])

  const globalRoles = useMemo(() => user?.globalRoles ?? [], [user])
  const isGlobalUser = useMemo(() => globalRoles.length > 0, [globalRoles])
  const isGlobalAdmin = useMemo(() => globalRoles.includes('PlatformAdmin'), [globalRoles])
  const hasGlobalRole = useCallback((role: string) => globalRoles.includes(role), [globalRoles])

  return (
    <AuthContext.Provider value={{ user, isAuthenticated: !!user, isLoading, selectedTenantId, setSelectedTenantId, login, logout, refreshUser, globalRoles, isGlobalUser, isGlobalAdmin, hasGlobalRole }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
