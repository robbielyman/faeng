-- faeng is a sequencer
-- inspired by kria
-- powerd by timber
-- connect a grid
-- and take wing
--
-- v 0.3.1
-- llllllll.co/t/faeng-is-a-sequencer/

engine.name = "Timber"

Timber = include("lib/timber_guts")
local sequins = require("sequins")
local Lattice = require("lattice")
local MusicUtil = require("musicutil")
local UI = require("ui")
local Arc_Guts = include("lib/arc_guts")
local Pattern_Time = require("pattern_time")

TRACKS = 7
PAGES = 5
Page = 0
Alt_Page = false
Pattern = 1
MODS = 3
Mod = 0
SCREENS = 7
SubSequins = 0
Tracks = {}
Active_Track = 1
Grid_Dirty = true
Screen_Dirty = true
Scale_Names = {}
for i = 1, #MusicUtil.SCALES do
  table.insert(Scale_Names, MusicUtil.SCALES[i].name)
end
Velocities = {0.1, 0.2, 0.3, 0.6, 1.0}
Freqs = {0.25, 0.5, 1.0, 1.5, 2.0}
Pans = {-1, -0.5, -0.25, 0, 0.25, 0.5, 1}
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
        local patterns = {}
        for j = 1, 4 do
            patterns[j] = Pattern_Time.new()
            patterns[j]:set_overdub(1)
            patterns[j].process = function(event)
                params:set(event.prefix .. event.id, event.val)
            end
        end
        for j = 1, 2*PAGES do
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
                elseif j == 4 or j == 9 then
                    -- octaves
                    -- filter
                    for k = 1,16 do
                        data[j][n][k] = 3
                    end
                elseif j == 6 then
                    -- velocities
                    for k=1,16 do
                        data[j][n][k] = 5
                    end
                elseif j == 5 then
                    -- ratchets
                    -- pan
                    for k = 1,16 do
                        data[j][n][k] = 4
                    end
                else
                    -- sample
                    -- note
                    -- slice
                    -- alt note
                    for k = 1,16 do
                        data[j][n][k] = 1
                    end
                end
            end
        end
        Tracks[i] = Track.new(i, data, lattice, divisions, probabilities, lengths, false, patterns)
    end
    local data = {}
    local probabilities = {}
    local lengths = {}
    for k = 1,16 do
        data[k] = 1
        probabilities[k] = 4
        lengths[k] = 4
    end
    Tracks[TRACKS + 1] = Track.pattern_new(data, lattice, 4, probabilities, lengths)
    -- params!
    params.action_read = function(_,_,number)
        local tracks_data = tab.load(_path.data .. "/faeng/pset_track_data_" .. number .. ".data")
        import_tracks(tracks_data)
    end
    params.action_write = function(_,_,number)
        if not util.file_exists(_path.data .. "/faeng") then
            util.os_capture(_path.data .. "/faeng")
        end
        tab.save(export_tracks(), _path.data .. "/faeng/pset_track_data_" .. number .. ".data")
    end
    params.action_delete = function(_,_,number)
        if util.file_exists(_path.data .. "/faeng/pset_track_data_" .. number .. ".data") then
            util.os_capture("rm " .. _path.data .. "/faeng/pset_track_data_" .. number .. ".data")
        end
    end
    -- Grid setup
    Grid = grid.connect()
    Grid.key = grid_key
    grid_arc_redraw_metro = metro.init()
    grid_arc_redraw_metro.event = function()
        if Grid.device and Grid_Dirty then
            grid_redraw()
        end
        Arc:redraw()
    end
    local dance_counter = 0
    Reset_Flag = 0
    lattice:new_pattern{
        division = 1/32,
        action = function()
            dance_counter = dance_counter % 4 + 1
            if dance_counter == 1 then
                Dance_Index = Dance_Index % 16 + 1
            end
            if dance_counter % 2 == 0 and Reset_Flag > 0 then
                Tracks[TRACKS + 1]:increment(-1, nil, true)
                Tracks[TRACKS + 1].patterns:stop()
                for i = 1,TRACKS do
                    for j = 1,PAGES do
                        Tracks[i].patterns[j]:stop()
                        Tracks[i]:increment(j, Pattern, true)
                    end
                end
                Reset_Flag = -1
            elseif dance_counter % 2 == 1 and Reset_Flag < 0 then
                Tracks[TRACKS + 1].patterns:start()
                for i = 1,TRACKS do
                    for j = 1,PAGES do
                        Tracks[i].patterns[j]:start()
                    end
                end
                Reset_Flag = 0
            end
            Grid_Dirty = true
        end
    }
    -- UI setup
    Screens = UI.Pages.new(1, 7)
    screen_redraw_metro = metro.init()
    screen_redraw_metro.event = function()
        if Screen_Dirty then
            redraw()
            update()
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
    Timber.add_params()
    params:add_separator("arc")
    Arc = Arc_Guts.new()
    Arc_Params = {
        "start_frame_1_",
        "end_frame_1_",
        "start_frame_2_",
        "end_frame_2_",
        "start_frame_3_",
        "end_frame_3_",
        "start_frame_4_",
        "end_frame_4_",
        "start_frame_5_",
        "end_frame_5_",
        "start_frame_6_",
        "end_frame_6_",
        "start_frame_7_",
        "end_frame_7_",
        "filter_freq_",
        "filter_resonance_",
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
    }
    Arc_Params.OPTIONS = {
        "start frame 1",
        "end frame 1",
        "start frame 2",
        "end frame 2",
        "start frame 3",
        "end frame 3",
        "start frame 4",
        "end frame 4",
        "start frame 5",
        "end frame 5",
        "start frame 6",
        "end frame 6",
        "start frame 7",
        "end frame 7",
        "filter freq",
        "filter resonance",
        "pan",
        "amp",
        "amp env attack",
        "amp env decay",
        "amp env sustain",
        "amp env release",
        "mod env attack",
        "mod env decay",
        "mod env sustain",
        "mod env release"
    }
    Arc_Params.DEFAULTS = {1, 2, 18, 15, 23, 24, 25, 26}
    for i = 1, 4 do
        params:add{
            type    = "option",
            id      = "arc_ring_" .. i,
            name    = "arc ring " .. i,
            options = Arc_Params.OPTIONS,
            default = Arc_Params.DEFAULTS[i]
        }
    end
    for i = 1, 4 do
        params:add{
            type    = "option",
            id      = "arc_ring_shift_" .. i,
            name    = "shift arc ring " .. i,
            options = Arc_Params.OPTIONS,
            default = Arc_Params.DEFAULTS[4 + i]
        }
    end
    for i = 0, TRACKS * 7 - 1 do
        Timber.add_sample_params(i)
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
    Timber.views_changed_callback = callback_screen
    Timber.sample_changed_callback = callback_sample
    Timber.watch_param_callback = callback_watch
    screen_redraw_metro:start(1/15)
    grid_arc_redraw_metro:start(1/25)
    screen.aa(1)
    lattice:start()
