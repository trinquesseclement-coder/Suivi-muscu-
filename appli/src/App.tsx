import { useStore } from './lib/store'
import { navigate, useRoute, type Route } from './lib/router'
import { Home } from './pages/Home'
import { Planning } from './pages/Planning'
import { PlanEditor } from './pages/PlanEditor'
import { SessionPage } from './pages/SessionPage'
import { Stats } from './pages/Stats'
import { Machines } from './pages/Machines'
import { Settings } from './pages/Settings'
import { Login, Onboarding } from './pages/Auth'
import { IconCalendar, IconChart, IconDumbbell, IconHome, IconPlus } from './components/Icons'

const TABS: { route: Route; label: string; icon: typeof IconHome }[] = [
  { route: { name: 'home' }, label: 'Accueil', icon: IconHome },
  { route: { name: 'planning' }, label: 'Planning', icon: IconCalendar },
  { route: { name: 'stats' }, label: 'Charge', icon: IconChart },
  { route: { name: 'machines' }, label: 'Machines', icon: IconDumbbell },
]

export default function App() {
  const st = useStore()
  const route = useRoute()

  if (st.mode === 'cloud') {
    if (!st.authReady) return <Splash />
    if (!st.authed)
      return (
        <main className="app no-tabbar">
          <Login />
        </main>
      )
    if (!st.loaded) return <Splash />
    if (!st.profiles.some((p) => p.id === st.meId))
      return (
        <main className="app no-tabbar">
          <Onboarding />
        </main>
      )
  }

  const withTabs = route.name !== 'session' && route.name !== 'plan'

  return (
    <>
      <main className={`app${withTabs ? '' : ' no-tabbar'}`}>
        {route.name === 'home' && <Home />}
        {route.name === 'planning' && <Planning week={route.week} />}
        {route.name === 'plan' && <PlanEditor key={route.id ?? route.date ?? 'new'} id={route.id} date={route.date} />}
        {route.name === 'session' && <SessionPage key={route.id} id={route.id} />}
        {route.name === 'stats' && <Stats />}
        {route.name === 'machines' && <Machines />}
        {route.name === 'settings' && <Settings />}
      </main>
      {withTabs ? <TabBar route={route} /> : null}
    </>
  )
}

function TabBar({ route }: { route: Route }) {
  const tabs = [...TABS.slice(0, 2), null, ...TABS.slice(2)]
  return (
    <div className="tabbar">
      <nav aria-label="Navigation principale">
        {tabs.map((t) =>
          t ? (
            <button
              key={t.label}
              aria-label={t.label}
              aria-current={route.name === t.route.name ? 'page' : undefined}
              onClick={() => navigate(t.route, { replace: true })}
            >
              <t.icon />
              <span className="lbl">{t.label}</span>
            </button>
          ) : (
            <button key="plan" className="fab" aria-label="Planifier une séance" onClick={() => navigate({ name: 'plan' })}>
              <IconPlus />
            </button>
          ),
        )}
      </nav>
    </div>
  )
}

function Splash() {
  return (
    <main className="app no-tabbar" style={{ display: 'grid', placeItems: 'center' }}>
      <p className="muted">Chargement…</p>
    </main>
  )
}
