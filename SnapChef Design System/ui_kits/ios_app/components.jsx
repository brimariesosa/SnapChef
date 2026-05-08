// SnapChef iOS components — pixel-faithful HTML/CSS recreation of the SwiftUI app.
// Style is owned by ../colors_and_type.css; this file only adds layout-specific tweaks
// and the component implementations.

const PHOSPHOR_BASE = "https://unpkg.com/@phosphor-icons/web@2.1.1/src/regular/style.css";
// Loaded by index.html

/* ---------------- atoms ---------------- */

const Icon = ({ name, size = 18, weight = "fill", style }) => (
  <i className={`ph${weight === "fill" ? "-fill" : weight === "bold" ? "-bold" : ""} ph-${name}`}
     style={{ fontSize: size, lineHeight: 1, ...style }} />
);

const GradientCircle = ({ from, to, size = 38, icon, iconSize, glow, weight = "fill" }) => (
  <div style={{
    width: size, height: size, borderRadius: "50%",
    background: `linear-gradient(135deg, ${from}, ${to})`,
    display: "flex", alignItems: "center", justifyContent: "center",
    color: "#fff", flexShrink: 0,
    boxShadow: glow ? `0 6px 10px ${glow}` : "none",
  }}>
    {icon && <Icon name={icon} size={iconSize ?? size * 0.45} weight={weight} />}
  </div>
);

const Pill = ({ children, color = "var(--forest)", filled, onClick }) => (
  <button onClick={onClick} className="snap-pill"
    style={{
      background: filled
        ? `linear-gradient(135deg, ${color}, ${color}b0)` : "#fff",
      color: filled ? "#fff" : color,
      border: filled ? "0" : `1.5px solid ${color}66`,
      boxShadow: filled
        ? `0 4px 8px ${color}59`
        : "0 1px 3px rgba(31,26,18,.04)",
    }}>
    {children}
  </button>
);

const StatusDot = ({ status, size = 10 }) => {
  const c = {
    fresh:  "#2BB673", soon: "#F5C24B",
    urgent: "#FF8A4C", expired: "#E2553F", unknown: "#7A7469",
  }[status] || "#7A7469";
  return <span style={{
    width: size, height: size, borderRadius: "50%", background: c,
    boxShadow: `0 0 0 4px ${c}33`, display: "inline-block", flexShrink: 0,
  }}/>;
};

/* ---------------- background layer ---------------- */

const AppBackground = ({ children }) => (
  <div className="snap-app-bg">
    <div className="snap-blob" style={{
      width: "85%", aspectRatio: "1/1", left: "-35%", top: "-30%",
      background: "rgba(255,178,122,.25)"
    }}/>
    <div className="snap-blob" style={{
      width: "75%", aspectRatio: "1/1", right: "-35%", bottom: "-20%",
      background: "rgba(130,218,178,.32)"
    }}/>
    <div className="snap-blob" style={{
      width: "50%", aspectRatio: "1/1", left: "-10%", bottom: "20%",
      background: "rgba(226,92,138,.10)"
    }}/>
    <div style={{ position: "relative", zIndex: 1, height: "100%" }}>{children}</div>
  </div>
);

/* ---------------- nav chrome ---------------- */

const LargeTitle = ({ title, accessory }) => (
  <div className="snap-large-title">
    <div className="t-h1" style={{ margin: 0, fontSize: 34 }}>{title}</div>
    {accessory}
  </div>
);

const SearchField = ({ placeholder = "Search ingredients", value, onChange }) => (
  <label className="snap-search">
    <Icon name="magnifying-glass" size={16} />
    <input type="text" placeholder={placeholder} value={value || ""}
      onChange={e => onChange?.(e.target.value)} />
  </label>
);