end

function Arc_Guts:get_param(i)
    if self.shift_mode then
        return params:lookup_param(Arc_Params[params:get("arc_ring_shift_" .. i)] .. get_current_sample())
    else
        return params:lookup_param(Arc_Params[params:get("arc_ring_" .. i)] .. get_current_sample())
    end
end

function callback_watch(id, prefix, x)
    local event = {
        id = id,
        prefix = prefix,
        val = x
    }
    local track = id // 7 + 1
    for i = 1, 4 do
        Tracks[track].pattern_times[i]:watch(event)
    end
end

function callback_sample(id)
   -- if Timber.samples_meta[id].manual_load and
   --     Timber.samples_meta[id].streaming == 0 and
   --     Timber.samples_meta[id].num_frames / Timber.samples_meta[id].sample_rate < 1 and
   --     string.find(string.lower(params:get("sample_" .. id)), "loop") == nil then
   --     params:set("play_mode_" .. id, 3)
   -- end
end

function callback_screen(id)
    -- if not(id) or id == Tracks[Active_Track].sample_id then
        Screen_Dirty = true
    -- end
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
    if Timber.file_select_active then
        Timber.FileSelect.redraw()
        return
    end
    Screens:redraw()
    if Screens.index == 1 then
        Sample_Setup_View:redraw()
    elseif Screens.index == 2 then
        Waveform_View:redraw()
    elseif Screens.index == 3 then
        Filter_Amp_View:redraw()
    elseif Screens.index == 4 then
        Amp_Env_View:redraw()
    elseif Screens.index == 5 then
        Mod_Env_View:redraw()
    elseif Screens.index == 6 then
        LFOs_View:redraw()
    elseif Screens.index == 7 then
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
        end
    else
        if Screens.index == 1 then
            Sample_Setup_View:enc(n, d)
        elseif Screens.index == 2 then
            Waveform_View:enc(n, d)
        elseif Screens.index == 3 then
            Filter_Amp_View:enc(n, d)
        elseif Screens.index == 4 then
            Amp_Env_View:enc(n, d)
        elseif Screens.index == 5 then
            Mod_Env_View:enc(n, d)
        elseif Screens.index == 6 then
            LFOs_View:enc(n, d)
        elseif Screens.index == 7 then
            Mod_Matrix_View:enc(n, d)
        end
    end
    Screen_Dirty = true
end

function key(n, z)
    Arc:key(n, z)
    Keys[n] = z
    if n == 1 then
        Timber.shift_mode = Keys[1] == 1
    end
    if Screens.index == 1 then
        Sample_Setup_View:key(n, z)
    elseif Screens.index == 2 then
        Waveform_View:key(n, z)
    elseif Screens.index == 3 then
        Filter_Amp_View:key(n, z)
    elseif Screens.index == 4 then
        Amp_Env_View:key(n, z)
    elseif Screens.index == 5 then
        Mod_Env_View:key(n, z)
    elseif Screens.index == 6 then
        LFOs_View:key(n, z)
    elseif Screens.index == 7 then
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
    for x = 1,PAGES do
        if Alt_Page then
            Grid:led(x + 5, 8, x == Page and Dance_Index % 2 == 1 and 15 or 9)
        else
            Grid:led(x + 5, 8, x == Page and 15 or 9)
        end
    end

    -- mods
    for x = 1,MODS do
        Grid:led(x + 5 + PAGES + 1, 8, x == Mod and Dance_Index % 2 == 1 and 15 or 9)
    end

    -- pattern page
    Grid:led(16, 8, Page == -1 and 15 or 9)

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
            if Presses[x][y] == 1 and Press_Counter[x][y] then
                Grid:led(x,y,15)
            else
                Grid:led(x,y,Dance_Index % 2 == 1 and 15 or 9)
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
            elseif Page == -1 and track.indices[Page] == x then
                Grid:led(x, 7 - value, 15)
            end
        end
    end
