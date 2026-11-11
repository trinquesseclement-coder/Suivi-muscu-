import { useEffect, useMemo, useRef, useState } from 'react'
import { store, useStore } from '../lib/store'
import { back, navigate } from '../lib/router'
import type { Exercise, Session, SessionItem, SetEntry } from '../lib/types'
import { doneSets, e1rm, lastPerformance, personalRecords, sessionCardioMin, sessionSetCount, sessionTonnage } from '../lib/stats'
import { hasProgress, helperName, isLive, needsHelp, newItem, resetItem } from '../lib/sessions'
import { fmtDay, fmtDM, fmtNum, fmtTonnage, isoDate, uid } from '../lib/util'
import { ExercisePicker } from '../components/ExercisePicker'
import { ExerciseBadges, Person, Sheet, Stepper } from '../components/ui'
import { restAlert, unlockAudio, useWakeLock } from '../lib/device'
import { ExerciseThumb, MovementSheet } from '../components/ExerciseMedia'
import { IconBack, IconCheck, IconClose, IconCopy, IconMore, IconPlus, IconTimer, IconTrophy } from '../components/Icons'

const K_REST = 'suivi:rest'
export const getRest = () => Number(localStorage.getItem(K_REST)) || 90
export const setRest = (s: number) => localStorage.setItem(K_REST, String(s))

