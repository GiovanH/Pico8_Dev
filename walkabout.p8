pico-8 cartridge // http://www.pico-8.com
version 33
__lua__

-- title
-- author

-- global vars

local debug = true  -- (stat(6) == 'debug')
local o_player

local flag_walkable = 0b1

-->8
-- utility

if (debug) menuitem(5,'toggle debug',function() debug = not debug end)

dbg=function()
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
end
dbg = dbg()

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

-- reset with one transparent color
function paltt(t)
 palt()
 palt(t, true)
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
 -- copy meta values, since lua doesn't walk the prototype chain to find them
 for k, v in pairs(self) do
  if sub(k, 1, 2) == "__" then
   proto[k] = v
  end
 end
 proto.__index = proto
 proto.__super = self
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
-- function bbox:itermap()
--  -- todo document this
--  local x0 = flr(self.x0)
--  local x, y = x0 - 1, flr(self.y0)
--  return function()
--   x += 1
--   if x >= self.x1 then
--    x = x0
--    y += 1
--    if (y >= self.y1) return
--   end
--   return x, y, mget(x, y)
--  end
-- end
function bbox:maptiles()
 -- todo document this
 local tiles = {}
 for x = flr(self.x0/8), flr(self.x1/8) do
  for y = flr(self.y0/8), flr(self.y1/8) do
   local i = mget(x, y)
   add(tiles, {spr=i, flags=fget(i)})
  end
 end
 return tiles
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
 anchor = vec(0,0),
 anim = nil,
 frame_len = 1,
 flipx = false,
 flipy = false
}
function mob:init(pos, ...)
 self.spr, self.size = ...
 actor.init(self, pos)
 self.bsize = self.size
 self.shape = bbox(
  self.pos,
  self.bsize
 )
end
function mob:update()
 actor.update(self)
 self.shape = bbox(
  self.pos,
  self.bsize
 )
