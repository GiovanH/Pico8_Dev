pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- the game
-- gIOVANh

-- global vars

local debug = (stat(6) == 'debug')

local cur_room
local o_player
local score = 0

-->8
-- utility

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

-- create a closure
function closure(fn, ...)
 local vars = {...}
 return (function() fn(unpack(vars)) end)
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

-- isomob
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
 for prop in all{'anchor', 'offset', 'z_is_y', 'tcol'} do
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
  local frame = self.anim[findex]
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
 for prop in all{'hbox_offset', 'dynamic', 'paltab', 'obstructs'} do
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
local stage = obj:extend{

}
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

local facemap_move = {d=vec(0, 1),u=vec(0, -1),l=vec(-1, 0),r=vec(1, 0)}
local facemap_npcspr_off = {d=0, u=2, l=1, r=1}

local dialoger = entity:extend{
 z=2,
 x = 8,
 y = 97,
 color = 0,
 max_chars_per_line = 28,
 max_lines = 4,
 queue = {},
 blinking_counter = 0,
 opts = {},
 init = function(self)
 end,
 enqueue = function(self, message, opts)
  -- default opts to empty
  opts = type(opts) == "nil" and {} or opts
  for _,section in ipairs(split(message, "\r")) do
   add(self.queue, {
     message = section,
     opts = opts
    })
   if #self.queue == 1 then
    focus:push'dialog'
    self:trigger(self.queue[1].message, self.queue[1].opts)
   end
  end

 end,
 trigger = function(self, message, opts)
  self.opts = opts
  self.color = opts.color or 7
  self.bgcolor = opts.bgcolor or 0
  self.current_message = opts.prefix or ''
  self.messages_by_line = nil
  self.current_line_in_table = 1
  self.current_line_count = 1
  self.pause_dialog = false
  self.no_text = (#message == 0)
  self:format_message(message)
  self.animation_loop = nil
  self.animation_loop = cocreate(self.animate_text)
 end,
 format_message = function(self, message)
  -- sets self.messages_by_line to lines from message
  local total_msg = {}
  local word = ''
  local letter = ''
  local current_line_msg = ''

  for i = 1, #message do
   letter = sub(message, i, i)
   word ..= letter

   -- on word break or end of line
   if letter == ' ' or i == #message then
    -- new line length
    local line_length = #current_line_msg + #word
    if line_length > self.max_chars_per_line then
     -- line will overflow, move word to new line.
     add(total_msg, current_line_msg)
     current_line_msg = word
    else
     current_line_msg ..= word
    end

    -- add letter if it's the last and didn't overflow
    if i == #message then
     add(total_msg, current_line_msg)
    end

    -- we've written a full word to the current message
    word = ''
   end
  end

  self.messages_by_line = total_msg
 end,
 animate_text = function(self)
  --> sets self.current_message to partially/fully displayed text
  -- ends when message is fully displayed (plus extra frames if autoplay is true)
  -- for each line, write it out letter by letter
  -- if we each the max lines, pause the coroutine
  -- wait for input in update before proceeding
  for k, line in pairs(self.messages_by_line) do
   self.current_line_in_table = k
   for i = 1, #line do
    self.current_message ..= sub(line, i, i)

    -- press btn 5 to skip to the end of the current passage
    -- otherwise, print 1 character per frame
    -- with sfx about every 5 frames
    if (i % 5 == 0) sfx(self.opts.blip or 001)
    if not btnp(5) then
     yield()
    end
   end
   self.current_message ..= '\n'
   self.current_line_count += 1
   if ((self.current_line_count > self.max_lines) or (self.current_line_in_table == #self.messages_by_line and not self.opts.autoplay)) then
    self.pause_dialog = true
    yield()
   end
  end

  if (self.opts.autoplay) self.yieldn(30)
 end,
 shift = function (t)
  local n=#t
  for i = 1, n do
   if i < n then
    t[i] = t[i + 1]
   else
    t[i] = nil
   end
  end
 end,
 update = function(self)
  if (self.animation_loop and costatus(self.animation_loop) != 'dead') then
   if not self.pause_dialog then
    --> resume animation if not paused
    coresume(self.animation_loop, self)
   else
    if btnp(4) then
     --
     self.pause_dialog = false
     self.current_line_count = 1
     self.current_message = self.opts.prefix or ''
    end
   end
  elseif self.animation_loop and self.current_message then
   if (self.opts.autoplay) self.current_message = self.opts.prefix or ''
   self.animation_loop = nil
  end

  --> not animatinf/displaying, and queue not empty
  --> finished displaying message, so pop it from queue and proceed.
  local anim_dead = (not self.animation_loop) or costatus(self.animation_loop) == 'dead'
  if anim_dead and #self.queue > 0 then
   focus:pop'dialog'
   if (self.opts.callback) self.opts.callback()
   self.shift(self.queue, 1)
   if #self.queue > 0 then
    focus:push'dialog'
    self:trigger(self.queue[1].message, self.queue[1].opts)
    coresume(self.animation_loop, self)
   end
  end

  if not self.opts.autoplay then
   self.blinking_counter += 1
   if self.blinking_counter > 30 then self.blinking_counter = 0 end
  end
 end,
 drawui = function(self)
  if (focus:isnt'dialog') return
  if (self.no_text) return
  local screen_width = 128

  -- display message
  if self.current_message then
   rectfill(1,90,126,126,self.bgcolor)
   rect(1,90,126,126,5)
   print(self.current_message, self.x, self.y, self.color)
  end

  -- draw blinking cursor at the bottom right
  if (not self.opts.autoplay) and self.pause_dialog then  --
   if self.blinking_counter > 15 then
    color(13)
    if self.current_line_in_table == #self.messages_by_line then
     print('◆', screen_width - 11, screen_width - 10)
    else
     -- draw arrow
     for box in all{
      bbox.pack(-12,-9,-8,-9),
      bbox.pack(-11,-8,-9,-8),
      bbox.pack(-10,-7,-10,-7)
     } do
      line(box:shift(vec(screen_width)):unpack())
     end
    end
   end
  end
 end
}

-- interactive debugger
-- based on work by mot ?tid=37822
dbg=function()
 poke(0x5f2d, 1)
 local vars,sy={},0
 local mx,my,mb,pb,click,mw,exp,x,y,dragx0, dragy0,mbox
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
   print(name,x+4,y,12) y+=6
   if var.expand then  -- content
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
  color(1)
  rectfill(box_screen:unpack())
  x=dx+2 y=dy+2-sy

  -- read mouse
  mx,my,mw=stat(32),stat(33),stat(36)
  mb=band(stat(34),1)~=0
  click=mb and not pb and mx>=dx and mx<dx+w and my>=dy and my<dy+h
  pb=mb

  if mb then
   mbox = bbox.pack(dragx0, dragy0, mx, my)
  else
   dragx0, dragy0 = mx, my
   mbox = nil
  end

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
  mbox=function() return mbox end,
  show=show,
  print=prnt
 }
end
dbg = dbg()

-->8
-- game classes

-- isomob: entity with a bounding box and dynamism
-- init(pos, spr, size, kwargs)
-- bsize: extent of bounding box. defaults to size
-- kwargs can set hbox_offset and bsize
-- dynamic: true to automatically regenerate hitbox each frame
-- hbox_offset: vector from pos to hbox
-- get_hitbox(v): hitbox is self.pos were v
local isomob = mob:extend{
 elev=0,
 footy=4,
 obstructs = true,
 z_is_y = true,  -- domain: camera perspective
}
function isomob:init(pos, spr_, size, kwargs)
 kwargs = kwargs or {}
 mob.init(self, pos, spr_, size, kwargs)
 for prop in all{'footy', 'elev'} do
  self[prop] = chainmap(prop, kwargs)
 end
 local halfsize = -self.size.x/2
 self.offset = vec_zero
 self.anchor = kwargs.anchor or vec(halfsize, -self.size.y)
 self.bsize = kwargs.bsize or vec(self.size.x, self.footy)
 self._apos = self.pos + self.anchor + self.offset + vec(0, -self.elev)
 -- hbox should go to one-inside pos
 self.hbox_offset = kwargs.hbox_offset or vec(halfsize, -self.footy)
 self.hbox = self:get_hitbox()
end
function isomob:update()
 mob.update(self)
 self._apos = self.pos + self.anchor + self.offset + vec(0, -self.elev)
end

function prettify_map()
 local tiletable = {
  [066]= 082,
 }
 for x = 0,128 do
  for y=0,64 do
   local state=mget(x, y)
   if (tiletable[state]) mset(x,y,tiletable[state])
  end
 end
end

local t_sign = mob:extend{
 lines = nil,
 blip = 001,
 talkedto = 0,
 istalking = false
}
function t_sign:interact(player, lines)
 lines = lines or self.lines
 if (type(lines) == 'string') lines = {lines}
 if (player.cooldown > 0) return false
 if (#lines < 1) return false
 self.istalking = true
 for _, v in ipairs(lines) do
  if type(v) == 'function' then
   dialoger:enqueue('', {callback=v})
  else
   dialoger:enqueue(v, self)
  end
 end
 dialoger:enqueue('',{callback=function() self.istalking = false end})
 if (self.talkedto != nil) self.talkedto += 1
end

local isosign = isomob:extend{
 lines = nil,
 blip = 001,
 talkedto = 0,
 istalking = false
}
isosign.interact = t_sign.interact

local t_trigger = mob:extend{}
function t_trigger:init(pos, size, dest, deststate)
 mob.init(self, pos, false, size)
 self.dest, self.deststate = dest, deststate
end
function t_trigger:hittrigger(p)
 if (p.justtriggered) return
 if self.deststate then
  cur_room = self.dest(self.deststate.pos)
  o_player.facing = self.deststate.facing
 else
  cur_room = self.dest()  -- let room decide position
 end
 o_player.cooldown = 1
 cur_room:update()  -- align camera
end

local t_player = isomob:extend{
 ismoving = false,
 dynamic = true,
 facing = 'd',
 spr0 = 0,
 cooldown = 0,
 footy=8,
 dynamic=true,
 paltab={[6]=7, [13]=6},
 justtriggered=true
}
function t_player:init(pos, kwargs)
 isomob.init(self, pos, nil, vec8(1,2), kwargs)  -- a little smaller
end
function t_player:_moveif(step, facing)
 local npos = self.pos + step
 local nhbox = self:get_hitbox(npos)
 local unobstructed = nhbox:within(self.stage.box_px)
 local tiles = nhbox:maptiles(self.stage.map_origin)
 for tile in all(tiles) do
  if band(tile.flags, 0b1) == 0 then
   unobstructed = false
   break
  end
 end
 for _,obj in pairs(self.stage.objects) do
  if obj != self then

   if nhbox:overlaps(obj.hbox) then
    if (obj.push) obj:push(self, facing)
    if (obj.obstructs) unobstructed = false; break
   end
  end
 end
 if (facing) self.facing = facing
 if unobstructed then
  self.pos = npos
  self.moved = true
 end
end
function t_player:move()
 -- player movement
 local speed = 1

 if (btn(5)) speed = 2

 self.moved = false

 -- lrudox
 for x=1,speed do
  if btn(0) then
   self:_moveif(vec(-1, 0), 'l')
  elseif btn(1) then
   self:_moveif(vec_x1, 'r')
  end
  if btn(2) then
   self:_moveif(vec(0, -1), 'u')
  elseif btn(3) then
   self:_moveif(vec_y1, 'd')
  end
 end

 self.ismoving = self.moved
end
function t_player:tryinteract()
 -- passive triggers
 local stillintrigger = false
 for _,obj in pairs(self.stage.objects) do
  if (self.hbox:overlaps(obj.hbox) and obj.hittrigger) then
   stillintrigger = true
   obj:hittrigger(self)
   break
  end
 end
 self.justtriggered = stillintrigger
 -- try interact
 if btnp(4) then
  local ibox = bbox(self.hbox.origin, vec_8_8):shift(facemap_move[self.facing]*8)
  -- self.ibox = ibox
  function p_dist(object)
   return (not object.pos) and 0 or self.pos:__sub(object.pos):mag()
  end
  for _,obj in pairs(sorted(self.stage.objects, p_dist)) do
   if (ibox:overlaps(obj.hbox) and obj.interact) then
    if (obj:interact(self) != false) then
     self.cooldown += 2
     break
    end
   end
  end
 else
  ibox = nil
 end
end
function t_player:update()

 self.ismoving = false
 if (focus:is'player') self:move()
 if self.cooldown > 0 then
  self.cooldown -= 1
 elseif focus:is'player' then
  self:tryinteract()
 end

 if (self.ismoving and self.stage.mclock % 10 == 0) sfx(008)

 self.stage.camfocus = self.pos
 isomob.update(self)
end

function t_player:draw()
 self.flipx = (self.facing == 'l')
 self.spr = self.spr0 + facemap_npcspr_off[self.facing]
 if self.ismoving and self.stage.mclock % 8 < 4 then
  self.offset = vec_zero
 else
  self.offset = vec(0, -1)
 end
 isomob.draw(self)
-- if (debug and self.ibox) rect(mrconcatu(self.ibox, 10))
end

local t_npc = isosign:extend{
 facing = 'd',
 spr0 = 0,
}
function t_npc:interact(player)
 local facetable = {
  d='u',
  u='d',
  l='r',
  r='l'
 }
 self.facing = facetable[player.facing]
 isosign.interact(self, player)
end
function t_npc:draw()
 self.flipx = (self.facing == 'l')
 self.spr = self.spr0 + facemap_npcspr_off[self.facing]
 if (self.istalking or self.ismoving) and self.stage.mclock % 8 < 4 then
  self.offset = vec(0, -1)
 else
  self.offset = vec(0, -0)
 end
 mob.draw(self)
end

local scoreui = entity:extend{}
function scoreui:drawui()
 local px, py = o_player.pos:unpack()
 if (py > 120 and px < 37) fillp(0b0011001111001100.1)
 rectfill(0, 120, 32, 128, 9)
 -- rect(0, 120, 32, 127, 10)
 prints(itostr(score, 8), 1, 121, 0, 10)
 fillp()
end

local room = stage:extend{
 camfocus = nil,
 mapbox = nil
}
function room:init(startpos)
 mx, my, mw, mh = self.mapbox:unpack()
 self.map_origin = vec8(mx, my)*2
 self.box_map = bbox.fromxywh(0, 0, mw, mh)
 self.box_cells = self.box_map*16
 self.box_px = self.box_cells*8

 self.camfocus = self.startpos
 stage.init(room)
 o_player = self:add(t_player(startpos or self.startpos))
 self:add(scoreui)
 -- self:add(choicer)
 self:add(dialoger)
end
function room:draw()
 local map_x, map_y = self.map_origin:unpack()
 local cell_w, cell_h = self.box_cells.size:unpack()
 local sx, sy = self.box_px.origin:unpack()

 cls()
 -- pal()
 local cam = self.camfocus - vec(64, 64)
 local cx0, cy0, cx1, cy1 = self.box_px:unpack()

 -- clamp camera
 cam.x = clamp(cx0, cam.x, cx1-128)
 cam.y = clamp(cy0, cam.y, cy1-128)

 -- offset by camera focus
 camera(cam:unpack())
 pal(self.paltab)
 map(map_x, map_y, sx, sy, cell_w, cell_h)
 pal()

 if debug and btn(5) and o_player then

  for x = 0,cell_w do
   for y=0,cell_h do
    pset(mrconcatu(vec8(x, y), (x%2==0 and y%2==0)and 8 or 14))
   end
  end

  for object in all(self.objects) do
   if object.pos then
    line(mrconcatu(o_player.pos, object.pos:unpack()))
   end
  end
 end

 self.cam = cam
 stage.draw(self)

 camera()
 if debug and o_player then

  local ui_offset = cam - self.box_px.origin
  poke(0x5f2d, 1)
  local mous = vec(stat(32), stat(33))
  pset(mrconcatu(mous, 10))
  mous += ui_offset

  prints('plr  ' .. tostr(o_player.pos), 0, 0)
  prints('8' .. tostr(o_player.pos:__div(8)), 64, 0)
  prints('room ' .. tostr(self.map_origin/16), 0, 8)
  prints('mous ' .. tostr(mous), 0, 16)
  prints('8' .. tostr(mous:__div(8)), 64, 16)
 end
end

-->8
-- rooms
local r_thegame = room:extend{
 startpos = vec8(8, 10),
 mapbox = bbox.fromxywh(0, 0, 1, 1)
}
function r_thegame:init(v)
 room.init(self, v)

 local o_sign = self:add(entity({z=0}))
 function o_sign:draw()
  color(7)
  print("\^w\^tthe game", 8, 8)
  line(8, 20, 70, 20)
  print("the rules:\n1. stand in \fathe spot\f7", 8, 24)
 end

 local o_rarr = self:add(mob(vec8(4, 11), 036, vec_16_16, {tcol=0}))
 local o_larr = self:add(mob(vec8(10, 11), 035, vec_16_16, {tcol=0}))

 local o_scorer = self:add(t_sign(vec8(7.5, 11.5), 032, vec_8_8, {
    bsize=vec(16, 12),
    hbox_offset=vec(-4, -2)
   }))
 o_scorer.lines = "it's \fathe spot\f7."
 function o_scorer:draw()
  local large_box = bbox(self.pos - vec8(1, 0.5), vec8(3, 2))
  oval(mrconcatu(large_box, 2))
  oval(mrconcatu(large_box:outline(-2), 2))
  mob.draw(self)
 end
 function o_scorer:update()
  if focus:is'player' and self.stage.mclock % 30 == 0 then
   if o_player.hbox:within(self.hbox) then
    score += 1
    sfx(000)
   end
  end
  mob.update(self)
 end

 self:add(t_trigger(vec8(0, 8), vec8(0.5, 3), r_closet))
 self:add(t_trigger(vec8(15.5, 8), vec8(0.5, 3), r_maze))
 self:add(t_trigger(vec8(13, 0), vec8(1, 1), r_street))

end

r_closet = room:extend{
 startpos = vec8(15, 10),
 mapbox = bbox.fromxywh(0, 1, 1, 0)
}
function r_closet:init(v)
 room.init(self, v)
 self:add(t_trigger(vec8(15.5, 8), vec8(0.5, 3), r_thegame, {
    pos=vec8(0.5, 10)
   }))

 local junktiles = {49, 35, 36, 37, 51, 52, 53}
 for i = 0,4 do
  for j = 0,6 do
   add(junktiles, 64 + i*16 + j)
  end
 end

 for i=1, 14 do
  self:add(mob(vec8(rndr(9,13), rndr(12,14)), rndc(junktiles), vec_8_8, {paltab={[1]=12}}))
 end

 local o_sign = self:add(entity({z=0}))
 function o_sign:draw()
  color(7)
  print("you are now entering", 40, 18)
  print("\^w\^tthe game", 40, 26)
 end

 local o_trash = self:add(isosign(vec8(13, 14.5), 006, vec8(2,3)))
 o_trash.lines = "it's a bin filled with old game elements."

 local o_paint = self:add(t_sign(vec8(2, 13), 033, vec_8_8))
 o_paint.lines = "a paint roller, for putting up game instructions."

 local o_note = self:add(t_sign(vec8(2, 9), 048, vec_8_8))
 o_note.lines = 'it\'s a note.\r"no game over here", it reads.'

 local o_note = self:add(t_sign(vec8(5.5, 7.5), nil, vec8(6, 3)))
 o_note.lines = 'boxes as far as the eye can see.'

 local o_pushcrate = self:add(mob(vec8(4, 12), 071, vec_8_8, {obstructs=true, dynamic=true}))
 o_pushcrate.step = nil
 function o_pushcrate:update()
  self.moved = false
  if (self.step) t_player._moveif(self, self.step)
  if (not self.moved) self.step = nil
  mob.update(self)
 end
 function o_pushcrate:interact(p)
  local stuck = false
  for stuckpos in all(split(
    "0,7|0,14|14,7|14,14|4,8|5,7|11,8|10,9|7,9|8,7"
    , "|")) do
   if (self.pos == vec8(unpack(split(stuckpos)))) stuck = true; break
  end
  if (stuck) return t_sign.interact(self, p, "it's stuck.")
  self:push(p, p.facing)  -- else
 end
 function o_pushcrate:push(p, facing)
  if (self.step) return false
  self.step = facemap_move[facing]
  self.stage:schedule(9, function()
    self.step = nil
   end)
 end
end

r_street = room:extend{
 startpos = vec8(29.5, 12),
 mapbox = bbox.pack(1, 0, 2, 1),
 name = "street"
}
function r_street:init(v)
 room.init(self, v)
 local o_hole = self:add(mob(vec8(29, 13), 009, vec_8_8))
 o_hole.tcol = 15
 o_hole.obstructs = true
 function o_hole:interact(p)
  cur_room = r_thegame(vec8(13.5, 2))
 end

 function newcloud(xpos)
  local cloud = self:add(sprparticle(072, vec(2,1),
    vec8(xpos, rndr(0,2.5)),
    vec(rndr(.1, .4), 0),
    vec_zero,
    (256/0.1)
   ))
  cloud.tcol = 1
 end

 function self:update()
  if (self.mclock % 240 == 0) newcloud(-2)
  room.update(self)
 end

 for x = 0, 16 do
  newcloud(8*x + rndr(0, 8))
 end

 self:add(t_trigger(vec8(0, 12), vec8(0.5, 3), r_closet))

 local o_door = self:add(mob(vec8(27, 5), nil, vec8(1,2)))
 function o_door:interact(p)
  cur_room = r_arcade()
 -- cur_room:update()
 end
 function o_door:draw()
  print("arcade", 210, 33, 0)
  mob.draw(self)
 end

 local o_guy = self:add(t_npc(vec8(31, 12), nil, vec8(1,2),
   {paltab={[2]=3}}))
 o_guy.lines = "hey, you know there's a game down there, right?"

 local o_sign = self:add(isosign(vec8(16+11, 13.5), 010, vec8(2,2), {footy=2}))
 o_sign.lines = "it's a sign. it says there's a game in the hole."

 for pos in all{
  vec8(19.5, 13),
  vec8(16.5, 11),
  vec8(18.5, 6),
 } do
  local o_tree = self:add(isomob(pos, 025, vec8(1,2)))
  o_tree.tcol = 1
 end

 for pos in all{
  vec8(11, 12),
  vec8(11, 16),
  vec8(4, 12),
  vec8(4, 16)
 } do
  local o_bush = self:add(isomob(pos, 057, vec8(2, 1)))
  o_bush.tcol = 1
 end
 local o_lfount = self:add(isomob(vec8(5, 9), 074, vec8(3,4), {obstructs=false, tcol=3}))
 local o_rfount = self:add(isomob(vec8(8, 9), 074, vec8(3,4), {obstructs=false, tcol=3}))
 o_rfount.flipx = true
 self:add(mob(vec8(3.5, 7), nil, vec8(6,1), {obstructs=true}))
 self:add(mob(vec8(4, 6), nil, vec8(5,3), {obstructs=true}))

 self:add(mob(vec8(12, 7), nil, vec(1,16), {obstructs=true}))

 function o_rfount:update()
  if (self.stage != cur_room) return
  for i=1,4 do
   self.stage:add(particle(self._apos, vec(rndr(-1.5, 1.5), -rnd()), vec(0,.4), 10, 12, self.z))
  end
  isomob.update(self)
 end

end

r_maze = room:extend{
 startpos = vec8(.5, 10),
 mapbox = bbox.fromxywh(1, 1, 1, 0)
}
function r_maze:init(v)
 room.init(self, v)
 self:add(t_trigger(vec8(0, 8), vec8(0.5, 3), r_thegame, {
    pos=vec8(15, 10)
   }))

 local megablock = mob:extend{
  paltab={[9]=8}
 }
 function megablock:coupdate()
  local i = 10
  while true do
   i += 1
   if i > #self.states then
    sort(self.states, function(a) return rnd() end)
    i = 1
   end
   if self.states[i] and not o_player.hbox:overlaps(self.hbox) then
    self.obstructs = true
    self.spr = 071
    yield()
    self.tcol = nil
   else
    self.tcol = 4
    yield()
    self.obstructs = false
    self.spr = nil
   end
   yieldn(60)
  end
 end

 for pos in all({
   vec8(6, 10),
   vec8(6, 7),
   vec8(13, 10),
   vec8(18, 4),
   vec8(16, 7),
   vec8(4, 3),
  }) do
  local block = self:add(megablock(pos, 071, vec_8_8))
  block.states = {false, false, true, true, true, true}
 end

 local o_guy = self:add(t_npc(vec8(30, 9), nil, vec8(1,2),
   {paltab={[2]=9}}))
 o_guy.lines = "hi!\ri'm not the game."
end

r_arcade = room:extend{
 startpos = vec8(8, 14),
 mapbox = bbox.pack(3, 0, 1, 1)
}
function r_arcade:init(v)
 room.init(self, v)
 o_player.facing = 'u'
 -- dbg.print(self.objects, 'arcade init')
 self:add(t_trigger(vec8(7, 13.5), vec8(2, 0.5), r_street, {
    pos=vec8(27.5, 8)
   }))
 for i=1, 6 do
  self:add(isomob(vec8(1.5, 6+i), 045, vec8(1,2)))
  if rnd() > 0.2 then
   local o_guy = self:add(t_npc(vec8(2.5, 6+i), nil, vec8(1,2),
     {paltab={[4]=1, [2]=4}}))
   o_guy.facing = 'l'
   o_guy.interact = nop
  end
 end
 for i=1, 2 do
  local o_guy = self:add(t_npc(vec8(3.5+i, 7), nil, vec8(1,2),
    {paltab={[4]=1, [2]=4}}))
  o_guy.facing = 'u'
  o_guy.interact = nop
 end
 local o_guy = self:add(t_npc(vec8(13.5, 11), nil, vec8(1,2), {
    bsize=vec8(2,2),
    hbox_offset=vec8(-1),
    paltab={[2]=14}
   }))
 o_guy.lines = "if you're looking for a game, there's one outside."
 o_guy.facing = 'l'

 local o_machin = self:add(isomob(vec8(8, 6), 044, vec8(1,2), {tcol=15}))
 function o_machin:interact(p)
  cur_room = r_subgame()
 end
-- dbg.print(self.objects, 'arcade postinit')
end

r_subgame = room:extend{
 startpos = vec8(8, 6),
 mapbox = bbox.pack(3, 1, 1, 1)
}
function r_subgame:init(v)
 room.init(self, v)

 self.paltab = {0}
 -- o_player.size = vec_8_8
 o_player.spr = 034
 o_player.draw = mob.draw

 local subscore = 0

 function self:update()
  room.update(self)
  if (btnp(4)) cur_room = r_arcade(vec8(8, 7))
 -- cur_room:update()
 end

 local subscoreui = self:add(entity())
 function subscoreui:drawui()
  -- rect(0, 120, 32, 127, 10)
  print('\^p' .. itostr(subscore, 8), 0, 0, 7)
 end

 local o_scorer = self:add(mob(vec8(6, 7), nil, vec8(4, 3)))
 function o_scorer:update()
  if focus:is'player' and self.stage.mclock % 30 == 0 then
   if o_player.hbox:within(self.hbox) then
    subscore += 1
    sfx(000)
   end
  end
  mob.update(self)
 end
end
-->8
--pico-8 builtins

function _init()
 prettify_map()
 cur_room = r_thegame()
 focus:push'player'
 if debug then
  menuitem(5,'toggle debug',function() debug = not debug end)
 end
end

function _update()
 cur_room:update()
-- dbg.watch(cur_room, "room")
-- dbg.watch(cur_room._tasks, "tasks")
-- dbg.watch(cur_room.objects, "objects")
-- dbg.watch(o_player, "player")
end

function _draw()
 cur_room:draw()
 if (debug) dbg.draw()
end
__gfx__
006666000066660000666600000bb000bbbb00000000bbbb0000000000000000dddddddddddddddd000000000000000056666666666666666666666666666665
06dddd6006dddd6006dddd60000bb000bbbb00000000bbbb00000aaaa0000000dddddddddddddddd000000000000000056666666000000607767777766666665
6dddddd66dddddd66dddddd6000bb000bb000000000000bb0aaaa9999a000000dd55ddd5d060060d066600000006000056666666000000607677777766666665
6d1dd1d66ddd1dd66dddddd6000bb000bb000000000000bb0a9999999a000000dddddddd00666600065566600065600056666666000000606777777766666665
6dddddd66dddddd66dddddd6000bb00000000000000000000a9999999a000000dddddddd00d00d00655555566655600056666666000000607777777666666665
6dd11dd66dddd1d66dddddd6000bb00000000000000000000a9999999a000000ddddddddd000000d655555555555560056666666000000607777776766666665
06dddd6006dddd6006dddd60000bb000000000000000000000a9999999a00000d5dd55dddddddddd655555555555560056666666000000607777767766666665
006666000066660000666600000bb000000000000000000000a9999999a00000dddddddddddddddd555555555555556056666666000000606666666666666665
00622600006226000062260000000000000000000000000000a9999999a0000011111111111bb111665555555555556056666666000000606666666666666665
06222260006226000622226000000000000000000000000000a9999999a555001111111111b33b11006665555555555656666666000000606666666666666665
062222600062260006222260000000000000000000000000051a9999999a1155111111111b3333b1000606665555555656666666000000606666666666666665
064444600064460006444460bbbbbbbb0000000000000000511a9494949a1115111111111b3333b1000600065555566056666666000000606666666666666665
064444600064460006444460bbbbbbbbbb000000000000bb511944444449111511111111b3b33b3b000600655566600056666666000000606666666666666665
06666660006666000666666000000000bb000000000000bb5511944444449155111111111bb33bb1000600666600000056666666000000606666666666666665
00500500005005000050050000000000bbbb00000000bbbb5d555555555555651111111111b33b11000600006000000056666666000000606666666666666665
05500550005505500550055000000000bbbb00000000bbbb5dd6666666667665111111111b3333b1000600006000000055555555555555555555555555555555
aa0000aa77777775007777000000000700000000700000005dd666666666666533333333b333333b6666666666666666111111110000110000d00d0000000000
aaa00aaa766666660077770000000077000000007700000005d6666666676650333333331b3333b166666666666666661cccccc100011100000ddd00000a0000
0aaaaaa0000c00000077770000000777000000007770000005dd6666666666503b3333331b3333b166666666666666661cccccc1011100000000000000a0a000
00aaaa00000c00000077770000007777000000007777000005dd66666666665033b3b333b333333b66666666666666661111111111150000000000a000a00a00
00aaaa000000c0000007700000077777777777777777700005dd666666676650333333331b3333b16666666666666666155555511c1550000000b00a0a000000
0aaaaaa00000200000077000007777777777777777777700005dd666666665003333333bb333333b666666666666666610bbbb011cc15500000b0000aa000e00
aaa00aaa0000220000077000077777777777777777777770005dd666666665003333b3b31bbbbbb1666666666666666610b00b011ccc150000bb0000000000e0
aa0000aa0000020000077000777777777777777777777777000555555555500033333333111441115555555566666666108bbb011cccc1000000bb000000000e
00070000aaaaaaaa000bb00077777777777777777777777756666666666a666666666665111111111111111100000000110111211ccccc11e00000b000000000
0077700099999999000bb00007777777777777777777777056666666666a66666666666511bb11bbb11bbb1100000000111121111ccccc110e000b00000000e0
0776770099999999000bb00000777777777777777777770056666666666a6666666666651bb3bb333bb333b100000000100000011ccccc100000b000cc00000e
7767767099999999000bb000000777777777777777777000566666666666666666666665b3333b3333b3333b00000000100000011ccccc100000000c00c00000
0777677799999999000bb00000007777000000007777000056666666666a666666666665b33333333333333b00000000100006011cccc100e000000c0c000000
0076777099999999000bb00000000777000000007770000056666666666a6666666666651b333333333333b100000000100006011cccc1000e00000c000c0000
0007770099999999000bb00000000077000000007700000056666666666a666666666665b333b333bb33b33b00000000100000011cccc1000000d000ccc00000
00007000aaaaaaaa000bb0000000000700000000700000005666666666666666666666651bbb4bbb4bbbbbb1000000001111111111111100000d0d0000000000
00777777777777001111111160000006000000000000000000000000d555555d1111111111111111333333333333333333333333333333030000000000000000
07777777777777701111111160000006000000000000000000000000544444451117777777777711333333333333333333333333333333430000000000000000
77711111111117771111ee1166666666000500000000000000005000544444451177777777777777333333333333333333333333333333430000000000000000
77111111111111771111111160000006005555555555555555555500544444451777777777777777333333333333333333333333330000430000000000000000
77111111111111771111111160000006000500000000000000005000d555555d1777777777777777333333333333333333333337334242430000000000000000
771111111111117711ee111160000006000500000000000000005000545542451777777777777771333333333333333333377766334222430000000000000000
77111111111111771111111166666666000500000000000000005000542455451117777777777711333333333333333337766677332222430000000000000000
77111111111111771111111160000006000500000000000000005000555555551111111111111111333333333333333337766667332424430000000000000000
77111111111111771111111100000000000500000000000000005000333333333333333333333333333333333336666667766666332224430000000000000000
7711111111111177111111110000000000050000000000000000500033333335454454454333333333333333666666666d777666332242030000000000000000
771111111111117711111111000000000005000000000000000050003b333544544545445443333333333366666dd1111ddd7777334242030000000000000000
7711111111111177111111110000000000050000000000000000500033b35454454454544544b333333336666511111111dddddd332222030000000000000000
771111111111117711111111000000000005000000000000000050003335444454454444544543333333666dd1111cccccccdddd330000030000000000000000
7771111111111777111111110000000000050000000000000000500033545454445454544454543b3336666d1111ccccccccc666330333030000000000000000
077777777777777011111111000000000005000000000000000050003354544454545444545454b333d666511cccccccccccc666333033030000000000000000
0077777777777700111111110000000000050000000000000000500034454544454545444545454333666611ccccccccccccc666330000030000000000000000
771111111111117711111111111111110005000000000000000050003444445454444454544444533d66661ccccccccccccc1666000000000000000000000000
771111111111117711111111111111110005000000000000000050003544544545445445454454433dd6661cccccccccccc16666000000000000000000000000
771111111111117711111111111111110005000000000000000050003445454454454544544545433dd6666cccccccccccc16666000000000000000000000000
771111111111117711111111111111110005000000000000000050003544545445445454454454533ddd6666ccccccccccc16666000000000000000000000000
7711111111111177111111111111111100555555555555555555550034454444544544445445444335dd66666ccccccccccc1666000000000000000000000000
7711111111111177111111111111111100050000000000000000500034545454445454544454545b35ddd6666666ccccccccc111000000000000000000000000
771111111111117711111117711111110000000000000000000000003454544454545444545454433d5dddd6666666cccccccccc000000000000000000000000
771111111111117711111177771111110000000000000000000000003445454445454544454545433d5dddddd66666666ccccccc000000000000000000000000
7777777711111111111111777711111100000000005005000000000034444544544445445444454333d5ddddddd6666666666ccc000000000000000000000000
77777777111111111111111771111111000000000050050000000000334454454544544545445433333d555dddddddd666666666000000000000000000000000
111111111111111111111111111111110000000000500500000000003b45454454454544544545333333dd55ddddddddddd66666000000000000000000000000
1111111111111111111111111111111100000000005005000000000033b454544544545445445333333333dd55dddddddddddddd000000000000000000000000
1111111111111111111111111111111155555555005005000000000033334444544544445445333333333333dd55555ddddddddd000000000000000000000000
1111111111111111111111111111111100500500005005000000000033333454445454544453333b3333333333ddddd55ddddddd000000000000000000000000
111111117777777711111111111111110050050000500500000000003333b3b4545454445333b3b3333333333333333dd5555555000000000000000000000000
1111111177777777111111111111111100500500005005000000000033333333333333333333333333333333333333333ddddddd000000000000000000000000

__gff__
0000000101010000010100000000000000000001010100000000000000000000000000000000000001000000000001010000000000000101010000000000010101010101000000000000000000010000010101010000000101010000000100000101010100000001010100000000000001010101000000010101000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4445454545454545454545454643000018181818181818181818181818181818181818181818181818181818181818180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5455555555555555555555555643000018181818181818181818181818181818181818181818181818181818181818180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5455555555555555555555555643000018181818181818181818181818181818181818181818181818181818181818180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5455555555555555555555555643000018181818181818181818181818181818181818181818181818182a2a2a2a2a2a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5455555555555555555555555643000028282828282828282828282828282828282828280836373808080c2b2b2b2b0f000000002c2c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6465656565657465656565656643000028282828282828282828282828282828282828280836373808080c0d0e0e0e0f002e2f2e3c3c2f2e2f2e2f2e2f2e2f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000007500000000000043000028282828282828282828282828282828282828280836373808081c1d1e1e1e1f003e3f3e3f3e3f3e3f3e3f3e3f3e3f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0040707070707070707070707070410028282828282828282828284d2828282828282828083637380808080808080808002e2f2e2f2e2f2e2f2e2f2e2f2e2f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7073424242424242424242424242727028282828282828282828285d2828282828282828083637380808080808080808003e3f3e3f3e3f3e3f3e3f3e0c3e3f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
424242424242424242424242424242422828282828282828282828282828282828282828083637380808080808080808002e2f2e2f2e2f2e2f2e2f2e0c2e2f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
716342424242424242424242424262712828282828282828282828282828282828282828083637380808080808080808003e3f3e3f3e3f3e3f3e3f3e0c3e3f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
006042424242424242424242424261002828282828282828282828282828282828282828083637380808080808080808002e2f2e2f2e2f2e2f2e2f2e1c2e2f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
006042424242424242424242424261002857585858585858585858585858585858592828083637380808080808080808003e3f3e3f3e3f3e3f3e3f3e1c3e3f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
006042424242424242424242424261002867686868686868686868686868686868692828083637380808080808090808000000000000002e2f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0050717171717171717171717171510028777878787878787878787878787878787928280836373808080808080808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000028282828282828282828282828282828282828280836373808080808080808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000407070707070707070707070707047707070707070707070704100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000044454545454545454545454600604747424747474747474747474247474747474747474747476100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000054000000000000000000005600604747424742424242424242424242474242424742424242476100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000054000000000000000024255600604747424742474747474247474747474742474747424747476100000000000000000000131313131313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000054000000000000000034355600604242424242424742424242424742424242474247424242476100000000000000000000424242424242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000064657465656565656574656600604747474747424742474747424742474742474247474742476100000000000000000342424242424242420300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000007500000000000075000000604742424247424742474242424742424742474247424242474700000000000000000342424242424242420300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4070707070704747707070707070410000474742474242424742474747474747424742424247424742477270707070410000000342420442420542420300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6042424242474747424247424242727070734242474247424742424242474242424747474747424742474242424242610000000342424242424242420300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6042424242424742424242474242424242424242474747424747424747474247424242424247424742424242424242610000000342421442421542420300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6042424242424242424747474242627171634242474242424747424742424247474747474247474742476271717171510000000342424242424242420300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6042424242424242424242424242610000474742474247474247424742474242424742474242424242474700000000000000000000424242424242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6042424242424242424242424242610000604242474247474247424742474747424742474747424747476100000000000000000000131313131313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6042424242424242424242424242610000604747474247424242424742474242424742424242424242426100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5071717171717171717171717171510000604742424247474747474742474747474747474747474747476100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000507171477171717171717171477171717171717171717171715100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100001d05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000900001a85014850038001480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a00001182000e000f8200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