const TabBar = ({ active, onChange }) => {
  const tabs = [
    { id: "snap", label: "Snap", icon: "camera" },
    { id: "recipes", label: "Recipes", icon: "fork-knife" },
    { id: "pantry", label: "Pantry", icon: "package" },
    { id: "profile", label: "Profile", icon: "user" },
  ];
  return (
    <div className="snap-tabbar">
      {tabs.map(t => (
        <button key={t.id} onClick={() => onChange(t.id)}
          className={`snap-tab ${active === t.id ? "active" : ""}`}>
          <Icon name={t.icon} size={22} weight="fill" />
          <span>{t.label}</span>
        </button>
      ))}
    </div>
  );
};

/* ---------------- buttons ---------------- */

const PrimaryButton = ({ children, icon, onClick }) => (
  <button onClick={onClick} className="snap-btn snap-btn-primary">
    {icon && <Icon name={icon} size={18} weight="fill" />}{children}
  </button>
);
const SecondaryButton = ({ children, icon, onClick }) => (
  <button onClick={onClick} className="snap-btn snap-btn-secondary">
    {icon && <Icon name={icon} size={18} />}{children}
  </button>
);
const SunsetButton = ({ children, icon, onClick }) => (
  <button onClick={onClick} className="snap-btn snap-btn-sunset">
    {icon && <Icon name={icon} size={18} weight="fill" />}{children}
  </button>
);

/* ---------------- pantry ---------------- */

const CATEGORIES = {
  Produce:    { c: "#82DAB2", c2: "#4FC793", icon: "leaf" },
  Dairy:      { c: "#7ABCE8", c2: "#4F9FD0", icon: "drop" },
  Meat:       { c: "#FF7062", c2: "#E04D3F", icon: "fork-knife" },
  Seafood:    { c: "#7ABCE8", c2: "#5FA9D8", icon: "fish" },
  Grains:     { c: "#FFB27A", c2: "#E08F50", icon: "grains" },
  Pantry:     { c: "#FED56E", c2: "#E0B33F", icon: "package" },
  "Spices & Condiments": { c: "#E25C8A", c2: "#B83F6B", icon: "sparkle" },
  Frozen:     { c: "#8E60B2", c2: "#6F4090", icon: "snowflake" },
  Beverages:  { c: "#8E60B2", c2: "#6F4090", icon: "coffee" },
  Other:      { c: "#7A7469", c2: "#5C5650", icon: "shopping-bag" },
};

const PantryItemCard = ({ item, onClick }) => {
  const cat = CATEGORIES[item.category] || CATEGORIES.Other;
  return (
    <button onClick={onClick} className="snap-pantry-card" style={{
      borderColor: `${cat.c}30`,
      boxShadow: `0 8px 12px ${cat.c}20`,
    }}>
      <div className="row">
        <GradientCircle from={cat.c} to={cat.c2} icon={cat.icon}
          glow={`${cat.c}59`}/>
        <StatusDot status={item.status} />
      </div>
      <div className="t-title" style={{ margin: 0, fontSize: 16 }}>{item.name}</div>
      <div className="meta">
        <span>{item.qty} {item.unit}{item.batches > 1 && ` · ${item.batches} batches`}</span>
        {item.days != null && (
          <span style={{
            color: { fresh: "#2BB673", soon: "#F5C24B", urgent: "#FF8A4C",
              expired: "#E2553F" }[item.status] || "#7A7469",
            fontWeight: 600,
          }}>{item.days >= 0 ? `${item.days}d` : "expired"}</span>
        )}
      </div>
    </button>
  );
};

const ExpiringItemCard = ({ item }) => {
  const c = item.status === "urgent" ? "#FF8A4C" : "#F5C24B";
  const cat = CATEGORIES[item.category] || CATEGORIES.Other;
  return (
    <div className="snap-expiring-card" style={{
      background: `linear-gradient(135deg, ${c}, ${c}c0)`,
      boxShadow: `0 10px 12px ${c}59`,
    }}>
      <Icon name={cat.icon} size={22} weight="fill" />
      <div style={{ font: "700 14px/1.2 var(--font-display)" }}>{item.name}</div>
      <div style={{ font: "600 12px/1 var(--font-display)", opacity: .95 }}>
        {item.days === 0 ? "Today" : `${item.days}d left`}
      </div>
    </div>
  );
};

