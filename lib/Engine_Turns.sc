// 7-voice formant monosynth for faeng

// this is a CroneEngine
Engine_Turns : CroneEngine {
  var endOfChain,
  outBus,
  tVoices;

  *new {
    arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    outBus = Bus.audio(numChannels:2);
    SynthDef("ColorLimiter", { arg input;
      Out.ar(context.out_b, In.ar(input, 2).tanh);
    }).add;
    
    Server.default.sync;
    endOfChain = Synth.new("ColorLimiter", [\input, outBus]);
    NodeWatcher.register(endOfChain);
    
    SynthDef("Turns", {
      var ampgate = \amp_gate.kr(0);
      var env = Env.adsr(\amp_attack.kr(0.1), \amp_decay.kr(0.3), \amp_sustain.kr(0.7), \amp_release.kr(0.2)).kr(0, ampgate);
      var modenv = Env.adsr(\mod_attack.kr(0.1), \mod_decay.kr(0.3), \mod_sustain.kr(0.7), \mod_release.kr(0.2)).kr(0, \mod_gate.kr(0));
      var lfo = LFTri.kr(\lfo_freq.kr(1), mul:Env.asr(\lfo_fade.kr(0), 1, 10).kr(0, ampgate));
      var amp_lfo = lfo.madd(0.05, 0.05) * \lfo_amp_mod.kr(0);
      var note = \note.kr(69);
      var pitch_mod = (1.2 * \lfo_pitch_mod.kr(0) * lfo) + (1.2 * modenv * \env_pitch_mod.kr(0));
      var pitch_sq = (note + \detune_square.kr(0) + pitch_mod).midicps;
      var width_sq = \width_square.kr(0.5) + (0.5 * \lfo_square_width_mod.kr(0) * lfo) + (\env_square_width_mod.kr(0) * modenv);
      var index = \fm_index.kr(0) + (2 * \env_index_mod.kr(0) * modenv) + (20 * \lfo_index_mod.kr(0) * amp_lfo);
      var sq = PulsePTR.ar(freq:pitch_sq, width:width_sq, phase:SinOsc.ar(pitch_sq * \fm_numerator.kr(1) / \fm_denominator.kr(1), mul:index));
      var pitch_form = (note + \detune_formant.kr(0) + pitch_mod).midicps;
      var width_form = \width_formant.kr(0.5) + (0.5 * \lfo_formant_width_mod.kr(0) * lfo) + (\env_formant_width_mod.kr(0) * modenv);
      var form_form = pitch_form * ((2 ** \formant.kr(0)) + (sq * \square_formant_mod.kr(0)) + (lfo * \lfo_formant_mod.kr(0)) + (modenv * \env_formant_mod.kr(0)));
      var form = SineShaper.ar(FormantTriPTR.ar(pitch_form, form_form, width_form) * (\formant_amp.kr(0.5) + (sq * \square_formant_amp_mod.kr(0))), 0.5, 2);
      var snd = (env + amp_lfo) * (form + (\square_amp.kr(0.5) * sq));
      var hifreq = (2 ** (modenv * 5 * \env_highpass_mod.kr(0)) + (lfo * \lfo_highpass_mod.kr(0))) * \highpass_freq.kr(50);
      var lofreq = (2 ** (modenv * 5 * \env_lowpass_mod.kr(0)) + (lfo * \lfo_lowpass_mod.kr(0))) * \lowpass_freq.kr(15000);
      snd = SVF.ar(snd, hifreq, \highpass_resonance.kr(0), lowpass:0, highpass:1);
      snd = SVF.ar(snd, lofreq, \lowpass_resonance.kr(0));
      Out.ar(\out.ir, Pan2.ar(snd * 0.5 * \amp.kr(0.5), \pan.kr(0)));
    }).add;

    tVoices = Dictionary.new;
    Server.default.sync;
    7.do({ arg i;
      var syn = Synth.before(endOfChain, "Turns", [\out, outBus]);
      NodeWatcher.register(syn, true);
      tVoices.put(i, syn)
    });

    this.addCommand("set", "sif", { arg msg;
      var key = msg[1].asSymbol;
      var val = msg[3];
      tVoices.at(msg[2]).set(key, val);
    });
  }

  free {
    7.do({ arg i;
      tVoices[i].free;
    });
    endOfChain.free;
    outBus.free;
  }
}