export function SessionPage({ id }: { id: string }) {
  const { sessions, profiles, meId, exerciseById } = useStore()
  const s = sessions.find((x) => x.id === id)
  const [picking, setPicking] = useState(false)
  const [finishing, setFinishing] = useState(false)
  const [menu, setMenu] = useState(false)
  const [restEnd, setRestEnd] = useState<number | null>(null)

  // Séance libre vide abandonnée : on ne la garde pas.
  const latest = useRef<Session | undefined>(s)
  latest.current = s
  useEffect(
    () => () => {
      const cur = latest.current
      if (!cur || cur.status !== 'planned' || cur.items.length || cur.title !== 'Séance libre') return
      // Décalé : en dev (StrictMode) le composant est démonté puis remonté aussitôt.
      setTimeout(() => {
        if (!location.hash.includes(cur.id)) store.deleteSession(cur.id)
      }, 0)
    },
    [],
  )

  const prevRecords = useMemo(
    () => (s ? personalRecords(sessions.filter((x) => x.id !== s.id && x.date <= s.date), s.ownerId) : {}),
    [sessions, s],
  )

  // Écran allumé pendant sa propre séance (mains moites, transferts…)
  useWakeLock(!!s && s.ownerId === meId && !s.endedAt)

  if (!s) {
    return (
      <div className="stack">
        <header className="page-head">
          <button className="icon-btn" aria-label="Retour" onClick={() => back()}>
            <IconBack />
          </button>
          <h1>Séance introuvable</h1>
        </header>
        <p className="muted">Elle a peut-être été supprimée.</p>
      </div>
    )
  }

  const owner = profiles.find((p) => p.id === s.ownerId)
  const canEdit = s.ownerId === meId
  const canEditPlan = canEdit || (s.createdBy === meId && s.status === 'planned')
  const helper = helperName(profiles)
  const helped = needsHelp(profiles, s.ownerId)

  const save = (patch: Partial<Session>) => store.saveSession({ ...s, ...patch })

  const updateItem = (itemId: string, fn: (it: SessionItem) => SessionItem, started = false) => {
    const items = s.items.map((it) => (it.id === itemId ? fn(it) : it))
    const patch: Partial<Session> = { items }
    if (started) {
      patch.status = 'done'
      if (!s.startedAt) patch.startedAt = new Date().toISOString()
      if (s.date > isoDate()) patch.date = isoDate()
    }
    save(patch)
  }

  const addExercises = (ids: string[]) => {
    const items = [...s.items, ...ids.map((eid) => newItem(exerciseById[eid], s.ownerId, sessions))]
    save({ items })
    setPicking(false)
  }

  const copyToMe = () => {
    if (!meId) return
    const copy: Session = {
      id: uid(),
      ownerId: meId,
      createdBy: meId,
      date: isoDate(),
      title: s.title,
      status: 'planned',
      items: s.items.map((it) => {
        const ex = exerciseById[it.exerciseId]
        return ex ? newItem(ex, meId, sessions) : resetItem(it)
      }),
      updatedAt: new Date().toISOString(),
    }
    store.saveSession(copy)
    navigate({ name: 'session', id: copy.id }, { replace: true })
  }

  const progress = hasProgress(s)
  const ton = sessionTonnage(s)
  const doneCount = s.items.filter((i) => doneSets(i).length || i.cardio?.done).length

  return (
    <div className="stack-lg">
      <header className="page-head">
        <button className="icon-btn" aria-label="Retour" onClick={() => back()}>
          <IconBack />
        </button>
        <div className="grow">
          <h1 style={{ fontSize: '1.35rem' }}>{s.title}</h1>
          <div className="sub row wrap" style={{ gap: 8, marginTop: 4 }}>
            <Person profile={owner} you={canEdit} />
            <span>{fmtDay(s.date)}</span>
            {isLive(s) ? <span className="badge live">En cours</span> : null}
          </div>
        </div>
        <button className="icon-btn" aria-label="Options" onClick={() => setMenu(true)}>
          <IconMore />
        </button>
      </header>

      {s.notes ? <p className="banner">{s.notes}</p> : null}

      {s.status === 'done' && progress ? (
        <div className="card tight tiles">
          <div className="tile">
            <div className="v">
              {doneCount}/{s.items.length}
            </div>
            <div className="l">exercices</div>
          </div>
          <div className="tile">
            <div className="v">{fmtTonnage(ton)}</div>
            <div className="l">{sessionSetCount(s)} série{sessionSetCount(s) > 1 ? 's' : ''}</div>
          </div>
          <div className="tile">
            <div className="v">{sessionCardioMin(s, exerciseById)} min</div>
            <div className="l">cardio</div>
          </div>
        </div>
      ) : null}

      <div className="stack">
        {s.items.map((it) => {
          const ex = exerciseById[it.exerciseId]
          if (!ex) return null
          return (
            <ExerciseBlock
              key={it.id}
              it={it}
              ex={ex}
              session={s}
              sessions={sessions}
              editable={canEdit}
              helperName={helper}
              showHelp={helped}
              record={prevRecords[ex.id]?.e1rm ?? 0}
              onChange={(fn, started) => updateItem(it.id, fn, started)}
              onRemove={() => {
                if (!hasProgressItem(it) || confirm(`Retirer ${ex.name} de la séance ?`)) {
                  save({ items: s.items.filter((x) => x.id !== it.id) })
                }
              }}
              onSetDone={() => setRestEnd(Date.now() + getRest() * 1000)}
            />
          )
        })}
        {!s.items.length ? (
          <p className="empty card">{canEdit ? 'Ajoute ton premier exercice.' : 'Séance vide.'}</p>
        ) : null}
        {canEdit ? (
          <button className="btn block" onClick={() => setPicking(true)}>
            <IconPlus /> Ajouter un exercice
          </button>
        ) : (
          <button className="btn block" onClick={copyToMe}>
            <IconCopy /> Faire cette séance moi aussi
          </button>
        )}
      </div>

      {canEdit ? (
        <div className="bottom-bar">
          <div>
            {restEnd ? <RestTimer end={restEnd} onAdd={(sec) => setRestEnd(restEnd + sec * 1000)} onClose={() => setRestEnd(null)} /> : null}
            <button
              className={`btn lg grow${progress ? ' primary' : ''}`}
              onClick={() => (progress ? setFinishing(true) : back())}
            >
              {progress ? (s.endedAt ? 'Modifier le bilan' : 'Terminer') : 'Fermer'}
            </button>
          </div>
        </div>
      ) : null}

      {picking ? <ExercisePicker helperName={helper} onClose={() => setPicking(false)} onPick={addExercises} /> : null}

      {finishing ? (
        <FinishSheet
          session={s}
          onClose={() => setFinishing(false)}
          onSave={(patch) => {
            save({ ...patch, status: 'done' })
            setFinishing(false)
            navigate({ name: 'home' }, { replace: true })
          }}
        />
      ) : null}

      {menu ? (
        <SessionMenu
          s={s}
          canEdit={canEdit}
          canEditPlan={canEditPlan && !progress}
          onClose={() => setMenu(false)}
          onSave={(patch) => {
            save(patch)
            setMenu(false)
          }}
        />
      ) : null}
    </div>
  )
}

