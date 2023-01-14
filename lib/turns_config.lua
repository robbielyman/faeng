local _, DEFAULTS = dofile(norns.state.lib .. 'default_config.lua')

DEFAULTS.pans = {-1, -0.75, -0.5, 0, 0.5, 0.75, 1}
DEFAULTS.filter = {-1, -0.5, 0, 0.5, 1}

local extensions = "/home/we/.local/share/SuperCollider/Extensions/"
Needs_Restart = util.file_exists(extensions .. "PulsePTR/PulsePTR.sc") and util.file_exists(extensions .. "FormantTriPTR/FormantTriPTR.sc")

local config = {
  engine = {
    name = Needs_Restart and "None" or "Turns",
    lua_file = "lib/turns_guts",
    ui_file = "lib/turns_ui"
  },
  page = {
    pages = {
      'amp_gate',
      'note',
      'octave',
      'lowpass',
      'mod_gate',
      'accidental',
      'alt_note',
      'pan',
      'highpass',
      'amp'
    },
  },
  modules = {},
  play_note = function (track)
    if track.muted then return end
    local note = track:get('note') + track:get('alt_note') - 1
    note = Scale(note) + 12 * (track:get('octave') - 3)
    note = note + DEFAULTS.accidental[track:get('accidental')]
    engine.note(track.id, note)
  end,
  setup = function ()
    if Needs_Restart then
      util.os_capture("mkdir -p /home/we/.local/share/SuperCollider/Extensions/PulsePTR")
      util.os_capture("mkdir -p /home/we/.local/share/SuperCollider/Extensions/FormantTriPTR")
      for _, ugen in ipairs({"PulsePTR", "FormantTriPTR"}) do
        util.os_capture("cp " .. norns.state.lib .. "ignore/" .. ugen .. "/" .. ugen .. "_scsynth.so " .. extensions .. ugen .. "/" .. ugen .. "_scsynth.so")
        util.os_capture("cp " .. norns.state.lib .. "ignore/" .. ugen .. "/" .. ugen .. ".sc " .. extensions .. ugen .. "/" .. ugen .. ".sc")
      end
      Engine_UI.init()
      return
    end
    Engine.init()
    Engine_UI.init()
  end,
  amp_gate = {
    data = 0,
    main = {
      display = function (datum, check, current, _)
        if current then
          return {{2, 15}}
        elseif datum == 1 then
          return {{2, check and 9 or 4}}
        else
          return {{2, check and 2 or 0}}
        end
      end,
      min = 2,
      max = 2,
      key = DEFAULTS.handle_column_trig
    },
    subsequins = {
      overlay = true,
      min = 6,
      max = 6,
      display = function (datum)
        return {{6, datum == 1 and 9 or 2}}
      end
    },
    action = function (track, name, datum, _)
      DEFAULTS.action(track, name, datum, _)
      engine.set("amp_gate", track.id, datum)
    end
  },
  note = {
    data = 1,
    main = {
      display = DEFAULTS.indicator,
      key = DEFAULTS.handle_column,
    },
    action = function (track, name, datum, _)
      local old = track:get('note')
      DEFAULTS.action(track, name, datum, _)
      if datum ~= old then
        Play_Note(track)
      end
    end
  },
  octave = {
    data = 3,
    main = {
      min = 3,
      display = DEFAULTS.bar(3),
      key = DEFAULTS.handle_column,
    },
    action = function (track, name, datum, _)
      local old = track:get('octave')
      DEFAULTS.action(track, name, datum, _)
      if datum ~= old then
        Play_Note(track)
      end
    end
  },
  lowpass = {
    data = 3,
    main = {
      min = 3,
      display = DEFAULTS.bar(3),
      key = DEFAULTS.handle_column,
    },
    action = function (track, name, datum, _)
      DEFAULTS.action(track, name, datum, _)
      local freq = 2^DEFAULTS.filter[datum] * params:get("lowpass_freq_" .. track.id)
      engine.set("lowpass_freq", track.id, freq)
    end
  },
  mod_gate = {
    data = 0,
    main = {
      display = function (datum, check, current, _)
        if current then
          return {{2, 15}}
        elseif datum == 1 then
          return {{2, check and 9 or 4}}
        else
          return {{2, check and 2 or 0}}
        end
      end,
      min = 2,
      max = 2,
      key = DEFAULTS.handle_column_trig
    },
    subsequins = {
      overlay = true,
      min = 6,
      max = 6,
      display = function (datum)
        return {{6, datum == 1 and 9 or 2}}
      end
    },
    action = function (track, name, datum, _)
      DEFAULTS.action(track, name, datum, _)
      engine.set("mod_gate", track.id, datum)
    end
  },
  accidental = {
    data = 4,
    main = {
      display = DEFAULTS.bar(4),
      key = DEFAULTS.handle_column,
    },
    action = function (track, name, datum, _)
      local old = track:get('accidental')
      DEFAULTS.action(track, name, datum, _)
      if datum ~= old then
        Play_Note(track)
      end
    end
  },
  alt_note = {
    data = 1,
    main = {
      display = DEFAULTS.indicator,
      key = DEFAULTS.handle_column,
    },
    action = function (track, name, datum, _)
      local old = track:get('alt_note')
      DEFAULTS.action(track, name, datum, _)
      if datum ~= old then
        Play_Note(track)
      end
    end
  },
  pan = {
    data = 4,
    main = {
      display = DEFAULTS.bar(4),
      key = DEFAULTS.handle_column,
    },
    action = function (track, name, datum, _)
      DEFAULTS.action(track, name, datum, _)
      local pan = DEFAULTS.pans[datum] + params:get("pan_" .. track.id)
      engine.set("pan", track.id, util.clamp(pan, -1, 1))
    end
  },
  highpass = {
    data = 3,
    main = {
      min = 3,
      display = DEFAULTS.bar(3),
      key = DEFAULTS.handle_column,
    },
    action = function (track, name, datum, _)
      DEFAULTS.action(track, name, datum, _)
      local freq = 2^DEFAULTS.filter[datum] * params:get("highpass_freq_" .. track.id)
      engine.set("highpass_freq", track.id, freq)
    end
  },
  amp = {
    data = 3,
    main = {
      min = 3,
      display = DEFAULTS.bar(3),
      key = DEFAULTS.handle_column,
    },
    action = function (track, name, datum, _)
      DEFAULTS.action(track, name, datum, _)
      local amp = 2^DEFAULTS.filter[datum] * params:get("amp_" .. track.id)
      engine.set("amp", track.id, amp)
    end
  },
}

return config, DEFAULTS
