-- =============================================================================
-- SE Fast Start: control.lua
-- =============================================================================
--
-- This is the sole runtime script for the mod. Factorio's mod lifecycle has
-- three distinct stages:
--   1. settings  - settings.lua runs; defines mod settings
--   2. data       - data*.lua runs; defines prototypes (items, recipes, etc.)
--   3. control    - control.lua runs at game load; handles events and logic
--
-- We only need the control stage since we're not adding new prototypes — we're
-- just handing the player existing items at the right moment.
--
-- All three feature groups (inventory, radar scan, bots/armor) are independent
-- and individually togglable via Mod Settings. Each has its own function and
-- guards itself with the relevant toggle at the top.
-- =============================================================================


-- =============================================================================
-- SETTINGS HELPER
-- =============================================================================

-- Shorthand to read a mod setting by its suffix (strips the "sefs-" prefix
-- boilerplate so callsites stay readable, e.g. s("enable-bots") instead of
-- settings.global["sefs-enable-bots"].value).
local function s(name)
    return settings.global["sefs-" .. name].value
end


-- =============================================================================
-- ITEM DELIVERY HELPER
-- =============================================================================

-- Puts `count` of an item into the character's main inventory. Anything that
-- doesn't fit is spilled on the ground at the character's feet (flagged so the
-- player picks it up automatically by walking over it) rather than lost.
--
-- Items that don't exist in the current mod set (e.g. removed or renamed by an
-- overhaul mod) are skipped with a log line instead of crashing the game.
--
-- Returns the number of items actually given (inserted + spilled).
local function give_item(character, name, count)
    if count <= 0 then return 0 end
    if not prototypes.item[name] then
        log("[fast-start-2] give_item: item '" .. name .. "' does not exist, skipping")
        return 0
    end

    local inv = character.get_main_inventory()
    local inserted = inv and inv.insert({ name = name, count = count }) or 0

    if inserted < count then
        character.surface.spill_item_stack{
            position      = character.position,
            stack         = { name = name, count = count - inserted },
            enable_looted = true,
        }
    end
    return count
end


-- =============================================================================
-- RADAR SCAN
-- =============================================================================

-- Reveals a large area of the map around the player's spawn position the first
-- time they join. Charts to the player's entire *force* (team), so in
-- multiplayer all teammates immediately benefit from the revealed area too.
--
-- The radius is configurable in Mod Settings. Default is 448 tiles, which is
-- roughly 2x the diameter of a standard radar's scan area (a radar covers ~7
-- chunks / 224 tiles radius at full scan).
--
-- GENERATION HAPPENS IN THE BACKGROUND:
--   We deliberately do NOT call surface.force_generate_chunk_requests(). That
--   blocks the whole game until every chunk exists — about 840 chunks at the
--   default radius and ~16,000 at the maximum — freezing every player in
--   multiplayer. Instead we queue the chunks for normal background generation
--   and let chart() fill in the map as they arrive.
local function do_radar_scan(player, character)
    if not s("enable-radar-scan") then return end

    local radius = s("radar-radius")
    local surface = character.surface
    local pos = character.position

    -- Chunks are 32x32 tiles; request_to_generate_chunks takes a chunk radius.
    surface.request_to_generate_chunks(pos, math.ceil(radius / 32))

    -- chart() takes a bounding box in tile coordinates, not chunk coordinates.
    -- It refreshes the chart for the area and creates it for any part that
    -- hasn't been charted yet, without blocking on generation.
    player.force.chart(surface, {
        { pos.x - radius, pos.y - radius },
        { pos.x + radius, pos.y + radius }
    })

    player.print("[Fast Start 2] Radar scan started - revealing a " .. radius .. " tile radius.")
end


-- =============================================================================
-- STARTING INVENTORY
-- =============================================================================

