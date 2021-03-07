pico-8 cartridge // http://www.pico-8.com
version 8
__lua__

--by giovanh, seth giovanetti

--[[
known issues:
areagrabs can cross with frame-perfect inputs and mirrored player coords
ratton needs a chip icon
ratton needs a speed fix
ui fanfare for deletion
chip ideas:
  meteor
  boomerang
  mm6 burner
  lance
  shuriken (targets)
  health recovery
  zapring
]]

--globals

debug = true

--utility functions

function dumptable(tab)
  --dumps object tab to console
  printh("{")
  for k,v in pairs(tab) do
    if (type(tab[k]) == "boolean") then
      local v = ""
      if tab[k] then
        v = "true"
      else
        v = "false"
      end
      printh(k .. ": " .. v)
    elseif (type(tab[k]) == "function") then
      printh(k .. ": function " .. k .. "()")
    elseif (type(tab[k]) != "table") then
      printh(k .. ": " .. tab[k])
    else
      printh(k .. ": ")
      dumptable(tab[k])
    end
  end
  printh("}")
end

--chips

chips = {
  {
    name = "cannon",
    weight = 4,
    sprite = 128,
    dmg = 50,
    use = function(c,p)
      sfx(6)
      add(entities,
        new_buster(
          p.x,
          p.y,
          p.faction,
          c.dmg,
          4
        )
      )
      add(entities,new_muzzle(
          p,
          1,  --l
          2,  --h
          24,  --ox
          4,  --oy
          {06,06,06}  --fmap
        )
      )
    end
  },
  {
    name = "’canon",
    weight = 1,
    sprite = 128,
    dmg = 120,
    use = function(c,p)
      sfx(6)
      add(entities,
        new_buster(
          p.x,
          p.y,
          p.faction,
          c.dmg,
          4
        )
      )
      add(entities,new_muzzle(
          p,
          1,  --l
          2,  --h
          24,  --ox
          4,  --oy
          {06,06,06}  --fmap
        )
      )
    end
  },
  {
    name = "grab",
    weight = 3,
    sprite = 144,
    use = function(c,p)
      add(entities,new_grabber(p.faction))
    end
  },
  {
    name = "shkwav",
    weight = 3,
    sprite = 130,
    dmg = 60,
    use = function(c,p)
      add(entities,
        new_wave(
          p.x,
          p.y,
          p.faction,
          c.dmg,
          6
        )
      )
    end
  },
  {
    name = "sword",
    weight = 1,
    sprite = 147,
    use = function(c,p)
      add(entities,new_sword(p,1,1,80))
    end
  },
  {
    name = "w-swrd",
    weight = 2,
    sprite = 145,
    use = function(c,p)
      add(entities,new_sword(p,2,1,80))
    end
  },
  {
    name = "l-swrd",
    weight = 2,
    sprite = 146,
    use = function(c,p)
      add(entities,new_sword(p,1,2,80))
    end
  },
  {
    name = "’swrd",
    weight = 1,
    sprite = 163,
    use = function(c,p)
      add(entities,new_sword(p,2,2,80))
    end
  },
  {
    name = "cube",
    weight = 1,
    sprite = 131,
    use = function(c,p)
      add(entities,new_cube(p,100))
    end
  },
  {
    name = "bomb",
    weight = 4,
    sprite = 129,
    use = function(c,p)
      add(entities,new_ball(p,80,false,1))
    end
  },
  {
    name = "breakr",
    weight = 2,
    sprite = 160,
    use = function(c,p)
      add(entities,new_ball(p,120,true,2))
    end
  },
  {
    name = "rat",
    weight = 2,
    sprite = 115,
    use = function(c,p)
      add(entities,new_rat(p,80))
    end
  },
  {
    name = "mixer",
    weight = 1,
    sprite = 161,
    use = function(c,p)
      p.chips = {}
      for i=1,3+flr(rnd(3)) do
        add(p.chips,random_chip())
      end
    end
  }
}

weightedchips = {}
for chip in all(chips) do
  if not chip.weight then chip.weight = 200 end
  printh(chip.name .. ": " .. chip.weight)
  for i = 1, chip.weight do
    add(weightedchips, chip)
  end
end

