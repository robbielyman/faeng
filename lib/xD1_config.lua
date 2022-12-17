local MusicUtil = require('musicutil')

local _, DEFAULTS = dofile(norns.state.lib .. 'default_config.lua')
DEFAULTS.amt = {0, 0.125, 0.25, 0.5, 0.75, 0.875, 1.0}
DEFAULTS.lengths = {1/16, 1/8, 3/16, 1/4, 3/8, 1/2, 3/4}
DEFAULTS.params = {
  {
    "oatk",
    subparams = 6,
    default = 1,
  },
  {
    "odec",
    subparams = 6,
    default = 2,
  },
  {
    "osus",
    subparams = 6,
    default = 3,
  },
  {
    "orel",
    subparams = 6,
    default = 4,
  },
  {
    "oamp",
    subparams = 6,
    default = 5,
  },
  { "lorat", default = 6 },
  "lores",
  { "lfamt", default = 8 },
  "hirat",
  "hires",
  "hfamt",
  "fatk",
  "fdec",
  "fsus",
  "frel",
  "ocurve",
  "fcurve",
  { "feedback", default = 7 },
  "alg"
}
DEFAULTS.schedule_note_off = function (note, preset, sync_time)
  if not Notes_Off_Counter then
    Notes_Off_Counter = {}
  end
  if not Notes_Off_Counter[preset] then
    Notes_Off_Counter[preset] = {}
  end
  if Notes_Off_Counter[preset][note] then
    clock.cancel(Notes_Off_Counter[preset][note])
  end
  Notes_Off_Counter[preset][note] = clock.run(function ()
    clock.sync(sync_time)
    engine.note_off(note, preset)
  end)
end

local config = {
  engine = {
    name = "xD1",
    lua_file = "xD1/lib/xD1_engine",
    ui_file = "lib/xD1_ui"
  },
  page = {
    pages = {
      'trigger',
      'note',
      'length',
      'octave',
      'ratchet',
      'velocity',
      'alt_note',
      'preset',
      'highpass',
      'lowpass',
    },
  },
  modules = {
    arc_guts = {
      enabled = true,
      args = {
        params = DEFAULTS.params
      }
    },
    narcissus = {
      enabled = true,
      args = {
        params = DEFAULTS.params
      }
    }
  },
  play_note = function(track)
    Playing[track.id] = 0
    if track.muted then return end
    if track:get('trigger') == 0 then return end
    local note = track:get('note') + track:get('alt_note')
    note = Scale(note) + 12 * (track:get('octave') - 3)
    local preset = (track.id - 1) * 7 + track:get('preset') - 1
    local velocity = DEFAULTS.velocities[track:get('velocity')]
    engine.note_on(note, velocity, preset)
    DEFAULTS.schedule_note_off(note, preset, DEFAULTS.lengths[track:get('length')])
    Playing[track.id] = 1
  end,
  setup = function()
    Engine.init(false, 7 * 7)
    Engine_UI.init()
  end,
  preset = {
    data = 1,
    main = {
      display = DEFAULTS.indicator,
      key = DEFAULTS.handle_column,
    },
    action = DEFAULTS.action,
  },
  length = {
    data = 2,
    main = {
      display = DEFAULTS.indicator,
      key = DEFAULTS.handle_column,
    },
    action = DEFAULTS.action
  },
  highpass = {
    data = 3,
    main = {
      min = 3,
      display = DEFAULTS.bar(3),
      key = DEFAULTS.handle_column,
    },
    action = function(track, name, datum, _)
      DEFAULTS.action(track, name, datum, _)
      local mult = DEFAULTS.freqs[datum]
      for i = 0, 6 do
        local preset = (track.id - 1) * 7 + i
        local val = params:get('hirat_' .. preset)
        engine.set('hirat', preset, val * mult)
      end
    end
  },
  lowpass = {
    data = 3,
    main = {
      display = DEFAULTS.bar(3),
      key = DEFAULTS.handle_column,
    },
    action = function(track, name, datum, _)
      DEFAULTS.action(track, name, datum, _)
      local mult = DEFAULTS.freqs[datum]
      for i = 0, 6 do
        local preset = (track.id - 1) * 7 + i
        local val = params:get('lorat_' .. preset)
        engine.set('lorat', preset, val * mult)
      end
    end
  }
}
return config, DEFAULTS
