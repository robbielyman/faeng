local config = {
  -- advanced: try replacing this!
  engine = {
    name = "Timber",
    lua_file = norns.state.lib .. "timber_guts",
    ui_file = norns.state.lib .. "timber_ui"
  },
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
    division = 1,
    probability = 4,
    data = 1
  },
  play_note = function(track)
    if track.muted then return end
    if track:get('trigger') == 0 then return end
    local note = track:get('note') + track:get('alt_note')
    note = Scale(note) + 12 * (track:get('octave') - 3)
    local sample_id = (track.id - 1) * 7 + track.get('sample') - 1
    local velocity = DEFAULTS.velocities[track.get('velocity')]
    -- obviously this needs changing if you change engines
    if Timber.samples_meta[sample_id].num_frames > 0 then
      engine.noteOn(track.id, MusicUtil.note_num_to_freq(note), velocity, sample_id)
    end
  end,
  -- arc settings
  arc = {
    -- disable to use arcwise, for instance
    enabled = true,
    slew = {
      -- set to true to enable
      enabled = false,
      -- in seconds
      time = 1
    },
    -- should be a list of strings
    -- each string should be one of the engine's params
    -- without the final integer that indicates the sample number
    params = {
      -- okay this one and end_frame_ involve cheating on my part, sorry
      "start_frame_",
      "end_frame_",
      "filter_freq_",
      "pan_",
      "amp_",
      "amp_env_attack_",
      "amp_env_decay_",
      "amp_env_sustain_",
      "amp_env_release_",
      "mod_env_attack_",
      "mod_env_decay_",
      "mod_env_sustain_",
      "mod_env_release_",
    },
    -- should be a list of eight strings
    -- drawn from the above
    defaults = {
      "start_frame_",
      "end_frame_",
      "amp_",
      "filter_freq_",
      "mod_env_attack_",
      "mod_env_decay_",
      "mod_env_sustain_",
      "mod_env_release_"
    },
  },
  -- pattern recorder settings
  narcissus = {
    -- by default listens to everything in arc.params 
    -- as well as any listed here
    params = {},
    -- params listed here will be ignored
    ignore = {},
    -- quantization; also affects arc slew quantum if enabled
    sync_time = 1/48,
    -- receives a table of the form
    -- {
    --  id = sample id string
    --  prefix = param id as listed in, arc.params
    --  val = param value
    -- }
    -- and returns a table of the same kind (or nil)
    -- called before the pattern recorder processes the event
    preprocess = function(event) return event end
  },
  setup_hook = function() end,
  -- defines the triggers page
  trigger = {
    -- length = 6,
    -- division = 1,
    -- probability = 4,
    data = 0,
    main = {
      -- should return a list of arrays
      -- of the form {y,b},
      -- where y is the row to be lit and b is the brightness
      -- datum is the step in question's value
      -- check is true when the x coordinate is within the loop range
      -- current is true when the x coordinate is the current step
      display = function(datum, check, current)
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
    -- division = 1,
    -- probability = 4,
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
    -- division = 1,
    -- probability = 4,
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
    -- division = 1,
    -- probability = 4,
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
    -- division = 1,
    -- probability = 4,
    data = 4,
    -- subsequins_overlay = false
    -- a bit of trickery to allow ratchets to count faster than their division
    counter = 12,
    main = {
      min = 3,
      -- max = 7,
      display = function(datum, check, current)
        local ratchet_amount = datum & 3
        local ratchets = datum >> 2
        local lights = {}
        local j
        if current then
          -- breaking the API slightly...
          local out_of_twelve = (Tracks[Active_Track].counter - 1) % 12 + 1
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
    action = function(track, name, datum)
      track.set(name, datum)
      local ratchet_div = 12 / ((datum & 3) + 1)
      local ratchets = datum >> 2
      local out_of_twelve = (track.counter - 1) % 12 + 1
      if track.counter % ratchet_div == 1 then
        local step = 2 ^ ((out_of_twelve - 1) / ratchet_div)
        if step & ratchets == step then Play_Note(track) end
      end
    end,
  },
  -- defines the velocity page
  velocity = {
    -- length = 6,
    -- division = 1,
    -- probability = 4,
    data = 5,
    -- subsequins_overlay = false
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
    -- division = 1,
    -- probability = 4,
    data = 1,
    -- subsequins_overlay = false
    main = {
      -- min = 1,
      -- max = 7
      display = DEFAULTS.indicator,
      key = DEFAULTS.handle_column,
    },
    -- subsequins = {},
    action = function(track, name, datum)
      DEFAULTS.action(track, name, datum)
      for j = (track.id - 1) * 7, (track.id - 1) * 7 + 6 do
        Timber.set_marker(j, "start_frame_", datum, true)
        Timber.set_marker(j, "end_frame_", datum, true)
      end
    end,
  },
  alt_note = {
    -- length = 6,
    -- division = 1,
    -- probability = 4,
    data = 1,
    -- subsequins_overlay = false
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
    -- division = 1,
    -- probability = 4,
    data = 3,
    -- subsequins_overlay = false
    main = {
      min = 3,
      -- max = 7,
      display = DEFAULTS.bar(3),
      key = DEFAULTS.handle_column,
    },
    -- subsequins = {},
    action = function(track, name, datum)
      DFEAULTS.action(track, name, datum)
      for j = (track.id - 1) * 7, (track.id - 1) * 7 + 6 do
        engine.filterFreq(j, DEFAULTS.freqs[datum] * params:get("filter_freq_" .. j))
      end
    end,
  },
  pan = {
    -- length = 6,
    -- division = 1,
    -- probability = 4,
    data = 4,
    -- subsequins_overlay = false
    main = {
      -- min = 1,
      -- max = 7,
      display = DEFAULTS.bar(4),
      key = DEFAULTS.handle_column,
    },
    -- subsequins = {}
    action = function(track, name, datum)
      DEFAULTS.action(track, name, datum)
      for j = (track.id - 1) * 7, (track.id - 1) * 7 + 6 do
        engine.pan(j, DEFAULTS.pans[datum] + params:get("pan_" .. j))
      end
    end
  },
  DEFAULTS = {
    -- draws an indicator at current value
    indicator = function(datum, check, current)
      if current then
        return {{8 - datum, 15}}
      else
        return {{8 - datum, check and 9 or 4}}
      end
    end,
    -- draws a bar that extends above or below a center value
    bar = function(center)
      return function(datum, check, current)
        local lights = DEFAULTS.indicator(datum, check, current)
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
    action = function(track, name, datum) track:set(name, datum) end,
    -- default mappings for values
    velocities = {0.1, 0.2, 0.3, 0.6, 1.0, 1.2},
    freqs = {0.25, 0.5, 1.0, 1.5, 2.0},
    pans = {-1, -0.5, -0.25, 0, 0.25, 0.5, 1}
  }
}
return config
