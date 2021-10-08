pico-8 cartridge // http://www.pico-8.com
version 33
__lua__

-- title
-- author

-- global vars

local debug = true  -- (stat(6) == 'debug')

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
end
function entity:update()
 if self.ttl then
  self.ttl -= 1
  if (self.ttl < 1) self:destroy()
 end
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
 kwargs = kwargs or {}
 self.pos, self.spr, self.size = pos, spr_, size
 for prop in all{'anchor', 'offset', 'z_is_y'} do
  self[prop] = chainmap(prop, kwargs, self)
 end
 self._apos = self.pos:__add(self.anchor):__add(self.offset)
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
 self._apos = self.pos:__add(self.anchor):__add(self.offset)
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
 dynamic=false,
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
 local halfsize = 0  -- -self.size.x/2
 self.offset = vec_zero
 self.anchor = vec(halfsize, -self.size.y)
 self.bsize = vec(self.size.x, self.footy)
 -- hbox should go to one-inside pos
 self.hbox_offset = vec(halfsize, -self.footy)
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
 self.talkedto += 1
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
 o_player.justtriggered = true
 o_player.cooldown = 1
 cur_room:update()  -- align camera
end

local t_player = isomob:extend{
 ismoving = false,
 facing = 'd',
 spr0 = 0,
 cooldown = 0,
 footy=8,
 dynamic=true
}
function t_player:init(pos, kwargs)
 kwargs = kwargs or {}
 isomob.init(self, pos, nil, vec8(1,2))  -- a little smaller
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
   if (nhbox:overlaps(obj.hbox) and obj.obstructs) unobstructed = false; break
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

 -- if (btn(4)) self.elev += 1
 -- if (btn(5)) self.elev -= 1
 -- if (btn(4) and btn(5)) self.elev = 0

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
 local facemap = {d=vec8(0, 1),u=vec8(0, -1),l=vec8(-1, 0),r=vec8(1, 0)}
 if btnp(4) then
  local ibox = bbox(self.hbox.origin, vec_8_8):shift(facemap[self.facing])
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
 self.hbox = self:get_hitbox()
end

function t_player:draw()
 self.flipx = (self.facing == 'l')
 local facemap = {d=0, u=2, l=1, r=1}
 self.spr = self.spr0 + facemap[self.facing]
 if self.ismoving and self.stage.mclock % 8 < 4 then
  self.offset = vec_zero
 else
  self.offset = vec(0, -1)
 end
 isomob.draw(self)
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
 local facemap = {d=0, u=2, l=1, r=1}
 self.spr = self.spr0 + facemap[self.facing]
 if (self.istalking or self.ismoving) and self.stage.mclock % 8 < 4 then
  self.offset = vec(0, -1)
 else
  self.offset = vec(0, -0)
 end
 mob.draw(self)
end

local scoreui = entity:extend{}
function scoreui:drawui()
 rectfill(0, 120, 32, 128, 9)
 rect(0, 120, 32, 127, 10)
 prints(itostr(score, 8), 1, 121, 0, 10)
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
  prints('8' .. tostr(o_player.pos:__div(8):floor()), 64, 0)
  prints('room ' .. tostr(self.map_origin/16), 0, 8)
  prints('mous ' .. tostr(mous), 0, 16)
  prints('8' .. tostr(mous:__div(8):floor()), 64, 16)
 end
end

-->8
-- rooms
local r_test = room:extend{
 startpos = vec8(8, 10),
 mapbox = bbox.fromxywh(0, 0, 1, 1)
}
function r_test:init(v)
 room.init(self, v)

 local o_sign = self:add(entity({z=0}))
 function o_sign:draw()
  color(7)
  print("\^w\^tthe game", 8, 8)
  line(8, 20, 70, 20)
  print("1. stand in \fathe spot\f7", 8, 24)
  print("2. do not move from\n   \fathe spot\f7", 8, 32)
 end

 local o_scorer = self:add(mob(vec8(7.5, 11.5), 032, vec_8_8, {
    bsize=vec(12, 12),
    hbox_offset=vec(-2, -2)
   }))
 local o_circ = self:add(t_sign(vec8(6.5, 11), 003, vec8(3,2)))
 o_circ.z = 0
 o_circ.tcol = 7
 o_circ.lines = "it's \fathe spot\f7."

 function o_scorer:update()
  mob.update(self)
  if self.stage.mclock % 30 == 0 then
   if o_player.hbox:within(self.hbox) then
    score += 1
    sfx(000)
   end
  end
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
 self:add(t_trigger(vec8(15.5, 8), vec8(0.5, 3), r_test, {
    pos=vec8(0.5, 10)
   }))

 local o_sign = self:add(entity({z=0}))
 function o_sign:draw()
  color(7)
  print("you are now entering", 42, 18)
  print("\^w\^tthe game", 42, 26)
 end

 local o_trash = self:add(isosign(vec8(13, 14.5), 006, vec8(2,3)))
 o_trash.lines = "it's a bin filled with old, dirty ui elements"

 local o_paint = self:add(t_sign(vec8(10, 13), 033, vec_8_8))
 o_paint.lines = "a paint roller, for putting up game instructions."

 local o_note = self:add(t_sign(vec8(2, 9), 048, vec_8_8))
 o_note.lines = 'it\'s a note.\r"no game over here", it reads.'

