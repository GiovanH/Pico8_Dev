pico-8 cartridge // http://www.pico-8.com
version 33
__lua__

-- title
-- author

-- todo add a choice menu to dialoger
-- pico-8 coroutines, seriously
-- TODO interactive debugger extended class support
-- todo replace dialog prefix with options table

-- global vars
local o_player
local debug = true  -- (stat(6) == 'debug')

-- game state flags
local speedshoes = false or debug
local godshoes = false

-- defined sprite flags
local flag_walkable = 0b1

local sfx_blip = 000
local sfx_teleport = 001
local sfx_creak = 002
local sfx_itemget = 003

-->8
-- utility

-- Focus stack
-- Use this to keep track of what
-- player input should be influencing.
-- Global because dialog/others are global.
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

-- any to string (dumptable)
function tostring(any)
 if (type(any)~="table") return tostr(any)
 if (any.__tostring) return any:__tostring()
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
-- > mrc({1, 2}, 3) = 1, 2, 3
function mrconcat(t, ...)
 for i, v in ipairs({...}) do
  add(t, v)
 end
 return unpack(t)
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
local vec_spritesize = vec(7,7)
local vec_spritesize = vec(8,8)
local vec_oneone = vec(1,1)
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
 -- product w/ vector
 -- temporarily de-zero-index
 local plusone = self+vec_oneone
 return vec((plusone.x * v.x), (plusone.y * v.y))-vec_oneone
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
 return self.x0 > other.x0 and self.x1 <= other.x1 and self.y0 > other.y0 and self.y1 <= other.y1
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
function bbox:maptiles(offset)
 if (offset == nil) offset = vec(0, 0)
 local ox, oy = offset:unpack()
 local tiles = {}
 -- Corner is outside edge, only check *within* [0, 1)
 for x = flr(self.x0/8), flr((self.x1-1)/8) do
  for y = flr(self.y0/8), flr((self.y1-1)/8) do
   -- dbg.print({x+ox, y+oy})
   local tpos = vec(x+ox, y+oy)
   local i = mget(tpos:unpack())
   add(tiles, {spr=i, flags=fget(i), pos=tpos})
  end
 end
 return tiles
end
-- actors
-- [1]pos: main position
-- draw: draw function (or nop)
-- z: draw order
-- z_is_y: auto set z to pos.y
-- ttl: self-destroy after n ticks if set
local actor = obj:extend{
 draw = nop,
 stage = nil,
 z = 0,
 ttl = nil,
 z_is_y = true,  -- domain: camera perspective
}
function actor:init(pos)
 self.pos = pos
end
function actor:update()
 if self.ttl then
  self.ttl -= 1
  if (self.ttl < 1) self:destroy()
 end
 if (self.z_is_y) self.z = self.pos.y
end
function actor:destroy() self._doomed = true end

-- mob
-- [1]pos: main position
-- [2]spr: sprite top-left corner
-- [3]size: size of sprite area to draw
-- shape_offset: vector from pos to shape
-- anchor: vector from pos to sprite
-- anim: table of frames to repeat instead of spr
-- frame_len: how long to show each frame in anim
-- flipx, flipy: sprite flip booleans
-- paltab: pallette replacement table (opt)
-- tcol: color # to mark as transparent
-- get_hitbox(v): hitbox is self.pos were v
local mob = actor:extend{
 size = vec_spritesize,
 anchor = vec(0,0),
 shape_offset = vec(0,0),
 anim = nil,
 frame_len = 1,
 flipx = false,
 flipy = false,
 tcol = nil,
 paltab = nil
}
function mob:init(pos, ...)
 self.spr, self.size = ...
 actor.init(self, pos)
 self.bsize = self.size
 self.shape = self:get_hitbox(self.pos)
end
function mob:update()
 actor.update(self)
 self.shape = self:get_hitbox(self.pos)
end
function mob:get_hitbox(pos)
 return bbox(
  pos + self.shape_offset,
  self.bsize
 )
end
function mob:drawdebug()
 if debug then
  -- picotool issue #92 :(
  local spx, spy = self.pos:__add(self.anchor):unpack()
  -- print bbox and anchor/origin
  local drawbox = self.shape:grow(vec_noneone)
  rect(mrconcat({drawbox:unpack()}, 2))
  line(spx, spy,
   mrconcat({self.pos:unpack()}, 4))
  pset(spx, spy, 10)
 end