end
function mob:draw()
 -- caching unpack saves tokens
 local temp = (self.pos - self.anchor)  -- picotool :(
 local spx, spy = temp:unpack()
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
  if (frame != false) spr(frame, spx, spy, spw, sph, self.flipx, self.flipy)
 -- end
 else
  spr(self.spr, spx, spy, spw, sph, self.flipx, self.flipy)
 end
 if debug then
  -- print bbox and anchor/origin
  rect(mrconcat({self.shape:unpack()}, 13))
  local temp = (self.pos - self.anchor)  --p8tool :(
  line(spx, spy,
   mrconcat({temp:unpack()}, 4))
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

local t_sign = mob:extend{
 lines = {}
}
function t_sign:addline(text)
 add(self.lines, text)
end
function t_sign:interact(player)
 dbg.print(self.lines)
end


local t_player = mob:extend{
 ismoving = false,
 hitbox = nil,
 facing = 'd',
 spr0 = 64
}
function t_player:init(pos)
 mob:init(pos, 64, vec(15,23))
end
function t_player:get_hitbox(pos)
 return bbox(
  pos + vec(0, 15),
  vec(15, 7)
 )
end
function t_player:move()
-- player movement
 local vright = vec(1, 0)
 local vdown = vec(0, 1)
 local speed = 2

 local moved = false

 function moveif(step, facing)
  local npos = self.pos + step
  local nhbox = self:get_hitbox(npos)
  local unobstructed = true
  dbg.watch(nhbox:maptiles(), "hittiles")
  for i,tile in pairs(nhbox:maptiles()) do
   if band(tile.flags, flag_walkable) == 0 then
    unobstructed = false
    break
   end
  end
  self.facing = facing
  if unobstructed then
   self.pos = npos
   moved = true
  end
 end
 -- lrudox
 if (btn(0)) then
  for x=1,speed do
   moveif(vec(-1, 0), 'l')
  end
 elseif (btn(1)) then
  for x=1,speed do
   moveif(vec(1, 0), 'r')
  end
 end
 if (btn(2)) then
  for x=1,speed do
   moveif(vec(0, -1), 'u')
  end
 elseif (btn(3)) then
  for x=1,speed do
   moveif(vec(0, 1), 'd')
  end
 end

 self.ismoving = moved

 self.stage.camfocus = self.pos + vec(8, 24)
end
function t_player:tryinteract()
 -- try interact
 local facemap = {d=vec(0,1), u=vec(0,-1), l=vec(-1,0), r=vec(1,0)}
 if (btnp(4)) then
  self.ibox = bbox(
   self.pos + vec(0, 7)+ facemap[self.facing]*8,
   vec(2,2)*8
  )
  for _,obj in pairs(self.stage.objects) do
   if (self.ibox:overlaps(obj.shape) and obj.interact) then
     obj:interact(self)
     break
   end
  end
 else
  self.ibox = nil
 end
end
function t_player:update()

 self:move()

 self:tryinteract()

 mob.update(self)
 self.hitbox = self:get_hitbox(self.pos)
end

function t_player:draw()
 paltt(15)
 self.flipx = (self.facing == 'l')
 local facemap = {d=0, u=2, l=4, r=4}
 self.spr = self.spr0 + facemap[self.facing]
 if self.ismoving and self.stage.mclock % 8 < 4 then
  self.anchor = vec(0, 1)
 else
  self.anchor = vec(0, 0)
 end
 mob.draw(self)
 if (debug) rect(mrconcat({self.hitbox:unpack()}, 5))
 if (debug and self.ibox) rect(mrconcat({self.ibox:unpack()}, 10))
 palt()
end

local room = stage:extend{
 camfocus = nil
}
function room:init(mx, my, mw, mh)
 -- size of room in map screens
 self.cell_pos = vec(mx, my)
 self.room_pos = self.cell_pos*16
 self.cell_size = vec(mw, mh)*16
 self.s_size = self.cell_size*8
 self.origin = self.room_pos*8
 -- origin in tiles
 -- self.origin = self.mapcoords * 16
 -- self.box = bbox(
 --  self.origin, self.size*16)
 stage.init(room)
end
function room:draw()
 cls()
 -- local x, y = self.origin:unpack()
 local cam = self.camfocus - vec(64, 64)
 camera(cam:unpack())
 if debug then
  local ox, oy = self.origin:unpack()
  local extent = self.origin + self.s_size
  rect(ox, oy, mrconcat({extent:unpack()}, 10))
  pset(mrconcat({cam:unpack()}, 9))
 end

 dbg.watch(cam,"cam")
 local cell_x, cell_y = self.room_pos:unpack()
 local cell_w, cell_h = self.cell_size:unpack()
 local sx, sy = self.origin:unpack()
 map(cell_x, cell_y, sx, sy, cell_w, cell_h)
 stage.draw(self)
 camera()
 if (debug and o_player) print('plr  ' .. tostring(o_player.pos), 0, 0)
 if (debug and o_player) print('room ' .. tostring(self.cell_pos), 0, 8)
end
function room:add(object)
 object.pos += self.origin
 stage.add(self, object)
end

-->8
--pico-8 builtins

function _init()
 teststage = room(0, 1, 1, 1)
 o_player = t_player(vec(32, 48))
 teststage:add(o_player)
 o_computer = t_sign(vec(88, 8), 112, vec(15, 7))
 o_computer:addline("it's just drawn on.")
 o_computer.bsize = vec(16,16)
 teststage:add(o_computer)
end

function _update()
 teststage:update()
 dbg.watch(teststage,"stage")
 dbg.watch(o_player,"player")
 dbg.watch(teststage.objects,"objects")
end

function _draw()
 teststage:draw()
 if (debug) dbg.draw()
end
__gfx__
00000000111111112222222233333333000000001111111111111111111111115000000000000005000000000000000000000000000000000000000000000000
000000001111111122222222333333330000000011111111111111111111111156dd555d6d555556055555555555555000000000000000000000000000000000
00000000111111112222222233333333000000001111111111111111111111110dddd555ddd55556011111111111111005555550000000000000000000000000
00000000111111112222222233333333000000001111111111111111111111110ddddd555ddd555d015000000000051051111115000000000000000000000000
00000000111111112222222233333333000000001111111111111111111111110dddddd555ddd555015066066060051051111115000000000000000000000000
00000000111111112222222233333333000000001111111111111111111111110ddddddd555ddd5d015000000000051051111115000000000000000000000000
00000000111111112222222233333333000000001111111111111111111111110dddddddd555dddd015066666066051051111115000000000000000000000000
000000001111111122222222333333330000000011111111111111111111111105dddddddd555ddd015000000000051051111115000000000000000000000000
444444445555555566666666777777772222222255555555ddddddddffffffff055dddddddd555d601555555555555105111111500000000dddddddddddddddd
444444445555555566666666777777772222222255555555ddddddddffffffff0d55dddddddd555d01111111111111105111111500000000d66666666666666d
444444445555555566666666777777772222222255555555ddddddddffffffff0dd55dddddddd55d50000000000000005111111500000000d66666666666666d
444444445555555566666666777777772222222255555555ddddddddffffffff0ddd555ddddddddd11101115551101105111111500000000d66666666666666d
444444445555555566666666777777772222222255555555ddddddddffffffff05ddd55ddddddddd10000000000000005111111500000000d66666666666666d
444444445555555566666666777777772222222255555555ddddddddffffffff055ddd55dddddddd06565566666565605111111500000000d66666666666666d
444444445555555566666666777777772222222255555555ddddddddffffffff0d5ddddddddddd6601111155555111105111111500000000d66666666666666d
444444445555555566666666777777772222222255555555ddddddddffffffff000000000000000010000000000000005111111500000000d66666666666666d
8888888899999999aaaaaaaabbbbbbbb2222222299999999aaaaaaaa33333333000000000000000000000000511111155111111500000000d66666666666666d
8888888899999999aaaaaaaabbbbbbbb2222222299999999aaaaaaaa33333333055555555555555555555550511111155111111500000000d66666666666666d
8888888899999999aaaaaaaabbbbbbbb2222222299999999aaaaaaaa33333333511111111111111111111115111111155111111500000000d66666666666656d
8888888899999999aaaaaaaabbbbbbbb2222222299999999aaaaaaaa33333333511111111111111111111115111111150555555000000000d66666666666565d
8888888899999999aaaaaaaabbbbbbbb2222222299999999aaaaaaaa33333333511111111111111111111115111111150000000000000000d66666666666656d
8888888899999999aaaaaaaabbbbbbbb2222222299999999aaaaaaaa33333333511111111111111111111115111111150000000000000000d66666666666666d
8888888899999999aaaaaaaabbbbbbbb2222222299999999aaaaaaaa33333333511111111111111111111115111111150000000000000000d66666666666666d
8888888899999999aaaaaaaabbbbbbbb2222222299999999aaaaaaaa33333333511111111111111111111115111155500000000000000000d66666666666666d
ccccccccffffffffffffffffffffffff3333333355555555ffffffffffffffff005000000000000000000500511111150000000000000000d66666666666666d
ccccccccffffffffffffffffffffffff3333333355555555ffffffffffffffff005111111111111111111500511111150000000000000000d66666666666666d
ccccccccffffffffffffffffffffffff3333333355555555ffffffffffffffff005111111111111111111500511111110000000000000000d66666666666666d
ccccccccffffffffffffffffffffffff3333333355555555ffffffffffffffff000555555555555555555000511111110000000000000000d66666666666666d
ccccccccffffffffffffffffffffffff3333333355555555ffffffffffffffff000000000000000000000000511111110000000000000000d66666666666666d
ccccccccffffffffffffffffffffffff3333333355555555ffffffffffffffff000000000000000000000000511111110000000000000000d66666666666666d
ccccccccffffffffffffffffffffffff3333333355555555ffffffffffffffff000000000000000000000000511111110000000000000000d66666666666666d
ccccccccffffffffffffffffffffffff3333333355555555ffffffffffffffff000000000000000000000000055511110000000000000000dddddddddddddddd
fffffffffffffffffffffffffffffffffffffffffffffffffffff1fffffffffffffff1fffffffffffffffff1ffffffff00000000000000000000000000000000
ffffffffffffffffffffffffffffffffffffffffffffffffffff11f111111fffffff111111111fffffffff11f11111ff00000000000000000000000000000000
ffffffffffffffffffffffffffffffffffffffffffffffffff1111111111fffffff11111111111ffffff1111111111ff00000000000000000000000000000000
fffffffffffffffffffffffffffffffffffffffffffffffff1111111111111fff1f11111111111ffff1f1111111111ff00000000000000000000000000000000
ffff1111111fffffffff1111111fffffffff1111111ffffff19111111111911ff11191111119111fff1111191111111f00000000000000000000000000000000
fff177777771fffffff177777771fffffff177777771fffff199111111199111f11911111111911fff1111199111111100000000000000000000000000000000
ff17777777771fffff17777777771fffff17777777771ffff19911111119911ff11111111111111fff1111199111111f00000000000000000000000000000000
f1777777777771fff1777777777771fff1777777777771fff111d111d11111fff1111111111111ffff11111d1111611f00000000000000000000000000000000
f1777777777771fff1777777777771fff1777777777771fff111d11d116111fff1111111111111ffff11111d6611111100000000000000000000000000000000
f1777177717771fff1777777777771fff1777777777171ff1111d9161961111f111111111111111ff111111d6691611f00000000000000000000000000000000
f1777077707771fff1777777777771fff1777777777171fff1d1d916196161ffff111111111111ffff1111dd669161ff00000000000000000000000000000000
f1777777777771fff1777777777771fff1777777777771ffff1dd5666d6611fffff1111111111ffffff1111d66dd61ff00000000000000000000000000000000
f177777d777771fff1777777777771fff1777777777771fffff11d111611fffffff111111111ffffffff11ddd1161fff00000000000000000000000000000000
ff17777777771fffff17777777771fffff17777777771fffffff1dd6661fffffffff1111111fffffffffff1dd661ffff00000000000000000000000000000000
fff177777771fffffff177777771fffffff177777771fffffffff11111fffffffffff111111fffffffffff11111fffff00000000000000000000000000000000
ffff1111111fffffffff1111111fffffffff1111111fffffffff1055101fffffffff1000000fffffffffff10051fffff00000000000000000000000000000000
ffff1777771fffffffff1777771fffffffff1777771fffffffff1050001fffffffff1000000ffffffffff1000551ffff00000000000000000000000000000000
ffff1777771fffffffff1777771fffffffff1777771fffffffff1000501fffffffff1000000ffffffffff1000501ffff00000000000000000000000000000000
ffff1777771fffffffff1777771fffffffff1777771fffffffff1015501fffffffff1000000ffffffffff1000151ffff00000000000000000000000000000000
ffff1777771fffffffff1777771fffffffff1777771fffffffff1511111fffffffff1511115ffffffffff1511111ffff00000000000000000000000000000000
fffff11111fffffffffff11111fffffffffff11111ffffffffff1555551fffffffff1551555ffffffffff155551fffff00000000000000000000000000000000
fffff1fff1fffffffffff1fff1fffffffffff1fff1ffffffffff1551551ffffffff111515511ffffffffff1551ffffff00000000000000000000000000000000
fffff1fff1fffffffffff1fff1fffffffffff1fff1ffffffff10551110551ffffff0001111051fffffffff100551ffff00000000000000000000000000000000
ffff1fffff1fffffffff1fffff1ffffffffff1ffff1fffffff11111f11111ffffff1111111111fffffffff111111ffff00000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05555555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01111111111111105555555555555555555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
015222222aa445101111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0156bbb72284a5101111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01560bb1721965101111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
015ffdcd651635101111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
015dfdc6656865101111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000
__gff__
0000000000000000010100000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000200000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000001e1f000000000000000000000000000000202000202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000002e2f000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000003e3f000000000000000000000000000000002020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0809080908090809080908090809080908090809080908090809080908090809200000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1819181918191819181918191819181918191819181918191819181918191819000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0809080908090809080908090809080908090809080908090809080908090809000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1819181918191819181918191819181918191819181918191819181918191819000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000a0b00000a0b00000a0b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0028291a1b29291a1b29291a1b292a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00383939393939393939393939393a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c08090809080908090809080908090c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c18191819181918191819181918191c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c08090809080908090809080908091c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c18191819181918191819181918191c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c08090809080908090809080908091c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c18191819181918191819181918191c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c08090809080908090809080908091c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c18191819181918191819181918191c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c08090809080908090809080908091c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c18191819181918191819181918191c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3b29292929292929292929292929292b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3839393939393939393939393939393a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
