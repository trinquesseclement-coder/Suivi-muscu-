import { useState } from 'react'
import { EQUIPMENT_LABEL, MUSCLE_LABEL } from '../data/exercises'
import { useStore } from '../lib/store'
import { ExerciseBadges, Sheet } from './ui'
import { applyFilters, ExerciseFilters, useFilters } from './ExerciseFilters'
import { IconCheck } from './Icons'

export function ExercisePicker({
  onClose,
  onPick,
  helperName,
}: {
  onClose: () => void
  onPick: (ids: string[]) => void
  helperName?: string
}) {
  const { exercises } = useStore()
  const [filters, setFilters] = useFilters()
  const [picked, setPicked] = useState<string[]>([])
  const list = applyFilters(exercises, filters)
  const toggle = (id: string) => setPicked((p) => (p.includes(id) ? p.filter((x) => x !== id) : [...p, id]))

  return (
    <Sheet
      title="Ajouter des exercices"
      onClose={onClose}
      footer={
        <button className="btn primary block lg" disabled={!picked.length} onClick={() => onPick(picked)}>
          Ajouter {picked.length ? `(${picked.length})` : ''}
        </button>
      }
    >
      <div className="stack">
        <ExerciseFilters value={filters} onChange={setFilters} helperName={helperName} />
        <div className="list">
          {list.map((ex) => {
            const on = picked.includes(ex.id)
            return (
              <button key={ex.id} className={`list-item${on ? ' selected' : ''}`} onClick={() => toggle(ex.id)}>
                <span className={`tick${on ? ' on' : ''}`}>
                  <IconCheck />
                </span>
                <span className="grow">
                  <span className="title">{ex.name}</span>
                  <span className="meta">
                    <span className="badge">{MUSCLE_LABEL[ex.muscle]}</span>
                    <ExerciseBadges ex={ex} helperName={helperName} />
                    <span className="faint small">{EQUIPMENT_LABEL[ex.equipment]}</span>
                  </span>
                </span>
              </button>
            )
          })}
          {!list.length ? <p className="empty">Aucun exercice avec ces filtres.</p> : null}
        </div>
      </div>
    </Sheet>
  )
}
