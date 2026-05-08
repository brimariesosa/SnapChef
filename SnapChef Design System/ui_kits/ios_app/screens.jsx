// SnapChef screens — composed from components.jsx into the full click-thru.

const { useState, useMemo } = React;

/* ---------------- seed data ---------------- */

const SEED_PANTRY = [
  { id: 1, name: "Spinach",        category: "Produce",  qty: 200, unit: "g",   batches: 2, days: 4,  status: "soon" },
  { id: 2, name: "Chicken thighs", category: "Meat",     qty: 500, unit: "g",   batches: 1, days: 2,  status: "urgent" },
  { id: 3, name: "Greek yogurt",   category: "Dairy",    qty: 1,   unit: "tub", batches: 1, days: 9,  status: "fresh" },
  { id: 4, name: "Cherry tomatoes",category: "Produce",  qty: 1,   unit: "pint",batches: 1, days: 3,  status: "soon" },
  { id: 5, name: "Brown rice",     category: "Grains",   qty: 1,   unit: "kg",  batches: 1, days: 280,status: "fresh" },
  { id: 6, name: "Cilantro",       category: "Produce",  qty: 1,   unit: "bunch",batches: 1, days: 1, status: "urgent" },
  { id: 7, name: "Olive oil",      category: "Pantry",   qty: 1,   unit: "btl", batches: 1, days: 420,status: "fresh" },
  { id: 8, name: "Feta cheese",    category: "Dairy",    qty: 200, unit: "g",   batches: 1, days: 14, status: "fresh" },
];

const SEED_RECIPES = [
  { id: "r1", title: "Tomato basil galette", icon: "pie-chart-slice",
    description: "Free-form tart with summer tomatoes, ricotta, and a fistful of basil. Uses up the bread you already have.",
    totalTime: 35, servings: 4, matchPercent: 82, tags: ["vegetarian"] },
  { id: "r2", title: "One-pan chicken & spinach orzo", icon: "cooking-pot",
    description: "Creamy lemon orzo simmered with thighs and wilted greens. Done in 25 minutes, one pot.",
    totalTime: 25, servings: 4, matchPercent: 92, tags: [] },
  { id: "r3", title: "Yogurt-marinated chicken bowls", icon: "bowl-food",
    description: "Tangy yogurt and herbs do the work overnight. Char on the stovetop, pile onto rice.",
    totalTime: 40, servings: 2, matchPercent: 76, tags: [] },
  { id: "r4", title: "Quick cilantro-lime rice", icon: "grains",
    description: "Rinsed brown rice, lime zest, a fistful of cilantro. The side dish that fixes any leftover.",
    totalTime: 22, servings: 4, matchPercent: 100, tags: ["vegan"] },
  { id: "r5", title: "Greek-ish chopped salad", icon: "leaf",
    description: "Tomatoes, feta, cucumber if you have it. Olive oil, lemon, salt — that's the dressing.",
    totalTime: 10, servings: 2, matchPercent: 64, tags: ["vegetarian"] },
];

/* ---------------- onboarding ---------------- */

const OnboardingScreen = ({ onDone }) => {
  const [page, setPage] = useState(0);
  const pages = [
    { icon: "camera", title: "Snap your fridge",
      sub: "Point your camera and let AI identify every ingredient in seconds.",
      grad: "linear-gradient(135deg,#226940,#56A56E,#82DAB2)" },
    { icon: "cooking-pot", title: "Cook what you have",
      sub: "Get recipe matches based on your pantry, diet, and kitchen equipment.",
      grad: "linear-gradient(135deg,#FF7062,#FFB27A,#FED56E)" },
    { icon: "leaf", title: "Waste nothing",
      sub: "Expiration alerts remind you to use ingredients before they spoil.",
      grad: "linear-gradient(135deg,#E25C8A,#8E60B2)" },
  ];
  const p = pages[page];
  return (
    <AppBackground>
      <div className="snap-onboard">
        <div className="hero">
          <div className="halo" style={{ background: p.grad }}/>
          <div className="orb"  style={{ background: p.grad }}>
            <Icon name={p.icon} size={80} weight="regular" />
          </div>
        </div>
        <div className="t-h1" style={{ fontSize: 34, textAlign: "center" }}>{p.title}</div>
        <div className="t-body" style={{ color: "var(--warm-gray)", textAlign: "center", padding: "0 24px" }}>
          {p.sub}
        </div>
        <div className="dots">
          {pages.map((_, i) => (
            <span key={i} className={i === page ? "on" : ""}/>
          ))}
        </div>
        <div className="actions">
          <PrimaryButton icon={page < 2 ? "arrow-right" : "sparkle"}
            onClick={() => page < 2 ? setPage(page + 1) : onDone()}>
            {page < 2 ? "Next" : "Get Started"}
          </PrimaryButton>
          {page < 2 && (
            <button onClick={onDone} className="snap-skip">Skip</button>
          )}
        </div>
      </div>
    </AppBackground>
  );
};

