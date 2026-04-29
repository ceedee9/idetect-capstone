import { createContext, useContext, useState, useCallback } from 'react'
import { authAPI } from '../services/api'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    try {
      const stored = localStorage.getItem('bplo_user')
      return stored ? JSON.parse(stored) : null
    } catch {
      return null
    }
  })

  const [token, setToken] = useState(() => localStorage.getItem('bplo_token'))

  const login = useCallback(async (email, password) => {
    const res = await authAPI.login(email, password)
    const { token: newToken, user: newUser } = res.data

    // Enforce BPLO-only access
    if (newUser.role !== 'bplo_admin') {
      throw new Error('Access denied. This portal is for BPLO administrators only.')
    }

    localStorage.setItem('bplo_token', newToken)
    localStorage.setItem('bplo_user', JSON.stringify(newUser))
    setToken(newToken)
    setUser(newUser)
    return newUser
  }, [])

  const logout = useCallback(() => {
    localStorage.removeItem('bplo_token')
    localStorage.removeItem('bplo_user')
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
