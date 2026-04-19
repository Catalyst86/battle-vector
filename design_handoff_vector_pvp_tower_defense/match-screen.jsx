// Match screen — unit-based PvP tower defense.
// Objective: destroy all enemy base squares in 3 min, or have more HP after overtime.
// Blue = player, Red = enemy. Player can place 3 walls at match start (and during match).

const { useState, useEffect, useRef, useCallback } = React;

const MAP_W = 360;
const MAP_H = 700;
const BASE_H = 60;
const MIDLINE = MAP_H / 2;

// Base grid: columns × rows of small squares
const BASE_COLS = 18;
const BASE_ROWS = 3;
const BASE_TOTAL = BASE_COLS * BASE_ROWS;

// Match config
const MATCH_SECONDS = 180;     // 3 min
const OVERTIME_SECONDS = 60;
const MAX_WALLS_PER_PLAYER = 3;
const WALL_W = 110;
const WALL_H = 8;

const DEFAULT_HAND = ['dart', 'bomb', 'spiral', 'lance', 'orb', 'chevron', 'burst', 'pulse'];

// Build initial base grid (array of squares)
function buildBase(side) {
  const y0 = side === 'enemy' ? 8 : MAP_H - BASE_H + 8;
  const cellW = (MAP_W - 20) / BASE_COLS;
  const cellH = (BASE_H - 16) / BASE_ROWS;
  const arr = [];
  for (let r = 0; r < BASE_ROWS; r++) {
    for (let c = 0; c < BASE_COLS; c++) {
      arr.push({
        id: `${side}-${r}-${c}`,
        x: 10 + c * cellW + 1,
        y: y0 + r * cellH + 1,
        w: cellW - 2, h: cellH - 2,
        alive: true, side,
      });
    }
  }
  return arr;
}

function useParticles(count = 60) {
  const ref = useRef(null);
  if (!ref.current || ref.current.length !== count) {
    ref.current = Array.from({ length: count }, () => ({
      x: Math.random() * MAP_W, y: Math.random() * MAP_H,
      r: Math.random() * 1.2 + 0.3,
      vy: Math.random() * 0.15 + 0.05, vx: (Math.random() - 0.5) * 0.05,
      op: Math.random() * 0.5 + 0.15,
    }));
  }
  return ref.current;
}

let unitIdSeq = 0;
let projIdSeq = 0;
let fxIdSeq = 0;
let wallIdSeq = 0;

