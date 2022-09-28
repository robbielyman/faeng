local Arc = {}
Arc.__index = Arc

function Arc.new()
    local arc = {}
    arc.arc = arc.connect()
    arc.shift_mode = false
    setmetatable(arc, Arc)
    arc.arc.delta = function(n, d)
        arc:delta(n, d)
    end
    return arc
end

function Arc:key(n, z)
    if n == 1 then
        self.shift_mode = z == 1
    end
end

function Arc:get_param(i)
    return nil
end

function Arc:delta(n, d)
    if self:get_param(n) then
        params:delta(self:get_param(n), d * 0.01)
    end
end

function Arc:redraw()
    self.arc:all(0)
    for i = 1, 4 do
        if self:get_param(i) then
            param = self:get_param(i)
            local val = util.linlin(param.min, param.max, 3, 61, param:get())
            self.arc:segment(i, 3, 61, 3)
            self.arc:segment(i, val - 1, val + 1, 15)
        end
    end
    self.arc:refresh()
end

return Arc
