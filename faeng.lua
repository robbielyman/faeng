-- faeng is a sequencer
-- inspired by kria
-- powerd by timber
-- connect a grid
-- and take wing
--
-- v 0.2.1
-- llllllll.co/t/faeng-is-a-sequencer/

engine.name = "Timber"

local Timber = include("timber/lib/timber_engine")
local sequins = require("sequins")
local Lattice = require("lattice")
local MusicUtil = require("musicutil")
local UI = require("ui")

TRACKS = 16
PAGES = 6
Page = 0
MODS = 3
Mod = 0
SCREENS = 7
Screen = 1
SubSequins = 0
Tracks = {}
Active_Track = 1
Grid_Dirty = true
Screen_Dirty = true
Scale_Names = {}
for i = 1, #MusicUtil.SCALES do
  table.insert(Scale_Names, MusicUtil.SCALES[i].name)
end
Velocities = {0.2, 0.4, 0.6, 0.8, 1.0}
Dance_Index = 1
Presses = {}
Keys = {0, 0, 0}
Press_Counter = {}

function init()
    for x = 1,16 do
        Presses[x] = {}
        for y = 1,8 do
            Presses[x][y] = 0
        end
    end
    for x = 1,16 do
        Press_Counter[x] = {}
    end
    -- Tracks setup
    local lattice = Lattice:new()
    Tracks = {}
    for i = 1, TRACKS do
        local data = {}
        local divisions = {}
        local probabilities = {}
        local lengths = {}
        for j = 1, PAGES do
            data[j] = {}
            divisions[j] = {}
            probabilities[j] = {}
            for n = 1, 16 do
                data[j][n] = {}
                divisions[j][n] = 1
                probabilities[j][n] = {}
                for k = 1, 16 do
                    probabilities[j][n][k] = 4
                end
                if j == 1 then
                    -- triggers
                    for k = 1,16 do
                        data[j][n][k] = 0
                    end
                elseif j == 4 then
                    -- octaves
                    for k = 1,16 do
                        data[j][n][k] = 3
                    end
                elseif j == 5 then
                    -- velocities
                    for k=1,16 do
                        data[j][n][k] = 5
                    end
                elseif j == 6 then
                    -- ratchets
                    for k = 1,16 do
                        data[j][n][k] = 4
                    end
                else
                    -- sample, note
                    for k = 1,16 do
                        data[j][n][k] = 1
                    end
                end
            end
        end
        data[PAGES + 1] = {}
        probabilities[PAGES + 1] = {}
        for k = 1,16 do
            data[PAGES + 1][k] = 1
            divisions[PAGES + 1] = 6
            probabilities[PAGES + 1][k] = 4
            lengths[k] = 4
        end
        Tracks[i] = Track.new(i, data, lattice, divisions, probabilities, lengths, false)
    end
    -- Grid setup
    Grid = grid.connect(1)
    Grid.key = grid_key
    grid_redraw_metro = metro.init()
    grid_redraw_metro.event = function()
        if Grid.device and Grid_Dirty then
            grid_redraw()
        end
    end
    grid_redraw_metro:start(1/25)
    lattice:new_pattern{
        division = 1/8,
        action = function()
            Dance_Index = Dance_Index % 16 + 1
            Grid_Dirty = true
        end
    }
    -- UI setup
    Screens = UI.Pages.new(0, 7)
    screen_redraw_metro = metro.init()
    screen_redraw_metro.event = function()
        update()
        if Screen_Dirty then
            redraw()
        end
    end
    params:add{
        type = 'number',
        id = 'root_note',
        name = 'root note',
        min = 0,
        max = 127,
        default = 60,
        formatter = function(param)
            return MusicUtil.note_num_to_name(param:get(), true)
        end,
        action = function() build_scale() end,
    }
    params:add{
        type = 'option',
        id = 'scale',
        name = 'scale',
        options = Scale_Names,
        default = 5,
        action = function() build_scale() end
    }
    build_scale() -- builds initial scale
    Timber.options.PLAY_MODE_BUFFER_DEFAULT = 4
    Timber.add_params()
    params:add_separator()
    for i = 0, TRACKS * 7 - 1 do
        Timber.add_sample_params(i, true)
        params:set('play_mode_' .. i, 4)
    end
    Sample_Setup_View   = Timber.UI.SampleSetup.new(get_current_sample())
    Waveform_View       = Timber.UI.Waveform.new(get_current_sample())
    Filter_Amp_View     = Timber.UI.FilterAmp.new(get_current_sample())
    Amp_Env_View        = Timber.UI.AmpEnv.new(get_current_sample())
    Mod_Env_View        = Timber.UI.ModEnv.new(get_current_sample())
    LFOs_View           = Timber.UI.Lfos.new(get_current_sample())
    Mod_Matrix_View     = Timber.UI.ModMatrix.new(get_current_sample())
    Timber.display = 'id'
    Timber.meta_changed_callback = callback_screen
    Timber.waveform_changed_callback = callback_waveform
    Timber.play_positions_changed_callback = callback_waveform
    Timber.views_change_callback = callback_screen
    Timber.sample_changed_callback = callback_sample
    screen_redraw_metro:start(1/15)
    screen.aa(1)
    lattice:start()
end

function callback_sample(id)
    if id then
        params:set('play_mode_' .. id, 3)
    end