function MatchScreen({ tweaks }) {
  const { particleDensity, glow, accent, aesthetic } = tweaks;

  // ───── State ─────
  const [phase, setPhase] = useState('build');  // 'build' | 'playing' | 'overtime' | 'over'
  const [units, setUnits] = useState([]);
  const [projectiles, setProjectiles] = useState([]);
  const [walls, setWalls] = useState([]);       // all placed walls
  const [fx, setFx] = useState([]);
  const [playerBase, setPlayerBase] = useState(() => buildBase('you'));
  const [enemyBase, setEnemyBase] = useState(() => buildBase('enemy'));
  const [selectedCard, setSelectedCard] = useState(null);
  const [wallMode, setWallMode] = useState(false);
  const [cardCooldowns, setCardCooldowns] = useState({});
  const [hand] = useState(DEFAULT_HAND);
  const [mana, setMana] = useState(6);
  const [enemyMana, setEnemyMana] = useState(6);
  const [timeLeft, setTimeLeft] = useState(MATCH_SECONDS);
  const [gameOver, setGameOver] = useState(null);  // 'win' | 'lose' | 'draw'
  const [, forceTick] = useState(0);

  const svgRef = useRef(null);
  const particles = useParticles(Math.floor(particleDensity));

  // Refs for loop
  const unitsRef = useRef(units);           unitsRef.current = units;
  const projRef = useRef(projectiles);      projRef.current = projectiles;
  const wallsRef = useRef(walls);           wallsRef.current = walls;
  const pBaseRef = useRef(playerBase);      pBaseRef.current = playerBase;
  const eBaseRef = useRef(enemyBase);       eBaseRef.current = enemyBase;
  const phaseRef = useRef(phase);           phaseRef.current = phase;

  const playerWallsCount = walls.filter(w => w.side === 'you').length;
  const enemyWallsCount = walls.filter(w => w.side === 'enemy').length;

  // ───── Enemy pre-match wall placement ─────
  useEffect(() => {
    if (phase !== 'build') return;
    const rows = [150, 220, 290];
    const wallsToAdd = [];
    for (let i = 0; i < MAX_WALLS_PER_PLAYER; i++) {
      wallsToAdd.push({
        id: `ew${++wallIdSeq}`,
        x: 40 + Math.random() * (MAP_W - WALL_W - 80),
        y: rows[i],
        w: WALL_W, h: WALL_H, side: 'enemy', hp: 80, maxHp: 80,
      });
    }
    setWalls(w => [...w, ...wallsToAdd]);
  }, []);

  const toGameCoords = useCallback((clientX, clientY) => {
    const svg = svgRef.current;
    if (!svg) return { x: 0, y: 0 };
    const rect = svg.getBoundingClientRect();
    return {
      x: ((clientX - rect.left) / rect.width) * MAP_W,
      y: ((clientY - rect.top) / rect.height) * MAP_H,
    };
  }, []);

  // ───── Start match ─────
  const startMatch = () => {
    setPhase('playing');
  };

  // ───── Spawn unit ─────
  const spawnUnit = useCallback((cardId, x, y, side) => {
    const card = CARDS.find(c => c.id === cardId);
    if (!card) return;
    const id = ++unitIdSeq;
    const mk = (over = {}) => ({
      id: over.id || ++unitIdSeq, cardId, side,
      x, y, hp: card.hp, maxHp: card.hp,
      role: card.role, speed: card.speed, range: card.range,
      dmg: card.dmg, fireRate: card.fireRate,
      size: card.size, color: card.color, shape: card.shape,
      fireCd: 0, age: 0, ...over,
    });
    if (card.role === 'swarm') {
      const outs = [];
      for (let i = 0; i < 3; i++) {
        outs.push(mk({
          id: ++unitIdSeq, role: 'shooter',
          hp: 12, maxHp: 12, dmg: 5, fireRate: 0.5, range: 70, speed: 60,
          size: 10, shape: 'chevron',
          x: x + (i - 1) * 20, y: y + (i % 2) * 10,
        }));
      }
      setUnits(u2 => [...u2, ...outs]);
      return;
    }
    setUnits(u2 => [...u2, { ...mk({ id }) }]);
  }, []);

  // ───── Player tap on map ─────
  const onMapPointerDown = (e) => {
    if (phase === 'over') return;
    const pt = toGameCoords(e.clientX, e.clientY);

    // Wall placement
    if (wallMode) {
      if (playerWallsCount >= MAX_WALLS_PER_PLAYER) return;
      // only on your half, between base and midline
      if (pt.y < MIDLINE + 20) return;
      if (pt.y > MAP_H - BASE_H - 20) return;
      const nx = Math.max(WALL_W / 2 + 4, Math.min(MAP_W - WALL_W / 2 - 4, pt.x));
      setWalls(w => [...w, {
        id: `pw${++wallIdSeq}`,
        x: nx - WALL_W / 2, y: pt.y - WALL_H / 2,
        w: WALL_W, h: WALL_H, side: 'you', hp: 80, maxHp: 80,
      }]);
      return;
    }

    // Unit deploy
    if (phase !== 'playing' && phase !== 'overtime') return;
    if (!selectedCard) return;
    if (pt.y < MIDLINE + 20) return;
    if (pt.y > MAP_H - BASE_H - 10) return;
    const card = CARDS.find(c => c.id === selectedCard);
    if (!card || mana < card.cost) return;
    spawnUnit(selectedCard, pt.x, pt.y, 'you');
    setMana(m => m - card.cost);
    setCardCooldowns(cd => ({ ...cd, [selectedCard]: performance.now() + 400 }));
    setSelectedCard(null);
  };

  // ───── Spawn projectile (called from loop) ─────
  const spawnProjectileInArr = (arr, fromU, targetPos, dmg) => {
    const dx = targetPos.x - fromU.x;
    const dy = targetPos.y - fromU.y;
    const len = Math.hypot(dx, dy) || 1;
    const speed = 260;
    arr.push({
      id: ++projIdSeq, side: fromU.side,
      x: fromU.x, y: fromU.y,
      vx: (dx / len) * speed, vy: (dy / len) * speed,
      dmg, color: fromU.color, life: 0, trail: [],
    });
  };

  // ───── Game loop ─────
  useEffect(() => {
    if (phase !== 'playing' && phase !== 'overtime') return;
    let raf;
    let last = performance.now();
    const step = (now) => {
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;

      let us = unitsRef.current.map(u => ({ ...u }));
      let ws = wallsRef.current.map(w => ({ ...w }));
      let ps = projRef.current.map(p => ({ ...p }));
      let pBase = pBaseRef.current.map(b => ({ ...b }));
      let eBase = eBaseRef.current.map(b => ({ ...b }));
      const newFx = [];

      // helpers
      const hitBase = (side, x, y, dmg) => {
        const arr = side === 'enemy' ? eBase : pBase;
        // find alive square nearest to (x,y)
        let best = null, bestD = Infinity;
        for (const sq of arr) {
          if (!sq.alive) continue;
          const cx = sq.x + sq.w / 2, cy = sq.y + sq.h / 2;
          const d = Math.hypot(cx - x, cy - y);
          if (d < bestD) { bestD = d; best = sq; }
        }
        if (best && bestD < 40) {
          // kill up to ~dmg squares (1 per 20 dmg)
          const n = Math.max(1, Math.round(dmg / 18));
          const sorted = arr.filter(s => s.alive).sort((a, b2) => {
            const da = Math.hypot(a.x - x, a.y - y);
            const db = Math.hypot(b2.x - x, b2.y - y);
            return da - db;
          });
          for (let i = 0; i < Math.min(n, sorted.length); i++) sorted[i].alive = false;
          newFx.push({ id: ++fxIdSeq, x, y: best.y + best.h / 2, color: side === 'enemy' ? '#fb7185' : '#67e8f9', t: now, r: 18, kind: 'big' });
          return true;
        }
        return false;
      };

      // ─── Unit AI ───
      for (const u of us) {
        if (u.hp <= 0) continue;
        u.age += dt;
        u.fireCd = Math.max(0, u.fireCd - dt);

        const enemies = us.filter(v => v.side !== u.side && v.hp > 0);
        const baseArr = u.side === 'you' ? eBase : pBase;
        const aliveBaseSq = baseArr.filter(s => s.alive);

        // Determine target
        let target = null, targetKind = null;

        if (u.role === 'wallbreak') {
          const tw = ws.filter(w => w.side !== u.side && w.hp > 0);
          let best = null, bestD = Infinity;
          for (const w of tw) {
            const cx = w.x + w.w / 2, cy = w.y + w.h / 2;
            const d = Math.hypot(cx - u.x, cy - u.y);
            if (d < bestD) { bestD = d; best = w; }
          }
          if (best) target = { x: best.x + best.w / 2, y: best.y + best.h / 2, wall: best, kind: 'wall' };
          else if (aliveBaseSq.length) {
            const t = aliveBaseSq[0];
            target = { x: t.x + t.w / 2, y: t.y + t.h / 2, kind: 'base' };
          }
        } else if (u.role === 'interceptor') {
          let best = null, bestD = Infinity;
          for (const e of enemies) {
            const d = Math.hypot(e.x - u.x, e.y - u.y);
            if (d < bestD) { bestD = d; best = e; }
          }
          if (best) target = { x: best.x, y: best.y, unit: best, kind: 'unit' };
          else if (aliveBaseSq.length) {
            const t = aliveBaseSq[0];
            target = { x: t.x + t.w / 2, y: t.y + t.h / 2, kind: 'base' };
          }
        } else if (u.role === 'sniper') {
          if (aliveBaseSq.length) {
            const t = aliveBaseSq[Math.floor(aliveBaseSq.length / 2)];
            target = { x: t.x + t.w / 2, y: t.y + t.h / 2, kind: 'base' };
          }
        } else {
          let best = null, bestD = Infinity;
          for (const e of enemies) {
            const d = Math.hypot(e.x - u.x, e.y - u.y);
            if (d < bestD) { bestD = d; best = e; }
          }
          if (best && bestD < u.range + 40) target = { x: best.x, y: best.y, unit: best, kind: 'unit' };
          else if (aliveBaseSq.length) {
            const t = aliveBaseSq[Math.floor(Math.random() * aliveBaseSq.length)];
            target = { x: t.x + t.w / 2, y: t.y + t.h / 2, kind: 'base' };
          }
        }
        if (!target) continue;
        const dx = target.x - u.x, dy = target.y - u.y;
        const dist = Math.hypot(dx, dy) || 1;

        if (u.role === 'sniper') {
          if (u.fireCd === 0) { spawnProjectileInArr(ps, u, target, u.dmg); u.fireCd = u.fireRate; }
        } else if (u.role === 'melee' || u.role === 'wallbreak' || u.role === 'interceptor') {
          if (dist > u.range) {
            const nx = u.x + (dx / dist) * u.speed * dt;
            const ny = u.y + (dy / dist) * u.speed * dt;
            if (u.role !== 'wallbreak') {
              const blocked = ws.find(w => w.side !== u.side && w.hp > 0 &&
                nx > w.x - u.size * 0.4 && nx < w.x + w.w + u.size * 0.4 &&
                ny > w.y - u.size * 0.4 && ny < w.y + w.h + u.size * 0.4);
              if (blocked) {
                blocked.hp -= u.dmg * dt * 2;
                newFx.push({ id: ++fxIdSeq, x: nx, y: ny, color: u.color, t: now, r: u.size, kind: 'small' });
              } else { u.x = nx; u.y = ny; }
            } else { u.x = nx; u.y = ny; }
          } else {
            if (target.kind === 'unit' && target.unit) {
              const tu = us.find(z => z.id === target.unit.id);
              if (tu) {
                tu.hp -= u.dmg;
                newFx.push({ id: ++fxIdSeq, x: tu.x, y: tu.y, color: u.color, t: now, r: u.size * 1.4, kind: 'small' });
                if (u.role === 'melee') {
                  u.hp = 0;
                  newFx.push({ id: ++fxIdSeq, x: u.x, y: u.y, color: u.color, t: now, r: u.size * 2.5, kind: 'big' });
                  for (const e of enemies) {
                    if (Math.hypot(e.x - u.x, e.y - u.y) < 40) {
                      const tuu = us.find(z => z.id === e.id);
                      if (tuu) tuu.hp -= u.dmg * 0.6;
                    }
                  }
                }
              }
            } else if (target.kind === 'wall' && target.wall) {
              const tw = ws.find(z => z.id === target.wall.id);
              if (tw) { tw.hp -= u.dmg * dt * 3; newFx.push({ id: ++fxIdSeq, x: u.x, y: u.y, color: u.color, t: now, r: u.size, kind: 'small' }); }
            } else if (target.kind === 'base') {
              hitBase(u.side === 'you' ? 'enemy' : 'you', u.x, u.side === 'you' ? BASE_H : MAP_H - BASE_H, u.dmg);
              u.hp = 0;
            }
          }
        } else {
          if (dist > u.range) {
            const nx = u.x + (dx / dist) * u.speed * dt;
            const ny = u.y + (dy / dist) * u.speed * dt;
            const blocked = ws.find(w => w.side !== u.side && w.hp > 0 &&
              nx > w.x - u.size * 0.4 && nx < w.x + w.w + u.size * 0.4 &&
              ny > w.y - u.size * 0.4 && ny < w.y + w.h + u.size * 0.4);
            if (blocked) blocked.hp -= u.dmg * dt * 2;
            else { u.x = nx; u.y = ny; }
          }
          if (u.fireCd === 0) { spawnProjectileInArr(ps, u, target, u.dmg); u.fireCd = u.fireRate; }
        }
      }

      // ─── Projectiles ───
      const aliveProjs = [];
      for (const p of ps) {
        let { x, y, vx, vy, life } = p;
        x += vx * dt; y += vy * dt; life += dt;
        const trail = [...p.trail, { x, y }].slice(-6);
        if (x < -20 || x > MAP_W + 20 || y < -20 || y > MAP_H + 20) continue;

        const hitWall = ws.find(w => w.hp > 0 && x > w.x && x < w.x + w.w && y > w.y - 3 && y < w.y + w.h + 3);
        if (hitWall) {
          hitWall.hp -= p.dmg;
          newFx.push({ id: ++fxIdSeq, x, y, color: p.color, t: now, r: 10, kind: 'small' });
          continue;
        }
        const hitUnit = us.find(u => u.hp > 0 && u.side !== p.side && Math.hypot(u.x - x, u.y - y) < u.size * 0.8);
        if (hitUnit) {
          hitUnit.hp -= p.dmg;
          newFx.push({ id: ++fxIdSeq, x, y, color: p.color, t: now, r: 12, kind: 'small' });
          continue;
        }
        // base hits
        if (p.side === 'you' && y < BASE_H) {
          hitBase('enemy', x, y, p.dmg);
          continue;
        }
        if (p.side === 'enemy' && y > MAP_H - BASE_H) {
          hitBase('you', x, y, p.dmg);
          continue;
        }
        aliveProjs.push({ ...p, x, y, life, trail });
      }

      // ─── Cleanup ───
      ws = ws.filter(w => w.hp > 0);
      for (const u of us) {
        if (u.hp <= 0 && u.shape === 'ring' && !u._shockDone) {
          u._shockDone = true;
          newFx.push({ id: ++fxIdSeq, x: u.x, y: u.y, color: u.color, t: now, r: 40, kind: 'big' });
          const en = us.filter(v => v.side !== u.side && v.hp > 0);
          for (const e of en) if (Math.hypot(e.x - u.x, e.y - u.y) < 60) e.hp -= 10;
        }
      }
      us = us.filter(u => u.hp > 0);

      unitsRef.current = us; projRef.current = aliveProjs; wallsRef.current = ws;
      pBaseRef.current = pBase; eBaseRef.current = eBase;
      setUnits(us); setProjectiles(aliveProjs); setWalls(ws);
      setPlayerBase(pBase); setEnemyBase(eBase);
      if (newFx.length) setFx(f => [...f, ...newFx].slice(-80));

      raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [phase]);

  // ───── Mana regen ─────
  useEffect(() => {
    if (phase !== 'playing' && phase !== 'overtime') return;
    const iv = setInterval(() => {
      setMana(m => Math.min(10, m + 1));
      setEnemyMana(m => Math.min(10, m + 1));
    }, 1000);
    return () => clearInterval(iv);
  }, [phase]);

  // ───── Enemy AI ─────
  useEffect(() => {
    if (phase !== 'playing' && phase !== 'overtime') return;
    const iv = setInterval(() => {
      const affordable = CARDS.filter(c => c.cost <= enemyMana);
      if (!affordable.length) return;
      const card = affordable[Math.floor(Math.random() * affordable.length)];
      const x = 60 + Math.random() * (MAP_W - 120);
      const y = BASE_H + 20 + Math.random() * (MIDLINE - BASE_H - 40);
      spawnUnit(card.id, x, y, 'enemy');
      setEnemyMana(m => m - card.cost);
    }, 2000);
    return () => clearInterval(iv);
  }, [enemyMana, phase, spawnUnit]);

  // ───── Clean FX ─────
  useEffect(() => {
    const iv = setInterval(() => {
      const now = performance.now();
      setFx(f => f.filter(e => now - e.t < 600));
    }, 200);
    return () => clearInterval(iv);
  }, []);

  // ───── Match timer ─────
  useEffect(() => {
    if (phase !== 'playing' && phase !== 'overtime') return;
    const iv = setInterval(() => {
      setTimeLeft(t => {
        if (t > 0) return t - 1;
        // time's up
        if (phase === 'playing') {
          // Check if anyone already won
          setPhase('overtime');
          return OVERTIME_SECONDS;
        } else {
          // overtime ended — HP tiebreak
          const pAlive = pBaseRef.current.filter(s => s.alive).length;
          const eAlive = eBaseRef.current.filter(s => s.alive).length;
          if (pAlive > eAlive) setGameOver('win');
          else if (eAlive > pAlive) setGameOver('lose');
          else setGameOver('draw');
          setPhase('over');
          return 0;
        }
      });
    }, 1000);
    return () => clearInterval(iv);
  }, [phase]);

  // ───── Base destruction win/loss ─────
  useEffect(() => {
    if (phase === 'over' || phase === 'build') return;
    const pAlive = playerBase.some(s => s.alive);
    const eAlive = enemyBase.some(s => s.alive);
    if (!pAlive) { setGameOver('lose'); setPhase('over'); }
    else if (!eAlive) { setGameOver('win'); setPhase('over'); }
  }, [playerBase, enemyBase, phase]);

  // ───── Particle drift ─────
  useEffect(() => {
    const iv = setInterval(() => {
      for (const p of particles) {
        p.x += p.vx; p.y += p.vy;
        if (p.y > MAP_H) { p.y = 0; p.x = Math.random() * MAP_W; }
        if (p.x < 0) p.x = MAP_W; if (p.x > MAP_W) p.x = 0;
      }
      forceTick(t => t + 1);
    }, 50);
    return () => clearInterval(iv);
  }, [particles]);

  const reset = () => {
    unitIdSeq = 0; projIdSeq = 0; fxIdSeq = 0; wallIdSeq = 0;
    unitsRef.current = []; projRef.current = []; wallsRef.current = [];
    setUnits([]); setProjectiles([]); setFx([]); setWalls([]);
    setPlayerBase(buildBase('you')); setEnemyBase(buildBase('enemy'));
    setMana(6); setEnemyMana(6); setSelectedCard(null); setCardCooldowns({});
    setTimeLeft(MATCH_SECONDS); setGameOver(null); setWallMode(false);
    setPhase('build');
    // add enemy walls
    const rows = [150, 220, 290];
    const wa = [];
    for (let i = 0; i < MAX_WALLS_PER_PLAYER; i++) {
      wa.push({
        id: `ew${++wallIdSeq}`,
        x: 40 + Math.random() * (MAP_W - WALL_W - 80),
        y: rows[i],
        w: WALL_W, h: WALL_H, side: 'enemy', hp: 80, maxHp: 80,
      });
    }
    setWalls(wa);
  };

  const palette = getPalette(aesthetic, accent);
  const nowMs = performance.now();

  const timeMin = Math.floor(timeLeft / 60);
  const timeSec = (timeLeft % 60).toString().padStart(2, '0');

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%',
      background: palette.bg, overflow: 'hidden',
      fontFamily: 'ui-monospace, "SF Mono", Menlo, monospace',
    }}>
      <svg
        ref={svgRef}
        viewBox={`0 0 ${MAP_W} ${MAP_H}`}
        style={{
          position: 'absolute', inset: 0, width: '100%', height: '100%',
          touchAction: 'none',
          cursor: (wallMode && playerWallsCount < MAX_WALLS_PER_PLAYER) ? 'crosshair' : (selectedCard ? 'copy' : 'default'),
        }}
        onPointerDown={onMapPointerDown}
      >
        <defs>
          <pattern id="grid" width="24" height="24" patternUnits="userSpaceOnUse">
            <path d="M 24 0 L 0 0 0 24" fill="none" stroke={palette.grid} strokeWidth="0.5" />
          </pattern>
          <radialGradient id="vignette" cx="50%" cy="50%" r="70%">
            <stop offset="60%" stopColor="transparent" />
            <stop offset="100%" stopColor={palette.bg} />
          </radialGradient>
        </defs>

        <rect x="0" y="0" width={MAP_W} height={MAP_H} fill="url(#grid)" opacity="0.4" />
        <rect x="0" y="0" width={MAP_W} height={MAP_H} fill="url(#vignette)" />

        {/* Deploy / wall zone highlight */}
        {(selectedCard || wallMode) && (
          <rect x="0" y={MIDLINE + 20} width={MAP_W} height={MAP_H - BASE_H - MIDLINE - 30}
            fill={wallMode ? palette.wallAccent : palette.wallYou} opacity="0.04"
            stroke={wallMode ? palette.wallAccent : palette.wallYou} strokeWidth="0.8" strokeDasharray="4 4" />
        )}

        {/* Midline */}
        <line x1="0" y1={MIDLINE} x2={MAP_W} y2={MIDLINE}
          stroke={palette.divider} strokeWidth="0.5" strokeDasharray="2 6" />

        {/* Particles */}
        {particles.map((p, i) => (
          <circle key={i} cx={p.x} cy={p.y} r={p.r} fill={palette.particle} opacity={p.op} />
        ))}

        {/* Bases: grids of small squares */}
        <BaseGrid squares={enemyBase} color={palette.wallEnemy} glow={glow} />
        <BaseGrid squares={playerBase} color={palette.wallYou} glow={glow} />

        {/* Walls */}
        {walls.map(w => (
          <g key={w.id}>
            <rect x={w.x} y={w.y} width={w.w} height={w.h} rx="2"
              fill={w.side === 'you' ? palette.wallYou : palette.wallEnemy}
              opacity={0.15 + 0.5 * (w.hp / w.maxHp)} />
            <rect x={w.x} y={w.y} width={w.w} height={w.h} rx="2"
              fill="none"
              stroke={w.side === 'you' ? palette.wallYou : palette.wallEnemy}
              strokeWidth="1.2"
              style={{ filter: `drop-shadow(0 0 ${glow * 2}px ${w.side === 'you' ? palette.wallYou : palette.wallEnemy})` }}
            />
          </g>
        ))}

        {/* Units */}
        {units.map(u => <UnitSVG key={u.id} u={u} glow={glow} />)}

        {/* Projectiles */}
        {projectiles.map(p => (
          <g key={p.id}>
            {p.trail.map((t, i) => (
              <circle key={i} cx={t.x} cy={t.y} r={1.5 * (i / p.trail.length)}
                fill={p.color} opacity={i / p.trail.length * 0.7} />
            ))}
            <circle cx={p.x} cy={p.y} r="2.5" fill={p.color}
              style={{ filter: `drop-shadow(0 0 ${glow * 2}px ${p.color})` }} />
          </g>
        ))}

        {/* FX */}
        {fx.map(e => {
          const age = Math.min(1, (nowMs - e.t) / 500);
          const r = e.r * (1 + age * 1.5);
          return (
            <g key={e.id}>
              <circle cx={e.x} cy={e.y} r={r} fill="none"
                stroke={e.color} strokeWidth={2 * (1 - age)} opacity={1 - age}
                style={{ filter: `drop-shadow(0 0 ${glow * 3}px ${e.color})` }} />
              <circle cx={e.x} cy={e.y} r={r * 0.4} fill={e.color} opacity={(1 - age) * 0.3} />
            </g>
          );
        })}
      </svg>

      {/* Top HUD: Enemy + Timer */}
      <div style={{
        position: 'absolute', top: 60, left: 12, right: 12,
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        color: palette.text, fontSize: 11, letterSpacing: 1.5, pointerEvents: 'none',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{
            width: 28, height: 28, borderRadius: 6,
            border: `1.5px solid ${palette.wallEnemy}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            background: 'rgba(0,0,0,0.4)', fontSize: 13, color: palette.wallEnemy,
          }}>◣</div>
          <div>
            <div style={{ fontSize: 9, opacity: 0.6 }}>ENEMY</div>
            <div style={{ fontSize: 12, fontWeight: 600 }}>K.VOID_07</div>
          </div>
        </div>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 8, opacity: 0.5, letterSpacing: 3 }}>
            {phase === 'overtime' ? 'OVERTIME' : phase === 'build' ? 'SETUP' : 'MATCH'}
          </div>
          <div style={{
            fontSize: 18, fontWeight: 700, letterSpacing: 2,
            color: phase === 'overtime' ? palette.wallEnemy : palette.text,
            textShadow: phase === 'overtime' ? `0 0 10px ${palette.wallEnemy}` : 'none',
          }}>
            {phase === 'build' ? '—:—' : `${timeMin}:${timeSec}`}
          </div>
        </div>
        <div style={{ fontSize: 10, opacity: 0.7, textAlign: 'right' }}>
          ⚡ {enemyMana.toFixed(0)}/10
          <div style={{ fontSize: 8, opacity: 0.6, marginTop: 2 }}>
            SQUARES {enemyBase.filter(s => s.alive).length}/{BASE_TOTAL}
          </div>
        </div>
      </div>

      {/* Mid: Player HUD above cards */}
      <div style={{
        position: 'absolute', bottom: 178, left: 12, right: 12,
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        color: palette.text, fontSize: 11, letterSpacing: 1.5, pointerEvents: 'none',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{
            width: 28, height: 28, borderRadius: 6,
            border: `1.5px solid ${palette.wallYou}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            background: 'rgba(0,0,0,0.4)', fontSize: 13, color: palette.wallYou,
          }}>◢</div>
          <div>
            <div style={{ fontSize: 9, opacity: 0.6 }}>YOU</div>
            <div style={{ fontSize: 12, fontWeight: 600 }}>VEC.BLUE</div>
          </div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 8, opacity: 0.6, marginBottom: 2 }}>
            SQUARES {playerBase.filter(s => s.alive).length}/{BASE_TOTAL}
          </div>
          <ManaBar mana={mana} palette={palette} />
        </div>
      </div>

      {/* Wall mode toggle button (bottom-left) */}
      <button
        onPointerDown={e => { e.stopPropagation(); setWallMode(m => !m); setSelectedCard(null); }}
        style={{
          position: 'absolute', left: 12, bottom: 134,
          width: 48, height: 32, borderRadius: 8,
          background: wallMode ? `${palette.wallAccent}22` : 'rgba(12,14,18,0.8)',
          border: `1px solid ${wallMode ? palette.wallAccent : palette.cardBorder}`,
          color: wallMode ? palette.wallAccent : palette.text,
          fontFamily: 'inherit', fontSize: 9, letterSpacing: 1.5, cursor: 'pointer',
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
          gap: 2, pointerEvents: 'auto',
        }}
      >
        <div style={{ fontSize: 13, lineHeight: 1 }}>▭</div>
        <div>WALL {playerWallsCount}/{MAX_WALLS_PER_PLAYER}</div>
      </button>

      {/* Start button (build phase) */}
      {phase === 'build' && (
        <button
          onPointerDown={e => { e.stopPropagation(); startMatch(); }}
          style={{
            position: 'absolute', right: 12, bottom: 134,
            padding: '8px 14px', borderRadius: 8,
            background: `${palette.wallYou}22`,
            border: `1px solid ${palette.wallYou}`,
            color: palette.wallYou,
            fontFamily: 'inherit', fontSize: 10, letterSpacing: 2, cursor: 'pointer',
            pointerEvents: 'auto',
          }}
        >
          ▸ START MATCH
        </button>
      )}

      {/* Card hand */}
      <div style={{
        position: 'absolute', bottom: 18, left: 0, right: 0,
        display: 'flex', justifyContent: 'center', gap: 6, padding: '0 10px',
        pointerEvents: (phase === 'over' || phase === 'build') ? 'none' : 'auto',
        opacity: phase === 'build' ? 0.4 : 1,
      }}>
        {hand.map((cid, i) => {
          const card = CARDS.find(c => c.id === cid);
          const onCd = (cardCooldowns[cid] ?? 0) > nowMs;
          const affordable = mana >= card.cost;
          const isSel = selectedCard === cid;
          const disabled = onCd || !affordable || wallMode || phase === 'build';
          return (
            <button key={i}
              onPointerDown={e => {
                e.stopPropagation();
                if (!disabled) { setSelectedCard(isSel ? null : cid); setWallMode(false); }
              }}
              style={{
                flex: '1 1 0', minWidth: 0, maxWidth: 72, height: 108,
                borderRadius: 10,
                background: isSel ? `${card.color}22` : 'rgba(12,14,18,0.75)',
                border: `1px solid ${isSel ? card.color : palette.cardBorder}`,
                color: palette.text, padding: '6px 4px',
                display: 'flex', flexDirection: 'column',
                alignItems: 'center', justifyContent: 'space-between',
                cursor: disabled ? 'not-allowed' : 'pointer',
                opacity: disabled ? 0.45 : 1,
                backdropFilter: 'blur(8px)',
                transform: isSel ? 'translateY(-8px)' : 'none',
                transition: 'transform 120ms, background 120ms, border-color 120ms',
                boxShadow: isSel ? `0 0 0 2px ${card.color}44, 0 -4px 20px ${card.color}55` : 'none',
                fontFamily: 'inherit',
              }}
            >
              <div style={{
                fontSize: 7, letterSpacing: 1, opacity: 0.65,
                alignSelf: 'flex-start', paddingLeft: 2, color: card.color,
              }}>{ROLE_LABEL[card.role]}</div>
              <div style={{ flex: 1, display: 'flex', alignItems: 'center' }}>
                <ShapeSVG shape={card.shape} color={card.color} size={16} glow={true} />
              </div>
              <div style={{
                fontSize: 9, letterSpacing: 0.5, fontWeight: 600,
                textTransform: 'uppercase',
              }}>{card.name}</div>
              <div style={{
                marginTop: 2, display: 'flex', alignItems: 'center', gap: 3,
                fontSize: 9, color: affordable ? palette.mana : '#f87171',
              }}>
                <span style={{
                  width: 8, height: 8, borderRadius: '50%',
                  background: affordable ? palette.mana : '#f87171',
                }} />
                <span>{card.cost}</span>
              </div>
            </button>
          );
        })}
      </div>

      {/* Hints */}
      {phase === 'build' && !wallMode && (
        <div style={{
          position: 'absolute', top: '46%', left: 0, right: 0,
          textAlign: 'center', color: palette.text, fontSize: 10,
          letterSpacing: 3, opacity: 0.7, pointerEvents: 'none',
        }}>
          ▭ PLACE UP TO 3 WALLS, THEN START
        </div>
      )}
      {wallMode && phase !== 'over' && (
        <div style={{
          position: 'absolute', top: '52%', left: 0, right: 0,
          textAlign: 'center', color: palette.wallAccent, fontSize: 10,
          letterSpacing: 2, opacity: 0.85, pointerEvents: 'none',
        }}>
          ▭ TAP YOUR SIDE TO PLACE WALL ({playerWallsCount}/{MAX_WALLS_PER_PLAYER})
        </div>
      )}
      {selectedCard && !wallMode && (
        <div style={{
          position: 'absolute', top: '52%', left: 0, right: 0,
          textAlign: 'center', color: palette.text, fontSize: 10,
          letterSpacing: 2, opacity: 0.7, pointerEvents: 'none',
        }}>
          ▼ TAP YOUR SIDE TO DEPLOY ▼
        </div>
      )}

      {/* Game over */}
      {phase === 'over' && (
        <div style={{
          position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.82)',
          display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center', gap: 20,
          backdropFilter: 'blur(4px)',
        }}>
          <div style={{ fontSize: 10, letterSpacing: 4, opacity: 0.5, color: palette.text }}>
            MATCH ENDED
          </div>
          <div style={{
            fontSize: 44, fontWeight: 700, letterSpacing: 2,
            color: gameOver === 'win' ? palette.wallYou : gameOver === 'lose' ? palette.wallEnemy : palette.text,
            textShadow: `0 0 30px ${gameOver === 'win' ? palette.wallYou : gameOver === 'lose' ? palette.wallEnemy : palette.text}`,
          }}>
            {gameOver === 'win' ? 'VICTORY' : gameOver === 'lose' ? 'DEFEAT' : 'DRAW'}
          </div>
          <div style={{ fontSize: 10, letterSpacing: 2, opacity: 0.6, color: palette.text }}>
            {playerBase.filter(s => s.alive).length} vs {enemyBase.filter(s => s.alive).length} SQUARES
          </div>
          <button onClick={reset} style={{
            padding: '10px 24px', borderRadius: 24,
            background: 'transparent', color: palette.text,
            border: `1px solid ${palette.text}`,
            fontSize: 11, letterSpacing: 2, cursor: 'pointer',
            fontFamily: 'inherit',
          }}>
            ▸ REMATCH
          </button>
        </div>
      )}
    </div>
  );
}

