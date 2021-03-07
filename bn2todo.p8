pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

--by giovanh

--[[
known issues:
ratton needs a chip icon
ui fanfare for deletion
controls not locking after deletion
chip ideas:
  boomerang
  health recovery
  zapring
  buster up
  invis
  
ignoring issues:
areagrabs can cross with frame-perfect inputs and mirrored player coords
]]

--globals

debug = true

--utility functions

function dumptable(tab,ind)
  if not ind then ind = "" end  
  --dumps object tab to console
  printh(ind .. "{")
  for k,v in pairs(tab) do
	  local b = (type(tab[k]) == "boolean")
	  if b == true then
      local v = ""
      if tab[k] then
        v = "true"
      else
        v = "false"
      end
      printh(ind .. k .. ": " .. v)
    elseif type(tab[k]) == "function" then
      printh(ind .. k .. ": function " .. k .. "()")
    elseif type(tab[k]) != "table" then
      printh(ind .. k .. ": " .. tab[k])
    else
      printh(ind .. k .. ": ")
      dumptable(tab[k],ind .. " ")
    end
  end
  printh(ind .. "}")
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
    name = "★cann",
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
    name = "a-grab",
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
    name = "sword ",
    weight = 1,
    sprite = 147,
    dmg = 80,
    use = function(c,p)
      add(entities,new_sword(p,1,1,c.dmg))
    end
  },
  {
    name = "w-swrd",
    weight = 2,
    sprite = 145,
    dmg = 80,
    use = function(c,p)
      add(entities,new_sword(p,2,1,c.dmg))
    end
  },
  {
    name = "l-swrd",
    weight = 2,
    sprite = 146,
    dmg = 80,
    use = function(c,p)
      add(entities,new_sword(p,1,2,c.dmg))
    end
  },
  {
    name = "★swrd",
    weight = 1,
    sprite = 163,
    dmg = 80,
    use = function(c,p)
      add(entities,new_sword(p,2,2,c.dmg))
    end
  },
  {
    name = "cube  ",
    weight = 1,
    sprite = 131,
    use = function(c,p)
      add(entities,new_cube(p,100))
    end
  },
  {
    name = "bomb  ",
    weight = 4,
    sprite = 129,
    dmg = 80,
    use = function(c,p)
      add(entities,new_ball(p,c.dmg,false,1))
    end
  },
  {
    name = "breakr",
    weight = 2,
    sprite = 160,
    dmg = 120,
    use = function(c,p)
      add(entities,new_ball(p,c.dmg,true,2))
    end
  },
  {
    name = "ratton",
    weight = 2,
    sprite = 177,
    dmg = 80,
    use = function(c,p)
      add(entities,new_rat(p,c.dmg))
    end
  },
  {
    name = "chips+",
    weight = 1,
    sprite = 161,
    use = function(c,p)
      p.chips = {}
      for i=1,3+flr(rnd(3)) do
        add(p.chips,random_chip())
      end
    end
  },
  {
    name = "meteor",
    weight = 1,
    sprite = 178,
    dmg = 100,
    use = function(c,p)
      add(entities,new_meteowand(p,c.dmg))
    end
  },
  {
    name = "burner",
    weight = 1,
    sprite = 148,
    dmg = 80,
    use = function(c,p)
      add(entities,new_burner(p,c.dmg,16))
    end
  },
  {
    name = "lance ",
    weight = 1,
    sprite = 149,
    dmg = 120,
    use = function(c,p)
	for y=1,3 do
		add(entities,new_lance(p.faction,c.dmg,y))
	  end
    end
  },
  {
    name = "shurik",
    weight = 1,
    sprite = 180,
    dmg = 120,
    use = function(c,p)
		local tx,ty=3,2
		for x=1,board.l do
			for y=1,board.h do
			  for c in all(collisions(entities,{x=x,y=y})) do
				if c.hp and c.faction != p.faction then
				  tx,ty=x,y
				end
			  end
			end
		end
		add(entities,new_targetmissile(2,c.dmg,p.faction,tx,ty))
    end
  }
}