end

function page_view()
    if Page == 0 then
        -- tracks page
        tracks_view()
    elseif Page == -1 then
        -- pattern page
        patterns_view()
    elseif Page == 1 then
        if Alt_Page then
            -- velocities page
            regular_view(function(x, datum, check)
                if datum < 5 then
                    for i = 5, datum + 1, -1 do
                        Grid:led(x, 8 - i, check and 9 or 4)
                    end
                end
            end)
        else
            -- triggers page
            triggers_view()
        end
    elseif Page == 2 then
        if Alt_Page then
            -- sample loc page
            regular_view()
        else
            -- sample page
            regular_view()
        end
    elseif Page == 3 then
        if Alt_Page then
            -- alt note page
            regular_view()
        else
            -- note page
            regular_view()
        end
    elseif Page == 4 then
        if Alt_Page then
            -- filter page
            regular_view()
        else
            -- octave page
            regular_view(function(x, datum, check)
                if datum > 3 then
                    for i = 3, datum - 1 do
                        Grid:led(x, 8 - i, check and 9 or 4)
                    end
                elseif datum < 2 then
                    for i = 2, datum + 1, -1 do
                        Grid:led(x, 8 - i, check and 9 or 4)
                    end
                end
            end)
        end
    elseif Page == 5 then
        if Alt_Page then
            -- pan page
            regular_view(function(x, datum, check)
                if datum > 4 then
                    for i = 4, datum - 1 do
                        Grid:led(x, 8 - i, check and 9 or 4)
                    end
                elseif datum < 3 then
                    for i = 3, datum + 1, -1 do
                        Grid:led(x, 8 - i, check and 9 or 4)
                    end
                end
            end)
        else
            ratchet_view()
        end
    end
end

function tracks_view()
    Grid:(16, 1, 4)
    for y = 1, 7 do
        Grid:led(3, y, 4)
        Grid:led(2, y, Tracks[y].muted and 4 or 9)
        if Active_Track == y then
            Grid:led(1, y, Tracks[y].values[1][Pattern] == 1 and 15 or 12)
        else
            Grid:led(1, y, Tracks[y].values[1][Pattern] == 1 and 9 or 4)
        end
        for x = 4, 7 do
            local i = x - 3
            if Tracks[y].pattern_times[i].play == 1 then
                Grid:led(x, y, Dance_Index % 2 == 1 and 15 or 9)
            elseif Tracks[y].pattern_times[i].rec == 1 then
                Grid:led(x, y, 15)
            else
                Grid:led(x, y, 2)
            end
        end
    end
end

