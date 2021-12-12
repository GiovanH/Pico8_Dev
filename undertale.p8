pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- title
-- author

-- global vars

-- game controller restores health between waves,
--  picks and starts patterns
-- No-hit bonus
-- no-graze bonus
-- hp delta with juicy animated changes

local debug = true  -- (stat(6) == 'debug')
local cur_stage = nil

local high_score = 10

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
 end)
dbg = dbg()

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
local function prints(s, x, y, c1, c2, left)
 local screen_width = 128
 if (left) x -= (#s * 4)
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

-- Draw the vector connecting the points in path
function draw_beam(path, origin, theta, color)
 local prev = nil
 for i, v in ipairs(path) do
  local x, y = v:unpack()
  local thisv = origin + vec(
   cos(theta)*x-sin(theta)*y,
   sin(theta)*x+cos(theta)*y
  )
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
function choicer:onadd()
 self.focus = 'choice' .. #self.stage.objects
 self.stage:schedule(0, closure(focus.push, focus, self.focus))
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
 if (focus:isnt(self.focus)) return
 color(8)
 print("♥ ",
  ppos:__add(
   vec(0, self.selected-1):dotp(self.char_size_sp)
  ):unpack())
end
function choicer:update()
 if (focus:isnt(self.focus)) return

 if (btnp(2)) self.selected -= 1; sfx(004)
 if (btnp(3)) self.selected += 1; sfx(004)
 self.selected = clamp(1, self.selected, #self.choices)
 if btnp(4) then
  focus:pop(self.focus)
  self.choices[self.selected][2]()
  self:destroy()
 end
end

-- Player

local t_soul = mob:extend{
 invuln = 0,
 dynamic = true,
 frame_len = 2,
 hp = 20,
 sp = 0,
 maxsp = 20,
 z = 7,
 isdemo = false,
 offset = vec(-3, -3),
 hbox_offset = vec(-3,-3)
}
function t_soul:init(pos)
 mob.init(self, pos, 0, vec(7))
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
 if self.invuln > 0 then
  return false
 else
  if (not self.isdemo) self.hp -= dmg
  self.stage.arena.waveperfect = false
  -- TODO gameover logic
  self.invuln = 12
  sfx(00)
  return true
 end
end
function t_soul:ongraze(bullet)
 if (self.invuln > 0) return false
 if (not self.isdemo) self.sp += 1
 sfx(01)
 if (self.sp >= 20) then
  self.sp = 0
  self.hp = min(20, self.hp + 1)
  self.stage:addscore(2, 11)
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
 local amt, max, col, origin = self.hp, 20, 8, vec(8, 118)
 local perc = amt / max
 local hpbox = bbox(origin, vec(60, 8))
 local hplostv = vec(hpbox.w * (perc - 1), 0)
 rectfill(mrconcatu(hpbox:grow(hplostv), col))
 rect(mrconcatu(hpbox, 10))
 print(amt .. "/" .. max, mrconcatu(origin+vec(2,2), 9))

 local amt, max, col, origin = self.sp, 20, 3, vec(8, 96)
 local perc = amt / max
 local hpbox = bbox(origin, vec(8, -60))
 local hplostv = vec(0, hpbox.h * (perc - 1))
 printa(perc, hpbox, hplost)
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
 rect(self.hbox:grow(vec_noneone):unpack())
 print("!", self.hbox:center():__sub(1, 3):unpack())
-- mob.draw(self)
end

-- Bullets

local t_bullet = mob:extend{
 z = 6,
 dynamic = true,
 ttl = 200,
 dmg = 1,
 hbox_offset = 'CENTER',
 anchor = 'CENTER',
 vel = vec(0),
 acc = vec(0),
 dmg_color = nil,
 destroy_on_dmg = true,
}
function t_bullet:init(pos)
 -- Center
 local csize = self.bsize or self.size
 if (self.hbox_offset == 'CENTER') self.hbox_offset = csize / -2
 if (self.anchor == 'CENTER') self.anchor = self.size / -2
 mob.init(self, pos, self.spr, self.size)
-- self.dmg_color = rndc{nil, "blue", "orange"}
end
function t_bullet:canhit(player)
 if (self.dmg_color == "blue" and not player.moved) return false
 if (self.dmg_color == "orange" and player.moved) return false
 return true
end
function t_bullet:oncollide(player)
 if (self:canhit(player)) then
  local didhit = player:dmghit(self.dmg)
  if (self.destroy_on_dmg and didhit) self:destroy()
 end
end
function t_bullet:update()
 self.pos += self.vel
 self.vel += self.acc

 if (self.dmg_color == "blue") self.paltab = {[7]=12}
 if (self.dmg_color == "orange") self.paltab = {[7]=9}

 mob.update(self)
end
function t_bullet:drawdebug()
 mob.drawdebug(self)
 if debug then
  local spx, spy = self.pos:unpack()
  line(spx, spy,
   mrconcatu(self.pos+self.vel*20, 4))
  line(spx, spy,
   mrconcatu(self.pos+self.acc*10, 8))
 end
end

local t_bullet_area = t_bullet:extend{}
function t_bullet_area:init(pos, size, ttl)
 self.size = size
 self.ttl = ttl
 t_bullet.init(self, pos)
end
function t_bullet_area:draw()
 printa(self.lifespan, self.ttl)
 pal(self.paltab)
 paltt(self.tcol)
 rectfill(mrconcatu(self.hbox:grow(vec_noneone), 7))
 mob.drawdebug(self)
end

local b_fall = t_bullet:extend{
 z = 4,
 ttl = 300,
 anim = {016, 017, 018, 019},
 frame_len = 4,
 dmg = 1,
 size = vec(5, 5),
 hbox_offset = vec(1, 0),
 anchor = vec(0),
 vel = vec(0, 0.3)
}
function b_fall:update()
 t_bullet.update(self)

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
end

local b_mine = t_bullet:extend{
 ttl = 800,
 anim = {001},
 dmg = 1,
 size = vec(4),
 -- anchor = vec(-2),
 -- hbox_offset = vec(-2),
 vel = vec(0, 0)
}

local b_meteorexp = t_bullet:extend{
 ttl = 100,
 anim = {016, 017, 018, 019},
 frame_len = 4,
 dmg = 4,
 size = vec(4),
 -- anchor = vec(-2),
 -- hbox_offset = vec(-2),
 vel = vec(0, 0)
}
function b_meteorexp:init(pos, vel, ttl)
 self.vel = vel
 self.ttl = ttl
 t_bullet.init(self, pos)
end
function b_meteorexp:update()
 self.vel *= 0.95
 t_bullet.update(self)
end

local b_thrown = t_bullet:extend{
 ttl = 300,
 anim = {016, 017, 018, 019},
 frame_len = 4,
 dmg = 1,
 size = vec(6),
 bsize = vec(4)
}
function b_thrown:init(pos, delay)
 t_bullet.init(self, pos)
 self.delay = delay
end
function b_thrown:coupdate()
 local arena = self.stage.arena
 yieldn(self.delay)
 self.vel = self.stage.o_soul.pos:__sub(self.pos):norm()
end

local b_missile = t_bullet:extend{
 ttl = 600,
 dmg = 4,
 anim = nil,
 size = vec(4),
 destroy_on_dmg = false
}
function b_missile:update()
 local v_towards = self.stage.o_soul.pos:__sub(self.pos):norm()
 -- self.acc = self.acc:norm()*0.4+ v_towards*0.05
 self.vel = self.vel*0.88 + v_towards*0.05
 t_bullet.update(self)
 self.v_towards = v_towards
end
function b_missile:draw()
 pal(self.paltab)
 local path = {
  vec(2, 0),
  vec(-6, 3),
  vec(-6, -3),
  vec(2, 0)
 }
 draw_beam(path, self.pos, atan2(self.v_towards:unpack()), 7)
 t_bullet.draw(self)
end

-- Patterns

local t_pattern = entity:extend{
 name = "??? pattern",
 lifespan = 200
}
function t_pattern:init(arena)
 entity.init(self)
 self.arena = arena
 self.children = {}
 self.ttl = self.lifespan
end
function t_pattern:drawui()
 line(0, 0, 128*(self.ttl / self.lifespan), 0, 10)
end
function t_pattern:addchild(newbullet)
 if (self.stage) add(self.children, self.stage:add(newbullet))
end
function t_pattern:destroy()
 foreach(self.children, function(c) c:destroy() end)
 entity.destroy(self)
end
function t_pattern:toblurb()
 return self.name
 .. '\ndmg: ' .. tostring(self.dmg)
 .. '\nlen: ' .. tostring(self.lifespan / 60) .. ' secs'
end

local pat_rest = t_pattern:extend{
 name = "rest pattern",
 lifespan = 60
}

local t_pattern_compound = t_pattern:extend{
 name = "base compound pattern",
 subpatterns = nil,
 dmg = "calc!",
 lifespan = "calc!"
}
function t_pattern_compound:onadd()
 self.children = {}

 local d = ''
 foreach(self.subpatterns, function(a) d ..= tostring(a.dmg) .. ',' end)
 self.dmg = sub(d, 0, #d-1)

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

local pat_rain = t_pattern:extend{
 name = "rain",
 dmg = b_fall.dmg .. '/ea',
 lifespan = 8 * 60
}
function pat_rain:coupdate()
 local arena = self.stage.arena
 -- our turn
 while true do
  self:addchild(b_fall(vec(
     rndr(arena.hbox.x0, arena.hbox.x1-4),
     arena.hbox.y0-8
    )))
  yieldn(20)
 end
end

local pat_circthrow = t_pattern:extend{
 name = "circle thrower",
 dmg = b_thrown.dmg .. '/ea',
 lifespan = 6 * 60
}
function pat_circthrow:coupdate()
 local arena = self.stage.arena
 local n = 40
 local r = 50
 for i = 1, n do
  self:addchild(b_thrown(vec(
     r*cos(i/n),
     r*sin(i/n)
    ) + arena.hbox:center(), 2*n))
  yieldn(2)
 end
end

local pat_randthrow = t_pattern:extend{
 name = "thrower",
 dmg = b_thrown.dmg .. '/ea',
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
    ) + arena.hbox:center(), 8*n))
  yieldn(8)
 end
end

local pat_miner = t_pattern:extend{
 name = "miner",
 lifespan = 6 * 60,
 dmg = b_mine.dmg .. '/ea',
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
  -- printa(arena.hbox)
  warnbox = bbox(
   arena.hbox.origin + v:dotp(arena.hbox.size),
   vec(0,0)
  ):outline(5)

  local bigbox = warnbox:outline(2)
  -- if not o_soul.hbox:overlaps(bigbox) then
  self:addchild(t_warnbox(warnbox.origin, false, warnbox.size, {ttl=warntime}))
  self.stage:schedule(warntime, closure(self.addchild, self, b_mine(bigbox:center())))
  -- end
  yieldn(4)

 end
end
local pat_miner_d3 = pat_miner:extend{
 density = 3
}
local pat_missile = t_pattern:extend{
 name = "missile",
 dmg = b_missile.dmg,
 lifespan = 8 * 60
}
function pat_missile:coupdate()
 self:addchild(b_missile(vec(rndr(0,128), 0)))
end

local pat_meteor = t_pattern:extend{
 name = "meteor",
 lifespan = 8 * 60,
 dmg = b_meteorexp.dmg .. '/ea',
 density = 3,
 simul = 3,
 warntime = 45,
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
  ):outline(14)

  self:addchild(t_warnbox(hitbox.origin, false, hitbox.size, {ttl=self.warntime}))
  -- self.stage:schedule(self.warntime, closure(
  --  self.addchild, self,
  --  t_bullet_area(hitbox:center(), hitbox.size, bttl)
  -- ))

  self.stage:schedule(self.warntime, function()
    local n = 12
    for i = 1, n do
     self:addchild(b_meteorexp(
       hitbox:center(),
       vec(cos(i/n), sin(i/n))*0.95,
       bttl))
    end
   end)

  -- Space freed, return to pool
  self.stage:schedule(self.warntime + self.pause_between*self.simul, closure(
    add, vecs, v
   ))
  -- end
  yieldn(self.pause_between)

 end
end

local pat_comptest = t_pattern_compound:extend{
 name = "compound pattern",
 subpatterns = {pat_miner_d3, pat_missile}
}

local lib_patterns = {
 pat_meteor,
 pat_missile,
 pat_comptest,
 pat_miner,
 pat_rain,
 pat_circthrow,
 pat_randthrow
}

-- Stage

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
-- entity.draw(self)
end

local t_arena = mob:extend{
 cur_pattern = nil,
 z = -1,
 onlypattern = nil
}
function t_arena:update()
 -- move arena with p2
 -- if (btn(0,1)) then self.shape:shift(vec(-8, 0))
 -- elseif (btn(1,1)) then self.shape:shift(vec(8, 0)) end
 -- if (btn(2,1)) then self.shape:shift(vec(0, -8))
 -- elseif (btn(3,1)) then self.shape:shift(vec(0, 8)) end
 if (self.cur_pattern and self.cur_pattern._doomed) self.cur_pattern = nil

 if (self.stage.o_soul.hp <= 0) then
  -- game over
  cur_stage = st_mainmenu()
 end

 mob.update(self)
end
function t_arena:onadd()
 self.stage.arena = self
-- self.stage:add(t_arena_frame(self))
end
function t_arena:coupdate()
 while true do
  -- Rest
  if not self.onlypattern then
   printh("resting")
   self.cur_pattern = self.stage:add(pat_rest(self))
   while (self.cur_pattern) do yield() end
  end

  -- New wave
  self:new_wave()
  self.waveperfect = true
  while (self.cur_pattern) do yield() end
  printa("waveperfect", self.waveperfect)
  if self.waveperfect then
   self.stage:addscore(3, 10)
  else
   self.stage:addscore(1)
  end
 end
end
function t_arena:new_wave()
 -- Pick random pattern
 -- Add new pattern to stage
 -- Set cur_pattern to new pattern
 -- Wait for cur_pattern to die
 local pat = self.onlypattern or rndc(lib_patterns)
 self.cur_pattern = self.stage:add(pat(self))
end
function t_arena:draw()
 -- TODO black frame for layered effects (stage is a hole)

 local drawbox = self.hbox:grow(vec_noneone):outline(1)
 rectfill(mrconcat({drawbox:unpack()}, 0))
 rect(mrconcat({drawbox:unpack()}, 3))
 rect(mrconcat({drawbox:outline(1):unpack()}, 11))
 mob.draw(self)
end
function t_arena:drawui()
 local label = "undefined"
 if (self.cur_pattern) then
  label = self.cur_pattern.name
 end
 print(label, 0, 1)
end

local t_scoreclock = entity:extend{}
function t_scoreclock:drawui()
 local highcol = 7
 if (high_score == self.stage.score) highcol = 10
 prints("score ".. self.stage.score..'00', 128, 116, 7, 0, true)
 prints("high ".. high_score..'00', 128, 122, highcol, 0, true)
end

local t_scorefx = particle:extend{}
function t_scorefx:init(pos, vel, score, color)
 self.score = score
 self.color = color
 particle.init(self, pos, vel, vec_zero, 30, 0)
end
function t_scorefx:draw()
 prints(self.score..'00', mrconcatu(self.pos, self.color, 0, true))
end

st_game = stage:extend{}
function st_game:init()
 stage.init(self)

 self.o_arena = self:add(t_arena(vec(32), false, vec(64)))
 self.o_soul = self:add(t_soul(self.o_arena.hbox:center()))
 self:add(t_graze(self.o_soul))
 self:add(t_scoreclock())

 self.score = 0
end
function st_game:addscore(points, color)
 color = color or 7
 self.score += points
 high_score = max(high_score, self.score)
 self:add(t_scorefx(vec(128, 116), vec(0, -1), points, color))
end

local t_inspectmenu = entity:extend{
 sel_index = 1,
 menubox = bbox.fromxywh(16,88,96,32),
 sel_origin = vec(92, 12)
}
function t_inspectmenu:drawui()
 rect(mrconcatu(self.menubox, 7))
 for i,v in ipairs(lib_patterns) do
  local c = 7
  if i == self.sel_index then
   c = 10
   print("♥", mrconcatu(self.sel_origin + vec(-8, i*8), 8))
  end
  print(v.name, mrconcatu(self.sel_origin + vec(0, i*8), c))
 end

 local cur_pat = self.stage.o_arena.cur_pattern
 if (cur_pat) print(cur_pat:toblurb(), mrconcatu(self.menubox.origin + vec(2), 7))

end
function t_inspectmenu:update()
 entity.update(self)
 local newindex = self.sel_index
 if (btnp(4)) newindex += 1
 if (newindex > #lib_patterns) newindex = 1
 if (btnp(5)) newindex -= 1
 if (newindex < 1 ) newindex = #lib_patterns

 if newindex != self.sel_index then
  printa(newindex, #lib_patterns)
  local arena = self.stage.o_arena
  arena.onlypattern = lib_patterns[newindex]
  arena.cur_pattern:destroy()
  self.sel_index = newindex
 end
end

st_game_inspect = st_game:extend{
 addscore = nop
}
function st_game_inspect:init(pattern)
 stage.init(self)

 self.o_arena = self:add(t_arena(vec(16), false, vec(64)))
 self.o_soul = self:add(t_soul(self.o_arena.hbox:center()))
 self.o_soul.isdemo = true
 self:add(t_graze(self.o_soul))
 self:add(t_inspectmenu())

 self.o_arena.onlypattern = pattern

 self.backheld = 0
end
function st_game_inspect:update()
 st_game.update(self)
 if (btn(5)) then
  self.backheld += 1
 else
  self.backheld = max(0, self.backheld-1)
 end
 -- TODO "hold back" entity w/ animation
 if (self.backheld > 60) cur_stage = st_mainmenu()
end

-- Menus

local t_mainmenu = entity:extend{}
function t_mainmenu:init()
 entity.init(self)
end
function t_mainmenu:drawui()
 for i, s in ipairs{"the title of", "the game"} do
  local x = (128 - (#s * 8)) / 2
  s = "\^w\^t" .. s
  print(s, x, 16+(i-1)*14 + 2, 1)
  print(s, x, 16+(i-1)*14, 7)
 end
end

st_mainmenu = stage:extend{}
function st_mainmenu:init()
 stage.init(self)
 self:add(t_mainmenu())
 self:rootmenu()
end
function st_mainmenu:rootmenu()
 self:add(choicer({
    {"start", function()
      cur_stage = st_game()
     end},
    {"library", closure(self.libmenu, self)},
    {"help", nop}
   }, {pos=vec(16, 64)}))
end
function st_mainmenu:libmenu()
 local choices = {}
 for i,v in ipairs(lib_patterns) do
  add(choices, {v.name, function()
     cur_stage = st_game_inspect(v)
    end})
 end
 self:add(choicer(choices, {pos=vec(18, 66)}))
end

-->8
--pico-8 builtins

function _init()
 cur_stage = st_mainmenu()
end

function _update60()
 cur_stage:update()
-- dbg.watch(cur_stage,"stage")
-- dbg.watch(focus, "focus")
-- dbg.watch(o_soul,"soul")
-- dbg.watch(o_tpattern,"pattern")
end

function _draw()
 cur_stage:draw()
 if (debug) dbg.draw()
end
__gfx__
08808800077000000000000000000000001111000111100000700000077000000777000000700000000000000000000000000000000000000000000000000000
88888880777700000000000000000000010000101000010007770000777770007777700007770000000000000000000000000000000000000000000000000000
88888880777700000000000000000000100000010000001007770000777777007777700007770000000000000000000000000000000000000000000000000000
88888880077000000000000000000000100000000000001077777000777770000777000077777000000000000000000000000000000000000000000000000000
08888800000000000000000000000000100000000000001077777000077000000777000077777000000000000000000000000000000000000000000000000000
00888000000000000000000000000000100000000000001007770000000000000070000007770000000000000000000000000000000000000000000000000000
00080000000000000000000000000000100000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000100000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000
00770000077000000000000000077000010000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777000777700000777700000777700010000000000010000000000770007700777777007777770077000000777700000000000000000000000000000000000
07777000777770007777770007777700001000000000100000000000770007700770077007700770077000000770077000000000000000000000000000000000
07777000077777007777770077777000000100000001000000000000770707700770077007700770077000000770077000000000000000000000000000000000
07777000007777000777700077770000000010000010000000000000777777700770077007777000077000000770077000000000000000000000000000000000
00770000000770000000000007700000000001000100000000000000777077700770077007700770077000000770077000000000000000000000000000000000
00000000000000000000000000000000000000101000000000000000770007700777777007700770077777700777777000000000000000000000000000000000
00000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
010800001162500600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010e00001c0300000017050180501a050000001805017050150500000015050180501c050000001a05018050170500000017050180501a050000001c050000001805000000150500000015050000000000000000
010e00001a050000001a0501d05021050000001f0501d0501c0500000000000180501c050000001a05018050170500000017050180501a050000001c050000001805000000150500000015050000000000000000
__music__
01 0a424344
02 0b424344