const hasProgressItem = (it: SessionItem) => it.sets.some((s) => s.done) || !!it.cardio?.done

function ExerciseBlock({
  it,
  ex,
  session,
  sessions,
  editable,
  helperName,
  showHelp,
  record,
  onChange,
  onRemove,
  onSetDone,
}: {
  it: SessionItem
  ex: Exercise
  session: Session
  sessions: Session[]
  editable: boolean
  helperName?: string
  showHelp: boolean
  record: number
  onChange: (fn: (it: SessionItem) => SessionItem, started?: boolean) => void
  onRemove: () => void
  onSetDone: () => void
}) {
  const last = lastPerformance(sessions, session.ownerId, ex.id, session.id)
  const step = ex.step ?? 2.5
  const [media, setMedia] = useState(false)

  const setSet = (i: number, patch: Partial<SetEntry>, started = false) =>
    onChange((x) => ({ ...x, sets: x.sets.map((st, j) => (j === i ? { ...st, ...patch } : st)) }), started)

  /** Changer la charge ou les reps d'une série recopie la valeur dans les séries suivantes pas encore faites. */
  const setValue = (i: number, patch: Pick<Partial<SetEntry>, 'kg' | 'reps'>) =>
    onChange((x) => ({
      ...x,
      sets: x.sets.map((st, j) => (j === i || (j > i && !st.done) ? { ...st, ...patch } : st)),
    }))

  const lastText = last
    ? ex.kind === 'cardio'
      ? `${last.item.cardio?.minutes ?? 0} min${last.item.cardio?.distanceKm ? ` · ${fmtNum(last.item.cardio.distanceKm)} km` : ''}${last.item.cardio?.level ? ` · niv. ${last.item.cardio.level}` : ''}`
      : doneSets(last.item)
          .map((st) => `${fmtNum(st.kg)}×${st.reps}`)
          .join(' · ')
    : null

  return (
    <div className={`ex-card${ex.help && showHelp ? ' help' : ''}`}>
      <div className="ex-head">
        <ExerciseThumb ex={ex} onClick={() => setMedia(true)} />
        <div className="grow">
          <h3>{ex.name}</h3>
          <div className="meta">
            <ExerciseBadges ex={ex} helperName={helperName} showHelp={showHelp} />
          </div>
        </div>
        {editable ? (
          <button className="icon-btn ghost" aria-label={`Retirer ${ex.name}`} onClick={onRemove}>
            <IconClose />
          </button>
        ) : null}
      </div>
      {ex.note ? (
        <p className="ex-note">
          <strong>Réglage :</strong> {ex.note}
        </p>
      ) : null}
      {media ? <MovementSheet ex={ex} onClose={() => setMedia(false)} /> : null}
      {lastText ? (
        <p className="ex-last">
          Dernière fois ({fmtDM(last!.session.date)}) : <span className="tnum">{lastText}</span>
        </p>
      ) : null}

      {ex.kind === 'cardio' ? (
        <CardioBlock it={it} editable={editable} onChange={onChange} />
      ) : (
        <>
          <div className="sets">
            {it.sets.map((st, i) => {
              const isPR = st.done && record > 0 && e1rm(st.kg, st.reps) > record + 0.01
              return editable ? (
                <div key={i} className={`set-row${st.done ? ' done' : ''}`}>
                  <span className="set-n">{i + 1}</span>
                  <Stepper label={`Série ${i + 1} charge`} unit="kg" step={step} value={st.kg} onChange={(v) => setValue(i, { kg: v })} />
                  <Stepper label={`Série ${i + 1} répétitions`} unit="reps" step={1} value={st.reps} onChange={(v) => setValue(i, { reps: v })} />
                  <button
                    className="check"
                    aria-pressed={st.done}
                    aria-label={st.done ? `Série ${i + 1} faite` : `Valider la série ${i + 1}`}
                    onClick={() => {
                      const done = !st.done
                      setSet(i, { done }, done)
                      if (done) {
                        unlockAudio()
                        onSetDone()
                        navigator.vibrate?.(30)
                      }
                    }}
                  >
                    {isPR ? <IconTrophy /> : <IconCheck />}
                  </button>
                </div>
              ) : (
                <div key={i} className={`set-row${st.done ? ' done' : ''}`} style={{ gridTemplateColumns: '28px 1fr auto' }}>
                  <span className="set-n">{i + 1}</span>
                  <span className="tnum" style={{ fontWeight: 650 }}>
                    {fmtNum(st.kg)} kg × {st.reps}
                  </span>
                  <span className="small muted">
                    {isPR ? (
                      <span className="badge pr">
                        <IconTrophy /> Record
                      </span>
                    ) : st.done ? (
                      'fait'
                    ) : (
                      'prévu'
                    )}
                  </span>
                </div>
              )
            })}
          </div>
          {editable ? (
            <div className="ex-foot">
              <button
                className="btn sm"
                onClick={() =>
                  onChange((x) => {
                    const prev = x.sets[x.sets.length - 1] ?? { kg: 0, reps: 10 }
                    return { ...x, sets: [...x.sets, { kg: prev.kg, reps: prev.reps, done: false }] }
                  })
                }
              >
                <IconPlus width={18} height={18} /> Série
              </button>
              {it.sets.length ? (
                <button className="btn sm ghost" onClick={() => onChange((x) => ({ ...x, sets: x.sets.slice(0, -1) }))}>
                  Retirer la dernière
                </button>
              ) : null}
            </div>
          ) : null}
        </>
      )}
    </div>
  )
}