-- Inserts a set of early-game buildings and infrastructure items directly into
-- the player's main inventory. Quantities for every item are individually
-- configurable in Mod Settings so players can tune the kit to taste.
--
-- If the player's inventory is full (unlikely at spawn but possible with other
-- mods), give_item() spills the overflow at their feet rather than losing it.
--
-- Note: raw resources (iron, copper, coal, etc.) are intentionally excluded.
-- The point of this mod is to skip the repetitive early building grind, not
-- to skip resource gathering entirely — that's still the fun part.
local function do_inventory(player, character)
    if not s("enable-inventory") then return end

    local items = {
        -- BELTS — red belts are the sweet spot: cheap to build toward,
        -- fast enough to last well into mid-game without replacement.
        { name = "fast-transport-belt",   count = s("count-fast-belt")       },
        { name = "fast-underground-belt", count = s("count-fast-underground") },
        { name = "fast-splitter",         count = s("count-fast-splitter")    },

        -- PIPES — needed for the steam power setup and oil processing early on.
        { name = "pipe",                      count = s("count-pipe")            },
        { name = "pipe-to-ground",            count = s("count-pipe-underground") },

        -- POWER INFRASTRUCTURE — enough to stand up a small steam plant
        -- immediately so the player isn't hand-mining coal for burner drills.
        { name = "medium-electric-pole",  count = s("count-medium-pole")      },
        { name = "boiler",                count = s("count-boiler")           },
        { name = "steam-engine",          count = s("count-steam-turbine")    },
        { name = "offshore-pump",         count = s("count-offshore-pump")    },

        -- MINING & SMELTING — electric miners + stone furnaces get an ore
        -- → plate pipeline running without touching burner equipment.
        { name = "electric-mining-drill", count = s("count-electric-miner")   },
        { name = "stone-furnace",         count = s("count-stone-furnace")    },

        -- PRODUCTION — blue assemblers handle everything up to mid-game
        -- recipes. Fast inserters only: regular inserters are too slow to
        -- be worth carrying when you already have fast ones available.
        -- Labs are included to avoid the coal micromanagement of burner labs.
        { name = "assembling-machine-2",  count = s("count-assembler")        },
        { name = "fast-inserter",         count = s("count-fast-inserter")    },
        { name = "lab",                   count = s("count-lab")              },
        -- AAI INDUSTRY BOOTSTRAP — AAI Industry (required by Space Exploration,
        -- but also usable on its own) makes offshore pumps require electricity,
        -- creating a chicken-and-egg problem with steam power. The burner
        -- turbine generator needs no water and breaks the cycle. Give one to
        -- bootstrap the initial power setup, then tear it down once the steam
        -- plant is running. give_item() silently skips it when AAI isn't loaded.
        { name = "burner-turbine",        count = 1                           },
    }

    for _, item in ipairs(items) do
        give_item(character, item.name, item.count)
    end

    player.print("[SE Fast Start] Starting inventory delivered.")
end


-- =============================================================================
-- BOTS, ARMOR & EQUIPMENT
-- =============================================================================

-- Equips the player with power armor and fills the armor grid with portable
-- fission reactors, personal roboports, and exoskeletons, then gives
-- construction bots.
--
-- ARMOR TIER & GRID SPACE:
--   The player can choose between power-armor (mk1, 6x8 grid) and
--   power-armor-mk2 (10x10 grid) in Mod Settings. Equipment sizes:
--     fission reactor 4x4, personal roboport 2x2, exoskeleton 2x4.
--   The default kit (2 reactors, 1 roboport, 1 exoskeleton) fits mk1: the two
--   reactors fill a 4x8 strip, leaving a 2x8 column for the roboport and exo.
--   mk2 fits 2 reactors + 2 roboports + 2 exoskeletons with room to spare.
--
-- POWER SOURCE — PORTABLE FISSION REACTOR:
--   Personal roboports and exoskeletons both draw from the armor's equipment
--   grid power supply. Without power the roboports won't deploy bots and
--   exoskeletons won't boost movement speed.
--
--   A fission reactor needs no fuel, unlike batteries (deplete and strand bots
--   mid-construction) or solar panels (nothing at night). One reactor makes
--   750 kW in vanilla but only 500 kW under Space Exploration, while one
--   exoskeleton alone uses 200 kW and a roboport recharging bots can draw much
--   more. Two reactors keep everything running at full speed.
--
--   (The newer "fusion-reactor-equipment" is a late-game Space Age unlock and
--   not appropriate for a fast-start kit.)
--
-- EXISTING ARMOR:
--   If the player is already wearing armor (e.g. the mod was added to an
--   existing save), it is moved into their main inventory with all of its
--   equipment, never deleted.
--
-- CONSTRUCTION BOTS:
--   Bots go into the main inventory, not the armor grid. Once the personal
--   roboport equipment is active, Factorio automatically deploys bots from the
--   player's inventory as needed.

