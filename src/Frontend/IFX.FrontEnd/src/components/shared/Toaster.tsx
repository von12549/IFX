import { useEffect, useState } from 'react'

export interface Toast {
  id: number
  type: 'warning' | 'error' | 'info'
  message: string
}

let nextId = 1

export function Toaster() {
  const [toasts, setToasts] = useState<Toast[]>([])

  useEffect(() => {
    const handler = (e: Event) => {
      const { type, message } = (e as CustomEvent).detail as { type: Toast['type']; message: string }
      const id = nextId++
      setToasts(prev => [...prev, { id, type, message }])
      setTimeout(() => setToasts(prev => prev.filter(t => t.id !== id)), 5000)
    }
    window.addEventListener('ifx:toast', handler)
    return () => window.removeEventListener('ifx:toast', handler)
  }, [])

  if (!toasts.length) return null

  return (
    <div className="toaster">
      {toasts.map(t => (
        <div key={t.id} className={`toast toast-${t.type}`}>
          <span className="toast-icon">
            {t.type === 'warning' ? '⚠' : t.type === 'error' ? '✕' : 'ℹ'}
          </span>
          <span className="toast-message">{t.message}</span>
          <button className="toast-close" onClick={() => setToasts(prev => prev.filter(x => x.id !== t.id))}>×</button>
        </div>
      ))}
    </div>
  )
}
