pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- title
-- author

-- global vars

-- game controller restores health between waves, 
--  picks and starts patterns
-- Pattern controller spawns, manages bullets
-- points from wavevs + grazes + overheal
-- Pattern: start. Stop called by game.
-- Coroutines
-- No-hit bonus
-- no-graze bonus
-- bonus round w/ heal + score bullets
-- t_bullet
-- t_pattern

local debug = true -- (stat(6) == 'debug')

-->8
-- utility

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

-- any to string (dumptable)
function tostring(any, depth)
 if (type(any)~="table" or depth==0) return tostr(any)
 local nextdepth = depth and depth -1 or nil
 if (any.__tostring) return any:__tostring()
 local str = "{"
 for k,v in pairs(any) do
  if (str~="{") str ..= ","
  str ..= tostring(k, nextdepth).."="..tostring(v, nextdepth)
 end
 return str.."}"
end

-- integer to zero padded string
function itostr(v,n)
 local s = ""..v
 local t = #s
 for i=1,n-t do
  s="0"..s
 end
 return s
end

-- print all arguments
function printa(...)
 s = ""
 foreach({...}, function(a) s ..= ','..tostring(a) end)
 printh(s)
end

-- multiple return concatenation
-- > mrc({1, 2}, 3) = 1, 2, 3
function mrconcat(t, ...)
 for i, v in ipairs{...} do
  add(t, v)
 end
 return unpack(t)
end

-- auto unpack first element
function mrconcatu(o, ...)
 return mrconcat({o:unpack()}, ...)
end

-- tries to look up query in all arguements
-- cannot be passed nils
function chainmap(query, ...)
 for i, o in ipairs{...} do
  local v = o[query]
  if (v != nil) return v
 end
end

-- returns a function that runs fn with specified arguments
function closure(fn, ...)
 local vars = {...}
 return (function() fn(unpack(vars)) end)
end

-- returns a table with all elements in tbl for which
-- criteria returns a truthy value
function filter(tbl, criteria)
 local matches = {}
 foreach(tbl, function(obj)
   if (criteria(obj)) add(matches, obj)
  end)
 return matches
end

-- reset with one transparent color
function paltt(t)
 palt()
 palt(0, false)
 palt(t, true)

end

-- random in range [a, b]
function rndr(a, b) return rnd(b - a) + a end

-- random int [0, n)
function rndi(n) return flr(rnd(n)) end

