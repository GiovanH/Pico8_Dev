pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

-- title

-- global vars
local todo

--factors 1-15, 18, 20-24, others (27720)

-->8
-- utility
function rndr(a, b) return rnd(b - a) + a end
function rndi(n) return flr(rnd(n)) end

function sort(list, keyfunc)
 for i = 2, #list do
  for j = i, 2, -1 do
   if keyfunc(list[j-1]) > keyfunc(list[j]) then
    list[j], list[j-1] = list[j-1], list[j]
   else
    break
   end
  end
 end
end

-- simple oo
local function nop() end
local obj = {init = nop}
obj.__index = obj
function obj:__call(...)
  local o = setmetatable({}, self)
  return o, o:init(...)
end
function obj:extend(proto)
  proto = proto or {}
  proto.__call, proto.__index =
    self.__call, proto
  return setmetatable(proto, self)
end

-->8
-- stage classes

local vec = obj:extend{}
function vec:init(x, y)
 self.x, self.y =
  x or 0, y or x or 0
end
function vec:clone() return vec(self.x, self.y) end
function vec:__add(v) return vec(self.x + v.x, self.y + v.y) end
function vec:__sub(v) return vec(self.x - v.x, self.y - v.y) end
function vec:__mul(n) return vec(self.x * n, self.y * n) end
function vec:__tostring() return "(" .. self.x .. ", " .. self.y .. ")" end
function vec:unpack() return self.x, self.y end
function vec:elemx(v)
 -- product w/ vector
 return vec(self.x * v.x, self.y * v.y)
end

local bbox = obj:extend{}
function bbox:init(origin, size)
 local corner = origin + size
 self.x0, self.y0,
 self.x1, self.y1,
 self.w, self.h =
  origin.x, origin.y,
  corner.x, corner.y,
  size:unpack()
end
function bbox:shift(v)
 self.x0 += v.x
 self.y0 += v.y
 self.x1 += v.x
 self.y1 += v.y
end
function bbox:overlaps(other)
 return self.x0 < other.x1 and other.x0 < self.x1 and self.y0 < other.y1 and other.y0 < self.y1
end
function bbox:itermap()
 -- todo document this
 local x0 = flr(self.x0)
 local x, y = x0 - 1, flr(self.y0)
 return function()
  x += 1
  if x >= self.x1 then
   x = x0
   y += 1
   if y >= self.y1 then
    return
   end
  end
  return x, y, mget(x, y)
 end
end

-- actors
local actor = obj:extend{
 draw = nop,
 stage = nil,
 z = 0,
 age = -1,
 ttl = nil,
 anchor = vec(),
}
function actor:init(pos)
 self.pos = pos
 if self.size then
  self.shape = bbox(
   pos - self.anchor, self.size)
  printh(self.shape)
 end
end
function actor:update()
 self.age += 1
 if self.ttl and self.age >= self.ttl then
  self:destroy()
 end
end
function actor:destroy() self._doomed = true end

local mob = actor:extend{}
function mob:init(pos, ...)
 actor.init(self, pos)
 self.spr, self.size = ...
end
function mob:draw()
 spr(self.spr, self.pos:unpack())
end

local particle = actor:extend{}
function particle:init(pos, ...)
 actor.init(self, pos)
 self.vel, self.acc, self.ttl, self.col, self.z = ...
end
function particle:update()
 actor.update(self)
 self.vel += self.acc
 self.pos += self.vel
end
function particle:draw()
 pset(self.pos.x, self.pos.y, self.col)
end

-- stage
local stage = obj:extend{}
function stage:init()
 self.actors = {}
 self.mclock = 0
 self.camera = vec() -- use for map offset
end
function stage:add(actor)
 add(self.actors, actor)
 actor.stage = self
end
function stage:_zsort()
 sort(self.actors, function(a) return a.z end)
end
function stage:update()
 for actor in all(self.actors) do
  if actor._doomed then
   -- clean up garbage
   del(self.actors, actor)
   actor.stage = nil
  else
   actor:update()
  end
 end
 self.mclock = (self.mclock + 1) % 27720
end
function stage:draw()
 self:_zsort()
 for actor in all(self.actors) do
  if not actor._doomed then
   actor:draw()
  end
 end
end

-->8
-- game classes

-->8
-- drawing

function draw_bg()
 cls()
end

-->8
-- test (delete this)

local testguy = mob(vec(32, 64), 0)
function testguy:update()
 if (self.stage.mclock % 30 == 0) then
  self.pos = vec(
   8*(4+rndi(8)),
   8*(4+rndi(8))
  )
 end
end

local testgamepad = actor()
function testgamepad:update()
 -- particle test
 if btnp(5) then
  testspark(self.stage, testguy.pos + vec(4, 8))
 end
end

local testhelloworld = actor()
testhelloworld.z = -1
function testhelloworld:draw()
 local i, j0, col, t1, x, y
 for i=1,11 do
  for j0=0,7 do
   j = 7-j0
   col = 7+j
   t1 = self.stage.mclock + i*4 - j*2
   x = cos(t0)*5
   y = 38 + j + cos(t1/50)*5
   pal(7,col)
   spr(16+i, 8+i*8 + x, y)
  end
 end

 print("this is pico-8", 37, 70, 14) --8+(t/4)%8)
 print("nice to meet you", 34, 80, 12) --8+(t/4)%8)

 spr(1, 64-4, 90)
end

function testspark(stage, origin)
 local grav = vec(0, 0.1)
 for i = 0, 16 do
  stage:add(particle(
   origin,
   vec(rndr(-0.5, 0.5), rndr(-1.1, -0.9)),
   grav,
   30,
   10
  ))
 end
end

teststage = stage()
teststage:add(testgamepad)
teststage:add(testguy)
teststage:add(testhelloworld)

-->8
--pico-8 builtins

function _init()
end

function _update()
 teststage:update()
end

function _draw()
 draw_bg()
 teststage:draw()
end

__gfx__
70000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077007700777777007700000077000000777777000000000770007700777777007777770077000000777700000000000000000000000000000000000
00000000077007700770000007700000077000000770077000000000770007700770077007700770077000000770077000000000000000000000000000000000
00000000077007700770000007700000077000000770077000000000770707700770077007700770077000000770077000000000000000000000000000000000
00000000077777700777700007700000077000000770077000000000777777700770077007777000077000000770077000000000000000000000000000000000
00000000077007700770000007700000077000000770077000000000777077700770077007700770077000000770077000000000000000000000000000000000
00000000077007700777777007777770077777700777777000000000770007700777777007700770077777700777777000000000000000000000000000000000
__sfx__
000100001d05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
