import { useMemo, useState } from 'react'
import { useStore } from '../lib/store'
import { MUSCLE_LABEL } from '../data/exercises'
import type { Muscle, Profile } from '../lib/types'
import { cardioHistory, exerciseHistory, personalRecords, weeklyStats } from '../lib/stats'
import { fmtDM, fmtNum, fmtTonnage, isoDate } from '../lib/util'
import { BarChart, ChartCard, HBarChart, LineChart } from '../components/Charts'
import { personColor, Seg } from '../components/ui'

type Who = 'both' | string
type Metric = 'top' | 'e1rm' | 'tonnage'

const WEEKS = 8

export function Stats() {
  const { profiles, sessions, exerciseById } = useStore()
  const [who, setWho] = useState<Who>('both')
  const today = isoDate()
  const shown: Profile[] = useMemo(
    () => (who === 'both' ? profiles : profiles.filter((p) => p.id === who)),
    [who, profiles],
  )

  const weekly = useMemo(
    () => shown.map((p) => ({ p, weeks: weeklyStats(sessions, p.id, exerciseById, WEEKS, today) })),
    [shown, sessions, exerciseById, today],
  )
  const weekLabels = weekly[0]?.weeks.map((w) => fmtDM(w.week)) ?? []
  const series = (fn: (w: (typeof weekly)[0]['weeks'][0]) => number) =>
    weekly.map(({ p, weeks }) => ({ key: p.id, name: p.name, color: personColor(p), values: weeks.map(fn) }))
  const legend = shown.map((p) => ({ key: p.id, name: p.name, color: personColor(p) }))

  // Séries par muscle : semaine en cours
  const muscles = (Object.keys(MUSCLE_LABEL) as Muscle[]).filter((m) => m !== 'cardio')
  const thisWeek = weekly.map(({ p, weeks }) => ({ p, w: weeks[weeks.length - 1] }))
  const usedMuscles = muscles.filter((m) => thisWeek.some(({ w }) => (w.setsByMuscle[m] ?? 0) > 0))

  // Exercices avec historique pour au moins une des personnes affichées
  const doneIds = useMemo(() => {
    const ids = new Map<string, number>()
    for (const s of sessions) {
      if (s.status !== 'done' || !shown.some((p) => p.id === s.ownerId)) continue
      for (const it of s.items) {
        if (it.sets.some((x) => x.done) || it.cardio?.done) ids.set(it.exerciseId, (ids.get(it.exerciseId) ?? 0) + 1)
      }
    }
    return [...ids.entries()].sort((a, b) => b[1] - a[1]).map(([id]) => id)
  }, [sessions, shown])

  const [exId, setExId] = useState<string>('')
  const [metric, setMetric] = useState<Metric>('top')
  const selected = exerciseById[exId && doneIds.includes(exId) ? exId : doneIds[0] ?? '']

  const whoOptions = [
    { value: 'both', label: 'Les deux' },
    ...profiles.map((p) => ({ value: p.id, label: p.name })),
  ]

  return (
    <div className="stack-lg">
      <header className="page-head">
        <div className="grow">
          <h1>Tableau de charge</h1>
          <p className="sub">Les {WEEKS} dernières semaines</p>
        </div>
      </header>

      <Seg label="Qui" value={who} options={whoOptions} onChange={setWho} />

      <ChartCard
        title="Tonnage par semaine"
        subtitle="Kilos × répétitions des séries validées"
        series={legend}
        table={{
          head: ['Semaine', ...shown.map((p) => p.name)],
          rows: weekLabels.map((l, i) => [l, ...weekly.map(({ weeks }) => fmtTonnage(weeks[i].tonnage))]),
        }}
      >
        <BarChart
          categories={weekLabels}
          series={series((w) => w.tonnage)}
          format={(v) => (v >= 1000 ? `${fmtNum(v / 1000)} t` : fmtNum(v))}
          tipTitle={(i) => `Semaine du ${weekLabels[i]}`}
        />
      </ChartCard>

      <ChartCard
        title="Cardio par semaine"
        subtitle="Minutes validées"
        series={legend}
        table={{
          head: ['Semaine', ...shown.map((p) => p.name)],
          rows: weekLabels.map((l, i) => [l, ...weekly.map(({ weeks }) => `${weeks[i].cardioMin} min`)]),
        }}
      >
        <BarChart
          categories={weekLabels}
          series={series((w) => w.cardioMin)}
          format={(v) => `${fmtNum(v)}`}
          tipTitle={(i) => `Semaine du ${weekLabels[i]} (min)`}
        />
      </ChartCard>

      <ChartCard
        title="Séries par muscle"
        subtitle="Cette semaine — repère : 10 à 20 séries par muscle et par semaine"
        series={legend}
        table={{
          head: ['Muscle', ...shown.map((p) => p.name)],
          rows: usedMuscles.map((m) => [MUSCLE_LABEL[m], ...thisWeek.map(({ w }) => w.setsByMuscle[m] ?? 0)]),
        }}
      >
        {usedMuscles.length ? (
          <HBarChart
            categories={usedMuscles.map((m) => MUSCLE_LABEL[m])}
            series={thisWeek.map(({ p, w }) => ({
              key: p.id,
              name: p.name,
              color: personColor(p),
              values: usedMuscles.map((m) => w.setsByMuscle[m] ?? 0),
            }))}
            format={(v) => String(v)}
          />
        ) : (
          <p className="empty">Aucune série validée cette semaine.</p>
        )}
      </ChartCard>

      <section className="card">
        <div className="section-title">
          <h2>Progression par machine</h2>
        </div>
        {selected ? (
          <div className="stack">
            <select
              className="input"
              value={selected.id}
              onChange={(e) => setExId(e.target.value)}
              aria-label="Choisir une machine"
            >
              {doneIds.map((id) => (
                <option key={id} value={id}>
                  {exerciseById[id]?.name ?? id}
                </option>
              ))}
            </select>
            {selected.kind === 'cardio' ? (
              <CardioProgress exerciseId={selected.id} people={shown} />
            ) : (
              <>
                <Seg
                  label="Mesure"
                  value={metric}
                  onChange={setMetric}
                  options={[
                    { value: 'top', label: 'Charge max' },
                    { value: 'e1rm', label: '1RM estimé' },
                    { value: 'tonnage', label: 'Tonnage' },
                  ]}
                />
                <MuscuProgress exerciseId={selected.id} people={shown} metric={metric} />
              </>
            )}
          </div>
        ) : (
          <p className="empty">Valide quelques séries pour voir ta progression ici.</p>
        )}
      </section>

      <Records people={shown} />
    </div>
  )
}

