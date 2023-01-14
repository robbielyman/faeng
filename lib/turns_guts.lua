-- Turns Engine lib
-- built for faeng

local Turns = {}

local controlspec = require "controlspec"

local function lin(min, max, default)
  return controlspec.new(min, max, "lin", 0, default)
end

local function exp(min, max, default)
  return controlspec.new(min, max, "exp", 0, default)
end

function Turns.init()
  local NUM_PARAMS = 54
  for i = 0, 6 do
    local suffix = "_" .. i
    params:add_group("turns_voice_" .. i, "TURNS " .. i, NUM_PARAMS)
    params:add{
      type  = "control",
      id    = "amp" .. suffix,
      name  = "amp",
      controlspec = lin(0, 1, 0.5),
      action = function (x)
        engine.set("amp", i, x)
        Turns.param_changed_callback("amp" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "square_amp" .. suffix,
      name  = "square",
      controlspec = lin(0, 1, 0.5),
      action = function (x)
        engine.set("square_amp", i, x)
        Turns.param_changed_callback("square_amp" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "formant_amp" .. suffix,
      name  = "formant",
      controlspec = lin(0, 1, 0.5),
      action = function (x)
        engine.set("formant_amp", i, x)
        Turns.param_changed_callback("formant_amp" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "lfo_amp_mod" .. suffix,
      name  = "lfo > amp",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("lfo_amp_mod", i, x)
        Turns.param_changed_callback("lfo_amp_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "pan" .. suffix,
      name  = "pan",
      controlspec = lin(-1, 1, 0),
      action = function (x)
        engine.set("pan", i, x)
        Turns.param_changed_callback("pan" .. suffix)
      end
    }
    params:add_separator("amp_env_" .. i, "amp env")
    params:add{
      type  = "control",
      id    = "amp_attack" .. suffix,
      name  = "attack",
      controlspec = lin(0, 2, 0.1),
      action = function (x)
        engine.set("amp_attack", i, x)
        Turns.param_changed_callback("amp_attack" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "amp_decay" .. suffix,
      name  = "decay",
      controlspec = lin(0, 4, 0.3),
      action = function (x)
        engine.set("amp_decay", i, x)
        Turns.param_changed_callback("amp_decay" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "amp_sustain" .. suffix,
      name  = "sustain",
      controlspec = lin(0, 1, 0.7),
      action = function (x)
        engine.set("amp_sustain", i, x)
        Turns.param_changed_callback("amp_sustain" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "amp_release" .. suffix,
      name  = "release",
      controlspec = lin(0, 3, 0.2),
      action = function (x)
        engine.set("amp_release", i, x)
        Turns.param_changed_callback("amp_release" .. suffix)
      end
    }
    params:add_separator("lfo_" .. i, "lfo")
    params:add{
      type  = "control",
      id    = "lfo_freq" .. suffix,
      name  = "lfo freq",
      controlspec = exp(0.01, 10, 1),
      action = function (x)
        engine.set("lfo_freq", i, x)
        Turns.param_changed_callback("lfo_freq" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "lfo_fade" .. suffix,
      name  = "fade in time",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("lfo_fade", i, x)
        Turns.param_changed_callback("lfo_fade" .. suffix)
      end
    }
    params:add_separator("mod_env_"..i, "mod env")
    params:add{
      type  = "control",
      id    = "mod_attack" .. suffix,
      name  = "attack",
      controlspec = lin(0, 2, 0.1),
      action = function (x)
        engine.set("mod_attack", i, x)
        Turns.param_changed_callback("mod_attack" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "mod_decay" .. suffix,
      name  = "decay",
      controlspec = lin(0, 4, 0.3),
      action = function (x)
        engine.set("mod_decay", i, x)
        Turns.param_changed_callback("mod_decay" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "mod_sustain" .. suffix,
      name  = "sustain",
      controlspec = lin(0, 1, 0.7),
      action = function (x)
        engine.set("mod_sustain", i, x)
        Turns.param_changed_callback("mod_sustain" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "mod_release" .. suffix,
      name  = "release",
      controlspec = lin(0, 3, 0.2),
      action = function (x)
        engine.set("mod_release", i, x)
        Turns.param_changed_callback("mod_release" .. suffix)
      end
    }
    params:add_separator("pitch_" .. i, "pitch")
    params:add{
      type  = "control",
      id    = "detune_square_octave" .. suffix,
      name  = "square: octave",
      controlspec = controlspec.new(-2, 2, "lin", 1, 0),
      action = function (x)
        local step = params:get("detune_square_steps" .. suffix)
        local cent = params:get("detune_square_cents" .. suffix) / 100
        x = 12 * x + step + cent
        engine.set("detune_square", i, x)
        Turns.param_changed_callback("detune_square_octave" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "detune_square_steps" .. suffix,
      name  = "square: steps",
      controlspec = controlspec.new(-12, 12,"lin", 1, 0),
      action = function (x)
        local oct = params:get("detune_square_octave" .. suffix) * 12
        local cent = params:get("detune_square_cents" .. suffix) / 100
        x = oct + x + cent
        engine.set("detune_square", i, x)
        Turns.param_changed_callback("detune_square_steps" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "detune_square_cents" .. suffix,
      name  = "square: cents",
      controlspec = lin(-100, 100, 0),
      action = function (x)
        local oct = params:get("detune_square_octave" .. suffix) * 12
        local step = params:get("detune_square_steps" .. suffix)
        x = oct + step + x / 100
        engine.set("detune_square", i, x)
        Turns.param_changed_callback("detune_square_cents" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "detune_formant_octave" .. suffix,
      name  = "formant: octave",
      controlspec = controlspec.new(-2, 2, "lin", 1, 0),
      action = function (x)
        local step = params:get("detune_formant_steps" .. suffix)
        local cent = params:get("detune_formant_cents" .. suffix) / 100
        x = 12 * x + step + cent
        engine.set("detune_formant", i, x)
        Turns.param_changed_callback("detune_formant_octave" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "detune_formant_steps" .. suffix,
      name  = "formant: steps",
      controlspec = controlspec.new(-12, 12,"lin", 1, 0),
      action = function (x)
        local oct = params:get("detune_formant_octave" .. suffix) * 12
        local cent = params:get("detune_formant_cents" .. suffix) / 100
        x = oct + x + cent
        engine.set("detune_formant", i, x)
        Turns.param_changed_callback("detune_formant_steps" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "detune_formant_cents" .. suffix,
      name  = "formant: cents",
      controlspec = lin(-100, 100, 0),
      action = function (x)
        local oct = params:get("detune_formant_octave" .. suffix) * 12
        local step = params:get("detune_formant_steps" .. suffix)
        x = oct + step + x / 100
        engine.set("detune_formant", i, x)
        Turns.param_changed_callback("detune_formant_cents" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "lfo_pitch_mod" .. suffix,
      name  = "lfo > pitch",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("lfo_pitch_mod", i, x)
        Turns.param_changed_callback("lfo_pitch_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "env_pitch_mod" .. suffix,
      name  = "env > pitch",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("env_pitch_mod", i, x)
        Turns.param_changed_callback("env_pitch_mod" .. suffix)
      end
    }
    params:add_separator("square" .. suffix, "square")
    params:add{
      type  = "control",
      id    = "width_square" .. suffix,
      name  = "width",
      controlspec = lin(0, 1, 0.5),
      action = function (x)
        engine.set("width_square", i, x)
        Turns.param_changed_callback("width_square" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "lfo_square_width_mod" .. suffix,
      name  = "lfo > width",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("lfo_square_width_mod", i, x)
        Turns.param_changed_callback("lfo_square_width_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "env_square_width_mod" .. suffix,
      name  = "env > width",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("env_square_width_mod", i, x)
        Turns.param_changed_callback("env_square_width_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "fm_numerator" .. suffix,
      name  = "fm numerator",
      controlspec = controlspec.new(1,50,"lin",1),
      action = function (x)
        engine.set("fm_numerator", i, x)
        Turns.param_changed_callback("fm_numerator" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "fm_denominator" .. suffix,
      name  = "fm denominator",
      controlspec = controlspec.new(1,50,"lin",1),
      action = function (x)
        engine.set("fm_denominator", i, x)
        Turns.param_changed_callback("fm_denominator" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "fm_index" .. suffix,
      name  = "fm index",
      controlspec = lin(0, 10, 0),
      action = function (x)
        engine.set("fm_index", i, x)
        Turns.param_changed_callback("fm_index" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "lfo_index_mod" .. suffix,
      name  = "lfo > index",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("lfo_index_mod", i, x)
        Turns.param_changed_callback("lfo_index_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "env_index_mod" .. suffix,
      name  = "env > index",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("env_index_mod", i, x)
        Turns.param_changed_callback("env_index_mod" .. suffix)
      end
    }
    params:add_separator("formant_sep" .. suffix, "formant")
    params:add{
      type  = "control",
      id    = "width_formant" .. suffix,
      name  = "width",
      controlspec = lin(0, 1, 0.5),
      action = function (x)
        engine.set("width_formant", i, x)
        Turns.param_changed_callback("width_formant" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "lfo_formant_width_mod" .. suffix,
      name  = "lfo > width",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("lfo_formant_width_mod", i, x)
        Turns.param_changed_callback("lfo_formant_width_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "env_formant_width_mod" .. suffix,
      name  = "env > width",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("env_formant_width_mod", i, x)
        Turns.param_changed_callback("env_formant_width_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "formant" .. suffix,
      name  = "formant",
      controlspec = lin(-5, 5, 0),
      action = function (x)
        engine.set("formant", i, x)
        Turns.param_changed_callback("formant" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "square_formant_mod" .. suffix,
      name  = "sq > formant",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("square_formant_mod", i, x)
        Turns.param_changed_callback("square_formant_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "lfo_formant_mod" .. suffix,
      name  = "lfo > formant",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("lfo_formant_mod", i, x)
        Turns.param_changed_callback("lfo_formant_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "env_formant_mod" .. suffix,
      name  = "env > formant",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("env_formant_mod", i, x)
        Turns.param_changed_callback("env_formant_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "square_formant_amp_mod" .. suffix,
      name  = "sq > amp",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("square_formant_amp_mod", i, x)
        Turns.param_changed_callback("square_formant_amp_mod" .. suffix)
      end
    }
    params:add_separator("filter" .. suffix, "filter")
    params:add{
      type  = "control",
      id    = "highpass_freq" .. suffix,
      name  = "highpass",
      controlspec = exp(10, 20000, 50),
      action = function (x)
        engine.set("highpass_freq", i, x)
        Turns.param_changed_callback("highpass_freq" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "lfo_highpass_mod" .. suffix,
      name  = "lfo > highpass",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("lfo_highpass_mod", i, x)
        Turns.param_changed_callback("lfo_highpass_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "env_highpass_mod" .. suffix,
      name  = "env > highpass",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("env_highpass_mod", i, x)
        Turns.param_changed_callback("env_highpass_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "highpass_resonance" .. suffix,
      name  = "hi res",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("highpass_resonance", i, x)
        Turns.param_changed_callback("highpass_resonance" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "lowpass_freq" .. suffix,
      name  = "lowpass",
      controlspec = exp(10, 20000, 15000),
      action = function (x)
        engine.set("lowpass_freq", i, x)
        Turns.param_changed_callback("lowpass_freq" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "lfo_lowpass_mod" .. suffix,
      name  = "lfo > lowpass",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("lfo_lowpass_mod", i, x)
        Turns.param_changed_callback("lfo_lowpass_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "env_lowpass_mod" .. suffix,
      name  = "env > lowpass",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("env_lowpass_mod", i, x)
        Turns.param_changed_callback("env_lowpass_mod" .. suffix)
      end
    }
    params:add{
      type  = "control",
      id    = "lowpass_resonance" .. suffix,
      name  = "lo res",
      controlspec = lin(0, 1, 0),
      action = function (x)
        engine.set("lowpass_resonance", i, x)
        Turns.param_changed_callback("lowpass_resonance" .. suffix)
      end
    }
  end
end

function Turns.amp_gate(voice, gate)
  engine.set("amp_gate", voice, gate)
  Turns.amp_gate_callback(voice, gate)
end

function Turns.note(voice, note)
  engine.set("note", voice, note)
  Turns.note_callback(voice, note)
end

function Turns.mod_gate(voice, gate)
  engine.set("mod_gate", voice, gate)
  Turns.mod_gate_callback(voice, gate)
end

function Turns.param_changed_callback(_) end
function Turns.amp_gate_callback(...) end
function Turns.mod_gate_callback(...) end
function Turns.note_callback(...) end

return Turns