end

function callback_screen(id)
    if not id or id == Tracks[Active_Track].sample_id then
        Screen_Dirty = true
    end
end

function callback_waveform(id)
    if (not id or id == Tracks[Active_Track].sample_id) and Screen == 2 then
        Screen_Dirty = true
    end
end

function build_scale()
    note_nums = MusicUtil.generate_scale_of_length(params:get('root_note'), params:get('scale'), 7)
end

function update()
    Waveform_View:update()
    LFOs_View:update()
end

function get_current_sample()
    return 7 * (Active_Track - 1) + Tracks[Active_Track].sample_id
end

function load_folder(file, add)
    local sample_id = 16 * (Active_Track - 1)
    if add then
        for i = 7, 0, -1 do
            local j = 16 * (Active_Track - 1) + i
            if Timber.samples_meta[j].num_frames > 0 then
                sample_id = j + 1
                break
            end
        end
    end
    local max = math.min(sample_id + 7, 16 * (Active_Track - 1) + 7)
    Timber.clear_samples(sample_id, max)
    local split_at = string.match(file, "^.*()/")
    local folder = string.sub(file, 1, split_at)
    file = string.sub(file, split_at + 1)
    local found = false
    for _, val in ipairs(Timber.FileSelect.list) do
        if val == file then
            found = true
        end
        if found then
            if sample_id > max then
                print('Max files loaded')
                break
            end
            local lower_val = val:lower()
            if string.find(lower_val, '.wav')
                or string.find(lower_val, '.aif')
                or string.find(lower_val, '.aiff')
                or string.find(lower_val, '.ogg') then
                Timber.load_sample(sample_id, folder .. val)
                sample_id = sample_id + 1
            else
                print('Skipped', val)
            end
        end
    end
end

function set_sample_id()
    Sample_Setup_View:set_sample_id(get_current_sample())
    Waveform_View:set_sample_id(get_current_sample())
    Filter_Amp_View:set_sample_id(get_current_sample())
    Amp_Env_View:set_sample_id(get_current_sample())
    Mod_Env_View:set_sample_id(get_current_sample())
    LFOs_View:set_sample_id(get_current_sample())
    Mod_Matrix_View:set_sample_id(get_current_sample())
    Screen_Dirty = true
end

-- norns display

function redraw()
    Screen_Dirty = false
    screen.clear()
    if File_Select or Timber.file_select_active then
        Timber.FileSelect.redraw()
        return
    end
    if Screen == 1 then
        Sample_Setup_View:redraw()
    elseif Screen == 2 then
        Waveform_View:redraw()
    elseif Screen == 3 then
        Filter_Amp_View:redraw()
    elseif Screen == 4 then
        Amp_Env_View:redraw()
    elseif Screen == 5 then
        Mod_Env_View:redraw()
    elseif Screen == 6 then
        LFOs_View:redraw()
    elseif Screen == 7 then
        Mod_Matrix_View:redraw()
    end
    screen.update()
end

-- norns input

function enc(n, d)
    if n == 1 then
        if Keys[1] == 1 then
            Tracks[Active_Track]:set_sample_id(Tracks[Active_Track].sample_id + d)
            set_sample_id()
        else
            Screens:set_index_delta(d, false)
            Screen = Screen + d
            while Screen > SCREENS do Screen = Screen - SCREENS end
            while Screen < 1 do Screen = Screen + SCREENS end
        end
    else
        if Screen == 1 then
            Sample_Setup_View:enc(n, d)
        elseif Screen == 2 then
            Waveform_View:enc(n, d)
        elseif Screen == 3 then
            Filter_Amp_View:enc(n, d)
        elseif Screen == 4 then
            Amp_Env_View:enc(n, d)
        elseif Screen == 5 then
            Mod_Env_View:enc(n, d)
        elseif Screen == 6 then
            LFOs_View:enc(n, d)
        elseif Screen == 7 then
            Mod_Matrix_View:enc(n, d)
        end
    end
    Screen_Dirty = true
end

function key(n, z)
    Keys[n] = z
    if n == 1 then
        Timber.shift_mode = Keys[1] == 1
    end
    if Screen == 1 then
        Sample_Setup_View:key(n, z)
    elseif Screen == 2 then
        Waveform_View:key(n, z)
    elseif Screen == 3 then
        Filter_Amp_View:key(n, z)
    elseif Screen == 4 then
        Amp_Env_View:key(n, z)
    elseif Screen == 5 then
        Mod_Env_View:key(n, z)
    elseif Screen == 6 then
        LFOs_View:key(n, z)
    elseif Screen == 7 then
        Mod_Matrix_View:key(n, z)
    end
    Screen_Dirty = true
end

-- grid display

function grid_redraw()
    Grid_Dirty = false
    Grid:all(0)
    -- nav bar
    -- tracks page
    if SubSequins > 0 and Mod == 0 then
        Grid:led(1, 8, Dance_Index % 2 == 1 and 15 or 9)
    else
        Grid:led(1, 8, Page == 0 and 15 or 9)
    end

    -- track scroll
    for i = 1,2 do
        Grid:led(2 + i, 8, 9)
    end

    -- pages
    for x = 1,PAGES+1 do
        Grid:led(x + 5, 8, x == Page and 15 or 9)
    end

    -- mods
    for x = 1,MODS do
        Grid:led(x + 5 + PAGES + 2, 8, x == Mod and Dance_Index % 2 == 1 and 15 or 9)
    end
    -- main view
    if Mod == 1 and Page == 0 then
        Mod = 0
        Grid_Dirty = true
    end
    if Mod == 2 then
        division_view()
    elseif Mod == 3 then
        probability_view()
    else
        page_view()
    end
    for x = 1,16 do
        for y = 1,8 do
            if Presses[x][y] == 1 then
                Grid:led(x,y,15)
            end
        end
    end
    Grid:refresh()
