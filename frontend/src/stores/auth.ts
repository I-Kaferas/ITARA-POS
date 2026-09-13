import { defineStore } from 'pinia'
import { ref } from 'vue'
import { api, clearAuth, extractApiErrorMessage, setAuth } from '../api/client'
import type { User } from '../types'

interface LoginResponse {
  access_token?: string
  refresh_token?: string
  requires_two_factor?: boolean
  challenge_token?: string
  user?: User
}

export interface AuthSession {
  id: string
  device_name?: string | null
  ip_address?: string | null
  last_used_at?: string | null
  is_current?: boolean
}

export interface TwoFactorStatus {
  enabled: boolean
}

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)
  const twoFactorChallenge = ref<string | null>(null)
  const sessions = ref<AuthSession[]>([])
  const twoFactorStatus = ref<TwoFactorStatus | null>(null)
  const recoveryCodes = ref<string[]>([])

  async function login(email: string, password: string) {
    loading.value = true
    error.value = null
    twoFactorChallenge.value = null

    try {
      const response = await api.post<LoginResponse>('/auth/login', { email, password })

      if (response.requires_two_factor && response.challenge_token) {
        twoFactorChallenge.value = response.challenge_token
        return { requiresTwoFactor: true as const }
      }

      if (!response.access_token || !response.user) {
        throw new Error('Réponse de connexion invalide')
      }

      setAuth(response.access_token, response.user.tenant_id ?? '', response.refresh_token)
      user.value = response.user
      return { requiresTwoFactor: false as const }
    } catch (e) {
      error.value = extractApiErrorMessage(e)
      throw e
    } finally {
      loading.value = false
    }
  }

  async function verifyTwoFactor(code: string) {
    if (!twoFactorChallenge.value) throw new Error('Aucun défi 2FA en cours')

    loading.value = true
    error.value = null

    try {
      const response = await api.post<Required<LoginResponse>>('/auth/two-factor/challenge', {
        challenge_token: twoFactorChallenge.value,
        code,
      })

      setAuth(
        response.access_token!,
        response.user!.tenant_id || '',
        response.refresh_token,
      )
      user.value = response.user!
      twoFactorChallenge.value = null
    } catch (e) {
      error.value = extractApiErrorMessage(e, 'Code 2FA invalide')
      throw e
    } finally {
      loading.value = false
    }
  }

  async function fetchMe() {
    if (!localStorage.getItem('pos_token')) return

    loading.value = true
    try {
      const response = await api.get<{ user: User }>('/auth/me')
      user.value = response.user
    } catch {
      clearAuth()
      user.value = null
    } finally {
      loading.value = false
    }
  }

  async function logout() {
    try {
      await api.post('/auth/logout')
    } finally {
      clearAuth()
      user.value = null
      twoFactorChallenge.value = null
      sessions.value = []
      twoFactorStatus.value = null
      recoveryCodes.value = []
    }
  }

  async function forgotPassword(email: string) {
    return api.post<{ message: string }>('/auth/forgot-password', { email })
  }

  async function changePassword(currentPassword: string, password: string, passwordConfirmation: string) {
    const res = await api.patch<{ message: string }>('/auth/password', {
      current_password: currentPassword,
      password,
      password_confirmation: passwordConfirmation,
    })
    return res
  }

  async function resetPassword(token: string, email: string, password: string, passwordConfirmation: string) {
    return api.post<{ message: string }>('/auth/reset-password', {
      token,
      email,
      password,
      password_confirmation: passwordConfirmation,
    })
  }

  async function emailVerificationStatus() {
    return api.get<{ email_verified: boolean }>('/auth/email/status')
  }

  async function resendEmailVerification() {
    return api.post<{ message: string }>('/auth/email/resend')
  }

  async function loadTwoFactorStatus() {
    twoFactorStatus.value = await api.get<TwoFactorStatus>('/auth/two-factor/status')
  }

  async function setupTwoFactor() {
    return api.post<{ secret: string; qr_code_url: string }>('/auth/two-factor/setup')
  }

  async function confirmTwoFactor(code: string) {
    const res = await api.post<{ recovery_codes?: string[] }>('/auth/two-factor/confirm', { code })
    recoveryCodes.value = res.recovery_codes ?? []
    await loadTwoFactorStatus()
  }

  async function disableTwoFactor(password: string) {
    await api.post('/auth/two-factor/disable', { password })
    recoveryCodes.value = []
    await loadTwoFactorStatus()
  }

  async function loadSessions() {
    const res = await api.get<{ data: AuthSession[] }>('/auth/sessions')
    sessions.value = res.data ?? []
  }

  async function revokeSession(id: string) {
    await api.delete(`/auth/sessions/${id}`)
    await loadSessions()
  }

  async function revokeOtherSessions() {
    await api.delete('/auth/sessions/others')
    await loadSessions()
  }

  async function logoutAll() {
    await api.post('/auth/logout-all')
    clearAuth()
    user.value = null
  }

  return {
    user,
    loading,
    error,
    twoFactorChallenge,
    sessions,
    twoFactorStatus,
    recoveryCodes,
    login,
    verifyTwoFactor,
    fetchMe,
    logout,
    forgotPassword,
    changePassword,
    resetPassword,
    emailVerificationStatus,
    resendEmailVerification,
    loadTwoFactorStatus,
    setupTwoFactor,
    confirmTwoFactor,
    disableTwoFactor,
    loadSessions,
    revokeSession,
    revokeOtherSessions,
    logoutAll,
  }
})
