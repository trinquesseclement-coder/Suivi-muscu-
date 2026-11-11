import { useState } from 'react'
import { store, useStore } from '../lib/store'
import { Seg } from '../components/ui'

export function Login() {
  const [mode, setMode] = useState<'in' | 'up'>('in')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      if (mode === 'in') await store.signIn(email.trim(), password)
      else await store.signUp(email.trim(), password)
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err)
      setError(msg === 'Invalid login credentials' ? 'Email ou mot de passe incorrect.' : msg)
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="stack-lg" onSubmit={submit} style={{ paddingTop: '10vh' }}>
      <div>
        <h1>Suivi Muscu</h1>
        <p className="muted" style={{ marginTop: 4 }}>
          Vos séances, vos charges, à deux.
        </p>
      </div>
      <Seg
        label="Connexion ou inscription"
        value={mode}
        onChange={setMode}
        options={[
          { value: 'in', label: 'Se connecter' },
          { value: 'up', label: 'Créer un compte' },
        ]}
      />
      <div className="stack">
        <label className="field">
          <span>Email</span>
          <input className="input" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label className="field">
          <span>Mot de passe</span>
          <input
            className="input"
            type="password"
            autoComplete={mode === 'in' ? 'current-password' : 'new-password'}
            minLength={6}
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>
      </div>
      {error ? <p className="banner error">{error}</p> : null}
      <button className="btn primary lg block" disabled={busy}>
        {busy ? '…' : mode === 'in' ? 'Se connecter' : 'Créer le compte'}
      </button>
    </form>
  )
}

export function Onboarding() {
  const { profiles, meId } = useStore()
  const [name, setName] = useState('')
  const taken = new Set(profiles.map((p) => p.slot))
  const slot: 1 | 2 = taken.has(1) ? 2 : 1
  return (
    <form
      className="stack-lg"
      style={{ paddingTop: '10vh' }}
      onSubmit={(e) => {
        e.preventDefault()
        if (meId && name.trim()) store.saveProfile({ id: meId, name: name.trim(), slot })
      }}
    >
      <div>
        <h1>Bienvenue</h1>
        <p className="muted" style={{ marginTop: 4 }}>
          {profiles.length ? `${profiles.map((p) => p.name).join(', ')} est déjà là. ` : ''}Comment tu t’appelles ?
        </p>
      </div>
      <label className="field">
        <span>Prénom</span>
        <input className="input" autoFocus value={name} onChange={(e) => setName(e.target.value)} />
      </label>
      <button className="btn primary lg block" disabled={!name.trim()}>
        C’est parti
      </button>
    </form>
  )
}