end

r_street = room:extend{
 startpos = vec8(13, 14),
 mapbox = bbox.fromxywh(1, 0, 0, 1)
}
function r_street:init(v)
 room.init(self, v)
 local o_hole = self:add(mob(vec8(13, 13), 009, vec_8_8))
 o_hole.tcol = 15
 function o_hole:interact(p)
  cur_room = r_test(vec8(13, 2))
 end

 self:add(t_trigger(vec8(0, 12), vec8(0.5, 3), r_closet))

 local o_door = self:add(mob(vec8(11, 5), nil, vec8(1,2)))
 function o_door:interact(p)
  cur_room = r_test(vec8(13, 2))
 end
 function o_door:draw()
  print("arcade", 82, 33, 6)
  mob.draw(self)
 end

 local o_guy = self:add(t_npc(vec8(13, 10), nil, vec8(1,2)))
 o_guy.paltab = {[7]=6}
 o_guy.lines = "hey, you know there's a game down there, right?"

 local o_sign = self:add(isosign(vec8(10.5, 13.5), 010, vec8(2,2), {footy=2}))
 o_sign.lines = "it's a sign. it says there's a game in the hole."

 for pos in all({
   vec8(3, 13),
   vec8(0, 11),
   vec8(2, 6),
  }) do
  local o_tree = self:add(isomob(pos, 025, vec8(1,2)))
  o_tree.tcol = 1

 end

end

r_maze = room:extend{
 startpos = vec8(0, 10),
 mapbox = bbox.fromxywh(1, 1, 1, 0)
}
function r_maze:init(v)
 room.init(self, v)
 self:add(t_trigger(vec8(0, 8), vec8(0.5, 3), r_test, {
    pos=vec8(15, 10)
   }))

 for pos in all({
   vec8(6, 10),
   vec8(13, 10),
   vec8(18, 4),
   vec8(16, 7),
   vec8(4, 3),
  }) do
  local block = self:add(mob(pos, 072, vec_8_8))
  block.i = 10
  block.states = {false, false, false, true, true, true}
  block.paltab = {[9]=8}
  function block:update()
   if self.stage.mclock % 30 == 0 then
    self.i += 1
   end
   if self.i > #block.states then
    sort(self.states, function(a) return rnd() end)
    self.i = 1
   end
   if self.states[self.i] then
    self.obstructs = true
    self.spr = 072
   else
    self.obstructs = false
    self.spr = nil
   end
  end
 end

 local o_guy = self:add(t_npc(vec8(30, 9), nil, vec8(1,2)))
 o_guy.paltab = {[7]=6}
 o_guy.lines = "hi!"

end
-->8
--pico-8 builtins

function _init()
 prettify_map()
 cur_room = r_test()
 focus:push'player'
 if debug then
  menuitem(5,'toggle debug',function() debug = not debug end)
 end
end

function _update()
 cur_room:update()
 dbg.watch(cur_room, "room")
 dbg.watch(o_player, "player")
end

function _draw()
 cur_room:draw()
 if (debug) dbg.draw()
