import { useEffect, type ReactNode } from 'react'
import type { Exercise, Profile } from '../lib/types'
import { POSTURE_SHORT } from '../data/exercises'
import { IconClose, IconHands, IconWheelchair } from './Icons'

export function personColor(p?: Profile | null) {
  return p?.slot === 2 ? 'var(--p2)' : 'var(--p1)'
}

export function Person({ profile, you }: { profile?: Profile | null; you?: boolean }) {
  return (
    <span className="person">
      <span className="dot" style={{ background: personColor(profile) }} />
      {profile?.name ?? '?'}
      {you ? <span className="faint">(toi)</span> : null}
    </span>
  )
}

export function ExerciseBadges({ ex, helperName }: { ex: Exercise; helperName?: string }) {
  return (
    <>
      <span className={ex.posture === 'fauteuil' ? 'badge chair' : 'badge'}>
        {ex.posture === 'fauteuil' ? <IconWheelchair /> : null}
        {POSTURE_SHORT[ex.posture]}
      </span>
      {ex.help ? (
        <span className="badge help">
          <IconHands />
          {helperName ? `Aide ${helperName}` : 'Aide'}
        </span>
      ) : null}
    </>
  )
}

export function Seg<T extends string>({
  value,
  options,
  onChange,
  label,
}: {
  value: T
  options: { value: T; label: ReactNode }[]
  onChange: (v: T) => void
  label: string
}) {
  return (
    <div className="seg" role="group" aria-label={label}>
      {options.map((o) => (
        <button key={o.value} type="button" aria-pressed={o.value === value} onClick={() => onChange(o.value)}>
          {o.label}
        </button>
      ))}
    </div>
  )
}

export function Sheet({
  title,
  onClose,
  children,
  footer,
}: {
  title: ReactNode
  onClose: () => void
  children: ReactNode
  footer?: ReactNode
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      window.removeEventListener('keydown', onKey)
      document.body.style.overflow = prev
    }
  }, [onClose])
  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <div className="sheet" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}>
        <div className="sheet-head">
          <h2 className="grow">{title}</h2>
          <button className="icon-btn ghost" onClick={onClose} aria-label="Fermer">
            <IconClose />
          </button>
        </div>
        <div className="sheet-body">{children}</div>
        {footer ? <div className="sheet-foot">{footer}</div> : null}
      </div>
    </div>
  )
}

export function Stepper({
  value,
  onChange,
  step,
  min = 0,
  unit,
  label,
  decimals = 2,
}: {
  value: number
  onChange: (v: number) => void
  step: number
  min?: number
  unit?: string
  label: string
  decimals?: number
}) {
  const fix = (n: number) => Math.max(min, Number(n.toFixed(decimals)))
  return (
    <div className="stepper">
      <button type="button" aria-label={`${label} moins ${step}`} onClick={() => onChange(fix(value - step))}>
        −
      </button>
      <div>
        <input
          inputMode="decimal"
          aria-label={label}
          value={Number.isFinite(value) ? String(value).replace('.', ',') : ''}
          onFocus={(e) => e.currentTarget.select()}
          onChange={(e) => {
            const n = parseFloat(e.target.value.replace(',', '.'))
            onChange(Number.isFinite(n) ? fix(n) : 0)
          }}
        />
        {unit ? <span className="unit">{unit}</span> : null}
      </div>
      <button type="button" aria-label={`${label} plus ${step}`} onClick={() => onChange(fix(value + step))}>
        +
      </button>
    </div>
  )
}
