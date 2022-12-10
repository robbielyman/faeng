-- Timber Engine UI
-- built for faeng

local Engine_UI = {}

local UI = require "ui"
Screen_Dirty = true
Screen = {}

local function norns_assert(cond, msg)
  if not cond then
    norns.scripterror(msg)
  end
end

local function callback_sample() end

local function callback_screen(_)
  Screen_Dirty = true
end

Engine_UI.screen_callback = callback_screen

local function callback_waveform(_)
  Screen_Dirty = true
end

local function update()
  Screen[2]:update()
  Screen[6]:update()
end

function Set_Current_Voice()
  for i = 1, 7 do
    Screen[i]:set_sample_id(Get_Current_Voice())
  end
end

function Engine_UI.init()
  Screen = UI.Pages.new(1, 7)
  norns_assert(Engine and Engine.UI and Engine.UI.SampleSetup, 'config error: Timber_Guts not loaded')
  -- Set the numerical indices of Screen to the pages for easy metaprogramming
  Screen[1] = Engine.UI.SampleSetup.new(0)
  Screen[2] = Engine.UI.Waveform.new(0)
  Screen[3] = Engine.UI.FilterAmp.new(0)
  Screen[4] = Engine.UI.AmpEnv.new(0)
  Screen[5] = Engine.UI.ModEnv.new(0)
  Screen[6] = Engine.UI.Lfos.new(0)
  Screen[7] = Engine.UI.ModMatrix.new(0)

  Engine.display = 'id'
  Engine.meta_changed_callback = callback_screen
  Engine.waveform_changed_callback = callback_waveform
  Engine.play_positions_changed_callback = callback_waveform
  Engine.views_changed_callback = callback_screen
  Engine.sample_changed_callback = callback_sample

  local screen_redraw_metro = metro.init()
  screen_redraw_metro.event = function ()
    if not Screen_Dirty then return end
    redraw()
    update()
  end
  if screen_redraw_metro then
    screen_redraw_metro:start(1/15)
  end
  screen.aa(1)
end

function Engine_UI.redraw()
  Screen_Dirty = false
  screen.clear()
  if Engine.file_select_active then
    Engine.FileSelect.redraw()
    return
  end
  Screen:redraw()
  Screen[Screen.index]:redraw()
  screen.update()
end

function Engine_UI.enc(n, d)
  if n == 1 then
    Screen:set_index_delta(d, false)
    return
  end
  Screen[Screen.index]:enc(n, d)
  Screen_Dirty = true
end

function Engine_UI.key(n, z)
  if n == 1 then
    Engine.shift_mode = z == 1
  end
  Screen[Screen.index]:key(n, z)
  Screen_Dirty = true
end

return Engine_UI
