pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--[[
kl8x
klax clone
by giovanh - seth giovanetti

todo:
 the algoritim for matching doesn't work at all
 game over if the board gets full
]]


-->8
-- abstract logic
function contains(t, element)
  for _, value in pairs(t) do
    if value == element then
      return true
    end
  end
  return false
end


log10_table = {
  0, 0.3, 0.475,
  0.6, 0.7, 0.775,
  0.8375, 0.9, 0.95, 1
}

function log10(n)
  if (n < 1) return nil
  local t = 0
  while n > 10 do
    n /= 10
    t += 1
  end
  return log10_table[flr(n)] + t
end
-->8
-- init and constructors


function init_gameboard(l,h)
  local gb = {
    h = h,
    l = l,
    tick = 0,
    tiles = {}
  }
  for x=1,gb.l do
    gb.tiles[x] = {}
    for y=1,gb.h do
      gb.tiles[x][y] = { }
    end
  end
  return gb
end

function random_tile()
  local c = 6
  --c += flr(score/500)
  --if c > 7 then c = 7 end
  return {
    col=1+flr(rnd(c)),
    draw = true,
    frame=1  --max 4
  }
end

function init_paddle()
  return {
    x = 3,
    offset = 0,
    d = 0,
    extended = false,
    tiles = {}
  }
end

function _init()
  score = 0
  scoreplus = 0
  combo = 10
  drops = 3
  x_offset = 24
  can_update = true
  fx = {
    tiles = {},
    wait = 40,
  }
  menuitem(1,"dump",function() dumptable(falling_ks) end)
  paddle = init_paddle()
  gb = init_gameboard(5,5)
  falling_ks = init_gameboard(5,9)
  ui = {}
  total_ticks = 0
end
-->8
-- pure utility functions

function dumptable(tab,ind)
  if not ind then ind = " " end
  --dumps object tab to console
  printh(ind .. "{","dump")
  for k,v in pairs(tab) do
    local b = (type(tab[k]) == "boolean")
    if b == true then
      local v = ""
      if tab[k] then
        v = "true"
      else
        v = "false"
      end
      printh(ind .. k .. ": " .. v,"dump")
    elseif type(tab[k]) == "function" then
      printh(ind .. k .. ": function " .. k .. "()","dump")
    elseif type(tab[k]) != "table" then
      printh(ind .. k .. ": " .. tab[k],"dump")
    else
      printh(ind .. k .. ": ","dump")
      dumptable(tab[k],ind .. " ")
    end
  end
  printh(ind .. "}","dump")
end
-->8
-- drawing

function _draw()
  cls()
  draw_bg()
  update_effects(fx)
  draw_paddle(paddle)
  draw_falling_ks(falling_ks)
  draw_board_ks(gb)
  draw_ui(ui)
end


function draw_bg()

  local ox,oy = 64,56
  ox -= 2*(1+flr(log10(score)))

  print("x" .. (flr(combo/10)),x_offset+1,70,10)

  line(x_offset-1,0,x_offset-1,128,2)
  line(128-(48-x_offset),0,128-(48-x_offset),128,2)
  line(x_offset,64,128-(48-x_offset),64,2)

  print("drops:",0,64-4,5)
  for i=1,drops do
    spr(128,x_offset + (i-1)*16,64-4,2,1)
  end
end

function draw_ui(ui)

  local ox,oy = 64,56
  --ox -= 2*(1+flr(log10(score)))

  print(score,ox - 2*(1+flr(log10(score))),oy,7)
  if scoreplus > 0 then print(" +" .. scoreplus,(ox + 2*(1+flr(log10(score)))),oy,10) end
  if scoreplus > 0 then
    local inc = 1

    if scoreplus > 100 then inc = 100
    elseif scoreplus > 10 then inc = 10
    end
    score += inc
    scoreplus -= inc
    if score%1000 == 0 and drops < 5 then drops += 1 end
  end

