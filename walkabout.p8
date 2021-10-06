pico-8 cartridge // http://www.pico-8.com
version 33
__lua__

-- walkabout
-- giovan_h

-- terezi dialog tree

-- music item with disc/mp3 icon
-- fake juju (it's just a lolilpop)
-- a modern computer, but it doesn't have magic time powers
-- huggable soft slamancer plush 003705

-- global vars
local o_player
local debug = (stat(6) == 'debug')

-- game state flags
local speedshoes = debug

-- persistent object state
local chest_data = {}
local state_flags = {}

-- defined sprite flags
local flag_walkable = 0b1

local sfx_blip = 000
local sfx_teleport = 001
local sfx_creak = 002
local sfx_itemget = 003
local sfx_curmove = 004
local sfx_wink = 005
local sfx_blip2 = 006
-- local sfx_fishcatch = 007
local sfx_footstep = 008

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

-- print all arguments
function printa(...)
 local args={...}  -- becomes a table of arguments
 s = ""
 foreach(args, function(a) s ..= ','..tostring(a) end)
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
 -- if (center) x = (screen_width - (#s * 4)) / 2
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
local vec_spritesize = vec(8, 8)
local vec_16_16 = vec(16, 16)
local vec_oneone = vec(1, 1)
local vec_twotwo = vec(2, 2)
local vec_zero = vec(0, 0)
local vec_x1 = vec(1, 0)
local vec_y1 = vec(0, 1)
local vec_noneone = vec(-1,-1)
-- vec\d*\(.+?\)
-- function vec:clone() return vec(self:unpack()) end
-- function vec:flip() return vec(self.y, self.x) end
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
-- function bbox:clone() return bbox(self.origin:unpack(), self.size.unpack()) end
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
 self.ttl = chainmap('ttl', kwargs, self)
 self.z = chainmap('z', kwargs, self)
end
function entity:update()
 if self.ttl then
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
 size = vec_spritesize,
 anchor = vec_zero,
 anim = nil,
 frame_len = 1,
 flipx = false,
 flipy = false,
 tcol = 0,
 paltab = nil,
 z_is_y = true,  -- domain: camera perspective
}
function actor:init(pos, spr_, size, kwargs)
 kwargs = kwargs or {}
 self.pos, self.spr, self.size = pos, spr_, size
 self.anchor = chainmap('anchor', kwargs, self)
 self._apos = self.pos:__add(self.anchor)
end
function actor:rel_anchor(x, y)
 self.anchor = vec(self.size.x*x, self.size.y*y)
end
-- function actor:drawdebug()
--  if debug then
--   -- picotool issue #92 :(
--   local spx, spy = self._apos:unpack()
--   line(spx, spy,
--    mrconcatu(self.pos, 4))
--  end
-- end
function actor:update()
 self._apos = self.pos:__add(self.anchor)
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
 -- if self.anim then
 --  local mclock = self.ttl or self.stage.mclock
 --  local findex = (flr(mclock/self.frame_len) % #self.anim) +1
 --  local frame = self.anim[findex]
 --  self._frame, self._findex = frame, findex
 -- end
 if (frame != false and frame != nil) spr(frame, spx, spy, spw, sph, self.flipx, self.flipy)
 -- end
 pal()
-- self:drawdebug()
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
 self.hbox_offset = chainmap('hbox_offset', kwargs, self)
 self.dynamic = chainmap('dynamic', kwargs)
 self.hbox = self:get_hitbox()
-- assert(mob.bsize == nil, 'mob class bsize set')
end
function mob:get_hitbox(pos)
 return bbox(
  (pos or self.pos) + self.hbox_offset,
  self.bsize
 )
end
function mob:update()
 actor.update(self)
 if (self.dynamic) self.hbox = self:get_hitbox()
end
function mob:drawdebug()
 if debug then
  -- print bbox and anchor/origin WITHIN box
  local drawbox = self.hbox:grow(vec_noneone)
  rect(mrconcatu(drawbox, 2))
  actor.drawdebug(self)
 end
end

-- particle
-- pos, vel, acc, ttl, col, z
local particle = entity:extend{}
function particle:init(pos, ...)
 -- assert(self != particle)
 entity.init(self)
 self.pos = pos
 self.vel, self.acc, self.ttl, self.col, self.z = ...
 if (self.z) self.z_is_y = false
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

function vec16(x, y) return vec(x, y)*16 end

-- interactive debugger
-- based on work by mot ?tid=37822
-- dbg=function()
--  poke(0x5f2d, 1)
--  local vars,sy={},0
--  local mx,my,mb,pb,click,mw,exp,x,y,dragx0, dragy0,mbox
--  function butn(exp,x,y)
--   local hover=mx>=x and mx<x+4 and my>=y and my<y+6
--   print(exp and "-" or "+",x,y,hover and 7 or 5)
--   return hover and click
--  end
--  function inspect(v,d)
--   d=d or 0
--   local t=type(v)
--   if t=="table" then
--    if(d>5)return "[table]"
--    local props={}
--    for key,val in pairs(v) do
--     props[key]=inspect(val,d+1)
--    end
--    return {
--     expand=false,
--     props=props
--    }
--   elseif t=="string" then
--    return chr(34)..v..chr(34)
--   elseif t=="boolean" then
--    return v and "true" or "false"
--   elseif t=="nil" or t=="function" or t=="thread" then
--    return "["..t.."]"
--   else
--    return ""..v
--   end
--  end
--  function drawvar(var,name)
--   if type(var)=="string" then
--    print(name..":",x+4,y,6)
--    print(var,x+#(""..name)*4+8,y,7)
--    y+=6
--   else
--    -- expand button
--    if(butn(var.expand,x,y))var.expand=not var.expand
--    print(name,x+4,y,12) y+=6
--    if var.expand then  -- content
--     x+=2
--     for key,val in pairs(var.props) do
--      drawvar(val,key)
--     end
--     x-=2
--    end
--   end
--  end
--  function copyuistate(src,dst)
--   if type(src)=="table" and type(dst)=="table" then
--    dst.expand=src.expand
--    for key,val in pairs(src.props) do
--     copyuistate(val,dst.props[key])
--    end
--   end
--  end
--  function watch(var,name)
--   name=name or "[var]"
--   local p,i=vars[name],inspect(var)
--   if(p)copyuistate(p,i)
--   vars[name]=i
--  end
--  function clear()
--   vars={}
--  end
--  function draw(dx,dy,w,h)
--   dx=dx or 0
--   dy=dy or 48
--   w=w or 128-dx
--   h=h or 128-dy
--   -- collapsed mode
--   if not exp then
--    dx+=w-10
--    w,h=10,5
--   end
--   -- window
--   clip(dx,dy,w,h)
--   color(1)
--   rectfill(box_screen:unpack())
--   x=dx+2 y=dy+2-sy

--   -- read mouse
--   mx,my,mw=stat(32),stat(33),stat(36)
--   mb=band(stat(34),1)~=0
--   click=mb and not pb and mx>=dx and mx<dx+w and my>=dy and my<dy+h
--   pb=mb

--   if mb then
--    mbox = bbox.pack(dragx0, dragy0, mx, my)
--   else
--    dragx0, dragy0 = mx, my
--    mbox = nil
--   end

--   if exp then
--    -- variables
--    for k,v in pairs(vars) do
--     drawvar(v,k)
--    end
--    -- scrolling
--    local sh=y+sy-dy
--    sy=max(min(sy-mw*8,sh-h),0)
--   end
--   -- expand/collapse btn
--   if(butn(exp,dx+w-10,dy))exp=not exp
--   -- draw mouse ptr
--   clip()

--   line(mx,my,mx,my+2,8)
--   color(7)
--  end
--  function show()
--   exp=true
--   while exp do
--    draw()
--    flip()
--   end
--  end
--  function prnt(v,name)
--   watch(v,name)
--   show()
--  end

--  return{
--   watch=watch,
--   clear=clear,
--   expand=function(val)
--    if(val~=nil)exp=val
--    return exp
--   end,
--   draw=draw,
--   mbox=function() return mbox end,
--   show=show,
--   print=prnt
--  }
-- end
-- dbg = dbg()

-- dialog box
-- based on work by rustybailey

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
   if (#self.queue == 1) then
    focus:push'dialog'
    self:trigger(self.queue[1].message, self.queue[1].opts)
   end
  end

 end,
 trigger = function(self, message, opts)
  self.opts = opts
  self.color = opts.color or 0
  self.bgcolor = opts.bgcolor or 6
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
    if (i % 5 == 0) sfx(self.opts.blip or sfx_blip)
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
   if (not self.pause_dialog) then
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
  elseif (self.animation_loop and self.current_message) then
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
   if (#self.queue > 0) then
    focus:push'dialog'
    self:trigger(self.queue[1].message, self.queue[1].opts)
    coresume(self.animation_loop, self)
   end
  end

  if (not self.opts.autoplay) then
   self.blinking_counter += 1
   if self.blinking_counter > 30 then self.blinking_counter = 0 end
  end
 end,
 drawui = function(self)
  if (focus:isnt'dialog') return
  if (self.no_text) return
  local screen_width = 128

  -- display message
  if (self.current_message) then
   rectfill(1,90,126,126,self.bgcolor)
   rect(1,90,126,126,5)
   print(self.current_message, self.x, self.y, self.color)
  end

  -- draw blinking cursor at the bottom right
  if (not self.opts.autoplay) and self.pause_dialog then  --
   if self.blinking_counter > 15 then
    color(13)
    if (self.current_line_in_table == #self.messages_by_line) then
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

local choicer = entity:extend{
 z=4,
 upos=vec(64),
 padding=vec(4, 4),
 char_size=vec(4, 6),
 size=nil,
 selected = 1,
 buttoncool = 0,
 prompt = function(self, choices, exopts)
  exopts = exopts or {}
  self.choices = choices

  self.selected = exopts.selected or 1
  if (exopts.allowcancel) add(self.choices, {'cancel', nop})

  local width = 0
  for v in all(self.choices) do
   width = max(width, #v[1])
  end
  width += 2
  self.size = self.char_size:dotp(width, #self.choices) - vec_oneone*2
  self.size += self.padding*2
  focus:push'choice'
  self.buttoncool = 4
 end,
 drawui = function(self)
  if (self.choices == nil) return
  local rbox = bbox(self.upos, self.size)
  rectfill(mrconcatu(rbox, 0))
  rect(mrconcatu(rbox, 9))
  local ppos = self.upos + self.padding
  color(7)
  local char_size_spaced = self.char_size + vec(0, 1)
  for i,v in ipairs(self.choices) do
   print(v[1],
    mrconcatu(ppos:__add(
      vec(2, i-1):dotp(char_size_spaced)
     ), v[3] or 7))
  end
  color(7)
  if (self.stage.mclock % 16 < 8) color(5)
  print("> ",
   ppos:__add(
    vec(0, self.selected-1):dotp(char_size_spaced)
   ):unpack())
 end,
 update = function(self)
  if (focus:isnt'choice') return
  if (self.buttoncool > 0) self.buttoncool -= 1;    return

  if (btnp(2)) self.selected -= 1; sfx(sfx_curmove)
  if (btnp(3)) self.selected += 1; sfx(sfx_curmove)
  self.selected = clamp(1, self.selected, #self.choices)
  if (btnp(4)) then
   focus:pop'choice'
   self.choices[self.selected][2]()
   self.choices = nil
  end
 end
}

-->8
-- game classes

local _music = music
local music_playing = nil
function music(t)
 if (t != music_playing) _music(t)
 music_playing = t
end

-- function roommenu_init(rooms)
--  local roommenu_room = 1
--  local roommenu_slot = 4
--  local irooms = {}
--  local srooms = {}

--  function set_roommenu(label)
--   menuitem(roommenu_slot, '<- ' .. label .. ' ->', roommenu_cb)
--  end
--  function roommenu_cb(b)
--   local left, right, select = b&1, b&10, b&100
--   if (left>0) roommenu_room = ((roommenu_room-2) % #irooms) + 1
--   if (right>0) roommenu_room = (roommenu_room % #irooms) + 1
--   if (select>0) irooms[roommenu_room]()
--   set_roommenu(srooms[roommenu_room])
--  end

--  local i = 0
--  for k,v in pairs(rooms) do
--   i += 1
--   irooms[i] = v
--   srooms[i] = k
--  end
--  set_roommenu(srooms[roommenu_room])
-- end

local t_sign = mob:extend{
 lines = nil,
 blip = sfx_blip,
 talkedto = 0,
 istalking = false
}
function t_sign:interact(player, lines)
 lines = lines or self.lines
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
 self.talkedto += 1
end

local chest_data = {}
local t_chest = t_sign:extend{
 id = nil,
 obstructs=true,
 bsize = vec8(2, 1),
 anchor = vec8(0,-1),
 getlines = {"you got a[] [???]"},
 emptylines = {}
}
function t_chest:init(id, pos, ispr, isize, itcol)
 t_sign.init(self, pos, 003, vec_16_16)
 self.id = id
 chest_data[self.id] = chest_data[id] or false
 self.ispr = ispr
 self.isize = isize
 self.itcol = itcol
end
function t_chest:interact(player)
 if not chest_data[self.id] then
  chest_data[self.id] = true
  sfx(sfx_itemget)
  self.ihold = 0xff
  self.ttl = 0x0f + self.ihold
  focus:push'anim'

  self.stage:schedule(18, function()
    focus:pop'anim'
    t_sign.interact(self, player, self.getlines)
    dialoger:enqueue('', {callback=function() self.ttl = nil end})
   end)
 else
  t_sign.interact(self, player, self.emptylines)
 end
end
function t_chest:draw()
 local apos = self._apos
 local spx, spy = apos:unpack()
 if (self.ttl and self.ttl < 0x0f) self.ttl = nil
 paltt(self.palt)
 pal(self.paltab)
 if chest_data[self.id] then
  spr(014, spx, spy, 2,1)
  if (self.ttl) then
   local self_isize = self.isize
   local age = self.ihold - (self.ttl-0x0f)
   -- local offset = vec(4*(2-self_isize.x),-min(12, age)-8*self_isize.y+8)
   local offset = vec(4*(2-self_isize.x),max(-16, -age)-self_isize.y)
   local sx, sy = apos:__add(offset):unpack()
   pal()
   pal(self.ipaltab)
   paltt(self.itcol)
   spr(self.ispr, sx, sy, self_isize:unpack())
   pal(self.paltab)
   paltt(self.palt)
  end
  spr(019, spx, spy+8, 2,1)
 else
  spr(003, spx, spy, 2,2)
 end
 pal()
-- mob.drawdebug(self)
end

function npcify(amob)
 amob.bsize = vec8(2, 1)
 amob.anchor = vec8(0,-2)
 amob.hbox_offset = vec8(0, 0)
 amob.hbox = amob:get_hitbox()
 amob.tcol = 15
 amob.obstructs = true
end

local t_npc = t_sign:extend{
 facing = 'd',
 spr0 = 0,
}
function t_npc:init(...)
 t_sign.init(self, ...)
 self.size = vec8(2, 3)
 self.spr0 = self.spr
 npcify(self)
end
function t_npc:interact(player, choices)
 local facetable = {
  d='u',
  u='d',
  l='r',
  r='l'
 }
 self.facing = facetable[player.facing]
 for i, s in ipairs(choices) do
  if type(choices[i]) == 'string' then
   -- choices is a list of lines
   -- enclose choice second part (lines => closure)
   choices = {{'default', closure(t_sign.interact, self, player, choices)}}
   break
  else
   -- choice is a list of choices proper (label, lines, optionals)
   local lines = choices[i][2]
   choices[i][2] = closure(t_sign.interact, self, player, lines)
  end
 end
 if #choices > 1 then
  choicer:prompt(choices)
 else
  choices[1][2]()
 end
end
function t_npc:draw()
 self.flipx = (self.facing == 'l')
 local facemap = {d=0, u=2, l=4, r=4}
 self.spr = self.spr0 + facemap[self.facing]
 if (self.istalking or self.ismoving) and self.stage.mclock % 8 < 4 then
  self.anchor = vec(0, -17)
 else
  self.anchor = vec(0, -16)
 end
 mob.draw(self)
end

local t_button = mob:extend{
 interact=nop
}

function newportal(pos, dest, deststate)
 o_portal = t_button(pos, 005, vec8(3, 1), {
   anchor=vec(-12, 0), hbox_offset=vec(-12, -3)
  })
 -- o_portal.anchor = vec(-12, 0)
 -- o_portal.hbox_offset = vec(-12, 0)
 o_portal.tcol = 15
 o_portal.bsize += vec(0, 6)
 o_portal.hbox = o_portal:get_hitbox()
 function o_portal:draw()
  local apos = self._apos
  pal(self.paltab)
  line(apos.x+6, apos.y+8, apos.x+17, apos.y+8, 1)
  mob.draw(self)
 end
 function o_portal:spark()
  local grav = vec(0, 0.01)
  local p_origin = o_player._apos
  local p_extent = p_origin + o_player.size
  for i = 0, 24 do
   local point_in_plr_spr = vec(
    rndr(p_origin.x, p_extent.x),
    rndr(p_origin.y, p_extent.y)
   )
   local p = cur_room:add(particle(
     point_in_plr_spr + vec(0, 4),
     vec(rndr(-0.5, 0.5), rndr(-2.0, -1.7)),  --vel
     grav,  -- acc
     rndr(10, 15),  -- ttl
     7  -- col
    ))
   function p:update()
    particle.update(self)
    self.z += (15 - self.ttl)*4
   end
  end
 end
 function o_portal:interact(p)
  -- if p.cooldown > 0 then
  --  p.cooldown += 1
  --  return
  -- end
  if p.hbox:overlaps(self.hbox) then
   self:spark()
   p:destroy()
   sfx(sfx_teleport)
   self.stage:schedule(16, function()
     -- new room after animation
     if deststate then
      dest(deststate.pos)
      p.facing = deststate.facing
     else
      dest()  -- let room decide position
     end
     o_player.cooldown = 5
     cur_room:update()  -- align camera
    end)
  end
 end
 return o_portal
end

local t_trigger = mob:extend{}
function t_trigger:init(pos, size, dest, deststate)
 mob.init(self, pos, false, size)
 self.dest, self.deststate = dest, deststate
end
function t_trigger:hittrigger(p)
 if (p.justtriggered) return
 if self.deststate then
  self.dest(self.deststate.pos)
  o_player.facing = self.deststate.facing
 else
  self.dest()  -- let room decide position
 end
 o_player.cooldown = 1
 cur_room:update()  -- align camera
end

local t_player = mob:extend{
 ismoving = false,
 facing = 'd',
 spr0 = 64,
 anchor = vec(-8, -24),
 tcol = 15,
 cooldown = 1,
 justtriggered = true,
 paltab = {[14]=7},
 hbox_offset = vec(-7, -6),
 obstructs = true,
 dynamic=true
}
function t_player:init(pos, kwargs)
 kwargs = kwargs or {}
 mob.init(self, pos, 64, vec(16, 24),
  {bsize=vec(13, 7)})  -- a little smaller
 self.facing = chainmap('facing', kwargs, self)
end
function t_player:_moveif(step, facing)
 local npos = self.pos + step
 local nhbox = self:get_hitbox(npos)
 local unobstructed = nhbox:within(self.stage.box_px)
 local tiles = nhbox:maptiles(self.stage.map_origin)
 for tile in all(tiles) do
  if band(tile.flags, flag_walkable) == 0 then
   unobstructed = false
   break
  end
 end
 for _,obj in pairs(self.stage.objects) do
  if (obj == self) goto continue
  if (nhbox:overlaps(obj.hbox) and obj.obstructs) unobstructed = false; break
  ::continue::
 end
 if (facing) self.facing = facing
 if unobstructed then
  self.pos = npos
  self.moved = true
 end
end
function t_player:move()
 -- player movement
 local vright = vec_x1
 local vdown = vec_y1
 local speed = 2

 if (speedshoes and btn(5)) speed = 3

 self.moved = false

 -- lrudox
 for x=1,speed do
  if (btn(0)) then
   self:_moveif(vec(-1, 0), 'l')
  elseif (btn(1)) then
   self:_moveif(vec_x1, 'r')
  end
  if (btn(2)) then
   self:_moveif(vec(0, -1), 'u')
  elseif (btn(3)) then
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
   -- if (not self.justtriggered) then
   --  -- self just got destroyed so
   --  -- this doesn't do anything:
   --  self.justtriggered = true
   -- -- what actually matters is
   -- -- the init setting here
   -- end
   break
  end
 end
 self.justtriggered = stillintrigger
 -- try interact
 local facemap = {d=vec(0, 6),u=vec(0,-12),l=vec(-12,-6),r=vec(12,-6)}
 if btnp(4) then
  local ibox = bbox(self.hbox.origin, vec(12, 12)):shift(facemap[self.facing])

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

 if (self.ismoving and (self.stage.mclock % 10 == 0)) sfx(sfx_footstep)

 self.stage.camfocus = self.pos
 mob.update(self)
 self.hbox = self:get_hitbox()
end

function t_player:draw()
 self.flipx = (self.facing == 'l')
 local facemap = {d=0, u=2, l=4, r=4}
 self.spr = self.spr0 + facemap[self.facing]
 if self.ismoving and self.stage.mclock % 8 < 4 then
  self.anchor = vec(-8, -25)
 else
  self.anchor = vec(-8, -24)
 end
 mob.draw(self)
-- if (debug and self.ibox) rect(mrconcatu(self.ibox, 10))
end

local room = stage:extend{
 camfocus = nil
}
function room:init(name, mx, my, mw, mh)
 self.map_origin = vec16(mx, my)
 self.box_map = bbox.fromxywh(0, 0, mw, mh)
 self.box_cells = self.box_map*16
 self.box_px = self.box_cells*8

 self.camfocus = self.box_px:center()
 stage.init(room)
 self:add(choicer)
 self:add(dialoger)
 local nameplate = entity({z=0})
 function nameplate:drawui()
  prints(name, 0, 122)
 end
 self:add(nameplate)
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

 -- if debug and btn(5) and o_player then
 --  for object in all(self.objects) do
 --   if object.pos then
 --    line(mrconcatu(o_player.pos, object.pos:unpack()))
 --   end
 --  end
 -- end

 self.cam = cam
 stage.draw(self)

-- camera()
-- if debug and o_player then

--  local ui_offset = cam - self.box_px.origin
--  poke(0x5f2d, 1)
--  local mous = vec(stat(32), stat(33))
--  pset(mrconcatu(mous, 10))
--  mous += ui_offset

--  prints('plr  ' .. tostr(o_player.pos), 0, 0)
--  prints('--8' .. tostr(o_player.pos:__div(8):floor()), 64, 0)
--  prints('-16' .. tostr(o_player.pos:__div(16):floor()), 68, 8)
--  line(67, 2, 67, 10)
--  prints('room ' .. tostr(self.map_origin/16), 0, 8)
--  prints('mous ' .. tostr(mous), 0, 16)
--  prints('-- 8' .. tostr(mous:__div(8):floor()), 64, 16)
--  prints('-16' .. tostr(mous:__div(16):floor()), 68, 24)
--  line(67, 18, 67, 26)
-- end
end

function drawgreat(self)
 paltt(15)
 spr(198, mrconcatu(self.pos, 2, 2))
 if (self.label) print(self.label, mrconcatu(self.pos:__add(-1,-6), 7))
end

-->8
--rooms

local paltab_prospitchest = {[5]=7,[1]=6}
local paltab_dersite = {[14]=0, [7]=0, [0]=7}

cur_room = nil

function room_complab()
 music(00)
 local center = vec16(8, 8.25)
 cur_room = room("complab", 0, 0, 2, 2)
 o_player = cur_room:add(t_player(center))

 local o_computer1 = cur_room:add(t_sign(vec16(1.5, 0.5), 010, vec_16_16))
 o_computer1.lines = {
  "two white lines of text are blown up to fill the entire screen.\rit's so huge you can read it from across the room.\ri wonder what it says."
 }

 local o_computer2 = cur_room:add(t_sign(vec8(11, 1), 112, vec8(2, 1), {bsize=vec_16_16}))
 o_computer2.lines = {
  "looks like someone was planning a fundraising campaign for a video game.\rtoo bad they're just a troll."
 }

 local o_computer3 = cur_room:add(t_sign(vec8(19, 1), 116, vec_spritesize, {
    anchor=vec(4, 1), bsize=vec_16_16}))
 o_computer3.lines = {"it's an off-ice computer.\ryou can tell because someone is running troll powerpoint. it ticked past the last slide though."}
 o_computer3.tcol = 15

 local o_computer4 = cur_room:add(t_sign(vec8(27, 1), 010, vec8(2, 1), {
    bsize=vec_16_16}))
 o_computer4.paltab = {[6]=3}
 o_computer4.lines = {"wowie! looks like somebody's been flirting. in \f3green.\ractually, scrolling up, you see that only a few lines ago this conversation was antagonistic. at least nominally. \rand then... ho boy, some typically convoluted nonlinear nonsense, and then it looks like some pretty painful shutdowns?\rrough. but it looks like greeno here has salvaged things, somehow."
 }
 -- o_computer4:addline(
 --  "due to technical limitations, the keyboard has also been flirting. in \f3green.")

 local o_teapot = cur_room:add(t_sign(vec16(15, 8), 050, vec8(2, 1)))
 o_teapot.tcol = 012
 o_teapot.lines = {"it's a cat-themed teapot. it seems out of place in this distinctly un-cat-themed room.\rthe sugar is arranged so as to be copyrightable intellectual property."}

 local o_chest = cur_room:add(t_chest('clabdollar',vec16(11.5, 3), 060, vec_oneone))
 o_chest.getlines = {
  "you got a fistfull of boondollars!\rit's important that sburb give these out to players for accomplishing game tasks, or else they wouldn't be motivated to play the game.\ralthough \"playing the game\" here pretty much means staying alive and ensuring you're not responsible for the annihilation of your species. you've gotta give people little wins."}

 -- todo polish dialogue
 local o_chest = cur_room:add(t_chest('clabfaygo',vec8(23, 20), 043, vec(1, 2)))
 o_chest.getlines = {
  "you got a faygo! a fun drink for fun people.\rit tastes like red pop."
 }

 local o_cards = cur_room:add(t_sign(vec(172, 194), 034, vec8(2, 1)))
 o_cards.lines = {"these cards really get lost in the floor. someone might slip and get hurt.\rthen again that's probably how the game would have ended anyway.\rsomeone has tried to play solitaire with them. you feel sad."}

 local o_plush = cur_room:add(t_sign(vec(142, 203), 032, vec_16_16))
 o_plush.lines = {
  "it's a stray fiduspawn host plush.\ronce hatched, fidusuckers \f2will\f0 forcibly impregnate the nearest viable receptacle, so it's really important to have a few of these around."}

 local o_trash = cur_room:add(t_sign(vec8(27, 28), 237, vec8(1, 2), {
    bsize=vec_spritesize,
    anchor=vec8(0,-1)
   }))
 o_trash.tcol = 14
 o_trash.obstructs = true
 o_trash.lines = {"there's suggestion in the trash. it just says the word \"alternia\".\ryou're glad that didn't get chosen. that would have been silly."}

 -- todo write dialogue
 local o_scalemate = cur_room:add(t_sign(vec(195, 78), 110, vec8(2, 1)))
 o_scalemate.lines = {
  "someone has tied a noose around this plush dragon and left it lying on the floor\rlooking around, you don't see anything nearby you could hang a rope from."
 }

 local o_corner = cur_room:add(t_sign(vec16(0, 11), false, vec16(5, 5)))
 o_corner.lines = {"this corner of the room feels strangely empty and unoccupied.\ryes, both."}

 local o_karkat = cur_room:add(t_npc(vec(64, 64), 070))
 o_karkat.color = 5
 function o_karkat:interact(player)
  local choices = {
   {"epilogues", {
     "the fuck are you talking about? we have bigger things to deal with right now than ill-advised  movie sequels or whatever it is you're distracted with."
    }},
   {"dave", {
     "i have had literally one interaction with the guy and it ended up being all about vriska.\rbecause of course literally fucking everything has to be about vriska if you're unfortunate enough to get stuck in the same universe as her. or apparently even if you're not.\ri'd joke about offing yourself being the only way to escape her absurd machivellian horseshit but at this point she's probably fucked up death too. also, people are fucking dead and i'm not going to chose this particular moment to star tlisting off all the cool perks of getting murdered."
    }}
  }
  if chest_data['clabdollar'] then
   add(choices, {"boondollars", {
      "oh fuck no. get those out of my face\rterezi's been filling the place with those. they're a worthless eyesore.\rwhy do you think i put them in all the chests?"}, 10})
  end
  t_npc.interact(self, player, choices)
 end

 cur_room:add(newportal(center, room_t))

end

function room_t(v)
 music(02)
 cur_room = room("teerezi", 2, 0, 1, 1)
 o_player = cur_room:add(t_player(v or vec8(3, 12)))

 o_chest = cur_room:add(
  t_chest('scalemate',vec8(5, 5), 142, vec_twotwo, 15)
 )
 o_chest.getlines = {"you got another scalemate!\rthere was also a rope in the chest. you decide to leave it and take the scalemate far away." }
 o_chest.emptylines = {"there was also a rope in the chest. you decide to leave it and take the scalemate far away."}

 o_scalehang = cur_room:add(actor(vec16(5, 3.5), 142, vec_16_16, {
    anchor = vec8(0,-5)
   }))
 o_scalehang.tcol = 15
 o_scalehang.paltab = {[3]=2, [11]=8,[12]=11}
 function o_scalehang:draw()
  local spx, spy = self.pos:__add(9,-32):unpack()
  line(spx, spy, spx, spy-32, 7)
  mob.draw(self)
 end

 -- todo write dialogue
 o_terezi = cur_room:add(t_npc(vec8(8, 7), 128))
 o_terezi.color = 3
 function o_terezi:interact(player)
  local choices = {
   {"up to", {
     "oh, 1'm not up to 4nyth1ng\rjust h4ng1ng 4round >:]"
    }},
  }
  if chest_data['scalemate'] then
   add(choices, {"scalemate", {
      "you c4n h4ng on3 1f you w4nt 1 dont m1nd\rjust m4k3 sur3 you go through du3 proc3ss f1rst\ror 4ny proc3ss r3411y\rjust1c3 1s mostly 4bout m4k1ng sur3 to s4y you'r3 do1ng just1c3 4 lot wh1l3 you do wh4t3v3r"
     }, 10})
  end
  t_npc.interact(self, player, choices)
 end

 cur_room:add(newportal(vec(24, 90), room_complab))
 cur_room:add(newportal(vec(104, 90), room_lab))

end

function room_lab(v)
 music(02)
 cur_room = room("scilab", 6, 0, 1, 2)
 o_player = cur_room:add(t_player(v or vec(64, 90), {facing='r'}))

 for y = 0, 3 do
  for x = 0, 1 do
   if (y == 2 and x == 0) goto continue
   o_cap = cur_room:add(actor(vec16((x*3+2), (y*3+4)), 076, vec8(2, 3), {
      anchor=vec8(0,-2)
     }))
   o_cap.tcol = 10
   ::continue::
  end
 end

 o_switch_dial = cur_room:add(t_sign(vec8(7.5, 2.5), 125, vec_spritesize))
 o_switch_dial.flipx = state_flags['frog_flipped']
 function o_switch_dial:interact(player)
  if (player.cooldown > 0) return false
  function promptswitch()
   choicer:prompt{
    {"flip it", function()
      state_flags['frog_flipped'] = not state_flags['frog_flipped']
      self.flipx = state_flags.frog_flipped
      sfx(sfx_creak)
      player.cooldown += 2
     end},
    {"do not", function()
      dialoger:enqueue"it's set correctly, you think."
     end}
   }
  end
  dialoger:enqueue("there is a switch here with a frog. flip it?", {callback=promptswitch}
  )
 end
 o_switch_frog = cur_room:add(mob(vec8(7, 1.5), 126, vec8(2, 1)))

 o_frog = t_sign(vec8(12, 4), 174, vec_16_16, {
   bsize=vec8(2, 1),
   anchor=vec8(0,-1)
  })
 o_frog.flipx = true
 o_frog.obstructs = true
 function o_frog:interact(player)
  o_frog.lines = {
   "hi. i'm the right frog.\ri'm more secret than the other frog.",
  }
  if chest_data['sciencetank'] then
   local choices = {
    {"frog", closure(t_sign.interact, self, player)},
    {"science tank", closure(t_sign.interact, self, player, {
       "we use those to make the frogs."
      }), 10}
   }
   choicer:prompt(choices)
  else
   t_sign.interact(self, player)
  end

 end
 if (state_flags['frog_flipped']) cur_room:add(o_frog)

 o_chest = cur_room:add(t_chest('sciencetank',vec16(2, 10), 076, vec(2, 3), 10))
 o_chest.getlines = {
  "it's one of those science tube things.  a tank, for cloning, or monsters, or ghosts. or whatver science comes up, really.\rno matter what your genre, if you've got something significant to do and really want to make it official, you've gotta have a room full of these bad boys around."}
 o_chest.emptylines = {"someone has carved a hole into the floor to give this chest space for an extra-tall item."}

 cur_room:add(newportal(vec(64, 84), room_t, {
    facing='d',
    pos=vec(104, 91)
   }))

 cur_room:add(t_trigger(vec(124, 192), vec8(.5, 4), room_hallway))

end

function room_hallway(v)
 music(-1)
 cur_room = room("hallway", 2, 1, 1, 1)
 o_player = cur_room:add(t_player(v or vec(14, 72)))

 local greydoor = cur_room:add(t_sign(vec8(7, 4), 030, vec8(2, 3)))
 function greydoor:interact(player)
  if self.talkedto < 1 then
   self.lines = {
    "it's locked. you can't open it. or, it's not locked, and you could open the door. or maybe something else. is it even a door?\ryou don't open it."
   }
  else
   self.lines = {"the door reeks of indeterminism. "}
  end
  t_sign.interact(self, player)
 end

 cur_room:add(t_trigger(vec(0, 56), vec8(.5, 4), room_lab, {
    facing='l',
    pos=vec(115, 208)
   }))

 cur_room:add(t_trigger(vec8(15.5, 7), vec8(.5, 4), room_stair))

end

function room_stair(v)

 music(04)
 cur_room = room("stairway", 7, 0, 1, 2)
 o_player = cur_room:add(t_player(v or vec(18, 52)))
 o_player.facing = 'r'

 local o_trigback = cur_room:add(t_trigger(vec(0, 32), vec(4, 32), room_hallway, {
    facing='l',
    pos=vec8(13, 9)
   }))
 function o_trigback:hittrigger(p)
  state_flags['leftstair'] = true
  t_trigger.hittrigger(self, p)
 end

 local o_plush = cur_room:add(t_sign(vec(80, 141), 032, vec_16_16))
 o_plush.lines = {"he must be lost.\rfortunately his owner can safely walk down here and retrieve him."}

 local o_chest = cur_room:add(t_chest('stair1',vec16(5, 2), 003, vec_twotwo))
 o_chest.getlines = {"you got a chest! the perfect container to store things in.","since only protagonists can open them, it's very secure."}
 o_chest.emptylines = {"it was only big enough to hold one chest."}

 local o_chest2 = cur_room:add(t_chest('stair2',vec16(2, 2), 206, vec_twotwo, 12))
 o_chest2.getlines = {
  "you got minihoof!\rsmall enough to sit on your desk, horse enough to be entirely inconvenient to care for.\rtotally worth it though."
 }

 local o_stair_rail = cur_room:add(mob(vec(65, 80), nil, vec(15, 1)))
 o_stair_rail.obstructs = true

 local o_stair = cur_room:add(mob(vec8(6.5, 10), nil, vec8(3, 5)))
 function o_stair:hittrigger(player)
  local speed = 2
  for x=1,speed do
   if (btn(0)) then
    player:_moveif(vec_y1)
   elseif (btn(1)) then
    player:_moveif(vec(0,-1))
   end
  end
 end

 local o_gio = cur_room:add(t_npc(vec(33, 206), 064))
 o_gio.paltab = {[7]=8, [0]=8, [14]=0, [13]=0}
 -- o_gio.addline(function() o_gio.prefix = '' o_gio.ismoving = false end)
 function o_gio:interact(player)
  local choices = {
   {"man", {
     "oh. there is a man here.",
     function()
      if speedshoes then
       dialoger:enqueue"you do not give him anything."
      else
       speedshoes = true
       sfx(000)
       dialoger:enqueue("he gave you an ❎ button. in addition to the rest.", {callback=function()
          focus:push'anim'
          self.facing = 'd'
          cur_room:schedule(10, function()
            sfx(sfx_wink)
            local face = cur_room:add(sprparticle(
              179, vec_oneone,
              self._apos:__add(4, 7),  -- get this while standing still
              vec(0.03, 0), vec_zero, 50, nil, self.z+1
             ))
            face.tcol = 14
           end)
          cur_room:schedule(60, function() focus:pop'anim' end)
         end})  -- end wink anim
      end  -- end nospeedshoes else
     end  -- end man func
    }}
  }
  if chest_data['limoncello'] then
   add(choices, {"faygocello", {
      "...\ryou are right to hold me to account for my sins."
     }, 10})
  end
  t_npc.interact(self, player, choices)

 end

 function o_gio:update()
  self.ismoving = focus:is'dialog'
  t_npc.update(self)
 end

 local o_vue = cur_room:add(t_sign(vec8(10, 24), 122, vec8(2, 1), {
    anchor=vec8(0, -1)
   }))
 o_vue.tcol = 14
 o_vue.lines = {
  "it looks like he has been trying to copy media from the past into the present.\ra fool's errand."}

 local o_p8cart = cur_room:add(t_sign(vec8(8, 23), 183, vec_spritesize))
 o_p8cart.lines = {"it's a pico-8 game cartridge. these things have a maximum capacity of about 90% the size of just the first animated panel of mspa, so programming one can be a royal headache.\rbut sometimes you've got to take off your archivist's stovetop hat and toil for a minute\runder the pulled-back baseball cap of the secrets' sommelier.\ryou think you'll stick with godot instead."}

 local o_great = cur_room:add(t_button(vec16(1, 6), false, vec_16_16))
 o_great.interact = function()
  room_turbine(vec(24, 122))
  o_player.facing = 'u'
 end
 if (state_flags['leftstair'] and not state_flags['knowsgreat']) o_great.label = "GREAT"
 o_great.draw = drawgreat

 local o_horsehole = cur_room:add(t_sign(vec16(6, 7), false, vec8(1, 2)))
 o_horsehole.lines = {"through a small hole in the wall you see a passage that leads deep into the [???]. it's too small for you to enter.\ryou hear a distant winney."}

end

function room_turbine(v)
 state_flags['knowsgreat'] = true
 music(00)
 cur_room = room("ventway", 3, 0, 2,1)
 o_player = cur_room:add(t_player(v or vec(24, 112)))

 o_player.bsize = vec(14, 10)  -- feel cramped
 o_player.hbox_offset = vec(-7, -10)

 local o_great = cur_room:add(t_button(vec16(12, 1), 198, vec_16_16))
 o_great.tcol = 15

 if (not state_flags['frog_flipped']) then
  local o_chest = cur_room:add(t_chest('frog',vec8(20, 11), 174, vec_twotwo))
  o_chest.getlines = {"you found a contraband amphibian!\rhe says something about being hidden better than the other frog.\ryou pet the frog."
  }
  o_chest.emptylines = {"you have left this chest so much the poorer."}
 end

 local o_hole = cur_room:add(mob(vec16(10, 3), 008, vec16(1, 1)))
 o_hole.tcol = 15
 function o_hole:update()
  if state_flags['holefilled'] then
   local tiles = self.hbox:maptiles(self.stage.map_origin)
   for tile in all(tiles) do
    mset(mrconcatu(tile.pos, 002))
   end
  end
  mob.update(self)
 end
 function o_hole:interact(player)
  local hastileitem = chest_data['tilechest']
  if hastileitem and not state_flags['holefilled'] then
   function promptbridge()
    choicer:prompt{
     {"yes", function()
       state_flags['holefilled'] = true
       sfx(sfx_itemget)
      end},
     {"no", function()
       dialoger:enqueue"you never know when you might need it."
      end}
    }
   end
   dialoger:enqueue("make a bridge with the tile?", {callback=promptbridge}
   )
  else
   if state_flags['holefilled'] then
    dialoger:enqueue"there wasn't a tile here. there is now."
   else
    dialoger:enqueue"there is a hole here. it's here now."
   end
  end
 end
 o_hole.size = vec16(1)
 function o_hole:draw()
  if (state_flags['holefilled']) mob.draw(self)
 -- else mob.drawdebug(self) end
 end

 for fg in all{
  "4, 6, 10",
  "14, 8, 6",
  "22, 8, 4",
  "26, 6, 6",
  "26, 12, 4",
  "20, 12, 2"
 } do
  local x, y, len = unpack(split(fg))
  local o_fg_rail = cur_room:add(mob(
    vec8(x, y+.1), 117, vec8(len, 1),
    {anchor=vec8(0,-1.1)}))
  function o_fg_rail:draw()
   local width = self.hbox.w
   for x = 1, width/8 do
    paltt(0)
    spr(self.spr, self._apos:__add(vec8(x-1,0)):unpack())
   end
  -- mob.drawdebug(self)
  end

 end

 local o_andrew = cur_room:add(t_sign(vec8(26, 11), 140, vec8(2, 3)))
 npcify(o_andrew)
 o_andrew.tcol = 14

 local o_cantreach = cur_room:add(t_sign(vec8(22, 11), false, vec_spritesize))
 o_cantreach.lines = {
  "try as you might, you can't cross the gap.\rprobably would have been a disappointment, honestly."
 }

 cur_room:add(t_trigger(vec8(2, 15.5), vec8(2, .5), room_stair, {
    facing='d',
    pos=vec(24, 121)
   }))
 cur_room:add(t_trigger(vec8(14, 0), vec8(2, .5), room_ocean))
 cur_room:add(t_trigger(vec8(31.5,4), vec8(.5, 2), room_roof))
 cur_room:update()
end

function room_roof(v)

 music(01)
 cur_room = room("john's roof", 5, 0, 1, 1)
 o_player = cur_room:add(t_player(v or vec(16, 98)))
 o_player.facing = 'r'

 local o_stair_rail = cur_room:add(mob(vec(77, 48), nil, vec(3, 64)))
 o_stair_rail.obstructs = true

 local o_chest = cur_room:add(t_chest('pogo',vec8(7, 6), 078, vec_twotwo))
 o_chest.paltab = paltab_prospitchest
 o_chest.ipaltab = {[11]=12, [0]=6}
 o_chest.itcol = 3
 o_chest.getlines = {
  "you got a rare off-color slimer!\ran artifact of a simpler time."
 }

 local o_chest = cur_room:add(t_chest('limoncello',vec8(13, 4), 176, vec_oneone))
 o_chest.getlines = {
  "it's a glass of... what is that, faygo cut with limoncello?\ra drink for the direst of circumstances."
 }

 local o_pogo = cur_room:add(t_sign(vec8(12, 9), 078, vec_16_16, {bsize=vec_spritesize}))
 o_pogo.obstructs = true
 o_pogo.tcol = 3
 o_pogo.lines = {
  "thanks to the miracle of digital technology, the pogo ride has been effortlessly preserved to the exact specifications of the designer, a feat unheard of in any previous era.\rbut it doesn't work anymore.",
  function()
   o_pogo.update = mob.update
   o_pogo.lines = {"it seems someone has replaced the ride with a still photo."}
  end
 }

 function o_pogo:update()
  if self.stage.mclock % 32 < 16 then
   self.anchor = vec(-4, -8)
  else
   self.anchor = vec(-4, -7)
  end
  mob.update(self)
 end

 o_pogo:update()

 local o_lamppost = cur_room:add(t_sign(vec8(6, 9), 078, vec_spritesize))
 o_lamppost.obstructs = true
 o_lamppost.tcol = 14
 o_lamppost.lines = {
  function() sfx(007) end,
  "it's the \falamppost\f7.\rquit the game?",
  function()
   choicer:prompt{
    {"yes", function()
      dialoger:enqueue"i mean, nobody's stopping you." end},
    {"no", function()
      dialoger:enqueue"ok cool" end},
   }
  end,
  closure(poke, 0x5f80, 1)
 }

 function o_lamppost:draw()
  paltt(self.tcol)
  spr(023, self.pos:unpack())
  spr(022, self.pos:__sub(vec8(0, 4)):unpack())
  local line_
  line_ = bbox(self.pos + vec(3, -25), vec(0, 25))
  line(mrconcatu(line_, 0))
  line(mrconcatu(line_:shift(vec_x1), 5))

  if (self.stage.mclock % 16 < 4 and rndi(6) == 0) self.flicker = true
  if self.flicker then
   pset(self.pos.x+3, self.pos.y-28, 9)
   if (rndi(2) != 0) self.flicker = false
  end
 -- mob.drawdebug(self)
 end

 cur_room:add(t_trigger(vec8(1, 11), vec8(.8, 2), room_turbine, {
    facing='l',
    pos=vec8(30, 6)
   }))
end

function room_ocean(v)

 music(03)
 cur_room = room("ocean roof", 5, 1, 1, 1)
 o_player = cur_room:add(t_player(v or vec(104, 40)))

 cur_room.paltab = {[3]=5, [11]=4}

 local o_great = cur_room:add(t_button(vec16(6, 1), 198, vec_16_16))
 o_great.tcol = 15

 o_great.interact = closure(room_turbine, vec(121, 20))
 o_great.draw = drawgreat

 local o_chest = cur_room:add(t_chest('oceanr',vec8(11, 9), 181, vec(2, 1)))
 o_chest.getlines = {"you got a boonbuck! through the magic of game mechanics, you can exchange this at any time for one million boondollars.\rgiven that boondollars are physical coins, making the exchange would immediately bury you alive. most people choose not do to this.\rsome enterprising sburb players have even weaponized this mechanic."}

 local o_kanaya = cur_room:add(t_npc(vec8(8, 9), 134))
 o_kanaya.color = 3
 o_kanaya.blip = sfx_blip2
 function o_kanaya:interact(player)
  local choices = {
   {"roof", {
     "oH i'M jUST eNJOYING tHE vIEW\rtHE oTHERS uSUALLY dO nOT cOME oUT hERE wITH aLL tHE sUNLIGHT\ri kEEP tELLING tHEM iT'S a mADCAP sECRET wALKAROUND uNIVERSE aND tHE lIGHT iS tHE nORMAL nONFATAL kIND bUT hABIT cAN bE a pOWERFUL tHING i sUPPOSE"
    }},
  }
  if chest_data['clabfaygo'] then
   add(choices, {"redpop", {
      "i\reR\ruH\rwELL\ri tHINK i wILL hAVE tO pASS tHIS tIME tHANK yOU\rpERHAPS gAMZEE mIGHT bE mORE INCLINED\roR eLSE sOMEONE nEARER a dRAIN"
     }, 10})
  end
  if chest_data['oceanr'] then
   add(choices, {"loot", {
      "oH yES fEEL fREE tO tAKE tHAT i wASNT uSING iT fOR aNYTHING\rtO eACH aCCORDING tO tHEIR gREED aND wHATNOT\rsEE tHE jOKE iS tHAT i aM jUDGING yOU"
     }, 10})
  end
  t_npc.interact(self, player, choices)
 end

 local o_stair = cur_room:add(t_button(vec16(1, 4), false, vec_16_16))
 o_stair.interact = function()
  room_chess()
 end
 o_stair.obstructs = true

 function cur_room:update()
  if (self.mclock % 120 == 0) then
   local fish = sprparticle(180, vec_oneone,
    vec8(rndr(9, 11), 2), vec(-3, -4), vec(0, 0.4), 18, nil, 16)
   fish.tcol = 2
   function fish:update()
    self.hbox = bbox(self.pos, vec_spritesize)
    particle.update(self)
   end
   function fish:interact(player)
    sfx(007)
    dialoger:enqueue"you caught a fish!"
    dialoger:enqueue("but nothing happened.", {callback=function()
       player.facing = 'd'
       t_npc.interact(o_kanaya, player, {"\f3wHAT aRE yOU dOING oVER tHERE\roR dO i nOT wANT tO kNOW\roN cLOSER iNSPECTION iM tHINKING iT iS tHE lATTER"})
      end})
   end
   self:add(fish)
  end
  room.update(self)
 end

 local o_decorator = cur_room:add(entity())
 function o_decorator:draw()
  rect(8, 24, 119, 87,4)
 end

 sfx(sfx_creak)

end

function prettify_map()
 local tiletable = {
  [036]= 052,
  [002]= 018
 }
 for x = 0,128 do
  for y=0,64 do
   local state=mget(x, y)
   if (tiletable[state]) mset(x,y,tiletable[state])
  end
 end
end

function room_chess(v)

 music(05)
 cur_room = room("castle board", 3, 1, 2, 1)
 o_player = cur_room:add(t_player(v or vec8(30, 10)))

 function drawpillar(self)
  local spx, spy = self._apos:unpack()
  paltt(0)
  spr(self.spr, spx, spy)
  for oy = -4,-1 do
   spr(self.spr-1, spx, spy+(8*oy))
  end
  spr(self.spr-2, spx, spy+(8*-5))
 -- mob.drawdebug(self)

 end

 for x in all{3, 11, 20, 28} do
  local o_pillar = cur_room:add(mob(vec8(x,14), 120, vec_spritesize))
  o_pillar.draw = drawpillar
  o_pillar.obstructs = true

 end

 -- Todo polish dialog
 local o_stalemate_w = cur_room:add(t_sign(vec8(7, 12), 066, vec8(2, 3)))
 npcify(o_stalemate_w)
 o_stalemate_w.lines = {
  "it's a north-going prospitian.\rit looks like they're stuck.\rthey look enraged."}

 local o_stalemate_b = cur_room:add(t_sign(vec8(7, 11), 064, vec8(2, 3)))
 npcify(o_stalemate_b)
 o_stalemate_b.paltab=paltab_dersite
 o_stalemate_b.lines = {
  "it's a south-going dersite.\rit looks like they're stuck.\rseems they've accepted it."}

 local o_promoguy = cur_room:add(t_npc(vec8(12.5, 7), 064))
 o_promoguy.step = vec_x1
 o_promoguy.dynamic = true
 o_promoguy.facing = 'r'
 o_promoguy.paltab=paltab_dersite
 function o_promoguy:update()
  self.ismoving = not self.istalking
  if not self.istalking then
   if (self.pos.x > 140) self.step = vec(-1, 0); self.facing = 'l'
   if (self.pos.x < 100) self.step = vec_x1; self.facing = 'r'
   t_player._moveif(self, self.step, self.facing)
  end
  mob.update(self)
 end
 function o_promoguy:interact(p)
  local wasfacing = self.facing
  t_npc.interact(self, p, {
    "i have to keep at it if i want to get that promotion.\r...what do you mean i'm going the wrong way?"
   })
  dialoger:enqueue('',{callback=function() self.facing = wasfacing end})
 end

 local o_palt_portal = cur_room:add(newportal(vec8(2, 9), room_complab))
 o_palt_portal.paltab = {[1]=7,[2]=10}

 local o_chest_tile = cur_room:add(t_chest('tilechest',vec8(5, 5), 008, vec_twotwo))
 o_chest_tile.paltab = paltab_prospitchest
 o_chest_tile.getlines = {
  "you found a floor tile!\ryou are filled with relief at some semblance of linear progression."
 }

 local o_chest_nendroid = cur_room:add(t_chest('nendroid',vec8(8, 5), 238, vec_twotwo))
 o_chest_nendroid.paltab = paltab_prospitchest
 o_chest_nendroid.itcol = 15
 o_chest_nendroid.getlines = {
  "you found a homestuck nendroid!\rah. truly, you're living your best timeline."
 }

 local o_chest_chaos = cur_room:add(t_chest('chaose',vec8(24, 13), 124, vec_oneone))
 o_chest_chaos.paltab = paltab_prospitchest
 o_chest_chaos.getlines = {
  "you found a chaos emerald! can you find them all?\r(you have already found them all)"
 }
 o_chest_chaos.emptylines = {
  "weird, there's room in here for like six or eight."
 }

 local o_jade = cur_room:add(t_npc(vec8(23, 6), 192))
 o_jade.color = 11
 o_jade.bgcolor = 13

 -- todo more dialogue
 function o_jade:interact(player)
  local choices = {
   {"walkaround", {
     "yeah, it feels good to wake up and stretch my legs!!\rsometimes it feels like i'm gonna spend my whole life dreaming. well awake but... oh, you know!\rbut that's all going to change soon! i think....."
    }},
   {"dogs", {
     "ok yes that's one thing about prospit that suuucks :(\rthe people here are all very nice but there's no dogs or animals anywhere\rsure bec can be a bossypants sometimes but i still think these guys are missing out!"
    }},
  }
  -- todo frogs
  -- frogs: cute? temple? visions?
  if chest_data['tilechest'] then
   add(choices, {"frogs", {"TODO JADE FROG"}, 10})
  end
  t_npc.interact(self, player, choices)
 end

 cur_room:add(t_trigger(vec8(31.5, 8), vec8(.5, 3), room_ocean, {
    facing='r',
    pos=vec(39, 76)
   }))
 cur_room:update()

end

local intro_keyspr = actor:extend{}
function intro_keyspr:init(btnid, ...)
 actor.init(self, ...)
 self.btnid = btnid
 self.size = vec_16_16
end
function intro_keyspr:draw()
 local x0, y0, x1, y1 = bbox(self._apos, self.size):unpack()
 local c1, c2, c3 = 13, 7, 5
 if (btn(self.btnid)) c2, c3 = 5, 7
 rectfill(x0, y0, x1, y1, c1)
 line(x0, y0, x0, y1-1, c2)
 line(x0, y0, x1-1, y0, c2)
 line(x0+1, y1, x1, y1, c3)
 line(x1, y0+1, x1, y1, c3)
-- actor.draw(self)
end

local introscreen = stage:extend{
 greyscale={0, 0, 1, 5, 13, 6, 7},
 lines = {"assume the", "position"},
 held = 0
}
function introscreen:init(fadelen, onopen)
 stage.init(self)
 self.onopen = onopen
 self.fadelen = fadelen

 --lrudox
 for i = 0, 3 do
  local y = i==2 and -18 or 0
  local x = i>1 and 18 or 36*i
  self:add(intro_keyspr(i, vec(72+x, 96+y)))
 end

 for i = 4, 5 do
  self:add(intro_keyspr(i, vec(18*i-68, 96)))
 end

 -- build fadetable
 self.fadeindex={}
 for k,v in pairs(self.greyscale) do
  self.fadeindex[v]=k
 end

end
function introscreen:update()
 if (band(btn(), 0b111111) > 0) then self.held += 1
 else self.held = max(self.held -4, 0) end

 if (self.held >= self.fadelen) self.onopen()

 stage.update(self)
end
function introscreen:draw()

 local fadescale = self.fadelen/#self.greyscale
 for c in all(self.greyscale) do
  local i = self.fadeindex[c]+flr(self.held/fadescale)
  pal(c, self.greyscale[i] or 7)
 end

 rectfill(0,0,128,128, 0)
 for i, s in ipairs(self.lines) do
  local x = (128 - (#s * 8)) / 2
  s = "\^w\^t" .. s
  print(s, x, 16+(i-1)*14 + 2, 1)
  print(s, x, 16+(i-1)*14, 7)
 end
 stage.draw(self)
end

-->8
--pico-8 builtins

function _init()
 -- roommenu_init{
 --  complab=room_complab,
 --  cross=room_t,
 --  lab=room_lab,
 --  hall=room_hallway,
 --  stair=room_stair,
 --  vent=room_turbine,
 --  roof=room_roof,
 --  ocean=room_ocean,
 --  chess=room_chess
 -- }
 if debug then
  --  menuitem(5,'toggle debug',function() debug = not debug end)

  menuitem(1,'progress',function()
    state_flags['holefilled'] = true
    chest_data['limoncello'] = true
    chest_data['clabdollar'] = true
    chest_data['clabfaygo'] = true
    chest_data['sciencetank'] = true
   end)
 end

 prettify_map()
 -- starting room
 if (debug) then
  room_stair()
  focus:push'player'
 else
  cur_room = introscreen(90, function()
    room_complab()
    focus:push'player'
    o_player.cooldown = 20
   end)
 end
end

function _update()
 cur_room:update()
end

function _draw()
 cur_room:draw()
end
__gfx__
0011223300000000eeeeeeee009a555555519a00fffffff1111111111fffffff5000000000000005000000000000000000000000000000050000000000000000
0011223300000000e222222e09a55555555519a0ffff1111115115111111ffff56dd555d6d555556055555555555555055dddd5500000015000000aa90000000
4455667700000000e222662e9a5555555555519aff11111111155111111111ff0dddd555ddd55556011111111111111055555555000005150005555955555000
4455667700000000e222222e9a5555555555519aff11111115511551111111ff0ddddd555ddd555d015000000000051051111115000015150551111111111550
8899aabb00000000e222222e9a5555555555519af1111115115115115111111f0dddddd555ddd555015066066060051051111115000515155111111111111115
8899aabb00000000e266222e9a5555555555519af1221111151111511111221f0ddddddd555ddd5d015000000000051051111115001515155111111111111115
ccddeeff00000000e222222e9a5555aaa555519af1112221111111111222111f0dddddddd555dddd015066666066051051111115051515155111111111111115
ccddeeff00000000eeeeeeee1111111911111111fff111122222222221111fff05dddddddd555ddd015000000000051051111115151515155111111111111115
0011111133333333666666669a555199a555519a11111111eee01eeeeee05eee055dddddddd555d6015555555555551051111115151515151111111111111111
0011111133333333666666669a5551115555519a11111111e000001eeee05eee0d55dddddddd555d011111111111111051111115151515151111111111111111
2255ddff3b333333666666669a5555555555519a11111d1100000001ee0000ee0dd55dddddddd55d500000000000000051111115151515156666666666666666
2255ddff33b3b333666666669a5555555555519a1111cd11e0deee0eee0000ee0ddd555ddddddd5d1110111555110110511111151515151566dddddddddddd66
2299aa3333333333666666669a5555555555519a11cdd1d1e0da9e0ee000050e05ddd55ddddddddd100000000000000051111115151515156d555555555555d6
2299aa333333333b666666669a5555555555519addd11111e0daae0eee0000ee055ddd55dddddddd065655666665656051111115151515156d5dddddddddd5d6
3355eeee3333b3b3666666669a5555555555519a11111111ee0000eee000050e0d55ddd55ddddddd011111555551111051111115151515156d5dd555555dd5d6
3355eeee33333333666666669a5555555555519a11111111eee05eeee000050e0dd55ddddddddd65100000000000000051111115151515156d5d5dd55dd5d5d6
0000044444440000000001dddd000000eeeeeeee6666666666666666777777775000000000000000000000000000000051111115151515156d5d5dd55dd5d5d6
0000488887884000000001d8dd000000e222222e6ccccccc666666667777777705555555555555555555555d00077000511111151515151d6d5d5dd55dd5d5d6
000048484848890000d001dddd0ddd00e222002e6ccccccc6666666677777777511111111111111111111115000ff00051111115151515dd6d5d5dd55dd5d5d6
000048898777aa400ddd0111111d8d50e222222e6ccccccc666666667777777751111111111111111111111500f28f00d555555d15151ddd6d5d5dd55dd5d5d6
0004848878787aa9dd8dd000001ddd55e222222e6ccccccc66666666777777775111111111111111111111150f2888f05ddd55dd1515dddd6d5d5dd55dd4d5d6
0048889878477aa41ddddd00001ddd50e200222e6ccccccc66666666777777775111111111111111111111150f9aaaf055ddd55d151ddddd6d5d5dd55d4645d6
4484848487887a7a01ddd100001ddd00e222222e6ccccccc66666666777777775111111111111111111111150f2888f00000000015dddddd6d5d5dd55d6465d6
48889888aa77aaa4001d100000115000eeeeeeee6ccccccc66666666777777775111111111111111111111150f7877f0000000001ddddddd6d5d5dd55d6565d6
4484848aaaaaaaa9cccccccccccccccc0000000055555555666666667777766705500000000000000000056d0f7788700cccc000dddddddd6d5d5dd55dd6d5d6
004888aaaaaaaaa4c77cccccc00ccccc000000005555555577677767777776670d51111111111111111115dd06288af0c9beac00dddddddd6d5d5dd55dd5d5d6
00048aaaaaaaafa9c77cccc00000cccc000000005555555577677767777776670d51111111111111111115dd0f2aa8f0cbebbc00dddddddd6d5d5dd55dd5d5d6
00009aaaaaaf4a4077cc0c0fffff0c0c000000005555555577677767777776670dd555555555555555555ddd0f2888f0cebbec00dddddddd6d5d5dd55dd5d5d6
000004aaaaa9000077cc00f0f0fff0c00000000055555555776777677777766705ddd5555ddd55dddddddddd0f2228f0cabe9c20dddddddd6d5d5dd55dd5d5d6
0000009aaf400000c77cc0f000fff0c000000000555555557767776777777667055ddd5555ddd55ddddddddd022002200cccc889dddddddd6d5d55555dd5d5d6
00000004a9000000c77ccc0f0fff0c0c000000005555555566666666777776670d5dddd555dddd555ddddddd0000000000002884dddddddddd5dd555555dd5dd
0000000a4a000000ccccccc00000cccc000000005555555577777777777776670dd55ddd5555dddddddddd6500000000000002e0dddddddd66d5555555555d66
fffffffffffffffffffffffffffffffffffffffffffffffffffff1fffffffffffffff1fffffffffffffffff1ffffffffaaaa11111111aaaa3333333333333333
ffffffffffffffffffffffffffffffffffffffffffffffffffff11f111111fffffff111111111fffffffff11f11111ffaa111111111111aa3333333331111333
ffffffffffffffffffffffffffffffffffffffffffffffffff1111111111fffffff11111111111ffffff1111111111ffa11111111111111a333333331bbbb133
fffffffffffffffffffffffffffffffffffffffffffffffff1111111111111fff1f11111111111ffff1f1111111111ffa11111111111111a333333331b1b1133
fffff11111fffffffffff11111fffffffffff11111fffffff19111111111911ff11191111119111fff1111191111111fa11111111111111a33333111bbbbbb13
fff117777711fffffff117777711fffffff117777711fffff199111111199111f11911111111911fff111119911111111a111111111111a133111111b7777b13
ff17777777771fffff17777777771fffff17777777771ffff19911111119911ff11111111111111fff1111199111111f1aa611111111aaa131bb11111b77b113
ff17777777771fffff17777777771fffff17777777771ffff111d111d11111fff1111111111111ffff11111d1111611f1a6aaa6aaa6aaaa131bb111b11bb1133
f1777777777771fff1777777777771fff1777777777771fff111d11d116111fff1111111111111ffff11111d6611111116aaa6aaa6aaaa6131bbbbbbbbbbb133
f1777177717771fff1777777777771fff1777777777171ff1111d9161961111f111111111111111ff111111d6691611f1aaa6aaa6aaaa6a1331b1bbb1bbb1333
f1777077707771fff1777777777771fff1777777777071fff1d1d916196161ffff111111111111ffff1111dd669161ff1aa6aaa6aaaa6aa1333111bbb1113333
f17777e777e771fff1777777777771fff1777777777771ffff1dd5666d6611fffff1111111111ffffff1111d66dd61ff1a6aaa6aaaa6aaa13333311111333333
ff17777dee771fffff17777777771fffff17777777771ffffff11d111611fffffff111111111ffffffff11ddd1161fff16aaa6aaaa6aaaa13333330033333333
ff17777777771fffff17777777771fffff17777777771fffffff1dd6661fffffffff1111111fffffffffff1dd661ffff1aaa6aaaa6aaaaa13333303000333333
fff117777711fffffff117777711fffffff117777711fffffffff11111fffffffffff111111fffffffffff11111fffff1aa611112111aaa13333330003333333
ffff1111111fffffffff1111111fffffffff1111111fffffffff1055101fffffffff1000000fffffffffff10051fffff1a211112111111613333333333333333
ffff1777771fffffffff1777771fffffffff1777771fffffffff1050001fffffffff1000000ffffffffff1000551ffffa21110200001121a0001c00100000000
ffff1777771fffffffff1777771fffffffff1777771fffffffff1000501fffffffff1000000ffffffffff1000501ffffa1110211111d211a0c01000c10000000
ffff1777771fffffffff1777771fffffffff1777771fffffffff1015501fffffffff1000000ffffffffff1000151ffffa1112dddddd2111a1c11dd7cc8000000
ffff1777771fffffffff1777771fffffffff1777771fffffffff1511111fffffffff1511115ffffffffff1511111ffff15121111112111d100ccdc7cccc00000
fffff11111fffffffffff11111fffffffffff11111ffffffffff1555551fffffffff1551555ffffffffff155551fffff155511111211d5d1001ccc7c8ccc0000
fffff1fff1fffffffffff1fff1fffffffffff1fff1ffffffffff1551551ffffffff111515511ffffffffff1551ffffffa15555555555d51a001ccc7cccc00700
fffff1fff1fffffffffff1fff1fffffffffff1fff1ffffffff10551110551ffffff0001111051fffffffff100551ffffaa115555555511aa00010070cc007000
ffff1fffff1fffffffff1fffff1ffffffffff1ffff1fffffff11111f11111ffffff1111111111fffffffff111111ffffaaaa11111111aaaa0000c00777770000
0000000000000000533333333333333555555555500050009999999909afa49049afa4947777ddd5000000000000000000000000772222dddddddddddddddddd
0555555555555550011111111111111011111111050505059444444909afa49049afa4947666ddd50555555555555550008880007777dd2dd66dddd555ddd66d
01111111111111100101011011011010000000005050505094444449099fa990499fa4947666ddd5011111111111111008fee80027700dd26d56dd57675d65d6
015222222aa44510011101101101111000000000055505559444444909a99490449999447666555501577bbccaa995108f888820270000d265d6d55655dd6d56
0156bbb72284a510011101101101111000000000555555559444444909afa49044444444ddd57777015667070076651008eee2002d0000d2d66dd56565ddd66d
01560bb172196510011101101101111000000000555555559999999909afa49099999999ddd5766601566ffffff66510008e20002dd00dd2dddddd555ddddddd
015ffdcd65163510010131131131101000000000555555559faaaaa9099fa9909faaaaa9ddd5766601566fff0ff6651000020000d2dddd2ddddddddddddddddd
015dfdc665686510000000000000000055555555555555559999999909a99490999999995555766601566ff0bff6651000000000dd2222dddddddddddddddddd
fffffffffffffffffffffffffffffffffffffffffffffffffffffff1ffffffffffffffff1fffffffffffffff11ffffffeeeeeeeeeeeeeeeefffffff00fffffff
fffffffffffffffffffffffffffffffffffffffffffffffffff1f111ffffffffffffffff111f1fffffffff111fffffffeeeee00000eeeeeeffffff0b0fffffff
fffff111111fffffffff11111111ffffffff111111ffffffff9111111111191ff1911111111119fffff1199111111fffeee004444400eeeefffff0b00000ffff
fff11111111111ffff11111111111ffffff1111111111fff1f191111111191f11f191111111191f11ff11199111111f1ee04444444440eeeffff0bbbbbb0ffff
19111111111111911911111111111191f11911111111111f111981111118911111111111111111111111119811111111e0444444444440eefff0bbbbbb000fff
f19111111111191f1191111111111911f1119911111111ff111811111111811111111111111111111111111811111111e0444444444440eeff0cbbbbbbbb0fff
f19981111118991f1181111111111811f1111981111111ff111111d1dd1111111111111111111111f111111111d11111e0444444444440ee00bbbbcbbbb0ffff
ff1811111111811f1111111111111111f111111111111ffff111dddd6666111ff11111111111111ff1111116666dd11fe0444999444440ee0bbbbbbbb03b0fff
ff1111dd11d111fff11111111111111ff11111111d111ffff11111166111111ff11111111111111fff1111161111d11fe0449999999440ee033000000f00ffff
ff18878dd88881fff11111111111111ff111111648781ffff11119166191111ff11111111111111fff1111166191d1ffe0449779779440eef000f07770ff000f
ff114788488811ffff1111111111111ff111111664788fffff115916619d11ffff111111111111fffff111666d91d1ffe0499999999940eefffff0aabb00000f
ff111dd6666111ffff111111111111fff111111666dd1ffffffdd5566dd66fffff111111111111fffff1111666d5d1ffee0999c999990eeefff0f0aabbbbb30f
ff111d17716111ffff111111111111fff111116661771fffffff1dd33661fffffff1111111111fffffff1166633d1fffeee099c99990eeeeff0b000bbbb330ff
ff111dd1166111ffff111111111111ffff11116666111ffffffff1dd661fffffffff11111111fffffffff1166dd1ffffeeee0999990eeeeeff0330b0b3300fff
fff111dd66111fffff111111111111fffff111166d11fffffffff111111ffffffffff111111fffffffffff11111fffffeeeee00000eeeeeefff00033300fffff
fff1100110011fffff111111111111fffff111000011ffffffff10333001ffffffff10000001ffffffffff10001fffffeeee0777770eeeeeffffff000fffffff
fffff003300ffffffff1111111111ffffffff10000ffffffffff10031301ffffffff10000001fffffffff100031fffffeeee0774770eeeee0000000000000000
fffff033330fffffffff10000001fffffffff10003ffffffffff10031301ffffffff10000001fffffffff100031fffffeeee0799970eeeee0000000000000000
fffff000000fffffffff10000001fffffffff10000ffffffffff12003121ffffffff12000081fffffffff180011fffffeeee0799470eeeee0000000aa1111aa0
fffff011110fffffffff10111101fffffffff11111ffffffffff12887821ffffffff12282881fffffffff182221fffffeeee0777770eeeee0000001aabbbbba0
fffff000000fffffffff10000001fffffffff10000ffffffffff12888281ffffffff12288881fffffffff188871fffffeeee0d55550eeeee00000133bbbbbb10
fffff000000fffffffff10000001ffffffffff0001ffffffffff12882221ffffffff12228881ffffffff1888211fffffeeee0ddddd0eeeee1110013bbbbbbbb1
fff2488224882ffffff4441111488fffffffff88842ffffffff0555110555ffffff0001281055ffffff182215001ffffee01dd0001dd0eee1bb113bb11111111
fff2222222222ffffff2222112222fffffffff22222ffffffff1111111111ffffff1111111111ffffff111111111ffffee00000e00000eee13bb13bbbbbb3110
0666666051111115511111158888888e22ff2722000000000000980000055500dddd005d1111111110001000000000005555555555555555013bb3bbbbb31310
5000000651111115511111158888888e7733772200000008aaa9a80055577650ddd0000011d111110101010111d111115666666666666665001bbbbbbb113100
5d66666551111111111111150088808e7073772200ddd8ff7aa9980056777650dd0000dd1d511111101010101d51111156dddddddddddd6501bb1333333b1000
50cccc0651111111111111158888888e7773732202dcd8f887a9998056776665d0000ddd11111111011101111111111156dddddddddddd65133311111113b100
5cccccc651111111111111158808880ef333332200ddd8f887aa9a800566d165d000dddd11111111111111111111111156666666666666651111000000011110
5cccccc651111111111111158880008e2f3333ff002dd8ef77aa99800561d66500d0dddd11111d111111111111111d1156dddddddddddd650000000000000000
dd1111d651111111111111158888888eff7733f2002dc8eee999800005666555ddd50ddd1111d511111111111111d51156dddddddddddd650000000000000000
0dddddd11555111111115551eeeeeeee227722f2002222220000000000555000dddddddd11111111111111111111111156666666666666650000000000000000
fffffff111111fffff111111fffffffff11ffff111111fffffffffffffffffff0000000000000000500010111101000556dddddddddddd65cccccccccccccce1
fffff1111111fffffff1111111fffffff11111111111ffffffffffffffffffff00809080905b6b0056dd51111d15155656dddddddddddd65cccccc1eccce0e1e
fff11111111fffffffff11111111ffffff1111111111fffffddddddddddddddfeeeeeeeeeeeeeeee0ddd151111d155565666666666666665cccccce1ee0070ee
1111111111111fffff1111111111111fff11111111111fffd60606060606060d008191c35b6bc7000dd1d151111d555d56dddddddddddd65ccccccee107070ec
1111111111111fffff1111111111111ff111111111111fffd60606060606060deeeeeeeeeeeeeeee0ddd1d1111d1d55556dddddddddddd65ccccccc1e077770c
f11111111111111f111111111111111ff11111111111111fd60606060606060d008090c3e0f0c3000dddd111151d1d5d5666666666666665ccccccce0777770c
111177111177111f111111111111111ff11111117771111fd60606060606060deeeeeeeeeeeeeeee0ddd1d111151dddd5611111111111165ccccccc007077770
111ddd771ddd711f111111111111111ff1111117ddd7111fd60606060606060d008b918b31e0f00005d1d1d111155ddd5611111111111165ccc0000e07077770
11d777d7d777d1fff11111111111111ff111171d777d11ffd60606060606060deeeeeeeeeeeeeeee055d1d1111d155d65611111111111165c00770ee07700770
11d711d7d117d1ffff111111111111fff111177d711d1fffd60606060606060d0080c8d8903141000d55d1111d1d155d5611111111111165077770ee0777700c
117ddd777ddd71ffff111111111111fff1111777ddd71fffd60606060606060deeeeeeeeeeeeeeee0dd51d1111d1d55d5611111111111165070e770077770ccc
f117777777711fffff111111111111fff111777777771fffd60606060606060d0081c9d98b8191000dd15151111ddddd56111111111111650700777777070ccc
f11177dd77111ffffff1111111111fffff1117777d71ffffd60606060606060deeeeeeeeeeeeeeee05dd151111d1dddd561111111111116500c0707007070ccc
ff1117767111fffffff1111111111fffff111177771fffffd60606060606060d008bcada90809000055dd1111d1d1ddd56111111111111650c07707007070ccc
ff1a911119a1ffffffff11111111fffffff1111111fffffffddddddddddddddfeeeeeeeeeeeeeeee0d551d1111d1dddd5666666666666665cc07070c07700ccc
fffa9aaaa9afffffffffa111111affffffff1a9aa9ffffffffffffffffffffff00819181918191000dd151d1111ddd655555555555555555cc00c00cc00ccccc
fff9aaaaaa9fffffffff9aaaaaa9fffffffffaa99affffff00000000000000000000000000000000000000000000000000000000ee6666eefffff11111ffffff
fffa9aaaa9afffffffffa9aaaa9afffffffffaaaa9ffffff00000000000000000000000000000000000000000000000000000000e600006eff11111111111fff
fff9a9aa9a9fffffffff9a9aa9a9fffffffff9999affffff0000000000000000000000000000000000000000000000000000000060000006fff911111119ffff
fffaaa99aaafffffffffaaa99aaafffffffffaaaaaffffff0000000000000000000000000000000000000000000000000000000066000066fff991111199ffff
fffaaaaaaaafffffffffaaaaaaaafffffffffa9aaaffffff00000000000000000000000000000000000000000000000000000000676666d6fff111dd1d11ffff
fff99ffff99fffffffff99ffff99ffffffffff99ffffffff000000000000000000000000000000000000000000000000000000006677dd66fff1878d8881ffff
fffeed22deefffffffffeed22deefffffffff2deeeffffff000000000000000000000000000000000000000000000000000000006d6666d6fff117888811ffff
ff2222222222fffffff2222222222ffffffff222222fffff000000000000000000000000000000000000000000000000000000006dd555d6fff11d171611ffff
111111111111111151511111111115155151111111111515777766665555000000000000000000000000000000000000000000006dd555d6fff11dd16611ffff
111111111111111155111111111151515511111111115151777776665555500000000000000000000000000000000000000000006dd555d6ffff1001001fffff
111111155111111151551111111155155151111551111515777777665555550000000000000000000000000000000000000000006dd555d6fffff00300ffffff
111155511555111115115551155511551515555115555155777777765555555000000000000000000000000000000000000000006dd555d6fffff03330ffffff
555511111111555551511115511115155151111111111515677777770555555500000000000000000000000000000000000000006dd555d6fffff01110ffffff
11111111111111115511111111115151551111111111515166777777005555550000000000000000000000000000000000000000d6dd5d6dfffff00000ffffff
11111111111111115151111111111515515111111111151566677777000555550000000000000000000000000000000000000000ed6666defffff00000ffffff
11111111111111111515111111111155151511111111115566667777000055550000000000000000000000000000000000000000eeddddeeffff2222222fffff

__gff__
0000010000000000010100000001000000010100000000000101000000010000000000000100000100000000000100000000000001000001000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100010000000000000000000000000000010100000000000000000000000000000101000000000000000000000000000000000000000000000000000001010000000000000000
__map__
0000000101010101010101010001010100000000000000000000000000000000000000007575757575757575000000000000000000000000000000000000080900000000000000000000000000000000000035353535353535351111111111110000000000000000000000000000000000000000000000000000000000000000
0000000a0b0000000000000a0b0000000000000a0b0000000000000a0b0000000000000035353535353535350000000000000000000000000000000000001819000000000000000000000000000000000000353535353535353511111111111100003d3d3d3d3d3d3d3d3d3d3d3d000000000000000000000000000000000000
0928291a1b2929292929291a1b2929292929291a1b2929292929291a1b292a080000000072733535353572730000000000000000000000000000000000000809000000000000000000000000000000000000262626262626262611111111111100003d3d3d3d3d3d3d3d3d3d3d3d000000000809080908090809080908090000
1938393939393939393939393939393939393939393939393939393939393a180000000008090809080908090000000000007575757575757575757575751819000000000000000075757575757575750000262525262626262611111111111100003d3d3d3d3d3d3d3d3d3d3d3d000000001819181918191819181918190000
0c0c090809080908090809080908090809080908090809080908090809080c0c000000001819181918191819000000000000080908090809080908090809080900000000000000000809080908090809000026252526262626261111111111110101080908090809080908090809000008090809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c000000000809080908090809000000000000181918191819181918191819181975757575757575751819181918191819000026262626262626261111111111110101181918191819181918191819000018191819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c757575751819181918191819757575750000080900000000000000000000080908090809000008090809000000000000000027272727272727371111111111110101080908090809080908090809000008090809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c353535350809080908090809353535350000181900000000000000000000181918191819000018191819000000000000000027272727272727371111111111110101181918191819181918191819000018191819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c72733535181918191819181935357273000008090000000000000000000000000000000024240000000000000000000000002727272727272737111111111111000008093d3d080908093d3d0809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c080908090809080908090809080908090000181900000000000000000000000000000000242400000000757575750000000027272727272727371111111111110000181918191819181918191819000000001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c18191819181918191819181918191819000008090000000000000000000000000000000008090000000008090809000000002727272727272737111111111111000008090809080908090809080900000000000000000000240d080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c080908090809080908090809080908090000181900000000000000000000000000000000181900000000181918190000242727272727272727371111111111110000181918191819181918191819000000000000000000240d1d181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c1819181918191819181918191819181900000809000000000000000000000000000000000000000000000000000000002427272727272727273711111111111100000809080908090809080908090100000000000000240d1d2d3d3d3d3d0100
1c1c191819181918191819181918191819181918191819181918191819181c1c08090809080908090809080908090809000018190000000000000000000000000000000000000000000000000000000024243636363636363636111111111111000018191819181918191819181900000000000000240d1d2d3d3d3d3d3d0000
1c1c090809080908090809080908090809080908090809080908090809081c1c18191819181918191819181918191819000008090000000000000000000000000000000000000000000000000000000024242626262626262626111111111111000008093d3d080908093d3d080900000000080908091d2d3d3d3d3d013d0000
1c1c191819181918191819181918191819181918191819181918191819181c1c00000000000000000000000000000000000018190000000000000000000000000000000000000000000000000000000024240202020202020202111111111111000018191819181918191819181900000000181918192d3d72733d3d013d0000
1c1c090809080908090809080908090809080908090809080908090809081c1c000000000000000000000000000000000000007600000000000000760000000000000000760000000000000076000000151515151515151515151515151515150000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c0000000000000000000000000000000000000077000000000000007700000000000000007700000000000000770000001515151515151515151515153db815150000181918191819181918191819000000001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c757575babababababababababa7575750000007700000000000000770000000000000000770000000000000077000000151515151515151515151515727315150000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c3535f4f1f0f1f0f1f0f1f0f1f0f535350000007700000000000000770000000000000000770000000000000077000000151212121212121212121212727312150000181918191819181918191819000000001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c3535f2f0f1f0f11e1ff0f1f0f1f33535000000770000000000000077000000000000000077000000000000007700000015121212121212121212121212121215000008093d3d080908093d3d0809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c3535f4f1f0f1f02e2ff1f0f1f0f535357979797879797979797979787979797979797979787979797979797978797900151212121212121212121212121212150000181918191819181918191819000000001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c3535f2f0f1f0f13e3ff0f1f0f1f33535797979797979797979797979f6f7f6f7f6f7f6f7797979797979797979797900151212121212121212121212121212150000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c0809cabbbbbbbbbbbbbbbbbbbbcb0809797979797979797979797979f7f6f7f6f7f6f7f67979797979797979797979001512121212121212121212121212121500001819181918191819181918190000000018191819181928290a0b18190000
1c1c090809080908090809080908090809080908090809080908090809081c1c1819dab9b9b9b9b9b9b9b9b9b9db1819797979797979797979797979f6f7f6f7f6f7f6f779797979797979797979790d1512240d121212121212121212121215000008090809080908090809080908090000080908090809b1b91a1b08090000
1c1c191819181918191819181918191819181918191819181918191819181c1c0809cab9b9b9b9b9b9b9b9b9b9cb0809797979797979797979797979f7f6f7f6f7f6f7f679797979797979797979791d15120d1d1212121212121212121212150000181918191819181918191819181900001819181918193839393a18190000
1c1c090809080908090809080908090809080908090809080908090809081c1c1819dab9b9b9b9b9b9b9b9b9b9db1819797979797979797979797979f6f7f6f7f6f7f6f779797979797979797979792d15121212121212121212121212121215000008093d3d080908093d3d0809080900000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c00000000000000000000000000000000797979797979797979797979f7f6f7f6f7f6f7f6797979797979797979797900153535bcbd353535353535bcbd3535150000181918191819181918191819181900001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c00000000000000000000000000000000797979797979797979797979f6f7f6f7f6f7f6f7797979797979797979797900151135cccd113535351135cccd1135150000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c00000000000000000000000000000000797979797979797979797979f7f6f7f6f7f6f7f6797979797979797979797900153535dcdd351111351111dcdd3511150000181918191819181918191819000000001819181918191819181918190000
b1292929292929292929292929292929292929292929292929292929292929b2000000000000000000000000000000007979797979797979797979797979797979797979797979797979797979797900151819151515151515151515151819150000000000000000000000000000000000000000000000000000000000000000
383939393939393939393939393939393939393939393939393939393939393a000000000000000000000000000000003535353535353535353535353535353535353535353535353535353535353535151819151515151515151515151819150000000000000000000000000000000000000000000000000000000000000000
__sfx__
010600000605001050060500305018000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0906000003d7007d7004d7006d7003d7006d7206d7600d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d00
000900000362000640006000160000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
490a00001b330183301b3302033020330003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
0103000013e500de5000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e00
000400003701038030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01080000125500d550125500f55000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
0006000023f502df502c5000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
010a00001d84000e001b8400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011e00001890518905289451c9550090000900289451c9550090500905289451c9551890518905289451c9551890518905289451c9551890518905289451c9551890518905289451c9551890518905289451c955
191e00000e050000000e035000000d050000000d03500000100500000010035000000e050000000e0350000009050000000903500000080500000008035000000705000000070350000008050000000803500000
593c180018530245301f530165301d530165301b530225301b530035300f5301f5301d530185301d5301b530165301b53016530115301d5301f5300e5301d5300050000500005000050000500005000050000500
011e000013145001051a1450010518145001051a1450010516145001051a1453010515145001051a145001050f14500105181450010516145001051814500105151450010511145001051b145001050e14500105
011e00001f7221f7221f7221f7221f7221f7221f7221f7221a7221a7221a7221a7221a7221a7221f7221f7221b7221b7221b7221b7221b7221b7221b7221b7222172221722217222172221722217221d7221d722
011e00001f543180321c0321f03216542160321d0321603211542110321d0322103213542130321a0321f03218542180321c0321f03216542160321d0322203215542150321d03221032135421a0322303224032
211e100015045110451004515045110451004515045110451004515045110451004515045100450e04515045100450e04515045100450e04515045100450e0450000500005000050000500005000050000500005
911e18001f53021535005001f53021535005001d5301f534005001d5301a534005001f53021535005001f53021535005001f53022534005001f53021535005000050000500005000050000500005000050000500
491e00001555000500215501555012550005001e550125501755000500235501755010550005001c550105500d55000500195500d55012550005001e5501255017550175532355017550105500e5500d55217550
050f002000600006000c625006000c6250c620006050060500605006050c625006050c6250c620006050060500605006050c625006050c6250c620006050060500605006050c625006050c6200c6250060500605
492d18000c1320e1300f130061320e1300f1300c1320e1300f13006132121300e1300c1320e1300f130061320e1300f1300c1320e1300f13006132121301a1300010000100001000010000100001000010000100
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
03 13494344
03 0b494344
03 0c0d4344
03 100f4344
03 0e4f4344
03 11124344