function patterns_view()
    for x = 1, 16 do
        Grid:led(x, 1, 4)
    end
    local track = Tracks[TRACKS + 1]
    local left = track.bounds[1]
    local right = track.bounds[2]

    if SubSequins > 0 then
        if type(track.data[SubSequins]) == 'number' then
            track.data[SubSequins] = {track.data[SubSequins]}
            track:make_sequins(-1)
        end
        local datum = track.data[SubSequins]
        for x = 1,#datum do
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
        local datum = track.data[track.selected]
        if type(datum) == 'number' then
            Grid:led(datum, 1, 9)
        else
            Grid:led(datum[Dance_Index % #datum + 1], 1, 9)
        end
        Grid:led(Pattern, 1, 15)
        for x = 1, 16 do
            local check = x >= left and x <= right
            Grid:led(x, 4, check and 9 or 4)
        end
        Grid:led(track.selected, 4, 12)
        Grid:led(track.indices, 4, 15)

        for x = 1, track.lengths[Pattern] do
            Grid:led(x, 6, 4)
        end

        Grid:led(track.lengths[Pattern], 6, 9)
        Grid:led(track.lengths[track.selected], 6, 12)
        Grid:led(track.counter, 6, 15)
    end
end

function triggers_view()
    local track = Tracks[Active_Track]
    local left  = track.bounds[Page][Pattern][1]
    local right = track.bounds[Page][Pattern][2]

    if SubSequins > 0 then
        if type(track.data[Page][Pattern][SubSequins]) == 'number' then
            track.data[Page][Pattern][SubSequins] = {track.data[Page][Pattern][SubSequins]}
            track:make_sequins(Page, Pattern)
        end
        local datum = track.data[Page][Pattern][SubSequins]
        for x = 1, #datum do
            Grid:led(x, 6, datum[x] == 1 and 9 or 2)
        end
        Grid:led(SubSequins, 2, Dance_Index % 2 == 1 and 15 or 0)
    end
    for x = 1, 16 do
        local datum = track.data[Page][Pattern][x]
        datum = type(datum) == 'number' and datum or datum[Dance_Index % #datum + 1]
        local check = x >= left and x <= right
        if datum == 1 then
            Grid:led(x, 2, check and 9 or 4)
        else
            Grid:led(x, 2, check and 2 or 0)
        end
    end
    Grid:led(track.indices[Page][Pattern], 2, 15)
end

function regular_view(hook)
    local track = Tracks[Active_Track]
    local page  = Page + Alt_Page and PAGES or 0
    local left  = track.bounds[page][Pattern][1]
    local right = track.bounds[page][Pattern][1]

    if SubSequins > 0 then
        if type(track.data[page][Pattern][SubSequins]) == 'number' then
            track.data[page][Pattern][SubSequins] = {track.data[page][Pattern][SubSequins]}
            track:make_sequins(page, Pattern)
        end
        local datum = track.data[page][Pattern][SubSequins]
        for x = 1, #datum do
            if hook then
                hook(x, datum[x], true)
            end
            Grid:led(x, 8 - datum[x], 9)
        end
    else
        for x = 1, 16 do
            local datum = track.data[Page][Pattern][x]
            datum = type(datum) == 'number' and datum or datum[Dance_Index % #datum + 1]
            local check = x >= left and x <= right
            if hook then
                hook(x, datum[x], check)
            end
            if track.indices[Page][Pattern] == x then
                Grid:led(x, 8 - datum, 15)
            else
                Grid:led(x, 8 - datum, check and 9 or 4)
            end
        end
    end
end

function ratchet_view()
    local track = Tracks[Active_Track]
    local left  = track.bounds[Page][Pattern][1]
    local right = track.bounds[Page][Pattern][2]

    if SubSequins > 0 then
        if type(track.data[Page][Pattern][SubSequins]) == 'number' then
            track.data[Page][Pattern][SubSequins] = {track.data[Page][Pattern][SubSequins]}
            track:make_sequins(Page, Pattern)
        end
        local datum = track.data[Page][Pattern][SubSequins]
        for x = 1, #datum do
            local ratchet_amount = datum[x] & 3
            local ratchets = datum[x] >> 2
            for i = 0, ratchet_amount do
                if ratchets & 2^i == 2^i then
                    Grid:led(x, 7 - i, 9)
                end
            end
        end
    else
        for x = 1, 16 do
            local datum = track.data[Page][Pattern][x]
            datum = type(datum) == 'number' and datum or datum[Dance_Index % #datum + 1]
            local check = x >= left and x <= right
            local ratchet_amount = datum & 3
            local ratchets = datum >> 2
            for i = 0, ratchet_amount do
                if ratchets & 2^i == 2^i then
                    Grid:led(x, 7 - i, check and 9 or 4)
                end
            end
            if track.indices[Page][Pattern] == x then
                local out_of_twelve = (track.counter - 1) % 12 + 1
                local i = out_of_twelve // (12 / (ratchet_amount + 1))
                if ratchets & 2^i == 2^i then
                    Grid:led(x, 7 - i, 15)
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
                    Alt_Page = false
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
        elseif x >= 5 + 1 and x <= 5 + PAGES then
            -- active page pressed
            if z == 0 then
                if Page == x - 5 then
                    -- toggle alt page
                    Alt_Page = not Alt_Page
                end
                Page = x - 5
                SubSequins = 0
            end
            Presses[x][y] = z
            Grid_Dirty = true
        elseif x >= 5 + PAGES + 1 + 1 and x <= 5 + PAGES + 1 + 3 then
            -- active mod pressed
            if z == 0 then
                if Mod == x - (5 + PAGES + 1) then
                    Mod = 0
                elseif Page > 0 then
                    Mod = x - (5 + PAGES + 1)
                    SubSequins = 0
                end
            end
            Presses[x][y] = z
            Grid_Dirty = true
        end
        return
    end
    if Page == 0 then
        -- tracks page
        tracks_key(x, y, z)
    elseif Mod == 2 then
        -- division mod
        division_key(x, y, z)
    elseif Mod == 3 then
        -- probability mod
        probability_key(x, y, z)
    elseif Page == -1 then
        -- pattern page
        patterns_key(x, y, z)
    elseif Page == 1 then
        if Alt_Page then
            -- velocities page
            regular_key(x, y, z, 5, 2)
        else
            -- triggers page
            triggers_key(x, y, z)
        end
    elseif Page == 2 then
        if Alt_Page then
            -- slices page
            regular_key(x, y, z, 1, 1)
        else
            -- sample page
            regular_key(x, y, z, 1, 1)
        end
    elseif Page == 3 then
        if Alt_Page then
            -- alt note page
            regular_key(x, y, z, 1, 1)
        else
            -- note page
            regular_key(x, y, z, 1, 1)
        end
    elseif Page == 4 then
        if Alt_Page then
            -- filter page
            regular_key(x, y, z, 3, 3)
        else
            -- octave page
            regular_key(x, y, z, 3, 3)
        end
    elseif Page == 5 then
        if Alt_Page then
            -- pan page
            regular_key(x, y, z, 4, 1)
        else
            -- ratchet page
            ratchet_key(x, y, z)
        end
    end
    if z == 0 then
        Presses[x][y] = z
    end
end

function tracks_key(x, y, z)
    if x == 1 then
        -- select track
        if z == 0 then
            Active_Track = y
            set_sample_id()
        end
        Presses[x][y] = z
        Grid_Dirty = true
    elseif x == 2 then
        -- mute/unmute track
        if z == 0 then
            Tracks[y].muted = not Tracks[y].muted
        end
        Presses[x][y] = z
        Grid_Dirty = true
    elseif x == 3 then
        -- reset track
        if z == 0 then
            for i = 1, 2 * PAGES do
                Tracks[y]:increment(i, Pattern, true)
            end
        end
        Presses[x][y] = z
        Grid_Dirty = true
    elseif x >= 4 and x <= 7 then
        -- pattern recorders
        if z == 0 and Press_Counter[x][y] then
            local i = x - 3
            clock.cancel(Press_Counter[x][y])
            if Tracks[y].pattern_times[i].play == 0 and Tracks[y].pattern_times[i].rec == 0 then
                -- first record
                if Tracks[y].pattern_times[i].count ~= 0 then
                    Tracks[y].pattern_times[i]:play()
                end
                Tracks[y].pattern_times[i]:rec_start()
            elseif Tracks[y].pattern_times[i].rec == 1 then
                -- then play
                Tracks[y].pattern_times[i]:rec_stop()
            elseif Tracks[y].pattern_times[i].play == 1 then
                -- then stop
                Tracks[y].pattern_times[i]:stop()
            end
        elseif z == 1 then
            Press_Counter[x][y] = clock.run(grid_long_press, x, y)
        end
        Presses[x][y] = z
        Grid_Dirty = true
    end
end

function patterns_key(x, y, z)
    if Mod == 1 then
        if y == 4 then
            if z == 0 then
                local flag = true
                for i = 1,16 do
                    if Presses[i][y] == 1 and i ~= x then
                        -- set new bounds
                        if i < x then
                            Tracks[TRACKS + 1].bounds[1] = i
                            Tracks[TRACKS + 1].bounds[2] = x
                        else
                            Tracks[TRACKS + 1].bounds[1] = x
                            Tracks[TRACKS + 1].bounds[2] = x
                        end
                        flag = false
                        break
                    end
                end
                if flag then
                    -- move bounds
                    local length = Tracks[TRACKS + 1].bounds[2] - Tracks[TRACKS + 1].bounds[1]
                    Tracks[TRACKS + 1].bounds[1] = x
                    Tracks[TRACKS + 1].bounds[2] = math.min(x + length, 16)
                end
            end
            Presses[x][y] = z
            Grid_Dirty = true
        end
    else
        -- Mod == 0
        if SubSequins > 0 then
            if y == 4 then
                if z == 0 then
                    local flag = true
                    if Presses[1][y] == 1 and 1 ~= x then
                        -- alter SubSequins length
                        if x > Tracks[TRACKS + 1].data[SubSequins] then
                            for i = #Tracks[TRACKS + 1].data[SubSequins], x do
                                Tracks[TRACKS + 1].data[SubSequins][i] = 1
                            end
                        elseif x < #Tracks[TRACKS + 1].data[SubSequins] then
                            for i = x + 1, #Tracks[TRACKS + 1].data[SubSequins] do
                                Tracks[TRACKS + 1].data[SubSequins][i] = nil
                            end
                        end
                        flag = false
                    elseif x == 1 then
                        for x = 2,16 do
                            -- remove SubSequins, exit SubSequins mode
                            if Presses[i][y] == 1 then
                                Tracks[TRACKS + 1].data[SubSequins] = Tracks[TRACKS + 1].data[SubSequins][1]
                                SubSequins = 0
                                flag = false
                                break
                            end
                        end
                    end
                    if flag then
                        -- select
                        if x <= #Tracks[TRACKS + 1].data[SubSequins] then
                            Tracks[TRACKS + 1].selected = x
                        end
                    end
                    Tracks[TRACKS+1]:make_sequins(-1)
                end
                Presses[x][y] = z
                Grid_Dirty = true
            elseif y == 1 then
                if z == 0 then
                    -- set selection
                    Tracks[TRACKS + 1].data[SubSequins][track.selected] = x
                    Tracks[TRACKS + 1]:make_sequins(-1)
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        else
            -- SubSequins == 0
            if y == 1 then
                if z == 0 and Press_Counter[x][y] then
                    clock.cancel(Press_Counter[x][y])
                    Tracks[TRACKS + 1].data[Tracks[TRACKS + 1].selected] = x
                    Tracks[TRACKS + 1]:make_sequins(-1)
                elseif z == 1 then
                    Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                end
                Presses[x][y] = z
                Grid_Dirty = true
            elseif y == 4 then
                if z == 0 and Press_Counter[x][y] then
                    -- select
                    clock.cancel(Press_Counter[x][y])
                    Tracks[TRACKS + 1].selected = x
                elseif z == 1 then
                    Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        end
    end
end

function triggers_key(x, y, z)
    local track = Tracks[Active_Track]
    if Mod == 1 then
        if y == 2 then
            if z == 0 then
                local flag = true
                for i = 1, 16 do
                    if Presses[i][y] == 1 and i ~= x then
                        -- set new bounds
                        if i < x then
                            track.bounds[Page][Pattern][1] = i
                            track.bounds[Page][Pattern][2] = x
                        else
                            track.bounds[Page][Pattern][1] = x
                            track.bounds[Page][Pattern][2] = x
                        end
                        flag = false
                        break
                    end
                end
                if flag then
                    -- move bounds
                    local length = track.bounds[Page][Pattern][2] - track.bounds[Page][Pattern][1]
                    track.bounds[Page][Pattern][1] = x
                    track.bounds[Page][Pattern][2] = math.min(x + length, 16)
                end
            end
            Presses[x][y] = z
            Grid_Dirty = true
        end
    else
        -- Mod == 0
        if SubSequins > 0 then
            if y == 6 then
                if z == 0 then
                    local flag = true
                    if Presses[1][y] == 1 and 1 ~= x then
                        -- alter SubSequins length
                        if x > #track.data[Page][Pattern][SubSequins] then
                            for i = #track.data[Page][Pattern][SubSequins], x do
                                track.data[Page][Pattern][SubSequins][i] = 0
                            end
                        elseif x < #track.data[Page][Pattern][SubSequins] then
                            for i = x + 1, #track.data[Page][Pattern][SubSequins] do
                                track.data[Page][Pattern][SubSequins][i] = nil
                            end
                        end
                        flag = false
                    elseif x == 1 then
                        for i = 2,16 do
                            -- remove SubSequins, exit SubSequins mode
                            if Presses[i][y] == 1 then
                                track.data[Page][Pattern][SubSequins] = track.data[Page][Pattern][SubSequins][1]
                                SubSequins = 0
                                flag = false
                                break
                            end
                        end
                    end
                    if flag then
                        -- toggle state
                        if x <= #track.data[Page][Pattern][SubSequins] then
                            track.data[Page][Pattern][SubSequins][x] = track.data[Page][Pattern][SubSequins][x] == 1 and 0 or 1
                        end
                    end
                    track:make_sequins(Page, Pattern)
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        elseif y == 2 then
            -- SubSequins == 0
            if z == 0 and Press_Counter[x][y] then
                -- short press
                -- remove any SubSequins and toggle step
                clock.cancel(Press_Counter[x][y])
                local datum = track.data[Page][Pattern][x]
                track.data[Page][Pattern][x] = datum == 0 and 1 or 0
                track:make_sequins(Page, Pattern)
            elseif z == 1 then
                -- start long press counter
                Press_Counter[x][y] = clock.run(grid_long_press, x, y)
            end
            Presses[x][y] = z
            Grid_Dirty = true
        end
    end
end

function division_key(x, y, z)
    local track = Tracks[Active_Track]
    local page = Page + Alt_Page and PAGES or 0
    if y == 2 then
        if z == 0 then
            if Page == -1 then
                -- set division for patterns
                Tracks[TRACKS + 1].divisions = x
                Tracks[TRACKS + 1].patterns:set_division(Tracks[TRACKS + 1].divisions / 16)
            else
                -- set division for track
                track.divisions[page][Pattern] = x
                track:update(page)
            end
        end
        Presses[x][y] = z
        Grid_Dirty = true
    elseif y == 4 then
        if z == 0 then
            -- set swing
            if page ~= 5 and Page ~= -1 then
                -- well, except for ratchet and patterns
                track.swings[page][Pattern] = x
                track:update(page)
            end
        end
        Presses[x][y] = z
        Grid_Dirty = true
    end
end

function probability_key(x, y, z)
    local track = Tracks[Active_Track]
    local page = Page + Alt_Page and PAGES or 0
    if y >= 3 then
        if z == 0 then
            -- set probability
            if Page == -1 then
                Track[TRACKS + 1].probabilities[x] = 7 - y
            else
                track.probabilities[page][Pattern][x] = 7 - y
            end
        end
        Presses[x][y] = z
        Grid_Dirty = true
    end
end

function regular_key(x, y, z, default, min)
    local track = Tracks[Active_Track]
    local page = Page + Alt_Page and PAGES or 0
    if Mod == 1 then
        -- Loop mod
        if z == 0 then
            local flag = true
            for i = 1, 16 do
                if Presses[i][y] == 1 and i ~= x then
                    -- set new bounds
                    if i < x then
                        track.bounds[page][Pattern][1] = i
                        track.bounds[page][Pattern][2] = x
                    else
                        track.bounds[page][Pattern][1] = x
                        track.bounds[page][Pattern][2] = x
                    end
                    flag = false
                    break
                end
            end
            if flag then
                -- move bounds
                local length = track.bounds[page][Pattern][2] - track.bounds[page][Pattern][1]
                track.bounds[page][Pattern][1] = x
                track.bounds[page][Pattern][2] = math.min(x + length, 16)
            end
        end
        Presses[x][y] = z
        Grid_Dirty = true
    else
        -- Mod == 0
        if SubSequins > 0 then
            if y >= min then
                if z == 0 then
                    local flag = true
                    if Presses[1][y] == 1 and 1 ~= x then
                        -- alter SubSequins length
                        if x > #track.data[page][Pattern][SubSequins] then
                            for i = #track.data[page][Pattern][SubSequins], x do
                                track.data[page][Pattern][SubSequins][i] = default
                            end
                        elseif x < #track.data[page][Pattern][SubSequins] then
                            for i = x + 1, #track.data[page][Pattern][SubSequins] do
                                track.data[page][Pattern][SubSequins][i] = nil
                            end
                        end
                        flag = false
                    elseif x == 1 then
                        for i = 2,16 do
                            -- remove SubSequins, exit SubSequins mode
                            if Presses[i][y] == 1 then
                                track.data[page][Pattern][SubSequins] = track.data[page][Pattern][SubSequins][1]
                                SubSequins = 0
                                flag = false
                                break
                            end
                        end
                    end
                    if flag then
                        -- enter data
                        if x <= #track.data[page][Pattern][SubSequins] then
                            track.data[page][Pattern][SubSequins][x] = 8 - y
                        end
                    end
                    track:make_sequins(page, Pattern)
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        else
            -- SubSequins == 0
            if y >= min then
                if z == 0 and Press_Counter[x][y] then
                    -- short press
                    -- remove any SubSequins and enter data
                    clock.cancel(Press_Counter[x][y])
                    track.data[page][Pattern][x] = 8 - y
                    track:make_sequins(page, Pattern)
                elseif z == 1 then
                    -- start long press counter
                    Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        end
    end
end

function ratchet_key(x, y, z)
    local track = Tracks[Active_Track]
    if Mod == 1 then
        -- loop mod
        if z == 0 then
            local flag = true
            for i = 1, 16 do
                if Presses[i][y] == 1 and i ~= x then
                    -- set new bounds
                    if i < x then
                        track.bounds[Page][Pattern][1] = i
                        track.bounds[Page][Pattern][2] = x
                    else
                        track.bounds[Page][Pattern][1] = i
                        track.bounds[Page][Pattern][2] = i
                    end
                    flag = false
                    break
                end
            end
            if flag then
                -- move bounds
                local length = track.bounds[Page][Pattern][2] - track.bounds[Page][Pattern][1]
                track.bounds[Page][Pattern][1] = x
                track.bounds[Page][Pattern][2] = math.min(x + length, 16)
            end
        end
        Presses[x][y] = z
        Grid_Dirty = true
    else
        -- Mod == 0
        if SubSequins > 0 then
            if y >= 4 then
                if z == 0 then
                    local flag = true
                    if Presses[1][y] == 1 and 1 ~= x then
                        -- alter SubSequins length
                        if x > #track.data[Page][Pattern][SubSequins] then
                            for i = #track.data[Page][Pattern][SubSequins], x do
                                track.data[Page][Pattern][SubSequins][i] = 4
                            end
                        elseif x < #track.data[Page][Pattern][SubSequins] then
                            for i = x + 1, #track.data[Page][Pattern][SubSequins] do
                                track.data[Page][Pattern][SubSequins][i] = nil
                            end
                        end
                        flag = false
                    elseif x == 1 then
                        for i = 2, 16 do
                            -- remove SubSequins, exit SubSequins mode
                            if Presses[i][y] == 1 then
                                track.data[Page][Pattern][SubSequins] = track.data[SubSequins][Pattern][1]
                                SubSequins = 0
                                flag = false
                                break
                            end
                        end
                    end
                    if flag then
                        -- enter data
                        if x <= #track.data[Page][Pattern][SubSequins] then
                            local datum = track.data[Page][Pattern][SubSequins][x]
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
                            track.data[Page][Pattern][SubSequins][x] = datum
                        end
                    end
                end
                track:make_sequins(Page, Pattern)
            end
            Presses[x][y] = z
            Grid_Dirty = true
        else
            -- SubSequins == 0
            if y >= 4 then
                if z == 0 and Press_Counter[x][y] then
                    -- short press
                    clock.cancel(Press_Counter[x][y])
                    local datum = track.data[Page][Pattern][x]
                    if type(datum) ~= 'number' then
                        -- remove SubSequins
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
                    track.data[Page][Pattern][x] = datum
                    track:make_sequins(Page, Pattern)
                elseif z == 1 then
                    -- start long press counter
                    Press_Counter[x][y] = clock.run(grid_long_press, x, y)
                end
                Presses[x][y] = z
                Grid_Dirty = true
            end
        end
    end
end

function grid_long_press(x, y)
    -- a long press is one second
    clock.sleep(1)
    Press_Counter[x][y] = nil
    if y == 8 or Mod > 0 or SubSequins > 0 then
        return
    elseif Page == -1 and y == 1 then
        for i = 1, TRACKS do
            local track = Tracks[i]
            track:copy(Tracks[TRACKS + 1].data[Tracks[TRACKS + 1].selected], x)
        end
        Tracks[TRACKS + 1].data[Tracks[TRACKS + 1].selected] = x
        Tracks[TRACKS + 1]:make_sequins(Page)
        Grid_Dirty = true
    elseif Page == -1 and y == 4 then
        SubSequins = x
        Grid_Dirty = true
    elseif Page == 0 then
        if x >= 4 and x <= 7 then
            local i = x - 3
            Tracks[y].pattern_times[i]:clear()
        end
    else
        SubSequins = x
        Grid_Dirty = true
    end
end

-- Track functions
Track = {}

function Track.new(id, data, host_lattice, divisions, probabilities, lengths, muted, patterns)
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
    t.pattern_times = patterns
    t.patterns = {}
    t.indices = {}
    t.values = {}
    t.counter = 0
    t.sequins = {}
    for i = 1, 2*PAGES do
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
            if i ~= 5 then
                t.patterns[i] = host_lattice:new_pattern{
                    division = divisions[i][1] / 16,
                    action = function()
                        t:increment(i, Pattern)
                        if i <= PAGES then
                            if Page == i and Active_Track == t.id then
                                Grid_Dirty = true
                            end
                        else
                            if Page == i - PAGES and Alt_Page and Active_Track == t.id then
                                Grid_Dirty = true
                            end
                        end
                        if i == 7 then
                            -- slices
                            for j = (t.id - 1) * 7, (t.id  - 1) * 7 + 6 do
                                Timber.set_marker(j, "start_frame_", t.values[i], true)
                                Timber.set_marker(j, "end_frame_", t.values[i], true)
                            end
                        elseif i == 9 then
                            -- filter
                            for j = (t.id - 1) * 7, (t.id - 1) * 7 + 6 do
                                engine.filterFreq(j, Freqs[t.values[i]] * params:get("filter_freq_" .. j))
                            end
                        elseif i == 10 then
                            -- pan
                            for j = (t.id - 1) * 7, (t.id - 1) * 7 + 6 do
                                engine.pan(j, Pans[t.values[i]] + params:get("pan_" .. j))
                            end
                        end
                        if Page == 0 and i == 1 then
                            Grid_Dirty = true
                        end
                    end
                }
            elseif i == 5 then
                t.patterns[i] = host_lattice:new_pattern{
                    division = divisions[i][1] / (12 * 16),
                    action = function()
                        t.counter = t.counter % (12 * divisions[i][Pattern]) + 1
                        if t.counter == 1 then
                            t:increment(i, Pattern)
                        end
                        local ratchet_div = 12 / ((t.values[i][Pattern] & 3) + 1)
                        local ratchets = t.values[i][Pattern] >> 2
                        local out_of_twelve = (t.counter - 1) % 12 + 1
                        if t.counter % ratchet_div == 1 then
                            local step = 2 ^ ((out_of_twelve - 1) / ratchet_div)
                            if step & ratchets == step and t.values[1][Pattern] == 1 and not t.muted then
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

function Track.pattern_new(data, host_lattice, division, probabilities, lengths)
    local t = setmetatable({}, { __index = Track})
    t.id = TRACKS + 1
    t.data = data
    t.probabilities = probabilities
    t.divisions = division
    t.lengths = lengths
    t.bounds = {1, 1}
    t.sequins = sequins(data)
    t.sequins:select(1)
    t.indices = 0
    t.values = t.sequins[1]
    t.swings = 8
    t.counter = 0
    t.selected = 1
    t.patterns = host_lattice:new_pattern{
        division = division / 16,
        action = function()
            t.counter = t.counter % t.lengths[t.values] + 1
            if t.counter == 1 then
                t:increment(-1)
            end
            if Page == -1 then
                Grid_Dirty = true
            end
        end
    }
    return t
end

function Track:update(i)
    if i ~= 6 then
        self.patterns[i]:set_division(self.divisions[i][Pattern] / 16)
        self.patterns[i]:set_swing(self.swings[i][Pattern] * 100 / 16)
    end
    if i == 6 or i == 1 then
        self.patterns[6]:set_division(self.divisions[1][Pattern] / (12 * 16))
    end
end

function Track:copy(source, target)
    for i = 1, PAGES do
        self.divisions[i][target] = self.divisions[i][source]
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
end

function Track:make_sequins(i, n)
    local s = {}
    if i == -1 or not n then
        for j = 1,16 do
            if type(self.data[j]) ~= 'number' then
                if #self.data[j] == 0 then
                    self.data[j] = {1}
                end
                s[j] = sequins(self.data[j])
            else
                s[j] = self.data[j]
            end
        end
        self.sequins:settable(s)
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
    if i == -1 or not n then
        if reset or self.indices + 1 > self.bounds[2] or self.indices + 1 < self.bounds[1] then
            self.indices = self.bounds[1]
        else
            self.indices = self.indices + 1
        end
        self.sequins:select(self.indices)
        local r = math.random()
        if r <= self.probabilities[self.indices] / 4 or reset then
            self.values = self.sequins()
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
    local note = note_nums[self.values[3][Pattern]] + 12 * (self.values[4][Pattern] - 3)
    local id = (self.id - 1) * 7 + self.values[2][Pattern] - 1
    if Timber.samples_meta[id].num_frames > 0 then
        engine.noteOn(self.id, MusicUtil.note_num_to_freq(note), Velocities[self.values[5][Pattern]], id)
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

function export_tracks()
    local data = {}
    for i = 1, TRACKS do
        data[i] = {}
        local track         = Tracks[i]
        data[i].sample_id   = track.sample_id
        data[i].probabilities = track.probabilities
        data[i].divisions   = track.divisions
        data[i].swings      = track.swings
        data[i].muted       = track.muted
        data[i].lengths     = track.lengths
        data[i].bounds      = track.bounds
        data[i].data        = track.data
    end
    data[TRACKS + 1] = {}
    local track = Track[TRACKS + 1]
    data[TRACKS + 1].probabilities  = track.probabilities
    data[TRACKS + 1].divisions      = track.divisions
    data[TRACKS + 1].swings         = track.swings
    data[TRACKS + 1].lengths        = track.lengths
    data[TRACKS + 1].bounds         = track.bounds
    data[TRACKS + 1].data           = track.data
    data[TRACKS + 1].selected       = track.selected
    return data
end

function import_tracks(data)
    for i = 1, TRACKS do
        local datum = data[i]
        Tracks[i].sample_id     = datum.sample_id
        Tracks[i].probabilities = datum.probabilities
        Tracks[i].divisions     = datum.divisions
        Tracks[i].swings        = datum.swings
        Tracks[i].muted         = datum.muted
        Tracks[i].lengths       = datum.lengths
        Tracks[i].bounds        = datum.bounds
        Tracks[i].data          = datum.data
        for j = 1, PAGES do
            Tracks[i]:update(j)
        end
        for j = 1, PAGES do
            for k = 1, 16 do
                Tracks[i]:make_sequins(j, k)
            end
        end
    end
    local datum = data[TRACKS + 1]
    Tracks[TRACKS + 1].probabilities    = datum.probabilities
    Tracks[TRACKS + 1].divisions        = datum.divisions
    Tracks[TRACKS + 1].swings           = datum.swings
    Tracks[TRACKS + 1].lengths          = datum.lengths
    Tracks[TRACKS + 1].bounds           = datum.bounds
    Tracks[TRACKS + 1].data             = datum.data
    Tracks[TRACKS + 1].selected         = datum.selected
end

function cleanup()
    Arc.arc:cleanup()
    metro.free_all()
end
