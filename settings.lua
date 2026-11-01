-- SE Fast Start: settings.lua
-- All player-configurable options via the in-game Mod Settings menu.
--
-- Settings are all runtime-global, meaning they apply to the whole save and
-- can be changed by the host mid-game (though they only affect new players
-- since the kit is only given once per player_index).
--
-- The "order" field controls sort order within the Mod Settings UI.
-- We use letter-prefixed strings (a-01, b-01, etc.) so groups stay together
-- and new entries can be inserted without renumbering everything.

-- ============================================================
-- FEATURE TOGGLES
-- ============================================================

data:extend({
    {
        type = "bool-setting",
        name = "sefs-enable-inventory",
        setting_type = "runtime-global",
        default_value = true,
        order = "a-01",
    },
    {
        type = "bool-setting",
        name = "sefs-enable-radar-scan",
        setting_type = "runtime-global",
        default_value = true,
        order = "a-02",
    },
    {
        type = "bool-setting",
        name = "sefs-enable-bots",
        setting_type = "runtime-global",
        default_value = true,
        order = "a-03",
    },

    -- ============================================================
    -- RADAR SCAN
    -- ============================================================

    {
        type = "int-setting",
        name = "sefs-radar-radius",
        setting_type = "runtime-global",
        default_value = 448,   -- default radar chunk diameter is 7 chunks (224 tiles), so 2x = 448
        minimum_value = 64,
        maximum_value = 2048,
        order = "b-01",
    },

    -- ============================================================
    -- BELTS & LOGISTICS
    -- ============================================================

    {
        type = "int-setting",
        name = "sefs-count-fast-belt",
        setting_type = "runtime-global",
        default_value = 500,
        minimum_value = 0,
        maximum_value = 2000,
        order = "c-01",
    },
    {
        type = "int-setting",
        name = "sefs-count-fast-underground",
        setting_type = "runtime-global",
        default_value = 80,
        minimum_value = 0,
        maximum_value = 500,
        order = "c-02",
    },
    {
        type = "int-setting",
        name = "sefs-count-fast-splitter",
        setting_type = "runtime-global",
        default_value = 40,
        minimum_value = 0,
        maximum_value = 200,
        order = "c-03",
    },

    -- ============================================================
    -- PIPES
    -- ============================================================

    {
        type = "int-setting",
        name = "sefs-count-pipe",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 0,
        maximum_value = 500,
        order = "c-10",
    },
    {
        type = "int-setting",
        name = "sefs-count-pipe-underground",
        setting_type = "runtime-global",
        default_value = 12,
        minimum_value = 0,
        maximum_value = 100,
        order = "c-11",
    },

    -- ============================================================
    -- POWER
    -- ============================================================

    {
        type = "int-setting",
        name = "sefs-count-medium-pole",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 0,
        maximum_value = 500,
        order = "d-01",
    },
    {
        type = "int-setting",
        name = "sefs-count-boiler",
        setting_type = "runtime-global",
        default_value = 4,
        minimum_value = 0,
        maximum_value = 50,
        order = "d-02",
    },
    {
        type = "int-setting",
        name = "sefs-count-steam-turbine",
        setting_type = "runtime-global",
        default_value = 8,
        minimum_value = 0,
        maximum_value = 100,
        order = "d-03",
    },
    {
        type = "int-setting",
        name = "sefs-count-offshore-pump",
        setting_type = "runtime-global",
        default_value = 2,
        minimum_value = 0,
        maximum_value = 20,
        order = "d-04",
    },

    -- ============================================================
    -- MINING & SMELTING
    -- ============================================================

    {
        type = "int-setting",
        name = "sefs-count-electric-miner",
        setting_type = "runtime-global",
        default_value = 30,
        minimum_value = 0,
        maximum_value = 200,
        order = "e-01",
    },
    {
        type = "int-setting",
        name = "sefs-count-stone-furnace",
        setting_type = "runtime-global",
        default_value = 30,
        minimum_value = 0,
        maximum_value = 200,
        order = "e-02",
    },

    -- ============================================================
    -- PRODUCTION
    -- ============================================================

    {
        type = "int-setting",
        name = "sefs-count-assembler",
        setting_type = "runtime-global",
        default_value = 12,
        minimum_value = 0,
        maximum_value = 200,
        order = "f-01",
    },
    {
        type = "int-setting",
        name = "sefs-count-fast-inserter",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 1000,
        order = "f-02",
    },
    {
        type = "int-setting",
        name = "sefs-count-lab",
        setting_type = "runtime-global",
        default_value = 8,
        minimum_value = 0,
        maximum_value = 50,
        order = "f-03",
    },

    -- ============================================================
    -- BOTS & ARMOR (quantities; feature toggle is above)
    -- ============================================================

    -- Armor tier choice exists because power-armor-mk2 has a much larger equipment
    -- grid (10x10 vs 7x7) and is needed to fit a fusion reactor + 2 roboports +
    -- 2 exoskeletons comfortably. However, in a vanilla game (no Space Exploration)
    -- mk2 is a very late-game research unlock, so forcing it on a vanilla player
    -- would be jarring. SE players should use mk2; vanilla players should use mk1.
    --
    -- We intentionally do NOT auto-detect SE here because checking for mod presence
    -- in the settings stage is fragile. Just let the player choose.
    {
        type = "string-setting",
        name = "sefs-armor-tier",
        setting_type = "runtime-global",
        default_value = "power-armor",
        allowed_values = { "power-armor", "power-armor-mk2" },
        order = "g-00",
    },
    {
        type = "int-setting",
        name = "sefs-count-construction-bot",
        setting_type = "runtime-global",
        default_value = 26,
        minimum_value = 0,
        maximum_value = 500,
        order = "g-01",
    },
    {
        type = "int-setting",
        name = "sefs-count-roboport",
        setting_type = "runtime-global",
        default_value = 1,
        minimum_value = 1,
        maximum_value = 4,
        order = "g-02",
    },
    {
        type = "int-setting",
        name = "sefs-count-exoskeleton",
        setting_type = "runtime-global",
        default_value = 1,
        minimum_value = 0,
        maximum_value = 4,
        order = "g-03",
    },
})