-- Puts up to `count` of an equipment into the grid and returns how many fit.
-- grid.put() returns nil when there's no room left for that shape.
local function place_equipment(grid, name, count)
    if count <= 0 then return 0 end
    if not prototypes.equipment[name] then
        log("[fast-start-2] place_equipment: equipment '" .. name .. "' does not exist, skipping")
        return 0
    end

    local placed = 0
    for _ = 1, count do
        if not grid.put({ name = name }) then break end
        placed = placed + 1
    end
    return placed
end

local function do_bots(player, character)
    if not s("enable-bots") then return end

    local bot_count     = s("count-construction-bot")
    local reactor_count = s("count-reactor")
    local robo_count    = s("count-roboport")
    local exo_count     = s("count-exoskeleton")
    local armor_name    = s("armor-tier")  -- "power-armor" or "power-armor-mk2"

    local armor_inv = character.get_inventory(defines.inventory.character_armor)
    local main_inv  = character.get_main_inventory()

    if not prototypes.item[armor_name] then
        player.print(
            "[Fast Start 2] Warning: armor '" .. armor_name ..
            "' not found. Check your armor tier setting. Armor skipped."
        )
    elseif armor_inv and main_inv then
        -- Build the new armor in a free main-inventory slot, then swap it into
        -- the armor slot. Whatever the player was wearing ends up in that
        -- inventory slot instead. If the inventory is completely full and the
        -- player already wears armor, skip rather than risk deleting it.
        local was_wearing = armor_inv[1].valid_for_read
        local new_stack = main_inv.find_empty_stack()
        local built_in_armor_slot = false
        if not new_stack and not was_wearing then
            new_stack = armor_inv[1]
            built_in_armor_slot = true
        end

        if not new_stack then
            player.print("[Fast Start 2] Warning: inventory full, so your current armor was kept. Armor skipped.")
        else
            new_stack.set_stack({ name = armor_name, count = 1 })
            local grid = new_stack.grid
            if not grid then
                player.print("[Fast Start 2] Warning: armor '" .. armor_name .. "' has no equipment grid. Equipment skipped.")
            else
                -- Reactors first (largest, and everything else needs power),
                -- exoskeletons last since they matter least if space runs out.
                local reactors = place_equipment(grid, "fission-reactor-equipment", reactor_count)
                local robos    = place_equipment(grid, "personal-roboport-equipment", robo_count)
                local exos     = place_equipment(grid, "exoskeleton-equipment", exo_count)

                player.print(
                    "[Fast Start 2] " .. armor_name .. " equipped: " ..
                    reactors .. " fission reactor(s), " .. robos .. " roboport(s), " ..
                    exos .. " exoskeleton(s)."
                )
                if reactors < reactor_count or robos < robo_count or exos < exo_count then
                    player.print(
                        "[Fast Start 2] Warning: not all equipment fit in the armor grid. " ..
                        "Switch to power-armor-mk2 or lower the equipment counts."
                    )
                end
            end

            if not built_in_armor_slot and new_stack.valid_for_read then
                armor_inv[1].swap_stack(new_stack)
                if was_wearing then
                    player.print("[Fast Start 2] Your previous armor was moved to your inventory.")
                end
            end
        end
    end

    -- Bots go in after the armor so the armor's extra inventory slots exist.
    -- The personal roboport equipment deploys bots from here once it's active.
    if give_item(character, "construction-robot", bot_count) > 0 then
        player.print("[Fast Start 2] " .. bot_count .. " construction robots added to inventory.")
    end
end


-- =============================================================================
-- MAIN ENTRY POINT
-- =============================================================================

