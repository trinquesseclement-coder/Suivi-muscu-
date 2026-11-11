import { store, useStore } from '../lib/store'
import { navigate } from '../lib/router'

const LABEL = {
  local: 'Local',
  synced: 'Synchro',
  syncing: 'Envoi…',
  offline: 'Hors ligne',
  error: 'Erreur synchro',
} as const

const COLOR = {
  local: 'var(--text-3)',
  synced: 'var(--good)',
  syncing: 'var(--warn)',
  offline: 'var(--text-3)',
  error: 'var(--danger)',
} as const

export function SyncPill() {
  const { sync, pending, mode } = useStore()
  return (
    <button
      className="sync-pill"
      onClick={() => (mode === 'cloud' ? void store.syncNow() : navigate({ name: 'settings' }))}
      title={mode === 'local' ? 'Données sur ce téléphone uniquement' : 'Synchroniser maintenant'}
    >
      <span className="dot" style={{ background: COLOR[sync], width: 8, height: 8 }} />
      {LABEL[sync]}
      {pending && sync !== 'local' ? ` (${pending})` : ''}
    </button>
  )
}