// ───── Base grid ─────
function BaseGrid({ squares, color, glow }) {
  return (
    <g style={{ filter: `drop-shadow(0 0 ${glow}px ${color})` }}>
      {squares.map(sq => (
        <rect key={sq.id}
          x={sq.x} y={sq.y} width={sq.w} height={sq.h} rx="0.8"
          fill={sq.alive ? color : 'transparent'}
          stroke={color}
          strokeWidth="0.5"
          opacity={sq.alive ? 0.85 : 0.15}
        />
      ))}
    </g>
  );
}

function UnitSVG({ u, glow }) {
  const hpPct = u.hp / u.maxHp;
  const rot = (u.age * 120) % 360;
  const s = u.size * 0.4;
  const sw = Math.max(1.5, s * 0.25);
  const props = { stroke: u.color, strokeWidth: sw, fill: 'none', strokeLinejoin: 'round' };
  const shape = (() => {
    switch (u.shape) {
      case 'triangle': return <polygon points={`0,${-s} ${s * 0.9},${s * 0.7} ${-s * 0.9},${s * 0.7}`} {...props} />;
      case 'square':   return <rect x={-s * 0.8} y={-s * 0.8} width={s * 1.6} height={s * 1.6} rx={s * 0.1} {...props} />;
      case 'diamond':  return <polygon points={`0,${-s} ${s * 0.7},0 0,${s} ${-s * 0.7},0`} {...props} />;
      case 'circle':   return <circle r={s * 0.85} {...props} />;
      case 'ring':     return <><circle r={s * 0.85} {...props} /><circle r={s * 0.45} {...props} strokeOpacity={0.5} /></>;
      case 'star': {
        const pts = [];
        for (let i = 0; i < 10; i++) {
          const r = i % 2 === 0 ? s : s * 0.45;
          const a = (i * Math.PI) / 5 - Math.PI / 2;
          pts.push(`${Math.cos(a) * r},${Math.sin(a) * r}`);
        }
        return <polygon points={pts.join(' ')} {...props} />;
      }
      case 'chevron': return <polyline points={`${-s * 0.8},${-s * 0.3} 0,${s * 0.5} ${s * 0.8},${-s * 0.3}`} {...props} />;
      case 'spiral': {
        const pts = [];
        for (let i = 0; i < 28; i++) {
          const a = i * 0.4 + u.age * 2;
          const r = (i / 28) * s;
          pts.push(`${Math.cos(a) * r},${Math.sin(a) * r}`);
        }
        return <polyline points={pts.join(' ')} {...props} />;
      }
      default: return <circle r={s * 0.8} {...props} />;
    }
  })();
  const rotated = ['triangle', 'diamond', 'star', 'chevron'].includes(u.shape);
  return (
    <g style={{ filter: `drop-shadow(0 0 ${glow * 2}px ${u.color})` }}>
      <circle cx={u.x} cy={u.y} r={u.size * 0.75}
        fill="none" stroke={u.color} strokeWidth="0.4" opacity="0.25" />
      <g transform={`translate(${u.x} ${u.y})${rotated ? ` rotate(${rot})` : ''}`}>{shape}</g>
      {hpPct < 1 && (
        <g>
          <rect x={u.x - 10} y={u.y + u.size * 0.9 + 2} width="20" height="2.2" rx="1" fill="rgba(0,0,0,0.5)" />
          <rect x={u.x - 10} y={u.y + u.size * 0.9 + 2} width={20 * hpPct} height="2.2" rx="1" fill={u.color} />
        </g>
      )}
    </g>
  );
}

