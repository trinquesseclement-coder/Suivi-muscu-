import { useStore } from '../lib/store'
import { GYM } from '../data/gym'
import { navigate } from '../lib/router'
import { addDays, fmtDM, isoDate, parseDate, weekStart } from '../lib/util'
import { isLive, needsHelp } from '../lib/sessions'
import { personColor } from '../components/ui'
import { IconBack, IconChevron, IconHands, IconPlus } from '../components/Icons'

const DOW = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']

export function Planning({ week }: { week?: string }) {
  const { sessions, profiles, meId, exerciseById } = useStore()
  const today = isoDate()
  const start = weekStart(week ?? today)
  const days = Array.from({ length: 7 }, (_, i) => addDays(start, i))
  const end = days[6]
  const inWeek = sessions.filter((s) => s.date >= start && s.date <= end)

  const go = (n: number) => navigate({ name: 'planning', week: addDays(start, 7 * n) }, { replace: true })

  return (
    <div className="stack">
      <header className="page-head">
        <div className="grow">
          <h1>Planning</h1>
          <p className="sub">
            Semaine du {fmtDM(start)} au {fmtDM(end)} · {GYM.name}
          </p>
        </div>
      </header>

      <div className="row">
        <button className="icon-btn" aria-label="Semaine précédente" onClick={() => go(-1)}>
          <IconBack />
        </button>
        <button
          className="btn grow"
          disabled={start === weekStart(today)}
          onClick={() => navigate({ name: 'planning' }, { replace: true })}
        >
          Cette semaine
        </button>
        <button className="icon-btn" aria-label="Semaine suivante" onClick={() => go(1)}>
          <IconChevron />
        </button>
      </div>

      <div className="legend" style={{ marginTop: 4 }}>
        {profiles.map((p) => (
          <span key={p.id}>
            <span className="dot" style={{ background: personColor(p) }} />
            {p.name}
            {p.id === meId ? ' (toi)' : ''}
          </span>
        ))}
        <span className="faint">Pointillés = prévue</span>
      </div>

      <div className="card" style={{ paddingTop: 4, paddingBottom: 4 }}>
        {days.map((d, i) => {
          const list = inWeek
            .filter((s) => s.date === d)
            .sort((a, b) => {
              const pa = profiles.find((p) => p.id === a.ownerId)?.slot ?? 9
              const pb = profiles.find((p) => p.id === b.ownerId)?.slot ?? 9
              return pa - pb
            })
          return (
            <div key={d} className={`day${d === today ? ' today' : ''}`}>
              <div className="day-label">
                <div className="dow">{DOW[i]}</div>
                <div className="num">{parseDate(d).getDate()}</div>
              </div>
              <div className="stack" style={{ gap: 6 }}>
                {list.map((s) => {
                  const owner = profiles.find((p) => p.id === s.ownerId)
                  const help = needsHelp(profiles, s.ownerId)
                    ? s.items.filter((it) => exerciseById[it.exerciseId]?.help).length
                    : 0
                  return (
                    <button
                      key={s.id}
                      className={`slot${s.status === 'planned' ? ' planned' : ''}`}
                      onClick={() => navigate({ name: 'session', id: s.id })}
                    >
                      <span className="bar" style={{ background: personColor(owner) }} />
                      <span className="grow">
                        <span style={{ fontWeight: 650 }}>{s.title}</span>
                        <span className="small muted" style={{ display: 'block' }}>
                          {owner?.name} · {s.items.length} exo{s.items.length > 1 ? 's' : ''}
                          {s.status === 'done' ? (isLive(s) ? ' · en cours' : ' · faite') : ''}
                        </span>
                      </span>
                      {help ? (
                        <span className="badge help" title="Exercices avec aide">
                          <IconHands />
                          {help}
                        </span>
                      ) : null}
                    </button>
                  )
                })}
                {d >= today ? (
                  <button className="add-slot" onClick={() => navigate({ name: 'plan', date: d })}>
                    <span className="row" style={{ justifyContent: 'center', gap: 4 }}>
                      <IconPlus width={18} height={18} /> Planifier
                    </span>
                  </button>
                ) : !list.length ? (
                  <span className="faint small" style={{ paddingTop: 12 }}>
                    —
                  </span>
                ) : null}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