function random_chip()
  -- local i =
  -- return chips[flr(rnd(#chips))+1]
  --return chips[4+flr(rnd(5))]
  return weightedchips[flr(rnd(#weightedchips))+1]
end

--constructors

function new_sword(p,h,l,dmg)
  return {
    x=p.x,
    y=p.y,
    z=p.y,
    sprite=0,
    l=2,
    h=2,
    oy=2,
    ox=0,
    hbh = h,
    hbl = l,  --*p.faction,
    faction = p.faction,
    frame = 0,
    damage = dmg,
    callback = function(this)
      --get ranges
      local x1,x2 = this.x+this.faction,this.x+(this.faction*this.hbl)
      --render
      local sprmap = {38,38,40,40,42,42}
      local oxmap =  {20,20,20,20,12,12}

      this.frame += 1
      --logic
      for x=min(x1,x2),max(x1,x2) do
        for y=this.y-(this.hbh-1),this.y+this.hbh-1 do
          if board.tiles[x] and board.tiles[x][y] then
            board.tiles[x][y].lit = sprmap[this.frame]
            for c in all(collisions(entities,{x=x,y=y})) do
              if c.faction != this.faction and c.hp then
                c.hurt(this.damage,c)
                del(entities,b)
              end
            end
          end
        end
      end
      if not sprmap[this.frame] then
        del(entities,this)
        return
      else
        this.sprite = sprmap[this.frame]
        this.ox = oxmap[this.frame]
      end
    end
  }
end

function new_cube(p,hp)
  local x = p.x+p.faction
  local h = hp
  for c in all(collisions(entities,{x=x,y=p.y})) do
    if c.hp then
      h = 0
    end
  end
  return {
    x=x,
    y=p.y,
    sprite=36,
    l=2,
    h=0,
    z=p.y,
    oy=12,
    ox=2,
    hp = h,
    lbl = hp,
    lblo = 2,
    stun = 0,
    faction = 0,
    callback = function(this)
      if this.stun > 0 then this.stun -= 1 end
      if this.h < 2 then this.h += 0.2 end
      if this.h > 2 then this.h = 2 end
      this.lbl = this.hp
      if this.hp <= 0 then del(entities,this) add(entities,new_explosion(this.x,this.y,2)) end
    end,
    hurt = function(dmg,this)
      if this.stun == 0 then
        this.hp -= dmg
        if dmg > 40 then this.stun = 4 end
      end
    end
  }
end

function new_wave(x,y,f,dmg,delay)
  function cb(b)
    if b.wait == 0 then
      board.tiles[b.x][b.y].lit = false
      b.x += b.faction
      sfx(7)
      b.wait = b.delay
      if b.x > board.l or b.x == 0 or board.tiles[b.x][b.y].faction == 0 then
        del(entities,b)
      else
        board.tiles[b.x][b.y].lit = true
      end
    else
      b.wait -= 1
    end
    for c in all(collisions(entities,b)) do
      if c.faction != b.faction and c.hp then
        c.hurt(b.damage,c)
      end
    end

  end
  return {
    x=x,
    y=y,
    z=y,
    sprite=34,
    l=2,
    h=2,
    oy=10,
    ox=2,
    faction = f,
    delay = delay,
    wait = 0,
    damage = dmg,
    callback = cb
  }
end

function new_grabber(faction)
  function cb(this)
    for y=1,3 do
      board.tiles[this.x][y].lit = false
    end
    this.x += this.faction
    if this.x +1 > board.l or this.x == 1 then
      del(entities,this)
      return
    end
    for y=1,3 do
      board.tiles[this.x][y].lit = true
      if board.tiles[this.x][y].faction != this.faction then
        --if any tile x,y is not the same faction
        for k = 1,3 do
          -- for each tile in that column
          local collide = false
          for c in all(collisions(entities,{x=this.x,y=k})) do
            if c.hp and c.faction != this.faction then
              collide = true
              c.hurt(10,c)
            end
          end
          if not collide then
            board.tiles[this.x][k].faction = this.faction
          end
          add(entities,new_explosion(this.x,k,1))
        end
        for k=1,3 do
          board.tiles[this.x][k].lit = false
        end
        sfx(5)
        del(entities,this)
        return
      end
    end
  end
  return {
    x = flr(4-2.5*faction),
    y=0,
    callback = cb,
    faction = faction

  }
end

function new_hole(x,y)
  local hold = board.tiles[x][y].faction
  return {
    timer = 600,
    hold = hold,
    x=x,
    y=y,
    z=0,
    draw = function(this,gb)
      if this.timer < 60 and this.timer%2 ==0 then return end
      pal()
      if (this.hold == 1) then
        pal(8,13)  --red to blue
        pal(14,6)  --pink to sky
        pal(4,5)  --brown to grey
      end
      spr(
        004,
        gb.startx+(20*(this.x-1)),
        gb.starty+(16*this.y),
        1.25,
        2)
      spr(
        004,
        gb.startx+(20*(this.x-0.5)),
        gb.starty+(16*this.y),
        1.25,2,
        true)
    end,
    callback = function(this)
      this.timer -= 1
      if this.timer > 0 then
        board.tiles[this.x][this.y].hole = true
        board.tiles[this.x][this.y].faction = 0
      else
        board.tiles[this.x][this.y].hole = false
        board.tiles[this.x][this.y].faction = this.hold
        del(entities,this)
      end
    end
  }
end

function new_rat(p,dmg)
  local skins = {112,113}
  b = {
    x=p.x,
    z=p.y,
    y=p.y,
    sprite=115,
    l=1,
    h=1,
    oy=16,
    turned = 0,
    ox=2,
    faction = p.faction,
    damage = dmg,
    callback = function(b)
      dumptable(b)
      board.tiles[b.x][b.y].lit = false
      if b.turned == 0 then
        b.ox += 4
        if b.ox >= 20 then
          b.ox = 0
          b.x += b.faction
        end
        for y=1,3 do
          for c in all(collisions(entities,{x=b.x,y=y})) do
            if c.faction != b.faction and c.hp then
              b.turned = y-b.y  --todo do this better
              if b.turned == -2 then b.turned = -1 end
              b.ox = 5
            end
          end
        end
      else
        b.oy += 4 * b.turned
        if abs(b.oy) >= 16 then
          b.oy = 0
          b.y += b.turned
        end
      end
      b.z=b.y

      if board.tiles[b.x] and board.tiles[b.x][b.y] and not board.tiles[b.x][b.y].hole and b.y <= board.h then
        board.tiles[b.x][b.y].lit = true
      else del(entities,b) return end
      local hit = false
      for c in all(collisions(entities,b)) do
        if c.faction != b.faction and c.hp then
          c.hurt(b.damage,c)
          hit = true
        end
      end
      if hit then
        board.tiles[b.x][b.y].lit = false
        add(entities,new_explosion(b.x,b.y,2))
        del(entities,b)
        return
      end
    end
  }
  return b
end

function new_ball(p,dmg,brk,skin)
  local skins = {112,113}
  b = {
    x=p.x,
    z=p.y,
    y=p.y,
    sprite=skins[skin],
    l=1,
    h=1,
    oy=12,
    ox=2,
    distance=3*p.faction,
    faction = p.faction,
    damage = dmg,
    brk = brk,
    callback = function(b)
      if board.tiles[b.x+b.distance] and board.tiles[b.x+b.distance][b.y] then board.tiles[b.x+b.distance][b.y].lit = true end
      if b.distance == 0 then  --if landed
        local hit = false
        for c in all(collisions(entities,b)) do
          if c.faction != b.faction and c.hp and b.damage > 0 then
            c.hurt(b.damage,c)
            hit = true
          end
        end
        if board.tiles[b.x] and board.tiles[b.x][b.y] then
          board.tiles[b.x][b.y].lit = false
          if b.brk and not hit then
            add(entities,new_hole(b.x,b.y))
          end
          add(entities,new_explosion(b.x,b.y,1))
        end
        del(entities,b)
        return
      else  --flying
        b.ox += 4
        b.oy += 6*(2 - abs( b.distance))
        if b.ox >= 20 then
          b.ox = 0
          b.x += b.faction
          b.distance -= 1*b.faction
        end
      end
    end
  }
  return b
end

function new_buster(x,y,f,dmg,delay)
  b = {
    x=x,
    y=y,
    faction = f,
    delay = delay,
    wait = 0,
    damage = dmg,
    callback = function(b)
      if b.wait == 0 then
        board.tiles[b.x][b.y].lit = false
        b.x += b.faction
        b.wait = b.delay
        if b.x > board.l or b.x == 0 then
          del(entities,b)  --remove
        else
          board.tiles[b.x][b.y].lit = true
        end
      else
        b.wait -= 1
      end
      for c in all(collisions(entities,b)) do
        if c.faction != b.faction and c.hp then
          c.hurt(b.damage,c)
          board.tiles[b.x][b.y].lit = false
          if b.damage >= 20 then add(entities,new_explosion(b.x,b.y,2)) else add(entities,new_explosion(b.x,b.y,0)) end
          del(entities,b)
        end
      end
    end
  }
  return b
end

function new_explosion(x,y,size)

  local sprite,l,h,oy,ox=0,0,0,0,0
  local  fmap = {}
  if size == 0 then
    local a = 6
    local b = a*2
    sprite,l,h,oy,ox=0,1,1,10,8
    oy += a-flr(rnd(b))
    ox += a-flr(rnd(b))
    fmap = {240,241,242}
  elseif size == 1 then
    sprite,l,h,oy,ox=0,1,1,10,6
    fmap = {224,225,226}
  else  --if size == 2 then
    sprite,l,h,oy,ox=0,2,2,6,2
    fmapx = {192,194,196,198}
    for i=1,size-1 do
      for frame in all(fmapx) do add(fmap, frame) end
    end
  end
  return {
    sprite=sprite,
    l=l,
    h=h,
    oy=oy,
    ox=ox,
    frame=0,
    fmap = fmap,
    x=x,
    y=y,
    z=y,
    callback=function(this)
      this.frame += 1
      if not this.fmap[this.frame] then
        del(entities,this)
        return
      else
        this.sprite = this.fmap[this.frame]
      end
    end
  }
end

function new_muzzle(player,l,h,ox,oy,fmap)
  return {
    sprite=72,
    l=l,
    h=h,
    oy=oy,
    ox=ox,
    frame=0,
    fmap = fmap,
    faction = player.faction,
    x=player.x,
    y=player.y,
    z=player.y,
    p=player,
    callback=function(this)
      this.x = this.p.x
      this.y = this.p.y
      this.frame += 1
      if not this.fmap[this.frame] then
        del(entities,this)
        return
      else
        this.sprite = this.fmap[this.frame]
      end
    end
  }
end

function new_chargeshot(player)
  --it's really just the logic
  function draw(cs)
  end
  function cb(cs)
    cs.z = cs.p.z-1
    cs.x = cs.p.x
    cs.y = cs.p.y
    if player.charge <= 10 then
      cs.l = 0
      cs.h = 0
    elseif player.charge <= 100 then
      cs.l = 1
      cs.h = 1
      cs.sprite = 76
    else
      cs.l = 1
      cs.h = 1
      cs.sprite = 75
    end
    if player.charge == 10 then
      sfx(01)
    elseif player.charge == 100 then
      sfx(02)
    end
  end
  return {
    p=player,
    faction=player.faction,
    x=0,
    z=0,
    y=0,
    callback = cb,
    sprite = 0,
    l = 1,
    h = 1,
    ox = 14 -player.faction,
    oy = 9
  }
end

function new_methat(x,y,faction)

  return {
    step = 0,
    sprite=172,
    hp = 100,
    lbl=100,
    lblo=0,
    l=2,
    h=2,
    ox=2,
    oy=12,
    rest=0,
    x=x,
    y=y,
    callback=function(m)
      m.z=m.y
      --hp
      m.lbl = m.hp
      --ai
      m.step += 1
      if m.step == 60 then
        add(entities,
          new_buster(
            m.x,
            m.y,
            m.faction,
            10,
            1
          )
        )
        --local c = chips[1]
        --c.use(c,m)
        m.step =0
      end
      if m.step == 20 or m.step == 30 then
        if m.y > p1.y then
          if board.tiles[m.x][m.y-1].faction == m.faction then
            m.y -= 1
          end
        elseif m.y < p1.y then
          if board.tiles[m.x][m.y+1].faction == m.faction then
            m.y += 1
          end
        end
      end
    end,
    hurt = function(amt,this)
      this.hp -= amt
    end,
    faction=faction
  }
end

function new_player(x,y,faction,joy)
  return {
    chips = {},
    rest = 0,
    delay = 3,
    canmove = true,
    x = x,
    y = y,
    z = y,
    joy = joy,
    xdir = 0,
    ydir = 0,
    sprite = 64,
    l = 2.2,
    h = 2.5,
    ox = 2,
    oy = 6,
    stun = 0,
    exploding = 0,
    sl = 0,
    sh = 0,
    charge = 0,
    dmg = 1,
    chg = 20,
    -- lblo = 4,
    -- lbl = 720,
    hp = 720,
    faction = faction,
    callback = function(p)
      p.z = p.y
      --hp logic
      -- if p.hp > p.lbl + 10 then p.lbl+=5
      -- elseif p.hp < p.lbl - 10 then p.lbl-=5

      -- elseif p.hp > p.lbl then p.lbl+=1
      -- elseif p.hp < p.lbl then p.lbl-=1
      -- else
      -- p.lbl = p.hp
      -- end
      --movement

      if p.exploding >= 1 then p.exploding -= 1
        if p.exploding <= 1 then
          game_pause = true
        end
      end

      if p.canmove then
        if (btn(0,p.joy)) then p.xdir = -1
        elseif (btn(1,p.joy)) then p.xdir = 1
        else p.xdir = 0
        end

        if (btn(2,p.joy)) then p.ydir = -1 p.xdir = 0
        elseif (btn(3,p.joy)) then p.ydir = 1 p.xdir =0
        else p.ydir = 0
        end

        --board collision
        if not (0 < p.x+p.xdir and p.x+p.xdir <= board.l) then
          p.xdir = 0
        end
        if not (0 < p.y+p.ydir and p.y+p.ydir <= board.h) then
          p.ydir = 0
        end

        local blocked = false
        for c in all(collisions(entities,{x=p.xdir+p.x,y=p.ydir+p.y})) do
          if c.hp and c != p then
            blocked = true
            break
          end
        end

        --tile permission
        if board.tiles[p.xdir+p.x][p.ydir+p.y].faction ~= p.faction or blocked then
          local c = false
          p.xdir = 0
          p.ydir = 0
        end

        if btn(4,p.joy) then
          p.charge += 1
        else  -- let go
          if p.charge >= 100 then  --charge shot
            add(entities,new_buster(p.x,p.y,p.faction,p.dmg*p.chg,0))
            add(entities,new_muzzle(p,2,1,24,8,{104,88,72}))
            p.rest = p.delay
            p.sprite = 69  --nice
            sfx(00)
            p.l = 3
          elseif p.charge > 0 then  --fire "semi charged"
            add(entities,new_buster(p.x,p.y,p.faction,p.dmg,0))
            add(entities,new_muzzle(p,2,1,24,8,{104,88,72}))
            p.rest = p.delay
            p.sprite = 69  --nice
            sfx(00)
            p.l = 3
          end
          p.charge = 0
        end
      end
      if (p.rest < p.delay and p.sprite == 67) then

        p.sprite = 64
        p.l = 2.2
      end

      if (p.rest == 0) then
        --chip attacks
        if p.chips[1] then
          local backbtns = {1,0}
          local backbtn = backbtns[p.faction + 2]
          if p.chips[2] and btn(5,p.joy) and btn(backbtn,p.joy) then
            local slot = p.chips[1]
            del(p.chips,slot)
            add(p.chips,slot)
            sfx(8)
            p.rest = p.delay
          elseif btn(5,p.joy) then
            local c = p.chips[1]
            del(p.chips,c)
            c.use(c,p)
            p.sprite = 69  --nice
            p.l = 3
            p.rest = p.delay*2
          end
        end
        --directional movement
        if (p.rest < 1) then
          if (p.ydir != 0) then
            p.y += p.ydir
            p.rest = p.delay
            p.sprite = 67
            p.l = 2.2
          elseif (p.xdir != 0) then
            p.x += p.xdir
            p.rest = p.delay
            p.sprite = 67
            p.l = 2.2
          end
        end
      elseif (p.rest > 0) then
        p.rest -= 1
      end
      if p.stun > 0 then
        p.stun -= 1
        if not (p.stun % 2 == 0) then
          p.sh = p.h
          p.sl = p.l
          p.l = 0
          p.h = 0
        else
          p.h = p.sh
          p.l = p.sl
        end
      end
    end,
    draw = function(p,gb)
      local yoff = #p.chips*2 + 14
      for i=#p.chips,1,-1 do
        local chip = p.chips[i]
        spr(
          chip.sprite,
          (p.x*20)-20+p.ox + 6 + gb.startx,
          (p.y*16)-16+p.oy - yoff + gb.starty
        )
        yoff -= 2
        print(chip.name,
          gb.startx + flr(3-2.5*faction)*20,
          gb.starty+(63)+7*i,
          7
        )
      end
    end,
    hurt = function(amt,p)
      if p.stun == 0 then
        p.hp -= amt
        if amt <= 10 then
          sfx(03)
        elseif amt < 40 then
          sfx(04)
        else
          p.stun = 16
          sfx(04)
        end
        if p.hp <= 0 then
          p.hp = 0
          add(entities,new_explosion(p.x,p.y,6))
          del(entities,p)
          p.exploding = 14
        end
      end
    end
  }
end

--game init functions
function init_gameboard()
  local gb = {
    startx = 4,
    starty = 32,
    h = 3,
    l = 6,
    tiles = {}
  }
  local div = 3

  for x=1,gb.l do
    gb.tiles[x] = {}
    for y=1,gb.h do
      local faction = 1
      if (x > 3) then faction = -1 end
      gb.tiles[x][y] = {
        faction=faction,
        lit = false,
        hole = false
      }
    end
  end

  return gb
end

--draw functions

function drawboard(gb)
  local startx,starty = gb.startx,gb.starty
  local spr_ymap = {0,32,2}
  for tx=1,gb.l do
    for ty=1,gb.h do
      if gb.tiles[tx][ty].hole then goto skip end
      --printh(tx .. ", " .. ty)
      local f = gb.tiles[tx][ty].faction
      local lit = gb.tiles[tx][ty].lit
      pal()
      if (f == 1) then
        pal(8,13)  --red to blue
        pal(14,6)  --pink to sky
        pal(4,5)  --brown to grey
      end
      if lit then
        pal(7,10)
        pal(6,10)
      end
      spr(
        spr_ymap[ty],
        startx+(20*(tx-1)),
        starty+(16*ty),
        1.25,
        2)
      spr(
        spr_ymap[ty],
        startx+(20*(tx-0.5)),
        starty+(16*ty),
        1.25,2,
        true)
      --[[if lit then
        color(10)
        rectfill(
        startx+(20*(tx-1) + 3),
        starty+(16*ty) + 3,
        startx+(20*(tx)) - 3,
        starty+(16*(ty+1) - 3)
        )
      end]]

      ::skip::
    end
    --the lit pal carries over
    -- by magic. be careful
    spr(
      60,
      startx+(20*(tx-1)),
      starty+(64),
      1.25,
      1)
    spr(
      60,
      startx+(20*(tx-0.5)),
      starty+(64),  --16*4
      1.25,1,
      true)
  end
  pal()  --necessary? todo
end

function drawent(ent,gb)
  pal()
  if ent.sprite then
    if fget(ent.sprite,0) then
      palt(0,false)
      palt(15,true)
    end
    if ent.faction and ent.faction == -1 then
      --draw flipped
      spr(ent.sprite,
        --gridx * 20 - (xoffset + [flip hack???]) + grid offset
        (ent.x-1)*20 - (ent.ox + (ent.l*8)-20) + gb.startx,
        (ent.y*16)-16+ent.oy + gb.starty,
        ent.l,
        ent.h,1)
    else
      --draw standard
      spr(ent.sprite,
        --gridx * 20 + x offset + grid offset
        (ent.x-1)*20 + (ent.ox) + gb.startx,
        (ent.y*16)-16+ent.oy + gb.starty,
        ent.l,
        ent.h)
    end
    palt()
  end
  if ent.draw then
    ent.draw(ent,gb)
  end
end

function drawents(ents,gb)
  for i=0,4 do
    for ent in all(ents) do
      if ent.z and ent.z == i then drawent(ent,gb) end
    end
  end
  for ent in all(ents) do
    if not ent.z then drawent(ent,gb) end
  end
  for ent in all(ents) do
    if ent.lbl then
      print(ent.lbl,
        (ent.x*20)-20+ent.ox + gb.startx + ent.lblo,
        (ent.y*16)-16+ent.oy + gb.starty -6,
        7  --white
      )
    end
  end
end

--game update functions

function updateents()
  for ent in all(entities) do
    ent.callback(ent)
  end
end

function custom(cust)
  x,y,l,h = 4,1,124,4
  players = {p1,p2}
  foffset = {0,0}
  if cust.val >= cust.max then
    --chip selection
    local chip = random_chip()
    for p in all(players) do
      if #p.chips < 4 then
        add(p.chips,chip)
      end
    end

    cust.val = 0
    cust.inc = 1
  else
    cust.val += cust.inc
  end
  color(9)
  rectfill(x,y,x+((l-x)/cust.max)*cust.val,h)
  color(4)
  rect(x,y,l,h)

  rectfill(
    0,
    1+y+h,
    14,
    1+y+h+6,
    6
  )
  print(
    p1.hp,
    1,
    1+y+h+1,
    1
  )
  rectfill(
    128,
    1+y+h,
    128-14,
    1+y+h+6,
    6
  )
  print(
    p2.hp,
    128-13,
    1+y+h+1,
    1
  )

end

function drawbg()
  --draw the animated background layer
  if not bgoy then bgoy = 0 end
  if not bgox then bgox = 0 end
  local s = 8  --tile size
  palt(0,false)
  for x=1,17 do
    for y=1,17 do
      spr(bg.sprite,(x-2)*s +bgox,(y-2)*s +bgoy,1,1)
    end
  end
  bgoy = (bgoy+bg.bumpy)%s
  bgox = (bgox+bg.bumpx)%s
  --if bgoy >= 4 then bgoy = 0 end
  palt()
end

--game utility functions
function collisions(table,ent)
  local cols = {}
  for item in all(table) do
    if item.x == ent.x and item.y == ent.y then
      add(cols,item)
    end
  end
  return cols
end

--pico-8 base
function _init()
  board = init_gameboard()
  bgs = {
    {sprite=92,bumpx=0,bumpy=0.2},
    {sprite=91,bumpx=2,bumpy=0.2}
  }
  bg = bgs[flr(rnd(#bgs)+1)]
  entities = {}

  game_pause = false

  if debug then
    menuitem(1,"dump",function() dumptable(entities) end)
  end

  p1 = new_player(1,1,1,0)
  add(entities,new_chargeshot(p1))
  add(entities,p1)

  p2 = new_player(6,3,-1,0)
  add(entities,new_chargeshot(p2))
  add(entities,p2)

  cust = {
    val = 0,
    max = 200,
    inc = 30
  }
end

--pico-8 builtins

function _update()
  if not game_pause then
    updateents()
  end
--printh(stat(0))
end

function _draw()
  -- cls()
  drawbg()
  drawboard(board)
  if not game_pause then
    custom(cust)
  end
  drawents(entities,board)
end
__gfx__
884444444800000088888888880000008888888888000000000000000067e000002e200090000000000000000000333333330000000000000000000000000000
88888888440000008e888888880000008e888888880000000000000002eee200062222000990000000000000033bbb3333bbb330000000222200000000000000
88444444dd00000088dddddddd00000088ddd00ddd0000000000a0000de2ed000d222d00009900000000000033b3000000003b33000002222200000000000000
44dddddddd00000084dddddddd00000084dd0000d0000000000a999006d6dd0006d6dd0000099900000000003bb3000000003bb3000004444420000000000000
44dddddddd00000084dddddddd00000084dd00000000000000a99900006dd000006dd00000009aa9a00000003bbb33333333bbb3000044444442000000000000
4866666666000000846666666600000084600000000000000aaa90000066d0000066d00000009a7aaa900000033bbbbbbbbbb330000244444444000000000000
48666666660000008e666666660000008e000000000000000a999990006660000066600000009977777a90000000033333300000000244944944200000000000
48666666660000008e777777770000008e00000000000000aaa9990000060000000600000000097777777a000000000000000000000449999994400000000000
84666666668888008e777777770000008e70000000000000aaa999000006000000060000000009a777422aa00000bbbbbbbb000000044af99f94400000000000
84666666668888008e777777770000008e700000000000000aa99990000600000006000000000097742288740bb777bbbb777bb00004977aa7f9400000000000
84777777770000008e777777770000008e000000000000000aaa900000060000000600000000000a722882eabb7b00000000b7bb0009affffffa400000000000
84777777770000008e777777770000008e0700000000000000aa99000006000000060000000000097288eeeab77b00000000b77b000afffffffa900000000000
84777777770000008e777777770000008e77770007000000000a9990000600000006000000000000a98e2e99b777bbbbbbbb777b002aff7777ff900000000000
88777777770000008e4444777700000088444470770000000000a0000006000000060000000000000a9ee9a00bb7777777777bb0000a77777777400000000000
88888888770000008e8eeeeeee000000888888888800000000000000005550000055500000000000009aa90000000bbbbbb00000000077777775000000000000
8888888888000000eeeeeeeeee000000888888888800000000000000055555000555550000000000000000000000000000000000000000111000000000000000
88888888880000000000000000000000fdddddddddddd6ff00000000000000000000000000000000ccccccc00000000000000000000000000000000000000000
88888888880000000000000000000000fdddddddddddd6ff00000000000000000000000000000000c77cccccccc0000000000000000000000000000000000000
88444444dd0000000000000600000000f6ddddddddddd6ff00000000000000000000000000000000cc77ccccccccc000333b3333333333000000000000000000
88dddddddd0000000000706600000000f666ddddddddd6ff000000000000000000000c00000000000c77ccccccccc000bbbbbbbbbbbbb9300000000000000000
88666666660000000600676670000000f77666ddddddd6ff0000000000000000000ccc7c0000000000c77ccccccc100033333333333333330000000000000000
84666666660000000060667667000000fd11111111111dff000000000000000000cc77cccc000000000c77cccccc100000000000000000000000000000000000
84666666660000006006666677700000fd11111111111dff00000000000000000c7ccccccccc00000000c7cccccc000000000000000000000000000000000000
84666666660000000666676667770000fd11111111111dff0000000000000000ccccccccccccc000000000ccccc0000000000000000000000000000000000000
8d777777770000000066667766776000fd11111111111dff00ccccccc0000000000ccccccccccc00000000000cc0000088888888880000000000000000000000
8d777777770000000776666777666600fd11111111111dffccccccccccc0000000000cccccccccc0000000000000000088488888880000000000000000000000
8e777777770000000067766677667700fd11111111111d0fcccc77777cc000000000000111cccc10000000000000000044dddddd660000000000000000000000
8e777777770000000666777767677770fd11111111111d0f000cccccccc000000000000111111110000000000000000046666666660000000000000000000000
84777777770000000000667776767770fd11111111111d0f0000cccccc0000000000000000111100000000000000000000000000000000000000000000000000
88888888770000007777777766677776fd11111111111d0f0000ccccc00000000000000000111000000000000000000000000000000000000000000000000000
88888888880000000006777766677600fd11111111111d0f00001ccc000000000000000000000000000000000000000000000000000000000000000000000000
88888888880000000066666666000000f00000000000000f00011000000000000000000000000000000000000000000000000000000000000000000000000000
00000000001c1400000000000000000000c04000000000000011c900000000000000000000000000000000000000000000000000000000000000000000000000
0000000001c7c14000000000000000001070100000000000011cc7900000000000000000000000000000000000eeee0000aaaa00000000000000000000000000
00000000149c1c90000000000000001040c0c000000000000141cc10000000000444400000000000000000000e8008e00a9009a0000000000000000000000000
0000000012275c1000000000000000002040c00000000000022971100000000049a9944000000000000000000e0000e00a0000a0000000000000000000000000
000000c104412100000000000000001040101000000000010121e40111c1100049a9944000000000000000000e0000e00a0000a0000000000000000000000000
00000019111111110000000000000090101010100000000c1991111ccc1717100444400000000000000000000e8008e00a9009a0000000000000000000000000
000000491110011c1000000000000090100010c000000001c111111ccc11111000000000000000000000000000eeee0000aaaa00000000000000000000000000
00000011142101111000000000000010401010100000000111410011111110000000000000000000000000000000000000000000000000000000000000000000
0000001112111c1100000000000000102010c01000000001122111c1100000000000000000000000000000006000000003000000000000000050005000000000
0000001cc001111000000000000000c0001010000000000c111ccc11100000000444400000000000000000005555555503000000000005000050005000000000
000000c1111011000000000000000010100010000000001111111111000000004499444000000000000000000000000003000000555550550500005000000000
0000011cc111100000000000000010c010100000000000c111111000000000004a7aa9444000000000000000000000000b000000000000000050005000000000
0000c111ccc111000000000000001010c01010000000011110111100000000004a7aa94440000000000000000000600000000300000000000050005000000000
00011110cc1ccc000000000000101000c0c0c00000001c1c0001cc10000000004499444000000000000000005555555500000300005000000050050000000000
001c1100110111000000000000c01000101010000001c11100001110000000000444400000000000000000000000000000000300550555550050005000000000
0011cc0000011100000000000010c000001010000001ccc000011100000000000000000000000000000000000000000000000b00000000000050005000000000
0011100000011cc100000000001000000010c0100011111000111c11000000000000000000000000000000000000000000000000000000000000000000000000
01c100000001cccc10000000101000000010c0c001cc1000001cccc1000000000aaaa00000000000000000000000000000000000000000000000000000000000
1ccc00000000011100000000c0c00000000010100ccc10000000011100000000aaaaaaa000000000000000000000000000000000000000000000000000000000
c11c0000000000000000000010c00000000000001c1110000000000000000000a7777aaaa0000000000000000000000000000000000000000000000000000000
1111000000000000000000001010000000000000011100000000000000000000a7777aaaa0000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000aaaaaaa000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000aaaa00000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00011000fff00fff000000000aa097a9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c7311d0f5dd000f5555505597a99f99000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
033311d0f56d000f000005009fa90990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1331113105500000000000000999f990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
111113c1000000000000000009ff7fa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ddd3c10f000000f550555559f9999a9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0333c110f000050f005000000aa99aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00011000fff00fff0000000000999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5ffffff55ffffff55ff6fff55ffffff50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000eee00
5fddfff55ff55ff55ff16ff55f6dddf5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000e0
5fdd5df55f5655f555651ff55f66ddf5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000e0
5f555df55f5515f5511515f55f1111f5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000e0
5f556ff55ff55ff5565111555f1111d50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000eee00
5ffffff55ffffff5511111155f1111d5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5ffffff55ffdddf55ffffff55ffffff5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5f1ffff55ffd77d55fff6df55fffddf5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
511177655f6766d55ff6d6f55ffd6df5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
571776d555677fd55d6d6ff555d6dff5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
51716dd55d5dfff556d6fff55d5dfff5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5776ddd555d5fff55d6dfff555d5fff5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5ff11ff55ffddff555ffff5555fddd55000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5f1d11f55f1f6df55fddfff55ffd77d5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5f1161f551d1fdf557dd5d755f6766d5000000000000000000000000000000000000000000000000000000000000000000000aaaaaa000000000000000000000
5ff11ff55fdf1d155f555df555677fd500000000000000000000000000000000000000000000000000000000000000000000aa9999aa00000000000000000000
5ffffff55fd6f1f5575567755d5dfff50000000000000000000000000000000000000000000000000000000000000000000aa999399aa0000000000000000000
5f1111d55ffddff555ffff5555d5ff550000000000000000000000000000000000000000000000000000000000000000000a99393999a0000000000000000000
555555555555555555555555555555550000000000000000000000000000000000000000000000000000000000000000000a999333999a000000000000000000
55555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000000a9979933399a000000000000000000
5ffffff55ffffff55ffffff55ffffff5000000000000000000000000000000000000000000000000000000000000000000a9779939999a000000000000000000
5ffffff55ffffff55ffffff55ffffff5000000000000000000000000000000000000000000000000000000000000000000a7779777799a000aaaaaaaaaaaaaa0
5ffffff55ffffff55ffffff55ffffff5000000000000000000000000000000000000000000000000000000000000000000a7579757799a000aaaaaaaaaaaaaa0
5ffffff55ffffff55ffffff55ffffff50000000000000000000000000000000000000000000000000000000000000000000aaaa77799aa000aaaaaaaaaaaaaa0
5ffffff55ffffff55ffffff55ffffff50000000000000000000000000000000000000000000000000000000000000000000000000aaaa0000aaaaaaaaaaaaaa0
5ffffff55ffffff55ffffff55ffffff5000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaaaaaaaa0
55555555555555555555555555555555000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000
00000a7777a00000000000000000000000000099990000000000005555000000000000000d000000000000000000000000000000000000000000000000000000
000a77777777a0000000000000000000000009aaaa900000000555555555500000000000dd000000000000000000000000000000000000000000000000000000
00a7777777777a000000000000000000009a99999999a900005555555555550000000000dd000000000000000000000000000000000000000eeeeeeeeeeeeee0
0a777777777777a00000004994000000099a99999999a99005555555555555500000000d5d000000000000000600000000000000000000000eeeeeeeeeeeeee0
07777777777777700000049999400000099999aaaa9999900dddd555555dddd00000000d5d000000000000000500000000000000000000000eeeeeeeeeeeeee0
a77777777777777a0044444994444400049999aaaa99994000d0505555050d00ddddddd55d00000000000000d500000000000000000000000eeeeeeeeeeeeee0
7777777777777777049994444449994004444999999444400555500dd0055550005555511555000000000000d500000000000000000000000eeeeeeeeeeeeee0
7777777777777777049994444449994099a9979449799a99555555500555555500005551155555000000000d5500000000000000000000000000000000000000
77777777777777770444444994444440999aaaa99aaaa999dd555555555555dd000000d55ddddddd5ddddddd5500000000000000000000000000000000000000
777777777777777700444444444444009999aa9999aa99990d0d5dddddd5d0d0000000d55000000000555551115d000000000000000000000000000000000000
a77777777777777a0044999449994400444999999999944400d0d0d00d0d0d00000000d5500000000000555111555d1000000000000000000000000000000000
077777777777777000944444444449000444999449994440500d0d0dd0d0d005000000d50000000000000015555555dd00000000000000000000000000000000
0a777777777777a0004444499444440000044449944440000000d0d55d0d0000000000d500000000000000055d00000000000000000000000000000000000000
00a7777777777a00000444499444400000044949949440000000d00dd00d0000000000d000000000000001155111000000000000000000000000000000000000
000a77777777a000000000044000000000004444444400000000000000000000000000d000000000000000111110000000000000000000000000000000000000
00000a7777a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000d66000006d60000000006f000d600000d0000000000000006f000060000000000000000000001d5000010000000000000000000000000000000000
000dd000006776000dd5d6d0000000dd700dd6000d6000000000000000dd700dd7000000000000000d66101dd600d60000000000000000000000000000000000
00d76000056676d00d0005500000000dd66ddd6ddd60000000000dd677ddd7ddd6fddd000000000001ddd6dddd6dd61000000000000000000000000000000000
00dd6d00d7dd676d0005055000676ddddddddddddd600000000000ddddddddddddddd7000000000000ddddddddddddd5dd100000000000000000000000000000
0d7d76d07666766d6500056d00dddddddddddddddddddd6000000066dddddddddddd6f0000000005d6dddddddddddddd66000000000000000000000000000000
006d6d00666676606d50d0d500006dddd15dd51ddddd66000000666dddd15dd51dddddddd00000dddddddd15dd51ddddd1110000000000000000000000000000
000dd00005d666500d50000000766ddd5d0000d5ddd660000006dddddd5d0000d5ddd66700000000ddddd5d0000d5ddddd660000000000000000000000000000
00000000000dd0000006dd0066ddddd5000000001ddddd000000006dd5000000001dd600000000066ddd5000000001dd67600000000000000000000000000000
000d0000000d0000000d000000067ddd00000000dddd6600000066dddd00000000dddddd0000016dddddd00000000dd6d0000000000000000000000000000000
00070000000700000007000000076dddddddddddddd6600000006dddddddddddddddd666d0000111d6ddddddddddddddd1000000000000000000000000000000
0067600000606000000000000066ddddddddddddddddd0000006ddd6ddddddddddddd6660000000066ddddddddddddd666600000000000000000000000000000
d77777d0d70007d0d70007d0006dd06ddd6ddddddddddd00000d0006dddddddddddddd00000000007dd7dddddddddd6ddd000000000000000000000000000000
00676000006060000000000000d0006dd66dddddd0666d000000006ddd6ddd6dd666dd000000000065076dd7ddd66dd100000000000000000000000000000000
0007000000070000000700000000007d006ddd66d00000000000006dd006dd66dd0000000000000010006d117dd0677d10000000000000000000000000000000
000d0000000d0000000d00000000000d0006dd006d000000000000000006dd006dd000000000000000006d0016d0001110000000000000000000000000000000
000000000000000000000000000000000000f000000000000000000000006d000600000000000000000001000050000000000000000000000000000000000000

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
000000000000000000003d3d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000003d3d3d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000003d3d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000003d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000003d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000003d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000003d3d3d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000003d3d3d3d3d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000003d3d3d3d3d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00030000004003a4502b4501940018400164001e4002240024400284002e400334003340027400184001140000400004000040000400004000040000400004000040000400004000040000400004000040000400
010c0000184220c4121c432104221e422124122443218422284221c4122a4321e4220000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002
010a00001f452132421f452132321f452132221f45213212000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002
01030000376401c640006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
010300003b2523b2523b2523b25235253302532725200202002020020200202002020020200202002020020200202002020020200202002020020200202002020020200202002020020200202002020020200202
010600003625136250342502825027250282500000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001
010500000a2600a260032600226000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
010f00001d2501b230182200220000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
010400003605436050310550000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000213021f3021f3021f302213021a3021f302000001d30200000000001b3020000021302000001f30200000000002130200000000001f30200000000001d30200000000000000000000000000000000000
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
00 0a0b4344
00 41424344
00 41424344
00 41424344
00 41424744
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

