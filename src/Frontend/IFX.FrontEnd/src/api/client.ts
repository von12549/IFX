import axios from 'axios'

const API_BASE = 'http://localhost:5010'

const KEYS = {
  accessToken: 'ifx_access_token',
  refreshToken: 'ifx_refresh_token',
  idToken: 'ifx_id_token',
  expiry: 'ifx_token_expiry',
  selectedTenantId: 'ifx_selected_tenant_id',
}

export const tokenStorage = {
  save(tokens: { accessToken: string; refreshToken: string; idToken: string; expiresIn: number }) {
    localStorage.setItem(KEYS.accessToken, tokens.accessToken)
    localStorage.setItem(KEYS.refreshToken, tokens.refreshToken)
    localStorage.setItem(KEYS.idToken, tokens.idToken)
    localStorage.setItem(KEYS.expiry, String(Date.now() + tokens.expiresIn * 1000))
  },
  getAccessToken: () => localStorage.getItem(KEYS.accessToken),
  getRefreshToken: () => localStorage.getItem(KEYS.refreshToken),
  getSelectedTenantId: () => localStorage.getItem(KEYS.selectedTenantId),
  setSelectedTenantId: (id: string | null) => {
    if (id) localStorage.setItem(KEYS.selectedTenantId, id)
    else localStorage.removeItem(KEYS.selectedTenantId)
  },
  clear() {
    Object.values(KEYS).forEach(k => localStorage.removeItem(k))
  },
}

export const apiClient = axios.create({ baseURL: API_BASE })

// Attach Bearer token and selected tenant on every request
apiClient.interceptors.request.use(config => {
  const token = tokenStorage.getAccessToken()
  if (token) config.headers.Authorization = `Bearer ${token}`
  const tenantId = tokenStorage.getSelectedTenantId()
  if (tenantId) config.headers['X-Tenant-Id'] = tenantId
  return config
})

let refreshing = false
let refreshQueue: Array<(token: string | null) => void> = []

const toastCooldown = new Map<string, number>()
const TOAST_COOLDOWN_MS = 2000

function fireToast(type: 'warning' | 'error' | 'info', message: string) {
  const key = `${type}:${message}`
  const now = Date.now()
  if ((toastCooldown.get(key) ?? 0) + TOAST_COOLDOWN_MS > now) return
  toastCooldown.set(key, now)
  window.dispatchEvent(new CustomEvent('ifx:toast', { detail: { type, message } }))
}

// On 403: show a permission-denied warning toast
apiClient.interceptors.response.use(
  res => res,
  error => {
    if (error.response?.status === 403) {
      fireToast('warning', 'You don\'t have permission to perform this action.')
    }
    return Promise.reject(error)
  }
)

// On 401: attempt token refresh once, then redirect to /login
apiClient.interceptors.response.use(
  res => res,
  async error => {
    const original = error.config
    if (error.response?.status !== 401 || original._retry) {
      return Promise.reject(error)
    }
    original._retry = true

    if (refreshing) {
      return new Promise((resolve, reject) => {
        refreshQueue.push(token => {
          if (token) {
            original.headers.Authorization = `Bearer ${token}`
            resolve(apiClient(original))
          } else {
            reject(error)
          }
        })
      })
    }

    refreshing = true
    try {
      const refreshToken = tokenStorage.getRefreshToken()
      if (!refreshToken) throw new Error('No refresh token')

      const resp = await axios.post(`${API_BASE}/api/v1/auth/refresh`, { refreshToken })
      const data = resp.data?.data
      if (!data?.accessToken) throw new Error('Refresh failed')

      tokenStorage.save({
        accessToken: data.accessToken,
        refreshToken: data.refreshToken ?? refreshToken,
        idToken: data.idToken ?? '',
        expiresIn: data.expiresIn ?? 3600,
      })

      refreshQueue.forEach(cb => cb(data.accessToken))
      refreshQueue = []
      original.headers.Authorization = `Bearer ${data.accessToken}`
      return apiClient(original)
    } catch {
      refreshQueue.forEach(cb => cb(null))
      refreshQueue = []
      tokenStorage.clear()
      fireToast('warning', 'Your session has expired. Redirecting to login…')
      setTimeout(() => { window.location.href = '/login' }, 1500)
      return Promise.reject(error)
    } finally {
      refreshing = false
    }
  }
)
