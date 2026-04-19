// Cards — deployable vector-shape units.
// role:
//   'shooter'     → travels up, stops at range, fires projectiles at enemies/walls
//   'melee'       → travels up, explodes on contact (AoE)
//   'wallbreak'   → ignores enemy units, targets walls + base
//   'interceptor' → targets oncoming enemy units only
//   'sniper'      → stays near spawn, long-range projectiles at base
//   'swarm'       → spawns 3 small units

const CARDS = [
  { id: 'dart',     name: 'Dart',     shape: 'triangle', role: 'shooter',     cost: 2, hp: 20, dmg: 6,  speed: 50, range: 140, fireRate: 0.6, size: 14, color: '#7dd3fc', desc: 'Shoots piercing bolts at enemies.' },
  { id: 'bomb',     name: 'Bomb',     shape: 'square',   role: 'melee',       cost: 4, hp: 50, dmg: 40, speed: 35, range: 18,  fireRate: 0,   size: 20, color: '#fb7185', desc: 'Walks up and detonates. AoE.' },
  { id: 'spiral',   name: 'Spiral',   shape: 'spiral',   role: 'wallbreak',   cost: 3, hp: 35, dmg: 18, speed: 30, range: 24,  fireRate: 0,   size: 18, color: '#c084fc', desc: 'Bores through walls. Ignores units.' },
  { id: 'burst',    name: 'Burst',    shape: 'star',     role: 'interceptor', cost: 3, hp: 25, dmg: 14, speed: 70, range: 40,  fireRate: 0,   size: 16, color: '#fbbf24', desc: 'Chases and rams enemies.' },
  { id: 'lance',    name: 'Lance',    shape: 'diamond',  role: 'sniper',      cost: 5, hp: 18, dmg: 28, speed: 0,  range: 380, fireRate: 1.4, size: 16, color: '#67e8f9', desc: 'Stationary. Long-range base shot.' },
  { id: 'orb',      name: 'Orb',      shape: 'circle',   role: 'shooter',     cost: 2, hp: 30, dmg: 4,  speed: 40, range: 90,  fireRate: 0.4, size: 14, color: '#86efac', desc: 'Cheap spam. Fast fire.' },
  { id: 'chevron',  name: 'Chevron',  shape: 'chevron',  role: 'swarm',       cost: 4, hp: 12, dmg: 5,  speed: 60, range: 70,  fireRate: 0.5, size: 16, color: '#f472b6', desc: 'Spawns 3 small scouts.' },
  { id: 'pulse',    name: 'Pulse',    shape: 'ring',     role: 'interceptor', cost: 5, hp: 45, dmg: 20, speed: 45, range: 50,  fireRate: 0,   size: 22, color: '#a78bfa', desc: 'Hunts enemies. Shockwave on kill.' },
];

function ShapeSVG({ shape, color, size = 20, rot = 0, glow = true }) {
  const s = size;
  const sw = Math.max(1.6, s * 0.12);
  const filter = glow ? `drop-shadow(0 0 ${s * 0.25}px ${color}) drop-shadow(0 0 ${s * 0.5}px ${color})` : 'none';
  const common = { stroke: color, strokeWidth: sw, fill: 'none', strokeLinejoin: 'round', strokeLinecap: 'round' };
  const wrap = (children) => (
    <svg width={s * 2.2} height={s * 2.2} viewBox={`${-s * 1.1} ${-s * 1.1} ${s * 2.2} ${s * 2.2}`}
      style={{ filter, transform: `rotate(${rot}deg)` }}>{children}</svg>
  );
  switch (shape) {
    case 'triangle': return wrap(<polygon points={`0,${-s} ${s * 0.9},${s * 0.7} ${-s * 0.9},${s * 0.7}`} {...common} />);
    case 'square':   return wrap(<rect x={-s * 0.8} y={-s * 0.8} width={s * 1.6} height={s * 1.6} rx={s * 0.1} {...common} />);
    case 'diamond':  return wrap(<polygon points={`0,${-s} ${s * 0.7},0 0,${s} ${-s * 0.7},0`} {...common} />);
    case 'circle':   return wrap(<circle cx={0} cy={0} r={s * 0.85} {...common} />);
    case 'ring':     return wrap(<>
      <circle cx={0} cy={0} r={s * 0.85} {...common} />
      <circle cx={0} cy={0} r={s * 0.45} {...common} strokeOpacity={0.6} />
    </>);
    case 'star': {
      const pts = [];
      for (let i = 0; i < 10; i++) {
        const r = i % 2 === 0 ? s : s * 0.45;
        const a = (i * Math.PI) / 5 - Math.PI / 2;
        pts.push(`${Math.cos(a) * r},${Math.sin(a) * r}`);
      }
      return wrap(<polygon points={pts.join(' ')} {...common} />);
    }
    case 'chevron': return wrap(<polyline points={`${-s * 0.8},${-s * 0.3} 0,${s * 0.5} ${s * 0.8},${-s * 0.3}`} {...common} />);
    case 'spiral': {
      const pts = [];
      for (let i = 0; i < 40; i++) {
        const a = i * 0.35;
        const r = (i / 40) * s;
        pts.push(`${Math.cos(a) * r},${Math.sin(a) * r}`);
      }
      return wrap(<polyline points={pts.join(' ')} {...common} />);
    }
    default: return wrap(<circle cx={0} cy={0} r={s * 0.8} {...common} />);
  }
}

// Role icon — tiny indicator on cards
const ROLE_ICON = {
  shooter:     '›› ',
  melee:       '◈ ',
  wallbreak:   '▞ ',
  interceptor: '◉ ',
  sniper:      '⟶ ',
  swarm:       '⋮⋮ ',
};
const ROLE_LABEL = {
  shooter:     'SHOOT',
  melee:       'MELEE',
  wallbreak:   'BREAK',
  interceptor: 'INTCP',
  sniper:      'SNIPE',
  swarm:       'SWARM',
};

Object.assign(window, { CARDS, ShapeSVG, ROLE_ICON, ROLE_LABEL });
