pico-8 cartridge // http://www.pico-8.com
version 33
__lua__

-- title

-- global vars
local todo

local debug = true -- (stat(6) == 'debug')
if (debug) menuitem(5,'toggle debug',function() debug = not debug end)

dbg=(function()
 poke(0x5f2d, 1)
 local vars,sy={},0
 local mx,my,mb,pb,click,mw,exp,x,y
 function butn(exp,x,y)
  local hover=mx>=x and mx<x+4 and my>=y and my<y+6
  print(exp and "-" or "+",x,y,hover and 7 or 5)
  return hover and click
 end
 function inspect(v,d)
  d=d or 0
  local t=type(v)  
  if t=="table" then
   if(d>5)return "[table]"
   local props={}
   for key,val in pairs(v) do
    props[key]=inspect(val,d+1)
   end
   return {
    expand=false,
    props=props
   }
  elseif t=="string" then
   return chr(34)..v..chr(34)
  elseif t=="boolean" then
   return v and "true" or "false"
  elseif t=="nil" or t=="function" or t=="thread" then
   return "["..t.."]"
  else 
   return ""..v
  end
 end
 function drawvar(var,name)
  if type(var)=="string" then  
   print(name..":",x+4,y,6)
   print(var,x+#(""..name)*4+8,y,7)
   y+=6
  else
   -- expand button
   if(butn(var.expand,x,y))var.expand=not var.expand
   -- name
   print(name,x+4,y,12) y+=6
   -- content
   if var.expand then
    x+=2
    for key,val in pairs(var.props) do
     drawvar(val,key)    
    end
    x-=2
   end
  end
 end
 function copyuistate(src,dst)
  if type(src)=="table" and type(dst)=="table" then
   dst.expand=src.expand
   for key,val in pairs(src.props) do
    copyuistate(val,dst.props[key])
   end
  end
 end
 function watch(var,name)
  name=name or "[var]"
  local p,i=vars[name],inspect(var)
  if(p)copyuistate(p,i)
  vars[name]=i
 end 
 function clear()
  vars={}
 end 
 function draw(dx,dy,w,h)
  dx=dx or 0
  dy=dy or 48
  w=w or 128-dx
  h=h or 128-dy
  -- collapsed mode
  if not exp then
   dx+=w-10
   w,h=10,5
  end
  -- window
  clip(dx,dy,w,h)
  rectfill(0,0,128,128,1)
  x=dx+2 y=dy+2-sy

  -- read mouse
  mx,my,mw=stat(32),stat(33),stat(36)
  mb=band(stat(34),1)~=0
  click=mb and not pb and mx>=dx and mx<dx+w and my>=dy and my<dy+h
  pb=mb

  if exp then  

   -- variables       
   for k,v in pairs(vars) do
    drawvar(v,k)
   end

   -- scrolling
   local sh=y+sy-dy
   sy=max(min(sy-mw*8,sh-h),0)
  end

  -- expand/collapse btn
  if(butn(exp,dx+w-10,dy))exp=not exp

  -- draw mouse ptr
  clip()    
  line(mx,my,mx,my+2,8)
  color(7) 
 end

 function show()
  exp=true
  while exp do
   draw()
   flip()
  end
 end

 function prnt(v,name)
  watch(v,name)
  show()
 end

 return{
  watch=watch,
  clear=clear,
  expand=function(val)
   if(val~=nil)exp=val
   return exp
  end,
  draw=draw,
  show=show,
  print=prnt
 }
end)()

-->8
-- utility

-- any to string (dumptable)
function tostring(any)
 if (type(any)~="table") return tostr(any)
 local str = "{"
 for k,v in pairs(any) do
  if (str~="{") str=str..","
  str=str..tostring(k).."="..tostring(v)
 end
 return str.."}"
end

-- print all arguments
function printa(...)
 local args={...}  -- becomes a table of arguments
 s = ""
 foreach(args, function(a) s = s..','..tostring(a) end)
 printh(s)
end

-- multiple return concatenation
function mrconcat(t, ...)
 for i, v in ipairs({...}) do
  add(t, v)
 end
 return unpack(t)
end

-- random in range
function rndr(a, b) return rnd(b - a) + a end

-- random int
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

-- print with shadow
local function prints(s, x, y, c1, c2)
 print(s, x, y+1, c2 or 1)
 print(s, x, y, c1)
end

--yield xn
local function yieldn(n)
 for i=1,n do
  yield()
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
 self.origin, self.size = origin, size
 local corner = origin + size
 self.x0, self.y0,
 self.x1, self.y1,
 self.w, self.h =
 origin.x, origin.y,
 corner.x, corner.y,
 size:unpack()
end
function bbox:shift(v)
 self.origin += v
 self:init(self.origin, self.size)
 return self
end
function bbox:unpack() return self.x0, self.y0, self.x1, self.y1 end
function bbox:overlaps(other)
 return self.x0 <= other.x1 and other.x0 <= self.x1 and self.y0 <= other.y1 and other.y0 <= self.y1
end
function bbox:within(other)
 return self.x0 > other.x0 and self.x1 < other.x1 and self.y0 > other.y0 and self.y1 < other.y1
end
function bbox:outline(w)
 local vw = vec(w, w)
 return bbox(
  self.origin - vw,
  self.size + vw*2
 )
end
function bbox:center()
 return self.origin + self.size*(1/2)
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
   if (y >= self.y1) return
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
 -- anch: offset between
 -- bounding box and
 -- pos (top left)
 anchor = vec()
}
function actor:init(pos)
 self.pos = pos
