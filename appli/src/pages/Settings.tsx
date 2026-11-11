import { useRef, useState } from 'react'
import { store, useStore } from '../lib/store'
import { back } from '../lib/router'
import { getSupabaseConfig, setManualSupabaseConfig } from '../lib/supabase'
import { isoDate } from '../lib/util'
import { getRest, setRest } from './SessionPage'
import { personColor, Seg, Stepper } from '../components/ui'
import { IconBack } from '../components/Icons'

const K_THEME = 'suivi:theme'
type Theme = 'auto' | 'light' | 'dark'
export function applyTheme(t: Theme = (localStorage.getItem(K_THEME) as Theme) || 'auto') {
  if (t === 'auto') document.documentElement.removeAttribute('data-theme')
  else document.documentElement.setAttribute('data-theme', t)
}

export function Settings() {
  const st = useStore()
  const me = st.profiles.find((p) => p.id === st.meId)
  const [theme, setTheme] = useState<Theme>(((localStorage.getItem(K_THEME) as Theme) || 'auto'))
  const [rest, setRestState] = useState(getRest())
  const cfg = getSupabaseConfig()
  const [url, setUrl] = useState(cfg?.url ?? '')
  const [key, setKey] = useState(cfg?.source === 'manual' ? cfg.key : '')
  const fileRef = useRef<HTMLInputElement>(null)

  const download = () => {
    const blob = new Blob([store.exportData()], { type: 'application/json' })
    const a = document.createElement('a')
    a.href = URL.createObjectURL(blob)
    a.download = `suivi-muscu-${isoDate()}.json`
    a.click()
    URL.revokeObjectURL(a.href)
  }

  return (
    <div className="stack-lg">
      <header className="page-head">
        <button className="icon-btn" aria-label="Retour" onClick={() => back()}>
          <IconBack />
        </button>
        <h1 className="grow">Réglages</h1>
      </header>

      <section className="card stack">
        <h2>Profils</h2>
        {st.mode === 'local' ? (
          <>
            <div className="field">
              <span>Sur ce téléphone, je suis</span>
              <Seg
                label="Profil actif"
                value={st.meId ?? ''}
                onChange={(id) => store.switchLocalProfile(id)}
                options={st.profiles.map((p) => ({ value: p.id, label: p.name }))}
              />
            </div>
            {st.profiles.map((p) => (
              <label className="field" key={p.id}>
                <span className="row">
                  <span className="dot" style={{ background: personColor(p) }} /> Prénom
                </span>
                <input className="input" defaultValue={p.name} onBlur={(e) => e.target.value.trim() && store.saveProfile({ ...p, name: e.target.value.trim() })} />
              </label>
            ))}
          </>
        ) : me ? (
          <label className="field">
            <span>Ton prénom</span>
            <input className="input" defaultValue={me.name} onBlur={(e) => e.target.value.trim() && store.saveProfile({ ...me, name: e.target.value.trim() })} />
          </label>
        ) : null}
      </section>

      <section className="card stack">
        <h2>Séance</h2>
        <label className="field">
          <span>Temps de repos par défaut</span>
          <Stepper
            label="Repos"
            unit="secondes"
            step={15}
            min={15}
            value={rest}
            onChange={(v) => {
              setRestState(v)
              setRest(v)
            }}
          />
        </label>
        <div className="field">
          <span>Thème</span>
          <Seg<Theme>
            label="Thème"
            value={theme}
            onChange={(t) => {
              setTheme(t)
              localStorage.setItem(K_THEME, t)
              applyTheme(t)
            }}
            options={[
              { value: 'auto', label: 'Auto' },
              { value: 'light', label: 'Clair' },
              { value: 'dark', label: 'Sombre' },
            ]}
          />
        </div>
      </section>

      <section className="card stack">
        <h2>Synchronisation</h2>
        {st.mode === 'cloud' ? (
          <>
            <p className="small muted">
              Connecté : <strong>{st.email}</strong>
              <br />
              État : {st.sync}
              {st.pending ? ` · ${st.pending} modif(s) en attente` : ''}
            </p>
            {st.lastError ? <p className="banner error small">{st.lastError}</p> : null}
            <div className="row wrap">
              <button className="btn" onClick={() => void store.syncNow()}>
                Synchroniser
              </button>
              <button
                className="btn danger"
                onClick={() => {
                  if (!st.pending || confirm(`${st.pending} modif(s) pas encore envoyées seront perdues. Se déconnecter ?`)) void store.signOut()
                }}
              >
                Se déconnecter
              </button>
            </div>
          </>
        ) : (
          <p className="small muted">
            Mode local : les données restent sur ce téléphone. Pour que vous voyiez les séances l’un de l’autre, branche
            Supabase (voir le README), via Netlify ou ci-dessous.
          </p>
        )}
        {cfg?.source !== 'env' ? (
          <details>
            <summary className="small" style={{ cursor: 'pointer', fontWeight: 600 }}>
              Connexion Supabase manuelle
            </summary>
            <div className="stack" style={{ marginTop: 12 }}>
              <label className="field">
                <span>Project URL</span>
                <input className="input" value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://xxxx.supabase.co" />
              </label>
              <label className="field">
                <span>Clé publique (anon / publishable)</span>
                <input className="input" value={key} onChange={(e) => setKey(e.target.value)} />
              </label>
              <div className="row">
                <button
                  className="btn primary"
                  disabled={!url.startsWith('https://') || key.length < 20}
                  onClick={() => {
                    setManualSupabaseConfig({ url: url.trim(), key: key.trim() })
                    location.reload()
                  }}
                >
                  Connecter
                </button>
                {cfg?.source === 'manual' ? (
                  <button
                    className="btn"
                    onClick={() => {
                      setManualSupabaseConfig(null)
                      location.reload()
                    }}
                  >
                    Repasser en local
                  </button>
                ) : null}
              </div>
            </div>
          </details>
        ) : null}
      </section>

      <section className="card stack">
        <h2>Sauvegarde</h2>
        <p className="small muted">Un fichier avec toutes vos séances, à garder au cas où.</p>
        <div className="row wrap">
          <button className="btn" onClick={download}>
            Exporter
          </button>
          <button className="btn" onClick={() => fileRef.current?.click()}>
            Importer
          </button>
          <input
            ref={fileRef}
            type="file"
            accept="application/json"
            hidden
            onChange={async (e) => {
              const f = e.target.files?.[0]
              if (!f) return
              try {
                store.importData(await f.text())
                alert('Import terminé.')
              } catch {
                alert('Fichier illisible.')
              }
              e.target.value = ''
            }}
          />
        </div>
      </section>
    </div>
  )
}
