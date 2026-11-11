import { useState } from 'react'
import { store, useStore } from '../lib/store'
import { BASE_EXERCISES, EQUIPMENT_LABEL, MUSCLE_LABEL, POSTURE_LABEL } from '../data/exercises'
import type { Equipment, Exercise, Muscle, Posture } from '../lib/types'
import { helperName } from '../lib/sessions'
import { uid } from '../lib/util'
import { applyFilters, ExerciseFilters, useFilters } from '../components/ExerciseFilters'
import { ExerciseBadges, Seg, Sheet, Stepper } from '../components/ui'
import { IconChevron, IconPlus } from '../components/Icons'

export function Machines() {
  const { exercises, profiles } = useStore()
  const [filters, setFilters] = useFilters('suivi:filters:machines')
  const [editing, setEditing] = useState<Exercise | null>(null)
  const helper = helperName(profiles)
  const list = applyFilters(exercises, filters)
  const muscu = list.filter((e) => e.kind === 'muscu')
  const cardio = list.filter((e) => e.kind === 'cardio')

  return (
    <div className="stack-lg">
      <header className="page-head">
        <div className="grow">
          <h1>Machines</h1>
          <p className="sub">{exercises.length} exercices · touche pour corriger</p>
        </div>
        <button
          className="icon-btn"
          aria-label="Ajouter une machine"
          onClick={() =>
            setEditing({
              id: `perso-${uid()}`,
              name: '',
              kind: 'muscu',
              muscle: 'pecs',
              posture: 'transfert',
              help: false,
              equipment: 'machine',
              step: 5,
              custom: true,
            })
          }
        >
          <IconPlus />
        </button>
      </header>

      <ExerciseFilters value={filters} onChange={setFilters} helperName={helper} />

      {[
        { title: 'Musculation', items: muscu },
        { title: 'Cardio', items: cardio },
      ].map((g) =>
        g.items.length ? (
          <section key={g.title}>
            <div className="section-title">
              <h2>{g.title}</h2>
              <span className="small muted">{g.items.length}</span>
            </div>
            <div className="list">
              {g.items.map((ex) => (
                <button key={ex.id} className="list-item" onClick={() => setEditing(ex)}>
                  <span className="grow">
                    <span className="title">{ex.name}</span>
                    <span className="meta">
                      {ex.kind === 'muscu' ? <span className="badge">{MUSCLE_LABEL[ex.muscle]}</span> : null}
                      <ExerciseBadges ex={ex} helperName={helper} />
                    </span>
                    {ex.note ? (
                      <span className="small muted" style={{ display: 'block', marginTop: 4 }}>
                        {ex.note}
                      </span>
                    ) : null}
                  </span>
                  <IconChevron width={18} height={18} className="faint" />
                </button>
              ))}
            </div>
          </section>
        ) : null,
      )}
      {!list.length ? <p className="empty card">Aucune machine avec ces filtres.</p> : null}

      {editing ? <ExerciseEditor ex={editing} helperName={helper} onClose={() => setEditing(null)} /> : null}
    </div>
  )
}

function ExerciseEditor({ ex, onClose, helperName }: { ex: Exercise; onClose: () => void; helperName?: string }) {
  const [draft, setDraft] = useState<Exercise>(ex)
  const set = (p: Partial<Exercise>) => setDraft((d) => ({ ...d, ...p }))
  const isBase = BASE_EXERCISES.some((b) => b.id === ex.id)
  const isNew = !!ex.custom && !ex.name

  return (
    <Sheet
      title={isNew ? 'Nouvelle machine' : 'Modifier'}
      onClose={onClose}
      footer={
        <>
          {!isNew ? (
            <button
              className="btn danger"
              onClick={() => {
                if (confirm(isBase ? 'Masquer cet exercice du catalogue ?' : 'Supprimer cet exercice ?')) {
                  store.saveExercise({ ...draft, deleted: true })
                  onClose()
                }
              }}
            >
              {isBase ? 'Masquer' : 'Supprimer'}
            </button>
          ) : null}
          <button
            className="btn primary grow"
            disabled={!draft.name.trim()}
            onClick={() => {
              store.saveExercise({ ...draft, name: draft.name.trim(), muscle: draft.kind === 'cardio' ? 'cardio' : draft.muscle })
              onClose()
            }}
          >
            Enregistrer
          </button>
        </>
      }
    >
      <div className="stack">
        <label className="field">
          <span>Nom</span>
          <input className="input" value={draft.name} onChange={(e) => set({ name: e.target.value })} placeholder="Ex. : Chest press Technogym" />
        </label>
        {draft.custom ? (
          <div className="field">
            <span>Type</span>
            <Seg
              label="Type"
              value={draft.kind}
              onChange={(kind) => set({ kind, equipment: kind === 'cardio' ? 'cardio' : 'machine' })}
              options={[
                { value: 'muscu', label: 'Musculation' },
                { value: 'cardio', label: 'Cardio' },
              ]}
            />
          </div>
        ) : null}
        <div className="field">
          <span>Comment tu la fais</span>
          <Seg<Posture>
            label="Posture"
            value={draft.posture}
            onChange={(posture) => set({ posture })}
            options={(Object.keys(POSTURE_LABEL) as Posture[]).map((p) => ({ value: p, label: p === 'fauteuil' ? 'Fauteuil' : POSTURE_LABEL[p] }))}
          />
          <p className="small muted">
            Fauteuil = sans quitter le fauteuil · Transfert = s’installer sur le siège · Debout = appui court
          </p>
        </div>
        <div className="field">
          <span>Besoin d’aide ?</span>
          <Seg
            label="Aide"
            value={draft.help ? 'yes' : 'no'}
            onChange={(v) => set({ help: v === 'yes' })}
            options={[
              { value: 'no', label: 'Seul' },
              { value: 'yes', label: helperName ? `Avec ${helperName}` : 'Avec aide' },
            ]}
          />
        </div>
        {draft.kind === 'muscu' ? (
          <>
            <label className="field">
              <span>Muscle principal</span>
              <select className="input" value={draft.muscle} onChange={(e) => set({ muscle: e.target.value as Muscle })}>
                {(Object.keys(MUSCLE_LABEL) as Muscle[])
                  .filter((m) => m !== 'cardio')
                  .map((m) => (
                    <option key={m} value={m}>
                      {MUSCLE_LABEL[m]}
                    </option>
                  ))}
              </select>
            </label>
            <label className="field">
              <span>Équipement</span>
              <select className="input" value={draft.equipment} onChange={(e) => set({ equipment: e.target.value as Equipment })}>
                {(Object.keys(EQUIPMENT_LABEL) as Equipment[])
                  .filter((k) => k !== 'cardio')
                  .map((k) => (
                    <option key={k} value={k}>
                      {EQUIPMENT_LABEL[k]}
                    </option>
                  ))}
              </select>
            </label>
            <label className="field">
              <span>Pas des boutons +/−</span>
              <Stepper label="Pas" unit="kg" step={1.25} min={0.5} value={draft.step ?? 2.5} onChange={(step) => set({ step })} />
            </label>
          </>
        ) : null}
        <label className="field">
          <span>Note (réglages, numéro de la machine…)</span>
          <textarea
            className="input"
            value={draft.note ?? ''}
            onChange={(e) => set({ note: e.target.value || undefined })}
            placeholder="Ex. : siège cran 4, dossier cran 2, retirer le siège pour le fauteuil"
          />
        </label>
      </div>
    </Sheet>
  )
}