end

function division_view()
    if Page == 0 then
        Mod = 0
        Grid_Dirty = true
        return
    end
    for x = 1, 16 do
        Grid:led(x, 2, 9)
    end
    local pattern = Tracks[Active_Track].values[PAGES + 1]
    if Page <= PAGES then
        Grid:led(Tracks[Active_Track].divisions[Page][pattern], 2, 15)
    else
        Grid:led(Tracks[Active_Track].divisions[Page], 2, 15)
    end
    if Page < 6 then
        Grid:led(Tracks[Active_Track].swings[Page][pattern], 4, 15)
    end
end

function probability_view()
    if Page == 0 then
        Mod = 0
        Grid_Dirty = true
        return
    else
        local pattern = Tracks[Active_Track].values[PAGES + 1]
        local track = Tracks[Active_Track]
        for x = 1,16 do
            local value = Page <= PAGES and track.probabilities[Page][pattern][x] or track.probabilities[Page][x]
            local left = Page <= PAGES and track.bounds[Page][pattern][1] or track.bounds[Page][1]
            local right = Page <= PAGES and track.bounds[Page][pattern][2] or track.bounds[Page][2]
            local check = x >= left and x <= right
            for i = 4, value, -1 do
                Grid:led(x, 7 - i, check and 9 or 4)
            end
            if Page <= PAGES and track.indices[Page][pattern] == x then
                Grid:led(x, 7 - value, 15)
            elseif Page > PAGES and track.indices[Page] == x then
                Grid:led(x, 7 - value, 15)
            end
        end
    end
end

