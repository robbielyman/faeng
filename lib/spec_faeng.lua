local stub = require('luassert.stub')
local mock = require('luassert.mock')

expose("faeng", function ()
  package.path = '../norns/lua/lib/?.lua;'
    .. '../norns/lua/core/?.lua;'
    .. '../norns/lua/?.lua;'
    .. './?.lua;' .. './lib/?.lua;'
    .. package.path

  it("can load norns, firstly", function ()
    _G._norns = {}
    _G._norns = mock(_norns)
    _G._norns.platform = stub(_norns, 'platform')
    _G._norns.platform.returns(2)
    util = require('util')
    util.time = stub(util, 'time')
    util.file_exists = function (name)
      local f = io.open("/Users/rylee/src/faeng" .. name)
      if f ~= nil then
        io.close(f)
        return true
      end
      return false
    end
    _G._path = {}
    require('norns')
    norns.scripterror = function(msg)
      assert(false, msg)
    end
    _G.grid = require('grid')
    _G.arc = require('arc')
    _G.clock = require('clock')
    _G.params = require('paramset').new()
  end)

  it("can be required without error", function ()
    _G.include = function (file)
      return require(file)
    end
    _G.engine = {}
    engine.playMode = stub(engine, 'playMode')
    engine.startFrame = stub(engine, 'startFrame')
    engine.endFrame = stub(engine, 'endFrame')
    engine.filterFreq = stub(engine, 'filterFreq')
    engine.pan = stub(engine, 'pan')
    _G.osc = {}
    _norns.metro_set_time = stub(_norns, 'metro_set_time')
    _norns.metro_start = stub(_norns, 'metro_start')
    _norns.clock_schedule_sync = stub(_norns, 'clock_schedule_sync')
    _G.metro = require('metro')
    norns.state.data = ""
    norns.state.lib = ""
    norns.state.path = ""
    util.file_exists = function (name)
      if string.find(name, 'config') then return false end
      return true
    end
    _path.code = ""
    _G.screen = require("screen")
    screen = mock(screen, true)
    assert(pcall(require,"faeng"))
  end)

  it("has 7 tracks", function ()
    assert.equals(7, TRACKS)
  end)

  it("has 16 patterns", function ()
    assert.equals(16, PATTERNS)
  end)

  it("has 5 pages, with an alt_page option", function ()
    assert.equals(5, PAGES)
    assert.equals(false, Alt_Page)
  end)

  it("has 3 mods", function ()
    assert.equals(3, MODS)
  end)

  it("has a Set_Current_Voice function as defined by config", function ()
    assert.equals("function", type(Set_Current_Voice))
  end)

  describe("has a Track class. Track", function ()
    it("exists", function ()
      assert.equals("table",type(Track))
      Track = mock(Track)
    end)

    it("can make new tracks", function ()
      local track = Track.new(1, require('lattice'):new())
      assert.is.truthy(track)
    end)

    it("can make pattern tracks", function ()
      local track = Track.pattern_new(require('lattice'):new())
      assert.is.truthy(track)
    end)

    it("has specific named fields", function ()
      local track = Track.new(1, require('lattice'):new())
      local keys = {
        "id_minor", "probabilities", "divisions", "swings",
        "muted", "bounds", "data"
      }
      for _, key in ipairs(keys) do
        assert.is.truthy(track[key] ~= nil)
      end
      track = Track.pattern_new(require('lattice'):new())
      keys = {
        "probabilities", "divisions", "swings", "lengths",
        "bounds", "data", "selected"
      }
      for _, key in ipairs(keys) do
        assert.is.truthy(track[key])
      end
    end)
  end)

  it("can be initialized without error", function ()
    assert(type(init) == "function")
    norns.state.lib = "./lib/"
    assert(pcall(init))
  end)

  it("can copy data from one track to another", function ()
    Tracks[1].divisions[3][1] = {4, 16}
    Tracks[1].probabilities[4][1][5] = 3
    Tracks[1].data[2][1][3] = 3
    assert.are_not.same(Tracks[1].divisions[3][1], Tracks[1].divisions[3][2])
    assert.are_not.same(Tracks[1].data[2][1], Tracks[1].data[2][2])
    assert.are_not.same(Tracks[1].probabilities[4][1], Tracks[1].probabilities[4][2])
    Tracks[1]:copy(1, 2)
    assert.are.same(Tracks[1].data[2][1], Tracks[1].data[2][2])
    assert.are.same(Tracks[1].divisions[3][1], Tracks[1].divisions[3][2])
    assert.are.same(Tracks[1].probabilities[4][1], Tracks[1].probabilities[4][2])
  end)

  it("has ten default pages", function ()
    local list = {
      "trigger", "velocity",
      "sample", "slice",
      "note", "alt_note",
      "octave", "filter",
      "ratchet", "pan"
    }
    for _, name in ipairs(list) do
      assert(pcall(Tracks[1].get, Tracks[1], name))
      assert(pcall(Tracks[1].set, Tracks[1], name, 1))
    end
    assert.is_not.truthy(pcall(Tracks[1].get, Tracks[1], "blah"))
  end)

  it("provides enc, key, and redraw", function ()
    spy.on(Engine_UI, 'enc')
    spy.on(Engine_UI, 'key')
    assert(pcall(key, 1, 1))
    assert(pcall(enc, 1, 2))
    assert(pcall(redraw))
    assert.spy(Engine_UI.enc).was_not.called()
    key(1,0)
    enc(1,-2)
    assert.spy(Engine_UI.enc).was.called()
    assert.spy(Engine_UI.key).was.called()
  end)
end)
