import type { Exercise, Profile, Session } from '../lib/types'
import { sessionCardioMin, sessionSetCount, sessionTonnage } from '../lib/stats'
import { isLive } from '../lib/sessions'
import { fmtDay, fmtTonnage } from '../lib/util'
import { navigate } from '../lib/router'
import { Person } from './ui'
import { IconHands, IconTrophy } from './Icons'

export function SessionCard({
  s,
  owner,
  meId,
  byId,
  prs = [],
  helped = false,
}: {
  s: Session
  owner?: Profile
  meId: string | null
  byId: Record<string, Exercise>
  prs?: string[]
  /** La personne a besoin d'aide : on affiche le nombre d'exercices avec aide. */
  helped?: boolean
}) {
  const ton = sessionTonnage(s)
  const cardio = sessionCardioMin(s, byId)
  const sets = sessionSetCount(s)
  const helpCount = helped ? s.items.filter((i) => byId[i.exerciseId]?.help).length : 0
  const names = s.items
    .map((i) => byId[i.exerciseId]?.name)
    .filter(Boolean)
    .slice(0, 3)
    .join(' · ')
  return (
    <button className="card click" onClick={() => navigate({ name: 'session', id: s.id })}>
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <Person profile={owner} you={owner?.id === meId} />
        <span className="small muted">{fmtDay(s.date)}</span>
      </div>
      <div className="row" style={{ marginTop: 6, gap: 8 }}>
        <h3 className="grow">{s.title}</h3>
        {isLive(s) ? <span className="badge live">En cours</span> : null}
        {s.status === 'planned' ? <span className="badge">Prévue</span> : null}
      </div>
      {names ? (
        <p className="small muted" style={{ marginTop: 2 }}>
          {names}
          {s.items.length > 3 ? ` +${s.items.length - 3}` : ''}
        </p>
      ) : null}
      <div className="row wrap" style={{ marginTop: 8 }}>
        {s.status === 'done' ? (
          <>
            {sets ? <span className="badge tnum">{sets} séries</span> : null}
            {ton ? <span className="badge tnum">{fmtTonnage(ton)}</span> : null}
            {cardio ? <span className="badge tnum">{cardio} min cardio</span> : null}
            {s.rpe ? <span className="badge tnum">Ressenti {s.rpe}/10</span> : null}
          </>
        ) : (
          <span className="badge tnum">{s.items.length} exercices</span>
        )}
        {helpCount ? (
          <span className="badge help">
            <IconHands />
            {helpCount} avec aide
          </span>
        ) : null}
        {prs.length ? (
          <span className="badge pr">
            <IconTrophy />
            {prs.length} record{prs.length > 1 ? 's' : ''}
          </span>
        ) : null}
      </div>
    </button>
  )
}