-- random choice from table
function rndc(t) return t[1+rndi(#t)] end

--- sort list by keyfunc
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

function sorted(list, keyfunc)
 local temp = {unpack(list)}
 sort(temp, keyfunc)
 return temp
end

-- clamp query between min/max
function clamp(min_, query, max_)
 return min(max_, max(min_, query))
end

-- print with shadow (optionally center)
local function prints(s, x, y, c1, c2, center)
 local screen_width = 128
 if (center) x = (screen_width - (#s * 4)) / 2
 print(s, x, y+1, c2 or 1)
 print(s, x, y, c1 or 7)
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
-- math classes

-- 2d vector
-- self ops: clone, unpack, flip
-- vector ops: +, -, dotp()
-- scalar ops: *
local vec = obj:extend{}
function vec:init(x, y)
 self.x, self.y =
 x or 0, y or x or 0
end
function vec8(x, y) return vec(x, y)*8 end
local vec_8_8 = vec(8, 8)
local vec_16_16 = vec(16, 16)
local vec_oneone = vec(1, 1)
local vec_zero = vec(0, 0)
local vec_x1 = vec(1, 0)
local vec_y1 = vec(0, 1)
local vec_noneone = vec(-1,-1)
function vec:clone() return vec(self:unpack()) end
function vec:flip() return vec(self.y, self.x) end
function vec:floor() return vec(flr(self.x), flr(self.y)) end
function vec:__add(v, y)
 if (y) v = vec(v, y)
 return vec(self.x + v.x, self.y + v.y)
end
function vec:__sub(v, y)
 if (y) v = vec(v, y)
 return vec(self.x - v.x, self.y - v.y)
end
function vec:__mul(n) return vec(self.x * n, self.y * n) end
function vec:__eq(v) return self.x == v.x and self.y == v.y end
function vec:__div(n) return vec(self.x / n, self.y / n) end
function vec:__tostring() return "(" .. self.x .. ", " .. self.y .. ")" end
function vec:unpack() return self.x, self.y end
function vec:dotp(v, y)
 if (y) v = vec(v, y)
 return vec(self.x * v.x, self.y * v.y)
end
function vec:mag() return sqrt(self.x^2 + self.y^2) end

-- 2d bounding box
-- self ops: clone, unpack, center (get)
-- bbox ops: overlaps, within
-- scalar ops: *, outline, shift
--  * multiplies size and origin
-- vector ops:
--  maptiles(offset) (get all touching map tiles w/ info)
--  shift (move origin by v)
--  grow (move corner/change size by v)
local bbox = obj:extend{}
function bbox:init(origin, size)
 self.origin, self.size = origin, size
 self.corner = origin + size
 self.x0, self.y0,
 self.x1, self.y1,
 self.w, self.h =
 origin.x, origin.y,
 self.corner.x, self.corner.y,
 size:unpack()
end
function bbox.fromxywh(x, y, w, h) return bbox(vec(x, y), vec(w, h)) end
function bbox.pack(x0, y0, x1, y1)
 local o = vec(x0, y0)
 return bbox(o, vec(x1, y1)-o)
end
local box_screen = bbox.pack(0, 0, 128, 128)
function bbox:__mul(n) return bbox(self.origin*n, self.size*n) end
function bbox:shift(v) return bbox(self.origin+v, self.size) end
function bbox:grow(v) return bbox(self.origin, self.size+v) end
function bbox:clone() return bbox(self.origin:unpack(), self.size.unpack()) end
function bbox:unpack() return self.x0, self.y0, self.x1, self.y1 end
function bbox:overlaps(other)
 if (other == nil) return false
 return self.x0 < other.x1 and other.x0 < self.x1 and self.y0 < other.y1 and other.y0 < self.y1
end
function bbox:within(other)
 if (other == nil) return false
 return self.x0 >= other.x0 and self.x1 <= other.x1 and self.y0 >= other.y0 and self.y1 <= other.y1
end
function bbox:outline(w)
 local vw = vec(w, w)
 return bbox(
  self.origin - vw,
  self.size + vw*2
 )
end
function bbox:center()
 return self.origin + self.size/2
end
function bbox:maptiles(offset)
 if (offset == nil) offset = vec_zero
 local ox, oy = offset:unpack()
 local tiles = {}
 -- corner is outside edge, only check *within* [0, 1)
 for x = flr(self.x0/8), flr((self.x1-1)/8) do
  for y = flr(self.y0/8), flr((self.y1-1)/8) do
   local tpos = vec(x+ox, y+oy)
   local i = mget(tpos:unpack())
   add(tiles, {spr=i, flags=fget(i), pos=tpos})
  end
 end
 return tiles
end

-->8
-- stage classes

-- entitys
-- [1]pos: main position
-- draw: draw function (or nop)
-- z: draw order
-- ttl: self-destroy after n ticks if set
local entity = obj:extend{
 draw = nil,
 drawui = nil,
 stage = nil,
 z = 0,
 ttl = nil,
}
function entity:init(kwargs)
 kwargs = kwargs or {}
 self.ttl = kwargs.ttl or self.ttl
 self.z = kwargs.z or self.z
 if (self.coupdate) self._coupdate = cocreate(self.coupdate, self)
end
function entity:update()
 if self.ttl then
  self.ttl -= 1
  if (self.ttl < 1) self:destroy()
 end
 if (self._coupdate) assert(coresume(self._coupdate, self))
end
function entity:destroy() self._doomed = true end

-- mob
-- [1]pos: main position
-- [2]spr: sprite top-left corner
-- [3]size: size of sprite area to draw
-- [4]kwargs: table with overrides for anchor, others
-- anchor: vector from pos to sprite
-- anim: table of frames to repeat instead of spr
-- frame_len: how long to show each frame in anim
-- flipx, flipy: sprite flip booleans
-- paltab: pallette replacement table (opt)
-- tcol: color # to mark as transparent
-- z_is_y: auto set z to pos.y
local actor = entity:extend{
 size = vec_8_8,
 anchor = vec_zero,
 offset = vec_zero,
 anim = nil,
 frame_len = 1,
 flipx = false,
 flipy = false,
 tcol = 0,
 paltab = nil,
 z_is_y = false,  -- domain: camera perspective
}
function actor:init(pos, spr_, size, kwargs)
 entity.init(self)
 kwargs = kwargs or {}
 self.pos, self.spr, self.size = pos, spr_, size
 for prop in all{'anchor', 'offset', 'z_is_y', 'tcol', 'paltab'} do
  self[prop] = chainmap(prop, kwargs, self)
 end
 self._apos = self.pos + self.anchor + self.offset
end
function actor:rel_anchor(x, y)
 self.anchor = vec(self.size.x*x, self.size.y*y)
end
function actor:drawdebug()
 if debug then
  -- picotool issue #92 :(
  local spx, spy = self._apos:unpack()
  line(spx, spy,
   mrconcatu(self.pos, 4))
 end
end
function actor:update()
 self._apos = self.pos + self.anchor + self.offset
 if (self.z_is_y) self.z = self.pos.y
 entity.update(self)
end
function actor:draw(frame)
 local frame = frame or self.spr
 -- if self.spr or self.afnim then
 pal(self.paltab)
 paltt(self.tcol)
 -- caching unpack saves tokens
 local spx, spy = self._apos:unpack()
 local spw, sph = self.size:unpack()
 spw, sph = ceil(spw/8), ceil(sph/8)
 -- anim is a list of frames to loop
 -- frames are sprite ids
 if self.anim then
  local mclock = self.ttl or self.stage.mclock
  local findex = (flr(mclock/self.frame_len) % #self.anim) +1
  frame = self.anim[findex]
  self._frame, self._findex = frame, findex
 end
 if (frame != false and frame != nil) spr(frame, spx, spy, spw, sph, self.flipx, self.flipy)
 -- end
 pal()
 self:drawdebug()
end

-- mob: entity with a bounding box and dynamism
-- init(pos, spr, size, kwargs)
-- bsize: extent of bounding box. defaults to size
-- kwargs can set hbox_offset and bsize
-- dynamic: true to automatically regenerate hitbox each frame
-- hbox_offset: vector from pos to hbox
-- get_hitbox(v): hitbox is self.pos were v
local mob = actor:extend{
 dynamic=false,
 hbox_offset = vec_zero,
}
function mob:init(pos, spr_, size, kwargs)
 kwargs = kwargs or {}
 actor.init(self, pos, spr_, size, kwargs)
 self.bsize = chainmap('bsize', kwargs, self) or self.size
 for prop in all{'hbox_offset', 'dynamic', 'obstructs'} do
  self[prop] = chainmap(prop, kwargs, self)
 end
 self.hbox = self:get_hitbox()
end
function mob:get_hitbox(pos)
 return bbox(
  (pos or self.pos) + self.hbox_offset,
  self.bsize
 )
end
function mob:update()
 if (self.dynamic) self.hbox = self:get_hitbox()
 actor.update(self)
end
function mob:drawdebug()
 if debug then
  -- print bbox and anchor/origin WITHIN box
  local drawbox = self.hbox:grow(vec_noneone)
  rect(mrconcatu(drawbox, 2))
 end
 actor.drawdebug(self)
end

-- particle
-- pos, vel, acc, ttl, col, z
-- set critical to true to force the particle even during slowdown
local particle = entity:extend{
 critical=false
}
function particle:init(pos, ...)
 -- assert(self != particle)
 entity.init(self)
 self.pos = pos
 self.vel, self.acc, self.ttl, self.col, self.z = ...
 if (self.z) self.z_is_y = false
 if (stat(7) < 30 and not self.critical) self:destroy()
end
function particle:update()
 self.vel += self.acc
 self.pos += self.vel
 entity.update(self)
end
function particle:draw()
 if self.spr and self.size then
  paltt(self.tcol)
  spr(self.spr, mrconcatu(self.pos, self.size:unpack()))
 else
  pset(self.pos.x, self.pos.y, self.col)
 end
end
function sprparticle(spr, size, ...)
 local p = particle(...)
 p.spr = spr
 p.size = size
 return p
end

-- stage
-- updates and draws all contained objects in order
-- tracks and executes asynchronous tasks
-- :add(object) to add object
--  objects can have only one stage at a time
-- :schedule(tics, callback) to execute callback in # ticks
-- mclock is highly composite modulo clock
-- % 1-15, 18, 20, 21-22, 24, 28...
local stage = obj:extend{}
function stage:init()
 self.objects = {}
 self.uiobjects = {}
 self.mclock = 0
 self.cam = vec()  -- use for map offset
 self._tasks = {}
end
function stage:add(object)
 add(self.objects, object)
 -- if (object.stage) del(object.stage.objects, object)
 object.stage = self
 return object
end
function stage:_zsort()
 sort(self.objects, function(a) return a.z end)
end
function stage:update()
 -- update clock
 self.mclock = (self.mclock + 1) % 27720
 -- update tasks
 for handle, task in pairs(self._tasks) do
  task.ttl -= 1
  if task.ttl <= 0 then
   task.callback()
   self._tasks[handle] = nil
  end
 end
 -- update objects
 for object in all(self.objects) do
  if object._doomed then
   -- clean up garbage
   del(self.objects, object)
   object.stage = nil
  else
   object:update()
  end
 end
end
function stage:draw()
 self:_zsort()
 camera(self.cam:unpack())
 for object in all(self.objects) do
  -- and not object._doomed -- necessary?
  if (object.draw) object:draw()
 end
 camera()  -- ui to raw screen coords
 for object in all(self.objects) do
  if (object.drawui) object:drawui()
 end
end
function stage:schedule(tics, callback)
 add(self._tasks, {
   ttl = tics,
   callback = callback,
  })
end

-->8
-- game utility

-- focus stack
-- use this to keep track of what
-- player input should be influencing.
-- global because dialog/others are global.
-- get(), push(v), pop(expected)
local focus = {}
function focus:get() return self[#self] end
function focus:is(q) return self:get() == q end
function focus:isnt(q) return self:get() != q end
function focus:push(s) add(self, s) end
function focus:pop(expected)
 local r = deli(self)
 if (expected) assert(expected == r, "popped '" .. r .. "', not " .. expected)
 return r
end

local t_soul = mob:extend{
 arena = nil,
 invuln = 0,
 dynamic = true,
 hp = 20
}
function t_soul:_moveif(step)
 local npos = self.pos + step
 local nhbox = self:get_hitbox(npos)
 local unobstructed = nhbox:within(self.arena.hbox)
 for _,obj in pairs(self.stage.objects) do
  if obj != self then
   if nhbox:overlaps(obj.hbox) then
    if (obj.obstructs) unobstructed = false
   end
  end
 end
 -- if (facing) self.facing = facing
 if unobstructed then
  self.pos = npos
  -- self.moved = true
 end
end
function t_soul:move()
 -- player movement
 local speed = 1
 -- lrudox
 for x=1,speed do
  if btn(0) then
   self:_moveif(vec(-1, 0))
  elseif btn(1) then
   self:_moveif(vec_x1)
  end
  if btn(2) then
   self:_moveif(vec(0, -1))
  elseif btn(3) then
   self:_moveif(vec_y1)
  end
 end

end
function t_soul:update()
 -- fit self to arena
 if not self.hbox:within(self.arena.hbox) then
  self.pos = self.arena.hbox:center()
 end

 -- Collision
 for _,obj in pairs(self.stage.objects) do
  if obj != self then
   if self.hbox:overlaps(obj.hbox) then
    -- If object has onhit, call onhit
    -- Bullet may choose to call soul:hit to deal damage
    -- If no damage delt, soul:hit returns false
    if (obj.onhit) obj:onhit(self)
   end
  end
 end

 self:move()

 if self.invuln > 0 then
  self.invuln -= 1
 end

 mob.update(self)
end
function t_soul:dmghit(dmg)
 if self.invuln > 0 then
  return false
 else
  self.hp -= dmg
  -- TODO gameover logic
  self.invuln = 12
  sfx(00)
  return true
 end
end
function t_soul:draw()
 if self.invuln > 0 then
  self.anim = {0, false}
 else
  self.anim = nil
 end
 mob.draw(self)
end
function t_soul:drawui()
 local perc = self.hp / 20
 rectfill(mrconcatu(bbox.fromxywh(2, 120, 60*perc, 8), 8))
 rect(mrconcatu(bbox.fromxywh(2, 120, 60, 8), 10))
end

local b_test = mob:extend{
 ttl = 200,
 anim = {016, 017, 018, 019},
 name = 'bullet',
 frame_len = 2,
 dynamic = true
}
function b_test:init(pos)
 self.pos = pos
 mob.init(self, self.pos, false, vec(5, 5))
end
function b_test:onhit(player)
 local didhit = player:dmghit(1)
 if (didhit) self:destroy()
end
function b_test:update()
 self.pos += vec(0, 0.6)
 printh(self._findex)
 if self._findex == 1 then
  self.hbox_offset = vec(1, 0)
  self.bsize = vec(4, 6)
 elseif self._findex == 3 then
  self.hbox_offset = vec(0, 1)
  self.bsize = vec(6, 4)
 end

 if not self.hbox:overlaps(box_screen) then
  self:destroy()
 end

 mob.update(self)
end

local pat_test = entity:extend{
 name = "test pattern",
 ttover = 0,
 lifespan = 200
}
function pat_test:init(arena)
 entity.init(self)
 self.arena = arena
 self.children = {}
 self.ttl = self.lifespan
end

function pat_test:drawui()
 local perc = self.ttl / self.lifespan
 line(0, 0, 128*perc, 0, 10)
end

function pat_test:destroy()
 foreach(self.children, function(c) c:destroy() end)
 entity.destroy(self)
end
function pat_test:update()
 entity.update(self)
 -- our turn
 if self.stage.mclock % 20 == 0 then
  -- fire new bullet
  printh('fire')
  local newbullet = b_test(vec(
   rndr(self.arena.hbox.x0, self.arena.hbox.x1-4),
   self.arena.hbox.y0
  ))
  self.stage:add(newbullet)
  add(self.children, newbullet)
 end
end

local t_arena = mob:extend{
 cur_pattern = nil,
 z = -1
}
function t_arena:update()
 -- move arena with p2
 -- if (btn(0,1)) then self.shape:shift(vec(-8, 0))
 -- elseif (btn(1,1)) then self.shape:shift(vec(8, 0)) end
 -- if (btn(2,1)) then self.shape:shift(vec(0, -8))
 -- elseif (btn(3,1)) then self.shape:shift(vec(0, 8)) end
 if (self.cur_pattern and self.cur_pattern._doomed) self.cur_pattern = nil
 if (debug and self.cur_pattern == nil and btnp(4)) self:new_wave()
end
function t_arena:new_wave()
 -- Pick random pattern
 -- Add new pattern to stage
 -- Set cur_pattern to new pattern
 -- Wait for cur_pattern to die
 self.cur_pattern = self.stage:add(rndc{
  pat_test
 }(self))
end
function t_arena:draw()
 rect(mrconcat({self.hbox:unpack()}, 3))
 rect(mrconcat({self.hbox:outline(1):unpack()}, 11))
end
function t_arena:drawui()
 if (self.cur_pattern) do
  print(self.cur_pattern.name, 0, 0)
  print(self.cur_pattern._doomed, 0, 8)
 end
end

bg = entity()
function bg:draw()
 cls()
end
bg.z = -100

-->8
--pico-8 builtins

function _init()
 local o_soul = t_soul(vec(64, 64), 0, vec(7,7))
 local o_arena = t_arena(vec(32,32), 0, vec(64, 64))
 o_soul.arena = o_arena

 teststage = stage()
 teststage:add(bg)
 teststage:add(o_arena)
 teststage:add(o_soul)
 -- teststage:add(o_tpattern)
end

function _update()
 teststage:update()
 dbg.watch(teststage,"stage")
 -- dbg.watch(o_soul,"soul")
 -- dbg.watch(o_tpattern,"pattern")
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00112233000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00112233000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44556677000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44556677000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8899aabb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8899aabb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccddeeff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccddeeff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100001d0501a0500c0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
