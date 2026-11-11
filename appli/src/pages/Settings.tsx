import { useRef, useState } from 'react'
import { K_PARTNER_EXPORT, store, useStore } from '../lib/store'
import { back } from '../lib/router'
import { getSupabaseConfig, setManualSupabaseConfig } from '../lib/supabase'
import { isoDate } from '../lib/util'
import { GYM, gymMapsUrl } from '../data/gym'
import { getRest, setRest } from './SessionPage'
import { beep, isSoundOn, setSoundOn, unlockAudio } from '../lib/device'
import { Avatar, Seg, Stepper } from '../components/ui'
import type { Profile } from '../lib/types'
import { toAvatar } from '../lib/image'
import { profileNeedsHelp } from '../lib/sessions'
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
  const [sound, setSound] = useState(isSoundOn())
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
              <ProfileEditor key={p.id} profile={p} />
            ))}
          </>
        ) : me ? (
          <ProfileEditor profile={me} />
        ) : null}
      </section>

      <section className="card stack">
        <h2>Ma salle</h2>
        <div>
          <p style={{ fontWeight: 600 }}>{GYM.name}</p>
          <p className="small muted">{GYM.address}</p>
          <p className="small muted">
            {GYM.hours} · {GYM.access}
          </p>
        </div>
        <a className="btn" href={gymMapsUrl()} target="_blank" rel="noreferrer">
          Itinéraire
        </a>
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
        <label className="row" style={{ gap: 10, cursor: 'pointer', minHeight: 44 }}>
          <input
            type="checkbox"
            checked={sound}
            onChange={(e) => {
              setSound(e.target.checked)
              setSoundOn(e.target.checked)
              if (e.target.checked) {
                unlockAudio()
                beep()
              }
            }}
            style={{ width: 22, height: 22, accentColor: 'var(--dark)' }}
          />
          Bip à la fin du repos
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

      <PartnerExport />

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

function ProfileEditor({ profile }: { profile: Profile }) {
  const fileRef = useRef<HTMLInputElement>(null)
  const [busy, setBusy] = useState(false)
  return (
    <div className="row" style={{ gap: 14, alignItems: 'center' }}>
      <button
        className="avatar"
        style={{ padding: 0, border: 'none', background: 'none', width: 64, height: 64 }}
        aria-label={`Changer la photo de ${profile.name}`}
        onClick={() => fileRef.current?.click()}
      >
        <Avatar profile={profile} size={60} />
      </button>
      <div className="grow stack" style={{ gap: 6 }}>
        <input
          className="input"
          aria-label={`Prénom de ${profile.name}`}
          defaultValue={profile.name}
          onBlur={(e) => e.target.value.trim() && store.saveProfile({ ...profile, name: e.target.value.trim() })}
        />
        <label className="row small" style={{ gap: 8, cursor: 'pointer', minHeight: 36 }}>
          <input
            type="checkbox"
            checked={profileNeedsHelp(profile)}
            onChange={(e) => store.saveProfile({ ...profile, needsHelp: e.target.checked })}
            style={{ width: 22, height: 22, accentColor: 'var(--dark)' }}
          />
          A besoin d’aide pour charger les disques
        </label>
        <div className="row" style={{ gap: 4 }}>
          <button className="link" disabled={busy} onClick={() => fileRef.current?.click()}>
            {busy ? 'Envoi…' : profile.avatar ? 'Changer la photo' : 'Ajouter une photo'}
          </button>
          {profile.avatar ? (
            <button className="link" style={{ marginLeft: 12 }} onClick={() => store.saveProfile({ ...profile, avatar: undefined })}>
              Retirer
            </button>
          ) : null}
        </div>
      </div>
      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        hidden
        onChange={async (e) => {
          const f = e.target.files?.[0]
          e.target.value = ''
          if (!f) return
          setBusy(true)
          try {
            store.saveProfile({ ...profile, avatar: await toAvatar(f) })
          } catch {
            alert('Impossible de lire cette image.')
          } finally {
            setBusy(false)
          }
        }}
      />
    </div>
  )
}

/** Séances de l'autre restées sur ce téléphone après le passage du mode local au mode en ligne. */
function PartnerExport() {
  const { profiles, meId } = useStore()
  const [raw, setRaw] = useState(() => localStorage.getItem(K_PARTNER_EXPORT))
  if (!raw) return null
  let count = 0
  try {
    count = Object.keys((JSON.parse(raw) as { sessions: object }).sessions).length
  } catch {
    return null
  }
  const other = profiles.find((p) => p.id !== meId)?.name ?? 'ton binôme'
  return (
    <section className="card stack">
      <h2>Séances de {other} sur ce téléphone</h2>
      <p className="small muted">
        {count} séance{count > 1 ? 's' : ''} de {other} {count > 1 ? 'ont été notées' : 'a été notée'} ici en mode local. Envoie-lui ce
        fichier : sur son téléphone, Réglages → Sauvegarde → Importer, et elles deviennent les siennes.
      </p>
      <div className="row wrap">
        <button
          className="btn primary"
          onClick={() => {
            const a = document.createElement('a')
            a.href = URL.createObjectURL(new Blob([raw], { type: 'application/json' }))
            a.download = `seances-pour-${other.toLowerCase()}.json`
            a.click()
            URL.revokeObjectURL(a.href)
          }}
        >
          Exporter pour {other}
        </button>
        <button
          className="btn danger"
          onClick={() => {
            if (confirm(`Effacer ces ${count} séances de ce téléphone ? Fais l’export d’abord.`)) {
              localStorage.removeItem(K_PARTNER_EXPORT)
              setRaw(null)
            }
          }}
        >
          Effacer
        </button>
      </div>
    </section>
  )
}
