pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
-- hearten
-- by giovanh

-- I don't like how pat_comp_spreadbar requires UT mechanic knowledge
-- better meter graphics
-- better library menu graphics
-- juicier score graphics  - wavey text effect on score bonus

-- help menu
-- nest2 background effects on heat up

-- global vars

local debug = (stat(6) == 'debug')
local cur_stage = nil

sfx_dmg = 000
sfx_graze = 001
sfx_screentick = 002
sfx_heal = 003
sfx_menutick = 004
sfx_overheal = 005

points_wave = 1
points_waveperfect = 3
points_heal = 2
points_overheal = 4

-->8
-- utility

if (debug) menuitem(5,'toggle debug',function() debug = not debug end)

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

-- merge arrays
function arrConcat(...)
 local ret = {}
 for i, list in ipairs{...} do
  for _, v in ipairs(list) do
   add(ret, v)
  end
 end
 return ret
end

-- print all arguments
function printa(...)
 s = ""
 foreach({...}, function(a) s ..= tostring(a)..',' end)
 printh(sub(s, 0, #s-1))
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

function shuffle_table(table)
 -- do a fisher-yates shuffle
 for i = #table, 1, -1 do
  local j = flr(rnd(i)) + 1
  table[i], table[j] = table[j], table[i]
 end
end

-- clamp query between min/max
function clamp(min_, query, max_)
 return min(max_, max(min_, query))
end

-- print with shadow (optionally center)
local function prints(s, x, y, c1, c2, align)
 -- align: 0 for right, 1 for center, 2 for left
 -- local screen_width = 128
 s..=''  -- Coerce to string
 x -= (#s * ((align or 0)*2))
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
function vec:norm()
 local ax, ay = abs(self.x), abs(self.y)
 local ratio1 = 1 / max(ax, ay)
 -- Nick Vogt's fast normalization
 local ratio2 = ratio1 * (1.29289 - (ax + ay) * ratio1 * 0.29289)
 return self:dotp(ratio2, ratio2)
end
function vec:rotate(theta)
 return vec(
  cos(theta)*self.x-sin(theta)*self.y,
  sin(theta)*self.x+cos(theta)*self.y
 )
end

-- Draw the vector connecting the points in path
function draw_beam(path, origin, theta, color)
 local prev = nil
 for i, v in ipairs(path) do
  local thisv = origin + v:rotate(theta)
  if prev then
   line(mrconcatu(thisv, mrconcatu(prev, color)))
  end
  prev = thisv
 end
end

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
 for prop in all{'ttl', 'z'} do
  self[prop] = chainmap(prop, kwargs, self)
 end
 -- self.ttl = kwargs.ttl or self.ttl
 -- self.z = kwargs.z or self.z
 if (self.coupdate) self._coupdate = cocreate(self.coupdate, self)
end
function entity:update()
 if (self._coupdate and costatus(self._coupdate) != 'dead') assert(coresume(self._coupdate, self))
 if self.ttl != nil then
  self.ttl -= 1
  if (self.ttl < 1) self:destroy()
 end
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
 entity.init(self, kwargs)
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
 self.mclock = 0
 self.cam = vec()  -- use for map offset
 self._tasks = {}
end
function stage:add(object)
 add(self.objects, object)
 -- if (object.stage) del(object.stage.objects, object)
 object.stage = self
 if (object.onadd) object:onadd()
 return object
end
function stage:_zsort()
 sort(self.objects, function(a) return a.z end)
end
function stage:update()
 -- update clock
 self.mclock = (self.mclock + 1) % 27720
 -- update tasks
 -- printa("stage updating", #self._tasks, "tasks", #self.objects, "objects", stat(7), "fps", stat(1), "cpu")
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
 cls()
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

function make_note(pitch, instr, vol, effect)
 return { pitch + 64*(instr%4) , 16*effect + 2*vol + flr(instr/4) }  -- flr may be redundant when this is poke'd into memory
end

function set_note(sfx, time, note)
 local addr = 0x3200 + 68*sfx + 2*time
 poke(addr, note[1])
 poke(addr+1, note[2])
end

function drawtitle(s, c1, c2)
 local x = (128 - (#s * 8)) / 2
 s = "\^w\^t" .. s
 print(s, x, 16 + 2, c2)
 print(s, x, 16, c1)
end

local choicer = entity:extend{
 z=4,
 pos=vec(64),
 padding=vec(3, 3),
 char_size=vec(4, 5),
 selected = 1,  -- index of selected opt
}
function choicer:init(choices, exopts)
 exopts = exopts or {}
 self.choices = choices

 for prop in all{'pos', 'selected'} do
  self[prop] = chainmap(prop, exopts, self)
 end

 if (exopts.allowcancel) add(self.choices, {'cancel', nop})

 local width = 0
 for v in all(self.choices) do
  width = max(width, #v[1] + 2)  -- cursor
 end
 -- 2px spacing
 self.char_size_sp = self.char_size:__add(0, 2)  -- compute once
 self.size = self.char_size_sp:dotp(width, #self.choices)
 self.size += self.padding*2 - vec(1, 3)  -- up to but not equal - last 2px space
end
function choicer:drawui()
 if (self.choices == nil) return
 local rbox = bbox(self.pos, self.size)
 rectfill(mrconcatu(rbox, 0))
 rect(mrconcatu(rbox, 6))
 local ppos = self.pos + self.padding
 for i,v in ipairs(self.choices) do
  print(v[1],
   mrconcatu(ppos:__add(
     vec(2, i-1):dotp(self.char_size_sp)
    ), v[3] or 7))
 end
 color(8)
 print("♥ ",
  ppos:__add(
   vec(0, self.selected-1):dotp(self.char_size_sp)
  ):unpack())
end
function choicer:update()

 if (btnp(2)) self.selected -= 1; sfx(sfx_menutick)
 if (btnp(3)) self.selected += 1; sfx(sfx_menutick)
 self.selected = clamp(1, self.selected, #self.choices)
 if btnp(4) then
  self.choices[self.selected][2]()
  self:destroy()
 end
end

-->8
-- player

local t_shakespr = mob:extend{
 frame_len = 3,
 shaketab={
  vec(-1, -1),
  vec(1, 1),
  vec(-1, 0),
  vec(1, 0),
  vec(-1, 1),
  vec(1, 1),
 }
}
function t_shakespr:update()
 self.offset = self.shaketab[flr(self.stage.mclock/self.frame_len) % #self.shaketab]
 mob.update(self)
end

local t_soul = mob:extend{
 invuln = 0,
 dynamic = true,
 frame_len = 2,
 hp = 20,
 maxhp = 20,
 sp = 0,
 maxsp = 20,
 heal_amt = 1,
 z = 7,
 isdemo = false,
 offset = vec(-3, -3),
 hbox_offset = vec(-2,-2),
 bsize = vec(5)
}
function t_soul:init(pos)
 mob.init(self, pos, 0, vec(7))
end
function t_soul:explode()
 music(-1)
 self.o_graze:destroy()
 self:destroy()

 -- TODO: Temp explosion
 local stage = self.stage  -- soul will be destroyed
 stage:add(t_shakespr(self.pos+self.offset, self.spr, self.size, {ttl=30}))
 stage:schedule(30, function()
   local n = 12
   local posoffset = self.pos + self.offset
   -- Explode entire actor
   spr(0,0,0,1,1)
   for x=0,6 do
    for y=0,6 do
     local p = posoffset + vec(x, y)
     stage:add(
      particle(
       p,
       vec(rndr(-0.5, 0.5), rndr(-2, -1)),
       vec(0, 0.1),
       60,
       pget(x, y)
      )
     )
    end  -- end for y
   end  -- end for x
  end)
 self.stage:schedule(120, function()
   cur_stage = st_postgame(stage)
  end)

end
function t_soul:_moveif(step)
 local npos = self.pos + step
 local nhbox = self:get_hitbox(npos)
 local unobstructed = nhbox:within(self.stage.arena.hbox)
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
  self.moved = true
 end
end
function t_soul:move()
 self.moved = false
 -- player movement
 local speed = 1
 -- lrudox
 for x=1,speed do
  if btn(0) then
   self:_moveif(vec(-0.5, 0))
  elseif btn(1) then
   self:_moveif(vec(0.5, 0))
  end
  if btn(2) then
   self:_moveif(vec(0, -0.5))
  elseif btn(3) then
   self:_moveif(vec(0, 0.5))
  end
 end

end
function t_soul:update()
 -- fit self to arena
 if not self.hbox:within(self.stage.arena.hbox) then
  self.pos = self.stage.arena.hbox:center()
 end

 -- Collision
 for _,obj in pairs(self.stage.objects) do
  if obj != self then
   if self.hbox:overlaps(obj.hbox) then
    -- If object has oncollide, call oncollide
    -- Bullet may choose to call soul:hit to deal damage
    -- If no damage delt, soul:hit returns false
    if (obj.oncollide) obj:oncollide(self)
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
 if self.invuln > 0 or dmg < 1 then
  return false
 else
  if (not self.isdemo) self.hp -= dmg
  -- printa(self.isdemo, dmg, self.hp)
  self.stage.arena.waveperfect = false
  self.invuln = 15
  sfx(sfx_dmg)
  return true
 end
end
function t_soul:ongraze(bullet)
 if (self.invuln > 0) return false
 if (not self.isdemo) self.sp += 1
 if (self.sp >= self.maxsp) then
  self.sp = 0
  if self.hp < self.maxhp then
   sfx(sfx_heal)
   self.hp = min(self.maxhp, self.hp + self.heal_amt)
   self.stage:addscore(points_heal, 11)
  else
   sfx(sfx_overheal)
   self.stage:addscore(points_overheal, 11)
  end
 else
  set_note(sfx_graze, 1,
   make_note(
    flr( self.sp/self.maxsp * (64 - 0) + 0 ),  -- pitch
    2,  -- instr
    1,  --vol
    6  -- effect
   )
  )
  sfx(sfx_graze)
 end
 return true
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
 if (self.isdemo) return
 local amt, max, col, origin = self.hp, self.maxhp, 8, vec(8, 118)
 local perc = amt / max
 local hpbox = bbox(origin, vec(60, 8))
 local hplostv = vec(hpbox.w * (perc - 1), 0)
 rectfill(mrconcatu(hpbox:grow(hplostv), col))
 rect(mrconcatu(hpbox, 10))
 print(amt .. "/" .. max, mrconcatu(origin+vec(2,2), 0))

 local amt, max, col, origin = self.sp, self.maxsp, 3, vec(8, 96)
 local perc = amt / max
 local hpbox = bbox(origin, vec(8, -60))
 local hplostv = vec(0, hpbox.h * (perc - 1))
 rectfill(mrconcatu(hpbox:grow(hplostv), col))
 rect(mrconcatu(hpbox, 10))
-- print(amt .. "/" .. max, mrconcatu(origin+vec(2,2), 9))

end

local t_graze = mob:extend{
 dynamic = true,
 z = t_soul.z + 1,
 offset = vec(-7),
 hbox_offset = vec(-7)
}
function t_graze:init(soul)
 self.soul = soul
 soul.o_graze = self
 mob.init(self, soul.pos, 004, vec(15))
end
function t_graze:update()
 self.pos = self.soul.pos
 mob.update(self)

 for _,obj in pairs(self.stage.objects) do
  if obj != self then
   if self.hbox:overlaps(obj.hbox) then
    if (obj.oncollide and obj:canhit(self.soul) and not obj._grazed) then
     self.soul:ongraze(obj)
     obj._grazed = true
    end
   end
  end
 end
end

local t_warnbox = mob:extend{}
function t_warnbox:draw()
 color(8)
 rect(self.hbox:unpack())
 print("!", self.hbox:center():__sub(1, 3):unpack())
-- mob.draw(self)
end

-->8
-- bullets

-- Super cheap particle to use for trails
local t_trailparticle = entity:extend{
 critical=false,
 col=5,
 ttl=240
}
function t_trailparticle:init(pos)
 entity.init(self)
 self.pos = pos
 if (stat(7) < 60 and not self.critical) self:destroy()
end
function t_trailparticle:draw()
 pset(self.pos.x, self.pos.y, self.col)
end

local t_bullet = mob:extend{
 z = 6,
 dynamic = true,
 ttl = 200,
 dmg = 0,  -- set by init
 hbox_offset = 'CENTER',
 anchor = 'CENTER',
 vel = vec(0),
 acc = vec(0),
 tcol = 8,
 destroy_on_dmg = true,
}
function t_bullet:init(pos, dmg)
 -- Center
 local csize = self.bsize or self.size
 if (self.hbox_offset == 'CENTER') self.hbox_offset = csize / -2
 if (self.anchor == 'CENTER') self.anchor = self.size / -2
 mob.init(self, pos, self.spr, self.size)
 self.dmg = dmg
end
function t_bullet:canhit(player)
 return true
end
function t_bullet:oncollide(player)
 if (self:canhit(player)) then
  local didhit = player:dmghit(self.dmg)
  if (didhit) self.stage:loghit(self)
  if (self.destroy_on_dmg and didhit) self:destroy()
 end
end
function t_bullet:update()
 self.pos += self.vel
 self.vel += self.acc

 -- if (self.stage.mclock % 4 == 0)
 if (self.vel:mag() > 0 and debug and self.stage.mclock % 4 == 0) self.stage:add(t_trailparticle(self.pos))

 mob.update(self)
end
function t_bullet:drawdebug()
 mob.drawdebug(self)
 if debug then
  local spx, spy = self.pos:unpack()
  line(spx, spy,
   mrconcatu(self.pos+self.vel*20, 4))
  line(spx, spy,
   mrconcatu(self.pos+self.acc*100, 8))
 end
end

local t_bullet_area = t_bullet:extend{}
function t_bullet_area:init(pos, dmg, size, ttl)
 self.size = size
 self.ttl = ttl
 t_bullet.init(self, pos, dmg)
end
function t_bullet_area:draw()
 pal(self.paltab)
 -- paltt(self.tcol)
 rectfill(mrconcatu(self.hbox:grow(vec_noneone), 7))
 mob.drawdebug(self)
end

local b_area_gapbar = t_bullet_area:extend{
 ttl = 400,
 z = 4,
 vel = vec(0, 0.4),
 hbox_offset = vec(0),
 anchor = vec(0),
 dynamic = true,
}
function b_area_gapbar:init(pos, size, dmg)
 self.size = size
 self.hbox_offset = vec(0)
 self.anchor = vec(0)
 t_bullet.init(self, pos, dmg)  -- ?
end

local b_area_sinbar = b_area_gapbar:extend{
 xfunc = sin,
 gap = 20,
}
function b_area_sinbar:coupdate()
 while true do
  self.hbox_offset.x = self.xfunc(self.pos.y/128)*self.gap
  yield()
 end
end

local b_fall = t_bullet:extend{
 z = 4,
 ttl = 300,
 anim = {016, 017, 018, 019},
 frame_len = 4,
 size = vec(6),
 bsize = vec(4),
 vel = vec(0, 0.3)
}

local b_mine = t_bullet:extend{
 ttl = 800,
 anim = {001},
 size = vec(4)
}

b_meteorexp = t_bullet:extend{
 ttl = 100,
 anim = {016, 017, 018, 019},
 frame_len = 4,
 size = vec(6),
 bsize = vec(4),
 friction = 0.95,
 -- anchor = vec(-2),
 -- hbox_offset = vec(-2),
 vel = vec(0, 0)
}
function b_meteorexp:init(pos, vel, ttl, dmg)
 self.vel = vel
 self.ttl = ttl
 t_bullet.init(self, pos, dmg)
 if (vel.x == 0 or vel.y == 0) self.friction -= 0.002  -- yeah,
end
function b_meteorexp:update()
 self.vel *= self.friction
 if (self.vel:mag() < 0.1) then
  -- cheapen calculations
  self.vel = vec_zero
  self.friction = 1
 end
 t_bullet.update(self)
end

local b_thrown = t_bullet:extend{
 ttl = 300,
 anim = {016, 017, 018, 019},
 frame_len = 4,
 size = vec(6),
 bsize = vec(4),
 angle_offset = nil
}
function b_thrown:init(pos, delay, dmg)
 t_bullet.init(self, pos, dmg)
 self.delay = delay
end
function b_thrown:coupdate()
 local arena = self.stage.arena
 yieldn(self.delay)
 self.vel = self.stage.o_soul.pos:__sub(self.pos):norm()
 if self.angle_offset then
  self.vel = self.vel:rotate(self.angle_offset)
 end
end

local b_missile = t_bullet:extend{
 ttl = 600,
 anim = nil,
 size = vec(4),
 destroy_on_dmg = false,
 max_vel = 1.0,
 acc_angle = 0.75
}
function b_missile:update()
 local vec_to_player = self.stage.o_soul.pos:__sub(self.pos)
 self.towards = atan2(vec_to_player:unpack())
 local a = self.towards

 -- always rotate the short way!
 if (a-self.acc_angle>.5) a-=1
 if (a-self.acc_angle<-.5) a+=1

 -- gradually rotate toward the player
 local vel_angle = atan2(self.vel:unpack())
 local ang_diff = a-self.acc_angle
 -- don't adjust if already on target
 if abs(ang_diff) > 0.01 then
  local newangle = sgn(ang_diff)/150
  self.acc_angle += newangle
  -- if far away, turn faster
  if (vec_to_player:mag() > 50) self.acc_angle += newangle
  self.acc_angle %= 1
 end
 -- move acceleration closer to towards player
 self.acc = vec(.05, 0):rotate(self.acc_angle)

 -- if angle ~ 90deg, slow down to avoid orbit
 -- local angle_between = abs((self.acc_angle - vel_angle)%0.5)
 -- printa(angle_between)
 -- if angle_between > 0.23 and angle_between < 0.25 then
 --  self.acc -= self.vel:norm()*0.05
 -- end
 -- local angle_between = abs(.5 + self.towards - vel_angle)
 -- -- printa((self.towards - vel_angle), angle_between)
 --  if angle_between < 0.12 then
 --  printa("reverse!")
 --  self.acc -= self.vel:norm()*0.05
 -- end

 if self.vel:mag() > self.max_vel then
  self.vel = self.vel:norm()*self.max_vel
 end
 t_bullet.update(self)
end
function b_missile:draw()
 pal(self.paltab)
 local path = {
  vec(2, 0),
  vec(-6, 3),
  vec(-6, -3),
  vec(2, 0)
 }
 draw_beam(path, self.pos, atan2(self.vel:unpack()), 7)
 t_bullet.draw(self)
end
function b_missile:drawdebug()
 if debug then
  local spx, spy = self.pos:unpack()
  line(spx, spy,
   mrconcatu(self.pos+vec(10, 0):rotate(self.towards), 3))
 end
 t_bullet.drawdebug(self)
end

local b_tocenter = t_bullet:extend{
 ttl = 300,
 anim = {003},
 size = vec(5),
 spin_amt = 0
}
function b_tocenter:coupdate()
 local target = self.stage.arena.hbox:center()
 while true do
  self.vel = target:__sub(self.pos):norm()
  self.vel += self.vel:rotate(0.25):__mul(self.spin_amt)
  local distance = self.pos:__sub(target)
  if distance:mag() < 1 then
   self:destroy()
  end
  yield()
 end
end

local b_tocenter_spin = b_tocenter:extend{
 spin_amt = 1
}

local b_denywall = b_meteorexp:extend{
 friction = 0.969,
 anim = {002},
 dmg = 2,
 -- size = vec(6)
 bsize = vec(6),
}

local b_bounceball = t_bullet:extend{
 ttl = 9000,
 anim = {001},
 vel = vec(.5, -.5),
 dir = 0.25,
 size = vec(4)
}
function b_bounceball:coupdate()
 while (not self.hbox:within(self.stage.arena.hbox)) do
  yield()
 end
 while true do
 if (not self.hbox:within(self.stage.arena.hbox)) self.vel = self.vel:rotate(self.dir)
  yield()
 end
end

local b_bounceball2 = b_bounceball:extend{vel=vec(-0.5, -0.5), dir=-0.25}

-->8
-- patterns

local t_pattern = entity:extend{
 name = "??? pattern",
 lifespan = 200,
 dmg = 0,
 seen = false
}
function t_pattern:init(arena)
 entity.init(self)
 self.arena = arena
 self.children = {}
 self.ttl = self.lifespan
end
-- function t_pattern:drawui()
--  line(0, 0, 128*(self.ttl / self.lifespan), 0, 10)
-- end
function t_pattern:addchild(newbullet)
 if (self.stage) add(self.children, self.stage:add(newbullet))
end
function t_pattern:destroy()
 self.__index.seen = true
 foreach(self.children, function(c) c:destroy() end)
 entity.destroy(self)
end
function t_pattern:dmgstr()
 return self.dmg .. "/ea"
end
function t_pattern:toblurb()
 return self.name
 .. '\ndmg: ' .. tostring(self:dmgstr())
 .. '\nlen: ' .. tostring(self.lifespan / 60) .. ' secs'
end

local pat_rest = t_pattern:extend{
 name = "rest pattern",
 lifespan = 15
}

local pat_lockedrest = t_pattern:extend{
 name = "??????",
 lifespan = 480
}
function pat_lockedrest:toblurb()
 return self.name
 .. '\nbeat pattern\nto unlock'
end

local t_pattern_compound = t_pattern:extend{
 name = "base compound pattern",
 subpatterns = nil,
 dmg = "calc!",
 lifespan = "calc!"
}
function t_pattern_compound:onadd()
 self.children = {}

 -- build dmg string
 local d = ''
 foreach(self.subpatterns, function(a) d ..= tostring(a:dmgstr()) .. ',' end)
 self.dmg = sub(d, 0, #d-1)

 -- normalize subpatterns' lifespans
 for p in all(self.subpatterns) do
  local c = self.stage:add(p(self.arena))
  add(self.children, c)
  self.lifespan = max(self.lifespan, c.lifespan)
 end

 for c in all(self.children) do
  c.lifespan = self.lifespan
  c.ttl = self.lifespan
 end
 self.ttl = self.lifespan
end
function t_pattern_compound:dmgstr()
 return self.dmg
end

-- real patterns

local pat_rain = t_pattern:extend{
 name = "rain",
 dmg = 1,
 lifespan = 8 * 60,
 b = b_fall,
 delay = 20,
 fallspd = vec(0, 0.3)
}
function pat_rain:coupdate()
 local arena = self.stage.arena
 -- our turn
 while true do
  local c = self.b(
   vec(
    rndr(arena.hbox.x0, arena.hbox.x1-4),
    arena.hbox.y0-8
   ),
   self.dmg
  )
  c.vel = self.fallspd
  self:addchild(c)
  yieldn(self.delay)
 end
end

local pat_sinbar = t_pattern:extend{
 name = "sinbar",
 dmg = 2,
 lifespan = 500,
 bullets = {b_area_sinbar, b_area_sinbar:extend{xfunc = cos}}
}
function pat_sinbar:coupdate()
 local arena = self.stage.arena
 local gap = 24
 -- our turn
 while true do
  local width = rndr(arena.hbox.x0+gap, arena.hbox.x1-gap)
  local bar = rndc(self.bullets)
  self:addchild(bar(
    vec(-64, -4),
    vec(width+64, 4),
    self.dmg
   ))
  self:addchild(bar(
    vec(width+gap, -4),
    vec(128-width, 4),
    self.dmg
   ))
  yieldn(80)
 end
end

local pat_gapbar = pat_sinbar:extend{
 name = "gapbar",
 dmg = 2,
 lifespan = 500,
 bullets = {b_area_gapbar}
}

local pat_redbar = t_pattern:extend{
 name = "redbar",
 dmg = 2,
 lifespan = 300
}
function pat_redbar:coupdate()
 while true do
  self:addchild(b_redbar_tb(
    vec(self.stage.arena.hbox.x0, -3),
    vec(self.stage.arena.hbox.w, 3),
    self.dmg
   ))
  yieldn(80)
 end
end

local pat_bluebar = t_pattern:extend{
 name = "bluebar",
 dmg = 2,
 lifespan = 300
}
function pat_bluebar:coupdate()
 while true do
  self:addchild(b_bluebar_lr(
    vec(128, self.stage.arena.hbox.y0),
    vec(3, self.stage.arena.hbox.h), 800),
   self.dmg)
  yieldn(120)
 end
end

local pat_circthrow = t_pattern:extend{
 name = "circthro",
 dmg = 1,
 lifespan = 6 * 60,
 numbullets = 30
}
function pat_circthrow:coupdate()
 local arena = self.stage.arena
 local r = 50
 local n = self.numbullets
 local rotation = rndi(4)/4  -- rotate whole spiral around center
 for i = 1, n do
  self:addchild(b_thrown(vec(
     r*cos(i/n + rotation),
     r*sin(i/n + rotation)
    ) + arena.hbox:center(),
    2*n+10,
    self.dmg
   )
  )
  yieldn(2)
 end
end

local pat_randthrow = t_pattern:extend{
 name = "thrower",
 dmg = 1,
 lifespan = 5 * 60
}
function pat_randthrow:coupdate()
 local arena = self.stage.arena
 local n = 10
 local r = 50
 for i = 1, n do
  theta = rnd()
  self:addchild(b_thrown(vec(
     r*cos(theta),
     r*sin(theta)
    ) + arena.hbox:center(),
    8*n,
    self.dmg))
  yieldn(8)
 end
end

local pat_spreadthrow = t_pattern:extend{
 name = "sprdgun",
 dmg = 1,
 lifespan = 6 * 50,
 seen = true,
 bullet = b_thrown
}
function pat_spreadthrow:coupdate()
 while true do
  self:fire(self:firepos(), 3)
  yieldn(50)
 end
end
function pat_spreadthrow:fire(pos, numbullets)
 local spreads = {
  [3] = {-0.07, 0, 0.07},
  [4] = {-0.09, -0.03, 0.03, 0.09}
 }
 for angle_offset in all(spreads[numbullets]) do
  local b = self.bullet(pos, 30, self.dmg)
  b.angle_offset = angle_offset
  self:addchild(b)
 end
end
function pat_spreadthrow:firepos()
 local arena = self.stage.arena
 return vec(
  rndr(arena.hbox.x0, arena.hbox.x1-4),
  arena.hbox.y0-8
 )
end

local pat_spreadthrow_rapid = pat_spreadthrow:extend{
 name = "sprdgunr",
 bullet = b_thrown:extend{anim={001}, size=vec(4)},
 lifespan = 390,  -- (32 + 58) * 4 + 30
}
function pat_spreadthrow_rapid:coupdate()
 while true do
  local p = self:firepos()
  for i=0,4 do
   self:fire(p, 3)
   yieldn(8)
  end
  yieldn(58)
 end
end

local pat_spreadthrow_odd = pat_spreadthrow:extend{
 name = "sprdguno",
}
function pat_spreadthrow_odd:coupdate()
 while true do
  self:fire(self:firepos(), 4)
  yieldn(40)
 end
end

local pat_spreadthrow_mix = pat_spreadthrow:extend{
 name = "sprdalt",
 dmg = 1,
 lifespan = 5 * 60
}
function pat_spreadthrow_mix:coupdate()
 while true do
  self:fire(self:firepos(), 3)
  yieldn(40)
  self:fire(self:firepos(), 4)
  yieldn(40)
 end
end

local pat_miner = t_pattern:extend{
 name = "miner",
 lifespan = 6 * 60,
 dmg = 1,
 density = 4
}
function pat_miner:coupdate()
 local arena = self.stage.arena
 local o_soul = self.stage.o_soul
 local warntime = 45
 local vecs = {}
 for x = 0, self.density-1 do
  for y = 0, self.density-1 do
   add(vecs, (vec(0.5)+vec(x, y))/self.density)
  end
 end
 shuffle_table(vecs)
 for v in all(vecs) do
  warnbox = bbox(
   arena.hbox.origin + v:dotp(arena.hbox.size),
   vec(0,0)
  ):outline(5)

  local bigbox = warnbox:outline(2)
  -- if not o_soul.hbox:overlaps(bigbox) then
  self:addchild(t_warnbox(warnbox.origin, false, warnbox.size, {ttl=warntime}))
  self.stage:schedule(warntime, closure(self.addchild, self, b_mine(bigbox:center(), self.dmg)))
  -- end
  yieldn(4)

 end
end
local pat_miner_d3 = pat_miner:extend{
 density = 3
}
local pat_missile = t_pattern:extend{
 name = "missile",
 dmg = 4,
 lifespan = 8 * 60,
 delay = 0
}
function pat_missile:coupdate()
 yieldn(self.delay)
 self:addchild(b_missile(vec(rndr(0,128), 0), self.dmg))
end

local pat_meteor = t_pattern:extend{
 name = "meteor",
 lifespan = 8 * 60,
 dmg = 3,
 density = 3,
 simul = 3,
 warntime = 55,
 pause_between = 60
}
function pat_meteor:coupdate()
 local arena = self.stage.arena
 local o_soul = self.stage.o_soul
 local bttl = self.pause_between*(self.simul - 0.5)
 local vecs = {}
 for x = 0, self.density-1 do
  for y = 0, self.density-1 do
   add(vecs, (vec(0.5)+vec(x, y))/self.density)
  end
 end
 while true do
  local v = rndc(vecs)
  -- remove in-use space from pool
  del(vecs, v)

  local hitbox = bbox(
   arena.hbox.origin + v:dotp(arena.hbox.size),
   vec(0,0)
  ):outline(10)

  self:addchild(t_warnbox(hitbox.origin, false, hitbox.size, {ttl=self.warntime}))

  self.stage:schedule(self.warntime, function()
    local n = 10
    for i = 1, n do
     self:addchild(b_meteorexp(
       hitbox:center(),
       vec(cos(i/n), sin(i/n))*0.90,
       bttl,
       self.dmg)
     )
    end
   end)

  -- Space freed, return to pool
  self.stage:schedule(self.warntime + self.pause_between*self.simul, closure(
    add, vecs, v
   ))
  yieldn(self.pause_between)
 end
end

local pat_circgrav = t_pattern:extend{
 name = "gravity",
 dmg = 1,
 lifespan = 6 * 60,
 numbullets = 4,
 delay = 60,
 bullet = b_tocenter
}
function pat_circgrav:coupdate()
 while true do
  self:spawnwave(self.numbullets, 0)
  yieldn(self.delay)
  self:spawnwave(self.numbullets, 1/(self.numbullets*2))
  yieldn(self.delay)
 end
end
function pat_circgrav:spawnwave(n, angle_offset)
 local arena = self.stage.arena
 local r = 70
 for i = 1, n do
  self:addchild(self.bullet(vec(
     r*cos(i/n + angle_offset),
     r*sin(i/n + angle_offset)
    ) + arena.hbox:center(),
    self.dmg
   )
  )
 end
end

local pat_circgrav_rot = pat_circgrav:extend{
 name = "gravspin",
 dmg = 1,
 lifespan = 6 * 60,
 numbullets = 5,
 bullet = b_tocenter_spin
}

local pat_denyring = t_pattern:extend{
 name = "denring",
 dmg = 1,
 lifespan = 3 * 60,
 numbullets = 24
}
function pat_denyring:coupdate()
 local arena = self.stage.arena
 local r = 60
 local n = self.numbullets
 local rotation = rndi(4)/4  -- rotate whole spiral around center
 for i = 1, n do
  local bpos = vec(
   r*cos(i/n),
   r*sin(i/n)
  ) + arena.hbox:center()
  local bul = b_denywall(
   bpos,
   self.stage.arena.hbox:center():__sub(bpos):norm(),
   self.lifespan,
   self.dmg
  )
  self:addchild(bul)
 end
end

local pat_mined_missile = t_pattern_compound:extend{
 name = "missmine",
 subpatterns = {pat_miner_d3, pat_missile}
}

local pat_comp_missile = t_pattern_compound:extend{
 name = "dblmsle",
 subpatterns = {pat_missile, pat_missile:extend{
   delay = 45
  }}
}

local pat_bounceball = t_pattern:extend{
 name = "brkout",
 dmg = 1,
 lifespan = 5 * 60,
 loops = 2,
 cadence = 50
}
function pat_bounceball:coupdate()
 local arena = self.stage.arena
 for i = 1, self.loops do
  for b in all{b_bounceball, b_bounceball2} do
   self:addchild(b(
    vec(
     rndr(arena.hbox.x0+12, arena.hbox.x1-12),
     arena.hbox.y1+8
    ),
    self.dmg))
   yieldn(self.cadence)
  end
 end
end

local pat_bounceball2 = pat_bounceball:extend{
 name = "arkanoid",
 lifespan = 6 * 60,
 loops = 3,
 cadence = 45
}

local pat_comp_rain_2 = t_pattern_compound:extend{
 name = "rain x2",
 subpatterns = {pat_rain:extend{
   fallspd = vec(0, 0.3),
   delay = 40
  }, pat_rain:extend{
   fallspd = vec(0, 0.6),
   delay = 40
  }
 }
}

local pat_comp_grav = t_pattern_compound:extend{
 name = "dengrav",
 subpatterns = {pat_circgrav, pat_denyring}
}

local pat_comp_grav_deny = t_pattern_compound:extend{
 name = "grav sp",
 subpatterns = {pat_circgrav_dense, pat_denyring}
}

local lib_patterns_easy = {
 pat_rain,
 pat_gapbar,
 pat_miner,
 pat_missile,
 pat_circgrav,
 pat_bounceball,
 pat_denyring,
}
local lib_patterns_med = {
 pat_meteor,
 pat_spreadthrow,
 pat_circthrow,
 pat_randthrow,
 pat_circgrav_rot,
 -- pat_circgrav_dense,
 pat_comp_grav
}
local lib_patterns_hard = {
 pat_comp_missile,
 pat_comp_rain_2,
 pat_bounceball2,
 -- pat_comp_spreadbar,
 pat_mined_missile,
 -- pat_comp_rain,
 pat_sinbar,
 pat_comp_grav_deny,
 pat_spreadthrow_rapid,
 pat_spreadthrow_mix
}

local lib_patterns = arrConcat(lib_patterns_easy, lib_patterns_med, lib_patterns_hard)

-->8
-- stages

local t_arena_frame = entity:extend{
 z = 5
}
function t_arena_frame:init(parent)
 self.parent = parent
 entity.init(self)
end
function t_arena_frame:draw()
 local box = self.parent.hbox:grow(vec_noneone):outline(3)
 rectfill(0, 0, 128, box.y0, 00)
 rectfill(0, 0, box.x0, 128, 00)
 rectfill(0, box.y1, 128, 128, 00)
 rectfill(box.x1, 0, 128, 128, 00)
end

local t_arena = mob:extend{
 cur_pattern = nil,
 z = -1,
 onlypattern = nil,
 patternbag = {},
 pause = false,
 difficulty_cutoff = 15
}
function t_arena:update()
 if (self.cur_pattern and self.cur_pattern._doomed) self.cur_pattern = nil

 if (not self.pause and self.stage.o_soul.hp <= 0) then
  -- game over
  save_cartdata()
  self.pause = true
  self.cur_pattern:destroy()
  self.stage.o_soul:explode()
 end

 mob.update(self)
end
function t_arena:onadd()
 self.stage.arena = self
 self.stage:add(t_arena_frame(self))
 self.wave_num = 0
 self.perfect_waves = 0
end
function t_arena:coupdate()
 while true do
  -- Rest
  if not self.onlypattern then
   -- printh("resting")
   self.cur_pattern = self.stage:add(pat_rest(self))
   while (self.cur_pattern) do yield() end
  end

  -- New wave
  self:new_wave()
  self.waveperfect = true
  while (self.cur_pattern) do yield() end
  while (self.pause) do yield() end
  if self.waveperfect then
   self.perfect_waves += 1
   self.stage:addscore(points_waveperfect, 10)
  else
   self.stage:addscore(points_wave)
  end
 end
end
function t_arena:new_wave()
 if self.onlypattern then
  -- Skip bag logic/difficulty
  self.cur_pattern = self.stage:add(self.onlypattern(self))
  return
 end

 -- debug save
 save_cartdata()

 -- Pick random pattern
 -- Add new pattern to stage
 -- Set cur_pattern to new pattern
 -- Wait for cur_pattern to die
 self.wave_num += 1
 if self.wave_num == 1 then
  self.patternbag = {pat_spreadthrow} -- pat_rest,
 elseif #self.patternbag < 1 or self.wave_num == self.difficulty_cutoff then
  if self.wave_num >= self.difficulty_cutoff then
   -- printh("New hard/med bag")
   self.patternbag = arrConcat(lib_patterns_med, lib_patterns_hard)
  else
   -- printh("New easy/med bag")
   self.patternbag = arrConcat(lib_patterns_easy, lib_patterns_med)
  end
  shuffle_table(self.patternbag)
 end
 local pat = rndc(self.patternbag)
 del(self.patternbag, pat)
 self.cur_pattern = self.stage:add(pat(self))
 return
end
function t_arena:draw()
 local drawbox = self.hbox:grow(vec_noneone):outline(1)
 rectfill(mrconcat({drawbox:unpack()}, 0))
 rect(mrconcat({drawbox:unpack()}, 3))
 rect(mrconcat({drawbox:outline(1):unpack()}, 11))
 mob.draw(self)
end
-- function t_arena:drawui()
--  local label = "undefined"
--  if (self.cur_pattern) then
--   label = self.wave_num .. ':' .. self.cur_pattern.name
--  end
--  print(label, 0, 1, 7)
-- end

local t_scoreclock = entity:extend{}
function t_scoreclock:drawui()
 local highcol = 7
 if (high_score == self.stage.score) highcol = 10
 prints("score ".. self.stage.score..'00', 128, 116, 7, 0, 2)
 prints("high ".. high_score..'00', 128, 122, highcol, 0, 2)
end

local t_scorefx = particle:extend{
 ttl = 60
}
function t_scorefx:init(pos, vel, score, color)
 self.score = score
 self.color = color
 particle.init(self, pos, vel, vec_zero, self.ttl, color, 10)
end
function t_scorefx:draw()
 prints(self.score..'00', mrconcatu(self.pos, self.color, 0, 2))
end

st_game = stage:extend{}
function st_game:init()
 stage.init(self)

 self.o_arena = self:add(t_arena(vec(32), false, vec(64)))
 self.o_soul = self:add(t_soul(self.o_arena.hbox:center()))
 self:add(t_graze(self.o_soul))
 self:add(t_scoreclock())

 self.score = 0
 self.stats = {}
 music(00)
end
function st_game:addscore(points, color)
 color = color or 7
 self.score += points
 high_score = max(high_score, self.score)
 self:add(t_scorefx(vec(128, 116), vec(0, -0.5), points, color))
end
function st_game:loghit(bullet)
 local cur_pattern_name = self.arena.cur_pattern.name
 -- printa("took damage of", bullet.dmg, "during pattern", cur_pattern_name)
 if (not self.stats[cur_pattern_name]) self.stats[cur_pattern_name] = 0
 self.stats[cur_pattern_name] += bullet.dmg
-- printa(self.stats)
end

local t_inspectmenu = entity:extend{
 sel_index = 1,
 menubox = bbox.fromxywh(16,88,64,32),
 sel_origin = vec(92, 12)
}
function t_inspectmenu:onadd()
 self:update_sel()
 self.backheld = 0
end

function t_inspectmenu:drawui()
 rect(mrconcatu(self.menubox, 7))
 local sel_index = self.sel_index
 local symbols = {
  [sel_index-1]="\f6❎",
  [sel_index]="\f8♥",
  [sel_index+1]="\f6🅾️"
 }
 local sel_origin = self.sel_origin
 if (sel_index > 8) sel_origin -= vec(0, (sel_index-8)*8)
 for i,v in ipairs(lib_patterns) do
  local c = 7
  if symbols[i] then
   if (i == sel_index) c = 10
   print(symbols[i], mrconcatu(sel_origin + vec(-8, i*8)))
  end
  local label = "??????"
  if (v.seen) label = v.name
  print(label, mrconcatu(sel_origin + vec(0, i*8), c))
 end

 local cur_pat = self.stage.o_arena.cur_pattern
 if (cur_pat) print(cur_pat:toblurb(), mrconcatu(self.menubox.origin + vec(2), 7))

 -- TODO backheld gauge
 print("❎",5, 108, 5)
 circ(8, 120, 6, 5)
 if (self.backheld > 1) circfill(8, 120, self.backheld/10, 2)
end
function t_inspectmenu:update()
 entity.update(self)
 local newindex = self.sel_index
 -- Scroll up/down
 if (btnp(4)) newindex += 1
 if (newindex > #lib_patterns) newindex = 1
 if (btnp(5)) newindex -= 1
 if (newindex < 1 ) newindex = #lib_patterns

 if newindex != self.sel_index then
  self.sel_index = newindex
  self:update_sel()
 end

 if (btn(5)) then
  self.backheld += 1
 else
  self.backheld = max(0, self.backheld-2)
 end
 -- TODO "hold back" entity w/ animation
 if (self.backheld > 60) cur_stage = st_mainmenu()
end
function t_inspectmenu:update_sel()
 -- Updates selection on change or init
 -- printa(self.sel_index, #lib_patterns)
 local arena = self.stage.o_arena
 local focused_pattern = lib_patterns[self.sel_index]
 if focused_pattern.seen then
  arena.onlypattern = lib_patterns[self.sel_index]
 else
  arena.onlypattern = pat_lockedrest
 end
 if (arena.cur_pattern) arena.cur_pattern:destroy()
end

st_game_inspect = st_game:extend{
 addscore = nop
}
function st_game_inspect:init(pat_index)
 stage.init(self)

 self.o_arena = self:add(t_arena(vec(16), false, vec(64)))
 self.o_soul = self:add(t_soul(self.o_arena.hbox:center()))
 self.o_soul.isdemo = true
 self:add(t_graze(self.o_soul))
 -- printa(pat_index)
 local o_inspectmenu = self:add(t_inspectmenu())
 o_inspectmenu.sel_index = pat_index

-- self.o_arena.onlypattern = lib_patterns[pat_index]
end

function st_game_inspect:loghit(bullet)
-- pass
end
-- Menus

local t_postgame = entity:extend{}
function t_postgame:init(game)
 entity.init(self)
 self.game = game
 self.ticks = 0

 self.hardname = "none"
 self.hardnum = 0
 for name, num in pairs(game.stats) do
  if (num > self.hardnum) self.hardname = name; self.hardnum = num
 end
end
function t_postgame:drawui()
 drawtitle("heart end", 7, 0)
 local tick_level = self.ticks
 local arena = self.game.arena
 if (debug) prints(tick_level, 64, 0, 7, 0, 1)

 local rowi = 1
 local a, b
 function nrow() rowi += 1; return rowi end
 function r(i) return 16+(7*i) end
 function myprint(s, i, align, c)
  prints(s, 16 * (align or 4), r(i), (c or 7), 0, 1)
 end
 if tick_level > 1 then
  myprint("score", nrow())
  a = nrow(); myprint(self.game.score..'00', a)
  if (debug or self.game.score == high_score) myprint('new best!', a, 6, 10)
  rowi += 0.5
 end
 if tick_level > 2 then
  myprint("high", nrow())
  myprint(high_score..'00', nrow())
  rowi += 0.5
 end
 if tick_level > 3 then
  a = nrow(); myprint("waves", a, 3)
  b = nrow(); myprint(arena.wave_num, b, 3)
  rowi += 0.5
 end
 if tick_level > 4 then
  myprint("perfect", a, 5)
  myprint(arena.perfect_waves, b, 5)
  rowi += 0.5
 end
 if tick_level > 5 then
  myprint("most dmg", nrow())
  b = nrow(); myprint(self.hardname, b, 3)
  myprint(self.hardnum, b, 5)
  rowi += 0.5
 end
 if tick_level > 6 then
  prints("🅾️again", 32, 112, 7, 0, 1)
  prints("❎return", 96, 112, 7, 0, 1)
 end
end
function t_postgame:coupdate()
 local input_block = false
 for x=0,6 do
  yieldn(15)
  if (not btn(5)) yieldn(15)
  self.ticks += 1
  sfx(sfx_screentick)
 end
 self.ticks = 7
 if (btn(5)) input_block = true  -- don't skip to menu
 while true do
  if not input_block then
   if (btnp(5)) cur_stage = st_mainmenu()
   if (btnp(4)) cur_stage = st_game()
  end
  if (not btn(5)) input_block = false
  yield()
 end
end

st_postgame = stage:extend{}
function st_postgame:init(game)
 stage.init(self)
 self:add(t_postgame(game))
 music(-1)
end

local t_mainmenu = entity:extend{
 textcolor=0,
 greyscale=split"0, 0, 1, 5, 13, 6, 7"
}

function t_mainmenu:drawui()
 -- for i, s in ipairs{"heart&"} do
 drawtitle("heart&", self.greyscale[self.textcolor], self.greyscale[self.textcolor-4])
-- printa(self.choicer.selected)
-- end
end
function t_mainmenu:coupdate()
 -- skip animation in debug mode
 if not debug then
  for i = 0, #self.greyscale do
   self.textcolor = i
   yieldn(10)
  end
  yieldn(30)
 else
  self.textcolor = #self.greyscale
 end
 self:mainmenu()
end
function t_mainmenu:mainmenu()
 local choices = {
  {"start", function()
    cur_stage = st_game()
   end},
  {"library", function()
    cur_stage = st_game_inspect(i)
   end},
  {"help", closure(self.mainmenu, self)}
 }
 if high_score >= 100 then
  add(choices, {"hard", function()
     cur_stage = st_game()
     cur_stage.o_arena.difficulty_cutoff = 0
     local soul = cur_stage.o_soul
     soul.maxhp -= 10
     soul.maxsp += 10
     soul.hp = min(soul.maxhp, soul.hp)
    end}, 2)
 end
 self.stage:add(choicer(choices, {pos=vec(16, 64)}))
end

st_mainmenu = stage:extend{}
function st_mainmenu:init()
 stage.init(self)
 self:add(t_mainmenu())
 music(-1)
end

-->8
--pico-8 builtins

local has_save = cartdata("hearten")

if has_save then
 high_score = dget(0)

 function map_seg(table, seen_map)
  local val = 1
  for i,v in ipairs(table) do
   printa(seen_map, v.name, val, (val & seen_map))
   if ((val & seen_map) > 0) v.seen = true
   val *= 2
  end
 end

 map_seg(lib_patterns_easy, dget(1))
 map_seg(lib_patterns_med,  dget(2))
 map_seg(lib_patterns_hard, dget(3))
else
 high_score = 10
end

function save_cartdata()
 dset(0, high_score)

 printa("saving")

 function map_seg(table)
  local seen_map = 0b0
  local val = 1
  for i,v in ipairs(table) do
   if (v.seen) seen_map += val
   val *= 2
  end
  return seen_map
 end
 dset(1, map_seg(lib_patterns_easy))
 dset(2, map_seg(lib_patterns_med))
 dset(3, map_seg(lib_patterns_hard))
end

function _init()
 cur_stage = st_mainmenu()
 menuitem(1, "reset save data",
  function()
   for i=0,1 do
    dset(i, 0)
   end
   extcmd("reset")
  end
 )
 if debug then
  menuitem(2, "unlock library",
   function()
    for i,v in ipairs(lib_patterns) do
     v.seen = true
    end
    save_cartdata()
   end
  )
 end
end

function _update60()
 cur_stage:update()
end

function _draw()
 cur_stage:draw()
end
__gfx__
08808800877888887777788887778888001111000111100000700000077000000777000000700000000000000000000000000000000000000000000000000000
88888880777788887070788877707888010000101000010007770000777770007777700007770000000000000000000000000000000000000000000000000000
88888880777788887777788877777888100000010000001007770000777777007777700007770000000000000000000000000000000000000000000000000000
88888880877888887700788870777888100000000000001077777000777770000777000077777000000000000000000000000000000000000000000000000000
08888800888888887777788887778888100000000000001077777000077000000777000077777000000000000000000000000000000000000000000000000000
00888000888888888888888888888888100000000000001007770000000000000070000007770000000000000000000000000000000000000000000000000000
00080000888888888888888888888888100000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888888888888888888888100000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000
88778888877888888888888888877888010000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000
87777888777788888777788888777788010000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000
87777888777778887777778887777788001000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000
87777888877777887777778877777888000100000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000
87777888887777888777788877778888000010000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88778888888778888888888887788888000001000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888888888888888888888888888000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888888888888888888888888888000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00112233877778888777888887778888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00112233777077887787788877877888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44556677777777887888788878887888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44556677707777887787788877877888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8899aabb777077888777888887778888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8899aabb877778888888888888888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccddeeff888888888888888888888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccddeeff888888888888888888888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100001d0501a0500c0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800001162500600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
000500000555005550055500455000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000002405429054350540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800000b05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000002405429054350543505435054000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010e00001c0300000017050180501a050000001805017050150500000015050180501c050000001a05018050170500000017050180501a050000001c050000001805000000150500000015050000000000000000
010e00001a050000001a0501d05021050000001f0501d0501c0500000000000180501c050000001a05018050170500000017050180501a050000001c050000001805000000150500000015050000000000000000
__music__
01 0a424344
02 0b424344

