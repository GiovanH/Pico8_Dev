pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--initialization

game_state = 0
function _init()
 start_game()
end

function start_game()
 game_state = 1
 sprites = {}
end

-->8
--draw

function _draw()
 if (game_state == 1) draw_game()
end

function draw_game()
 cls()
 -- map(0, 0, 0, 0, 128, 32)
 for s in all(sprites) do
  if (s.draw == "std") do
   spr(s.sprite+s.frame,(8*s.x)+s.ox, (8*s.y)+s.oy)
  else
   s:draw()
  end
 end
end

-->8
--update

function update_game()
 tick_game()
 end
end

function tick_game()
 for sprite in all(sprites) do
  sprite:tick()
 end
end

-->
--objects

function new_sprite(x,y)
 s = {}
 --map position
 s.x=x
 s.y=y
 --movement direction
 s.dx=0
 s.dy=0
 --pixel offset
 s.ox=0
 s.oy=0
 s.sprite=000
 s.frame=0
 s.draw="std"
 s.tick=nop
 s.move=nop
 s.busy=false
 add(sprites,s)
 return s
end
