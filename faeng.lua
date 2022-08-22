-- faeng is a sequencer
-- inspired by kria
-- powerd by timber
-- connect a grid
-- and take wing
--
-- v 0.1
-- llllllll.co/t/faeng-is-a-sequencer/

engine.name = "Timber"

local Timber = include("timber/lib/timber_engine")
local sequins = require("sequins")
local Lattice = require("lattice")
local MusicUtil = require("musicutil")
local UI = require("ui")

TRACKS = 4
PAGES = 5
Page = 1
PATTERNS = 16
Pattern = 1
MODS = 3
Mod = 0
SCREENS = 7
Screen = 0
SubSequins = 0
Tracks = {}
Metatrack = {}
Song_Mode = false
Active_Track = 1
Grid_Dirty = true
Screen_Dirty = true
scale_names = {}
for i = 1, #MusicUtil.SCALES do
  table.insert(scale_names, MusicUtil.SCALES[i].name)
end
Velocities = {0.2, 0.4, 0.6, 0.8, 1.0}
Dance_Index = 1
Presses = {}
Keys = {0, 0, 0}
Press_Counter = {}

function init()
    -- Tracks setup
    for x = 1,16 do
        Presses[x] = {}
        for y = 1,8 do
            Presses[x][y] = 0
        end
    end
    for x = 1,16 do
        Press_Counter[x] = {}
    end
    local lattice = Lattice:new()
    for n = 1, PATTERNS do
        Tracks[n] = {}
        for i = 1, TRACKS do
            local data = {}
            local transpose_mode = false
            local divisions = {}
            local probabilities = {}
            for j = 1, PAGES do
                data[j] = {}
                divisions[j] = 1
                probabilities[j] = {}
                for k = 1,16 do
                    probabilities[j][k] = 4
                end
                if j == 1 then
                    for k=1,16 do
                        data[j][k] = 0
                    end
                elseif j == 3 and transpose_mode then
                    for k=1,16 do
                        data[j][k] = 3
                    end
                elseif j == 4 then
                    for k=1,16 do
                        data[j][k] = 5
                    end
                elseif j == 5 then
                    for k=1,16 do
                        data[j][k] = 4
                    end
                else
                    for k=1,16 do
                        data[j][k] = 1
                    end
                end
            end
            Tracks[n][i] = Track.new({n, i}, false, data, probabilities, divisions, lattice)
        end
    end
    -- Metatrack setup
    Metatrack.data = {}
    Metatrack.lengths = {}
    Metatrack.bounds = {1,4}
    for i = 1, 64 do
        Metatrack.data[i] = 1
        Metatrack.lengths[i] = 8
    end
    Metatrack.current = 1
    Metatrack.division = 6
    Metatrack.index = 0
    Metatrack.counter = 0
    Metatrack.selected = 1
    Metatrack.pattern = lattice:new_pattern{
        division = 1 / 16,
        action = function()
            Metatrack.counter = Metatrack.counter % Metatrack.division + 1
            if Metatrack.counter % Metatrack.division == 1 and Song_Mode then
                Metatrack:increment()
            end
        end
    }
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
        options = scale_names,
        default = 5,
        action = function() build_scale() end
    }
    build_scale() -- builds initial scale
    for i = 1,TRACKS do
        params:add{
            type = 'option',
            id = 'track_mode_' .. i,
            name = 'track ' .. i .. ' mode',
            options = {'multisample', 'repitch'},
            default = 1,
            action = function()
                for _, pattern in ipairs(Tracks) do
                    pattern[i].transpose_mode = params:get('track_mode_' ..i) == 2
                    for j = 1,16 do
                        pattern[i].data[3][j] = params:get('track_mode_' ..i) == 2 and 3 or 1
                    end
                    pattern[i]:make_sequins(3)
                end
            end,
        }
    end
    Timber.options.PLAY_MODE_BUFFER_DEFAULT = 4
    Timber.add_params()
    params:add_separator()
    for i = 0, 255 do
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
    if not id or id == Tracks[Pattern][Active_Track].sample_id then
        Screen_Dirty = true
    end
end