function CardioBlock({
  it,
  editable,
  onChange,
}: {
  it: SessionItem
  editable: boolean
  onChange: (fn: (it: SessionItem) => SessionItem, started?: boolean) => void
}) {
  const c = it.cardio ?? { minutes: 15, done: false }
  const set = (patch: Partial<typeof c>, started = false) =>
    onChange((x) => ({ ...x, cardio: { ...c, ...patch } }), started)
  if (!editable) {
    return (
      <p className="ex-last tnum" style={{ paddingBottom: 14 }}>
        {c.done ? 'Fait' : 'Prévu'} : {c.minutes} min
        {c.distanceKm ? ` · ${fmtNum(c.distanceKm)} km` : ''}
        {c.level ? ` · niveau ${c.level}` : ''}
        {c.calories ? ` · ${c.calories} kcal` : ''}
      </p>
    )
  }
  return (
    <>
      <div className="cardio-grid">
        <label>
          Durée
          <Stepper label="Durée" unit="min" step={1} value={c.minutes} onChange={(v) => set({ minutes: v })} />
        </label>
        <label>
          Distance
          <Stepper label="Distance" unit="km" step={0.1} decimals={1} value={c.distanceKm ?? 0} onChange={(v) => set({ distanceKm: v || undefined })} />
        </label>
        <label>
          Niveau / résistance
          <Stepper label="Niveau" step={1} value={c.level ?? 0} onChange={(v) => set({ level: v || undefined })} />
        </label>
        <label>
          Calories
          <Stepper label="Calories" unit="kcal" step={10} value={c.calories ?? 0} onChange={(v) => set({ calories: v || undefined })} />
        </label>
      </div>
      <div className="ex-foot">
        <button
          className={`btn grow${c.done ? ' primary' : ''}`}
          aria-pressed={c.done}
          onClick={() => {
            set({ done: !c.done }, !c.done)
            navigator.vibrate?.(30)
          }}
        >
          <IconCheck /> {c.done ? 'Fait' : 'Valider le cardio'}
        </button>
      </div>
    </>
  )
}

