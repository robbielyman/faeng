local MusicUtil = require('musicutil')

local DEFAULTS = {
  amt = {0, 0.125, 0.25, 0.5, 0.75, 0.875, 1.0}
}

local config = {
  engine = {
    name = "xD1",
    lua_file = "xD1/lib/engine_xD1",
    ui_file = "lib/xD1_ui"
  },
  page = {
    pages = {
      'trigger',
      'preset',
      'note',
      'octave',
      'ratchet',
      'velocity',
      'macro',
      'alt_note',
      'highpass',
      'lowpass',
    },
  },
  play_note = function(track)
    Playing[track.id] = 0
    if track.muted then return end
    if track:get('trigger') == 0 then return end
    local note = track:get('note') + track:get('alt_note')
    note = Scale(note) + 12 * (track:get('octave') - 3)
    local preset = (track.id - 1) * 7 + track:get('preset') - 1
    local velocity = DEFAULTS.velocities[track:get('velocity')]
    engine.noteOn(track.id, MusicUtil.note_num_to_freq(note), velocity, preset)
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
  macro = {
    data = 3,
    main = {
      min = 3,
      display = DEFAULTS.bar(3),
      key = DEFAULTS.handle_column,
    },
    action = function(track, name, datum, _)
      DEFAULTS.action(track, name, datum, _)
      Engine_UI.do_macro(track.id, DEFAULTS.amt[datum])
    end
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
