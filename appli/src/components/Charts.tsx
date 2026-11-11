import { useLayoutEffect, useRef, useState, type ReactNode } from 'react'
import { fmtDM, parseDate } from '../lib/util'

export interface Series {
  key: string
  name: string
  color: string
  values: number[]
}

function useWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null)
  const [w, setW] = useState(320)
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const ro = new ResizeObserver(([e]) => setW(Math.max(200, Math.floor(e.contentRect.width))))
    ro.observe(el)
    return () => ro.disconnect()
  }, [])
  return [ref, w] as const
}

/** Graduations « rondes » de 0 à max. */
function niceTicks(max: number, count = 4): number[] {
  if (max <= 0) return [0, 1]
  const raw = max / count
  const mag = 10 ** Math.floor(Math.log10(raw))
  const step = [1, 2, 2.5, 5, 10].map((m) => m * mag).find((s) => s >= raw) ?? raw
  const ticks: number[] = []
  for (let v = 0; v <= max + step * 0.001; v += step) ticks.push(v)
  if (ticks[ticks.length - 1] < max) ticks.push(ticks[ticks.length - 1] + step)
  return ticks
}

/** Rectangle à coins hauts arrondis, ancré sur la ligne de base. */
function barPath(x: number, y: number, w: number, h: number, r = 4) {
  if (h <= 0) return ''
  const rr = Math.min(r, w / 2, h)
  return `M${x},${y + h}V${y + rr}Q${x},${y} ${x + rr},${y}H${x + w - rr}Q${x + w},${y} ${x + w},${y + rr}V${y + h}Z`
}
function hbarPath(x: number, y: number, w: number, h: number, r = 4) {
  if (w <= 0) return ''
  const rr = Math.min(r, h / 2, w)
  return `M${x},${y}H${x + w - rr}Q${x + w},${y} ${x + w},${y + rr}V${y + h - rr}Q${x + w},${y + h} ${x + w - rr},${y + h}H${x}Z`
}

export function Legend({ series }: { series: { key: string; name: string; color: string }[] }) {
  if (series.length < 2) return null
  return (
    <div className="legend">
      {series.map((s) => (
        <span key={s.key}>
          <span className="dot" style={{ background: s.color }} />
          {s.name}
        </span>
      ))}
    </div>
  )
}

