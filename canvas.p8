pico-8 cartridge // http://www.pico-8.com
version 16
__lua__


function _init()
 poke(0x5f2d,1)
 mx,my,mb=0,0,false
 mc = 3

 px,py=64,64
 pc = 1

 fx,fy=0,0
 fc = 6

 lc = 4
end

function _update()
 mx = stat(32)
 my = stat(33)
 mb = stat(34)
 if (mb == 1) px,py=mx,my

 fx = mx + 2*(px-mx)
 fy = my + 2*(py-my)

end

function _draw()
 cls()
 circ(px,py,2,pc)
 circ(mx,my,2,mc)
 circ(fx,fy,2,fc)

 line(px,py,fx,fy,lc)
end