function callback_waveform(id)
    if (not id or id == Tracks[Pattern][Active_Track].sample_id) and Screen == 2 then
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
    return 64 * (Active_Track - 1) + Tracks[Pattern][Active_Track].sample_id
end

function load_folder(file, add)
    local sample_id = 64 * (Active_Track - 1)
    if add then
        for i = 63, 0, -1 do
            local j = 64 * (Active_Track - 1) + i
            if Timber.samples_meta[j].num_frames > 0 then
                sample_id = j + 1
                break
            end
        end
    end
    local max = math.min(sample_id + 63, 64 * Active_Track - 1)
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
    if Screen == 0 then
        screen.level(3)
        screen.move(68, 28)
        screen.text("K3 to")
        screen.move(68, 37)
        screen.text(Keys[1] == 1 and "add folder" or "load folder")
        screen.fill()
        screen.move(4, 28)
        screen.text("track " .. Active_Track)
        screen.move(4, 37)
        if Tracks[Pattern][Active_Track].transpose_mode then
            screen.text("repitch")
        else
            screen.text("multisample")
        end
    elseif Screen == 1 then
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
            if Screen > 0 then
                for _,pattern in ipairs(Tracks) do
                    pattern[Active_Track]:set_sample_id(pattern[Active_Track].sample_id + d)
                end
                set_sample_id()
            end
        else
            Screens:set_index_delta(d, false)
            Screen = Screen + d
            while Screen > SCREENS do Screen = Screen - SCREENS end
            while Screen < 0 do Screen = Screen + SCREENS end
        end
    else
        if Screen == 0 then
            if n == 2 then
                params:delta("track_mode_" .. Active_Track, d)
            end
        elseif Screen == 1 then
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
    if Screen == 0 then
        if z == 1 then
            if n == 3 then
                File_Select = true
                local add = Keys[1] == 1
                Keys[1] = 0
                Timber.shift_mode = Keys[1] == 1
                Timber.FileSelect.enter(_path.audio, function(file)
                    File_Select = false
                    Screen_Dirty = true
                    if file ~= 'cancel' then
                        load_folder(file, add)
                    end
                end)
            end
        end
    elseif Screen == 1 then
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
    for x = 1,TRACKS do
        if SubSequins == 0 then
            Grid:led(x, 8, x == Active_Track and 15 or 9)
        elseif Mod == 0 then
            Grid:led(x, 8, x == Active_Track and Dance_Index % 2 == 1 and 15 or 9)
        end
    end
    for x = 1,PAGES do
        Grid:led(x + TRACKS + 1, 8, x == Page and 15 or 9)
    end
    for x = 1,MODS do
        Grid:led(x + TRACKS + PAGES + 2, 8, x == Mod and Dance_Index % 2 == 1 and 15 or 9)
    end
    Grid:led(16, 8, Page == PAGES + 1 and 15 or 9)
    -- main view
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
    if Page > PAGES then
        Mod = 0
        Grid_Dirty = true
        return
    end
    for x = 1, 16 do
        Grid:led(x, 2, 9)
    end
    Grid:led(Tracks[Pattern][Active_Track].divisions[Page], 2, 15)
end

function probability_view()
    if Page > PAGES then
        Mod = 0
        Grid_Dirty = true
        return
    else
        local track = Tracks[Pattern][Active_Track]
        for x = 1,16 do
            local value = track.probabilities[Page][x]
            local left = track.bounds[Page][1]
            local right = track.bounds[Page][2]
            local check = x >= left and x <= right
            for i = 4, value, -1 do
                Grid:led(x, 7 - i, check and 9 or 4)
            end
            if track.indices[Page] == x then
                Grid:led(x, 7 - value, 15)
            end
        end
    end
end

