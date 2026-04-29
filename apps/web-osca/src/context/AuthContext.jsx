import { createContext, useContext, useState, useCallback } from 'react'
import { authAPI } from '../services/api'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    try { return JSON.parse(localStorage.getItem('osca_user')) } catch { return null }
  })
  const [token, setToken] = useState(() => localStorage.getItem('osca_token'))

  const login = useCallback(async (email, password) => {
    const res = await authAPI.login(email, password)
    const { token: newToken, user: newUser } = res.data

    if (newUser.role !== 'osca_admin') {
      throw new Error('Access denied. This portal is for OSCA administrators only.')
    }

    localStorage.setItem('osca_token', newToken)
    localStorage.setItem('osca_user', JSON.stringify(newUser))
    setToken(newToken)
    setUser(newUser)
    return newUser
  }, [])

  const logout = useCallback(() => {
    localStorage.removeItem('osca_token')
    localStorage.removeItem('osca_user')
    setToken(null)
    setUser(null)
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
