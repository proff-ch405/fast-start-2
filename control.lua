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
-- We call request_to_generate_chunks + force_generate_chunk_requests first to
-- ensure the chunks actually exist before we try to chart them — charting an
-- ungenerated chunk is a no-op.
local function do_radar_scan(player)
    if not s("enable-radar-scan") then return end

    local radius = s("radar-radius")
    local surface = player.surface
    local pos = player.position

    -- Chunks are 32x32 tiles. We need to generate all chunks within the radius
    -- before charting, otherwise the map stays black even after the chart call.
    local chunk_radius = math.ceil(radius / 32)
    surface.request_to_generate_chunks(pos, chunk_radius)
    surface.force_generate_chunk_requests()

    -- chart() takes a bounding box in tile coordinates, not chunk coordinates.
    -- This reveals the full square area to the player's force on the map.
    player.force.chart(surface, {
        { pos.x - radius, pos.y - radius },
        { pos.x + radius, pos.y + radius }
    })

    player.print("[SE Fast Start] Radar scan complete - " .. radius .. " tile radius revealed.")
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
local function do_inventory(player)
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
        give_item(player.character, item.name, item.count)
    end

    player.print("[SE Fast Start] Starting inventory delivered.")
end


-- =============================================================================
-- BOTS, ARMOR & EQUIPMENT
-- =============================================================================

-- Equips the player with power armor and fills the armor grid with a fusion
-- reactor, personal roboports, and exoskeletons, then gives construction bots.
--
-- ARMOR TIER:
--   The player can choose between power-armor (mk1, 7x7 grid) and
--   power-armor-mk2 (10x10 grid) in Mod Settings.
--
--   We default to mk2 because Space Exploration (the primary target mod for
--   this fast-start) makes mk2 available much earlier than vanilla, and the
--   larger grid comfortably fits: 1 fusion reactor + 2 roboports + 2 exos.
--   On a 7x7 mk1 grid, fitting all of that is tight and may fail silently.
--
--   Vanilla players without SE should switch the setting to mk1, since mk2
--   is a very late research unlock in vanilla and would feel out of place.
--
-- POWER SOURCE — FUSION REACTOR:
--   Personal roboports and exoskeletons both draw from the armor's equipment
--   grid power supply. Without a power source the roboports won't deploy bots
--   and exoskeletons won't boost movement speed.
--
--   We use a fusion reactor (infinite power, no fuel needed) rather than
--   batteries or solar panels because:
--     - Batteries deplete and leave bots stranded mid-construction
--     - Solar panels produce nothing underground or at night
--     - A fusion reactor "just works" for the entire run with zero upkeep
--   This is intentional: the goal is to remove friction, not to make the
--   player manage personal power as another early-game chore.
--
-- CONSTRUCTION BOTS:
--   Bots go into the main inventory, not the armor grid. Once the personal
--   roboport equipment is active, Factorio automatically pulls bots from the
--   player's inventory into the roboport's internal buffer as needed.
local function do_bots(player)
    if not s("enable-bots") then return end

    local inv = player.get_main_inventory()
    if not inv then return end

    local bot_count  = s("count-construction-bot")
    local robo_count = s("count-roboport")
    local exo_count  = s("count-exoskeleton")
    local armor_name = s("armor-tier")  -- "power-armor" or "power-armor-mk2"

    -- Give construction bots to main inventory. The personal roboport equipment
    -- will automatically pull bots from here once it's active.
    give_item(player.character, "construction-robot", bot_count)

    -- Safety check: if the chosen armor somehow doesn't exist in this mod
    -- configuration (e.g. a mod removed it), fall back gracefully rather
    -- than throwing a hard error.
    -- Note: game.item_prototypes was moved to prototypes.item in Factorio 2.0
    if not prototypes.item[armor_name] then
        player.print(
            "[SE Fast Start] Warning: armor '" .. armor_name ..
            "' not found. Check your armor tier setting. Bots/equipment skipped."
        )
        return
    end

    -- Clear the armor slot before inserting — handles edge cases where the
    -- player already has armor equipped from another mod's starter kit.
    local armor_inv = player.get_inventory(defines.inventory.character_armor)
    if not armor_inv then return end

    armor_inv.clear()
    armor_inv.insert({ name = armor_name, count = 1 })

    -- Retrieve the equipment grid from the newly inserted armor stack.
    -- We validate each step because if any layer is nil (e.g. the armor item
    -- has no grid defined) we want a clear warning rather than a Lua error.
    local armor_stack = armor_inv[1]
    if not (armor_stack and armor_stack.valid_for_read and armor_stack.grid) then
        player.print("[SE Fast Start] Warning: could not access armor grid. Equipment skipped.")
        return
    end

    local grid = armor_stack.grid

    -- Place fission reactor first — provides personal power for roboports and
    -- exoskeletons. Note: in Factorio 2.0 the old "fusion-reactor-equipment"
    -- was renamed to "fission-reactor-equipment". The new fusion reactor is a
    -- late-game DLC unlock and not appropriate for a fast-start kit.
    grid.put({ name = "fission-reactor-equipment" })

    -- Place personal roboports. grid.put() returns nil if there's no room,
    -- so we warn and break rather than silently placing fewer than expected.
    for i = 1, robo_count do
        if not grid.put({ name = "personal-roboport-equipment" }) then
            player.print(
                "[SE Fast Start] Warning: armor grid full after " .. (i - 1) ..
                " roboport(s). Consider switching to mk2 armor for a larger grid."
            )
            break
        end
    end

    -- Place exoskeletons last since they're lowest priority if space is tight.
    for i = 1, exo_count do
        if not grid.put({ name = "exoskeleton-equipment" }) then
            player.print(
                "[SE Fast Start] Warning: armor grid full after " .. (i - 1) ..
                " exoskeleton(s). Consider switching to mk2 armor for a larger grid."
            )
            break
        end
    end

    player.print(
        "[SE Fast Start] " .. armor_name .. " equipped: fission reactor, " ..
        robo_count .. " roboport(s), " .. exo_count .. " exoskeleton(s). " ..
        bot_count .. " construction bots added to inventory."
    )