function page_view()
    if Page > PAGES then
        -- metasequencer page
        for x = 1, 16 do
            Grid:led(x, 1, 9)
        end
        Grid:led(Pattern, 1, 15)
        if Song_Mode then
            Grid:led(Metatrack.data[Metatrack.selected], 1, 15)
            for x = 1,Metatrack.division do
                Grid:led(x, 2, x == Metatrack.counter and 15 or x == Metatrack.division and 9 or 2)
            end
            for x = 1,Metatrack.lengths[Metatrack.current] do
                Grid:led(x, 7, x == Metatrack.index and 15 or 4)
            end
            local i = Metatrack.lengths[Metatrack.selected]
            if i ~= Metatrack.index then
                Grid:led(i, 7, 9)
            end
            for x = 1,64 do
                local check = x >= Metatrack.bounds[1] and x <= Metatrack.bounds[2]
                if check then
                    Grid:led((x - 1) % 16 + 1, 3 + x // 16, 9)
                end
            end
            Grid:led((Metatrack.selected - 1) % 16 + 1, 3 + Metatrack.selected // 16, 15)
            Grid:led((Metatrack.current - 1) % 16 + 1, 3 + Metatrack.current // 16, 15)
        end
        return
    end
    local track = Tracks[Pattern][Active_Track]
    if Page == 1 then
        -- triggers page
        if SubSequins > 0 then
            if type(track.data[Page][SubSequins]) == 'number' then
                track.data[Page][SubSequins] = {track.data[Page][SubSequins]}
                track:make_sequins(Page)
            end
            local datum = track.data[Page][SubSequins]
            for x = 1, #datum do
                Grid:led(x, 6, datum[x] == 1 and 9 or 2)
            end
            Grid:led(SubSequins, Active_Track, Dance_Index % 2 == 1 and 15 or 0)
        end
        for y = 1, TRACKS do
            track = Tracks[Pattern][y]
            for x = 1, 16 do
                local datum = track.data[Page][x]
                datum = type(datum) == 'number' and datum or datum[Dance_Index % #datum + 1]
                local left = track.bounds[Page][1]
                local right = track.bounds[Page][2]
                local check = x >= left and x <= right
                if datum == 1 then
                    Grid:led(x, y, check and 9 or 4)
                else
                    Grid:led(x, y, check and 2 or 0)
                end
            end
            Grid:led(track.indices[Page], y, 15)
        end
    elseif Page <= 4 then
        -- sample coarse, sample fine, velocity page
        if SubSequins > 0 then
            if type(track.data[Page][SubSequins]) == 'number' then
                track.data[Page][SubSequins] = {track.data[Page][SubSequins]}
                track:make_sequins(Page)
            end
            local datum = track.data[Page][SubSequins]
            for x = 1, #datum do
                if Page == 3 and track.transpose_mode then
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
                elseif Page == 3 and not track.transpose_mode then
                    -- sample coarse page
                    if datum[x] > 1 then
                        for i = 1, datum[x] - 1 do
                            Grid:led(x, 8 - i, 9)
                        end
                    end
                elseif Page == 4 then
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
                local datum = track.data[Page][x]
                datum = type(datum) == 'number' and datum or datum[Dance_Index % #datum + 1]
                local left = track.bounds[Page][1]
                local right = track.bounds[Page][2]
                local check = x >= left and x <= right
                if Page == 3 and track.transpose_mode then
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
                elseif Page == 3 and not track.transpose_mode then
                    -- sample coarse page
                    if datum > 1 then
                        for i = 1, datum - 1 do
                            Grid:led(x, 8 - i, check and 9 or 4)
                        end
                    end
                elseif Page == 4 then
                    if datum < 5 then
                        for i = 5, datum + 1, -1 do
                            Grid:led(x, 8 - i, check and 9 or 4)
                        end
                    end
                end
                -- all three pages
                if track.indices[Page] == x then
                    Grid:led(x, 8 - datum, 15)
                else
                    Grid:led(x, 8 - datum, check and 9 or 4)
                end
            end
        end
    elseif Page == 5 then
        -- ratchets page
        if type(track.data[Page][SubSequins]) == 'number' then
            track.data[Page][SubSequins] = {track.data[Page][SubSequins]}
            track:make_sequins(Page)
        end
        if SubSequins > 0 then
            local datum = track.data[Page][SubSequins]
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
                local datum = track.data[Page][x]
                datum = type(datum) == 'number' and datum or datum[Dance_Index % #datum + 1]
                local left = track.bounds[Page][1]
                local right = track.bounds[Page][2]
                local check = x >= left and x <= right
                local ratchet_amount = datum & 3
                local ratchets = datum >> 2
                for i = 0,ratchet_amount do
                    if ratchets & 2^i == 2^i then
                        Grid:led(x, 7 - i, check and 9 or 4)
                    end
                end
                if track.indices[Page] == x then
                    local i = track.ratchet_counter // (12 / (ratchet_amount + 1))
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
        if x <= TRACKS then
            -- active track pressed
            if z == 0 then
                if x == Active_Track and SubSequins > 0 then
                    SubSequins = 0
                end
                Active_Track = x
                set_sample_id()
            end
            Presses[x][y] = z
            Grid_Dirty = true
            Screen_Dirty = true
        elseif x >= TRACKS + 2 and x <= TRACKS + PAGES + 1 then
            -- active page pressed
            if z == 0 then
                Page = x - TRACKS - 1
                SubSequins = 0
            end
            Presses[x][y] = z
            Grid_Dirty = true
        elseif x >= TRACKS + PAGES + 3 and x <= TRACKS + PAGES + MODS + 2 then
            -- active mod pressed
            if z == 0 then
                if Mod == x - TRACKS - PAGES - 2 then
                    Mod = 0
                elseif Page <= PAGES then
                    Mod = x - TRACKS - PAGES - 2
                    SubSequins = 0
                end
            end
            Presses[x][y] = z
            Grid_Dirty = true
        elseif x == 16 then
            if z == 0 then
                Page = PAGES + 1
                SubSequins = 0
            end
            Presses[x][y] = z
            Grid_Dirty = true
        end
    elseif Page > PAGES then
        -- metasequencer page
        if not Song_Mode then
            if z == 0 and y == 7 and Presses[16][8] == 1 then
                Song_Mode = true
                Grid_Dirty = true
            elseif y == 1 then
                if z == 0 and Press_Counter[x][y] then
                    clock.cancel(Press_Counter[x][y])
                    Pattern = x
                    for _,track in ipairs(Tracks[Pattern]) do
                        for i = 1, PAGES do
                            track:increment(i, true)
                        end
                    end
                else
                    -- start long press counter
                    Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        else
            if y == 1 then
                if z == 0 and Press_Counter[x][y] then
                    clock.cancel(Press_Counter[x][y])
                    Metatrack.data[Metatrack.selected] = x
                else
                    Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                end
            elseif y == 2 then
                if z == 0 then
                    Metatrack.division = x
                end
            elseif y >= 3 and y <= 6 then
                if z == 0 then
                    local flag = true
                    for i = 1,64 do
                        local j = (i - 1) % 16 + 1
                        local k = i // 16 + 3
                        if Presses[j][k] == 1 and not (j == x and k == y) then
                            -- change bounds
                            if k < y or k == y and j < x then
                                Metatrack.bounds[1] = i
                                Metatrack.bounds[2] = (y - 3) * 16 + x
                            else
                                Metatrack.bounds[1] = (y - 3) * 16 + x
                                Metatrack.bounds[2] = (y - 3) * 16 + x
                            end
                            flag = false
                            break
                        end
                    end
                    if flag then
                        -- select
                        Metatrack.selected = (y - 3) * 16 + x
                    end
                end
            elseif y == 7 then
                if z == 0 then
                    if Presses[16][8] == 1 then
                        Song_Mode = false
                    else
                        Metatrack.lengths[Metatrack.selected] = x
                    end
                end
            end
            Presses[x][y] = z
            Grid_Dirty = true
        end
    elseif Page == 1 and Mod <= 1 then
        -- triggers page
        if Mod == 1 then
            if y <= 4 then
                if z == 0 then
                    local flag = true
                    for i = 1,16 do
                        if Presses[i][y] == 1 and i ~= x then
                            -- set new bounds
                            if i < x then
                                Tracks[Pattern][y].bounds[Page][1] = i
                                Tracks[Pattern][y].bounds[Page][2] = x
                            else
                                Tracks[Pattern][y].bounds[Page][1] = i
                                Tracks[Pattern][y].bounds[Page][2] = i
                            end
                            flag = false
                            break
                        end
                    end
                    if flag then
                        -- move bounds
                        local length = Tracks[Pattern][y].bounds[Page][2] - Tracks[Pattern][y].bounds[Page][1]
                        Tracks[Pattern][y].bounds[Page][1] = x
                        Tracks[Pattern][y].bounds[Page][2] = math.min(x + length, 16)
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
                        local track = Tracks[Pattern][Active_Track]
                        if Presses[1][y] == 1 and 1 ~= x then
                            if x > #track.data[Page][SubSequins] then
                                for i = #track.data[Page][SubSequins], x do
                                    track.data[Page][SubSequins][i] = 0
                                end
                            elseif x < #track.data[Page][SubSequins] then
                                for i = x, #track.data[Page][SubSequins] do
                                    track.data[Page][SubSequins][i] = nil
                                end
                            end
                            flag = false
                        elseif x == 1 then
                            for i = 2,16 do
                                if Presses[i][y] == 1 then
                                    track.data[Page][SubSequins] = track.data[SubSequins][1]
                                    SubSequins = 0
                                    flag = false
                                    break
                                end
                            end
                        end
                        if flag then
                            if x <= #track.data[Page][SubSequins] then
                                track.data[Page][SubSequins][x] = track.data[Page][SubSequins][x] == 1 and 0 or 1
                            end
                        end
                        track:make_sequins(Page)
                    end
                    Presses[x][y] = z
                    Grid_Dirty = true
                end
            elseif y <= 4 then
                -- short press
                if z == 0 and Press_Counter[x][y] then
                    clock.cancel(Press_Counter[x][y])
                    local datum = Tracks[Pattern][y].data[Page][x]
                    Tracks[Pattern][y].data[Page][x] = datum == 0 and 1 or 0
                    Tracks[Pattern][y]:make_sequins(Page)
                -- start long press counter
                else
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
            local track = Tracks[Pattern][Active_Track]
            if z == 0 then
                local flag = true
                for i = 1,16 do
                    if Presses[i][y] == 1 and i ~= x then
                        -- set new bounds
                        if i < x then
                            track.bounds[Page][1] = i
                            track.bounds[Page][2] = x
                        else
                            track.bounds[Page][1] = i
                            track.bounds[Page][2] = i
                        end
                        flag = false
                        break
                    end
                end
                if flag then
                    -- move bounds
                    local length = track.bounds[Page][2] - track.bounds[Page][1]
                    track.bounds[Page][1] = x
                    track.bounds[Page][2] = math.min(x + length, 16)
                end
            end
            Presses[x][y] = z
            Grid_Dirty = true
        elseif Mod == 2 then
            -- Division mod
            local track = Tracks[Pattern][Active_Track]
            if y == 2 then
                if z == 0 then
                    track.divisions[Page] = x
                    if Page <= 4 then 
                        track.patterns[Page]:set_division(track.divisions[Page] / 16)
                    elseif Page == 5 then
                        track.patterns[Page]:set_division(track.divisions[Page] / (16 * 12))
                    end
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        elseif Mod == 3 then
            -- Probability mod
            local track = Tracks[Pattern][Active_Track]
            if y >= 3 then
                if z == 0 then
                    track.probabilities[Page][x] = 7 - y
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        elseif Mod == 0 then
            -- normal page view
            if SubSequins > 0 then
                local track = Tracks[Pattern][Active_Track]
                if Page == 2 or (Page == 3 and not track.transpose_mode)
                    or (Page <= 4 and y >= 3)
                    or (Page == 5 and y >= 4) then
                    if z == 0 then
                        local flag = true
                        if Presses[1][y] == 1 and 1 ~= x then
                            if x > #track.data[Page][SubSequins] then
                                for i = #track.data[Page][SubSequins], x do
                                    local value = 1
                                    if Page == 3 and track.transpose_mode then
                                        value = 3
                                    elseif Page == 4 then
                                        value = 5
                                    elseif Page == 5 then
                                        value = 4
                                    end
                                    track.data[Page][SubSequins][i] = value
                                end
                            elseif x < #track.data[Page][SubSequins] then
                                for i = x, #track.data[Page][SubSequins] do
                                    track.data[Page][SubSequins][i] = nil
                                end
                            end
                            flag = false
                        elseif x == 1 then
                            for i = 2,16 do
                                if Presses[i][y] == 1 then
                                    track.data[Page][SubSequins] = track.data[SubSequins][1]
                                    SubSequins = 0
                                    flag = false
                                    break
                                end
                            end
                        end
                        if flag then
                            if x <= #track.data[Page][SubSequins] then
                                if Page <= 4 then
                                    track.data[Page][SubSequins][x] = 8 - y
                                elseif Page == 5 then
                                    local datum = track.data[Page][SubSequins][x]
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
                        track:make_sequins(Page)
                    end
                    Presses[x][y] = z
                    Grid_Dirty = true
                end
            elseif Page == 2 or (Page == 3 and not(Tracks[Pattern][Active_Track].transpose_mode)) then
                -- sample or coarse sample page
                -- short press
                if z == 0 and Press_Counter[x][y] then
                    clock.cancel(Press_Counter[x][y])
                    Tracks[Pattern][Active_Track].data[Page][x] = 8 - y
                    Tracks[Pattern][Active_Track]:make_sequins(Page)
                -- start long press counter
                else
                    Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                end
                Presses[x][y] = z
                Grid_Dirty = true
            elseif Page <= 4 then
                -- other pages
                if y >= 3 then
                    -- short press
                    if z == 0 and Press_Counter[x][y] then
                        clock.cancel(Press_Counter[x][y])
                        Tracks[Pattern][Active_Track].data[Page][x] = 8 - y
                        Tracks[Pattern][Active_Track]:make_sequins(Page)
                    -- start long press counter
                    else
                        Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                    end
                    Presses[x][y] = z
                    Grid_Dirty = true
                end
            elseif Page == 5 then
                -- ratchet page
                if y >= 3 then
                    -- short press
                    if z == 0 and Press_Counter[x][y] then
                        clock.cancel(Press_Counter[x][y])
                        local datum = Tracks[Pattern][Active_Track].data[Page][x]
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
                        Tracks[Pattern][Active_Track].data[Page][x] = datum
                        Tracks[Pattern][Active_Track]:make_sequins(Page)
                    -- start long press counter
                    else
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
    -- a long press is a second
    clock.sleep(1)
    Press_Counter[x][y] = nil
    if y == 8 or Mod > 0 or SubSequins > 0 then
        return
    elseif Page > PAGES and y == 1 then
        if not Song_Mode then
            for i = 1, TRACKS do
                Tracks[x][i]:copy(Tracks[Pattern][i])
            end
        else
            for i = 1, TRACKS do
                Tracks[x][i]:copy(Tracks[Pattern][i])
            end
        end
        Pattern = x
        Grid_Dirty = true
    elseif Page == 1 and y <= 4 then
        Active_Track = y
        SubSequins = x
        Presses[x][y] = 0
        Grid_Dirty = true
    elseif Page == 2 or (Page == 3 and not Tracks[Pattern][Active_Track].transpose_mode) then
        SubSequins = x
        Grid_Dirty = true
    elseif Page <= 4 and y >= 3 then
        SubSequins = x
        Grid_Dirty = true
    elseif Page == 5 and y >= 4 then
        SubSequins = x
        Grid_Dirty = true
    end
end

-- Track functions
Track = {}

function Track.new(id, transpose_mode, data, probabilities, divisions, lattice)
    local t = setmetatable({}, { __index = Track})
    t.id = id
    t.data = data
    t.probabilities = probabilities
    t.divisions = divisions
    t.transpose_mode = transpose_mode
    t.sample_id = 0
    t.bounds = {}
    t.sequins = {}
    t.patterns = {}
    t.indices = {}
    t.values = {}
    t.ratchet_counter = 0
    for i = 1, PAGES do
        t.bounds[i] = {1,6}
        t.indices[i] = 0
        t.sequins[i] = sequins(data[i])
        t.sequins[i]:select(1)
        if i ~= 5 then
            t.patterns[i] = lattice:new_pattern{
                division = divisions[i] / 16,
                action = function()
                    t:increment(i)
                    if Page == 1 and Pattern == t.id[1] then
                        Grid_Dirty = true
                    elseif Page == i and Active_Track == t.id[2] and Pattern == t.id[1] then
                        Grid_Dirty = true
                    end
                end
            }
        elseif i == 5 then
            t.patterns[5] = lattice:new_pattern{
                division = divisions[i] / (12 * 16),
                action = function()
                    t.ratchet_counter = t.ratchet_counter % 12 + 1
                    if t.ratchet_counter == 1 then
                        t:increment(5)
                    end
                    local ratchet_div = 12 / ((t.values[5] & 3) + 1)
                    local ratchets = t.values[5] >> 2
                    if t.ratchet_counter % ratchet_div == 1 then
                        local step = 2 ^ ((t.ratchet_counter - 1) / ratchet_div)
                        if step & ratchets == step and Pattern == t.id[1] and t.values[1] == 1 then
                            t:play_note()
                        end
                        Grid_Dirty = true
                    end
                end
            }
        end
        t.values[i] = t.sequins[i][1]
    end
    return t
end

function Track:copy(track)
    for i = 1, PAGES do
        self.divisions[i] = track.divisions[i]
        for j = 1,16 do
            self.probabilities[i][j] = track.probabilities[i][j]
            if type(track.data[i][j]) ~= 'number' then
                self.data[i][j] = {}
                for k = 1,#track.data[i][j] do
                    self.data[i][j][k] = track.data[i][j][k]
                end
            else
                self.data[i][j] = track.data[i][j]
            end
        end
        for j = 1,2 do
            self.bounds[i][j] = track.bounds[i][j]
        end
        self.indices[i] = track.indices[i]
        self:make_sequins(i)
    end
    self.transpose_mode = track.transpose_mode
    self.ratchet_counter = track.ratchet_counter
end

function Track:make_sequins(i)
    local s = {}
    for j = 1,16 do
        if type(self.data[i][j]) ~= 'number' then
            s[j] = sequins(self.data[i][j])
        else
            s[j] = self.data[i][j]
        end
    end
    self.sequins[i]:settable(s)
end

function Track:increment(i, reset)
    if reset or self.indices[i] + 1 > self.bounds[i][2] or self.indices[i] + 1 < self.bounds[i][1] then
        self.indices[i] = self.bounds[i][1]
    else
        self.indices[i] = self.indices[i] + 1
    end
    self.sequins[i]:select(self.indices[i])
    local r = math.random()
    if r <= self.probabilities[i][self.indices[i]] / 4 then
        self.values[i] = self.sequins[i]()
    end
end

function Track:play_note()
    local note = 60
    if self.transpose_mode then
        note = note_nums[self.values[2]] + 12 * (self.values[3] - 3)
    end
    local id = (self.id[2] - 1) * 64
    if not(self.transpose_mode) then
        id = id + self.values[2] - 1 + 7 * (self.values[3] - 1)
    else
        id = id + self.sample_id
    end
    if Timber.samples_meta[id].num_frames > 0 then
        engine.noteOn(self.id[2], MusicUtil.note_num_to_freq(note), Velocities[self.values[4]], id)
    end
end

function Track:set_sample_id(id)
    self.sample_id = id
    while self.sample_id >= 64 do self.sample_id = self.sample_id - 64 end
    while self.sample_id < 0 do self.sample_id = self.sample_id + 64 end
end

function Metatrack:increment()
    if self.index + 1 > self.lengths[self.current] then
        self.index = 1
        if self.current + 1 > self.bounds[2] or self.current + 1 < self.bounds[1] then
            self.current = self.bounds[1]
            Pattern = self.data[self.current]
        else
            self.current = self.current + 1
            Pattern = self.data[self.current]
        end
        for _,track in ipairs(Tracks[Pattern]) do
            for i = 1, PAGES do
                track:increment(i, true)
            end
        end
        Grid_Dirty = true
    else
        self.index = self.index + 1
    end
end