const CategoryChip = ({ label, icon, color = "var(--forest)", selected, onClick }) => (
  <button onClick={onClick} className="snap-chip" style={{
    background: selected
      ? `linear-gradient(135deg, ${color}, ${color}b0)` : "#fff",
    color: selected ? "#fff" : color,
    border: selected ? "0" : `1.5px solid ${color}66`,
    boxShadow: selected
      ? `0 4px 8px ${color}59`
      : "0 1px 3px rgba(31,26,18,.04)",
  }}>
    {icon && <Icon name={icon} size={11} weight="fill" />}{label}
  </button>
);

/* ---------------- recipe ---------------- */

const StatCard = ({ value, label, icon, gradient }) => (
  <div className="snap-stat">
    <div className="ic" style={{ background: gradient }}>
      <Icon name={icon} size={16} weight="fill" />
    </div>
    <div className="t-h2" style={{ fontSize: 22, margin: 0 }}>{value}</div>
    <div className="t-meta" style={{ fontSize: 11, fontWeight: 600 }}>{label}</div>
  </div>
);

const RecipeCard = ({ recipe, onClick }) => {
  const m = recipe.matchPercent;
  const heroGrad = m >= 80
    ? "linear-gradient(135deg,#226940,#56A56E,#82DAB2)"
    : m >= 50
      ? "linear-gradient(135deg,#FF7062,#FFB27A,#FED56E)"
      : "linear-gradient(135deg,#7A7469,#7A746999)";
  const matchGrad = m >= 80
    ? "linear-gradient(135deg,#2BB673,#82DAB2)"
    : m >= 50
      ? "linear-gradient(135deg,#FF7062,#FFB27A)"
      : "linear-gradient(135deg,#7A7469,#7A7469aa)";
  return (
    <button onClick={onClick} className="snap-recipe-card">
      <div className="hero" style={{ background: heroGrad }}>
        <Icon name={recipe.icon} size={36} weight="regular" />
      </div>
      <div className="body">
        <div className="t-title" style={{ margin: 0 }}>{recipe.title}</div>
        <div className="t-meta" style={{ overflow: "hidden",
          display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical" }}>
          {recipe.description}
        </div>
        <div className="row">
          <span><Icon name="clock" size={12}/>{recipe.totalTime}m</span>
          <span><Icon name="users" size={12}/>{recipe.servings}</span>
          <span style={{ marginLeft: "auto", background: matchGrad,
            color: "#fff", padding: "4px 10px", borderRadius: 999,
            fontWeight: 800, boxShadow: "0 4px 6px rgba(0,0,0,.1)",
          }}>{m}%</span>
        </div>
      </div>
    </button>
  );
};

/* ---------------- snap ---------------- */

const PulsingRing = ({ size = 220 }) => (
  <div className="snap-ring" style={{ width: size, height: size }}>
    <span/><span/><span/>
  </div>
);

const ScanPlaceholder = () => (
  <div className="snap-scan-placeholder">
    <PulsingRing />
    <div className="snap-scan-core">
      <GradientCircle from="#226940" to="#82DAB2" size={92} icon="camera"
        iconSize={44} glow="rgba(34,105,64,.35)" weight="fill" />
      <div className="t-h3" style={{ margin: 0, fontSize: 18 }}>Ready to scan</div>
      <div className="t-meta" style={{ margin: 0 }}>Snap or pick a photo to get started</div>
    </div>
  </div>
);

/* ---------------- exports ---------------- */
Object.assign(window, {
  Icon, GradientCircle, Pill, StatusDot, AppBackground,
  LargeTitle, SearchField, TabBar,
  PrimaryButton, SecondaryButton, SunsetButton,
  PantryItemCard, ExpiringItemCard, CategoryChip,
  StatCard, RecipeCard, PulsingRing, ScanPlaceholder, CATEGORIES,
});
