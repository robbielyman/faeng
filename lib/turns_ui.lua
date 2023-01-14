-- Turns Engine UI
-- built for faeng

local Engine_UI = {}
local UI = require "ui"
local Filtergraph = require "filtergraph"
local Envgraph = require "envgraph"
local Graph = require "graph"
local Voice = 0

local Tab = {}
Tab.__index = Tab

function Tab.new(params, lists, hook)
  local t = {
    params = params,
    lists = lists,
    hook = hook,
    index = 1
  }
  setmetatable(t, Tab)
  return t
end

function Tab:redraw()
  self:hook()
  for _, list in pairs(self.lists) do
    list:redraw()
  end
end

function Tab:enc(n, d)
  if n == 2 then
    self.index = util.clamp(self.index + d, 1, #self.params)
  elseif n == 3 then
    params:delta(self.params[self.index], d)
  end
end

local Page = {}
Page.__index = Page

function Page.new(titles, tabs)
  local p = {
    tabs = tabs,
    active_tab = 1,
    ui = UI.Tabs.new(1, titles)
  }
  setmetatable(p, Page)
  return p
end

function P:enc(n, d)
  local tab = self.tabs[self.ui.index]
  tab:enc(n, d)
end

function Page:key(n, z)
  if n == 2 and z == 1 then
    self.ui:set_index_delta(-1, true)
  elseif n ==3 and z == 1 then
    self.ui:set_index_delta(1, true)
  end
end

function Page:redraw()
  self.ui:redraw()
  self.tabs[self.ui.index]:redraw()
end

Screen_Dirty = true
Screen = {}

local function norns_assert(cond, msg)
  if not msg then msg = "" end
  if cond then return end
  norns.scripterror(msg)
end

function Engine_UI.screen_callback(_)
  Screen_Dirty = true
end

function Set_Current_Voice(voice_id)
  Voice = voice_id // 7
  Screen_Dirty = true
end

function Engine_UI.init()
  if Needs_Restart then Engine_UI.redraw() return end
  Screen = UI.Pages.new(1,3)
  norns_assert(params:lookup_param("formant_amp_0"), "config error: turns not properly loaded!")

  Screen[1] = Page.new({"SQUARE", "FORMANT"},
    {
      Tab.new({"square_amp_", "width_square_", "lfo_square_width_mod_", "env_square_width_mod_", "fm_numerator_", "fm_denominator_", "fm_index_", "lfo_index_mod_", "env_index_mod_", "detune_square_octave_", "detune_square_steps_", "detune_square_cents_", "lfo_pitch_mod_", "env_pitch_mod_"},
        {
          UI.ScrollingList.new(70, 24, 1, {"amp", "width", "lfo>width", "env>width", "num", "denom", "index", "lfo>index", "env>index", "oct", "coarse", "fine", "lfo>pitch", "env>pitch"}),
          UI.ScrollingList.new(120, 24)
        },
        function (self)
          self.lists[1].index = self.index
          self.lists[1].num_above_selected = 1
          self.lists[2].index = self.index
          self.lists[2].num_above_selected = 1
          for i = 1, 15 do
            self.lists[2].entries[i] = params:string(self.params[i] .. Voice)
          end
          self.lists[2].text_align = "right"
          self.osc_graph:update_functions()
          self.osc_graph:redraw()
        end),
      Tab.new({"width_formant_", "lfo_formant_width_mod_", "env_formant_width_mod_", "formant_", "square_formant_mod_", "lfo_formant_mod_", "env_formant_mod_", "square_formant_amp_mod_", "detune_formant_octave_", "detune_formant_steps_", "detune_formant_cents_", "lfo_pitch_mod_", "env_pitch_mod_", "formant_amp_", "lfo_amp_mod_"},
        {
          UI.ScrollingList.new(70, 24, 1, {"width", "lfo>width", "env>width", "formant", "sq>form", "lfo>form", "env>form", "oct", "coarse", "fine", "lfo>pitch", "env>pitch", "amp", "sq>amp", "lfo>amp"}),
          UI.ScrollingList.new(120, 24)
        },
        function (self)
          self.lists[1].index = self.index
          self.lists[1].num_above_selected = 1
          self.lists[2].index = self.index
          self.lists[2].num_above_selected = 1
          for i = 1, 15 do
            self.lists[2].entries[i] = params:string(self.params[i] .. Voice)
          end
          self.lists[2].text_align = "right"
          self.osc_graph:update_functions()
          self.osc_graph:redraw()
        end)
    })
  local function sq_func(x)
    local w = params:get("width_square_" .. Voice)
    local ratio = params:get("fm_numerator_" .. Voice) / params:get("fm_denominator_" .. Voice)
    local index = params:get("fm_index_" .. Voice)
    x = x + math.sin(x * math.pi * 2 * ratio) * index
    local y =  x % 1 < w and -1 or 1
    return y
  end
  local last = 0
  local state = false
  local function form_func(x)
    local w = params:get("width_formant_" .. Voice)
    local sq = sq_func(x)
    local form = 2^params:get("formant_" .. Voice)
    form = form + sq * params:get("square_formant_mod_" .. Voice)
    if form == 0 then
      form = 0.0001
    end
    if form < 0 then
      form = -form
    end
    local v = (1-w) / form
    w = w / form
    local a = 2 / w
    local b = -2 / v
    local y
    if not state then
      -- rise: do we start falling?
      if x + last > w then
        state = not state
      end
    else
      -- fall: do we start rising?
      if x % 1 < 0.01 then
        last = x
        state = not state
      end
    end
    if state then
      -- falling
      y = math.max(b * (x + last - w) + 1, -1)
    else
      y = a * (x + last) - 1
    end
    local am = sq * params:get("square_formant_amp_mod_" .. Voice)
    return util.clamp(y * (params:get("formant_amp_" .. Voice) + am), -1, 1)
  end
  for i = 1, 2 do
    Screen[1].tabs[i].osc_graph = Graph.new(0, 1, "lin", -1, 1, "lin", nil, true, false)
    Screen[1].tabs[i].osc_graph:set_position_and_size(4, 22, 56, 38)
  end
  Screen[1].tabs[1].osc_graph:add_function(function (x)
    local y = sq_func(x)
    return y * params:get("square_amp_" .. Voice)
  end, 4)
  Screen[1].tabs[2].osc_graph:add_function(form_func, 4)
  Screen[2] = Page.new({"AMP ENV", "MOD ENV", "LFO"},
    {
      Tab.new({"amp_attack_", "amp_decay_", "amp_sustain_", "amp_release_", "pan_"},
        {
          UI.ScrollingList.new(70, 24, 1, {"atk", "dec", "sus", "rel", "pan"}),
          UI.ScrollingList.new(120, 24)
        },
        function (self)
          self.lists[1].index = self.index
          self.lists[1].num_above_selected = 1
          self.lists[2].index = self.index
          self.lists[2].num_above_selected = 1
          for i = 1, 5 do
            self.lists[2].entries[i] = params:string(self.params[i] .. Voice)
          end
          self.lists[2].text_align = "right"
          self.env_graph:edit_adsr(params:get(self.params[1]..Voice), params:get(self.params[2]..Voice), params:get(self.params[3]..Voice), params:get(self.params[4]..Voice))
          self.env_graph:redraw()
        end),
      Tab.new({"mod_attack", "mod_decay_", "mod_sustain_", "mod_release_"},
        {
          UI.ScrollingList.new(70, 24, 1, {"atk", "dec", "sus", "rel"}),
          UI.ScrollingList.new(120, 24)
        },
        function (self)
          self.lists[1].index = self.index
          self.lists[1].num_above_selected = 1
          self.lists[2].index = self.index
          self.lists[2].num_above_selected = 1
          for i = 1, 4 do
            self.lists[2].entries[i] = params:string(self.params[i] .. Voice)
          end
          self.lists[2].text_align = "right"
          self.env_graph:edit_adsr(params:get(self.params[1]..Voice), params:get(self.params[2]..Voice), params:get(self.params[3]..Voice), params:get(self.params[4]..Voice))
          self.env_graph:redraw()
        end),
      Tab.new({"lfo_freq_", "lfo_fade_"},
        {
          UI.List.new(70, 24, 1, {"freq", "fade"}),
          UI.List.new(120, 24)
        },
        function (self)
          self.lists[1].index = self.index
          self.lists[2].index = self.index
          for i = 1, 2 do
            self.lists[2].entries[i] = params:string(self.params[i] .. Voice)
          end
          self.lists[2].text_align = "right"
          self.lfo_graph:update_functions()
          self.lfo_graph:redraw()
        end)
    })
  Screen[2].tabs[1].env_graph = Envgraph.new_adsr(0, 20, nil, nil, nil, nil, nil, nil, 1, -4)
  Screen[2].tabs[2].env_graph = Envgraph.new_adsr(0, 20, nil, nil, nil, nil, nil, nil, 1, -4)
  Screen[2].tabs[3].lfo_graph = Graph.new(0, 1, "lin", -1, 1, "lin", nil, true, false)
  Screen[2].tabs[1].env_graph:set_position_and_size(4,22,56,38)
  Screen[2].tabs[2].env_graph:set_position_and_size(4,22,56,38)
  Screen[2].tabs[3].lfo_graph:set_position_and_size(4,22,56,38)
  Screen[2].tabs[3].lfo_graph:add_function(function (x)
    local freq = params:get("lfo_freq_" .. Voice)
    local fade = params:get("lfo_fade_" .. Voice)
    local fade_end
    local y_fade
    local MIN_Y = 0.15

    fade_end = util.linlin(0, 10, 0, 1, fade)
    y_fade = util.linlin(0, fade_end, MIN_Y, 1, x)
    x = x * util.linlin(0.01, 10, 0.5, 10, freq)
    local y = math.sin(x * math.pi * 2)
    return y * y_fade * 0.75
  end, 4)
  Screen[3] = Page.new({"HIPASS", "LOPASS"},
    {
      Tab.new({"highpass_freq_", "highpass_resonance_", "lfo_highpass_mod_", "env_highpass_mod_"},
        {
          UI.List.new(70, 34, 1, {"freq", "res", "lfo>freq", "env>freq"}),
          UI.List.new(120, 34)
        },
        function (self)
          self.lists[1].index = self.index
          self.lists[2].index = self.index
          for i = 1, 4 do
            self.lists[2].entries[i] = params:string(self.params[i] .. Voice)
          end
          self.lists[2].text_align = "right"
          self.filt_graph:edit("highpass", nil, params:get(self.params[1] .. Voice), params:get(self.params[2] .. Voice))
          self.filt_graph:redraw()
        end),
      Tab.new({"lowpass_freq_", "lowpass_resonance_", "lfo_lowpass_mod_", "env_lowpass_mod_"},
        {
          UI.List.new(70, 34, 1, {"freq", "res", "lfo>freq", "env>freq"}),
          UI.List.new(120, 34)
        },
        function (self)
          self.lists[1].index = self.index
          self.lists[2].index = self.index
          for i = 1, 4 do
            self.lists[2].entries[i] = params:string(self.params[i] .. Voice)
          end
          self.lists[2].text_align = "right"
          self.filt_graph:edit("lowpass", nil, params:get(self.params[1] .. Voice), params:get(self.params[2] .. Voice))
          self.filt_graph:redraw()
        end)
    })
  Page[3].tabs[1].filt_graph = Filtergraph.new(10, 20000, -60, 32.5, "highpass", 12, params:get("highpass_freq_" .. Voice), params:get("highpass_resonance_" .. Voice))
  Page[3].tabs[2].filt_graph = Filtergraph.new(10, 20000, -60, 32.5, "lowpass", 12, params:get("lowpass_freq_" .. Voice), params:get("lowpass_resonance_" .. Voice))
  Page[3].tabs[1].filt_graph:set_position_and_size(4, 22, 56, 38)
  Page[3].tabs[2].filt_graph:set_position_and_size(4, 22, 56, 38)

  local screen_redraw_metro = metro.init()
  screen_redraw_metro.event = function ()
    if not Screen_Dirty then return end
    redraw()
  end
  if screen_redraw_metro then
    screen_redraw_metro:start(1/15)
  end
  screen.aa(1)
end

local function draw_title()
  screen.level(15)
  screen.move(4, 15)
  screen.text(string.format("%d", Voice))
  screen.fill()
end

function Engine_UI.redraw()
  Screen_Dirty = false
  screen.clear()
  if Needs_Restart then
    local Restart_Message = UI.Message.new{ "please restart norns" }
    Restart_Message:redraw()
    screen.update()
    return
  end
  Screen:redraw()
  draw_title()
  Screen[Screen.index]:redraw()
  if Popup then
    Popup:redraw()
  end
  screen.update()
end

function Engine_UI.enc(n, d)
  if n == 1 then
    Screen:set_index_delta(d, false)
    Screen_Dirty = true
    return
  end
  Screen[Screen.index]:enc(n, d)
  Screen_Dirty = true
end

function Engine_UI.key(n, z)
  Screen[Screen.index]:keyw(n, z)
  Screen_Dirty = true
  Popup = nil
end

function Engine.param_changed_callback(id)
  Screen_Dirty = true
  local page = Screen[Screen.index]
  local tab = page.tabs[page.ui.index]
  local found = false
  for _, v in pairs(tab.params) do
    if v .. Voice == id then
      found = true
      break
    end
  end
  if found then return end
  Popup = {
    text = params:lookup_param(id).name .. ": " .. params:string(id),
    redraw = function (self)
      screen.level(0)
      screen.rect(8, 0, 128 - 16, 6)
      screen.fill()
      screen.move(64, 6)
      screen.level(8)
      screen.text_center(self.text)
      screen.fill()
    end
  }
  if Popup_Clock then
    clock.cancel(Popup_Clock)
  end
  Popup_Clock = clock.run(function ()
    clock.sleep(1)
    Popup = nil
    Screen_Dirty = true
  end)
end

return Engine_UI