end
__gfx__
0077770000777700007777007777777222222222277777770000000000000000dddddddddddddddd000000000000000011111111111111117777777777777777
07dddd7007dddd7007dddd7077777227777777777227777700000aaaa0000000dddddddddddddddd000000000000000011177777777777117777777777777777
071dd17007ddd17007dddd707772277722222222777227770aaaa9999a000000dddd66ddd060060d066600000006000011777777777777777777777777777777
07dddd7007dddd7007dddd707727722277777777222772770a9999999a000000dddddddd00666600065566600065600017777777777777777777777777777777
07d11d7007ddd17007dddd707277277777777777777277270a9999999a000000dddddddd00d00d00655555566655600017777777777777777777777777777777
0077770000777700007777002772777777777777777727720a9999999a000000dd66ddddd000000d655555555555560017777777777777717777777777777777
007dd700007dd700007dd70027277777777777777777727200a9999999a00000dddddddddddddddd655555555555560011177777777777117777777777777777
007dd700007dd700007dd70027277777777777777777727200a9999999a00000dddddddddddddddd555555555555556011111111111111115555555555555555
007dd700007dd700007dd70027277777777777777777727200a9999999a0000011111111111bb11166555555555555605dddddddddddddddddddddddddddddd5
007dd700007dd700007dd70027277777777777777777727200a9999999a555001111111111b33b1100666555555555565ddddddd000000d077677777ddddddd5
007dd700007dd700007dd700277277777777777777772772051a9999999a1155111111111b3333b100060666555555565ddddddd000000d076777777ddddddd5
007dd700007dd700007dd700727727777777777777727727511a9494949a1115111111111b3333b100060006555556605ddddddd000000d067777777ddddddd5
007dd700007dd700007dd700772772227777777722277277511944444449111511111111b3b33b3b00060065556660005ddddddd000000d077777776ddddddd5
0077770000777700007777007772277722222222777227775511944444449155111111111bb33bb100060066660000005ddddddd000000d077777767ddddddd5
0070070000700700007007007777722777777777722777775d555555555555651111111111b33b1100060000600000005ddddddd000000d077777677ddddddd5
0070070000700700007007007777777222222222277777775dd6666666667665111111111b3333b100060000600000005ddddddd000000d0ddddddddddddddd5
8800008800777777750000000000000700000000700000005dd666666666666533333333b333333bdddddddddddddddd5ddddddd000000d0ddddddddddddddd5
88800888007666666600000000000077000000007700000005d6666666676650333333331b3333b1dddddddddddddddd5ddddddd000000d0ddddddddddddddd5
08888880000001000000000000000777000000007770000005dd6666666666503b3333331b3333b1dddddddddddddddd5ddddddd000000d0ddddddddddddddd5
00888800000001000000000000007777000000007777000005dd66666666665033b3b333b333333bdddddddddddddddd5ddddddd000000d0ddddddddddddddd5
00888800000000100000000000077777777777777777700005dd666666676650333333331b3333b1dddddddddddddddd5ddddddd000000d0ddddddddddddddd5
088888800000002000777777007777777777777777777700005dd666666665003333333bb333333bdddddddddddddddd5ddddddd000000d0ddddddddddddddd5
888008880000002200777777077777777777777777777770005dd666666665003333b3b31bbbbbb1dddddddddddddddd5ddddddd000000d0ddddddddddddddd5
8800008800000002007777777777777777777777777777770005555555555000333333331114411155555555dddddddd55555555555555555555555555555555
00070000007777777777777777777777777777777777777756666666666a66666666666511111111111111110000000000000000000000000000000000000000
00777000007777777777777707777777777777777777777056666666666a66666666666511bb11bbb11bbb110000000000000000000000000000000000000000
07767700007777777777777700777777777777777777770056666666666a6666666666651bb3bb333bb333b10000000000000000000000000000000000000000
776776700077777777777777000777777777777777777000566666666666666666666665b3333b3333b3333b0000000000000000000000000000000000000000
07776777007777777777777700007777000000007777000056666666666a666666666665b33333333333333b0000000000000000000000000000000000000000
00767770007777777777777700000777000000007770000056666666666a6666666666651b333333333333b10000000000000000000000000000000000000000
00077700007777777777777700000077000000007700000056666666666a666666666665b333b333bb33b33b0000000000000000000000000000000000000000
0000700000777777777777770000000700000000700000005666666666666666666666651bbb4bbb4bbbbbb10000000000000000000000000000000000000000
00777777777777000000000070000007000000000000000000000000000000002222222200000000000000000000000000000000000000000000000000000000
07777777777777700000000070000007000000000000000000000000000000002444444200000000000000000000000000000000000000000000000000000000
77700000000007770000ee0077777777000500000000000000005000000000002444444200000000000000000000000000000000000000000000000000000000
77000000000000770000000070000007005555555555555555555500000000002444444200000000000000000000000000000000000000000000000000000000
77000000000000770000000070000007000500000000000000005000000000002444444200000000000000000000000000000000000000000000000000000000
770000000000007700ee000070000007000500000000000000005000000000002222222200000000000000000000000000000000000000000000000000000000
77000000000000770000000077777777000500000000000000005000000000002444444200000000000000000000000000000000000000000000000000000000
77000000000000770000000070000007000500000000000000005000000000002222222200000000000000000000000000000000000000000000000000000000
77000000000000770000000000000000000500000000000000005000333333333333333333333333000000000000000000000000000000000000000000000000
77000000000000770000000000000000000500000000000000005000333333344444444443333333000000000000000000000000000000000000000000000000
77000000000000770000000000000000000500000000000000005000333334444444444444433333000000000000000000000000000000000000000000000000
77000000000000770000000000000000000500000000000000005000333344444444444444443333000000000000000000000000000000000000000000000000
77000000000000770000000000000000000500000000000000005000333444444444444444444333000000000000000000000000000000000000000000000000
77700000000007770000000000000000000500000000000000005000334444444444444444444433000000000000000000000000000000000000000000000000
07777777777777700000000000000000000500000000000000005000334444444444444444444433000000000000000000000000000000000000000000000000
00777777777777000000000000000000000500000000000000005000344444444444444444444443000000000000000000000000000000000000000000000000
77000000000000770000000000000000000500000000000000005000344444444444444444444443000000000000000000000000000000000000000000000000
77000000000000770000000000000000000500000000000000005000344444444444444444444443000000000000000000000000000000000000000000000000
77000000000000770000000000000000000500000000000000005000344444444444444444444443000000000000000000000000000000000000000000000000
77000000000000770000000000000000000500000000000000005000344444444444444444444443000000000000000000000000000000000000000000000000
77000000000000770000000000000000005555555555555555555500344444444444444444444443000000000000000000000000000000000000000000000000
77000000000000770000000000000000000500000000000000005000344444444444444444444443000000000000000000000000000000000000000000000000
77000000000000770000000770000000000000000000000000000000344444444444444444444443000000000000000000000000000000000000000000000000
77000000000000770000007777000000000000000000000000000000344444444444444444444443000000000000000000000000000000000000000000000000
77777777000000000000007777000000000000000050050000000000344444444444444444444443000000000000000000000000000000000000000000000000
77777777000000000000000770000000000000000050050000000000334444444444444444444433000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000050050000000000334444444444444444444433000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000050050000000000333444444444444444444333000000000000000000000000000000000000000000000000
00000000000000000000000000000000555555550050050000000000333344444444444444443333000000000000000000000000000000000000000000000000
00000000000000000000000000000000005005000050050000000000333334444444444444433333000000000000000000000000000000000000000000000000
00000000777777770000000000000000005005000050050000000000333333344444444443333333000000000000000000000000000000000000000000000000
00000000777777770000000000000000005005000050050000000000333333333333333333333333000000000000000000000000000000000000000000000000

