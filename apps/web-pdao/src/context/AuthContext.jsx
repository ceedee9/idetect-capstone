import { createContext, useContext, useState, useCallback } from 'react'
import { authAPI } from '../services/api'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser]   = useState(() => { try { return JSON.parse(localStorage.getItem('pdao_user')) } catch { return null } })
  const [token, setToken] = useState(() => localStorage.getItem('pdao_token'))

  const login = useCallback(async (email, password) => {
    const res = await authAPI.login(email, password)
    const { token: t, user: u } = res.data
    if (u.role !== 'pdao_admin') throw new Error('Access denied. This portal is for PDAO administrators only.')
    localStorage.setItem('pdao_token', t)
    localStorage.setItem('pdao_user', JSON.stringify(u))
    setToken(t); setUser(u)
    return u
  }, [])

  const logout = useCallback(() => {
    localStorage.removeItem('pdao_token')
    localStorage.removeItem('pdao_user')
    setToken(null); setUser(null)
  }, [])

  return (
    <AuthContext.Provider value={{ user, token, login, logout, isAuthenticated: !!token }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
