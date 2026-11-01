# Fast Start 2

A balanced fast-start mod for Factorio 2.1, designed primarily for **Space Exploration** runs but fully compatible with vanilla.

Space Exploration is one of the most rewarding overhaul mods available — but the early game is a long grind that can kill a run before it gets interesting. This mod gets you past the repetitive bootstrapping phase so you can spend your time on the parts that actually matter.

Everything is configurable. If you want a lighter touch or a heavier one, dial it in via **Settings → Mod Settings → Map**.

---

## What You Get

Each player gets the kit **once**, the first time they join. It arrives whether you watch the intro cutscene, skip it, or have it turned off.

### 🗺️ Radar Scan
The map is revealed in a large radius around your spawn point (default: 448 tiles, roughly 2× the diameter of a standard radar's scan area). The reveal is shared with your entire team in multiplayer. The area generates in the background, so the map fills in over a few seconds instead of freezing the game.

### 📦 Starting Inventory
A set of mid-game infrastructure items so you can skip straight to building a real factory. Default quantities:

| Category | Items |
|---|---|
| Belts | 500 red belts, 80 red underground belts, 40 red splitters |
| Pipes | 100 pipes, 12 underground pipes |
| Power | 100 medium electric poles, 4 boilers, 8 steam engines, 2 offshore pumps |
| Mining & smelting | 30 electric mining drills, 30 stone furnaces |
| Production | 12 blue assemblers (assembling-machine-2), 60 fast inserters, 8 electric labs |
| AAI Industry only | 1 burner turbine generator (see below) |

Raw resources are intentionally left out. All quantities are individually configurable in Mod Settings.

**Burner turbine:** AAI Industry (required by Space Exploration) makes offshore pumps run on electricity, so you can't start a steam plant without power. The burner turbine needs no water and breaks that loop; tear it down once steam is running. It's only given when AAI Industry is installed.

### 🤖 Bots & Armor
Power armor pre-equipped with:
- **2 portable fission reactors** — personal power with no fuel or batteries to manage
- **1 personal roboport** — deploy construction bots immediately
- **1 exoskeleton** — faster movement from the start
- **26 construction robots** — in your inventory, ready to go

Defaults to **power armor (mk1)**, whose 6×8 grid exactly fits this loadout. Switch to **mk2** (10×10 grid) in settings if you want room for more roboports and exoskeletons.

Why two reactors? One portable fission reactor makes 750 kW in vanilla but only 500 kW under Space Exploration, which isn't enough to run an exoskeleton and recharge bots at full speed.

If you're already wearing armor when the kit arrives (for example, adding the mod to an existing save), your old armor and its equipment are moved to your inventory, not deleted.

---

## Multiplayer

Each player receives their own kit independently on their first join. Delivery is tracked in the save file, so rejoining, reloading, or updating mods never gives you the kit a second time.

---

## Adding to an Existing Save

Every player who hasn't received the kit yet gets it the next time the save is loaded with the mod enabled. Players keep their current armor (it's moved to their inventory).

---

## Configuration

All three feature groups can be independently enabled or disabled:

- **Enable starting inventory** — toggle the buildings/infrastructure kit
- **Enable radar scan** — toggle the map reveal
- **Enable construction bots & armor** — toggle the armor/equipment/bot bundle

Fine-grained quantity settings are available for every item category. See **Settings → Mod Settings → Map** in-game.

---

## Compatibility

- ✅ Factorio 2.1
- ✅ Space Exploration (primary target)
- ✅ Vanilla Factorio
- ✅ AAI Industry without Space Exploration
- ✅ Multiplayer / dedicated servers
- ⚠️ Other mods that give starter items may stack with this one — disable the relevant feature groups in settings if needed
- ⚠️ Items removed by other mods are skipped (and noted in the log) instead of causing errors

---

## Why "Fast Start 2"?

There are a few older fast-start mods around, most of which are unmaintained and have bugs (commonly: re-giving items every time you join a session). This is a clean rewrite with proper persistent state tracking and full configurability.

---

## License

MIT — see LICENSE file.
