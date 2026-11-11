import { useEffect } from 'react'

/**
 * Garde l'écran allumé tant que `active` est vrai (séance en cours).
 * Le navigateur relâche le verrou quand l'appli passe en arrière-plan :
 * on le redemande au retour. Sans support (vieux navigateurs) : rien.
 */
export function useWakeLock(active: boolean) {
  useEffect(() => {
    if (!active || !('wakeLock' in navigator)) return
    let lock: WakeLockSentinel | null = null
    let cancelled = false
    const request = async () => {
      try {
        const l = await navigator.wakeLock.request('screen')
        if (cancelled) void l.release()
        else lock = l
      } catch {
        /* refusé (batterie faible, onglet caché…) : tant pis */
      }
    }
    const onVisible = () => {
      if (document.visibilityState === 'visible') void request()
    }
    void request()
    document.addEventListener('visibilitychange', onVisible)
    return () => {
      cancelled = true
      document.removeEventListener('visibilitychange', onVisible)
      void lock?.release()
    }
  }, [active])
}

// ---------- son de fin de repos ----------
// iPhone : pas de vibration dans Safari. On joue un bip via Web Audio, qu'il faut
// « déverrouiller » pendant un geste de l'utilisateur (le tap sur la coche).

const K_SOUND = 'suivi:sound'
export const isSoundOn = () => localStorage.getItem(K_SOUND) !== 'off'
export const setSoundOn = (on: boolean) => localStorage.setItem(K_SOUND, on ? 'on' : 'off')

let ctx: AudioContext | null = null

/** À appeler dans un gestionnaire de clic. */
export function unlockAudio() {
  if (!isSoundOn()) return
  try {
    // Son court qui se mélange à la musique au lieu de la couper (Safari 16.4+)
    const session = (navigator as Navigator & { audioSession?: { type: string } }).audioSession
    if (session) session.type = 'transient'
    ctx ??= new AudioContext()
    if (ctx.state === 'suspended') void ctx.resume()
  } catch {
    ctx = null
  }
}

/** Trois bips courts. */
export function beep() {
  if (!isSoundOn() || !ctx) return
  const t0 = ctx.currentTime + 0.02
  for (let i = 0; i < 3; i++) {
    const t = t0 + i * 0.22
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()
    osc.type = 'sine'
    osc.frequency.value = i === 2 ? 1320 : 880
    gain.gain.setValueAtTime(0.0001, t)
    gain.gain.exponentialRampToValueAtTime(0.5, t + 0.02)
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.16)
    osc.connect(gain).connect(ctx.destination)
    osc.start(t)
    osc.stop(t + 0.18)
  }
}

/** Fin de repos : son + vibration (Android). */
export function restAlert() {
  beep()
  navigator.vibrate?.([200, 100, 200])
}
