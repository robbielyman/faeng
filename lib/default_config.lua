local MusicUtil = require "musicutil"

local function indicator(datum, check, current, _)
  if current then
    return {{8 - datum, 15}}
  else
    return {{8 - datum, check and 9 or 4}}
  end
end

DEFAULTS = {
  -- draws an indicator at current value
  indicator = indicator,
  -- draws a bar that extends above or below a center value
  bar = function(center)
    return function(datum, check, current, _)
      local lights = indicator(datum, check, current, _)
      if datum > center then
        for i = center, datum - 1 do
          table.insert(lights, {8 - i, check and 9 or 4})
        end
      elseif datum < center then
        for i = center - 1, datum + 1, -1 do
          table.insert(lights, {8 - i, check and 9 or 4})
        end
      end
      return lights
    end
  end,
  -- registers a press 
  -- and returns a new data value
  handle_column = function(y, _) return 8 - y end,
  -- registers a press
  -- and flips state between 0 and 1
  handle_column_trig = function(_, current) return current == 1 and 0 or 1 end,
  -- default action for a track.
  -- arguments are track, name, datum and counter
  -- for counter usage, see ratchet
  action = function(track, name, datum, _) track:set(name, datum) end,
  -- default mappings for values
  velocities = {0.1, 0.2, 0.3, 0.6, 1.0, 1.2},
  freqs = {0.25, 0.5, 1.0, 1.5, 2.0},
  pans = {-1, -0.5, -0.25, 0, 0.25, 0.5, 1},
  -- should be a list of params
  -- with the final "_0" stripped
  -- if the param has subparams, see start_frame
  arc_params = {
    {"filter_freq", default = 4},
    "filter_resonance",
    "pan",
    {"amp", default = 3},
    {"amp_env_attack", default = 5},
    {"amp_env_decay", default = 6},
    {"amp_env_sustain", default = 7},
    {"amp_env_release", default = 8},
    "mod_env_attack",
    "mod_env_decay",
    "mod_env_sustain",
    "mod_env_release",
    {
      "start_frame",
      -- indicates that there is one param per id_minor
      -- for a total of 49
      -- defaults to true
      id_minor = true,
      -- indicates further subparams if defined
      subparams = 6,
      -- should editing one ring affect all sharing the same track?
      -- defaults to true
      macro_edit = false,
      default = 1,
    },
    {
      "end_frame",
      id_minor = true,
      subparams = 6,
      macro_edit = false,
      default = 2,
    },
  },
}

