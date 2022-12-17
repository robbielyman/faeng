local M = {}
local midi_device

local defaults = {"audio", "midi", "audio + midi", "crow out 1+2", "crow ii jf", "crowii er301"}

local function norns_assert(cond, msg)
  if not msg then msg = "" end
  if cond then return end
  norns.scripterror(msg)
end

function M.init(args)
  norns_assert(type(args.outputs) == "table", 'config error: outputs.args.outputs must be list')
  local flag
  for _, output in ipairs(args.outputs) do
    local found
    for _, str in ipairs(defaults) do
      if output == str then
        found = true
        if str == "midi" or str == "audio + midi" then
          flag = true
        end
        break
      end
    end
    norns_assert(found, 'config error: ' .. output .. ' in outputs.args.outputs not understood')
  end
  if flag then
    local midi_devices = {}
    midi_device = midi.connect(1)
    for i = 1, #midi.vports do
      local long_name = midi.vports[i].name
      local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
      table.insert(midi_devices, i .. ": " .. short_name)
    end
    params:add{
      type    = "option",
      id      = "midi_device",
      name    = "midi out device",
      options = midi_devices,
      default = 1,
      action  = function (value)
        midi_device = midi.connect(value)
      end
    }
  end
  for i = 1, 7 do
    params:add{
      type    = "option",
      id      = "output_" .. i,
      name    = "track output " .. i,
      options = args.outputs,
      default = 1,
      action  = function (value)
        local str = args.outputs[value]
        if str == "crow out 1+2" then
          crow.output[2].action = "{to(5,0),to(0,0.25)}"
        elseif str == "crow ii jf" then
          crow.ii.pullup(true)
          crow.ii.jf.mode(1)
        elseif str == "crow ii er301" then
          crow.ii.pullup(true)
        end
      end
    }
  end
  local play_note = Play_Note
  Play_Note = function (track)
    local mode = args.outputs[params:get("output_" .. track.id)]
    if mode == "audio" or mode == "audio + midi" then
      play_note(track)
    end
    local sync_time = 1/4
    if args.provides_length then
      sync_time = DEFAULTS.lengths[track:get('length')]
    end
    Playing[track.id] = 0
    if track.muted then return end
    if track:get('trigger') == 0 then return end
    local note = track:get('note') + track:get('alt_note')
    note = Scale(note) + 12 * (track:get('octave') - 3)
    if mode == "midi" or mode == "audio + midi" then
      local channel = track.id_minor + 1
      local velocity = DEFAULTS.velocities[track:get('velocity')]
      velocity = util.linlin(0, 1, 0, 127, velocity)
      velocity = util.clamp(velocity, 0, 127)
      if not midi_device then return end
      midi_device:note_on(note, velocity, channel)
      Playing[track.id] = 1
      clock.run(function ()
        clock.sync(sync_time)
        midi_device:note_off(note, nil, channel)
        Playing[track.id] = 0
      end)
    elseif mode == "crow out 1+2" then
      crow.output[1].volts = (note - 60) / 12
      crow.output[2].execute()
      Playing[track.id] = 1
    elseif mode == "crow ii jf" then
      crow.ii.jf.play_note((note - 60) / 12, 5)
      Playing[track.id] = 1
    elseif mode == "crow ii er301" then
      crow.ii.er301.cv(1, (note - 60) / 12)
      crow.ii.er301.tr_pulse(1)
      Playing[track.id] = 1
    end
  end
end

return M