end
function actor:update()
 self.age += 1
 if self.ttl and self.age >= self.ttl then
  self:destroy()
 end
end
function actor:destroy() self._doomed = true end

local mob = actor:extend{
 size = vec(7,7),
 anim = nil,
 frame_len = 1
}
function mob:init(pos, ...)
 self.spr, self.size = ...
 actor.init(self, pos)
 self.shape = bbox(
  self.pos - self.anchor,
  self.size
 )
end
function mob:update()
 actor.update(self)
 self.shape = bbox(
  self.pos - self.anchor,
  self.size
 )
end
function mob:draw()
 -- caching unpack saves tokens
 local spx, spy = self.pos:unpack()
 local spw, sph = self.size:unpack()
 spw, sph = ceil(spw/8), ceil(sph/8)
 -- anim is a list of frames to loop
 -- frames are sprite ids
 if self.anim then 
  local findex = (flr(self.stage.mclock/self.frame_len) % #self.anim) +1
  local frame = self.anim[findex]
  self._frame, self._findex = frame, findex
  
  -- printh(tostring({i=findex, s=self.name, a=self.anim, f=frame}))
  -- if type(frame) == "function"
  --  frame()  
  -- else
   if (frame != false) spr(frame, spx, spy, spw, sph)
  -- end
 else
  spr(self.spr, spx, spy, spw, sph)
 end
 if debug then 
  -- print bbox and anchor/origin
  rect(mrconcat({self.shape:unpack()}, 13))
  line(spx, spy, 
   mrconcat({(self.pos - self.anchor):unpack()}, 4))
 end
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
 self.objects = {}
 self.mclock = 0
 self.camera = vec()  -- use for map offset
end
function stage:add(object)
 add(self.objects, object)
 object.stage = self
end
function stage:_zsort()
 sort(self.objects, function(a) return a.z end)
end
function stage:update()
 for object in all(self.objects) do
  if object._doomed then
   -- clean up garbage
   del(self.objects, object)
   object.stage = nil
  else
   object:update()
  end
 end
 self.mclock = (self.mclock + 1) % 27720
end
function stage:draw()
 self:_zsort()
 for object in all(self.objects) do
  if (not object._doomed) object:draw()
 end
end

-->8
-- game classes

local o_soul = mob(vec(64, 64), 0, vec(7,7))
o_soul.name = 'soul'
o_soul.arena = nil
o_soul.invuln = 0
function o_soul:update()
 -- fit self to arena

 -- todo
 if not self.shape:within(self.arena.shape) then
  self.pos = self.arena.shape:center()
 end

 -- player movement
 local vright = vec(1, 0)
 local vdown = vec(0, 1)
 local speed = 2

 local npos = self.pos
 function moveif()
  local nbox = bbox(
   npos - self.anchor, self.size)
  if nbox:within(self.arena.shape) then
   self.pos = npos
  else
   npos = self.pos
  end
 end
 if (btn(0)) then
  for x=1,speed do
   npos -= vright moveif()
  end
 elseif (btn(1)) then
  for x=1,speed do
   npos += vright moveif()
  end
 end
 if (btn(2)) then
  for x=1,speed do
   npos -= vdown moveif()
  end
 elseif (btn(3)) then
  for x=1,speed do
   npos += vdown moveif()
  end
 end

 if self.invuln > 0 then
  self.invuln -= 1
 end

 mob.update(self)
end

function o_soul:hit(dmg)
 if self.invuln > 0 then
  return false
 else
  self.invuln = 12
  sfx(00)
  return true
 end
end

function o_soul:draw()
 print(self.invuln, self.pos + vec(0, -8))
 if self.invuln > 0 then
  self.anim = {0, false}
 else
  self.anim = nil
 end
 mob.draw(self)
end

local t_testbullet = mob:extend{
 ttl = 200,
 anchor = vec(-1, -1),
 anim = {016, 017, 018, 019},
 name = 'bullet',
 frame_len = 2
}
function t_testbullet:init(pos)
 self.pos = pos
 mob.init(self, self.pos, 000, vec(4, 4))
end
function t_testbullet:update()
 local wholescreen = bbox(vec(0, 0), vec(128, 128))

 if self._findex == 1 then
  self.anchor = vec(-1, 0)
  self.size = vec(3, 5)
 elseif self._findex == 3 then
  self.anchor = vec(0, -1)
  self.size = vec(5, 3)
 end

 self.pos += vec(0, 0.6)

 if not self.shape:overlaps(wholescreen) then
  self:destroy()
 end

 if self.shape:overlaps(o_soul.shape) then
  local didhit = o_soul:hit(1)
  if (didhit) self:destroy()
 end

 mob.update(self)
end

local o_tpattern = mob(vec(64, 16), 001)
o_tpattern.name = 'pattern'
o_tpattern.ttover = 0
o_tpattern.bullets = {}

function o_tpattern:start_turn()
 self.ttover = 200
end
function o_tpattern:draw()
 local perc = self.ttover / 200
 line(0, 0, 128*perc, 0, 10)
 mob.draw(self)
end
function o_tpattern:update()

 if (debug and btn(4)) self:start_turn()

 if (self.ttover > 0) then
  -- our turn
  if self.stage.mclock % 20 == 0 then
   -- fire new bullet
   printh('fire')
   local newbullet = t_testbullet(vec(
    rndr(self.arena.shape.x0, self.arena.shape.x1-4),
    self.arena.shape.y0
   ))
   self.stage:add(newbullet)
  end
  self.ttover -= 1
 end
end

local o_arena = actor()
o_arena.shape = bbox(vec(32,32), vec(64, 64))
function o_arena:update()
 -- move arena with p2
 if (btn(0,1)) then self.shape:shift(vec(-8, 0))
 elseif (btn(1,1)) then self.shape:shift(vec(8, 0)) end
 if (btn(2,1)) then self.shape:shift(vec(0, -8))
 elseif (btn(3,1)) then self.shape:shift(vec(0, 8)) end
end
function o_arena:draw()
 rect(mrconcat({self.shape:unpack()}, 3))
 rect(mrconcat({self.shape:outline(1):unpack()}, 11))
end
o_arena.z = -1

bg = actor()
function bg:draw()
 cls()
end
bg.z = -100

o_soul.arena = o_arena
o_tpattern.arena = o_arena

teststage = stage()
teststage:add(bg)
teststage:add(o_arena)
teststage:add(o_soul)
teststage:add(o_tpattern)

-->8
--pico-8 builtins

function _init()
end

function _update()
 teststage:update()
 dbg.watch(teststage,"stage")
 dbg.watch(o_soul,"soul")
 dbg.watch(o_tpattern,"pattern")
end

function _draw()
 teststage:draw()
 if (debug) dbg.draw()
end
__gfx__
08800880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888007777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888880007777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888880000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00770000077000000000000000077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777000777700000777700000777700077000000777777000000000770007700777777007777770077000000777700000000000000000000000000000000000
07777000777770007777770007777700077000000770077000000000770007700770077007700770077000000770077000000000000000000000000000000000
07777000077777007777770077777000077000000770077000000000770707700770077007700770077000000770077000000000000000000000000000000000
07777000007777000777700077770000077000000770077000000000777777700770077007777000077000000770077000000000000000000000000000000000
00770000000770000000000007700000077000000770077000000000777077700770077007700770077000000770077000000000000000000000000000000000
00000000000000000000000000000000077777700777777000000000770007700777777007700770077777700777777000000000000000000000000000000000
__sfx__
000100001d0501a0500c0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