local config = {
  -- allows you to build on another config file
  -- we'll set it to nil in this default file
  -- NB: if *that* file defines extends, it will be ignored
  extends = nil,
  -- advanced: try replacing this!
  engine = {
    name = "Timber",
    lua_file = "lib/timber_guts",
    ui_file = "lib/default_ui"
  },
  -- it's possible to define your own modules
  -- if you're interested in writing a module
  -- that has access to the screen, let's chat :)
  -- access to the grid is modeled by the narcissus module
  modules = {
    -- each module should be a table with two keys:
    -- a boolean 'enabled', and an 'args'
    -- modules should be stored in 'data/faeng'
    -- (or 'code/faeng/lib' if you want to PR)
    -- so 'arc_guts' points to a file 'code/faeng/lib/arc_guts.lua'
    -- that gets included by faeng
    -- like all modules,
    -- arc_guts provides a function arc_guts.init
    -- that gets called with args as its argument.
    arc_guts = {
      -- arc integration is enabled by default
      enabled = true,
      args = {
        -- be sure to change these if you change engines!
        params = DEFAULTS.arc_params,
        rings = 4,
        alt_rings = true,
        slew = {
          enabled = true,
          time = 1
        },
      },
    },
    -- clocked pattern recorder per track
    narcissus = {
      -- enabled by default
      enabled = true,
      args = {
        -- defaults to listening to the same params as arc can control
        params = DEFAULTS.arc_params,
        quantization = 1/48,
      },
    },
    -- adds more output options
    outputs = {
      -- disabled by default
      enabled = false,
      args = {
        outputs = {"audio", "midi", "audio + midi", "crow out 1+2", "crow ii jf", "crow ii er301"}
      },
    },
  },
  -- are there 7 voices or 49? you decide
  use_id_minor = true,
  -- should be a list of ten strings
  page = {
    pages = {
      'trigger',
      'sample',
      'note',
      'octave',
      'ratchet',
      'velocity',
      'slice',
      'alt_note',
      'filter',
      'pan',
    },
    -- all of these are overridden by
    -- corresponding settings
    -- in a given page's table
    length = 6,
    division = {1, 16},
    probability = 4,
    data = 1,
    swing = 8,
    priority = 3,
  },
  play_note = function(track)
    Playing[track.id] = 0
    if track.muted then return end
    if track:get('trigger') == 0 then return end
    local note = track:get('note') + track:get('alt_note')
    note = Scale(note) + 12 * (track:get('octave') - 3)
    local sample_id = (track.id - 1) * 7 + track:get('sample') - 1
    local velocity = DEFAULTS.velocities[track:get('velocity')]
    -- obviously this needs changing if you change engines
    if Engine.samples_meta[sample_id].num_frames > 0 then
      engine.noteOn(track.id, MusicUtil.note_num_to_freq(note), velocity, sample_id)
      Playing[track.id] = 1
    end
  end,
  -- use to manage the engine's lua and ui files
  -- which are included as Engine and Engine_UI.
  setup = function()
    Engine.add_params()
    for i = 0, TRACKS * 7 - 1 do
      Engine.add_sample_params(i)
    end
    Engine_UI.init()
  end,
  -- defines the triggers page
  trigger = {
    -- length = 6,
    -- division = {1, 16},
    -- probability = 4,
    -- swing = 8,
    -- priority = 3
    data = 0,
    main = {
      -- should return a list of pairs
      -- of the form {y,b},
      -- where y is the row to be lit and b is the brightness
      -- datum is the step in question's value
      -- check is true when the x coordinate is within the loop range
      -- current is true when the x coordinate is the current step
      -- the final argument is counter; see ratchet for example of use
      display = function(datum, check, current, _)
        if current then
          return {{2, 15}}
        elseif datum == 1 then
          return {{2, check and 9 or 4}}
        else
          return {{2, check and 2 or 0}}
        end
      end,
      -- min row to register grid press
      min = 2,
      -- max row to register grid press (clipped to 7)
      max = 2,
      -- should return a number or nil
      -- corresponding to setting a new data point
      key = DEFAULTS.handle_column_trig
    },
    subsequins = {
      -- displays both triggers and subsequins
      -- at once if SubSequins is active
      overlay = true,
      -- min row to register grid press
      min = 6,
      -- max row to register grid press
      max = 6,
      -- defaults to main.display
      display = function(datum)
        return {{6, datum == 1 and 9 or 2}}
      end
    },
    action = DEFAULTS.action,
  },
  -- defines the sample page
  sample = {
    -- length = 6,
    -- division = {1, 16},
    -- probability = 4,
    -- swing = 8,
    -- priority = 3
    data = 1,
    main = {
      -- min = 1,
      -- max = 7,
      display = DEFAULTS.indicator,
      key = DEFAULTS.handle_column,
    },
    -- subsequins = {},
    action = DEFAULTS.action,
  },
  -- defines the note page
  note = {
    -- length = 6,
    -- division = {1, 16},
    -- probability = 4,
    -- swing = 8,
    -- priority = 3
    data = 1,
    main = {
      -- min = 1,
      -- max = 7,
      display = DEFAULTS.indicator,
      key = DEFAULTS.handle_column,
    },
    -- subsequins = {},
    action = DEFAULTS.action,
  },
  octave = {
    -- length = 6,
    -- division = {1, 16},
    -- probability = 4,
    -- swing = 8,
    -- priority = 3
    data = 3,
    main = {
      min = 3,
      -- max = 7,
      display = DEFAULTS.bar(3),
      key = DEFAULTS.handle_column,
    },
    -- subsequins = {},
    action = DEFAULTS.action,
  },
  -- defines the ratchet page
  ratchet = {
    -- length = 6,
    -- division = {1, 16},
    -- probability = 4,
    -- swing = 8,
    priority = 5,
    data = 4,
    -- a bit of trickery to allow ratchets to count faster than their division
    counter = 12,
    main = {
      min = 3,
      -- max = 7,
      display = function(datum, check, current, counter)
        local ratchet_amount = datum & 3
        local ratchets = datum >> 2
        local lights = {}
        local j
        if current then
          local out_of_twelve = (counter - 1) % 12 + 1
          j = out_of_twelve // (12 / (ratchet_amount + 1))
        end
        for i = 0, ratchet_amount do
          if ratchets & 2^i == 2^i then
            if i == j then
              table.insert(lights, {7-i, 15})
            else
              table.insert(lights, {7-i, check and 9 or 4})
            end
          end
        end
        return lights
      end,
      key = function(y, current)
        local ratchet_amount = current & 3
        local ratchets = current >> 2
        if 7 - y > ratchet_amount then
          -- add new bits
          for i = ratchet_amount + 1, 7 - y do
            ratchets = ratchets ~ 2^i
          end
          ratchet_amount = 7 - y
        else
          -- toggle pressed key
          ratchets = ratchets ~ 2^(7-y)
        end
        if ratchets == 0 then
          -- reset
          ratchets = 1
          ratchet_amount = 0
        end
        return (ratchets << 2) | ratchet_amount
      end,
    },
    -- subsequins = {},
    action = function(track, name, datum, counter)
      track:set(name, datum)
      local ratchet_div = 12 / ((datum & 3) + 1)
      local ratchets = datum >> 2
      local out_of_twelve = (counter - 1) % 12 + 1
      if counter % ratchet_div == 1 then
        local step = 2 ^ ((out_of_twelve - 1) / ratchet_div)
        -- Play_Note is an alias for config.play_note
        if step & ratchets == step then Play_Note(track) end
      end
    end,
  },
  -- defines the velocity page
  velocity = {
    -- length = 6,
    -- division = {1, 16},
    -- probability = 4,
    -- swing = 8,
    -- priority = 3
    data = 5,
    main = {
      min = 2,
      -- max = 7,
      display = DEFAULTS.bar(5),
      key = DEFAULTS.handle_column,
    },
    -- subsequins = {},
    action = DEFAULTS.action,
  },
  slice = {
    -- length = 6,
    -- division = {1, 16},
    -- probability = 4,
    -- swing = 8,
    -- priority = 3
    data = 1,
    main = {
      -- min = 1,
      -- max = 7
      display = DEFAULTS.indicator,
      key = DEFAULTS.handle_column,
    },
    -- subsequins = {},
    action = function(track, name, datum, _)
      DEFAULTS.action(track, name, datum, _)
      for j = (track.id - 1) * 7, (track.id - 1) * 7 + 6 do
        Engine.set_marker(j, "start_frame_", datum, true)
        Engine.set_marker(j, "end_frame_", datum, true)
      end
    end,
  },
  alt_note = {
    -- length = 6,
    -- division = {1, 16},
    -- probability = 4,
    -- swing = 8,
    -- priority = 3
    data = 1,
    main = {
      -- min = 1,
      -- max = 7,
      display = DEFAULTS.indicator,
      key = DEFAULTS.handle_column,
    },
    -- subsequins = {},
    action = DEFAULTS.action,
  },
  filter = {
    -- length = 6,
    -- division = {1, 16},
    -- probability = 4,
    -- swing = 8,
    -- priority = 3
    data = 3,
    main = {
      min = 3,
      -- max = 7,
      display = DEFAULTS.bar(3),
      key = DEFAULTS.handle_column,
    },
    -- subsequins = {},
    action = function(track, name, datum, _)
      DEFAULTS.action(track, name, datum, _)
      for j = (track.id - 1) * 7, (track.id - 1) * 7 + 6 do
        engine.filterFreq(j, DEFAULTS.freqs[datum] * params:get("filter_freq_" .. j))
      end
    end,
  },
  pan = {
    -- length = 6,
    -- division = {1, 16},
    -- probability = 4,
    -- swing = 8,
    -- priority = 3
    data = 4,
    main = {
      -- min = 1,
      -- max = 7,
      display = DEFAULTS.bar(4),
      key = DEFAULTS.handle_column,
    },
    -- subsequins = {}
    action = function(track, name, datum, _)
      DEFAULTS.action(track, name, datum, _)
      for j = (track.id - 1) * 7, (track.id - 1) * 7 + 6 do
        engine.pan(j, DEFAULTS.pans[datum] + params:get("pan_" .. j))
      end
    end
  },
}
return config, DEFAULTS