end

function draw_paddle(paddle)

  local f = 0
  if btn(5) then f = 2 end
  spr(
    f,  --frame,
    x_offset-16 + paddle.offset + (16*paddle.x),
    64 + (#paddle.tiles)*8,
    2,
    2
  )

  for y=1,#paddle.tiles do
    draw_klax(
      x_offset-16+paddle.offset+(16*paddle.x),
      64+(#paddle.tiles-(y))*8,
      paddle.tiles[y])

  end
end

function draw_board_ks(fb)

  for x=fb.l,1,-1 do
    for y=fb.h,1,-1 do
      if fb.tiles[x][y].frame and fb.tiles[x][y].draw then
        --draw falling tile
        local tile = fb.tiles[x][y]
        draw_klax(x_offset + (x-1)*16,72+8+(y-1)*8,tile)
      end
    end
  end
end

function draw_falling_ks(fb)
  for x=1,fb.l do
    for y=1,fb.h do
      if fb.tiles[x][y].frame then
        --draw falling tile
        local tile = fb.tiles[x][y]
        draw_klax(x_offset + (x-1)*16,(y-1)*8 + tile.frame*0,tile)
      end
    end
  end
end


function draw_klax(x,y,klax)
  local pals = {{8,2},{10,9},{11,3},{12,13},{9,4},{7,6},{0,5}}
  local p = pals[klax.col]
  pal(10,p[1])
  pal(9,p[2])
  --dumptable(p)
  local frame = 96 + (klax.frame*2)
  spr(
    frame,  --frame,
    x,
    y,
    2,
    2
  )
  --rint(klax.frame,x+6,y+3,7)
  pal()
end
-->8
-- updates and game logic


function update_falling(fb)
  fb.tick += 1
  if fb.tick == 600 then fb.tick = 0 end

		update_interval = 100
		update_interval -= flr(total_ticks/50)
		if update_interval <= 50 then update_interval = 50 end

  if fb.tick % update_interval == 1 then
    fb.tiles[1+flr(rnd(5))][1] = random_tile()
  end

  --gb.tiles[x][1] = fb.tiles[x][y]
  --fb.tiles[x][y].frame = 134

  for x=fb.l,1,-1 do
    for y=fb.h,1,-1 do
      if fb.tiles[x][y].frame then
        local tile = fb.tiles[x][y]

        if paddle.x == x and #paddle.tiles < 5 and (not fb.tiles[x][y+1] or not fb.tiles[x][y+2]) then

          fb.tiles[x][y].frame = 4
          add(paddle.tiles,fb.tiles[x][y])
          fb.tiles[x][y] = {}
          break
        end

        if fb.tick % 6 == 0 or (btn(3) and fb.tick % 2 == 0) then
          tile.frame = (tile.frame +1 ) % 5
        end

        if fb.tiles[x][y+1] then
          --update falling tile
          if fb.tick % 6 == 0 or (btn(3) and fb.tick % 2 == 0) then
            if tile.frame == 1 then sfx(02) end
            if (tile.frame +1 ) % 5 == 0 and not fb.tiles[x][y+1].frame then
              fb.tiles[x][y+1] = fb.tiles[x][y]
              fb.tiles[x][y] = {}
            end
          end
        elseif   fb.tiles[x][y].frame%4 == 3 then
          drops -= 1
          if drops == 0 then game_end() end
          sfx(03)
          fb.tiles[x][y] = {}
        end
      end
    end
  end
end

function game_end()
  can_update = false
  sfx(04)
end

function score_match(matches)
  local scores = {}
  scores[3] = 50
  scores[4] = 250
  scores[5] = 1000
  if combo <= 10 then
    scoreplus += scores[#matches+1]
    --score += 10*(1+#matches)
    sfx(00)
  else
    scoreplus += flr(combo/10) * scores[#matches+1]
    --score += (10*flr(combo/10))*(1+#matches)
    sfx(01)
  end
  if combo == 10 then
    combo = 40
  else
    combo += 20
  end
end

function update_baseboard(fb)
  fb.tick += 1
  if fb.tick == 1000 then fb.tick = 0 end
  for x=fb.l,1,-1 do
    for y=fb.h,1,-1 do
      if fb.tiles[x][y].frame and fb.tiles[x][y+1] then
        --update falling tile
        local tile = fb.tiles[x][y]
        if not fb.tiles[x][y+1].frame then
          fb.tiles[x][y+1] = fb.tiles[x][y]
          fb.tiles[x][y] = {}
        end
      end
    end
  end
  for x=1,fb.l do
    for y=1,fb.h do
      if fb.tiles[x][y].frame and (not fb.tiles[x][y+1] or fb.tiles[x][y+1].frame)  then
        local tile = fb.tiles[x][y]
        printh(x .. "," .. y .. ":" .. tile.col,"tile")
        local matched = false
        --horizontal
        local hmatches = {}
        local yoff = {0,1,-1}
        for yoff in all(yoff) do
          local matches = 1
          --printh("\tfor y offset " .. yoff,"tile")
          local y2 = y
          for x2 = x+1,fb.l do
            y2 += yoff
            --printh("\t\tchecking tile at " .. x2 .. "," .. y2 .. "","tile")
            if not fb.tiles[x2][y2] or fb.tiles[x2][y2].col != tile.col then
              break
            elseif (fb.tiles[x2][y2+1] and not fb.tiles[x2][y2+1].frame) then
              break
            elseif contains(fx.tiles, fb.tiles[x2][y2]) then
              break
            else
              --printh("\t\t\ttile at " .. x2 .. "," .. y2 .. "matches","tile")
              fb.tiles[x2][y2].x = x2
              fb.tiles[x2][y2].y = y2
              add(hmatches,fb.tiles[x2][y2])
              matches += 1
            end
          end
          if matches >= 3 then matched = true end
        end

        --vertical
        local x2 = x
        local matches = 1
        for y2 = y+1,fb.h do
          --printh("\t\tchecking tile at " .. x2 .. "," .. y2 .. "","tile")
          if not fb.tiles[x2][y2] or fb.tiles[x2][y2].col != tile.col then
            break
          elseif (fb.tiles[x2][y2+1] and not fb.tiles[x2][y2+1].frame) then
            break
          elseif contains(fx.tiles, fb.tiles[x2][y2]) then
            break
          else
            --printh("\t\t\ttile at " .. x2 .. "," .. y2 .. "matches","tile")
            fb.tiles[x2][y2].x = x2
            fb.tiles[x2][y2].y = y2
            add(hmatches,fb.tiles[x2][y2])
            matches += 1
          end
        end
        if matches >= 3 then matched = true end

        if matched then
          dumptable(hmatches)
          can_update = false
          tile.x = x
          tile.y = y
          if not contains(fx.tiles, tile) then add(fx.tiles,tile) end
          for t in all(hmatches) do
            if not contains(fx.tiles, t) then add(fx.tiles,t) end
          end
          score_match(hmatches)
        end
      end
    end
  end
end

function update_paddle(paddle)

  if btn(5) and not paddle.extended and #paddle.tiles > 0 and not gb.tiles[paddle.x][1].frame then
    paddle.extended = true
    if not gb.tiles[paddle.x][1].frame then
      --paddle.tiles[#paddle.tiles].frame = 19
      gb.tiles[paddle.x][1] = paddle.tiles[#paddle.tiles]
      del(paddle.tiles,paddle.tiles[#paddle.tiles])
    end
  elseif not btn(5) then
    paddle.extended = false
  end
  if paddle.offset == 0 then
    if btn(0) and paddle.x > 1 then
      paddle.offset = 16
      paddle.x -= 1
      paddle.d = -1
    elseif btn(1) and paddle.x < 5 then
      paddle.offset = -16
      paddle.x += 1
      paddle.d = 1
    end
  else
    paddle.offset += 4*paddle.d
  end
end

function update_effects(fx)

  if fx.wait <= 0 then
    fx.wait = 40
    can_update = true
    for tile in all(fx.tiles) do
      gb.tiles[tile.x][tile.y] = {}
      tile = {}
    --todo: score
    --del(fx.tiles,tile)
    end

    fx.tiles = {}
  --gb.tiles = {}
  elseif #fx.tiles > 0 then
    fx.wait -= 1
    for tile in all(fx.tiles) do
      tile.draw = not tile.draw
    end
  end
end

function _update()
  if can_update then
    total_ticks += 1
    update_paddle(paddle)
    update_baseboard(gb)
    update_falling(falling_ks)
    if combo > 10 then combo -= 1 end
  end
--dumptable(falling_ks)
end
__gfx__
00000000000000000000005555000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000057777500000000000000000000000000005022222222222222202222222222222202222222000000000000000000000000000000000
00555555555555000055555555555500000555555555555000000005025555555555555202555555555555205555552000000000000000000000000000000000
05777755557777500577757777577750005555555555555500000005025555555555555202555555555555205555552000000000000000000000000000000000
05777577775777500577757777577750005555555555555500000002055555555555552025555555555555525555555020000000000000000000000000000000
57777755557777755777775555777775555555555555555550000002055555555555552025555555555555525555555020000000000000000000000000000000
57777777777777755777777777777775555555555555555550000002055555555555552025555555555555525555555020000000000000000000000000000000
55555555555555555555555555555555555555555555555550000002055555555555552025555555555555525555555020000000000000000000000000000000
57777777777777755777777777777775555555555555555550000002022222222222222022222222222222222222222020000000000000000000000000000000
5777777777777775577777777777777555557777777777555000000205aaa5aaa5aaa52025aaa5aaa5aaa552a5aaa55020000000000000000000000000000000
577755555555777557775555555577755555777777777755500000020555a5a5a5a5a5202555a5a5a5a5a552a5a5a55020000000000000000000000000000000
5777555555557775577755555555777555555555555555555000000205aaa5a5a5a5a52025aaa5a5a5a5a552a5a5a55020000000000000000000000000000000
5777777777777775577777777777777555555555555555555000000205a555a5a5a5a52025a555a5a5a5a552a5a5a55020000000000000000000000000000000
0577777777777750057777777777775000000000000000000000000205aaa5aaa5aaa52025aaa5aaa5aaa552a5aaa55020000000000000000000000000000000
00555555555555000055555555555500000000000000000000000002022222222222222022222222222222202222222020000000000000000000000000000000
00000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000005555555555555555000000000000000000000000000000000000000000000000
00000000000000005555555555555550555555555555555000000000000000005a9a9a9a9a9a9a95000000000000000000000000000000000000000000000000
55555555555555505a9a9a9a9a9a9a505aaaaaaaaaaaaa50005555555555500059a9a9a9a9a9a9a5000000000000000000000000000000000000000000000000
5a9a9a9a9a9a9a5059a9a9a9a9a9a9505aaaaaaaaaaaaa50055a9a9a9a9a55005a9aaaaaaaaaaa95000000000000000000000000000000000000000000000000
59a9a9a9a9a9a9505a9aaaaaaaaa9a50555555555555555005a9a9a9a9a9a50059aaaaaaaaaaa9a5000000000000000000000000000000000000000000000000
5a9aaaaaaaaa9a5059aaaaaaaaaaa9505a9aaaaaaaaa9a505a9aaaaaaaaa9a505a9aaaaaaaaaaa95000000000000000000000000000000000000000000000000
59aaaaaaaaaaa9505a9aaaaaaaaa9a5059aaaaaaaaaaa95059a9a9a9a9a9a95059aaaaaaaaaaa9a5000000000000000000000000000000000000000000000000
5a9aaaaaaaaa9a5059aaaaaaaaaaa9505a9aaaaaaaaa9a5055555555555555505555555555555555000000000000000055555555500000000000000000000000
59aaaaaaaaaaa9505a9aaaaaaaaa9a5059aaaaaaaaaaa9505aaaaaaaaaaaaa505aaaaaaaaaaaaaa500000000000000005a5a5a5a500000000000000000000000
5a9aaaaaaaaa9a5059aaaaaaaaaaa9505a9a9a9a9a9a9a505aaaaaaaaaaaaa505aaaaaaaaaaaaaa5555555555000000055aaaaa5500000000000000000000000
55555555555555505a9aaaaaaaaa9a5059a9a9a9a9a9a9505aaaaaaaaaaaaa505aaaaaaaaaaaaaa55a5a5a5a500000005aaaaaaa500000000000000000000000
5aaaaaaaaaaaaa5059aaaaaaaaaaa95055555555555555505aaaaaaaaaaaaa505aaaaaaaaaaaaaa555aaaaa55000000055aaaaa5500000000000000000000000
5aaaaaaaaaaaaa505a9aaaaaaaaa9a5000000000000000005aaaaaaaaaaaaa505aaaaaaaaaaaaaa55aaaaaaa500000005aaaaaaa500000000000000000000000
555555555555555059a9a9a9a9a9a95000000000000000005aaaaaaaaaaaaa505aaaaaaaaaaaaaa5555555555000000055aaaaa5500000000000000000000000
00000000000000005a9a9a9a9a9a9a500000000000000000555555555555555055555555555555555aaaaaaa500000005a5a5a5a500000000000000000000000
00000000000000005555555555555550000000000000000000000000000000000000000000000000555555555000000055555555500000000000000000000000
00000000000000000000000000000000000000000000000000000000000000005555555555555555000000000000000000000000000000000000000000000000
00000000000000005555555555555550555555555555555000000000000000005a9a9a9a9a9a9a95000000000000000000000000000000000000000000000000
55555555555555505a9a9a9a9a9a9a505aaaaaaaaaaaaa50005555555555500059a9a9a9a9a9a9a5000000000000000000000000000000000000000000000000
5a9a9a9a9a9a9a5059a9a9a9a9a9a9505aaaaaaaaaaaaa50055a9a9a9a9a55005a9aaaaaaaaaaa95000000000000000055555555555550000000000000000000
59a9a9a9a9a9a9505a9aaaaaaaaa9a50555555555555555005a9a9a9a9a9a50059aaaaaaaaaaa9a500000000000000005a5a5a5a5a5a50000000000000000000
5a9aaaaaaaaa9a5059aaaaaaaaaaa9505a9aaaaaaaaa9a505a9aaaaaaaaa9a505a9aaaaaaaaaaa95555555555555500055a5a5a5a5a550000000000000000000
59aaaaaaaaaaa9505a9aaaaaaaaa9a5059aaaaaaaaaaa95059a9a9a9a9a9a95059aaaaaaaaaaa9a55a5a5a5a5a5a50005a5aaaaaaa5a50000000000000000000
5a9aaaaaaaaa9a5059aaaaaaaaaaa9505a9aaaaaaaaa9a505555555555555550555555555555555555a5a5a5a5a5500055aaaaaaaaa550000000000000000000
59aaaaaaaaaaa9505a9aaaaaaaaa9a5059aaaaaaaaaaa9505aaaaaaaaaaaaa505aaaaaaaaaaaaaa55a5aaaaaaa5a50005a5aaaaaaa5a50000000000000000000
5a9aaaaaaaaa9a5059aaaaaaaaaaa9505a9a9a9a9a9a9a505aaaaaaaaaaaaa505aaaaaaaaaaaaaa555aaaaaaaaa5500055aaaaaaaaa550000000000000000000
55555555555555505a9aaaaaaaaa9a5059a9a9a9a9a9a9505aaaaaaaaaaaaa505aaaaaaaaaaaaaa55a5aaaaaaa5a50005a5aaaaaaa5a50000000000000000000
5aaaaaaaaaaaaa5059aaaaaaaaaaa95055555555555555505aaaaaaaaaaaaa505aaaaaaaaaaaaaa555aaaaaaaaa5500055aaaaaaaaa550000000000000000000
5aaaaaaaaaaaaa505a9aaaaaaaaa9a5000000000000000005aaaaaaaaaaaaa505aaaaaaaaaaaaaa555555555555550005a5aaaaaaa5a50000000000000000000
555555555555555059a9a9a9a9a9a95000000000000000005aaaaaaaaaaaaa505aaaaaaaaaaaaaa55aaaaaaaaaaa500055a5a5a5a5a550000000000000000000
00000000000000005a9a9a9a9a9a9a500000000000000000555555555555555055555555555555555aaaaaaaaaaa50005a5a5a5a5a5a50000000000000000000
00000000000000005555555555555550000000000000000000000000000000000000000000000000555555555555500055555555555550000000000000000000
00000000000000000000000000000000000000000000000000000000000000005555555555555555555555555555555555555555555555550000000000000000
00000000000000005555555555555550555555555555555000000000000000005a9a9a9a9a9a9a955a5a5a5a5a5a5a5555a5a5a5a5a5a5a50000000000000000
55555555555555505a9a9a9a9a9a9a505aaaaaaaaaaaaa50005555555555500059a9a9a9a9a9a9a555a5a5a5a5a5a5a55a5a5a5a5a5a5a550000000000000000
5a9a9a9a9a9a9a5059a9a9a9a9a9a9505aaaaaaaaaaaaa50055a9a9a9a9a55005a9aaaaaaaaaaa955a5aaaaaaaaaaa5555aaaaaaaaaaa5a50000000000000000
59a9a9a9a9a9a9505a9aaaaaaaaa9a50555555555555555005a9a9a9a9a9a50059aaaaaaaaaaa9a555aaaaaaaaaaa5a55a5aaaaaaaaaaa550000000000000000
5a9aaaaaaaaa9a5059aaaaaaaaaaa9505a9aaaaaaaaa9a505a9aaaaaaaaa9a505a9aaaaaaaaaaa955a5aaaaaaaaaaa5555aaaaaaaaaaa5a50000000000000000
59aaaaaaaaaaa9505a9aaaaaaaaa9a5059aaaaaaaaaaa95059a9a9a9a9a9a95059aaaaaaaaaaa9a555aaaaaaaaaaa5a55a5aaaaaaaaaaa550000000000000000
5a9aaaaaaaaa9a5059aaaaaaaaaaa9505a9aaaaaaaaa9a50555555555555555055555555555555555a5a5a5a5a5a5a5555aaaaaaaaaaa5a50000000000000000
59aaaaaaaaaaa9505a9aaaaaaaaa9a5059aaaaaaaaaaa9505aaaaaaaaaaaaa505aaaaaaaaaaaaaa555a5a5a5a5a5a5a55a5aaaaaaaaaaa550000000000000000
5a9aaaaaaaaa9a5059aaaaaaaaaaa9505a9a9a9a9a9a9a505aaaaaaaaaaaaa505aaaaaaaaaaaaaa5555555555555555555aaaaaaaaaaa5a50000000000000000
55555555555555505a9aaaaaaaaa9a5059a9a9a9a9a9a9505aaaaaaaaaaaaa505aaaaaaaaaaaaaa55aaaaaaaaaaaaaa55a5aaaaaaaaaaa550000000000000000
5aaaaaaaaaaaaa5059aaaaaaaaaaa95055555555555555505aaaaaaaaaaaaa505aaaaaaaaaaaaaa55aaaaaaaaaaaaaa555aaaaaaaaaaa5a50000000000000000
5aaaaaaaaaaaaa505a9aaaaaaaaa9a5000000000000000005aaaaaaaaaaaaa505aaaaaaaaaaaaaa55aaaaaaaaaaaaaa55a5aaaaaaaaaaa550000000000000000
555555555555555059a9a9a9a9a9a95000000000000000005aaaaaaaaaaaaa505aaaaaaaaaaaaaa55aaaaaaaaaaaaaa555a5a5a5a5a5a5a50000000000000000
00000000000000005a9a9a9a9a9a9a5000000000000000005555555555555550555555555555555555555555555555555a5a5a5a5a5a5a550000000000000000
00000000000000005555555555555550000000000000000000000000000000000000000000000000000000000000000055555555555555550000000000000000
00000000000000005555555555555555000000000000000055555555555555550000000000000000555555555555555500000000000000000000000000000000
00000000000000005aa5a5a5a5a5a5aa00000000000000005aa5a5a5a5a5a5a50000000000000000aa5a5a5a5a5a5aa500000000000000000000000000000000
00000000000000005a5a5a5a5a5a5a5a00000000000000005a5a5a5a5a5a5aa50000000000000000a5a5a5a5a5a5a5a500000000000000000000000000000000
05555555555555505aa5aaaaaaaaa5aa00000000000000005aa5aaaaaaaaa5a50000000000000000aa5aaaaaaaaa5aa500000000000000000000000000000000
5555555555555555aa5aaaaaaaaa5aa50000000000000000aa5aaaaaaaaa5a5a00000000000000005aa5aaaaaaaaa5aa00000000000000000000000000000000
5666666666666665a5a5aaaaaaa5a5a50000000000000000a5a5aaaaaaaaa5aa00000000000000005a5a5aaaaaaa5a5a00000000000000000000000000000000
5555555555555555aa5a5a5a5a5a5aa50000000000000000aa5a5a5a5a5a5a5a00000000000000005aa5a5a5a5a5a5aa00000000000000000000000000000000
0000000000000000a5555555555555a50000000000000000a55555555555555a00000000000000005a5555555555555a00000000000000000000000000000000
220e0003005000ddaaaaaaaaaaaaaaa50000000000000000aaaaaaaaaaaaaaaa00000000000000005aaaaaaaaaaaaaaa00000000000000000000000000000000
200e0330050000d0aaaaaaaaaaaaaaa50000000000000000aaaaaaaaaaaaaaaa00000000000000005aaaaaaaaaaaaaaa00000000000000000000000000000000
20ee300050000d00aaaaaaaaaaaaaaa50000000000000000aaaaaaaaaaaaaaaa00000000000000005aaaaaaaaaaaaaaa00000000000000000000000000000000
eee03005000dd000aaaaaaaaaaaaaaa50000000000000000aaaaaaaaaaaaaaaa00000000000000005aaaaaaaaaaaaaaa00000000000000000000000000000000
e003055000d00009aaaaaaaaaaaaaaa50000000000000000aaaaaaaaaaaaaaaa00000000000000005aaaaaaaaaaaaaaa00000000000000000000000000000000
003005000d000009aaaaaaaaaaaaaaa50000000000000000aaaaaaaaaaaaaaaa00000000000000005aaaaaaaaaaaaaaa00000000000000000000000000000000
33005000d0000990aaaaaaaaaaaaaaa50000000000000000aaaaaaaaaaaaaaaa00000000000000005aaaaaaaaaaaaaaa00000000000000000000000000000000
0005000dd00099005555555555555555000000000000000055555555555555550000000000000000555555555555555500000000000000000000000000000000
__sfx__
000600001a0501a0501e0501e05021050210502605026050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000700001c0501c050200502005023050230502805028050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800000c46008620073000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
00100000245501f550135500655004600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000300502f0502b0502a050210501e0501f0501f050190001500019000150000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
