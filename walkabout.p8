pico-8 cartridge // http://www.pico-8.com
version 33
__lua__

-- title
-- author

-- global vars

local debug = true  -- (stat(6) == 'debug')
local o_player
local speedshoes = false
local godshoes = false

local flag_walkable = 0b1

-->8
-- utility

if (debug) menuitem(5,'toggle debug',function() debug = not debug end)
if (debug) menuitem(4,'toggle airshoes',function() godshoes = not godshoes end)

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
 palt(0, false)
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

function clamp(min_, query, max_)
 return min(max_, max(min_, query))
end

-- print with shadow
local function prints(s, x, y, c1, c2)
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
 if (other == nil) return false
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
function bbox:__mul(n) return bbox(self.origin*n, self.size*n) end
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
 self.age = (self.age + 1) % 27720
 if self.ttl and self.age >= self.ttl then
  self:destroy()
 end
 -- domain: camera perspective
 self.z = self.pos.y
end
function actor:destroy() self._doomed = true end

local mob = actor:extend{
 size = vec(7,7),
 anchor = vec(0,0),
 anim = nil,
 frame_len = 1,
 flipx = false,
 flipy = false,
 tcol = nil,
 paltab = nil,
 shape_offset = vec(0,0)
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
 self.shape = self:get_hitbox(self.pos)
end
function mob:get_hitbox(pos)
 return bbox(
  pos + self.shape_offset,
  self.bsize
 )
end
function mob:draw()
 -- if self.spr or self.afnim then
 if (self.tcol != nil) paltt(self.tcol)
 if (self.paltab) pal(self.paltab)
 -- caching unpack saves tokens
 local temp = (self.pos + self.anchor)  -- picotool :(
 local spx, spy = temp:unpack()
 local spw, sph = self.size:unpack()
 spw, sph = ceil(spw/8), ceil(sph/8)
 -- anim is a list of frames to loop
 -- frames are sprite ids
 if self.anim then
  local findex = (flr(self.age/self.frame_len) % #self.anim) +1
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
 if debug then
  -- print bbox and anchor/origin
  rect(mrconcat({self.shape:unpack()}, 2))
  line(spx, spy,
   mrconcat({self.pos:unpack()}, 4))
  pset(spx, spy, 5)
 end
 if (self.paltab) pal()
end

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
 -- if (object.stage) del(object.stage.objects, object)
 object.stage = self
end
function stage:_zsort()
 sort(self.objects, function(a) return a.z end)
end
function stage:update()
 self.mclock = (self.mclock + 1) % 27720
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

-->8
-- game utility

-- dialog box
-- by rusty bailey

dialoger = {
 x = 8,
 y = 97,
 color = 7,
 max_chars_per_line = 28,
 max_lines = 4,
 queue = {},
 blinking_counter = 0,
 init = function(self)
 end,
 enqueue = function(self, message, prefix)
  -- default prefix to empty
  prefix = type(prefix) == "nil" and '' or prefix
  add(self.queue, {
    message = message,
    prefix = prefix
   })

  if (#self.queue == 1) then
   self:trigger(self.queue[1].message, self.queue[1].prefix)
  end
 end,
 trigger = function(self, message, prefix)
  self.prefix = prefix
  self.current_message = prefix
  self.messages_by_line = nil
  self.animation_loop = nil
  self.current_line_in_table = 1
  self.current_line_count = 1
  self.pause_dialog = false
  self:format_message(message)
  self.animation_loop = cocreate(self.animate_text)
 end,
 format_message = function(self, message)
  if type(message) == "function" then
   message()
   return
  end
  local total_msg = {}
  local word = ''
  local letter = ''
  local current_line_msg = ''

  for i = 1, #message do
   -- get the current letter add
   letter = sub(message, i, i)

   -- keep track of the current word
   word ..= letter

   -- if it's a space or the end of the message,
   -- determine whether we need to continue the current message
   -- or start it on a new line
   if letter == ' ' or i == #message then
    -- get the potential line length if this word were to be added
    local line_length = #current_line_msg + #word
    -- if this would overflow the dialog width
    if line_length > self.max_chars_per_line then
     -- add our current line to the total message table
     add(total_msg, current_line_msg)
     -- and start a new line with this word
     current_line_msg = word
    else
     -- otherwise, continue adding to the current line
     current_line_msg ..= word
    end

    -- if this is the last letter and it didn't overflow
    -- the dialog width, then go ahead and add it
    if i == #message then
     add(total_msg, current_line_msg)
    end

    -- reset the word since we've written
    -- a full word to the current message
    word = ''
   end
  end

  self.messages_by_line = total_msg
 end,
 animate_text = function(self)
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
     if (i % 5 == 0) sfx(0)
     yield()
    end
   end
   self.current_message ..= '\n'
   self.current_line_count += 1
   if ((self.current_line_count > self.max_lines) or (self.current_line_in_table == #self.messages_by_line)) then  --  and not self.autoplay)) then
    self.pause_dialog = true
    yield()
   end
  end

 -- if (self.autoplay) then
 --  self.yieldn(30)
 -- end
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
    coresume(self.animation_loop, self)
   else
    if btnp(4) then
     self.pause_dialog = false
     self.current_line_count = 1
     self.current_message = self.prefix
    end
   end
  elseif (self.animation_loop and self.current_message) then
   -- if (self.autoplay) self.current_message = ''
   self.animation_loop = nil
  end

  if (not self.animation_loop and #self.queue > 0) then
   self.shift(self.queue, 1)
   if (#self.queue > 0) then
    self:trigger(self.queue[1].message, self.queue[1].prefix)
    coresume(self.animation_loop, self)
   end
  end

  --if (not self.autoplay) then
  self.blinking_counter += 1
  if self.blinking_counter > 30 then self.blinking_counter = 0 end
 --end
 end,
 draw = function(self)
  local screen_width = 128

  -- display message
  if (self.current_message) then
   rectfill(0,90,127,127,0)
   rect(0,90,127,127,7)
   print(self.current_message, self.x, self.y, self.color)
  end

  -- draw blinking cursor at the bottom right
  if (self.pause_dialog) then  -- not self.autoplay and
   if self.blinking_counter > 15 then
    if (self.current_line_in_table == #self.messages_by_line) then
     -- draw square
     rectfill(
      screen_width - 11,
      screen_width - 10,
      screen_width - 11 + 3,
      screen_width - 10 + 3,
      7
     )
    else
     -- draw arrow
     line(screen_width - 12, screen_width - 9, screen_width - 8,screen_width - 9)
     line(screen_width - 11, screen_width - 8, screen_width - 9,screen_width - 8)
     line(screen_width - 10, screen_width - 7, screen_width - 10,screen_width - 7)
    end
   end
  end
 end
}

-->8
-- game classes

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
 for _, v in ipairs(self.lines) do
  dialoger:enqueue(v, self.prefix)
 end
 self.talkedto += 1
end

local t_npc = t_sign:extend{
 facing = 'd',
 spr0 = 0,
 bsize = vec(15,7),
 obstructs = true,
 tcol = 15
}
function t_npc:init(...)
 t_sign:init(...)
 self.size = vec(15,23)
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
 dialoger:enqueue(function() self.ismoving = false end)
end
function t_npc:draw()
 self.flipx = (self.facing == 'l')
 local facemap = {d=0, u=2, l=4, r=4}
 self.spr = self.spr0 + facemap[self.facing]
 if self.ismoving and self.age % 8 < 4 then
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
 o_portal = t_button(pos, 005, vec(23, 15))
 o_portal.tcol = 15
 function o_portal:interact(p)
  if p.cooldown > 0 then
   p.cooldown += 1
   printh('Not Portalling (cooldown)')
   return
  end
  if deststate then
   dest(deststate.pos)
   p.facing = deststate.facing
  else
   dest()  -- let room decide position
  end
  o_player.cooldown = 5
  cur_room:update()  -- align camera
  sfx(001)
  printh('portalled player to')
  printh(o_player.stage:relpos(o_player))

  local grav = vec(0, 0.01)
  for i = 0, 24 do
   local spread = 8
   local p = particle(
     o_player.stage:relpos(o_player) + vec(rndr(-spread, spread), 4),
     vec(rndr(-0.5, 0.5), rndr(-2.1, -1.7)), --vel
     grav, -- acc
     rndr(10, 15), -- ttl
     7 -- col
    )
   function p:update()
    particle.update(self)
    self.z += (self.age)*4
   end
   cur_room:add(p)
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
  printh(o_player.stage:relpos(o_player))
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
 shape_offset = vec(-8, -7)
}
function t_player:init(pos)
 mob.init(self, pos, 64, vec(15,23))
 self.bsize = vec(14, 7)
end
function t_player:_moveif(step, facing)
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
   end
   break
  end
 end
 self.justtriggered = stillintrigger
 -- try interact
 local facemap = {d=vec(0,1), u=vec(0,-1), l=vec(-1,0), r=vec(1,0)}
 if btnp(4) then
  self.ibox = bbox(
   self.pos + self.anchor - vec(0, -8) + facemap[self.facing]*8,
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

 self.ismoving = false
 if self.cooldown > 0 then
  self.cooldown -= 1
 elseif (#dialoger.queue == 0) then
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
 if self.ismoving and self.age % 8 < 4 then
  self.anchor = vec(-8, -23)
 else
  self.anchor = vec(-8, -24)
 end
 mob.draw(self)
 if (debug) rect(mrconcat({self.shape:unpack()}, 2))
 if (debug and self.ibox) rect(mrconcat({self.ibox:unpack()}, 10))
end

local room = stage:extend{
 camfocus = nil
}
function room:init(mx, my, mw, mh)
 self.box_map = bbox(vec(mx, my), vec(mw, mh))
 self.box_cells = self.box_map*16
 self.box_px = self.box_cells*8

 self.camfocus = self.box_px:center()

 -- origin in units
 self.origin_map = vec(mx, my)
 self.origin_cells = self.origin_map*16
 self.origin_px = self.origin_cells*8

 -- extent in units
 self.extent_map = vec(mw, mh)
 self.extent_cells = self.extent_map*16
 self.extent_px = self.extent_cells*8
 stage.init(room)
end
function room:draw()
 local cell_x, cell_y = self.box_cells.origin:unpack()
 local cell_w, cell_h = self.box_cells.size:unpack()
 local sx, sy = self.box_px.origin:unpack()

 cls()
 local cam = self.camfocus - vec(64, 64)
 local cx0, cy0, cx1, cy1 = self.box_px:unpack()
 cam.x = clamp(cx0, cam.x, cx1-128)
 cam.y = clamp(cy0, cam.y, cy1-128)

 camera(cam:unpack())

 dbg.watch(cam,"cam")
 map(cell_x, cell_y, sx, sy, cell_w, cell_h)
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
 camera()
 if debug and o_player then
  -- rect(mrconcat({self.box_px:unpack()}, 10))
  local mous = vec(stat(32), stat(33)) + cam - cur_room.box_px.origin
  prints('plr  ' .. tostring(self:relpos(o_player)), 0, 0)
  prints('room ' .. tostring(self.box_map.origin), 0, 8)
  prints('mous ' .. tostring(mous), 0, 16)
  
 end

end
function room:relpos(object)
 return object.pos - self.box_px.origin
end
function room:add(object)
 object.pos += self.box_px.origin
 stage.add(self, object)
end

function drawgreat(self)
 local box = bbox((self.pos + vec(0,2)), vec(15, 12))
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
 local center = vec(124, 128)
 cur_room = room(0, 0, 2, 2)
 o_player = t_player(center)
 o_player.pos += vec(12, 12)
 cur_room:add(o_player)

 o_computer1 = t_sign(vec(24, 8), 010, vec(15, 15))
 o_computer1:addline(
  "tWO WHITE LINES OF TEXT ARE BLOWN UP TO FILL THE ENTIRE SCREEN.")
 o_computer1:addline(
  "iT'S SO HUGE YOU CAN READ IT FROM ACROSS THE ROOM.")
 o_computer1:addline(
  "i WONDER WHAT IT SAYS.")
 cur_room:add(o_computer1)

 o_computer2 = t_sign(vec(88, 8), 112, vec(15, 7))
 o_computer2:addline(
  "lOOKS LIKE SOMEONE WAS PLANNING A FUNDRAISING CAMPAIGN FOR A VIDEO GAME.")
 o_computer2:addline("tOO BAD THEY'RE JUST A TROLL.")
 o_computer2.bsize = vec(15,15)
 cur_room:add(o_computer2)

 o_computer3 = t_sign(vec(156, 9), 116, vec(7, 7))
 o_computer3:addline("iT'S AN OFF-ICE COMPUTER.")
 o_computer3:addline("yOU CAN TELL BECAUSE SOMEONE IS RUNNING TROLL POWERPOINT. iT TICKED PAST THE LAST SLIDE THOUGH.")
 o_computer3.tcol = 15
 cur_room:add(o_computer3)

 o_computer4 = t_sign(vec(216, 8), 010, vec(15, 15))
 o_computer4.paltab = {[6]=3}
 o_computer4:addline(
  "wOWIE! LOOKS LIKE SOMEBODY'S BEEN FLIRTING. iN \f3green.")
 o_computer4:addline(
  "dUE TO TECHNICAL LIMITATIONS, THE KEYBOARD HAS ALSO BEEN FLIRTING. iN \f3green.")
 cur_room:add(o_computer4)

 o_teapot = t_sign(vec(240, 128), 050, vec(15, 7))
 o_teapot.tcol = 012
 o_teapot:addline(
  "iT'S A CAT-THEMED TEAPOT. " ..
  "iT SEEMS OUT OF PLACE IN THIS DISTINCTLY UN-CAT-THEMED ROOM.")
 o_teapot:addline(
  "tHE SUGAR IS ARRANGED SO AS TO BE COPYRIGHTABLE INTELLECTUAL PROPERTY.")
 cur_room:add(o_teapot)

 o_karkat = t_npc(vec(64, 64), 070)
 o_karkat.prefix = "\fd"
 function o_karkat:interact(player)
  if self.talkedto % 2 == 0 then
   self.lines = {
    "epilogues? the fuck are you talking about? we have bigger things to deal with right now than ill-advised " ..
    "movie sequels or whatever it is you're distracted with."
   }
  else
   self.lines = {
    "strider? i have had literally one interaction with the guy and it ended up being all about vriska.",
    "because of course literally fucking everything has to be about vriska if you're unfortunate enough to get stuck in the same universe as her. or apparently even if you're not.",
    "i'd joke about offing yourself being the only way to escape her absurd machivellian horseshit but at this point she's probably fucked up death too. also, [todo] is goddamn dead and i'm not going to chose this particular moment to startlisting off all the cool perks of getting murdered."
   }

  end
  t_npc.interact(self, player)
 end
 cur_room:add(o_karkat)

 o_cards = t_sign(vec(184, 194), 034, vec(15, 7))
 o_cards.tcol = 0
 o_cards:addline("tHESE CARDS REALLY GET LOST IN THE FLOOR. SOMEONE MIGHT SLIP AND GET HURT.")
 o_cards:addline("tHEN AGAIN THAT'S PROBABLY HOW THE GAME WOULD HAVE ENDED ANYWAY.")
 o_cards:addline("sOMEONE HAS TRIED TO PLAY SOLITAIRE WITH THEM. yOU FEEL SAD.")
 cur_room:add(o_cards)

 o_plush = t_sign(vec(142, 203), 032, vec(15, 15))
 o_plush.tcol = 0
 o_plush:addline("todo gio pls add flavor text for plush in complab")
 cur_room:add(o_plush)

 cur_room:add(newportal(center, room_t))

end

function room_t(v)
 cur_room = room(2, 0, 1, 1)
 o_player = t_player(v or vec(24, 91))
 cur_room:add(o_player)

 cur_room:add(newportal(vec(12, 79), room_complab))

 cur_room:add(newportal(vec(92, 79), room_lab))

end

function room_lab(v)
 cur_room = room(6, 0, 1, 2)
 o_player = t_player(v or vec(64, 44))
 o_player.facing = 'r'
 cur_room:add(o_player)

 cur_room:add(newportal(vec(53, 33), room_t, {
    facing='d',
    pos=vec(104, 91)
   }))

 cur_room:add(newtrig(vec(124, 192), vec(4, 31), room_hallway))

end

function room_hallway(v)
 cur_room = room(2, 1, 2, 1)
 o_player = t_player(v or vec(14, 72))
 cur_room:add(o_player)

 greydoor = t_sign(vec(120, 32), 030, vec(15, 23))
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

 cur_room:add(newtrig(vec(0, 56), vec(8, 31), room_lab, {
    facing='l',
    pos=vec(115, 208)
   }))

 cur_room:add(newtrig(vec(248, 56), vec(15, 31), room_stair))

end

function room_stair(v)
 cur_room = room(7, 0, 1, 2)
 o_player = t_player(v or vec(18, 52))
 o_player.facing = 'r'
 cur_room:add(o_player)

 cur_room:add(newtrig(vec(0, 32), vec(4, 31), room_hallway, {
    facing='l',
    pos=vec(240, 72)
   }))

 o_plush = t_sign(vec(80, 141), 032, vec(15, 15))
 o_plush.tcol = 0
 o_plush:addline("hE MUST BE LOST.")
 o_plush:addline("fORTUNATELY HIS OWNER CAN SAFELY WALK DOWN HERE AND RETRIEVE HIM.")
 cur_room:add(o_plush)

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
 -- function o_gio:update()

 --  t_npc.update(self)
 -- end
 cur_room:add(o_gio)

 o_vue = t_sign(vec(72, 184), 010, vec(15, 15))
 o_vue:addline("iT LOOKS LIKE HE HAS BEEN TRYING TO COPY MEDIA FROM THE PAST INTO THE PRESENT.")
 o_vue:addline("a FOOL'S ERRAND.")
 cur_room:add(o_vue)

 o_great = t_button(vec(16, 96), false, vec(15, 15))
 o_great.interact = function()
  room_turbine(vec(24, 112))
 end
 o_great.draw = drawgreat
 cur_room:add(o_great)

end

function room_turbine(v)
 cur_room = room(3, 0, 1, 1)
 o_player = t_player(v or vec(24, 112))
 cur_room:add(o_player)

 o_great = t_button(vec(96, 16), false, vec(15, 15))
 o_great.draw = drawgreat
 cur_room:add(o_great)

 cur_room:add(newtrig(vec(16, 124), vec(15, 4), room_stair, {
   facing='d',
   pos=vec(24, 121)
  }))
 cur_room:add(newtrig(vec(124, 32), vec(4, 15), room_roof))
end

function room_roof(v)
 cur_room = room(4, 0, 1, 1)
 o_player = t_player(v or vec(16, 98))
 cur_room:add(o_player)

 function cur_room:update()
  if self:relpos(o_player).x < 32 then
   o_player.bsize = vec(7,7)
   o_player.shape_offset = vec(-4, -7)
  else
   o_player.bsize = vec(14,7)
   o_player.shape_offset = vec(-8, -7)
  end
  room.update(self)
 end

 o_stair_rail = mob(vec(77, 48), nil, vec(2, 64))
 o_stair_rail.obstructs = true
 cur_room:add(o_stair_rail)

 o_pogo = t_sign(vec(96, 22), 078, vec(15, 15))
 o_pogo.bsize = vec(7,7)
 o_pogo.obstructs = true
 o_pogo.tcol = 3
 o_pogo:addline("tHANKS TO THE MIRACLE OF DIGITAL TECHNOLOGY, THE POGO RIDE HAS BEEN EFFORTLESSLY PRESERVED TO THE EXACT SPECIFICATIONS OF THE DESIGNER, A FEAT UNHEARD OF IN ANY PREVIOUS ERA.")
 o_pogo:addline("bUT IT DOESN'T WORK ANYMORE.")
 o_pogo:addline(function()
  o_pogo.draw = mob.draw
  o_pogo.lines = {"iT SEEMS SOMEONE HAS REPLACED THE RIDE WITH A STILL PHOTO."}
  end)

 function o_pogo:draw()
  if self.age % 32 < 16 then
   self.anchor = vec(-4, -8)
  else
   self.anchor = vec(-4, -7)
  end
  mob.draw(self)
 end
 cur_room:add(o_pogo)

 cur_room:add(newtrig(vec(8, 88), vec(4, 15), room_turbine, {
   facing='l',
   pos=vec(108, 41)
  }))
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

-->8
--pico-8 builtins

function _init()
 prettify_map()
 room_complab()
end

function _update()
 dialoger:update()
 cur_room:update()

 dbg.watch(dialoger,"dialoger")
 dbg.watch(cur_room,"cur_room")
 dbg.watch(o_player,"player")
 dbg.watch(cur_room.objects,"objects")
end

function _draw()

 pal()
 cur_room:draw()
 if #dialoger.queue > 0 then
  dialoger:draw()
 end
 if (debug) dbg.draw()
end
__gfx__
0011223300000000eeeeeeee0000000000000000ffffffffffffffffffffffff5000000000000005000000000000000000000000000000050000000000000000
0011223300000000e222222e0000000000000000ffffffffffffffffffffffff56dd555d6d555556055555555555555055dddd55000000150000000000000000
4455667700000000e222662e0000000000000000ffffffffffffffffffffffff0dddd555ddd55556011111111111111055555555000005150000000000000000
4455667700000000e222222e0000000000000000ffffffffffffffffffffffff0ddddd555ddd555d015000000000051051111115000015150000000000000000
8899aabb00000000e222222e0000000000000000ffffffffffffffffffffffff0dddddd555ddd555015066066060051051111115000515150000000000000000
8899aabb00000000e266222e0000000000000000fffffff1111111111fffffff0ddddddd555ddd5d015000000000051051111115001515150000000000000000
ccddeeff00000000e222222e0000000000000000ffff1111115115111111ffff0dddddddd555dddd015066666066051051111115051515150000000000000000
ccddeeff00000000eeeeeeee0000000000000000ff11111111155111111111ff05dddddddd555ddd015000000000051051111115151515150000000000000000
0011111133333333666666660000000000000000ff11111115511551111111ff055dddddddd555d601555555555555105111111515151515dddddddddddddddd
0011111133333333666666660000000000000000f1111115115115115111111f0d55dddddddd555d01111111111111105111111515151515d66666666666666d
2255ddff3b333333666666660000000000000000f1221111151111511111221f0dd55dddddddd55d50000000000000005111111515151515d6dddddddddddd6d
2255ddff33b3b333666666660000000000000000f1112221111111111222111f0ddd555ddddddddd11101115551101105111111515151515d6d6666666666d6d
2299aa3333333333666666660000000000000000fff111122222222221111fff05ddd55ddddddddd10000000000000005111111515151515d6d6666666666d6d
2299aa33333333b3666666660000000000000000ffffff111111111111ffffff055ddd55dddddddd06565566666565605111111515151515d6d6666666666d6d
3355eeee333b3b33666666660000000000000000ffffffffffffffffffffffff0d55ddd55ddddddd01111155555111105111111515151515d6d6666666666d6d
3355eeee33333333666666660000000000000000ffffffffffffffffffffffff0dd55ddddddddd6510000000000000005111111515151515d6d6666666666d6d
0000044444440000000001dddd000000eeeeeeee666666666666666677777777000000000000000000000000511111155111111515151515d6d6666666666d6d
0000488887884000000001d8dd000000e222222e6ccccccc666666667777777755555555555555555555555051111115511111151515151dd6d6666666666d6d
000048484848890000d001dddd0ddd00e222002e6ccccccc66666666777777775111111111111111111111151111111551111115151515ddd6d6666666466d6d
000048898777aa400ddd0111111d8d50e222222e6ccccccc666666667777777751111111111111111111111511111115d555555d15151dddd6d6666664646d6d
0004848878787aa9dd8dd000001ddd55e222222e6ccccccc6666666677777777511111111111111111111115111111155ddd55dd1515ddddd6d666666d4d6d6d
0048889878477aa41ddddd00001ddd50e200222e6ccccccc66666666777777775111111111111111111111151111111555ddd55d151dddddd6d666666d6d6d6d
4484848487887a7a01ddd100001ddd00e222222e6ccccccc6666666677777777511111111111111111111115111111150000000015ddddddd6d6666666d66d6d
48889888aa77aaa4001d100000115000eeeeeeee6ccccccc666666667777777751111111111111111111111511115550000000001dddddddd6d6666666666d6d
4484848aaaaaaaa9cccccccccccccccc000000005555555566666666777776670550000000000000000005605111111500000000ddddddddd6d6666666666d6d
004888aaaaaaaaa4c77cccccc00ccccc000000005555555577677767777776670d51111111111111111115d05111111500000000ddddddddd6d6666666666d6d
00048aaaaaaaafa9c77cccc00000cccc000000005555555577677767777776670d51111111111111111115d05111111100000000ddddddddd6d6666666666d6d
00009aaaaaaf4a4077cc0c0fffff0c0c000000005555555577677767777776670dd555555555555555555dd05111111100000000ddddddddd6d6666666666d6d
000004aaaaa9000077cc00f0f0fff0c00000000055555555776777677777766705ddd5555ddd55ddddddddd05111111100000000ddddddddd6d6666666666d6d
0000009aaf400000c77cc0f000fff0c000000000555555557767776777777667055ddd5555ddd55dddddddd05111111100000000ddddddddd6d6666666666d6d
00000004a9000000c77ccc0f0fff0c0c000000005555555566666666777776670d5dddd555ddddddddddd6605111111100000000dddddddd66d6666666666d66
0000000a4a000000ccccccc00000cccc000000005555555577777777777776670000000000000000000000000555111100000000dddddddddddddddddddddddd
fffffffffffffffffffffffffffffffffffffffffffffffffffff1fffffffffffffff1fffffffffffffffff1ffffffff00000000000000003333333333333333
ffffffffffffffffffffffffffffffffffffffffffffffffffff11f111111fffffff111111111fffffffff11f11111ff00000000000000003333333331111333
ffffffffffffffffffffffffffffffffffffffffffffffffff1111111111fffffff11111111111ffffff1111111111ff0000000000000000333333331bbbb133
fffffffffffffffffffffffffffffffffffffffffffffffff1111111111111fff1f11111111111ffff1f1111111111ff0000000000000000333333331b1b1133
fffff11111fffffffffff11111fffffffffff11111fffffff19111111111911ff11191111119111fff1111191111111f000000000000000033333111bbbbbb13
fff117777711fffffff117777711fffffff117777711fffff199111111199111f11911111111911fff11111991111111000000000000000033111111b7777b13
ff17777777771fffff17777777771fffff17777777771ffff19911111119911ff11111111111111fff1111199111111f000000000000000031bb11111b77b113
ff17777777771fffff17777777771fffff17777777771ffff111d111d11111fff1111111111111ffff11111d1111611f000000000000000031bb111b11bb1133
f1777777777771fff1777777777771fff1777777777771fff111d11d116111fff1111111111111ffff11111d66111111000000000000000031bbbbbbbbbbb133
f1777177717771fff1777777777771fff1777777777171ff1111d9161961111f111111111111111ff111111d6691611f0000000000000000331b1bbb1bbb1333
f1777077707771fff1777777777771fff1777777777171fff1d1d916196161ffff111111111111ffff1111dd669161ff0000000000000000333111bbb1113333
f17777e777e771fff1777777777771fff1777777777771ffff1dd5666d6611fffff1111111111ffffff1111d66dd61ff00000000000000003333311111333333
ff17777dee771fffff17777777771fffff17777777771ffffff11d111611fffffff111111111ffffffff11ddd1161fff00000000000000003333330033333333
ff17777777771fffff17777777771fffff17777777771fffffff1dd6661fffffffff1111111fffffffffff1dd661ffff00000000000000003333303000333333
fff117777711fffffff117777711fffffff117777711fffffffff11111fffffffffff111111fffffffffff11111fffff00000000000000003333330003333333
ffff1111111fffffffff1111111fffffffff1111111fffffffff1055101fffffffff1000000fffffffffff10051fffff00000000000000003333333333333333
ffff1777771fffffffff1777771fffffffff1777771fffffffff1050001fffffffff1000000ffffffffff1000551ffff00000000000000000000000000000000
ffff1777771fffffffff1777771fffffffff1777771fffffffff1000501fffffffff1000000ffffffffff1000501ffff00000000000000000000000000000000
ffff1777771fffffffff1777771fffffffff1777771fffffffff1015501fffffffff1000000ffffffffff1000151ffff00000000000000000000000000000000
ffff1777771fffffffff1777771fffffffff1777771fffffffff1511111fffffffff1511115ffffffffff1511111ffff00000000000000000000000000000000
fffff11111fffffffffff11111fffffffffff11111ffffffffff1555551fffffffff1551555ffffffffff155551fffff00000000000000000000000000000000
fffff1fff1fffffffffff1fff1fffffffffff1fff1ffffffffff1551551ffffffff111515511ffffffffff1551ffffff00000000000000000000000000000000
fffff1fff1fffffffffff1fff1fffffffffff1fff1ffffffff10551110551ffffff0001111051fffffffff100551ffff00000000000000000000000000000000
ffff1fffff1fffffffff1fffff1ffffffffff1ffff1fffffff11111f11111ffffff1111111111fffffffff111111ffff00000000000000000000000000000000
00000000000000000000000000000000555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05555555555555500555555555555550111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01111111111111100111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
015222222aa44510015222222aa44510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0156bbb72284a5100156bbb72284a510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01560bb17219651001560bb172196510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
015ffdcd65163510015ffdcd65163510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
015dfdc665686510015dfdc665686510555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000010000000000010100000001000000010100000000000101000000010000000000000100000100000000000100000000000001000001000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000101010101010101010001010100000000000000000000000000000000000000000000000000000000000000000000000000000809000000000000000000003535353535353535111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000a0b0000000000000a0b0000000000000a0b0000000000000a0b000000000000000000000000000000000000000000000000001819000000000000000000003535353535353535111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0928291a1b2929292929291a1b2929292929291a1b2929292929291a1b292a08000000000809080908090809000000000000000000000809000000000101000000002626262626262626111111111111000000000000000000000000000000000000080908090809080908090809000000000809080908090809080908090000
1938393939393939393939393939393939393939393939393939393939393a18000000001819181918191819000000000000000000001819000000000101000000002625252626262626111111111111000000000000000000000000000000000000181918191819181918191819000000001819181918191819181918190000
0c0c090809080908090809080908090809080908090809080908090809080c0c000000000809080908090809000000000000080908090809000000000809080900002625252626262626111111111111000000000000000000000000000000000101080908090809080908090809000008090809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c010100001819181918191819000000000000181918191819000000001819181900002626262626262626111111111111000000000000000000000000000000000101181918191819181918191819000018191819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c010101010809080908090809000000000000080900000809080908090809000000002727272727272737111111111111000000000000000000000000000000000101080908090809080908090809000008090809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c000001011819181918191819000000000000181900001819181918191819000000002727272727272737111111111111000000000000000000000000000000000101181918191819181918191819000018191819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c080908090809080908090809080908090000080900000000000000000000000000002727272727272737111111111111000000000000000000000000000000000000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c181918191819181918191819181918190000181900000000000000000000000000002727272727272737111111111111000000000000000000000000000000000000181918191819181918191819000000001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c08090809080908090809080908090809000008090000000000000000000000000000272727272727273711111111111100000000000000000000000000000000000008090809080908090809080900000000010101010101240d080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c181918191819181918191819181918190000181900000000000000000000000001272727272727272737111111111111000000000000000000000000000000000000181918191819181918191819000000000101010101240d1d181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c0809080908090809080908090809080900000809000000000000000000000000002727272727272727371111111111110000000000000000000000000000000000000809080908090809080908090100000001010101240d1d2d3d3d3d3d0100
1c1c191819181918191819181918191819181918191819181918191819181c1c18191819181918191819181918191819000018190000000000000000000000000024363636363636363611111111111100000000000000000000000000000000000018191819181918191819181900000000010101240d1d2d3d3d3d3d3d0000
1c1c090809080908090809080908090809080908090809080908090809081c1c00000000000000000000000000000000000008090000000000000000000000260024262626262626262611111111111100000000000000000000000000000000000008090809080908090809080900000000080908091d2d3d3d3d3d013d0000
1c1c191819181918191819181918191819181918191819181918191819181c1c00000000000000000000000000000000000018190000000000000000000000260024020202020202020211111111111100000000000000000000000000000000000018191819181918191819181900000000181918192d3d3d3d3d3d013d0000
1c1c090809080908090809080908090809080908090809080908090809081c1c000000000000000000000000000000000000000000000000000000000000000100010101000000000000000000000000010000000000000000000000000000000000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c000000000000000000000000000000000000000000000000000000000000000000010101000000000000000000000000000000000000000000000000000000000000181918191819181918191819000000001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000181918191819181918191819000000001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c0000000000000000000000000000001e1f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c0000000000000000000000000000002e2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000181918191819181918191819000000001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c0000000000000000000000000000003e3f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c08090809080908090809080908090809080908090809080908090809080908090000000000000000000000000000000000000000000000000000000000000000000018191819181918191819181900000000181918191819180a0b1918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c18191819181918191819181918191819181918191819181918191819181918190000000000000000000000000000000000000000000000000000000000000000000008090809080908090809080908090000080908090809281a1b2a08090000
1c1c191819181918191819181918191819181918191819181918191819181c1c080908090809080908090809080908090809080908090809080908090809080900000000000000000000000000000000000000000000000000000000000000000000181918191819181918191819181900001819181918193839393a18190000
1c1c090809080908090809080908090809080908090809080908090809081c1c181918191819181918191819181918191819181918191819181918191819181900000000000000000000000000000000000000000000000000000000000000000000080908090809080908090809080900000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000181918191819181918191819181900001819181918191819181918190000
1c1c090809080908090809080908090809080908090809080908090809081c1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080908090809080908090809000000000809080908090809080908090000
1c1c191819181918191819181918191819181918191819181918191819181c1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000181918191819181918191819000000001819181918191819181918190000
3b2929292929292929292929292929292929292929292929292929292929292b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
383939393939393939393939393939393939393939393939393939393939393a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000600000605001050060500305018000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
090600000305007050040500605003050060520605600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