/* ---------------- snap tab ---------------- */

const SnapScreen = ({ onScan }) => {
  const [scanning, setScanning] = useState(false);
  const start = () => {
    setScanning(true);
    setTimeout(() => { setScanning(false); onScan(); }, 1800);
  };
  return (
    <AppBackground>
      <div className="snap-nav">Snap & Scan</div>
      <div className="snap-screen">
        <div className="hero-card">
          <div className="t-h2" style={{ fontSize: 28, margin: 0, textAlign: "center" }}>
            Point and snap
          </div>
          <div className="t-meta" style={{ textAlign: "center", padding: "0 16px" }}>
            SnapChef AI identifies every ingredient in seconds.
          </div>
        </div>
        <ScanPlaceholder />
        <div style={{ flex: 1 }}/>
        <div className="actions">
          <PrimaryButton icon="camera" onClick={start}>Take Photo</PrimaryButton>
          <SecondaryButton icon="image-square" onClick={start}>Choose from Library</SecondaryButton>
          <button className="snap-demo-btn" onClick={start}>
            <Icon name="sparkle" size={14} weight="fill" />Demo Library
          </button>
        </div>
      </div>
      {scanning && (
        <div className="snap-scan-overlay">
          <PulsingRing size={120}/>
          <Icon name="sparkle" size={36} weight="fill" style={{ position: "absolute", color: "#fff" }}/>
          <div className="t-h3" style={{ color: "#fff", marginTop: 24, fontSize: 18 }}>
            Identifying ingredients…
          </div>
          <div className="t-meta" style={{ color: "rgba(255,255,255,.85)" }}>
            AI is analyzing your photo
          </div>
        </div>
      )}
    </AppBackground>
  );
};

/* ---------------- scan results ---------------- */

const SCAN_DETECTED = [
  { id: "d1", name: "Bell pepper",   category: "Produce", confidence: 0.94, selected: true },
  { id: "d2", name: "Spinach",       category: "Produce", confidence: 0.91, selected: true, inPantry: true },
  { id: "d3", name: "Lemon",         category: "Produce", confidence: 0.88, selected: true },
  { id: "d4", name: "Whole milk",    category: "Dairy",   confidence: 0.86, selected: true },
  { id: "d5", name: "Salmon fillet", category: "Seafood", confidence: 0.82, selected: false },
];

const ScanResultsScreen = ({ onDone }) => {
  const [items, setItems] = useState(SCAN_DETECTED);
  const toggle = id => setItems(items.map(it =>
    it.id === id ? { ...it, selected: !it.selected } : it));
  const selectedCount = items.filter(i => i.selected).length;

  return (
    <AppBackground>
      <div className="snap-sheet-nav">
        <button className="snap-link" onClick={onDone}>Cancel</button>
        <span className="t-title" style={{ fontSize: 16 }}>Scan Results</span>
        <button className="snap-link bold" onClick={onDone}>Add {selectedCount}</button>
      </div>
      <div className="snap-screen scroll">
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <Icon name="sparkle" size={14} weight="fill" style={{ color: "#FF8A4C" }}/>
          <span className="t-meta">Tap a row to edit. Uncheck anything we got wrong.</span>
        </div>

        <div className="t-caption" style={{ marginTop: 8 }}>Scanned items ({items.length})</div>

        <div className="snap-detection-list">
          {items.map(it => {
            const cat = CATEGORIES[it.category] || CATEGORIES.Other;
            return (
              <div key={it.id} className="snap-detection-row" onClick={() => toggle(it.id)}>
                <span className={`check ${it.selected ? "on" : ""}`}>
                  {it.selected && <Icon name="check" size={14} weight="bold"/>}
                </span>
                <div className="ic" style={{ background: `${cat.c}26`, color: "var(--forest)" }}>
                  <Icon name={cat.icon} size={18} weight="fill"/>
                </div>
                <div className="body">
                  <div className="row">
                    <span style={{ font: "600 16px/1.2 var(--font-display)" }}>{it.name}</span>
                    {it.inPantry && <span className="pantry-tag">in pantry</span>}
                  </div>
                  <div className="t-meta">
                    {it.category} · <span style={{ color: "#2BB673" }}>{Math.round(it.confidence*100)}% confidence</span>
                  </div>
                </div>
                <Icon name="pencil-circle" size={22} weight="fill" style={{ color: "rgba(34,105,64,.7)" }}/>
              </div>
            );
          })}
          <button className="snap-add-missed">
            <Icon name="plus-circle" size={16} weight="fill"/>Add item the scan missed
          </button>
        </div>

        <div className="t-caption" style={{ marginTop: 8 }}>Recipe suggestions</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {SEED_RECIPES.slice(0, 3).map(r => (
            <RecipeCard key={r.id} recipe={r}/>
          ))}
        </div>
      </div>
    </AppBackground>
  );
};

/* ---------------- pantry tab ---------------- */