__gff__
0000000000000000010100000000000000000000000000000000000000000000000000000000000001000000000000000000000000000101010000000000000001010101000000000000000000000000010101010000000101010000000000000101010100000001010100000000000001010101000000010101000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4445454545454545454545454643000018181818181818181818181818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5455555555555555555555555643000018181818180c0d18181818180c0d1818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
545555555555555555555555564300001818181818181818180c0d1818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
54555555555555555555555556430000181818181818181818182a2a2a2a2a2a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
54555555555555555555555556430000282828280836373808081c2b2b2b2b1f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
64656565656574656565656566430000282828280836373808081c1d2b1e1e1f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000075000000000000430000282828280836373808082c2d2e2e2e2f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0040707070707070707070707070410028282828083637380808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7073424242424242424242424242727028282828083637380808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4242424242424242424242424242424228282828083637380808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7163424242424242424242424242627128282828083637380808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0060424242424242424242424242610028282828083637380808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0060424242424242424242424242610058592828083637380808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0060424242424242424242424242610068692828083637380808080808090808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0050717171717171717171717171510078792828083637380808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000028282828083637380808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000407070707070707070707070707048707070707070707070704100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000604848424848484848484848484248484848484848484848486100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000604848424842424242424242424242484242424842424242486100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000604848424842484848484248484848484842484848424848486100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000242500604242424242424842424242424842424242484248424242486100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000343500604848484848424842484848424842484842484248484842486100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000604842424248424842484242424842424842484248424242484800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4070707070707070707070707070410000484842484248424842484848484848424842424248424842487270707070410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6042424242424242424242424242727070734242484248424842424242484242424848484848424842484242424242610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6042424242424242424242424242424242424242484848424848424848484248424242424248424842424242424242610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6042424242424242424242424242627171634242484242424848424842424248484848484248484842486271717171510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6042424242424242424242424242610000484842484248484248424842484242424842484242424242484800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6042424242424242424242424242610000604242484248484248424842484848424842484848424848486100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6042424242424242424242424242610000604848484248424242424842484242424842424242424242426100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5071717171717171717171717171510000604842424248484848484842484848484848484848484848486100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000507171487171717171717171487171717171717171717171715100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100001d05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000900001a85014850038001480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a00001d84000e001b8400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