weightedchips = {}
for chip in all(chips) do
  if not chip.weight then chip.weight = 200 end
  if chip.dmg then
  printh(chip.name .. "\t" .. chip.dmg .. "\t" .. chip.weight,"chips.log")
  else
  printh(chip.name .. "\tnil" .. "\t" .. chip.weight,"chips.log")
  end
  for i = 1, chip.weight do
    add(weightedchips, chip)
  end
end

function random_chip()
  -- local i =
  --return chips[flr(rnd(#chips))+1]
  return chips[#chips]
  --return weightedchips[flr(rnd(#weightedchips))+1]
end

--constructors

function new_lance(f,dmg,y)
	return {
		sprite=044,
		l=2,
		h=1,
		x=3.5+2.5*f,
		y=y,
		ox=16,
		hold = 0,
		faction=f,
		damage=dmg,
		oy=10,
		z=y,
		callback = function(this)
			if this.ox > 8 then 
				this.ox -= 4
			else 
				this.hold += 1
				if this.hold == 8 then
					del(entities,this)
					return
				end
			end
			if this.ox >= 12 then
				for c in all(collisions(entities,this)) do
				  if c.faction != this.faction and c.hp and this.damage > 0 then
					c.hurt(this.damage,c)
				  end
				end
			end
		end
	}
end

function new_targetmissile(skin,dmg,f,x,y)
  local skins = {009,200}
  local rox = 0
  local roy = 10
  b = {
    x=x,
    z=y,
    y=y,
    sprite=skins[skin],
    l=2,
    h=2,
	roy = roy,
	rox = rox,
    oy=roy-128,
    ox=(rox-160) ,
    faction = f,
    damage = dmg,
    callback = function(b)
	board.tiles[b.x][b.y].lit = true
      if b.oy == b.roy or b.ox == b.rox then  --if landed
        local hit = false
        for c in all(collisions(entities,b)) do
          if c.faction != b.faction and c.hp and b.damage > 0 then
            c.hurt(b.damage,c)
            hit = true
          end
        end
	    board.tiles[b.x][b.y].lit = false
	    -- if b.brk and not hit then
	  	  -- printh("making a hole at" .. b.x .. "," .. b.y)
	  	  -- add(entities,new_hole(b.x,b.y))
	    -- end
		if skin == 2 then 
			add(entities,new_muzzle(b,2,2,b.ox,b.oy,{202,202,202,202,202,202,204,202}))
		end
	    add(entities,new_explosion(b.x,b.y,2))
        del(entities,b)
        return
      else  --flying
        b.ox += 10
        b.oy += 8
      end
    end
  }
  return b
end

function new_meteowand(p,dmg)
  local x = p.x+p.faction
  local h = 30
  for c in all(collisions(entities,{x=x,y=p.y})) do
    if c.hp then
      h = 0
    end
  end
  if board.tiles[x][p.y].hole then h = 0 end
  return {
    x=x,
    y=p.y,
    sprite=007,
    l=1,
    h=0,
    z=p.y,
	dmg=dmg,
    oy=12,
    ox=6,
	lifespan=320,
    hp = h,
    --lbl = hp,
    --lblo = 2,
    stun = 0,
    faction = p.faction,
    callback = function(this)
      if this.stun > 0 then this.stun -= 1 end
      if this.h < 2 then this.h += 0.5 end
      if this.h > 2 then this.h = 2 end
      --this.lbl = this.hp
	  this.lifespan -= 1
	  if this.lifespan % 14 == 0 then
	    this.sprite = 007
		
		local tiles = {}
		for x=1,board.l do
			for y=1,board.h do
			  if board.tiles[x][y].faction != this.faction then
				add(tiles,{x=x,y=y})
			  end
			end
		end
		local tile = tiles[flr(rnd(#tiles))+1]
	    local x,y = tile.x,tile.y
		--add(entities,new_ball({x=x-(3*this.faction),y=y,faction=this.faction},80,true,1))
		add(entities,new_targetmissile(1,this.dmg,this.faction,x,y))
	  else
	    this.sprite = 008
	  end
	  
      if this.hp <= 0 or this.lifespan <= 0 then del(entities,this) add(entities,new_explosion(this.x,this.y,2)) end
    end,
    hurt = function(dmg,this)
      if this.stun == 0 then
        this.hp -= dmg
        if dmg > 40 then this.stun = 4 end
      end
    end
  }
end

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
  if board.tiles[x][y].hole then h = 0 end
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
    -- lbl = hp,
    -- lblo = 2,
    stun = 0,
    faction = 0,
    callback = function(this)
      if this.stun > 0 then this.stun -= 1 end
      if this.h < 2 then this.h += 0.2 end
      if this.h > 2 then this.h = 2 end
      --this.lbl = this.hp
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


function new_burner(p,dmg,delay)
  
  return {
    x=p.x,
    y=p.y,
    z=y,
    sprite=13,
    l=2,
    h=2,
    oy=10,
    ox=2,
    faction = p.faction,
    delay = delay,
    wait = 0,
    damage = dmg,
    callback = function(b)
		if b.wait == 0 then
		  board.tiles[b.x][b.y].lit = false
		  b.x += b.faction
		  if b.y < p.y then
			b.y += 1
		  elseif b.y > p.y then
			b.y -= 1
		  end
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
  if board.tiles[x][y].hole then return end
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
      if this.hold == 1 then
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
    sprite=114,
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
              if c.y > b.y then b.turned = 1
              elseif c.y < b.y then b.turned = -1 end
              b.ox = 5
            end
          end
        end
      else
        b.oy += 3 * b.turned
        if b.oy >= 16 or b.oy <= 0 then
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
			printh("making a hole at" .. b.x .. "," .. b.y)
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
    sprite=0,
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
    faction=faction,
    hp = 1000,
    lbl=100,
    lblo=0,
    l=2,
    h=2,
    ox=2,
	chips={},
    oy=12,
    rest=50+(faction*25),
    x=x,
    y=y,
    callback=function(m)
      m.z=m.y
      --hp
      m.lbl = m.hp
      --ai
	  local xdir,ydir = 0,0
      m.step += 1
      if m.step <= 60 and m.step%10==0 then
		--avoid player
        if p1.y == m.y then
			ydir = 1-flr(rnd(3))
		end
        if p1.x - m.faction*3 == m.y then
			xdir = 1-flr(rnd(3))
		end
      end
      if m.step >= 70 and m.step <= 90 and m.step%10 == 0 then
        if p1.y != m.y then
			if p1.y > m.y then
				ydir = 1
			elseif p1.y < m.y then
				ydir = -1
			end
		end
		
        if p1.y +3 != m.y then
			if p1.x - m.faction*3> m.x then
				xdir = 1
			elseif p1.x - m.faction*3 < m.x then
				xdir = -1
			end
		end
      end
	  
	  
	if not (0 < m.x+xdir and m.x+xdir <= board.l) then
	  xdir = 0
	end
	if not (0 < m.y+ydir and m.y+ydir <= board.h) then
	  ydir = 0
	end
	
        --tile permission
        if board.tiles[xdir+m.x][ydir+m.y].faction ~= m.faction then
          xdir = 0
          ydir = 0
        end
	  
	  if ydir != 0 then
		m.y += ydir
	  elseif xdir != 0 then
		m.x += xdir
	  end
	  
	  if m.step >= 95 then
	    local chip = random_chip()
		chip.use(chip,m)
		m.step = 0
	  end
    end,
    hurt = function(amt,this)
      this.hp -= amt
    end
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
        if btn(0,p.joy) then p.xdir = -1
        elseif btn(1,p.joy) then p.xdir = 1
        else p.xdir = 0
        end

        if btn(2,p.joy) then p.ydir = -1 p.xdir = 0
        elseif btn(3,p.joy) then p.ydir = 1 p.xdir =0
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
            add(entities,new_muzzle(p,2,1,24,8,{119,117,115}))
            p.rest = p.delay
            p.sprite = 69  --nice
            sfx(00)
            p.l = 3
          elseif p.charge > 0 then  --fire "semi charged"
            add(entities,new_buster(p.x,p.y,p.faction,p.dmg,0))
            add(entities,new_muzzle(p,2,1,24,8,{119,117,115}))
            p.rest = p.delay
            p.sprite = 69  --nice
            sfx(00)
            p.l = 3
          end
          p.charge = 0
        end
      end
      if p.rest < p.delay and p.sprite == 67 then

        p.sprite = 64
        p.l = 2.2
      end

      if p.rest == 0 then
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
        if p.rest < 1 then
          if p.ydir != 0 then
            p.y += p.ydir
            p.rest = p.delay
            p.sprite = 67
            p.l = 2.2
          elseif p.xdir != 0 then
            p.x += p.xdir
            p.rest = p.delay
            p.sprite = 67
            p.l = 2.2
          end
        end
      elseif p.rest > 0 then
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
		local lbl = chip.name
		if chip.dmg then lbl = lbl .. " " .. chip.dmg end
        spr(
          chip.sprite,
          (p.x*20)-20+p.ox + 6 + gb.startx,
          (p.y*16)-16+p.oy - yoff + gb.starty
        )
        yoff -= 2
        print(lbl,
          gb.startx + flr(2-1.5*faction)*20,
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
    starty = 32-8,
    h = 3,
    l = 6,
    tiles = {}
  }
  local div = 3

  for x=1,gb.l do
    gb.tiles[x] = {}
    for y=1,gb.h do
      local faction = 1
      if x > 3 then faction = -1 end
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
      if f == 1 then
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
        --add(p.chips,chip)
        add(p.chips,random_chip())
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
  entities = {}

  game_pause = false

  if debug then
    menuitem(1,"dump",function() dumptable(entities) end)
  end

  p1 = new_player(1,1,1,0)
  add(entities,new_chargeshot(p1))
  -- p1 = new_methat(1,1,1,0)
  add(entities,p1)

  p2 = new_methat(6,3,-1,0)
  --add(entities,new_chargeshot(p2))
  add(entities,p2)
  -- p2 = new_player(6,3,-1,0)
  -- add(entities,new_chargeshot(p2))
  -- add(entities,p2)

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
88444444480000008888888888000000888888888800000000000000ff67efffff2e2fff90000000000000000000333333330000000000000000000000000000
88888888440000008e888888880000008e8888888800000000000000f2eee2fff62222ff0990000000000000033bbb3333bbb330000000222200000000000000
88444444dd00000088dddddddd00000088ddd00ddd0000000000a000fde2edfffd222dff009900000000000033b3000000003b33000002222200000000000000
44dddddddd00000084dddddddd00000084dd0000d0000000000a9990f6d6ddfff6d6ddff00099900000000003bb3000000003bb3000004444420000000000000
44dddddddd00000084dddddddd00000084dd00000000000000a99900ff6ddfffff6ddfff00009aa9a00000003bbb33333333bbb3000044444442000000000000
4866666666000000846666666600000084600000000000000aaa9000ff66dfffff66dfff00009a7aaa900000033bbbbbbbbbb330000244444444000000000000
48666666660000008e666666660000008e000000000000000a999990ff666fffff666fff00009977777a90000000033333300000000244944944200000000000
48666666660000008e777777770000008e00000000000000aaa99900fff6fffffff6ffff0000097777777a000000000000000000000449999994400000000000
84666666660000008e777777770000008e70000000000000aaa99900fff6fffffff6ffff000009a777422aa00000bbbbbbbb000000044af99f94400000000000
84666666660000008e777777770000008e700000000000000aa99990fff6fffffff6ffff00000097742288740bb777bbbb777bb00004977aa7f9400000000000
84777777770000008e777777770000008e000000000000000aaa9000fff6fffffff6ffff0000000a722882eabb7b00000000b7bb0009affffffa400000000000
84777777770000008e777777770000008e0700000000000000aa9900fff6fffffff6ffff000000097288eeeab77b00000000b77b000afffffffa900000000000
84777777770000008e777777770000008e77770007000000000a9990fff6fffffff6ffff00000000a98e2e99b777bbbbbbbb777b002aff7777ff900000000000
88777777770000008e4444777700000088444470770000000000a000fff6fffffff6ffff000000000a9ee9a00bb7777777777bb0000a77777777400000000000
88888888770000008e8eeeeeee000000888888888800000000000000ff555fffff555fff00000000009aa90000000bbbbbb00000000077777775000000000000
8888888888000000eeeeeeeeee000000888888888800000000000000f55000fff55500ff00000000000000000000000000000000000000111000000000000000
88888888880000000000000000000000fdddddddddddd6ff00000000000000000000000000000000ccccccc00000000000000000000000000000000000000000
88888888880000000000000000000000fdddddddddddd6ff00000000000000000000000000000000c77cccccccc0000000000000000000000000000000000000
88444444dd0000000000000600000000f6ddddddddddd6ff00000000000000000000000000000000cc77ccccccccc000003333333333b3330000000000000000
88dddddddd0000000000706600000000f666ddddddddd6ff000000000000000000000c00000000000c77ccccccccc000039bbbbbbbbbbbbb0000000000000000
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
00000000001c1400000000000000000000c04000000000000011c900000000000000000000000000000000000000000000000000030000000000000003000000
0000000001c7c14000000000000000001070100000000000011cc7900000000000000000000000000000000000eeee0000aaaa00030000000000000003000000
00000000149c1c90000000000000001040c0c000000000000141cc10000000000000000000000000000000000e8008e00a9009a0030000000000333b03000000
0000000012275c1000000000000000002040c0000000000002297110000000000000000000000000000000000e0000e00a0000a00b000000000000000b000000
000000c104412100000000000000001040101000000000010121e40111c110000000000000000000000000000e0000e00a0000a0000003000000000000000300
00000019111111110000000000000090101010100000000c1991111ccc1717100000000000000000000000000e8008e00a9009a0000003000000000000000300
000000491110011c1000000000000090100010c000000001c111111ccc11111000000000000000000000000000eeee0000aaaa0000000300333b000000000300
0000001114210111100000000000001040101010000000011141001111111000000000000000000000000000000000000000000000000b000000000000000b00
0000001112111c1100000000000000102010c01000000001122111c1100000000000000000000000000000000000000000000000000000000000000000000000
0000001cc001111000000000000000c0001010000000000c111ccc11100000000000000000000000000000000000000000000000000000000000000000000000
000000c1111011000000000000000010100010000000001111111111000000000000000000000000000000000000000000000000000000000000000000000000
0000011cc111100000000000000010c010100000000000c111111000000000000000000000000000000000000000000000000000000000000000000000000000
0000c111ccc111000000000000001010c01010000000011110111100000000000000000000000000000000000000000000000000000000000000000000000000
00011110cc1ccc000000000000101000c0c0c00000001c1c0001cc10000000000000000000000000000000000000000000000000000000000000000000000000
001c1100110111000000000000c01000101010000001c11100001110000000000000000000000000000000000000000000000000000000000000000000000000
0011cc0000011100000000000010c000001010000001ccc000011100000000000000000000000000000000000000000000000000000000000000000000000000
0011100000011cc100000000001000000010c0100011111000111c11000000000000000000000000000000000000000000000000000000000000000000000000
01c100000001cccc10000000101000000010c0c001cc1000001cccc1000000000000000000000000000000000000000000000000000000000000000000000000
1ccc00000000011100000000c0c00000000010100ccc100000000111000000000000000000000000000000000000000000000000000000000000000000000000
c11c0000000000000000000010c00000000000001c11100000000000000000000000000000000000000000000000000000000000000000000000000000000000
11110000000000000000000010100000000000000111000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00011000fff00fff0aa097a900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c7311d0f5dd000f97a99f99000000000000000004444000000000000aaaa0000000000000000000000000000000000000000000000000000000000000000000
033311d0f56d000f9fa9099004444000000000004499444000000000aaaaaaa00000000000000000000000000000000000000000000000000000000000000000
13311131055000000999f99049a99440000000004a7aa94440000000a7777aaaa000000000000000000000000000000000000000000000000000000000000000
111113c10000000009ff7fa049a99440000000004a7aa94440000000a7777aaaa000000000000000000000000000000000000000000000000000000000000000
0ddd3c10f000000f9f9999a904444000000000004499444000000000aaaaaaa00000000000000000000000000000000000000000000000000000000000000000
0333c110f000050f0aa99aa0000000000000000004444000000000000aaaa0000000000000000000000000000000000000000000000000000000000000000000
00011000fff00fff0099990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000
5ffffff55ffffff55ff6fff55ffffff55fff6d655ffffff500000000000000000000000000000000000000000000000000000000000000000000000000000000
5fddfff55ff55ff55ff16ff55f6dddf55fffdd655ffddff500000000000000000000000000000000000000000000000000000000000000000000000000000000
5fdd5df55f5655f555651ff55f66ddf556dffd655fdf7df500000000000000000000000000000000000000000000000000000000000000000000000000000000
5f555df55f5515f5511515f55f1111f55dddfd655fd7fdf500000000000000000000000000000000000000000000000000000000000000000000000000000000
5f556ff55ff55ff5565111555f1111d556dfddd55fd66df500000000000000000000000000000000000000000000000000000000000000000000000000000000
5ffffff55ffffff5511111155f1111d55f6f66655ffffff500000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000
5ffffff55ffdddf55ffffff55ffffff55fdfdfd55ffffff500000000000000000000000000000000000000000000000000000000000000000000000000000000
5f1ffff55ffd77d55fff6df55fffddf55d5d5d555ff6666500000000000000000000000000000000000000000000000000000000000000000000000000000000
511177655f6766d55ff6d6f55ffd6df555f5f5f55fd1d11500000000000000000000000000000000000000000000000000000000000000000000000000000000
571776d555677fd55d6d6ff555d6dff55f6f6f655d11111500000000000000000000000000000000000000000000000000000000000000000000000000000000
51716dd55d5dfff556d6fff55d5dfff556d6d6d55ffffff500000000000000000000000000000000000000000000000000000000000000000000000000000000
5776ddd555d5fff55d6dfff555d5fff55dfdfdf55ffffff500000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000
5ff11ff55ffddff555ffff5555fddd555f6666f55ffffff500000000000000000000000000000000000000000000000000000000000000000000000000000000
5f1d11f55f1f6df55fddfff55ffd77d556dddd655ffffff500000000000000000000000000000000000000000000000000000000000000000000000000000000
5f1161f551d1fdf557dd5d755f6766d55dffffd55ffffff500000000000000000000000000000000000000000000000000000aaaaaa000000000000000000000
5ff11ff55fdf1d155f555df555677fd555dddd555ffffff50000000000000000000000000000000000000000000000000000aa9999aa00000000000000000000
5ffffff55fd6f1f5575567755d5dfff55f5555f55ffffff5000000000000000000000000000000000000000000000000000aa993999aa0000000000000000000
5f1111d55ffddff555ffff5555d5ff555ffffff55ffffff5000000000000000000000000000000000000000000000000000a99939399a0000000000000000000
55555555555555555555555555555555555555555555555500000000000000000000000000000000000000000000000000a999333999a0000000000000000000
55555555555555555555555555555555555555555555555500000000000000000000000000000000000000000000000000a9933399799a000000000000000000
5ffffff55ffffdf5566ffff5566666655ffdfff55ffffff500000000000000000000000000000000000000000000000000a9999399779a000000000000000000
55df5df55f6fd1d55fdd6ff55ddddd655f6566f55ffffff500000000000000000000000000000000000000000000000000a9977779777a000000000000000000
555655f556dd11155f6dd6f55ffffd655f6555d55ffffff500000000000000000000000000000000000000000000000000a9977579757a000000000000000000
5d555df55d6dd1655ffd55d55ffffd655d5556f55ffffff500000000000000000000000000000000000000000000000000aa99777aaaa0000000000000000000
56d5d6f55ddddd155ffd55d5566666655f6656f55ffffff5000000000000000000000000000000000000000000000000000aaaa0000000000000000000000000
5f6d6ff55f6666f55fffddf55dddddd55fffdff55ffffff500000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000
00000a7777a00000000000000000000000000099990000000000005555000000000000000d000000000000000000000000000000000000000000000000000000
000a77777777a0000000000000000000000009aaaa900000000555555555500000000000dd000000000000000000000000000000000000000000000000000000
00a7777777777a000000000000000000009a99999999a900005555555555550000000000dd000000000000000000000000000000000000000000000000000000
0a777777777777a00000004994000000099a99999999a99005555555555555500000000d5d000000000000000600000000000000000000000000000000000000
07777777777777700000049999400000099999aaaa9999900dddd555555dddd00000000d5d000000000000000500000000000000000000000000000000000000
a77777777777777a0044444994444400049999aaaa99994000d0505555050d00ddddddd55d00000000000000d500000000000000000000000000000000000000
7777777777777777049994444449994004444999999444400555500dd0055550005555511555000000000000d500000000000000000000000000000000000000
7777777777777777049994444449994099a9979449799a99555555500555555500005551155555000000000d5500000000000000000000000000000000000000
77777777777777770444444994444440999aaaa99aaaa999dd555555555555dd000000d55ddddddd5ddddddd5500000000000000000000000000000000000000
777777777777777700444444444444009999aa9999aa99990d0d5dddddd5d0d0000000d55000000000555551115d000000000000000000000000000000000000
a77777777777777a0044999449994400444999999999944400d0d0d00d0d0d00000000d5500000000000555111555d1000000000000000000000000000000000
077777777777777000944444444449000444999449994440500d0d0dd0d0d005000000d50000000000000015555555dd00000000000000000000000000000000
0a777777777777a0004444499444440000044449944440000000d0d55d0d0000000000d500000000000000055d00000000000000000000000000000000000000
00a7777777777a00000444499444400000044949949440000000d00dd00d0000000000d000000000000001155111000000000000000000000000000000000000
000a77777777a000000000044000000000004444444400000000000000000000000000d000000000000000111110000000000000000000000000000000000000
00000a7777a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000d66000006d600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000dd000006776000dd5d6d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00d76000056676d00d00055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00dd6d00d7dd676d0005055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d7d76d07666766d6500056d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
006d6d00666676606d50d0d500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000dd00005d666500d50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000dd0000006dd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000d0000000d0000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00070000000700000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00676000006060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d77777d0d70007d0d70007d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00676000006060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00070000000700000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000d0000000d0000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000001010000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000
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
__sfx__
00030000004003a4502b4501940018400164001e4002240024400284002e400334003340027400184001140000400004000040000400004000040000400004000040000400004000040000400004000040000400
010c0000184220c4121c432104221e422124122443218422284221c4122a4321e4220000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002
010a00001f452132421f452132321f452132221f45213212000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002
01030000376401c640006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
010300003b2523b2523b2523b25235253302532725200202002020020200202002020020200202002020020200202002020020200202002020020200202002020020200202002020020200202002020020200202
010600003625136250342502825027250282500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010500000a2600a260032600226000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
010f00001d2501b230182200220000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
010400003605436050310550000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000213021f3021f3021f302213021a3021f302000001d30200000000001b3020000021302000001f30200000000002130200000000001f30200000000001d30200000000000000000000000000000000000
__music__
00 0a0b4344
00 41424344
00 41424344
00 41424344
00 41424744