function MuscuProgress({ exerciseId, people, metric }: { exerciseId: string; people: Profile[]; metric: Metric }) {
  const { sessions } = useStore()
  const lines = people.map((p) => {
    const h = exerciseHistory(sessions, p.id, exerciseId).slice(-20)
    return {
      key: p.id,
      name: p.name,
      color: personColor(p),
      points: h.map((pt) => ({
        date: pt.date,
        value: metric === 'top' ? pt.topKg : metric === 'e1rm' ? Math.round(pt.e1rm * 10) / 10 : pt.tonnage,
        detail:
          metric === 'top'
            ? `${fmtNum(pt.topKg)} kg × ${pt.topReps}`
            : metric === 'e1rm'
              ? `${fmtNum(pt.e1rm)} kg`
              : fmtTonnage(pt.tonnage),
      })),
    }
  })
  const visible = lines.filter((l) => l.points.length)
  const dates = [...new Set(visible.flatMap((l) => l.points.map((p) => p.date)))].sort()
  const unit = metric === 'tonnage' ? '' : ' kg'
  return (
    <ChartCardInner
      lines={visible}
      table={{
        head: ['Date', ...visible.map((l) => l.name)],
        rows: dates.map((d) => [fmtDM(d), ...visible.map((l) => l.points.find((p) => p.date === d)?.detail ?? '—')]),
      }}
      format={(v) => (metric === 'tonnage' ? fmtTonnage(v) : `${fmtNum(v)}${unit}`)}
    />
  )
}