-- Orchestrates all three feature groups in a sensible order:
--   1. Radar scan first so the map is revealed before the player moves
--   2. Bots/armor second, because equipping power armor adds inventory slots
--   3. Inventory last so the buildings have the most room to land in
--
-- WHICH CHARACTER?
--   While the freeplay intro cutscene is playing, player.character is nil and
--   the real character is parked in player.cutscene_character until the
--   cutscene ends. We give the kit straight to whichever one exists, so the
--   kit arrives on creation whether the player watches the intro, skips it,
--   or has it disabled. Everything else (inventories, position, surface) is
--   read from that character entity rather than from the player.
--
-- Returns false if there is no character at all yet (e.g. a player who has
-- not spawned), so the caller leaves the "given" flag unset and retries later.
local function give_fast_start(player)
    local character = player.character or player.cutscene_character
    if not (character and character.valid) then
        log("[fast-start-2] give_fast_start: no character yet for " .. player.name .. ", deferring")
        return false
    end

    log("[fast-start-2] give_fast_start: starting for player " .. player.name)
    do_radar_scan(player, character)
    do_bots(player, character)
    do_inventory(player, character)
    log("[fast-start-2] give_fast_start: complete for player " .. player.name)
    return true
end


-- =============================================================================
-- EVENT HANDLERS
-- =============================================================================
--
-- WHICH EVENTS?
--   on_player_created     — fires when a brand new player is created
--                           (singleplayer start, or first ever join in MP).
--                           This is where the kit is normally delivered.
--   on_player_joined_game — fires every time a player connects. Retries for
--                           anyone who had no character when they were created.
--   on_cutscene_finished / on_cutscene_cancelled — the character is guaranteed
--                           to be back on the player by now, so these are a
--                           last safety net for scenarios that create the
--                           character late.
--
--   All of them go through try_give_fast_start(), which checks the persistent
--   "already given" flag, so it's harmless for several of them to fire.
--
-- WHY PLAYER_INDEX AND NOT THE PLAYER OBJECT?
--   Factorio player *objects* are Lua userdata — live references that are
--   recreated fresh each time the game loads. Using a player object as a table
--   key would mean the guard check always fails after a reload (different
--   reference = different key), causing the kit to be given again every session.
--
--   player_index is a plain integer that is stable across save/load cycles,
--   so it's the correct key for anything stored in the persistent `storage` table.
--
-- WHY STORAGE TABLE?
--   The `storage` table (called `global` in Factorio 1.x) is the only Lua table
--   that Factorio serialises into the save file. Anything else (local variables,
--   module-level tables) is wiped on every game load. Storing our "already given"
--   flag anywhere other than `storage` would mean it resets on every reload.
--   Renamed from `global` to `storage` in Factorio 2.0.

-- Gives the kit once per player. The flag is only set if the kit was actually
-- delivered, so a player with no character yet is retried by the next event.
local function try_give_fast_start(player)
    if not (player and player.valid) then return end

    -- Defensive init: on_init/on_configuration_changed set this up, but guard
    -- here too so an event can never index a missing table.
    storage.fast_start_given = storage.fast_start_given or {}
    if storage.fast_start_given[player.index] then return end

    if give_fast_start(player) then
        storage.fast_start_given[player.index] = true
    end
end

local function on_player_event(event)
    try_give_fast_start(game.get_player(event.player_index))
end

script.on_event(defines.events.on_player_created,     on_player_event)
script.on_event(defines.events.on_player_joined_game, on_player_event)
script.on_event(defines.events.on_cutscene_finished,  on_player_event)
script.on_event(defines.events.on_cutscene_cancelled, on_player_event)

-- on_init runs exactly once when the mod is first loaded into a brand new save.
-- We initialise the storage table here so it's always valid when events fire.
script.on_init(function()
    storage.fast_start_given = {}
end)

-- on_configuration_changed fires when this mod is added to an existing save
-- (on_init does NOT run in that case), and also whenever the game or any mod
-- is updated. Players already flagged as given are skipped, so updates never
-- hand out a second kit; only players who never got one receive it here.
script.on_configuration_changed(function()
    storage.fast_start_given = storage.fast_start_given or {}

    for _, player in pairs(game.players) do
        try_give_fast_start(player)
    end
end)