end


-- =============================================================================
-- MAIN ENTRY POINT
-- =============================================================================

-- Orchestrates all three feature groups in a sensible order:
--   1. Radar scan first so the map is revealed before the player moves
--   2. Inventory second so buildings are available immediately
--   3. Bots/armor last since it modifies the character's equipment state
--
-- Guards against edge cases where the event fires before the character exists
-- (can happen briefly in certain multiplayer scenarios).
local function give_fast_start(player)
    if not player then
        log("[fast-start-2] give_fast_start: player is nil, aborting")
        return false
    end
    if not player.valid then
        log("[fast-start-2] give_fast_start: player not valid, aborting")
        return false
    end
    if not player.character then
        -- on_player_created can fire before the character is spawned in Factorio 2.0.
        -- Returning false tells the caller not to mark this player as given yet,
        -- so on_player_joined_game can try again once the character exists.
        log("[fast-start-2] give_fast_start: player.character is nil, deferring")
        return false
    end

    log("[fast-start-2] give_fast_start: starting for player " .. player.name)
    do_radar_scan(player)
    do_inventory(player)
    do_bots(player)
    log("[fast-start-2] give_fast_start: complete for player " .. player.name)
    return true
end


-- =============================================================================
-- EVENT HANDLERS
-- =============================================================================
--
-- WHY TWO EVENTS?
--   on_player_created  — fires when a brand new player slot is created
--                        (singleplayer start, or first ever join in MP)
--   on_player_joined_game — fires every time any player connects, including
--                        returning players in multiplayer
--
--   We need both because on_player_created alone won't fire for a returning
--   multiplayer player, and on_player_joined_game alone won't fire in some
--   singleplayer edge cases.
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

local function on_player_init(event)
    -- Defensive init: on_init sets this up, but guard here too in case the mod
    -- is added to an existing save (on_init won't re-run in that case).
    storage.fast_start_given = storage.fast_start_given or {}

    local player = game.players[event.player_index]
    if not player then
        log("[fast-start-2] on_player_init: no player found for index " .. event.player_index)
        return
    end

    log("[fast-start-2] on_player_init: fired for " .. player.name .. " (index " .. event.player_index .. "), already_given=" .. tostring(storage.fast_start_given[event.player_index]))

    if not storage.fast_start_given[event.player_index] then
        local success = give_fast_start(player)
        -- Only mark as given if the kit was actually delivered. If the character
        -- wasn't ready yet (returns false), leave the flag unset so the next
        -- event firing (on_player_joined_game) can try again.
        if success then
            storage.fast_start_given[event.player_index] = true
        end
    end
end

script.on_event(defines.events.on_player_created,     on_player_init)
script.on_event(defines.events.on_player_joined_game, on_player_init)
-- on_player_spawned does not exist in Factorio 2.0. on_player_created and
-- on_player_joined_game both fire before the character exists due to the intro
-- cutscene. on_cutscene_cancelled fires when the cutscene ends, which is the
-- first moment player.character is guaranteed to be valid.
script.on_event(defines.events.on_cutscene_cancelled, on_player_init)

-- on_init runs exactly once when the mod is first loaded into a brand new save.
-- We initialise the storage table here so it's always valid when events fire.
script.on_init(function()
    storage.fast_start_given = {}
end)

-- on_configuration_changed fires when a mod is added to an existing save.
-- on_init does NOT run in this case, so we need to initialise storage here too
-- and then attempt to deliver the kit to all currently connected players.
-- The character may or may not exist at this point depending on game state,
-- but give_fast_start() will return false gracefully if it doesn't — the player
-- will then receive their kit on the next on_cutscene_cancelled or on_player_joined_game.
script.on_configuration_changed(function()
    storage.fast_start_given = storage.fast_start_given or {}

    for _, player in pairs(game.players) do
        if player.valid and not storage.fast_start_given[player.index] then
            log("[fast-start-2] on_configuration_changed: attempting kit delivery for " .. player.name)
            if give_fast_start(player) then
                storage.fast_start_given[player.index] = true
            else
                log("[fast-start-2] on_configuration_changed: character not ready for " .. player.name .. ", will retry on next join")
            end
        end
    end
end)
