import { createRoot } from 'react-dom/client'
import { registerSW } from 'virtual:pwa-register'
import App from './App'
import { applyTheme } from './pages/Settings'
import '@fontsource/poppins/latin-400.css'
import '@fontsource/poppins/latin-500.css'
import '@fontsource/poppins/latin-600.css'
import './styles.css'

applyTheme()
registerSW({ immediate: true })

createRoot(document.getElementById('root')!).render(<App />)