function ManaBar({ mana, palette }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 4, justifyContent: 'flex-end' }}>
      <span style={{ fontSize: 9, opacity: 0.6, marginRight: 4 }}>⚡ {mana.toFixed(0)}</span>
      <div style={{ display: 'flex', gap: 2 }}>
        {Array.from({ length: 10 }, (_, i) => (
          <div key={i} style={{
            width: 5, height: 10, borderRadius: 1,
            background: i < mana ? palette.mana : 'transparent',
            border: `1px solid ${palette.mana}`,
            opacity: i < mana ? 1 : 0.3,
            boxShadow: i < mana ? `0 0 4px ${palette.mana}` : 'none',
          }} />
        ))}
      </div>
    </div>
  );
}

function getPalette(aesthetic, accent) {
  const base = {
    clean: {
      bg: '#06080b', grid: '#ffffff', divider: '#ffffff33',
      particle: '#ffffff', text: '#e5e7eb',
      wallYou: '#67e8f9', wallEnemy: '#fb7185',
      wallAccent: '#86efac',
      mana: '#fbbf24', accent: accent || '#67e8f9',
      cardBorder: 'rgba(255,255,255,0.12)',
    },
    neon: {
      bg: '#0a0014', grid: '#ff00ff', divider: '#ff00ff66',
      particle: '#ff66ff', text: '#f0e6ff',
      wallYou: '#00ffea', wallEnemy: '#ff2d95',
      wallAccent: '#ffff00',
      mana: '#ffdd00', accent: accent || '#00ffea',
      cardBorder: 'rgba(255,0,255,0.25)',
    },
    mono: {
      bg: '#000000', grid: '#ffffff', divider: '#ffffff44',
      particle: '#ffffff', text: '#ffffff',
      wallYou: '#ffffff', wallEnemy: '#ff3030',
      wallAccent: '#cccccc',
      mana: '#ffffff', accent: accent || '#ffffff',
      cardBorder: 'rgba(255,255,255,0.2)',
    },
  };
  return base[aesthetic] || base.clean;
}

Object.assign(window, { MatchScreen });
