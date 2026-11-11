import { useMemo } from 'react'
import { useStore, store } from '../lib/store'
import { navigate } from '../lib/router'
import { weeklyStats, sessionPRs } from '../lib/stats'
import { blankSession, isLive } from '../lib/sessions'
import { addDays, fmtDay, fmtTonnage, isoDate } from '../lib/util'
import { SessionCard } from '../components/SessionCard'
import { Person, personColor } from '../components/ui'
import { SyncPill } from '../components/SyncPill'
import { IconDumbbell, IconPlay, IconPlus, IconTimer, IconTrophy } from '../components/Icons'

export function Home() {
  const st = useStore()
  const { profiles, sessions, meId, exerciseById } = st
  const today = isoDate()
  const me = profiles.find((p) => p.id === meId)

  const week = useMemo(
    () =>
      profiles.map((p) => ({ p, w: weeklyStats(sessions, p.id, exerciseById, 1, today)[0] })),
    [profiles, sessions, exerciseById, today],
  )

  const live = sessions.find((s) => s.ownerId === meId && isLive(s))
  const nextPlanned = sessions
    .filter((s) => s.ownerId === meId && s.status === 'planned' && s.date >= today)
    .sort((a, b) => a.date.localeCompare(b.date))[0]
  const partnerLive = sessions.find((s) => s.ownerId !== meId && isLive(s))

  const feed = sessions.filter((s) => s.status === 'done' && s.date >= addDays(today, -60)).slice(0, 8)

  const startFree = () => {
    if (!meId) return
    const s = { ...blankSession(meId, meId), title: 'Séance libre' }
    store.saveSession(s)
    navigate({ name: 'session', id: s.id })
  }

  return (
    <div className="stack-lg">
      <header className="page-head">
        <div className="grow">
          <p className="welcome">
            Salut <strong>{me?.name ?? ''}</strong>, voici où vous en êtes cette semaine.
          </p>
          <p className="sub" style={{ marginTop: 6 }}>
            {fmtDay(today)}
          </p>
        </div>
        <div className="stack" style={{ gap: 8, alignItems: 'flex-end', alignSelf: 'flex-start' }}>
          <button
            className="avatar"
            style={{ background: personColor(me) }}
            aria-label="Réglages"
            onClick={() => navigate({ name: 'settings' })}
          >
            {(me?.name ?? '?').charAt(0).toUpperCase()}
          </button>
          <SyncPill />
        </div>
      </header>

      {live ? (
        <button className="card click" onClick={() => navigate({ name: 'session', id: live.id })}>
          <span className="badge live">En cours</span>
          <h2 style={{ marginTop: 6 }}>{live.title}</h2>
          <p className="muted small">Reprendre la séance</p>
        </button>
      ) : nextPlanned ? (
        <section className="card">
          <p className="small muted">Prochaine séance · {fmtDay(nextPlanned.date)}</p>
          <h2 style={{ margin: '4px 0 4px' }}>{nextPlanned.title}</h2>
          <p className="small muted">{nextPlanned.items.length} exercices prévus</p>
          <div className="row" style={{ marginTop: 12 }}>
            <button className="btn primary grow" onClick={() => navigate({ name: 'session', id: nextPlanned.id })}>
              <IconPlay /> {nextPlanned.date === today ? 'Démarrer' : 'Ouvrir'}
            </button>
            <button className="btn" onClick={startFree}>
              Séance libre
            </button>
          </div>
        </section>
      ) : (
        <section className="card">
          <h2>Rien de prévu</h2>
          <p className="small muted" style={{ marginTop: 4 }}>
            Planifie une séance avec {profiles.find((p) => p.id !== meId)?.name ?? 'ton binôme'}, ou lance-toi direct.
          </p>
          <div className="row" style={{ marginTop: 12 }}>
            <button className="btn primary grow" onClick={startFree}>
              <IconPlay /> Séance libre
            </button>
            <button className="btn" onClick={() => navigate({ name: 'plan', date: today })}>
              <IconPlus /> Planifier
            </button>
          </div>
        </section>
      )}

      {partnerLive ? (
        <button className="card click" onClick={() => navigate({ name: 'session', id: partnerLive.id })}>
          <div className="row">
            <Person profile={profiles.find((p) => p.id === partnerLive.ownerId)} />
            <span className="badge live">En cours</span>
          </div>
          <p className="small muted" style={{ marginTop: 4 }}>
            {partnerLive.title} · {partnerLive.items.filter((i) => i.sets.some((s) => s.done) || i.cardio?.done).length}/
            {partnerLive.items.length} exercices
          </p>
        </button>
      ) : null}

      <section>
        <div className="section-title">
          <h2>Cette semaine</h2>
          <button className="link" onClick={() => navigate({ name: 'stats' })}>
            Tableau de charge
          </button>
        </div>
        <div className="stack">
          {week.map(({ p, w }) => (
            <div className="card tight" key={p.id}>
              <Person profile={p} you={p.id === meId} />
              <div className="tiles" style={{ marginTop: 8 }}>
                <div className="tile">
                  <div className="l">Séances</div>
                  <div className="v">{w.sessions}</div>
                  <div className="ico">
                    <IconTrophy />
                  </div>
                </div>
                <div className="tile">
                  <div className="l">Soulevé</div>
                  <div className="v">{fmtTonnage(w.tonnage)}</div>
                  <div className="ico">
                    <IconDumbbell />
                  </div>
                </div>
                <div className="tile">
                  <div className="l">Cardio</div>
                  <div className="v">{w.cardioMin} min</div>
                  <div className="ico">
                    <IconTimer />
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <div className="section-title">
          <h2>Activité récente</h2>
        </div>
        <div className="stack">
          {feed.length ? (
            feed.map((s) => (
              <SessionCard
                key={s.id}
                s={s}
                owner={profiles.find((p) => p.id === s.ownerId)}
                meId={meId}
                byId={exerciseById}
                prs={sessionPRs(sessions, s)}
              />
            ))
          ) : (
            <p className="empty card">Pas encore de séance. La première, c’est la plus importante.</p>
          )}
        </div>
      </section>
    </div>
  )
}
