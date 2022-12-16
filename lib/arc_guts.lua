local M = {}

local Arc_Dirty = true
local Shift_Mode = false
local Arc_Guts_Params = {}
local Arc = {}
local Rings = 4
local Slew = false

-- useful for making config errors fail hard and fast
local function norns_assert(cond, msg)
  if not msg then msg = "" end
  if cond then return end
  norns.script.clear()
  norns.scripterror(msg)
end

local Arc_Param = {}
Arc_Param.__index = Arc_Param

function Arc_Param.new(args, slew_enabled)
  local p = {
    id_base = args[1],
    subparams = args.subparams,
    id_minor = args.id_minor,
    visible = args.subparams and 1 or true
  }
  local infix = ""
  if p.subparams then infix = "_" .. p.subparams end
  local suffix = ""
  if p.id_minor then suffix = "_0" end
  p.name = params:get_name(p.id_base .. infix .. suffix)
  setmetatable(p, Arc_Param)
  if not slew_enabled then return p end
  p.data = {}
  local num_params = 7 * (p.id_minor and 7 or 1)
  for i = 0, num_params - 1 do
    p.data[i] = 0
    if p.subparams then
      p.data[i] = {}
      for j = 1, p.subparams do
        p.data[i][j] = 0
      end
    end
  end
  return p
end

local function validate_param(param)
  if type(param) == "string" then param = {param} end
  norns_assert(type(param) == "table" and type(param[1]) == "string", 'config error: bad param in arc_guts.args.params')
  if param.id_minor == nil then
    param.id_minor = true
  end
  if param.macro_edit == nil then
    param.macro_edit = true
  end
  if param.subparams == 0 then
    param.subparams = nil
  end
  local infix = param.subparams and "_" .. param.subparams or ""
  local find = params:lookup_param(param[1] .. infix .. "_0")
  norns_assert(find, 'config error: param not found: ' .. param[1] .. infix)
  return param
end

local function edit_param(param, delta, index, subindex)
  if Slew then
    if subindex then
      param.data[index][subindex] = param.data[index][subindex] + delta
    else
      param.data[index] = param.data[index] + delta
    end
  elseif subindex then
    params:delta(param.id_base .. "_" .. subindex .. "_" .. index, delta)
  else
    params:delta(param.id_base .. "_" .. index, delta)
  end
end

local function arc_delta(n, d)
  local id = "arc_guts_ring_"
  if Shift_Mode then id = "arc_guts_alt_ring_" end
  local param = Arc_Guts_Params[params:get(id .. n)]
  if not param then return end
  local start = Get_Current_Voice()
  if param.macro_edit then
    start = (start // 7) * 7
    for i = 0, 6 do
      if type(param.visible) == "number" then
        edit_param(param, d, start + i, param.visible)
      else
        edit_param(param, d, start + i)
      end
    end
  elseif type(param.visible) == "number" then
    edit_param(param, d, start, param.visible)
  else
    edit_param(param, d, start)
  end
end

local function slew_param(param, a)
  if not param.data then return end
  for id, datum in ipairs(param.data) do
    if type(datum) == "table" then
      for sub_id, val in ipairs(datum) do
        local out = (1 - a) * val
        datum[sub_id] = a * val
        params:delta(param.id_base .. "_" .. sub_id .. "_" .. id, out)
      end
      return
    end
    local out = (1 - a) * datum
    param.data[id] = a * datum
    params:delta(param.id_base .. "_" .. id, out)
  end
end

local function process_slew(time)
  local a = math.exp(-1/(15 * time))
  for _, param in ipairs(Arc_Guts_Params) do
    slew_param(param, a)
  end
  Arc_Dirty = true
end

local function draw_ring(ring, param)
  local i = Get_Current_Voice()
  if not param.id_minor then i = i // 7 end
  local suffix = "_" .. i
  if param.subparams then
    suffix = "_" .. param.visible .. suffix
  end
  local p = params:lookup_param(param.id_base .. suffix)
  if not p then return end
  local t = p.t
  local minval, maxval
  if t == params.tNUMBER or t == params.tOPTION or t == params.tBINARY then
    minval, maxval = unpack(p:get_range())
  else
    minval = p:map_value(0)
    maxval = p:map_value(1)
  end
  local val = util.linlin(minval, maxval, .2 * math.pi, 1.8 * math.pi, p:get())
  Arc:segment(ring, val - .1 + math.pi, val + .1 + math.pi, 15)
end

local function arc_redraw()
  local id = "arc_guts_ring_"
  if Shift_Mode then id = "arc_guts_alt_ring_" end
  for i = 1, Rings do
    local param = Arc_Guts_Params[params:get(id .. i)]
    if param then
      draw_ring(i, param)
    end
  end
  Arc:refresh()
end

function M.init(args)
  norns_assert(type(args.params) == "table", 'config error: arc_guts.args.params must be list')
  local defaults = {}
  local options = {}
  for i, param in ipairs(args.params) do
    param = validate_param(param)
    Arc_Guts_Params[i] = Arc_Param.new(param)
    options[i] = Arc_Guts_Params[i].name
    if param.default then
      defaults[param.default] = i
    end
  end
  norns_assert(type(args.rings) == "number", 'config error: bad argument to args.rings')
  Rings = args.rings
  for i = 1, args.rings do
    params:add{
      type    = "option",
      id      = "arc_guts_ring_" .. i,
      name    = "arc ring " .. i,
      options = options,
      default = defaults[i],
      action  = function (_)
        Arc_Dirty = true
      end
    }
  end
  if args.alt_rings then
    for i = 1, args.rings do
      params:add{
        type    = "option",
        id      = "arc_guts_alt_ring_" .. i,
        name    = "alt arc ring " .. i,
        options = options,
        default = defaults[args.rings + i],
        action  = function (_)
          Arc_Dirty = true
        end
      }
    end
  end
  Arc = arc.connect()
  Arc.delta = arc_delta
  local arc_redraw_metro = metro.init()
  Slew = args.slew and args.slew.enabled == true
  arc_redraw_metro.event = function ()
    if Slew then
      process_slew(args.slew.time)
    end
    if not Arc_Dirty then return end
    arc_redraw()
  end
  if arc_redraw_metro then
    arc_redraw_metro:start(1/15)
  end
end

function M.key(n, z)
  if n == 1 then
    Shift_Mode = z == 1
  end
end

return M