function page_view()
    if Page == 0 then
        -- tracks page
        for x = 1, 16 do
            local pattern = Tracks[x].values[PAGES + 1]
            Grid:led(x, 4, 4)
            Grid:led(x, 5, Tracks[x].muted and 4 or 9)
            if Active_Track == x then
                Grid:led(x, 6, Tracks[x].values[1][pattern] == 1 and 15 or 12)
            else
                Grid:led(x, 6, Tracks[x].values[1][pattern] == 1 and 9 or 4)
            end
        end
        return
    end
    local track = Tracks[Active_Track]
    local pattern = track.values[PAGES + 1]
    local left = Page <= PAGES and track.bounds[Page][pattern][1] or track.bounds[Page][1]
    local right = Page <= PAGES and track.bounds[Page][pattern][2] or track.bounds[Page][2]
    if Page > PAGES then
        Page = PAGES + 1
        -- pattern page
        for x = 1, 16 do
            Grid:led(x, 1, 4)
        end

        if SubSequins > 0 then
            if type(track.data[Page][SubSequins]) == 'number' then
                track.data[Page][SubSequins] = {track.data[Page][SubSequins]}
                track:make_sequins(Page)
            end
            local datum = track.data[Page][SubSequins]
            for x = 1, #datum do
                Grid:led(x, 4, 9)
            end
            if track.selected > #datum then
                track.selected = #datum
                Grid_Dirty = true
                return
            end
            Grid:led(track.selected, 4, 12)
            Grid:led(datum[track.selected], 1, 12)
        else
            local datum = track.data[Page][track.selected]
            if type(datum) == 'number' then
                Grid:led(datum, 1, 9)
            else
                Grid:led(datum[Dance_Index % #datum + 1], 1, 9)
            end
            Grid:led(pattern, 1, 15)
            for x = 1,16 do
                local check = x >= left and x <= right
                Grid:led(x, 4, check and 9 or 4)
            end
            Grid:led(track.selected, 4, 12)
            Grid:led(track.indices[Page], 4, 15)

            for x = 1,track.lengths[pattern] do
                Grid:led(x, 6, 4)
            end

            Grid:led(track.lengths[pattern], 6, 9)
            Grid:led(track.lengths[track.selected], 6, 12)
            Grid:led(track.pattern_counter, 6, 15)
        end
    elseif Page == 1 then
        -- triggers page
        if SubSequins > 0 then
            if type(track.data[Page][pattern][SubSequins]) == 'number' then
                track.data[Page][pattern][SubSequins] = {track.data[Page][pattern][SubSequins]}
                track:make_sequins(Page, pattern)
            end
            local datum = track.data[Page][pattern][SubSequins]
            for x = 1, #datum do
                Grid:led(x, 6, datum[x] == 1 and 9 or 2)
            end
            Grid:led(SubSequins, 2, Dance_Index % 2 == 1 and 15 or 0)
        end
        for x = 1, 16 do
            local datum = track.data[Page][pattern][x]
            datum = type(datum) == 'number' and datum or datum[Dance_Index % #datum + 1]
            local check = x >= left and x <= right
            if datum == 1 then
                Grid:led(x, 2, check and 9 or 4)
            else
                Grid:led(x, 2, check and 2 or 0)
            end
        end
        Grid:led(track.indices[Page][pattern], 2, 15)
    elseif Page <= 5 then
        -- sample coarse, sample fine, velocity page
        if SubSequins > 0 then
            if type(track.data[Page][pattern][SubSequins]) == 'number' then
                track.data[Page][pattern][SubSequins] = {track.data[Page][pattern][SubSequins]}
                track:make_sequins(Page)
            end
            local datum = track.data[Page][pattern][SubSequins]
            for x = 1, #datum do
                if Page == 4 then
                    -- octave page
                    if datum[x] > 3 then
                        for i = 3, datum[x] - 1 do
                            Grid:led(x, 8 - i, 9)
                        end
                    elseif datum[x] < 2 then
                        for i = 2, datum + 1, -1 do
                            Grid:led(x, 8 - i, 9)
                        end
                    end
                elseif Page == 5 then
                    -- velocities page
                    if datum[x] < 5 then
                        for i = 5, datum[x] + 1, -1 do
                            Grid:led(x, 8 - i, 9)
                        end
                    end
                end
                -- all three pages
                Grid:led(x, 8 - datum[x], 9)
            end
        else
            for x = 1, 16 do
                local datum = track.data[Page][pattern][x]
                datum = type(datum) == 'number' and datum or datum[Dance_Index % #datum + 1]
                local check = x >= left and x <= right
                if Page == 4 then
                    -- octave page
                    if datum > 3 then
                        for i = 3, datum - 1 do
                            Grid:led(x, 8 - i, check and 9 or 4)
                        end
                    elseif datum < 2 then
                        for i = 2, datum + 1, -1 do
                            Grid:led(x, 8 - i, check and 9 or 4)
                        end
                    end
                elseif Page == 5 then
                    -- velocities page
                    if datum < 5 then
                        for i = 5, datum + 1, -1 do
                            Grid:led(x, 8 - i, check and 9 or 4)
                        end
                    end
                end
                -- all three pages
                if track.indices[Page][pattern] == x then
                    Grid:led(x, 8 - datum, 15)
                else
                    Grid:led(x, 8 - datum, check and 9 or 4)
                end
            end
        end
    elseif Page == 6 then
        -- ratchets page
        if SubSequins > 0 then
            if type(track.data[Page][pattern][SubSequins]) == 'number' then
                track.data[Page][pattern][SubSequins] = {track.data[Page][pattern][SubSequins]}
                track:make_sequins(Page, pattern)
            end
            local datum = track.data[Page][pattern][SubSequins]
            for x = 1, #datum do
                local ratchet_amount = datum[x] & 3
                local ratchets = datum[x] >> 2
                for i = 0,ratchet_amount do
                    if ratchets & 2^i == 2^i then
                        Grid:led(x, 7 - i, 9)
                    end
                end
            end
        else
            for x = 1, 16 do
                local datum = track.data[Page][pattern][x]
                datum = type(datum) == 'number' and datum or datum[Dance_Index % #datum + 1]
                local check = x >= left and x <= right
                local ratchet_amount = datum & 3
                local ratchets = datum >> 2
                for i = 0,ratchet_amount do
                    if ratchets & 2^i == 2^i then
                        Grid:led(x, 7 - i, check and 9 or 4)
                    end
                end
                if track.indices[Page][pattern] == x then
                    local out_of_twelve = (track.ratchet_counter - 1) % 12 + 1
                    local i = out_of_twelve // (12 / (ratchet_amount + 1))
                    if ratchets & 2^i == 2^i then
                        Grid:led(x, 7 - i, 15)
                    end
                end
            end
        end
    end
end

-- grid input

function grid_key(x, y, z)
    if y == 8 then
        -- nav bar
        if x == 1 then
            -- track button pressed
            if z == 0 then
                if SubSequins > 0 then
                    SubSequins = 0
                elseif SubSequins == 0 then
                    -- enter track view
                    Page = 0
                    Mod = 0
                end
            end
            Presses[x][y] = z
            Grid_Dirty = true
        elseif x == 3 then
            -- scroll active track left
            if z == 0 then
                Active_Track = Active_Track - 1 < 1 and TRACKS or Active_Track - 1
                set_sample_id()
            end
            Presses[x][y] = z
            Grid_Dirty = true
            Screen_Dirty = true
        elseif x == 4 then
            -- scroll active track right
            if z == 0 then
                Active_Track = Active_Track + 1 > TRACKS and 1 or Active_Track + 1
                set_sample_id()
            end
            Presses[x][y] = z
            Grid_Dirty = true
            Screen_Dirty = true
        elseif x >= 6 and x <= 6 + PAGES then
            -- active page pressed
            if z == 0 then
                Page = x - 5
                SubSequins = 0
            end
            Presses[x][y] = z
            Grid_Dirty = true
        elseif x >= 14 and x <= 16 then
            -- active mod pressed
            if z == 0 then
                if Mod == x - 13 then
                    Mod = 0
                elseif Page > 0 then
                    Mod = x - 13
                    SubSequins = 0
                end
            end
            Presses[x][y] = z
            Grid_Dirty = true
        end
        return
    end
    local track = Tracks[Active_Track]
    local pattern = track.values[PAGES + 1]
    if Page == 0 then
        -- tracks page
        if y == 6 then
            -- select track
            if z == 0 then
                Active_Track = x
                set_sample_id()
            end
            Presses[x][y] = z
            Grid_Dirty = true
        elseif y == 5 then
            -- mute/unmute track
            if z == 0 then
                Tracks[x].muted = not Tracks[x].muted
            end
            Presses[x][y] = z
            Grid_Dirty = true
        elseif y == 4 then
            -- reset track
            if z == 0 then
                for i = 1, PAGES + 1 do
                    if i <= PAGES then
                        Tracks[x]:increment(i, pattern, true)
                    else
                        Tracks[x]:increment(i, nil, true)
                    end
                end
            end
            Presses[x][y] = z
            Grid_Dirty = true
        end
    elseif Page > PAGES and Mod <= 1 then
        Page = PAGES + 1
        -- pattern page
        if Mod == 1 then
            if y == 4 then
                if z == 0 then
                    local flag = true
                    for i = 1,16 do
                        if Presses[i][y] == 1 and i ~= x then
                            -- set new bounds
                            if i < x then
                                track.bounds[Page][1] = i
                                track.bounds[Page][2] = x
                            else
                                track.bounds[Page][1] = x
                                track.bounds[Page][2] = x
                            end
                            flag = false
                            break
                        end
                    end
                    if flag then
                        -- move  bounds
                        local length = track.bounds[Page][2] - track.bounds[Page][1]
                        track.bounds[Page][1] = x
                        track.bounds[Page][2] = math.min(x + length, 16)
                    end
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        elseif Mod == 0 then
            if SubSequins > 0 then
                if y == 4 then
                    if z == 0 then
                        local flag = true
                        if Presses[1][y] == 1 and 1 ~= x then
                            -- alter SubSequins length
                            if x > #track.data[Page][SubSequins] then
                                for i = #track.data[Page][SubSequins], x do
                                    track.data[Page][SubSequins][i] = 1
                                end
                            elseif x < #track.data[Page][SubSequins] then
                                for i = x, #track.data[Page][SubSequins] do
                                    track.data[Page][SubSequins][i] = nil
                                end
                            end
                            flag = false
                        elseif x == 1 then
                            for i = 2,16 do
                                -- remove SubSequins, exit SubSequins mode
                                if Presses[i][y] == 1 then
                                    track.data[Page][SubSequins] = track.data[Page][SubSequins][1]
                                    SubSequins = 0
                                    flag = false
                                    break
                                end
                            end
                        end
                        if flag then
                            -- select
                            if x <= #track.data[Page][SubSequins] then
                                track.selected = x
                            end
                        end
                        track:make_sequins(Page)
                    end
                    Presses[x][y] = z
                    Grid_Dirty = true
                elseif y == 1 then
                    if z == 0 then
                        -- set selection
                        track.data[Page][SubSequins][track.selected] = x
                        track:make_sequins(Page)
                    end
                    Presses[x][y] = z
                    Grid_Dirty = true
                end
            else
                if y == 1 then
                    if z == 0 and Press_Counter[x][y] then
                        clock.cancel(Press_Counter[x][y])
                        track.data[Page][track.selected] = x
                        track:make_sequins(Page)
                    elseif z == 1 then
                        Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                    end
                    Presses[x][y] = z
                    Grid_Dirty = true
                elseif y == 4 then
                    if z == 0 and Press_Counter[x][y] then
                        -- select
                        clock.cancel(Press_Counter[x][y])
                        track.selected = x
                    elseif z == 1 then
                        Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                    end
                    Presses[x][y] = z
                    Grid_Dirty = true
                elseif y == 6 then
                    if z == 0 then
                        track.lengths[track.selected] = x
                    end
                    Presses[x][y] = z
                    Grid_Dirty = true
                end
            end
        end
    elseif Page == 1 and Mod <= 1 then
        -- triggers page
        if Mod == 1 then
            if y == 2 then
                if z == 0 then
                    local flag = true
                    for i = 1,16 do
                        if Presses[i][y] == 1 and i ~= x then
                            -- set new bounds
                            if i < x then
                                track.bounds[Page][pattern][1] =  i
                                track.bounds[Page][pattern][2] = x
                            else
                                track.bounds[Page][pattern][1] = x
                                track.bounds[Page][pattern][2] = x
                            end
                            flag = false
                            break
                        end
                    end
                    if flag then
                        -- move bounds
                        local length = track.bounds[Page][pattern][2] - track.bounds[Page][pattern][1]
                        track.bounds[Page][pattern][1] = x
                        track.bounds[Page][pattern][2] = math.min(x + length, 16)
                    end
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        elseif Mod == 0 then
            if SubSequins > 0 then
                if y == 6 then
                    if z == 0 then
                        local flag = true
                        if Presses[1][y] == 1 and 1 ~= x then
                            -- alter SubSequins length
                            if x > #track.data[Page][pattern][SubSequins] then
                                for i = #track.data[Page][pattern][SubSequins], x do
                                    track.data[Page][pattern][SubSequins][i] = 0
                                end
                            elseif x < #track.data[Page][pattern][SubSequins] then
                                for i = x, #track.data[Page][pattern][SubSequins] do
                                    track.data[Page][pattern][SubSequins][i] = nil
                                end
                            end
                            flag = false
                        elseif x == 1 then
                            for i = 2,16 do
                                -- remove SubSequins, exit SubSequins mode
                                if Presses[i][y] == 1 then
                                    track.data[Page][pattern][SubSequins] = track.data[Page][pattern][SubSequins][1]
                                    SubSequins = 0
                                    flag = false
                                    break
                                end
                            end
                        end
                        if flag then
                            -- toggle state
                            if x <= #track.data[Page][pattern][SubSequins] then
                                track.data[Page][pattern][SubSequins][x] = track.data[Page][pattern][SubSequins][x] == 1 and 0 or 1
                            end
                        end
                        track:make_sequins(Page, pattern)
                    end
                    Presses[x][y] = z
                    Grid_Dirty = true
                end
            elseif y == 2 then
                -- short press
                -- remove any SubSequins and toggle step
                if z == 0 and Press_Counter[x][y] then
                    clock.cancel(Press_Counter[x][y])
                    local datum = track.data[Page][pattern][x]
                    track.data[Page][pattern][x] = datum == 0 and 1 or 0
                    track:make_sequins(Page, pattern)
                -- start long press counter
                elseif z == 1 then
                    Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        end
    else
        -- all other pages
        if Mod == 1 then
            -- Loop mod
            if z == 0 then
                local flag = true
                for i = 1,16 do
                    if Presses[i][y] == 1 and i ~= x then
                        -- set new bounds
                        if i < x then
                            track.bounds[Page][pattern][1] = i
                            track.bounds[Page][pattern][2] = x
                        else
                            track.bounds[Page][pattern][1] = i
                            track.bounds[Page][pattern][2] = i
                        end
                        flag = false
                        break
                    end
                end
                if flag then
                    -- move bounds
                    local length = track.bounds[Page][pattern][2] - track.bounds[Page][pattern][1]
                    track.bounds[Page][pattern][1] = x
                    track.bounds[Page][pattern][2] = math.min(x + length, 16)
                end
            end
            Presses[x][y] = z
            Grid_Dirty = true
        elseif Mod == 2 then
            -- Division mod
            if y == 2 then
                if z == 0 then
                    if Page <= PAGES then
                        track.divisions[Page][pattern] = x
                        track:update(Page)
                    else
                        Page = PAGES + 1
                        track.divisions[Page] = x
                        track.patterns[Page]:set_division(track.divisions[Page] / 16)
                    end
                end
                Presses[x][y] = z
                Grid_Dirty = true
            elseif y == 4 and Page < 6 then
                if z == 0 then
                    if Page <= PAGES then
                        track.swings[Page][pattern] = x
                        track:update(Page)
                    end
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        elseif Mod == 3 then
            -- Probability mod
            if y >= 3 then
                if z == 0 then
                    if Page <= PAGES then
                        track.probabilities[Page][pattern][x] = 7 - y
                    else
                        Page = PAGES + 1
                        track.probabilities[Page][x] = 7 - y
                    end
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        elseif Mod == 0 then
            -- normal page view
            if SubSequins > 0 then
                if Page == 2 or Page == 3
                    or (Page <= 5 and y >= 3)
                    or (Page == 6 and y >= 4) then
                    if z == 0 then
                        local flag = true
                        if Presses[1][y] == 1 and 1 ~= x then
                            -- alter SubSequins length
                            if x > #track.data[Page][pattern][SubSequins] then
                                for i = #track.data[Page][pattern][SubSequins], x do
                                    local value = 1
                                    if Page == 4 then
                                        value = 3
                                    elseif Page == 5 then
                                        value = 5
                                    elseif Page == 6 then
                                        value = 4
                                    end
                                    track.data[Page][pattern][SubSequins][i] = value
                                end
                            elseif x < #track.data[Page][pattern][SubSequins] then
                                for i = x, #track.data[Page][pattern][SubSequins] do
                                    track.data[Page][pattern][SubSequins][i] = nil
                                end
                            end
                            flag = false
                        elseif x == 1 then
                            for i = 2,16 do
                                -- remove SubSequins, exit SubSequins mode
                                if Presses[i][y] == 1 then
                                    track.data[Page][pattern][SubSequins] = track.data[SubSequins][pattern][1]
                                    SubSequins = 0
                                    flag = false
                                    break
                                end
                            end
                        end
                        if flag then
                            -- enter data
                            if x <= #track.data[Page][pattern][SubSequins] then
                                if Page <= 5 then
                                    track.data[Page][pattern][SubSequins][x] = 8 - y
                                elseif Page == 6 then
                                    local datum = track.data[Page][pattern][SubSequins][x]
                                    local ratchet_amount = datum & 3
                                    local ratchets = datum >> 2
                                    if 7 - y > ratchet_amount then
                                        -- add new bits
                                        for i = ratchet_amount + 1, 7 - y do
                                            ratchets = ratchets ~ 2^i
                                        end
                                        ratchet_amount = 7 - y
                                    else
                                        -- toggle pressed key
                                        ratchets = ratchets ~ 2^(7 - y)
                                    end
                                    if ratchets == 0 then
                                        -- reset
                                        ratchets = 1
                                        ratchet_amount = 0
                                    end
                                    datum = (ratchets << 2) | ratchet_amount
                                    track.data[Page][SubSequins][x] = datum
                                end
                            end
                        end
                        track:make_sequins(Page, pattern)
                    end
                    Presses[x][y] = z
                    Grid_Dirty = true
                end
            elseif Page == 2 or Page == 3 then
                -- sample or note page
                -- short press
                -- remove any SubSequins and enter data
                if z == 0 and Press_Counter[x][y] then
                    clock.cancel(Press_Counter[x][y])
                    track.data[Page][pattern][x] = 8 - y
                    track:make_sequins(Page, pattern)
                -- start long press counter
                elseif z == 1 then
                    Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                end
                Presses[x][y] = z
                Grid_Dirty = true
            elseif Page <= 5 then
                -- other pages
                if y >= 3 then
                    -- short press
                    -- remove any SubSequins and enter data
                    if z == 0 and Press_Counter[x][y] then
                        clock.cancel(Press_Counter[x][y])
                        track.data[Page][pattern][x] = 8 - y
                        track:make_sequins(Page, pattern)
                    -- start long press counter
                    elseif z == 1 then
                        Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                    end
                    Presses[x][y] = z
                    Grid_Dirty = true
                end
            elseif Page == 6 then
                -- ratchet page
                if y >= 3 then
                    -- short press
                    if z == 0 and Press_Counter[x][y] then
                        clock.cancel(Press_Counter[x][y])
                        local datum = track.data[Page][pattern][x]
                        if type(datum) ~= 'number' then
                            -- remove subsequins
                            datum = 4
                        end
                        local ratchet_amount = datum & 3
                        local ratchets = datum >> 2
                        if 7 - y > ratchet_amount then
                            -- add new bits
                            for i = ratchet_amount + 1, 7 - y do
                                ratchets = ratchets ~ 2^i
                            end
                            ratchet_amount = 7 - y
                        else
                            -- toggle pressed key
                            ratchets = ratchets ~ 2^(7 - y)
                        end
                        if ratchets == 0 then
                            -- reset
                            ratchets = 1
                            ratchet_amount = 0
                        end
                        datum = (ratchets << 2) | ratchet_amount
                        track.data[Page][pattern][x] = datum
                        track:make_sequins(Page, pattern)
                    -- start long press counter
                    elseif z == 1 then
                        Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                    end
                    Presses[x][y] = z
                    Grid_Dirty = true
                end
            end
        end
    end
    if z == 0 then
        Presses[x][y] = z
    end
end

function grid_long_press(x, y)
    -- a long press is one second
    clock.sleep(1)
    Press_Counter[x][y] = nil
    if y == 8 or Mod > 0 or SubSequins > 0 then
        return
    elseif Page > PAGES and y == 1 then
        local track = Tracks[Active_Track]
        track:copy(track.data[Page][track.selected], x)
        track.data[Page][track.selected] = x
        track:make_sequins(Page)
        Grid_Dirty = true
    elseif Page > PAGES and y == 4 then
        SubSequins = x
        Grid_Dirty = true
    elseif Page == 1 and y == 2 then
        SubSequins = x
        Grid_Dirty = true
    elseif Page == 2 or Page == 3 then
        SubSequins = x
        Grid_Dirty = true
    elseif Page <= 5 and y >= 3 then
        SubSequins = x
        Grid_Dirty = true
    elseif Page == 6 and y >= 4 then
        SubSequins = x
        Grid_Dirty = true
    end
end

-- Track functions
Track = {}

function Track.new(id, data, host_lattice, divisions, probabilities, lengths, muted)
    local t = setmetatable({}, { __index = Track})
    t.id = id
    t.sample_id = 0
    t.data = data
    t.probabilities = probabilities
    t.divisions = divisions
    t.swings = {}
    t.muted = muted
    t.lengths = lengths
    t.bounds = {}
    t.patterns = {}
    t.indices = {}
    t.values = {}
    t.ratchet_counter = 0
    t.pattern_counter = 0
    t.selected = 1
    t.sequins = {}
    t.bounds[PAGES + 1] = {1, 1}
    t.indices[PAGES + 1] = 0
    t.sequins[PAGES + 1] = sequins(data[PAGES+1])
    t.sequins[PAGES + 1]:select(1)
    t.values[PAGES + 1] = t.sequins[PAGES + 1][1]
    t.swings[PAGES + 1] = 8
    t.patterns[PAGES + 1] = host_lattice:new_pattern{
        division = divisions[PAGES + 1] / 16,
        action = function()
            t.pattern_counter = t.pattern_counter % t.lengths[t.values[PAGES + 1]] + 1
            if t.pattern_counter == 1 then
                t:increment(PAGES + 1)
            end
            if Page == PAGES + 1 and Active_Track == t.id then
                Grid_Dirty = true
            end
        end
    }
    for i = 1, PAGES do
        t.bounds[i] = {}
        t.indices[i] = {}
        t.values[i] = {}
        t.sequins[i] = {}
        t.patterns[i] = {}
        t.swings[i] = {}
        for n = 1, 16 do
            t.bounds[i][n] = {1,6}
            t.indices[i][n] = 0
            t.sequins[i][n] = sequins(data[i][n])
            t.sequins[i][n]:select(1)
            t.values[i][n] = t.sequins[i][n][1]
            t.swings[i][n] = 8
            end
            if i ~= 6 then
                t.patterns[i] = host_lattice:new_pattern{
                    division = divisions[i][1] / 16,
                    action = function()
                        local pattern = t.values[PAGES + 1]
                        t:increment(i, pattern)
                        if Page == i and Active_Track == t.id then
                            Grid_Dirty = true
                        end
                        if Page == 0 and i == 1 then
                            Grid_Dirty = true
                        end
                    end
                }
            elseif i == 6 then
                t.patterns[i] = host_lattice:new_pattern{
                    division = divisions[i][1] / (12 * 16),
                    action = function()
                        local pattern = t.values[PAGES + 1]
                        t.ratchet_counter = t.ratchet_counter % (12 * divisions[i][pattern]) + 1
                        if t.ratchet_counter == 1 then
                            t:increment(i, pattern)
                        end
                        local ratchet_div = 12 / ((t.values[i][pattern] & 3) + 1)
                        local ratchets = t.values[i][pattern] >> 2
                        local out_of_twelve = (t.ratchet_counter - 1) % 12 + 1
                        if t.ratchet_counter % ratchet_div == 1 then
                            local step = 2 ^ ((out_of_twelve - 1) / ratchet_div)
                            if step & ratchets == step and t.values[1][pattern] == 1 and not t.muted then
                                t:play_note()
                            end
                            if Page == i and Active_Track == t.id then
                                Grid_Dirty = true
                            end
                        end
                    end
                }
        end
    end
    return t
end

function Track:update(i)
    if i ~= 6 then
        local pattern = self.values[PAGES + 1]
        self.patterns[i]:set_division(self.divisions[i][pattern] / 16)
        self.patterns[i]:set_swing(self.swings[i][pattern] * 100 / 16)
    end
    if i == 6 or i == 1 then
        local pattern = self.values[PAGES + 1]
        self.patterns[6]:set_division(self.divisions[1][pattern] / (12 * 16))
    end
end

function Track:copy(source, target)
    for i = 1, PAGES do
        self.divisions[i][target] = self.divisions[i][source]
        if i ~= 6 then
            self.patterns[i][target]:set_division(self.divisions[i][source] / 16)
        end
        for j = 1,16 do
            self.probabilities[i][target][j] = self.probabilities[i][source][j]
            if type(self.data[i][source][j]) ~= 'number' then
                self.data[i][target][j] = {}
                for k = 1,#self.data[i][source][j] do
                    self.data[i][target][j][k] = self.data[i][source][j][k]
                end
            else
                self.data[i][target][j] = self.data[i][source][j]
            end
        end
        for j = 1,2 do
            self.bounds[i][target][j] = self.bounds[i][source][j]
        end
        self.indices[i][target] = self.indices[i][source]
        self.values[i][target] = self.values[i][source]
        self:make_sequins(i, target)
    end
    self.ratchet_counter[target] = self.ratchet_counter[source]
end

function Track:make_sequins(i, n)
    local s = {}
    if i > PAGES or not n then
        i = PAGES + 1
        for j = 1,16 do
            if type(self.data[i][j]) ~= 'number' then
                if #self.data[i][j] == 0 then
                    self.data[i][j] = {1}
                end
                s[j] = sequins(self.data[i][j])
            else
                s[j] = self.data[i][j]
            end
        end
        self.sequins[i]:settable(s)
    else
        for j = 1,16 do
            if type(self.data[i][n][j]) ~= 'number' then
                if #self.data[i][n][j] == 0 then
                    self.data[i][n][j] = {1}
                end
                s[j] = sequins(self.data[i][n][j])
            else
                s[j] = self.data[i][n][j]
            end
        end
        self.sequins[i][n]:settable(s)
    end
end

function Track:increment(i, n, reset)
    if i > PAGES or not n then
        i = PAGES + 1
        if reset or self.indices[i] + 1 > self.bounds[i][2] or self.indices[i] + 1 < self.bounds[i][1] then
            self.indices[i] = self.bounds[i][1]
        else
            self.indices[i] = self.indices[i] + 1
        end
        self.sequins[i]:select(self.indices[i])
        local r = math.random()
        if r <= self.probabilities[i][self.indices[i]] / 4 or reset then
            self.values[i] = self.sequins[i]()
            for j = 1, PAGES do
                self:update(j)
            end
        end
    else
        if reset or self.indices[i][n] + 1 > self.bounds[i][n][2]
            or self.indices[i][n] + 1 < self.bounds[i][n][1] then
            self.indices[i][n] = self.bounds[i][n][1]
        else
            self.indices[i][n] = self.indices[i][n] + 1
        end
        self.sequins[i][n]:select(self.indices[i][n])
        local r = math.random()
        if r <= self.probabilities[i][n][self.indices[i][n]] / 4  or reset then
            self.values[i][n] = self.sequins[i][n]()
        end
    end
end

function Track:play_note()
    local pattern = self.values[PAGES + 1]
    local note = note_nums[self.values[3][pattern]] + 12 * (self.values[4][pattern] - 3)
    local id = (self.id - 1) * 7 + self.values[2][pattern] - 1
    if Timber.samples_meta[id].num_frames > 0 then
        engine.noteOn(self.id, MusicUtil.note_num_to_freq(note), Velocities[self.values[5][pattern]], id)
    end
end

function Track:set_sample_id(n)
    while n > 7 do
        n = n - 7
    end
    while n < 0 do
        n = n + 7
    end
    self.sample_id = n
end
