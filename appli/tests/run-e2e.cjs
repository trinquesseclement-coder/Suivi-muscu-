// Construit les deux variantes (locale et « en ligne » vers le faux Supabase), puis lance le test.
const { execSync, spawn } = require('child_process')
const path = require('path')
const root = path.join(__dirname, '..')
const tmp = path.join(__dirname, '.tmp')
const run = (cmd, env = {}) => execSync(cmd, { cwd: root, stdio: 'inherit', env: { ...process.env, ...env } })
run(`npx vite build --outDir ${tmp}/dist-local --emptyOutDir --logLevel warn`, { VITE_SUPABASE_URL: '', VITE_SUPABASE_ANON_KEY: '' })
run(`npx vite build --outDir ${tmp}/dist-cloud --emptyOutDir --logLevel warn`, {
  VITE_SUPABASE_URL: 'http://localhost:54321',
  VITE_SUPABASE_ANON_KEY: 'fake-anon-key-0123456789abcdef',
})
const fake = spawn('node', [path.join(__dirname, 'fake-supabase.cjs')], { stdio: 'ignore' })
setTimeout(() => {
  const t = spawn('node', [path.join(__dirname, 'e2e.cjs')], { stdio: 'inherit' })
  t.on('exit', (code) => {
    fake.kill()
    process.exit(code ?? 1)
  })
}, 800)