const PantryScreen = () => {
  const [search, setSearch] = useState("");
  const [cat, setCat] = useState("All");
  const items = SEED_PANTRY.filter(i =>
    (cat === "All" || i.category === cat) &&
    (!search || i.name.toLowerCase().includes(search.toLowerCase()))
  );
  const expiring = SEED_PANTRY.filter(i => i.status === "urgent" || i.status === "soon");

  return (
    <AppBackground>
      <LargeTitle title="Pantry" accessory={
        <div className="snap-add-btn">
          <Icon name="plus" size={16} weight="bold" />
        </div>
      }/>
      <div className="snap-screen scroll">
        <SearchField value={search} onChange={setSearch}/>

        {expiring.length > 0 && (
          <div className="snap-expiring-section">
            <div className="head">
              <GradientCircle from="#FF7062" to="#FED56E" size={28} icon="clock-countdown"
                iconSize={13}/>
              <span className="t-h3" style={{ fontSize: 18, margin: 0 }}>Use soon</span>
              <span className="count">{expiring.length}</span>
            </div>
            <div className="strip">
              {expiring.map(i => <ExpiringItemCard key={i.id} item={i}/>)}
            </div>
          </div>
        )}

        <div className="snap-chip-row">
          <CategoryChip label="All" selected={cat === "All"} onClick={() => setCat("All")} color="#226940"/>
          {Object.entries(CATEGORIES).slice(0, 6).map(([name, c]) => (
            <CategoryChip key={name} label={name} icon={c.icon} color={c.c}
              selected={cat === name} onClick={() => setCat(name)}/>
          ))}
        </div>

        <div className="snap-pantry-grid">
          {items.map(i => <PantryItemCard key={i.id} item={i}/>)}
        </div>
      </div>
    </AppBackground>
  );
};

/* ---------------- recipes tab ---------------- */

const RecipesScreen = () => {
  const [filter, setFilter] = useState("All");
  const filters = ["All", "High Match", "Quick (≤20min)", "Vegetarian"];
  const recipes = SEED_RECIPES.filter(r => {
    if (filter === "High Match") return r.matchPercent >= 60;
    if (filter === "Quick (≤20min)") return r.totalTime <= 20;
    if (filter === "Vegetarian") return r.tags.includes("vegetarian") || r.tags.includes("vegan");
    return true;
  });

  return (
    <AppBackground>
      <LargeTitle title="Recipes"/>
      <div className="snap-screen scroll">
        <SearchField placeholder="Search recipes"/>
        <div className="snap-stats">
          <StatCard value={SEED_PANTRY.length} label="Ingredients" icon="package"
            gradient="linear-gradient(135deg,#226940,#56A56E)"/>
          <StatCard value={SEED_RECIPES.length} label="Recipes" icon="fork-knife"
            gradient="linear-gradient(135deg,#FF7062,#FFB27A,#FED56E)"/>
          <StatCard value={SEED_RECIPES.filter(r => r.matchPercent >= 60).length}
            label="Matches" icon="star" gradient="linear-gradient(135deg,#E25C8A,#8E60B2)"/>
        </div>
        <div className="snap-chip-row">
          {filters.map(f => (
            <CategoryChip key={f} label={f} selected={filter === f}
              onClick={() => setFilter(f)} color="#226940"/>
          ))}
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          {recipes.map(r => <RecipeCard key={r.id} recipe={r}/>)}
        </div>
      </div>
    </AppBackground>
  );
};

/* ---------------- profile (light) ---------------- */

const ProfileScreen = () => (
  <AppBackground>
    <LargeTitle title="Profile"/>
    <div className="snap-screen scroll">
      <div className="snap-profile-hero">
        <div className="orb"><Icon name="user" size={36} weight="fill"/></div>
        <div>
          <div className="t-h3" style={{ margin: 0 }}>My Profile</div>
          <div className="t-meta">Vegetarian · 3 allergies</div>
        </div>
      </div>
      <div className="t-caption">Dietary</div>
      <div className="snap-toggle-card">
        {["Vegetarian","Vegan","Gluten-free","Dairy-free","Nut-free"].map((label, i) => (
          <div key={label} className="row">
            <span style={{ font: "600 15px/1 var(--font-display)" }}>{label}</span>
            <span className={`toggle ${i < 1 ? "on" : ""}`}><span/></span>
          </div>
        ))}
      </div>
      <div className="t-caption">Kitchen equipment</div>
      <div className="snap-equip-grid">
        {["Oven","Stovetop","Microwave","Air Fryer","Slow Cooker","Blender","Toaster","Grill"].map((e, i) => (
          <div key={e} className={`equip ${i < 5 ? "on" : ""}`}>{e}</div>
        ))}
      </div>
    </div>
  </AppBackground>
);

Object.assign(window, {
  OnboardingScreen, SnapScreen, ScanResultsScreen,
  PantryScreen, RecipesScreen, ProfileScreen,
});