function RestTimer({ end, onAdd, onClose }: { end: number; onAdd: (s: number) => void; onClose: () => void }) {
  const [now, setNow] = useState(Date.now())
  const buzzed = useRef(false)
  useEffect(() => {
    buzzed.current = false
    const t = setInterval(() => setNow(Date.now()), 250)
    return () => clearInterval(t)
  }, [end])
  const left = Math.round((end - now) / 1000)
  useEffect(() => {
    if (left <= 0 && !buzzed.current) {
      buzzed.current = true
      restAlert()
    }
  }, [left])
  const announce = left <= 0 ? 'Repos terminé, série suivante.' : left <= 10 ? 'Plus que 10 secondes de repos.' : ''
  const abs = Math.abs(left)
  const txt = `${left < 0 ? '+' : ''}${Math.floor(abs / 60)}:${String(abs % 60).padStart(2, '0')}`
  return (
    <div className={`timer${left <= 0 ? ' over' : ''}`} role="timer" aria-live="off">
      <span className="sr-only" aria-live="assertive">
        {announce}
      </span>
      <IconTimer width={20} height={20} />
      <span style={{ minWidth: 44 }}>{txt}</span>
      <button onClick={() => onAdd(30)} aria-label="Ajouter 30 secondes">
        +30
      </button>
      <button onClick={onClose} aria-label="Arrêter le minuteur">
        ✕
      </button>
    </div>
  )
}

function FinishSheet({
  session,
  onClose,
  onSave,
}: {
  session: Session
  onClose: () => void
  onSave: (p: Partial<Session>) => void
}) {
  const auto = session.startedAt ? Math.max(1, Math.round((Date.now() - new Date(session.startedAt).getTime()) / 60000)) : 60
  const [rpe, setRpe] = useState(session.rpe ?? 7)
  const [duration, setDuration] = useState(session.durationMin ?? Math.min(auto, 240))
  const [notes, setNotes] = useState(session.notes ?? '')
  return (
    <Sheet
      title="Bilan de la séance"
      onClose={onClose}
      footer={
        <button
          className="btn primary block lg"
          onClick={() => onSave({ rpe, durationMin: duration, notes: notes || undefined, endedAt: session.endedAt ?? new Date().toISOString() })}
        >
          Enregistrer
        </button>
      }
    >
      <div className="stack">
        <div className="field">
          <span>Ressenti global (1 = facile, 10 = à fond)</span>
          <div className="rpe">
            {Array.from({ length: 10 }, (_, i) => i + 1).map((n) => (
              <button key={n} aria-pressed={rpe === n} onClick={() => setRpe(n)}>
                {n}
              </button>
            ))}
          </div>
        </div>
        <label className="field">
          <span>Durée</span>
          <Stepper label="Durée" unit="min" step={5} value={duration} onChange={setDuration} />
        </label>
        <label className="field">
          <span>Notes (douleurs, machine prise, réglages du siège…)</span>
          <textarea className="input" value={notes} onChange={(e) => setNotes(e.target.value)} />
        </label>
      </div>
    </Sheet>
  )
}

function SessionMenu({
  s,
  canEdit,
  canEditPlan,
  onClose,
  onSave,
}: {
  s: Session
  canEdit: boolean
  canEditPlan: boolean
  onClose: () => void
  onSave: (p: Partial<Session>) => void
}) {
  const [title, setTitle] = useState(s.title)
  const [date, setDate] = useState(s.date)
  return (
    <Sheet title="Options" onClose={onClose}>
      <div className="stack">
        {canEdit ? (
          <>
            <label className="field">
              <span>Nom</span>
              <input className="input" value={title} onChange={(e) => setTitle(e.target.value)} />
            </label>
            <label className="field">
              <span>Date</span>
              <input className="input" type="date" value={date} onChange={(e) => e.target.value && setDate(e.target.value)} />
            </label>
            <button className="btn primary" onClick={() => onSave({ title: title.trim() || s.title, date })}>
              Enregistrer
            </button>
          </>
        ) : null}
        {canEditPlan ? (
          <button className="btn" onClick={() => navigate({ name: 'plan', id: s.id }, { replace: true })}>
            Modifier le plan
          </button>
        ) : null}
        {canEdit || canEditPlan ? (
          <button
            className="btn danger"
            onClick={() => {
              if (confirm('Supprimer cette séance ? C’est définitif.')) {
                store.deleteSession(s.id)
                navigate({ name: 'home' }, { replace: true })
              }
            }}
          >
            Supprimer la séance
          </button>
        ) : (
          <p className="muted small">C’est la séance de quelqu’un d’autre : tu peux la consulter et la copier.</p>
        )}
      </div>
    </Sheet>
  )
}