end
function mob:draw()
 -- if self.spr or self.afnim then
 if (self.tcol != nil) paltt(self.tcol)
 if (self.paltab) pal(self.paltab)
 -- caching unpack saves tokens
 -- picotool issue #92 :(
 local spx, spy = self.pos:__add(self.anchor):unpack()
 local spw, sph = self.size:unpack()
 spw, sph = ceil(spw/8), ceil(sph/8)
 -- anim is a list of frames to loop
 -- frames are sprite ids
 if self.anim then
  local mclock = self.ttl or self.stage.mclock
  local findex = (flr(mclock/self.frame_len) % #self.anim) +1
  local frame = self.anim[findex]
  self._frame, self._findex = frame, findex

  -- printh(tostring({i=findex, s=self.name, a=self.anim, f=frame}))
  -- if type(frame) == "function"
  --  frame()
  -- else
  if (frame != false) spr(frame, spx, spy, spw, sph, self.flipx, self.flipy)
 else
  if (self.spr != nil and self.spr != false) spr(self.spr, spx, spy, spw, sph, self.flipx, self.flipy)
 end
 -- end
 self:drawdebug()
 if (self.paltab) pal()
end

-- particle
-- pos, vel, acc, ttl, col, z
local particle = actor:extend{}
function particle:init(pos, ...)
 actor.init(self, pos)
 self.vel, self.acc, self.ttl, self.col, self.z = ...
end
function particle:update()
 self.vel += self.acc
 self.pos += self.vel
 actor.update(self)
end
function particle:draw()
 if self.spr and self.size then
  spr(self.spr, mrconcat({self.pos:unpack()}, self.size:unpack()))
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
 self.camera = vec()  -- use for map offset
 self._tasks = {}
end
function stage:add(object)
 add(self.objects, object)
 -- if (object.stage) del(object.stage.objects, object)
 object.stage = self
end
function stage:_zsort()
 sort(self.objects, function(a) return a.z end)
end
function stage:update()
 -- Update clock
 self.mclock = (self.mclock + 1) % 27720
 -- Update tasks
 dbg.watch(self._tasks, "tasks")
 for handle, task in pairs(self._tasks) do
  task.ttl -= 1
  if task.ttl <= 0 then
   task.callback()
   self._tasks[handle] = nil
  end
 end
 -- Update objects
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
 for object in all(self.objects) do
  if (not object._doomed) object:draw()
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

function vec16(x, y) return vec(x, y)*16 end

-- Interactive debugger
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

  if mb then
   mbox = bbox.pack(dragx0, dragy0, mx, my)
  else
   dragx0, dragy0 = mx, my
   mbox = nil
  end
  line(dragx0,dragy0,dragx0+2,dragy0,4)

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

-- dialog box
-- based on work by rustybailey

dialoger = {
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
  add(self.queue, {
    message = message,
    opts = opts
   })

  if (#self.queue == 1) then
   focus:push('dialog')
   self:trigger(self.queue[1].message, self.queue[1].opts)
  end
 end,
 trigger = function(self, message, opts)
  self.opts = opts
  self.current_message = opts.prefix or ''
  self.messages_by_line = nil
  self.animation_loop = nil
  self.current_line_in_table = 1
  self.current_line_count = 1
  self.pause_dialog = false
  self:format_message(message)
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
    if (not btnp(5)) then
     if (i % 5 == 0) sfx(sfx_blip)
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

  if (self.opts.autoplay) then
   self.yieldn(30)
  end
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
    --> Resume animation if not paused
    coresume(self.animation_loop, self)
   else
    if btnp(4) then
     self.pause_dialog = false
     self.current_line_count = 1
     self.current_message = self.opts.prefix
    end
   end
  elseif (self.animation_loop and self.current_message) then
   if (self.opts.autoplay) self.current_message = self.opts.prefix or ''
   if (self.opts.callback) self.opts.callback()
   self.animation_loop = nil
  end

  --> Not animating/displaying, and queue not empty
  --> Finished displaying message, so pop it from queue and proceed.
  local anim_dead = (not self.animation_loop) or costatus(self.animation_loop) == 'dead'
  if anim_dead and #self.queue > 0 then
   self.shift(self.queue, 1)
   if (#self.queue > 0) then
    self:trigger(self.queue[1].message, self.queue[1].opts)
    coresume(self.animation_loop, self)
   else
    focus:pop('dialog')
   end
  end

  if (not self.opts.autoplay) then
   self.blinking_counter += 1
   if self.blinking_counter > 30 then self.blinking_counter = 0 end
  end
 end,
 draw = function(self)
  local screen_width = 128

  -- display message
  if (focus:is('dialog') and self.current_message) then
   rectfill(1,90,126,126,6)
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
     for box in all({
       bbox.pack(-12,-9,-8,-9),
       bbox.pack(-11,-8,-9,-8),
       bbox.pack(-10,-7,-10,-7)
      }) do
      line(box:shift(vec(screen_width)):unpack())
     end
    end
   end
  end
 end
}

local choicer = {
 pos=nil,
 padding=nil,
 char_size=nil,
 size=nil,
 mclock = 0,
 selected = 1,
 buttoncool = 0,
 prompt = function(self, choices, pos, exopts)
  assert(#choices > 0, 'choice table is empty or unindexed')
  exopts = exopts or {}
  self.choices = choices

  self.pos = pos or self.pos
  self.padding = exopts.padding or vec(3,4)
  self.char_size = exopts.char_size or vec(4,5)

  self.selected = exopts.selected or 1
  if (exopts.allowcancel) add(self.choices, {'cancel', nop})

  local width = 0
  for v in all(self.choices) do
   width = max(width, #v[1])
  end
  self.size = self.char_size:dotp(width, #self.choices) + (self.padding*2)
  focus:push('choice')
  self.buttoncool = 4
 end,
 draw = function(self)
  if (self.choices == nil) return
  local rbox = bbox(self.pos, self.size)
  color(0)
  rectfill(rbox:unpack())
  color(9)
  rect(rbox:unpack())
  local ppos = self.pos + self.padding
  color(7)
  for i,v in ipairs(self.choices) do
   -- local print_ = i == self.selected and prints or print
   print(v[1], ppos:__add(vec8(1,i-1)):unpack())
  end
  if (self.mclock % 16 < 8) color(5)
  print(">", ppos:__add(vec8(0,self.selected-1)):unpack())
 end,
 update = function(self)
  dbg.watch(self, 'choicer')
  self.mclock += 1
  self.mclock %= 27720
  if (focus:isnt('choice')) return
  if (self.buttoncool > 0) self.buttoncool -= 1;    return

  if (btnp(2)) self.selected -= 1; sfx(sfx_curmove)
  if (btnp(3)) self.selected += 1; sfx(sfx_curmove)
  self.selected = clamp(1, self.selected, #self.choices)
  if (btnp(4)) then
   focus:pop('choice')
   self.choices[self.selected][2]()
   self.choices = nil
  end
 end
}

-->8
-- game classes

function roommenu_init(rooms)
 local roommenu_room = 1
 local roommenu_slot = 4
 local irooms = {}
 local srooms = {}

 function set_roommenu(label)
  menuitem(roommenu_slot, '<- ' .. label .. ' ->', roommenu_cb)
 end
 function roommenu_cb(b)
  local left, right, select = b&1, b&10, b&100
  if (left>0) roommenu_room = ((roommenu_room-2) % #irooms) + 1
  if (right>0) roommenu_room = (roommenu_room % #irooms) + 1
  if (select>0) irooms[roommenu_room]()
  set_roommenu(srooms[roommenu_room])
 end

 local i = 0
 for k,v in pairs(rooms) do
  i += 1
  irooms[i] = v
  srooms[i] = k
 end
 set_roommenu(srooms[roommenu_room])
end

local t_sign = mob:extend{
 lines = nil,
 prefix = '',
 talkedto = 0
}
function t_sign:addline(text)
 if (self.lines == nil) self.lines = {}
 add(self.lines, text)
end
function t_sign:interact(player)
 for _, v in ipairs(self.lines or {'nO PROBLEM HERE.'}) do
  if type(v) == 'function' then
   dialoger:enqueue('', {autoplay=true,callback=v})
  else
   dialoger:enqueue(v, {prefix=self.prefix})
  end
 end
 self.talkedto += 1
end

local chest_data = {}
local t_chest = t_sign:extend{
 id = nil,
 obstructs=true,
 bsize = vec8(2,1),
 anchor = vec8(0,-1),
 getlines = {},
 emptylines = {}
}
function t_chest:init(id, pos, ispr, isize, itcol)
 t_sign:init(pos, 003, vec8(2,2))
 self.id = id
 self.data = chest_data[id] or {
  open=false
 }
 chest_data[id] = self.data
 self.ispr = ispr
 self.isize = isize
 self.itcol = itcol
end
function t_chest:interact(player)
 if not self.data.open then
  self.data['open'] = true
  sfx(sfx_itemget)
  self.ihold = 30
  self.ttl = 0x10 + self.ihold
  focus:push('anim')

  self.stage:schedule(18, function()
    focus:pop('anim')
    self.lines = self.getlines
    t_sign.interact(self, player)
   end)
 else
  self.lines = self.emptylines
  t_sign.interact(self, player)
 end
end
function t_chest:draw()
 local apos = self.pos:__add(self.anchor)
 local spx, spy = apos:unpack()
 if (self.ttl and self.ttl < 0x10) self.ttl = nil
 paltt(0)
 if self.data.open then
  spr(014, spx, spy, 2,1)
  if (self.ttl) then
   local age = self.ihold - (self.ttl-0x10)
   local offset = vec(4*(2-self.isize.x),-min(12, age)-8*self.isize.y+8)
   local sx, sy = apos:__add(offset):unpack()
   paltt(self.itcol)
   spr(self.ispr, sx, sy, self.isize:unpack())
   paltt(0)
  end
  spr(019, spx, spy+8, 2,1)
 else
  spr(003, spx, spy, 2,2)
 end
 mob.drawdebug(self)
end

local t_npc = t_sign:extend{
 facing = 'd',
 spr0 = 0,
 bsize = vec(16,8),
 obstructs = true,
 tcol = 15
}
function t_npc:init(...)
 t_sign:init(...)
 self.size = vec(16,24)
 self.spr0 = self.spr
end
function t_npc:interact(player)
 local facetable = {
  d='u',
  u='d',
  l='r',
  r='l'
 }
 self.facing = facetable[player.facing]
 self.ismoving = true
 t_sign.interact(self, player)
 dialoger:enqueue('',{callback=function() self.ismoving = false end})
end
function t_npc:draw()
 self.flipx = (self.facing == 'l')
 local facemap = {d=0, u=2, l=4, r=4}
 self.spr = self.spr0 + facemap[self.facing]
 if self.ismoving and self.stage.mclock % 8 < 4 then
  self.anchor = vec(0, -15)
 else
  self.anchor = vec(0, -16)
 end
 mob.draw(self)
end

local t_button = mob:extend{
 lines = nil,
 interact=nop
}

function newportal(pos, dest, deststate)
 o_portal = t_button(pos, 005, vec8(3,1))
 o_portal.anchor = vec(-12, 0)
 o_portal.shape_offset = vec(-12, 0)
 o_portal.tcol = 15
 function o_portal:draw()
  mob.draw(self)
  local apos = self.pos:__add(self.anchor)
  line(apos.x+6, apos.y+8, apos.x+17, apos.y+8, 1)
 end
 function o_portal:spark()
  local grav = vec(0, 0.01)
  for i = 0, 24 do
   local spread = 8
   local p_origin = o_player.pos + o_player.anchor
   local p_extent = p_origin + o_player.size
   local point_in_plr_spr = vec(
    rndr(p_origin.x, p_extent.x),
    rndr(p_origin.y, p_extent.y)
   )
   local p = particle(
    point_in_plr_spr + vec(0, 4),
    vec(rndr(-0.5, 0.5), rndr(-2.0, -1.7)),  --vel
    grav,  -- acc
    rndr(10, 15),  -- ttl
    7  -- col
   )
   function p:update()
    particle.update(self)
    self.z += (15 - self.ttl)*4
   end
   cur_room:add(p)
  end
 end
 function o_portal:interact(p)
  if p.cooldown > 0 then
   p.cooldown += 1
   printh('Not Portalling (cooldown)')
   return
  end
  if p.shape:overlaps(self.shape) then
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
     printh('portalled player to')
     printh(o_player.pos)
    end)
  end
 end
 return o_portal
end

function newtrig(pos, size, dest, deststate)
 o_trig = mob(pos, nil, size)
 function o_trig:hittrigger(p)
  if p.justtriggered then
   return
  end
  if deststate then
   dest(deststate.pos)
   o_player.facing = deststate.facing
  else
   dest()  -- let room decide position
  end
  o_player.cooldown = 1
  cur_room:update()  -- align camera
  printh('triggered player to')
  printh(o_player.pos)
 end
 return o_trig
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
 shape_offset = vec(-7, -7)
}
function t_player:init(pos)
 mob.init(self, pos, 64, vec(16,24))
 self.bsize = vec(13, 7)  -- a little smaller
end
function t_player:_moveif(step, facing)
 local npos = self.pos + step
 local nhbox = self:get_hitbox(npos)
 -- self.nhbox = nhbox
 local unobstructed = nhbox:within(self.stage.box_px)
 local tiles = nhbox:maptiles(self.stage.map_origin)
 dbg.watch(tiles, "foottiles")
 for i,tile in pairs(tiles) do
  if band(tile.flags, flag_walkable) == 0 then
   unobstructed = false
   break
  end
 end
 for _,obj in pairs(self.stage.objects) do
  if (nhbox:overlaps(obj.shape) and obj.obstructs) then
   unobstructed = false
   break
  end
 end
 if (facing) self.facing = facing
 if unobstructed or godshoes then
  self.pos = npos
  self.moved = true
 end
end
function t_player:move()
 -- player movement
 local vright = vec(1, 0)
 local vdown = vec(0, 1)
 local speed = 2

 if (speedshoes and btn(5)) speed = 3

 self.moved = false

 -- lrudox
 for x=1,speed do
  if (btn(0)) then
   self:_moveif(vec(-1, 0), 'l')
  elseif (btn(1)) then
   self:_moveif(vec(1, 0), 'r')
  end
  if (btn(2)) then
   self:_moveif(vec(0, -1), 'u')
  elseif (btn(3)) then
   self:_moveif(vec(0, 1), 'd')
  end
 end

 self.ismoving = self.moved
end
function t_player:tryinteract()
 -- passive triggers
 local stillintrigger = false
 for _,obj in pairs(self.stage.objects) do
  if (self.shape:overlaps(obj.shape) and obj.hittrigger) then
   stillintrigger = true
   obj:hittrigger(self)
   if (not self.justtriggered) then
    -- self just got destroyed so
    -- this doesn't do anything:
    self.justtriggered = true
   -- what actually matters is
   -- the init setting here
   end
   break
  end
 end
 self.justtriggered = stillintrigger
 -- try interact
 local facemap = {d=vec(0,1),u=vec(0,-1),l=vec(-1,0),r=vec(1,0)}
 if btnp(4) then
  self.ibox = bbox(
   self.pos + self.anchor - vec(0, -8) + facemap[self.facing]*8, vec_spritesize*2
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

 self.ismoving = false
 if self.cooldown > 0 then
  self.cooldown -= 1
 elseif focus:is('player') then
  self:move()
  self:tryinteract()
 end

 self.stage.camfocus = self.pos
 mob.update(self)
 self.shape = self:get_hitbox(self.pos)
end

function t_player:draw()
 self.flipx = (self.facing == 'l')
 local facemap = {d=0, u=2, l=4, r=4}
 self.spr = self.spr0 + facemap[self.facing]
 if self.ismoving and self.stage.mclock % 8 < 4 then
  self.anchor = vec(-8, -23)
 else
  self.anchor = vec(-8, -24)
 end
 mob.draw(self)
 if (debug and self.ibox) rect(mrconcat({self.ibox:unpack()}, 10))
 if (debug and self.nhbox) rect(mrconcat({self.nhbox:unpack()}, 10))
end

local room = stage:extend{
 camfocus = nil
}
function room:init(mx, my, mw, mh)
 self.map_origin = vec16(mx, my)
 self.box_map = bbox.fromxywh(0, 0, mw, mh)
 self.box_cells = self.box_map*16
 self.box_px = self.box_cells*8

 self.camfocus = self.box_px:center()
 stage.init(room)
end
function room:draw()
 local map_x, map_y = self.map_origin:unpack()
 local cell_w, cell_h = self.box_cells.size:unpack()
 local sx, sy = self.box_px.origin:unpack()

 cls()
 local cam = self.camfocus - vec(64, 64)
 local cx0, cy0, cx1, cy1 = self.box_px:unpack()
 cam.x = clamp(cx0, cam.x, cx1-128)
 cam.y = clamp(cy0, cam.y, cy1-128)

 -- offset by camera focus
 camera(cam:unpack())

 dbg.watch(cam,"cam")
 map(map_x, map_y, sx, sy, cell_w, cell_h)
 stage.draw(self)
 if debug and btn(5) then
  for object in all(self.objects) do
   if object.pos then
    local a,b = o_player.pos:unpack()
    local c,d = object.pos:unpack()
    line(a, b, c, d)
   end
  end
 end

 if debug and o_player then
  local ui_offset = cam - self.box_px.origin
  local mous = vec(stat(32), stat(33)) + ui_offset
  local mbox = dbg:mbox()
  if mbox and abs(mbox.size.x) + abs(mbox.size.y) > 0 then
   mbox = mbox:shift(ui_offset)
   fillp(0b0101101001011010)
   palt()
   color(0x48)
   rect(mbox:unpack())
   fillp()
   prints(mbox.origin, mbox.origin:unpack())
   prints(mbox.corner, mbox.corner:unpack())
   prints(mbox.size, min(mbox.origin.x, mous.x), max(mbox.corner.y, mous.y)-6)
  end
  -- rect(mrconcat({self.box_px:unpack()}, 10))
  camera()  -- ui to raw screen coords
  prints('plr  ' .. tostr(o_player.pos), 0, 0)
  prints('--8' .. tostr(o_player.pos:__div(8):floor()), 64, 0)
  prints('-16' .. tostr(o_player.pos:__div(16):floor()), 68, 8)
  line(67, 2, 67, 10)
  prints('room ' .. tostr(self.map_origin/16), 0, 8)
  prints('mous ' .. tostr(mous), 0, 16)
  prints('-- 8' .. tostr(mous:__div(8):floor()), 64, 16)
  prints('-16' .. tostr(mous:__div(16):floor()), 68, 24)
  line(67, 18, 67, 26)
  prints(focus:get(), 0, 64)

 end
 camera()

end
function room:add(object)
 object.pos += self.box_px.origin
 stage.add(self, object)
end

function drawgreat(self)
 local box = bbox((self.pos + vec(0,2)), vec(16, 12))
 rectfill(mrconcat({box:unpack()},2))
 fillp(0b1010101010101010)
 rectfill(mrconcat({box:unpack()},6))
 fillp()
 rect(mrconcat({box:unpack()},13))
 for _,x in pairs({box.x0, box.x1}) do
  for _,y in pairs({box.y0, box.y1}) do
   pset(x, y, 0)
  end
 end
end

-->8
--rooms

cur_room = nil

function room_complab()
 local center = vec16(8, 8.25)
 cur_room = room(0, 0, 2, 2)
 o_player = t_player(center)
 cur_room:add(o_player)

 o_computer1 = t_sign(vec16(1.5, 0.5), 010, vec8(2, 2))
 o_computer1:addline(
  "tWO WHITE LINES OF TEXT ARE BLOWN UP TO FILL THE ENTIRE SCREEN.")
 o_computer1:addline(
  "iT'S SO HUGE YOU CAN READ IT FROM ACROSS THE ROOM.")
 o_computer1:addline(
  "i WONDER WHAT IT SAYS.")
 cur_room:add(o_computer1)

 o_computer2 = t_sign(vec16(5.5, 0.5), 112, vec8(2, 1))
 o_computer2:addline(
  "lOOKS LIKE SOMEONE WAS PLANNING A FUNDRAISING CAMPAIGN FOR A VIDEO GAME.")
 o_computer2:addline("tOO BAD THEY'RE JUST A TROLL.")
 o_computer2.bsize = vec(15,15)
 cur_room:add(o_computer2)

 o_computer3 = t_sign(vec(156, 9), 116, vec_spritesize)
 o_computer3:addline("iT'S AN OFF-ICE COMPUTER.")
 o_computer3:addline("yOU CAN TELL BECAUSE SOMEONE IS RUNNING TROLL POWERPOINT. iT TICKED PAST THE LAST SLIDE THOUGH.")
 o_computer3.tcol = 15
 cur_room:add(o_computer3)

 o_computer4 = t_sign(vec(216, 8), 010, vec8(2, 1))
 o_computer4.paltab = {[6]=3}
 o_computer4:addline(
  "wOWIE! LOOKS LIKE SOMEBODY'S BEEN FLIRTING. iN \f3green.")
 -- o_computer4:addline(
 --  "dUE TO TECHNICAL LIMITATIONS, THE KEYBOARD HAS ALSO BEEN FLIRTING. iN \f3green.")
 cur_room:add(o_computer4)

 o_teapot = t_sign(vec16(15, 8), 050, vec8(2, 1))
 o_teapot.tcol = 012
 o_teapot:addline(
  "iT'S A CAT-THEMED TEAPOT. " ..
  "iT SEEMS OUT OF PLACE IN THIS DISTINCTLY UN-CAT-THEMED ROOM.")
 o_teapot:addline(
  "tHE SUGAR IS ARRANGED SO AS TO BE COPYRIGHTABLE INTELLECTUAL PROPERTY.")
 cur_room:add(o_teapot)

 o_karkat = t_npc(vec(64, 64), 070)
 o_karkat.prefix = "\f5"
 function o_karkat:interact(player)
  choicer:prompt({
    {"epilogues", function()
      self.lines = {
       "the fuck are you talking about? we have bigger things to deal with right now than ill-advised " ..
       "movie sequels or whatever it is you're distracted with."
      }
      t_npc.interact(self, player) end},
    {"dave", function()
      self.lines = {
       "i have had literally one interaction with the guy and it ended up being all about vriska.",
       "because of course literally fucking everything has to be about vriska if you're unfortunate enough to get stuck in the same universe as her. or apparently even if you're not.",
       "i'd joke about offing yourself being the only way to escape her absurd machivellian horseshit but at this point she's probably fucked up death too. also, [todo] is goddamn dead and i'm not going to chose this particular moment to startlisting off all the cool perks of getting murdered."
      }
      t_npc.interact(self, player) end}
   })
 end
 cur_room:add(o_karkat)

 o_cards = t_sign(vec(184, 194), 034, vec(16, 8))
 o_cards.tcol = 0
 o_cards:addline("tHESE CARDS REALLY GET LOST IN THE FLOOR. SOMEONE MIGHT SLIP AND GET HURT.")
 o_cards:addline("tHEN AGAIN THAT'S PROBABLY HOW THE GAME WOULD HAVE ENDED ANYWAY.")
 o_cards:addline("sOMEONE HAS TRIED TO PLAY SOLITAIRE WITH THEM. yOU FEEL SAD.")
 cur_room:add(o_cards)

 o_plush = t_sign(vec(142, 203), 032, vec_spritesize*2)
 o_plush.tcol = 0
 o_plush:addline("todo gio pls add flavor text for plush in complab")
 cur_room:add(o_plush)

 o_corner = t_sign(vec16(0,11), false, vec16(5,5))
 o_corner:addline("tHIS CORNER OF THE ROOM FEELS STRANGELY EMPTY AND UNOCCUPIED.")
 cur_room:add(o_corner)

 cur_room:add(newportal(center, room_t))

end

function room_t(v)
 cur_room = room(2, 0, 1, 1)
 o_player = t_player(v or vec8(3, 12))
 cur_room:add(o_player)

 o_chest = t_chest('t1',vec8(5, 5), 142, vec(2,2), 15)
 o_chest.getlines = {"todo scalemate lines"}
 o_chest.emptylines = {}
 cur_room:add(o_chest)

 o_terezi = t_npc(vec8(9, 5), 128)
 o_terezi.prefix = "\f3"
 o_terezi:addline("todo terezi dialog")
 -- function o_terezi:interact(player)
 --  choicer:prompt({
 --    {"epilogues", function()
 --      self.lines = {
 --       "the fuck are you talking about? we have bigger things to deal with right now than ill-advised " ..
 --       "movie sequels or whatever it is you're distracted with."
 --      }
 --      t_npc.interact(self, player) end},
 --    {"dave", function()
 --      self.lines = {
 --       "i have had literally one interaction with the guy and it ended up being all about vriska.",
 --       "because of course literally fucking everything has to be about vriska if you're unfortunate enough to get stuck in the same universe as her. or apparently even if you're not.",
 --       "i'd joke about offing yourself being the only way to escape her absurd machivellian horseshit but at this point she's probably fucked up death too. also, [todo] is goddamn dead and i'm not going to chose this particular moment to startlisting off all the cool perks of getting murdered."
 --      }
 --      t_npc.interact(self, player) end}
 --   })
 -- end
 cur_room:add(o_terezi)

 cur_room:add(newportal(vec(24, 90), room_complab))

 cur_room:add(newportal(vec(104, 90), room_lab))

end

function room_lab(v)
 cur_room = room(6, 0, 1, 2)
 o_player = t_player(v or vec(64, 90))
 o_player.facing = 'r'
 cur_room:add(o_player)

 for y = 0, 3 do
  for x = 0, 1 do
   if (y == 2 and x == 0) goto continue
   o_cap = mob(vec((x*3+2), (y*3+4))*16, 076, vec(16, 24))
   npcify(o_cap)
   o_cap.tcol = 10
   cur_room:add(o_cap)
   ::continue::
  end
 end

 o_switch_dial = t_sign(vec8(7.5, 2.5), 125, vec8(1,1))
 function o_switch_dial:interact()
  function promptswitch()
    choicer:prompt({
      {"flip it", function()
        state_flags['frog_flipped'] = not state_flags['frog_flipped']
        self.flipx = state_flags.frog_flipped
        sfx(sfx_creak)
       end},
      {"do not", function()
        dialoger:enqueue("it's set correctly, you think.")
       end}
     })
   end
   dialoger:enqueue("there is a switch here with a frog. flip it?", {callback=promptswitch}
   )
 end
 cur_room:add(o_switch_dial)
 o_switch_frog = mob(vec8(7, 1.5), 126, vec8(2,1))
 cur_room:add(o_switch_frog)

 o_chest = t_chest('science1',vec16(2, 10), 076, vec(2,3), 10)
 o_chest.getlines = {
  "it's one of those science tube things.  a tank, for cloning, or monsters, or ghosts. or whatver science comes up, really.",
  "just about big enough to squeeze into, except there's no door hole."}

 o_chest.emptylines = {"someone has carved a hole into the floor to give this chest space for an extra-tall item."}
 cur_room:add(o_chest)

 cur_room:add(newportal(vec(64, 84), room_t, {
    facing='d',
    pos=vec(104, 91)
   }))

 cur_room:add(newtrig(vec(124, 192), vec8(.5, 4), room_hallway))

end

function room_hallway(v)
 cur_room = room(2, 1, 1, 1)
 o_player = t_player(v or vec(14, 72))
 cur_room:add(o_player)

 greydoor = t_sign(vec8(7, 4), 030, vec8(2, 3))
 function greydoor:interact(player)
  if self.talkedto < 1 then
   self.lines = {
    "iT'S LOCKED. yOU CAN'T OPEN IT. oR, IT'S NOT LOCKED, AND YOU COULD OPEN THE DOOR. oR MAYBE SOMETHING ELSE. iS IT EVEN A DOOR?",
    "yOU DON'T OPEN IT."
   }
  else
   self.lines = {"tHE DOOR REEKS OF INDETERMINISM. "}
  end
  t_sign.interact(self, player)
 end
 cur_room:add(greydoor)

 cur_room:add(newtrig(vec(0, 56), vec8(.5, 4), room_lab, {
    facing='l',
    pos=vec(115, 208)
   }))

 cur_room:add(newtrig(vec8(15.5, 7), vec8(.5, 4), room_stair))

end

function room_stair(v)
 cur_room = room(7, 0, 1, 2)
 o_player = t_player(v or vec(18, 52))
 o_player.facing = 'r'
 cur_room:add(o_player)

 cur_room:add(newtrig(vec(0, 32), vec(4, 32), room_hallway, {
    facing='l',
    pos=vec8(13, 9)
   }))

 o_plush = t_sign(vec(80, 141), 032, vec_spritesize*2)
 o_plush.tcol = 0
 o_plush:addline("hE MUST BE LOST.")
 o_plush:addline("fORTUNATELY HIS OWNER CAN SAFELY WALK DOWN HERE AND RETRIEVE HIM.")
 cur_room:add(o_plush)

 o_chest = t_chest('stair1',vec16(5, 2), 003, vec(2,2))
 o_chest.getlines = {"yOU GOT A CHEST! tHE PERFECT CONTAINER TO STORE THINGS IN.","sINCE ONLY PROTAGONISTS CAN OPEN THEM, IT'S VERY SECURE."}
 o_chest.emptylines = {"iT WAS ONLY BIG ENOUGH TO HOLD ONE CHEST."}
 cur_room:add(o_chest)

 o_stair_rail = mob(vec(65, 80), nil, vec(15, 1))
 o_stair_rail.obstructs = true
 cur_room:add(o_stair_rail)

 o_stair = mob(vec(54, 80), nil, vec(18, 44))
 function o_stair:hittrigger(player)
  local speed = 2
  for x=1,speed do
   if (btn(0)) then
    player:_moveif(vec(0,2))
   elseif (btn(1)) then
    player:_moveif(vec(0,-2))
   end
  end
 end
 cur_room:add(o_stair)

 o_gio = t_npc(vec(33, 206), 064)
 o_gio.paltab = {[7]=8, [0]=8, [14]=0, [13]=0}
 -- o_gio.addline(function() o_gio.prefix = '' o_gio.ismoving = false end)
 o_gio:addline("oH. tHERE IS A MAN HERE.")
 o_gio:addline(function()
   if speedshoes then
    dialoger:enqueue("yOU DO NOT GIVE HIM ANYTHING.")
   else
    dialoger:enqueue("hE GAVE YOU AN ❎ BUTTON. iN ADDITION TO THE REST.")
    speedshoes = true
    sfx(000)
   end
  end)
 function o_gio:update()
  self.ismoving = (#dialoger.queue > 0)
  t_npc.update(self)
 end
 cur_room:add(o_gio)

 o_vue = t_sign(vec(72, 184), 122, vec8(2,1))
 o_vue.tcol = 14
 cur_room:add(o_vue)

 o_great = t_button(vec16(1, 6), false, vec_spritesize*2)
 o_great.interact = function()
  room_turbine(vec(24, 112))
 end
 o_great.draw = drawgreat
 cur_room:add(o_great)

 o_horsehole = t_sign(vec16(6, 7), false, vec_spritesize:dotp(1, 2))
 o_horsehole:addline("tHROUGH A SMALL HOLE IN THE WALL YOU SEE A PASSAGE THAT LEADS DEEP INTO THE [???]. IT'S TOO SMALL FOR YOU TO ENTER.")
 o_horsehole:addline("yOU HEAR A DISTANT WINNEY.")
 cur_room:add(o_horsehole)

end

function room_turbine(v)
 cur_room = room(3, 0, 2,1)
 o_player = t_player(v or vec(24, 112))
 cur_room:add(o_player)

 o_player.bsize = vec(14, 14)  -- feel cramped
 o_player.shape_offset = vec(-7, -14)

 o_great = t_button(vec16(12, 1), false, vec_spritesize*2)
 o_great.draw = drawgreat
 cur_room:add(o_great)


 o_hole = mob(vec16(9, 3), 008, vec16(3,1))
 function o_hole:update()
  self.deobstructs = (state_flags['holefilled'])
  mob.update(self)
 end
 function o_hole:interact(player)
  local hastileitem = chest_data['tilechest'] and chest_data['tilechest'].open
  if hastileitem and not state_flags['holefilled'] then
   function promptbridge()
    choicer:prompt({
      {"yes", function()
        state_flags['holefilled'] = true
        sfx(sfx_itemget)
       end},
      {"no", function()
        dialoger:enqueue("you never know when you might need it.")
       end}
     })
   end
   dialoger:enqueue("make a bridge with the tile?", {callback=promptbridge}
   )
  else
   if state_flags['holefilled'] then
    dialoger:enqueue("there was a hole here. it's gone now.")
   else
    dialoger:enqueue("there is a hole here.")
   end
  end
 end
 o_hole.size = vec16(1)
 o_hole.anchor = vec16(1,0)
 function o_hole:draw()
  if state_flags['holefilled'] then mob.draw(self)
  else mob.drawdebug(self) end

 end
 cur_room:add(o_hole)

 for fg in all({
   {4, 6, 10},
   {14, 8, 12},
   {26, 6, 6},
   {26, 12, 4}
  }) do
  o_fg_rail = mob(vec8(fg[1], fg[2]), 117, vec8(fg[3], 1))
  o_fg_rail.anchor = vec8(0,-1)
  function o_fg_rail:draw()
   local width = self.shape.w
   for x = 1, width/8 do
    paltt(0)
    spr(self.spr, self.pos:__add(self.anchor):__add(vec8(x-1,0)):unpack())
   end
   mob.drawdebug(self)
  end
  cur_room:add(o_fg_rail)
 end

 o_andrew = t_sign(vec8(27, 11), 140, vec8(2,3))
 npcify(o_andrew)
 o_andrew.tcol = 14
 cur_room:add(o_andrew)

 cur_room:add(newtrig(vec8(2, 15.5), vec8(2, .5), room_stair, {
    facing='d',
    pos=vec(24, 121)
   }))
 cur_room:add(newtrig(vec8(14, 0), vec8(2, .5), room_ocean))
 cur_room:add(newtrig(vec8(31.5,4), vec8(.5, 2), room_roof))
 cur_room:update()
end

function room_roof(v)
 cur_room = room(5, 0, 1, 1)
 o_player = t_player(v or vec(16, 98))
 cur_room:add(o_player)

 o_stair_rail = mob(vec(78, 48), nil, vec(2, 64))
 o_stair_rail.obstructs = true
 cur_room:add(o_stair_rail)

 o_pogo = t_sign(vec8(11, 9), 078, vec_spritesize*2)
 o_pogo.bsize = vec_spritesize
 o_pogo.obstructs = true
 o_pogo.tcol = 3
 o_pogo:addline("thanks to the miracle of digital technology, the pogo ride has been effortlessly preserved to the exact specifications of the designer, a feat unheard of in any previous era.")
 o_pogo:addline("but it doesn't work anymore.")
 o_pogo:addline(function()
   o_pogo.draw = mob.draw
   o_pogo.lines = {"it seems someone has replaced the ride with a still photo."}
  end)

 function o_pogo:draw()
  if self.stage.mclock % 32 < 16 then
   self.anchor = vec(-4, -8)
  else
   self.anchor = vec(-4, -7)
  end
  mob.draw(self)
 end
 cur_room:add(o_pogo)

 o_lamppost = t_sign(vec8(14,6), 078, vec_spritesize)
 o_lamppost.obstructs = true
 o_lamppost.tcol = 14
 o_lamppost:addline(function() sfx(sfx_itemget) end)
 o_lamppost:addline("it's the \falamppost\f7.")
 o_lamppost:addline("quit the game?")
 o_lamppost:addline(function()
  choicer:prompt({
    {"yes", function()
      dialoger:enqueue("i mean, nobody's stopping you.") end},
    {"no", function()
      dialoger:enqueue("ok cool") end},
   })
  end)
 o_lamppost:addline(function() poke(0x5f80, true) end)

 function o_lamppost:draw()
  paltt(self.tcol)
  spr(023, self.pos:unpack())
  spr(022, self.pos:__sub(vec8(0,4)):unpack())
  local line_
  line_ = bbox(self.pos + vec(3, -25), vec(0, 25))
  line(mrconcat({line_:unpack()}, 0))
  line(mrconcat({line_:shift(vec(1, 0)):unpack()}, 5))

  if (self.stage.mclock % 16 < 4 and rndi(6) == 0) self.flicker = true
  if self.flicker then
   pset(self.pos.x+3, self.pos.y-28, 9)
   if (rndi(2) != 0) self.flicker = false
  end
  mob.drawdebug(self)
 end
 cur_room:add(o_lamppost)

 cur_room:add(newtrig(vec8(1, 11), vec8(.5, 2), room_turbine, {
    facing='l',
    pos=vec8(30,6)
   }))
end

function room_ocean(v)
 cur_room = room(5, 1, 1, 1)
 o_player = t_player(v or vec8(13, 7))
 -- cur_room.paltab = {[5]=1}
 cur_room:add(o_player)

 o_great = t_button(vec16(6, 1), false, vec_spritesize*2)
 
 o_great.interact = function()
  room_turbine(vec(119, 26))
 end
 o_great.draw = drawgreat
 cur_room:add(o_great)

 o_stair = t_button(vec16(1, 4), false, vec_spritesize*2)
 o_stair.interact = function()
  room_chess()
 end
 o_stair.obstructs = true
 cur_room:add(o_stair)

 o_decorator = actor(vec())
 function o_decorator:draw()
  rect(8, 24, 119, 87,4)
 end
 cur_room:add(o_decorator)
 sfx(sfx_creak)

end

function prettify_map()
 function fortile(fn)
  for x = 0,128 do
   for y=0,64 do
    fn(x,y)
   end
  end
 end
 fortile(function(x,y)
   local state=mget(x, y)
   local tiletable = {
    [036]= 052,
    [002]= 018
   }
   if (tiletable[state]) mset(x,y,tiletable[state])

  end)
end

function room_chess(v)
 cur_room = room(3, 1, 2, 1)
 o_player = t_player(v or vec8(30, 10))
 cur_room:add(o_player)

 function drawpillar(self)
  local spx, spy = self.pos:__add(self.anchor):unpack()
  paltt(0)
  spr(self.spr, spx, spy)
  for oy = -4,-1 do
  spr(self.spr-1, spx, spy+(8*oy))
  end
  spr(self.spr-2, spx, spy+(8*-5))
  mob.drawdebug(self)

 end

 for x in all({3, 11, 20, 28}) do 
  o_pillar = mob(vec8(x,14), 120, vec_spritesize)
  o_pillar.draw = drawpillar
  o_pillar.obstructs = true
  cur_room:add(o_pillar)
 end

 o_stalemate_w = t_sign(vec8(7, 12), 066, vec8(2,3))
 npcify(o_stalemate_w)
 o_stalemate_w:addline("it's a north-going prospitian.")
 o_stalemate_w:addline("it looks like they're stuck.")
 cur_room:add(o_stalemate_w)

 o_stalemate_b = t_sign(vec8(7, 11), 064, vec8(2,3))
 npcify(o_stalemate_b)
 o_stalemate_b.paltab={[14]=0, [7]=0, [0]=7}
 o_stalemate_b:addline("it's a south-going dersite.")
 o_stalemate_b:addline("it looks like they're stuck.")
 function o_stalemate_b:interact(p)
  if (p.pos.y > 96) return false
  t_sign.interact(self)
 end
 cur_room:add(o_stalemate_b)

 o_promoguy = t_npc(vec8(12.5, 7), 064)
 o_promoguy.step = vec(1, 0)
 o_promoguy.facing = 'r'
 o_promoguy.paltab={[14]=0, [7]=0, [0]=7}
 function o_promoguy:update()
  self.ismoving = not self.istalking
  if not self.istalking then
   if (self.pos.x > 140) self.step = vec(-1, 0); self.facing = 'l'
   if (self.pos.x < 100) self.step = vec(1, 0); self.facing = 'r'
   t_player._moveif(self, self.step, self.facing)
  end
  mob.update(self)
 end
 function o_promoguy:interact(p)
  local wasfacing = self.facing
  t_npc.interact(self, p)
  dialoger:enqueue('',{callback=function() self.facing = wasfacing end})
 end
 o_promoguy:addline("i have to keep at it if i want to get that promotion.")
 o_promoguy:addline("...what do you mean i'm going the wrong way?")
 cur_room:add(o_promoguy)

 o_palt_portal = newportal(vec8(2, 9), room_complab)
 o_palt_portal.paltab = {[1]=7,[2]=10}
 cur_room:add(o_palt_portal)

 o_chest_tile = t_chest('tilechest',vec8(6, 5), 008, vec(2,2))
 o_chest_tile.paltab = {[5]=7,[1]=6}
 o_chest_tile.getlines = {
  "you found a floor tile!",
  "you are filled with the relieving fealing of linear progression."
 }
 o_chest_tile.emptylines = {}
 cur_room:add(o_chest_tile)

 o_chest_chaos = t_chest('tilechest',vec8(24, 13), 124, vec_oneone)
 o_chest_chaos.getlines = {
  "you found a chaos emerald! can you find them all?",
  "(you have already found them all)"
 }
 o_chest_chaos.emptylines = {
  "weird, there's room in here for like six or eight."
 }
 cur_room:add(o_chest_chaos)

 o_jade = t_npc(vec8(23, 6), 192)
 o_jade.prefix = "\#d\fb"
 o_jade:addline("todo jade dialog")
 -- function o_jade:interact(player)
 --  choicer:prompt({
 --    {"epilogues", function()
 --      self.lines = {
 --       "the fuck are you talking about? we have bigger things to deal with right now than ill-advised " ..
 --       "movie sequels or whatever it is you're distracted with."
 --      }
 --      t_npc.interact(self, player) end},
 --    {"dave", function()
 --      self.lines = {
 --       "i have had literally one interaction with the guy and it ended up being all about vriska.",
 --       "because of course literally fucking everything has to be about vriska if you're unfortunate enough to get stuck in the same universe as her. or apparently even if you're not.",
 --       "i'd joke about offing yourself being the only way to escape her absurd machivellian horseshit but at this point she's probably fucked up death too. also, [todo] is goddamn dead and i'm not going to chose this particular moment to startlisting off all the cool perks of getting murdered."
 --      }
 --      t_npc.interact(self, player) end}
 --   })
 -- end
 cur_room:add(o_jade)

 cur_room:add(newtrig(vec8(31.5, 8), vec8(.5, 2), room_ocean, {
    facing='r',
    pos=vec(39,76)
   }))
 cur_room:update()

end
-->8
--pico-8 builtins

function _init()
 roommenu_init({
   complab=room_complab,
   cross=room_t,
   lab=room_lab,
   hall=room_hallway,
   stair=room_stair,
   vent=room_turbine,
   roof=room_roof,
   chess=room_chess
  })
 if debug then
  menuitem(5,'toggle debug',function() debug = not debug end)

  menuitem(1,'progress',function()
     state_flags['holefilled'] = true
   end)
 end

 prettify_map()
 room_lab()
 focus:push('player')
end

function _update()
 cur_room:update()
 dialoger:update()
 choicer:update()

 dbg.watch(dialoger,"dialoger")
 dbg.watch(cur_room,"cur_room")
 dbg.watch(o_player,"player")
 dbg.watch(focus,"focus")
 dbg.watch(cur_room.objects,"objects")
end

function _draw()

 pal()
 cur_room:draw()
 dialoger:draw()
 choicer:draw()
 if (debug) dbg.draw()
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
0011111133333333666666669a555199a555519a11111111eee01eeeeee05eee055dddddddd555d601555555555555105111111515151515dddddddddddddddd
0011111133333333666666669a5551115555519a11111111e000001eeee05eee0d55dddddddd555d01111111111111105111111515151515d66666666666666d
2255ddff3b333333666666669a5555555555519a11111d1100000001ee0000ee0dd55dddddddd55d50000000000000005111111515151515d6dddddddddddd6d
2255ddff33b3b333666666669a5555555555519a1111cd11e0deee0eee0000ee0ddd555ddddddddd11101115551101105111111515151515d6d6666666666d6d
2299aa3333333333666666669a5555555555519a11cdd1d1e0da9e0ee000050e05ddd55ddddddddd10000000000000005111111515151515d6d6666666666d6d
2299aa333333333b666666669a5555555555519addd11111e0daae0eee0000ee055ddd55dddddddd06565566666565605111111515151515d6d6666666666d6d
3355eeee3333b3b3666666669a5555555555519a11111111ee0000eee000050e0d55ddd55ddddddd01111155555111105111111515151515d6d6666666666d6d
3355eeee33333333666666669a5555555555519a11111111eee05eeee000050e0dd55ddddddddd6510000000000000005111111515151515d6d6666666666d6d
0000044444440000000001dddd000000eeeeeeee666666666666666677777777000000000000000000000000000000005111111515151515d6d6666666666d6d
0000488887884000000001d8dd000000e222222e6ccccccc666666667777777755555555555555555555555000077000511111151515151dd6d6666666666d6d
000048484848890000d001dddd0ddd00e222002e6ccccccc6666666677777777511111111111111111111115000ff00051111115151515ddd6d6666666466d6d
000048898777aa400ddd0111111d8d50e222222e6ccccccc666666667777777751111111111111111111111500f28f00d555555d15151dddd6d6666664646d6d
0004848878787aa9dd8dd000001ddd55e222222e6ccccccc66666666777777775111111111111111111111150f2888f05ddd55dd1515ddddd6d666666d4d6d6d
0048889878477aa41ddddd00001ddd50e200222e6ccccccc66666666777777775111111111111111111111150f9aaaf055ddd55d151dddddd6d666666d6d6d6d
4484848487887a7a01ddd100001ddd00e222222e6ccccccc66666666777777775111111111111111111111150f2888f00000000015ddddddd6d6666666d66d6d
48889888aa77aaa4001d100000115000eeeeeeee6ccccccc66666666777777775111111111111111111111150f7877f0000000001dddddddd6d6666666666d6d
4484848aaaaaaaa9cccccccccccccccc000000005555555566666666777776670550000000000000000005600f7788700cccc000ddddddddd6d6666666666d6d
004888aaaaaaaaa4c77cccccc00ccccc000000005555555577677767777776670d51111111111111111115d006288af0c9beac00ddddddddd6d6666666666d6d
00048aaaaaaaafa9c77cccc00000cccc000000005555555577677767777776670d51111111111111111115d00f2aa8f0cbebbc00ddddddddd6d6666666666d6d
00009aaaaaaf4a4077cc0c0fffff0c0c000000005555555577677767777776670dd555555555555555555dd00f2888f0cebbec00ddddddddd6d6666666666d6d
000004aaaaa9000077cc00f0f0fff0c00000000055555555776777677777766705ddd5555ddd55ddddddddd00f2228f0cabe9c20ddddddddd6d6666666666d6d
0000009aaf400000c77cc0f000fff0c000000000555555557767776777777667055ddd5555ddd55dddddddd0022002200cccc889ddddddddd6d6666666666d6d
00000004a9000000c77ccc0f0fff0c0c000000005555555566666666777776670d5dddd555ddddddddddd6600000000000002884dddddddd66d6666666666d66
0000000a4a000000ccccccc00000cccc0000000055555555777777777777766700000000000000000000000000000000000002e0dddddddddddddddddddddddd
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
fffff000000fffffffff10000001fffffffff10000ffffffffff12003121ffffffff12000081fffffffff180011fffffeeee0799470eeeee0000000000000000
fffff011110fffffffff10111101fffffffff11111ffffffffff12887821ffffffff12282881fffffffff182221fffffeeee0777770eeeee0000000000000000
fffff000000fffffffff10000001fffffffff10000ffffffffff12888281ffffffff12288881fffffffff188871fffffeeee0d55550eeeee0000000000000000
fffff000000fffffffff10000001ffffffffff0001ffffffffff12882221ffffffff12228881ffffffff1888211fffffeeee0ddddd0eeeee0000000000000000
fff2488224882ffffff4441111488fffffffff88842ffffffff0555110555ffffff0001281055ffffff182215001ffffee01dd0001dd0eee0000000000000000
fff2222222222ffffff2222112222fffffffff22222ffffffff1111111111ffffff1111111111ffffff111111111ffffee00000e00000eee0000000000000000
06666660511111155111111500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
50000006511111155111111500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5d666665511111111111111500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
50cccc06511111111111111500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5cccccc6511111111111111500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5cccccc6511111111111111500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dd1111d6511111111111111500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0dddddd0055511111111555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
fffff11111111ffffff1111111ffffffffffff1111111fffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
fff111111111fffffff111111111ffffffff11111111ffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
fff111111111fffffff1111111111ffffff111111111ffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
1111111111111fffff1111111111111ff111111111111fffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
1111111111111fffff1111111111111ff111111111111fffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
111111111111111f111111111111111ff11111111111111fffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
111177711771111f111111111111111ff11111117771111fffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
11ddddd1ddddd11f111111111111111ff111111ddddd111fffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
11d777d7d777d1fff11111111111111ff111171d777d11ffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
f1d711d7d117dfffff111111111111fff111177d711d1fffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
ffddddd7dddddffffff1111111111fffff11177ddddd1fffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
ff1777777771fffffff1111111111ffffff1777777771fffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
fff177d6771fffffffff11111111fffffff117777d71ffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
ffff177771fffffffffff111111ffffffffff177771fffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
fff10111101fffffffff10111101fffffffff11111ffffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
fff100dd001fffffffff10000001ffffffff1000001fffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
fff000000001fffffff1000000001fffffff1000001fffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
fff000000001fffffff1000000001fffffff1000001fffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
fff000000001fffffff1000000001fffffff1000001fffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
fff000000001fffffff1000000001fffffff1000001fffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
fff001111001fffffff1000000001fffffff1000c1ffffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
fff011111100fffffff0011111100ffffffff11100ffffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
ff04890148880ffffff4441111448ffffffff044880fffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
ff00000f00000ffffff0000000000ffffffff000000fffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffff00000000000000000000000000000000
__gff__
0000010000000000010100000001000000010100000000000101000000010000000000000100000100000000000100000000000001000001000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000101010101010101010001010100000000000000000000000000000000000000007575757575757575000000000000000000000000000000000000080900000000000000000000000000000000000035353535353535351111111111110000000000000000000000000000000000000000000000000000000000000000
0000000a0b0000000000000a0b0000000000000a0b0000000000000a0b0000000000000035353535353535350000000000000000000000000000000000001819000000000000000000000000000000000000353535353535353511111111111100003d3d3d3d3d3d3d3d3d3d3d3d000000000000000000000000000000000000
0928291a1b2929292929291a1b2929292929291a1b2929292929291a1b292a080000000072733535353572730000000000000000000000000000000001010809000000000000000001010000000000000000262626262626262611111111111100003d3d3d3d3d3d3d3d3d3d3d3d000000000809080908090809080908090000
1938393939393939393939393939393939393939393939393939393939393a180000000008090809080908090000000000007575757575757575757575751819000000000000000075757575757575750000262525262626262611111111111100003d3d3d3d3d3d3d3d3d3d3d3d000000001819181918191819181918190000
0c0c090809080908090809080908090809080908090809080908090809080c0c000000001819181918191819000000000000080908090809080908090809080900000000000000000809080908090809000026252526262626261111111111110101080908090809080908090809000008090809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c000000000809080908090809000000000000181918191819181918191819181975757575757575751819181918191819000026262626262626261111111111110101181918191819181918191819000018191819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c757575751819181918191819757575750000080900000000000000000000080908090809000008090809000000000000000027272727272727371111111111110101080908090809080908090809000008090809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c353535350809080908090809353535350000181900000000000000000000181918191819000018191819000000000000000027272727272727371111111111110101181918191819181918191819000018191819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c727335351819181918191819353572730000080900000000000000000000000000000000000000000000000000000000000027272727272727371111111111110000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c080908090809080908090809080908090000181900000000000000000000000000000000000000000000000000000000000027272727272727371111111111110000181918191819181918191819000000001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c18191819181918191819181918191819000008090000000000000000000000000000000000000000000008090809000000002727272727272737111111111111000008090809080908090809080900000000010101010101240d080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c080908090809080908090809080908090000181900000000000000000000000000000000000000000000181918190000242727272727272727371111111111110000181918191819181918191819000000000101010101240d1d181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c1819181918191819181918191819181900000809000000000000000000000000000000000000000000000000000000002427272727272727273711111111111100000809080908090809080908090100000001010101240d1d2d3d3d3d3d0100
1c1c191819181918191819181918191819181918191819181918191819181c1c08090809080908090809080908090809000018190000000000000000000000000000000000000000000000000000000024243636363636363636111111111111000018191819181918191819181900000000010101240d1d2d3d3d3d3d3d0000
1c1c090809080908090809080908090809080908090809080908090809081c1c18191819181918191819181918191819000008090000000000000000000000000000000000000000000000000000000024242626262626262626111111111111000008090809080908090809080900000000080908091d2d3d3d3d3d013d0000
1c1c191819181918191819181918191819181918191819181918191819181c1c00000000000000000000000000000000000018190000000000000000000000000000000000000000000000000000000024240202020202020202111111111111000018191819181918191819181900000000181918192d3d72733d3d013d0000
1c1c090809080908090809080908090809080908090809080908090809081c1c000000000000000000000000000000000000007600000000000000760000000000000000760000000000000076000000151515151515151515151515151515150000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c0000000000000000000000000000000000000077000000000000007700000000000000007700000000000000770000001515151515151515151515153d3d15150000181918191819181918191819000000001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c7575757575757575757575757575757500000077000000000000007700000000000000007700000000000000770000001515151515151515151515151e1f15150000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c3535353535353535353535353535353500000077000000000000007700000000000000007700000000000000770000001512121212121212121212123e3f12150000181918191819181918191819000000001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c353535353535351e1f353535353535350000007700000000000000770000000000000000770000000000000077000000151212121212121212121212121212150000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c353535353535352e2f353535353535357979797879797979797979787979797979797979787979797979797978797900151212121212121212121212121212150000181918191819181918191819000000001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c353535353535353e3f353535353535357979797979797979797979791234123412341234797979797979797979797900151212121212121212121212121212150000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c08090809080908090809080908090809797979797979797979797979341234123412341279797979797979797979790015121212121212121212121212121215000018191819181918191819181900000000181918191819280a0b2a18190000
1c1c090809080908090809080908090809080908090809080908090809081c1c18191819181918191819181918191819797979797979797979797979123412341234123479797979797979797979790d1512240d121212121212121212121215000008090809080908090809080908090000080908090809b11a1bb208090000
1c1c191819181918191819181918191819181918191819181918191819181c1c08090809080908090809080908090809797979797979797979797979341234123412341279797979797979797979791d15120d1d1212121212121212121212150000181918191819181918191819181900001819181918193839393a18190000
1c1c090809080908090809080908090809080908090809080908090809081c1c18191819181918191819181918191819797979797979797979797979123412341234123479797979797979797979792d151212121212121212121212121212150000080908090809080908090809080900000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c000000000000000000000000000000007979797979797979797979793412341234123412797979797979797979797900153535353535353535353535353535150000181918191819181918191819181900001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c000000000000000000000000000000007979797979797979797979791234123412341234797979797979797979797900153535353535353535353535353535150000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c000000000000000000000000000000007979797979797979797979793412341234123412797979797979797979797900153535353535353535353535353535150000181918191819181918191819000000001819181918191819181918190000
b1292929292929292929292929292929292929292929292929292929292929b2000000000000000000000000000000007979797979797979797979797979797979797979797979797979797979797900151819151515151515151515151819150000000000000000000000000000000000000000000000000000000000000000
383939393939393939393939393939393939393939393939393939393939393a000000000000000000000000000000003535353535353535353535353535353535353535353535353535353535353535151819151515151515151515151819150000000000000000000000000000000000000000000000000000000000000000
__sfx__
000600000605001050060500305018000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
090600000305007050040500605003050060520605600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000900000363000650006000160000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
000a00001b050180501b0502005020050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000137500d750007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
