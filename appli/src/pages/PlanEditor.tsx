import { useMemo, useState } from 'react'
import { store, useStore } from '../lib/store'
import { back, navigate } from '../lib/router'
import type { Session, SessionItem } from '../lib/types'
import { lastPerformance } from '../lib/stats'
import { helperName, needsHelp, partnerOf, titleSuggestion } from '../lib/sessions'
import { fmtDay, isoDate, uid } from '../lib/util'
import { ExercisePicker } from '../components/ExercisePicker'
import { ExerciseBadges, Seg, Sheet, Stepper } from '../components/ui'
import { IconBack, IconClose, IconCopy, IconHands, IconPlus } from '../components/Icons'

interface Spec {
  key: string
  exerciseId: string
  sets: number
  reps: number
  kg: number
  minutes: number
}

type Who = 'me' | 'partner' | 'both'

export function PlanEditor({ id, date }: { id?: string; date?: string }) {
  const { sessions, profiles, meId, exerciseById } = useStore()
  const existing = id ? sessions.find((s) => s.id === id) : undefined
  const partner = partnerOf(profiles, meId)
  const helper = helperName(profiles)

  const [day, setDay] = useState(existing?.date ?? date ?? isoDate())
  const [who, setWho] = useState<Who>(existing ? (existing.ownerId === meId ? 'me' : 'partner') : 'both')
  const [title, setTitle] = useState(existing?.title ?? '')
  const [notes, setNotes] = useState(existing?.notes ?? '')
  const [specs, setSpecs] = useState<Spec[]>(() =>
    (existing?.items ?? []).map((it) => ({
      key: uid(),
      exerciseId: it.exerciseId,
      sets: Math.max(1, it.sets.length),
      reps: it.sets[0]?.reps ?? 10,
      kg: it.sets[0]?.kg ?? 0,
      minutes: it.cardio?.minutes ?? 15,
    })),
  )
  const [picking, setPicking] = useState(false)
  const [copying, setCopying] = useState(false)

  const owners = useMemo(() => {
    if (!meId) return []
    if (who === 'me') return [meId]
    if (who === 'partner') return partner ? [partner.id] : []
    return [meId, ...(partner ? [partner.id] : [])]
  }, [who, meId, partner])
  const singleOwner = owners.length === 1 ? owners[0] : null
  // L'aide ne concerne que les séances de la personne qui en a besoin
  const helpMatters = owners.some((o) => needsHelp(profiles, o))

  const specFor = (exerciseId: string): Spec => {
    const ex = exerciseById[exerciseId]
    const last = singleOwner ? lastPerformance(sessions, singleOwner, exerciseId) : null
    const done = last?.item.sets.filter((s) => s.done) ?? []
    const top = done.reduce((a, s) => (s.kg > a.kg ? s : a), done[0] ?? { kg: 0, reps: 10 })
    return {
      key: uid(),
      exerciseId,
      sets: done.length || 3,
      reps: top?.reps ?? 10,
      kg: top?.kg ?? 0,
      minutes: last?.item.cardio?.minutes ?? (ex?.kind === 'cardio' ? 15 : 0),
    }
  }

  const update = (key: string, patch: Partial<Spec>) => setSpecs((l) => l.map((s) => (s.key === key ? { ...s, ...patch } : s)))
  const move = (i: number, d: -1 | 1) =>
    setSpecs((l) => {
      const j = i + d
      if (j < 0 || j >= l.length) return l
      const c = [...l]
      ;[c[i], c[j]] = [c[j], c[i]]
      return c
    })
  const groupHelp = () =>
    setSpecs((l) => {
      const firstHelp = l.findIndex((s) => exerciseById[s.exerciseId]?.help)
      if (firstHelp < 0) return l
      const help = l.filter((s) => exerciseById[s.exerciseId]?.help)
      const rest = l.filter((s) => !exerciseById[s.exerciseId]?.help)
      return [...rest.slice(0, firstHelp), ...help, ...rest.slice(firstHelp)]
    })

  const helpCount = helpMatters ? specs.filter((s) => exerciseById[s.exerciseId]?.help).length : 0
  const helpIdx = specs.map((s, i) => (exerciseById[s.exerciseId]?.help ? i : -1)).filter((i) => i >= 0)
  const helpGrouped = helpIdx.length < 2 || helpIdx[helpIdx.length - 1] - helpIdx[0] === helpIdx.length - 1
  const autoTitle = titleSuggestion(
    specs.map((s) => ({ id: s.key, exerciseId: s.exerciseId, sets: [] })),
    exerciseById,
  )

  const buildItems = (ownerId: string): SessionItem[] =>
    specs.map((sp) => {
      const ex = exerciseById[sp.exerciseId]
      if (ex?.kind === 'cardio') {
        const last = lastPerformance(sessions, ownerId, sp.exerciseId)?.item.cardio
        return {
          id: uid(),
          exerciseId: sp.exerciseId,
          sets: [],
          cardio: { minutes: sp.minutes, level: last?.level, distanceKm: undefined, done: false },
        }
      }
      let kg = sp.kg
      if (!singleOwner) {
        const last = lastPerformance(sessions, ownerId, sp.exerciseId)
        const done = last?.item.sets.filter((s) => s.done) ?? []
        kg = done.reduce((a, s) => Math.max(a, s.kg), 0)
      }
      return {
        id: uid(),
        exerciseId: sp.exerciseId,
        sets: Array.from({ length: sp.sets }, () => ({ kg, reps: sp.reps, done: false })),
      }
    })

  const save = () => {
    if (!meId || !owners.length) return
    const finalTitle = title.trim() || autoTitle
    const now = new Date().toISOString()
    if (existing) {
      const ownerId = owners[0]
      store.saveSession({ ...existing, ownerId, date: day, title: finalTitle, notes: notes || undefined, items: buildItems(ownerId) })
    } else {
      const groupId = owners.length > 1 ? uid() : undefined
      const list: Session[] = owners.map((ownerId) => ({
        id: uid(),
        ownerId,
        createdBy: meId,
        date: day,
        title: finalTitle,
        status: 'planned',
        items: buildItems(ownerId),
        notes: notes || undefined,
        groupId,
        updatedAt: now,
      }))
      store.saveSessions(list)
    }
    navigate({ name: 'planning', week: day }, { replace: true })
  }

  const copyFrom = (s: Session) => {
    setSpecs(
      s.items.map((it) => ({
        key: uid(),
        exerciseId: it.exerciseId,
        sets: Math.max(1, it.sets.length),
        reps: it.sets[0]?.reps ?? 10,
        kg: Math.max(0, ...it.sets.map((x) => x.kg)),
        minutes: it.cardio?.minutes ?? 15,
      })),
    )
    if (!title) setTitle(s.title)
    setCopying(false)
  }

  const whoOptions: { value: Who; label: string }[] = existing
    ? [
        { value: 'me', label: 'Moi' },
        ...(partner ? [{ value: 'partner' as Who, label: partner.name }] : []),
      ]
    : [
        { value: 'both', label: 'Les deux' },
        { value: 'me', label: 'Moi' },
        ...(partner ? [{ value: 'partner' as Who, label: partner.name }] : []),
      ]

  return (
    <div className="stack-lg">
      <header className="page-head">
        <button className="icon-btn" aria-label="Retour" onClick={() => back({ name: 'planning' })}>
          <IconBack />
        </button>
        <div className="grow">
          <h1>{existing ? 'Modifier la séance' : 'Planifier'}</h1>
          <p className="sub">{fmtDay(day)}</p>
        </div>
      </header>

      <section className="stack">
        <label className="field">
          <span>Date</span>
          <input className="input" type="date" value={day} onChange={(e) => e.target.value && setDay(e.target.value)} />
        </label>
        <div className="field">
          <span>Pour qui</span>
          <Seg label="Pour qui" value={who} options={whoOptions} onChange={setWho} />
          {who === 'both' ? (
            <p className="small muted">Une séance chacun, avec les charges de la dernière fois de chacun.</p>
          ) : null}
        </div>
        <label className="field">
          <span>Nom</span>
          <input className="input" placeholder={autoTitle} value={title} onChange={(e) => setTitle(e.target.value)} />
        </label>
      </section>

      <section className="stack">
        <div className="section-title">
          <h2>Exercices</h2>
          <button className="link" onClick={() => setCopying(true)}>
            <span className="row" style={{ gap: 4 }}>
              <IconCopy width={16} height={16} /> Reprendre une séance
            </span>
          </button>
        </div>

        {helpCount ? (
          <div className="banner row" style={{ alignItems: 'flex-start' }}>
            <IconHands width={20} height={20} style={{ flex: 'none', marginTop: 2 }} />
            <div className="grow">
              <strong>
                {helpCount} exercice{helpCount > 1 ? 's' : ''} avec aide
              </strong>{' '}
              {helper ? `(${helper} charge les disques).` : ''}
              {!helpGrouped ? (
                <div>
                  <button className="link" onClick={groupHelp}>
                    Les regrouper pour enchaîner
                  </button>
                </div>
              ) : null}
            </div>
          </div>
        ) : null}

        {specs.map((sp, i) => {
          const ex = exerciseById[sp.exerciseId]
          if (!ex) return null
          return (
            <div key={sp.key} className={`ex-card${ex.help && helpMatters ? ' help' : ''}`}>
              <div className="ex-head">
                <div className="grow">
                  <h3>{ex.name}</h3>
                  <div className="meta">
                    <ExerciseBadges ex={ex} helperName={helper} showHelp={helpMatters} />
                  </div>
                </div>
                <div className="row" style={{ gap: 0 }}>
                  <button className="icon-btn ghost" aria-label="Monter" disabled={i === 0} onClick={() => move(i, -1)}>
                    ↑
                  </button>
                  <button
                    className="icon-btn ghost"
                    aria-label="Descendre"
                    disabled={i === specs.length - 1}
                    onClick={() => move(i, 1)}
                  >
                    ↓
                  </button>
                  <button
                    className="icon-btn ghost"
                    aria-label="Retirer"
                    onClick={() => setSpecs((l) => l.filter((s) => s.key !== sp.key))}
                  >
                    <IconClose />
                  </button>
                </div>
              </div>
              {ex.kind === 'cardio' ? (
                <div className="cardio-grid">
                  <label>
                    Durée
                    <Stepper label="Minutes" unit="min" step={5} value={sp.minutes} onChange={(v) => update(sp.key, { minutes: v })} />
                  </label>
                </div>
              ) : (
                <div className="cardio-grid" style={{ gridTemplateColumns: singleOwner ? '1fr 1fr 1fr' : '1fr 1fr' }}>
                  <label>
                    Séries
                    <Stepper label="Séries" step={1} min={1} value={sp.sets} onChange={(v) => update(sp.key, { sets: v })} />
                  </label>
                  <label>
                    Reps
                    <Stepper label="Répétitions" step={1} min={1} value={sp.reps} onChange={(v) => update(sp.key, { reps: v })} />
                  </label>
                  {singleOwner ? (
                    <label>
                      Charge
                      <Stepper
                        label="Charge"
                        unit="kg"
                        step={ex.step ?? 2.5}
                        value={sp.kg}
                        onChange={(v) => update(sp.key, { kg: v })}
                      />
                    </label>
                  ) : null}
                </div>
              )}
            </div>
          )
        })}

        <button className="btn block" onClick={() => setPicking(true)}>
          <IconPlus /> Ajouter des exercices
        </button>

        <label className="field">
          <span>Notes</span>
          <textarea
            className="input"
            placeholder="Ex. : arriver tôt, la presse est souvent prise vers 18 h"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
          />
        </label>
      </section>

      <div className="bottom-bar">
        <div>
          {existing ? (
            <button
              className="btn danger"
              onClick={() => {
                if (confirm('Supprimer cette séance prévue ?')) {
                  store.deleteSession(existing.id)
                  navigate({ name: 'planning', week: day }, { replace: true })
                }
              }}
            >
              Supprimer
            </button>
          ) : null}
          <button className="btn primary lg grow" disabled={!specs.length || !owners.length} onClick={save}>
            {existing ? 'Enregistrer' : who === 'both' ? 'Planifier pour les deux' : 'Planifier'}
          </button>
        </div>
      </div>

      {picking ? (
        <ExercisePicker
          helperName={helper}
          onClose={() => setPicking(false)}
          onPick={(ids) => {
            setSpecs((l) => [...l, ...ids.map(specFor)])
            setPicking(false)
          }}
        />
      ) : null}

      {copying ? (
        <Sheet title="Reprendre une séance" onClose={() => setCopying(false)}>
          <div className="list">
            {sessions
              .filter((s) => s.items.length)
              .slice(0, 30)
              .map((s) => (
                <button key={s.id} className="list-item" onClick={() => copyFrom(s)}>
                  <span className="grow">
                    <span className="title">{s.title}</span>
                    <span className="small muted" style={{ display: 'block' }}>
                      {profiles.find((p) => p.id === s.ownerId)?.name} · {fmtDay(s.date)} · {s.items.length} exos
                    </span>
                  </span>
                </button>
              ))}
            {!sessions.some((s) => s.items.length) ? <p className="empty">Aucune séance à reprendre.</p> : null}
          </div>
        </Sheet>
      ) : null}
    </div>
  )
}
