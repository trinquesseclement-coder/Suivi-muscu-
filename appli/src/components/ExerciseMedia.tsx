import { useEffect, useRef, useState } from 'react'
import type { Exercise } from '../lib/types'
import { store } from '../lib/store'
import { toPhoto } from '../lib/image'
import { ILLUSTRATION_CREDIT, illustrationFor } from '../data/illustrations'
import { Sheet } from './ui'
import { IconDumbbell } from './Icons'

/** Vignette : la photo de TA machine si elle existe, sinon l'illustration du mouvement. */
export function ExerciseThumb({ ex, size = 52, onClick }: { ex: Exercise; size?: number; onClick?: () => void }) {
  const ill = illustrationFor(ex.id)
  const src = ex.photo ?? ill?.frames[0]
  const [broken, setBroken] = useState(false)
  const style = { width: size, height: size }
  const content =
    src && !broken ? (
      <img className="thumb" style={style} src={src} alt="" loading="lazy" onError={() => setBroken(true)} />
    ) : (
      <span className="thumb thumb-empty" style={style} aria-hidden="true">
        <IconDumbbell />
      </span>
    )
  if (!onClick) return content
  return (
    <button className="thumb-btn" onClick={onClick} aria-label={`Voir ${ex.name} : machine et mouvement`}>
      {content}
    </button>
  )
}

/** Fiche visuelle : photo de la machine (à prendre soi-même) + mouvement en deux temps. */
export function MovementSheet({ ex, onClose }: { ex: Exercise; onClose: () => void }) {
  const ill = illustrationFor(ex.id)
  const fileRef = useRef<HTMLInputElement>(null)
  const [frame, setFrame] = useState(0)
  const [busy, setBusy] = useState(false)
  const [failed, setFailed] = useState(false)
  const reduced = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches

  useEffect(() => {
    if (!ill || reduced) return
    const t = setInterval(() => setFrame((f) => 1 - f), 1100)
    return () => clearInterval(t)
  }, [ill, reduced])

  return (
    <Sheet title={ex.name} onClose={onClose}>
      <div className="stack">
        {ex.note ? (
          <p className="ex-note" style={{ margin: 0 }}>
            <strong>Réglage :</strong> {ex.note}
          </p>
        ) : null}

        <section className="stack" style={{ gap: 8 }}>
          <h3>Ta machine à la salle</h3>
          {ex.photo ? <img className="machine-photo" src={ex.photo} alt={`Photo de la machine ${ex.name}`} /> : null}
          <div className="row wrap">
            <button className="btn sm" disabled={busy} onClick={() => fileRef.current?.click()}>
              {busy ? 'Envoi…' : ex.photo ? 'Changer la photo' : 'Prendre la machine en photo'}
            </button>
            {ex.photo ? (
              <button className="btn sm ghost danger" onClick={() => store.saveExercise({ ...ex, photo: undefined })}>
                Retirer
              </button>
            ) : null}
          </div>
          {!ex.photo ? (
            <p className="small muted">Pour la reconnaître du premier coup d’œil. La photo est partagée avec ton binôme.</p>
          ) : null}
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
                store.saveExercise({ ...ex, photo: await toPhoto(f) })
              } catch {
                alert('Impossible de lire cette image.')
              } finally {
                setBusy(false)
              }
            }}
          />
        </section>

        {ill ? (
          <section className="stack" style={{ gap: 8 }}>
            <h3>Le mouvement</h3>
            {failed ? (
              <p className="small muted">Illustration indisponible hors ligne. Elle s’affichera avec du réseau, puis restera en mémoire.</p>
            ) : reduced ? (
              <div className="row" style={{ gap: 8 }}>
                {ill.frames.map((src, i) => (
                  <img key={src} className="movement" src={src} alt={i === 0 ? 'Position de départ' : 'Position d’arrivée'} onError={() => setFailed(true)} />
                ))}
              </div>
            ) : (
              <div className="movement-stage">
                {ill.frames.map((src, i) => (
                  <img
                    key={src}
                    className="movement"
                    src={src}
                    alt={i === 0 ? 'Position de départ' : 'Position d’arrivée'}
                    style={{ opacity: frame === i ? 1 : 0 }}
                    onError={() => setFailed(true)}
                  />
                ))}
                <span className="movement-label">{frame === 0 ? 'Départ' : 'Arrivée'}</span>
              </div>
            )}
            {ill.approx ? <p className="small muted">Mouvement proche : ce n’est pas exactement la même machine.</p> : null}
            <p className="small faint">{ILLUSTRATION_CREDIT}</p>
          </section>
        ) : (
          <p className="small muted">Pas d’illustration pour cet exercice : prends ta machine en photo.</p>
        )}
      </div>
    </Sheet>
  )
}
