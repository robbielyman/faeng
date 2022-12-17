-- xD1 Engine UI
-- built for faeng

local Engine_UI = {}
local UI = require "ui"
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
    preset = 0,
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
    params:delta(self.params[self.index] .. self.preset, d)
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

function Page:enc(n, d)
  local tab = self.tabs[self.ui.index]
  tab:enc(n, d)
end

function Page:key(n, z)
  if n == 2 and z == 1 then
    self.ui:set_index_delta(-1, true)
  elseif n == 3 and z == 1 then
    self.ui:set_index_delta(1, true)
  end
end

function Page:redraw()
  self.ui:redraw()
  self.tabs[self.ui.index]:redraw()
end

function Page:set_preset(id)
  for _, tab in pairs(self.tabs) do
    tab.preset = id
  end
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
  for i = 1, 3 do
    Screen[i]:set_preset(voice_id)
  end
  Voice = voice_id
  Screen_Dirty = true
end

function Engine_UI.init()
  Screen = UI.Pages.new(1, 7)
  norns_assert(params:lookup_param("oatk_1_0"), "config error: xD1 not properly loaded!")

  local ophook = function (self)
    self.lists[1].index = self.index
    self.lists[1].num_above_selected = 0
    self.lists[2].index = self.index
    for i = 1, 8 do
      self.lists[2].entries[i] = params:string(self.params[i] .. self.preset)
    end
    self.lists[2].num_above_selected = 0
    self.lists[2].text_align = "right"
    self.env_graph:edit_adsr(params:get(self.params[1] .. self.preset), params:get(self.params[2] .. self.preset), params:get(self.params[3] .. self.preset), params:get(self.params[4] .. self.preset), params:get(self.params[7] .. self.preset) / 4, params:get("ocurve_" .. self.preset))
    self.env_graph:redraw()
  end
  local titles, tabs = {}, {}
  for i = 1, 6 do
    titles[i] = tostring(i)
    tabs[i] = Tab.new({
      "oatk_" .. i .. "_", "odec_" .. i .. "_", "osus_" .. i .. "_", "orel_" .. i .. "_",
      "num_" .. i .. "_", "denom_" .. i .. "_", "oamp_" .. i .. "_", "ocurve" .. "_"
    }, {
        UI.ScrollingList.new(70, 24, 1, {
          "atk", "dec", "sus", "rel", "num", "denom", "index", "curve"
        }),
        UI.ScrollingList.new(120, 24)
      }, ophook)
    local adsr_params = { params:get("oatk_1_0"), params:get("odec_1_0"), params:get("osus_1_0"), params:get("orel_1_0")}
    local env_graph = Envgraph.new_adsr(0, 20, nil, nil, table.unpack(adsr_params), 1, -4)
    env_graph:set_position_and_size(4, 22, 56, 38)
    tabs[i].env_graph = env_graph
  end
  Screen[1] = Page.new(titles, tabs)
  Screen[2] = Page.new({"FILTER", "LFO"},
    {
      Tab.new({"fatk_", "fdec_", "fsus_", "frel_", "hirat_", "hires_", "lorat_", "lores_", "hfamt_", "lfamt_", "fcurve_"},
        {
          UI.ScrollingList.new(70, 24, 1, {"atk", "dec", "sus", "rel", "high", "res", "low", "res", "e>hi", "e>low", "curve"}),
          UI.ScrollingList.new(120, 24)
        },
        function (self)
          self.lists[1].index = self.index
          self.lists[1].num_above_selected = 0
          self.lists[2].index = self.index
          self.lists[2].num_above_selected = 0
          for i = 1, 11 do
            self.lists[2].entries[i] = params:string(self.params[i] .. self.preset)
          end
          self.lists[2].text_align = "right"
          self.env_graph:edit_adsr(params:get(self.params[1] .. self.preset), params:get(self.params[2] .. self.preset), params:get(self.params[3] .. self.preset), params:get(self.params[4] .. self.preset), nil, params:get("fcurve_" .. self.preset))
          self.env_graph:redraw()
        end),
      Tab.new({"lfreq_", "lfade_", "lfo_am_", "lfo_pm_", "lfo_hfm_", "lfo_lfm_"},
        {
          UI.ScrollingList.new(70, 24, 1, {"freq", "fade", "l>amp", "l>pit", "l>hi", "l>low"}),
          UI.ScrollingList.new(120, 24)
        },
        function (self)
          self.lists[1].index = self.index
          self.lists[1].num_above_selected = 0
          self.lists[2].index = self.index
          self.lists[2].num_above_selected = 0
          for i = 1, 6 do
            self.lists[2].entries[i] = params:string(self.params[i] .. self.preset)
          end
          self.lists[2].text_align = "right"
          self.lfo_graph:update_functions()
          self.lfo_graph:redraw()
        end)
    })
  local adsr_params = {params:get("fatk_0"), params:get("fdec_0"), params:get("fsus_0"), params:get("frel_0")}
  Screen[2].tabs[1].env_graph = Envgraph.new_adsr(0, 20, nil, nil, table.unpack(adsr_params), 1, -4)
  Screen[2].tabs[1].env_graph:set_position_and_size(4, 22, 56, 38)
  Screen[2].tabs[2].lfo_graph = Graph.new(0, 1, "lin", -1, 1, "lin", nil, true, false)
  Screen[2].tabs[2].lfo_graph:set_position_and_size(4, 22, 56, 38)
  Screen[2].tabs[2].lfo_graph:add_function( function (x)
    local id = Get_Current_Voice()
    local freq = params:get("lfreq_" .. id)
    local fade = params:get("lfade_" .. id)
    local fade_end
    local y_fade
    local MIN_Y = 0.15

    fade_end = util.linlin(0, 10, 0, 1, fade)
    y_fade = util.linlin(0, fade_end, MIN_Y, 1, x)
    x = x * util.linlin(0.01, 10, 0.5, 10, freq)
    local y = math.sin(x * math.pi * 2)
    return y * y_fade * 0.75
  end, 4)
  Screen[3] = Page.new({"MISC", "PITCH ENV"},
    {
      Tab.new({"alg_", "monophonic_", "feedback_"},
        {
          UI.List.new(70, 34, 1, {"alg", "mono", "fdbk"}),
          UI.List.new(120, 34)
        },
        function (self)
          self.lists[1].index = self.index
          self.lists[2].index = self.index
          for i = 1, 3 do
            self.lists[2].entries[i] = params:string(self.params[i] .. self.preset)
          end
          self.lists[2].text_align = "right"
          screen.level(10)
          local alg_path = _path.code .. "xD1/img/" .. params:get("alg_" .. self.preset) .. ".png"
          screen.display_png(alg_path, 4, 24)
          screen.fill()
        end),
      Tab.new({"patk_", "pdec_", "psus_", "prel_", "pamt_", "pcurve_"},
        {
          UI.ScrollingList.new(70, 24, 1, {"atk", "dec", "sus", "rel", "e>pit", "curve"}),
          UI.ScrollingList.new(120, 24)
        },
        function (self)
          self.lists[1].index = self.index
          self.lists[1].num_above_selected = 0
          self.lists[2].index = self.index
          for i = 1, 6 do
            self.lists[2].entries[i] = params:string(self.params[i] .. self.preset)
          end
          self.lists[2].num_above_selected = 0
          self.lists[2].text_align = "right"
          self.env_graph:edit_adsr(params:get(self.params[1] .. self.preset), params:get(self.params[2] .. self.preset), params:get(self.params[3] .. self.preset), params:get(self.params[4] .. self.preset), nil, params:get("pcurve_" .. self.preset))
          self.env_graph:redraw()
        end)
    })
  adsr_params = {params:get("patk_0"), params:get("pdec_0"), params:get("psus_0"), params:get("prel_0")}
  Screen[3].tabs[2].env_graph = Envgraph.new_adsr(0, 20, nil, nil, table.unpack(adsr_params), 1, -4)
  Screen[3].tabs[2].env_graph:set_position_and_size(4, 22, 56, 38)

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

local function draw_title(preset)
  screen.level(15)
  screen.move(4, 15)
  screen.text(string.format("%03d", preset))
  screen.fill()
end

function Engine_UI.redraw()
  Screen_Dirty = false
  screen.clear()
  Screen:redraw()
  draw_title(Voice)
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
  Screen[Screen.index]:key(n, z)
  Screen_Dirty = true
  Popup = nil
end

function Engine.param_changed_callback(id)
  Screen_Dirty = true
  local page = Screen[Screen.index]
  local tab = page.tabs[page.ui.index]
  local found = false
  for _, v in pairs(tab.params) do
    if v .. tab.preset == id then
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
  Popup_Clock = clock.run(function()
    clock.sleep(1)
    Popup = nil
    Screen_Dirty = true
  end)
end

return Engine_UI