/** Cadre commun : titre, légende, bascule tableau. */
export function ChartCard({
  title,
  subtitle,
  series,
  table,
  children,
  right,
}: {
  title: string
  subtitle?: string
  series: { key: string; name: string; color: string }[]
  table: { head: string[]; rows: (string | number)[][] }
  children: ReactNode
  right?: ReactNode
}) {
  const [showTable, setShowTable] = useState(false)
  return (
    <section className="card">
      <div className="section-title">
        <div>
          <h2>{title}</h2>
          {subtitle ? <p className="small muted">{subtitle}</p> : null}
        </div>
        {right}
      </div>
      <Legend series={series} />
      {showTable ? (
        <table className="data-table">
          <thead>
            <tr>
              {table.head.map((h) => (
                <th key={h}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {table.rows.map((r, i) => (
              <tr key={i}>
                {r.map((c, j) => (
                  <td key={j}>{c}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      ) : (
        children
      )}
      <button className="link" onClick={() => setShowTable((v) => !v)}>
        {showTable ? 'Voir le graphique' : 'Voir le tableau'}
      </button>
    </section>
  )
}

interface Tip {
  x: number
  y: number
  title: string
  rows: { color: string; name: string; value: string }[]
}

function Tooltip({ tip }: { tip: Tip | null }) {
  if (!tip) return null
  return (
    <div className="tooltip" style={{ left: tip.x, top: tip.y }}>
      <div className="t">{tip.title}</div>
      {tip.rows.map((r) => (
        <div className="r" key={r.name}>
          <span className="dot" style={{ background: r.color }} />
          {r.name} : {r.value}
        </div>
      ))}
    </div>
  )
}

// ---------- barres verticales groupées ----------

export function BarChart({
  categories,
  series,
  format,
  height = 180,
  tipTitle,
}: {
  categories: string[]
  series: Series[]
  format: (v: number) => string
  height?: number
  tipTitle?: (i: number) => string
}) {
  const [ref, width] = useWidth<HTMLDivElement>()
  const [hover, setHover] = useState<number | null>(null)
  const m = { t: 18, r: 4, b: 22, l: 40 }
  const iw = width - m.l - m.r
  const ih = height - m.t - m.b
  const max = Math.max(0, ...series.flatMap((s) => s.values))
  const ticks = niceTicks(max)
  const top = ticks[ticks.length - 1] || 1
  const y = (v: number) => m.t + ih - (v / top) * ih
  const band = iw / Math.max(1, categories.length)
  const groupW = Math.min(band * 0.72, 22 * series.length + 2 * (series.length - 1))
  const gap = 2
  const barW = (groupW - gap * (series.length - 1)) / series.length
  const last = categories.length - 1

  const tip: Tip | null =
    hover === null
      ? null
      : {
          x: m.l + band * hover + band / 2,
          y: y(Math.max(...series.map((s) => s.values[hover] ?? 0))),
          title: tipTitle ? tipTitle(hover) : categories[hover],
          rows: series.map((s) => ({ color: s.color, name: s.name, value: format(s.values[hover] ?? 0) })),
        }

  return (
    <div className="chart" ref={ref} onPointerLeave={() => setHover(null)}>
      <svg width={width} height={height} role="img" aria-label="Graphique en barres">
        <g className="grid">
          {ticks.map((t) => (
            <line key={t} x1={m.l} x2={width - m.r} y1={y(t)} y2={y(t)} />
          ))}
        </g>
        <g className="axis">
          {ticks.map((t) => (
            <text key={t} x={m.l - 6} y={y(t)} dy="0.32em" textAnchor="end">
              {format(t)}
            </text>
          ))}
          {categories.map((c, i) =>
            band >= 46 || i % 2 === last % 2 ? (
              <text key={i} x={m.l + band * i + band / 2} y={height - 6} textAnchor="middle">
                {c}
              </text>
            ) : null,
          )}
        </g>
        {categories.map((_, i) => {
          const x0 = m.l + band * i + (band - groupW) / 2
          return (
            <g key={i} opacity={hover === null || hover === i ? 1 : 0.55}>
              {series.map((s, j) => {
                const v = s.values[i] ?? 0
                return <path key={s.key} d={barPath(x0 + j * (barW + gap), y(v), barW, y(0) - y(v))} fill={s.color} />
              })}
            </g>
          )
        })}
        {/* étiquette directe : seulement la dernière période */}
        {series.map((s, j) => {
          const v = s.values[last] ?? 0
          if (!v || hover !== null) return null
          const x0 = m.l + band * last + (band - groupW) / 2 + j * (barW + gap) + barW / 2
          return (
            <text key={s.key} className="lbl" x={x0} y={y(v) - 5} textAnchor={j === series.length - 1 ? 'end' : 'middle'}>
              {format(v)}
            </text>
          )
        })}
        <line className="baseline" x1={m.l} x2={width - m.r} y1={y(0)} y2={y(0)} />
        {categories.map((_, i) => (
          <rect
            key={i}
            x={m.l + band * i}
            y={m.t}
            width={band}
            height={ih}
            fill="transparent"
            onPointerEnter={() => setHover(i)}
            onPointerDown={() => setHover(i)}
          />
        ))}
      </svg>
      <Tooltip tip={tip} />
    </div>
  )
}

// ---------- barres horizontales groupées ----------

export function HBarChart({
  categories,
  series,
  format,
}: {
  categories: string[]
  series: Series[]
  format: (v: number) => string
}) {
  const [ref, width] = useWidth<HTMLDivElement>()
  const [hover, setHover] = useState<number | null>(null)
  const barH = 12
  const gap = 2
  const rowH = series.length * barH + (series.length - 1) * gap + 16
  const labelW = 92
  const m = { t: 4, r: 36, b: 4, l: labelW }
  const height = m.t + m.b + rowH * categories.length
  const iw = width - m.l - m.r
  const max = Math.max(1, ...series.flatMap((s) => s.values))
  const x = (v: number) => (v / max) * iw

  const tip: Tip | null =
    hover === null
      ? null
      : {
          x: m.l + iw / 2,
          y: m.t + rowH * hover + 6,
          title: categories[hover],
          rows: series.map((s) => ({ color: s.color, name: s.name, value: format(s.values[hover] ?? 0) })),
        }

  return (
    <div className="chart" ref={ref} onPointerLeave={() => setHover(null)}>
      <svg width={width} height={height} role="img" aria-label="Graphique en barres horizontales">
        {categories.map((c, i) => {
          const y0 = m.t + rowH * i + 8
          return (
            <g key={c} opacity={hover === null || hover === i ? 1 : 0.55}>
              <text className="lbl" x={0} y={y0 + (rowH - 16) / 2} dy="0.32em">
                {c}
              </text>
              {series.map((s, j) => {
                const v = s.values[i] ?? 0
                const yy = y0 + j * (barH + gap)
                return (
                  <g key={s.key}>
                    <path d={hbarPath(m.l, yy, x(v), barH)} fill={s.color} />
                    <text className="lbl" x={m.l + x(v) + 6} y={yy + barH / 2} dy="0.32em">
                      {v ? format(v) : ''}
                    </text>
                  </g>
                )
              })}
              <rect
                x={0}
                y={m.t + rowH * i}
                width={width}
                height={rowH}
                fill="transparent"
                onPointerEnter={() => setHover(i)}
                onPointerDown={() => setHover(i)}
              />
            </g>
          )
        })}
        <line className="baseline" x1={m.l} x2={m.l} y1={m.t} y2={height - m.b} />
      </svg>
      <Tooltip tip={tip} />
    </div>
  )
}

// ---------- courbes dans le temps ----------

export interface LineSeries {
  key: string
  name: string
  color: string
  points: { date: string; value: number; detail?: string }[]
}

export function LineChart({
  series,
  format,
  height = 200,
}: {
  series: LineSeries[]
  format: (v: number) => string
  height?: number
}) {
  const [ref, width] = useWidth<HTMLDivElement>()
  const [hover, setHover] = useState<string | null>(null)
  const m = { t: 16, r: 44, b: 22, l: 40 }
  const iw = width - m.l - m.r
  const ih = height - m.t - m.b
  const all = series.flatMap((s) => s.points)
  if (!all.length) return <p className="empty">Pas encore de données.</p>

  const dates = [...new Set(all.map((p) => p.date))].sort()
  const t0 = parseDate(dates[0]).getTime()
  const t1 = parseDate(dates[dates.length - 1]).getTime()
  const span = Math.max(1, t1 - t0)
  const x = (d: string) => (dates.length === 1 ? m.l + iw / 2 : m.l + ((parseDate(d).getTime() - t0) / span) * iw)

  const vals = all.map((p) => p.value)
  const vmax = Math.max(...vals)
  const vmin = Math.min(...vals)
  // Axe qui ne part pas de 0 : on veut voir la progression, pas l'écraser.
  const pad = Math.max(1, (vmax - vmin) * 0.15)
  const lo = Math.max(0, Math.floor((vmin - pad) / 5) * 5)
  const hiRaw = vmax + pad
  const ticksRel = niceTicks(hiRaw - lo)
  const hi = lo + ticksRel[ticksRel.length - 1]
  const ticks = ticksRel.map((t) => lo + t)
  const y = (v: number) => m.t + ih - ((v - lo) / Math.max(1, hi - lo)) * ih

  const xTicks = dates.length <= 4 ? dates : [dates[0], dates[Math.floor(dates.length / 2)], dates[dates.length - 1]]

  const onMove = (clientX: number) => {
    const el = ref.current
    if (!el) return
    const px = clientX - el.getBoundingClientRect().left
    let best = dates[0]
    let bd = Infinity
    for (const d of dates) {
      const dd = Math.abs(x(d) - px)
      if (dd < bd) {
        bd = dd
        best = d
      }
    }
    setHover(best)
  }

  const tip: Tip | null = hover
    ? {
        x: Math.min(Math.max(x(hover), 70), width - 70),
        y: y(Math.max(...series.flatMap((s) => s.points.filter((p) => p.date === hover).map((p) => p.value)))),
        title: fmtDM(hover),
        rows: series.flatMap((s) =>
          s.points
            .filter((p) => p.date === hover)
            .map((p) => ({ color: s.color, name: s.name, value: p.detail ?? format(p.value) })),
        ),
      }
    : null

  return (
    <div
      className="chart"
      ref={ref}
      onPointerMove={(e) => onMove(e.clientX)}
      onPointerDown={(e) => onMove(e.clientX)}
      onPointerLeave={() => setHover(null)}
    >
      <svg width={width} height={height} role="img" aria-label="Courbe de progression">
        <g className="grid">
          {ticks.map((t) => (
            <line key={t} x1={m.l} x2={width - m.r} y1={y(t)} y2={y(t)} />
          ))}
        </g>
        <g className="axis">
          {ticks.map((t) => (
            <text key={t} x={m.l - 6} y={y(t)} dy="0.32em" textAnchor="end">
              {format(t)}
            </text>
          ))}
          {xTicks.map((d, i) => (
            <text
              key={d}
              x={x(d)}
              y={height - 6}
              textAnchor={xTicks.length > 1 && i === 0 ? 'start' : i === xTicks.length - 1 && xTicks.length > 1 ? 'end' : 'middle'}
            >
              {fmtDM(d)}
            </text>
          ))}
        </g>
        {hover ? <line x1={x(hover)} x2={x(hover)} y1={m.t} y2={m.t + ih} stroke="var(--text-3)" strokeDasharray="3 3" /> : null}
        {series.map((s) => {
          const pts = s.points
          if (!pts.length) return null
          const d = pts.map((p, i) => `${i ? 'L' : 'M'}${x(p.date)},${y(p.value)}`).join('')
          const lastP = pts[pts.length - 1]
          return (
            <g key={s.key}>
              <path d={d} fill="none" stroke={s.color} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
              {pts.map((p) => (
                <circle
                  key={p.date + p.value}
                  cx={x(p.date)}
                  cy={y(p.value)}
                  r={p.date === hover ? 5 : 4}
                  fill={s.color}
                  stroke="var(--glass-strong)"
                  strokeWidth={2}
                />
              ))}
              {!hover ? (
                <text className="lbl" x={x(lastP.date) + 8} y={y(lastP.value)} dy="0.32em">
                  {format(lastP.value)}
                </text>
              ) : null}
            </g>
          )
        })}
      </svg>
      <Tooltip tip={tip} />
    </div>
  )
}