function CardioProgress({ exerciseId, people }: { exerciseId: string; people: Profile[] }) {
  const { sessions } = useStore()
  const lines = people
    .map((p) => ({
      key: p.id,
      name: p.name,
      color: personColor(p),
      points: cardioHistory(sessions, p.id, exerciseId)
        .slice(-20)
        .map((pt) => ({
          date: pt.date,
          value: pt.minutes,
          detail: `${pt.minutes} min${pt.distanceKm ? ` · ${fmtNum(pt.distanceKm)} km` : ''}${pt.level ? ` · niv. ${pt.level}` : ''}`,
        })),
    }))
    .filter((l) => l.points.length)
  const dates = [...new Set(lines.flatMap((l) => l.points.map((p) => p.date)))].sort()
  return (
    <ChartCardInner
      lines={lines}
      table={{
        head: ['Date', ...lines.map((l) => l.name)],
        rows: dates.map((d) => [fmtDM(d), ...lines.map((l) => l.points.find((p) => p.date === d)?.detail ?? '—')]),
      }}
      format={(v) => `${fmtNum(v)} min`}
    />
  )
}

function ChartCardInner({
  lines,
  table,
  format,
}: {
  lines: { key: string; name: string; color: string; points: { date: string; value: number; detail?: string }[] }[]
  table: { head: string[]; rows: (string | number)[][] }
  format: (v: number) => string
}) {
  const [showTable, setShowTable] = useState(false)
  return (
    <div>
      {lines.length > 1 ? (
        <div className="legend">
          {lines.map((l) => (
            <span key={l.key}>
              <span className="dot" style={{ background: l.color }} />
              {l.name}
            </span>
          ))}
        </div>
      ) : null}
      {showTable ? (
        <table className="data-table">
          <thead>
            <tr>
              {table.head.map((h) => (
                <th key={h}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {table.rows.map((r, i) => (
              <tr key={i}>
                {r.map((c, j) => (
                  <td key={j}>{c}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      ) : (
        <LineChart series={lines} format={format} />
      )}
      <button className="link" onClick={() => setShowTable((v) => !v)}>
        {showTable ? 'Voir le graphique' : 'Voir le tableau'}
      </button>
    </div>
  )
}

function Records({ people }: { people: Profile[] }) {
  const { sessions, exerciseById } = useStore()
  return (
    <section className="card">
      <div className="section-title">
        <h2>Records</h2>
        <span className="small muted">meilleur 1RM estimé</span>
      </div>
      <div className="stack">
        {people.map((p) => {
          const prs = Object.values(personalRecords(sessions, p.id))
            .filter((r) => exerciseById[r.exerciseId])
            .sort((a, b) => b.date.localeCompare(a.date))
            .slice(0, 8)
          return (
            <div key={p.id}>
              <p className="person" style={{ marginBottom: 6 }}>
                <span className="dot" style={{ background: personColor(p) }} />
                {p.name}
              </p>
              {prs.length ? (
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Machine</th>
                      <th>Meilleure série</th>
                      <th>1RM est.</th>
                      <th>Date</th>
                    </tr>
                  </thead>
                  <tbody>
                    {prs.map((r) => (
                      <tr key={r.exerciseId}>
                        <td>{exerciseById[r.exerciseId].name}</td>
                        <td>
                          {fmtNum(r.kg)} × {r.reps}
                        </td>
                        <td>{fmtNum(r.e1rm)}</td>
                        <td>{fmtDM(r.date)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p className="small muted">Pas encore de record.</p>
              )}
            </div>
          )
        })}
      </div>
    </section>
  )
}
