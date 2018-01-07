pico-8 cartridge // http://www.pico-8.com
version 15
__lua__
-- bomberfun
-- by droune

--[[ todo:

 [render]
 - bigger characters
 - character animations (3 sprites per anim)
 - animations mode: one_shot, loop, reverse.
  
 [gui]
  - nb cups per player
  - remaining time
  - cups screen
  - menu screen: add nb cups goal.
  - add transition states between screens.
 
 [gameplay]
 - winning conditions for 1 match/cup
  - kill player by sudden death
  - timer -> "draw"
 - winning condition = first to max cups
 - dying = scatter powerups.

 [opt]
 - push bombs power
 - shoot bombs power
 - a.i.
]]
state=0 -- 0=menu, 1=game, 2=endgame
-- todo: add transitional states
players={}
bombs={}
explosions={}
pickups={} -- active powerups on field
tiles={} -- tile map by name, stores id, bbox and flags.
maps={}
powerups={}
debug_rects={} -- map space pixels {x0,y0,x1,y1,color}

g_nb_players = 2 -- 2..4
g_twp = 8 -- global tile width in pixels
g_mop = {x=12,y=12} -- global map offsets in pixels
g_tlc = 13 -- global number of tile lines
g_tcc = 13 -- global number of tile columns

g_pu_bomb = 1
g_pu_speed = 2
g_pu_fire = 3

g_max_pu_bomb = 5
g_max_pu_speed = 3
g_max_pu_fire = 12 -- maybe have a non-linear progress? quadratic?

g_winning_player = 0

g_bomb_timeout = 2 -- nb seconds before explosion
g_explosion_duration = 0.8 -- nb seconds during which fire is harmful
g_pickup_timeout = 8 -- nb seconds before pickup disappears

--
-- init/create
--

function init_tiles()
 tiles = {}
 -- idx: base tile index in pico8 tileset.
 -- tag: is collidable
 -- d: is destructible
 -- bbox: x/y coordinates are top-left integer coords of pixels
 --       x+w and y+h gives the end of the bbox
 --       x+(w-1) and y+(h-1) gives the coords of top-left of the max pixels.
 tiles["exterior_wall"] = {idx=-1,tag=1,d=0,bbox={x=0,y=0,w=8,h=8}} -- fake tile that acts like a wall
 
 tiles["player"] = {idx=0,tag=1,d=0,bbox={x=1,y=2,w=5.9,h=5.9}}
 
 tiles["wall"] = {idx=48,tag=1,d=1,bbox={x=1,y=1,w=6,h=6}}
 tiles["floor"] = {idx=49,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["wood_plot"] = {idx=35,tag=1,d=1,bbox={x=0,y=0,w=8,h=8}}
 tiles["hard_wall"] = {idx=36,tag=1,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["champi"] = {idx=20,tag=1,d=1,bbox={x=0,y=0,w=8,h=8}}
 
 tiles["pu_bomb"] = {idx=16,tag=0,d=1,bbox={x=0,y=0,w=8,h=8}}
 tiles["pu_speed"] = {idx=17,tag=0,d=1,bbox={x=0,y=0,w=8,h=8}}
 tiles["pu_fire"] = {idx=18,tag=0,d=1,bbox={x=0,y=0,w=8,h=8}}
 
 tiles["block_expl"] = {idx=59,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_center"] = {idx=44,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_hor"] = {idx=45,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_ver"] = {idx=28,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_left_end"] = {idx=43,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_right_end"] = {idx=46,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_top_end"] = {idx=12,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_bottom_end"] = {idx=60,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
end

function init_powerups()
 powerups = {}
 add(powerups, {t="pu_bomb"})
 add(powerups, {t="pu_speed"})
 add(powerups, {t="pu_fire"})
end

function is_starting_player_area(l,c)
 -- todo(nfauvet): make it based off g_tlc and g_tcc
 local starting_tiles = { 
  -- 1-based
  {1,1},{1,2},{2,1}, -- player 1
  {1,13},{1,12},{2,13}, -- player 2
  {13,1},{13,2},{12,1}, -- player 3
  {13,13},{13,12},{12,13}  -- player 4
 }
 
 for st in all(starting_tiles) do
  if ( l == st[1] and c == st[2] ) return true
 end
 return false
end

-- 0-based pixel map position [0..96]
function player_starting_position(index)
 -- 1-based grid position [1..13]
 -- todo(nfauvet): use g_tlc/tcc
 local sp = {
  {x=1, y=1},
  {x=13,y=1},
  {x=1, y=13},
  {x=13,y=13}
 }
 -- 0-based pixel map position [0..96]
 -- todo(nfauvet): use g_twp
 local pixel_position = { 
  x = 8 * ( sp[index].x - 1 ),
  y = 8 * ( sp[index].y - 1 ) 
 }
 return pixel_position
end

function create_player( index )
 local p = {}
 p.index = index -- 1-based, 1,2,3,4
 p.is_alive = 1
 p.x = player_starting_position(index).x -- in pixel map space [0..12*8=96]
 p.y = player_starting_position(index).y
 p.spr_index = tiles["player"].idx -- note: tiles must be init
 p.pu = {b=0,s=0,f=0} -- bomb, speed, fire
 p.has_bombs_left = 1
 p.bomb_intensity = 1
 -- SLOW: 200 8 -- keep it for a slowdown pickup
 -- normal: 400 10
 -- x2: 800 14
 -- x4: 1600 22
 -- x8: 3200 38
 -- formulae = 2^(powerup)*100, 6+2^pu
 p.speed = 400
 p.drag = 10
 p.dx = 0
 p.dy = 0
 p.tag = 0
 p.face = 3 -- facing direction
 p.anim = "idle"
 p.anim_time = 0
 -- d = current direction (for reflect model)
 -- m = model -> 0 = one shot, 1 = reflect loop, 2 = modulo loop
 p.anims = { 
  ["idle"] = {f=0,d=1,m=2,st=65,sz=1,spd=1},
  ["walk"] = {f=0,d=1,m=1,st=64,sz=3,spd=1/3},
  ["death"] = {f=0,d=1,m=0,st=64,sz=1,spd=1/15}
 }
 return p
end

function init_players()
 players = {}
 for i=1,g_nb_players do
  players[i] = create_player(i)
 end
end

function init_map()
 maps = {}
 local map0 = {}
 for l=1,g_tlc do
  for c=1,g_tcc do
   local ti = (l-1) * g_tcc + c;
   
   -- default state
   map0[ti] = {t="floor",o=0,f=0,b=0}
   
   if c%2==0 and l%2==0 then
    map0[ti].t = "hard_wall" -- grid of hard indestructible tiles
   elseif not is_starting_player_area(l,c) then
    local is_there_a_tile = ( 2 > rnd(3) )
    if is_there_a_tile then
     local rnd_object = max(0,flr(rnd(12) - 8.5)) -- 3/4 chance to have 0, then 1,2,3
     map0[ti].o = rnd_object -- hide a random object inside the block.
     if rnd(2) > 1 then
	     map0[ti].t = "champi"
	    else
	     map0[ti].t = "wood_plot"
	    end
    end 
   end
   
  end
 end
 add(maps,map0)
end

function reset_game()
 --players={}
 bombs={}
 explosions={}
 pickups={} -- active powerups on field
 --tiles={} -- tile map by name, stores id, bbox and flags.
 --maps={}
 --powerups={}
 debug_rects={}
end

function init_game()
 --music(0)
 reset_game() 
 init_powerups()
 init_tiles()
 init_map()
 init_players()
end

--
-- update
--

function bomb_at(c,l)
 if c < 1 or c > g_tcc or l < 1 or l > g_tlc then
  return false
 else
  return maps[1][(l-1)*g_tcc+c].b == 1
 end
end

function get_tile(c,l)
 if c < 1 or c > g_tcc or l < 1 or l > g_tlc then
  return tiles["exterior_wall"]
 else
  return tiles[maps[1][(l-1)*g_tcc+c].t]
 end
end

function get_tile_safe(ti)
  return tiles[maps[1][ti]]
end

function get_tile_index(c,l)
 if c < 1 or c > g_tcc or l < 1 or l > g_tlc then
  return -1 -- todo: see what we can return.
  -- or better, assert.
 else
  return (l-1)*g_tcc+c
 end
end

-- function parameters are written as if only testing a vertical wall
-- swap x and y params to test horizontal walls.
function test_wall( wallx, relx, rely, deltax, deltay, tmin, miny, maxy )
 local ok = false
 local local_tmin = tmin
 local tepsilon = 0.001
 if deltax ~= 0 then
  -- time of collision. percent of where is the wall
  -- on the way from box middle to object colliding
  local tresult = (wallx - relx) / deltax
  -- use that time to find the y of collision on the way
  -- y in box local coords
  local y = rely + tresult * deltay
  -- if found a better tmin
  if tresult >= 0 and tmin > tresult then
   -- if collision y is between wall bounds
   if y >= miny and y <= maxy then
    -- clamp tmin to 0 if found a result too close.
    -- avoid collision response if stuck to a wall
    local_tmin = max(0,tresult-tepsilon)
    ok = true
   end
  end
 end
 return ok, local_tmin
end

function give_pu_to_player( pu, p )
 if pu == g_pu_bomb then
  if p.pu.b < g_max_pu_bomb then
   p.pu.b += 1
   p.has_bombs_left += 1
  end
 elseif pu == g_pu_speed then
  if p.pu.s < g_max_pu_speed then
   p.pu.s += 1
   local speeds_drags = {
    {s=800,d=14},
    {s=1600,d=22},
    {s=3200,d=38}
   }
   p.speed = speeds_drags[p.pu.s].s
   p.drag = speeds_drags[p.pu.s].d
  end
 elseif pu == g_pu_fire then
  if p.pu.b < g_max_pu_fire then
   p.pu.f += 1
   p.bomb_intensity += 1
  end
 end
end

function pick_pu_under_player( p, ti )
 local pu_under_player = maps[1][ti].o
   if pu_under_player ~= 0 then
    give_pu_to_player(pu_under_player,p)
    remove_powerup(ti)
   end
end

function kill_player(p)
 -- todo: anim
 p.is_alive = 0
end

function test_die_by_fire( p, ti )
 if ( maps[1][ti].f ~= 0 ) kill_player(p)
end

function move_player( p, acc, dt )
 
  -- fix diagonal (normalize)
 if acc.x ~= 0 and acc.y ~= 0 then
  acc.x *= 0.707
  acc.y *= 0.707
 end
  
 -- give a real value to the acceleration
 acc.x *= p.speed
 acc.y *= p.speed
 -- drag, lower the acceleration by a portion of the speed
 acc.x += -p.drag * p.dx
 acc.y += -p.drag * p.dy
  
 -- current_position = previous_position + previous_speed * t + 0.5 * acceleration * t*t
 -- delta_position = current_position - previous_position
 --                = previous_speed * t + 0.5 * acceleration * t*t
 local deltap = {
  x = 0.5 * acc.x * dt * dt + p.dx * dt,
  y = 0.5 * acc.y * dt * dt + p.dy * dt
 }
 -- update entity speed
 p.dx += acc.x * dt
 p.dy += acc.y * dt
 
 -- todo: not necessarily "player" in fact... bomb slide, enemies
 local entity_tile = tiles["player"]
 local entity_tile_bbox = entity_tile.bbox
 
 -- entity bbox in pixel map space
 local newp = {x = p.x + deltap.x, y = p.y + deltap.y}
 local newp_bbox_xmin = newp.x + entity_tile_bbox.x
 local newp_bbox_ymin = newp.y + entity_tile_bbox.y
 local newp_bbox_xmax = newp.x + entity_tile_bbox.x + entity_tile_bbox.w
 local newp_bbox_ymax = newp.y + entity_tile_bbox.y + entity_tile_bbox.h
 
 -- get the 4 tiles the player may be in
 -- 1-based 1..13
 local tile_index_xmin = 1 + flr(newp_bbox_xmin/g_twp)
 local tile_index_ymin = 1 + flr(newp_bbox_ymin/g_twp)
 local tile_index_xmax = 1 + flr(newp_bbox_xmax/g_twp)
 local tile_index_ymax = 1 + flr(newp_bbox_ymax/g_twp)
 -- todo(nfauvet): reduce to unique tiles
 -- if player entirely inside 1 tile, we will have 
 -- 4 times the same in the array.
 local tile_indices = {
  { c = tile_index_xmin, l = tile_index_ymin },
  { c = tile_index_xmin, l = tile_index_ymax },
  { c = tile_index_xmax, l = tile_index_ymin },
  { c = tile_index_xmax, l = tile_index_ymax }
 }
 
 -- 4 iterations of the collides and sweep.
 for iteration=1,4 do

  local tmin = 1.0
  local wall_normal = {x=0,y=0}
  local desired_location = {x = p.x + deltap.x, y = p.y + deltap.y}
  local hit_tile_index = {c=-1,l=-1}
  local entity_bbox_center = {
   x = p.x + entity_tile_bbox.x + 0.5 * entity_tile_bbox.w,
   y = p.y + entity_tile_bbox.y + 0.5 * entity_tile_bbox.h}

  if entity_tile.tag == 1 then -- and not non_spatial

   for t in all(tile_indices) do

    local test_tile = get_tile(t.c,t.l)
    local bomb_here = bomb_at(t.c,t.l)
    -- tag == 1 is collidable
    if test_tile.tag == 1 or bomb_here then -- and not non_spatial
     -- test_tile bbox in pixel map space
	   local test_tile_bbox_center = 
     bomb_here and {
      x = g_twp * (t.c-1) + 4, -- hardcoded full-tile bbox for floor with bomb
	     y = g_twp * (t.l-1) + 4}
     or {
	     x = g_twp * (t.c-1) + test_tile.bbox.x + 0.5 * test_tile.bbox.w,
	     y = g_twp * (t.l-1) + test_tile.bbox.y + 0.5 * test_tile.bbox.h}
	 
	   -- minkowsky sum of test_tile and entity_tile
	   -- dans le repere centre bbox de la test_entity
	   local min_box = {
	    x = -0.5 * ( test_tile.bbox.w + entity_tile.bbox.w ),
	    y = -0.5 * ( test_tile.bbox.h + entity_tile.bbox.h )}
	   local max_box = {
	    x = 0.5 * ( test_tile.bbox.w + entity_tile.bbox.w ),
	    y = 0.5 * ( test_tile.bbox.h + entity_tile.bbox.h )}
	  
	   -- position of entity relative to the test_tile center
	   local rel = { 
	    x = entity_bbox_center.x - test_tile_bbox_center.x, 
	    y = entity_bbox_center.y - test_tile_bbox_center.y }
	 
	   -- left edge
	   local ok, local_tmin = test_wall( min_box.x, rel.x, rel.y, deltap.x, deltap.y, tmin, min_box.y, max_box.y )
	   if ok then
	    wall_normal = {x=-1,y=0}
	    hit_tile_index = {c=t.c,l=t.l}
      tmin = local_tmin
	   end
	 
	   -- right edge
	   ok, local_tmin = test_wall( max_box.x, rel.x, rel.y, deltap.x, deltap.y, tmin, min_box.y, max_box.y )
	   if ok then
	    wall_normal = {x=1,y=0}
	    hit_tile_index = {c=t.c,l=t.l}
      tmin = local_tmin
	   end

	   -- top edge
	   ok, local_tmin = test_wall( min_box.y, rel.y, rel.x, deltap.y, deltap.x, tmin, min_box.x, max_box.x )
	   if ok then
	    wall_normal = {x=0,y=-1}
	    hit_tile_index = {c=t.c,l=t.l}
      tmin = local_tmin
	   end
	 
	   -- bottom edge
	   ok, local_tmin = test_wall( max_box.y, rel.y, rel.x, deltap.y, deltap.x, tmin, min_box.x, max_box.x )
	   if ok then
	    wall_normal = {x=0,y=1}
	    hit_tile_index = {c=t.c,l=t.l}
      tmin = local_tmin
	   end

	  end -- if tested tile if collidable
   end -- foreach tile to test against entity
  end -- if entity is collidable
 
  -- move to the closest hit location in the desired direction.
  -- if no collisions, move 100% of the way.
  p.x += tmin * deltap.x
  p.y += tmin * deltap.y
  
  -- if there was a hit, deviate speed and compute remaining delta
  -- to walk, for the next iteration. else, stop iterating.
  if hit_tile_index.c ~= -1 and hit_tile_index.l ~= -1 then
   local dp_dot_wall = p.dx*wall_normal.x + p.dy*wall_normal.y
   -- deviate speed
   p.dx = p.dx - dp_dot_wall * wall_normal.x
   p.dy = p.dy - dp_dot_wall * wall_normal.y
   -- remaining delta after the hit position
   deltap.x = desired_location.x - p.x
   deltap.y = desired_location.y - p.y
   -- move the delta along the wall (slide)
   local delta_dot_wall = deltap.x*wall_normal.x + deltap.y*wall_normal.y
   deltap.x = deltap.x - delta_dot_wall * wall_normal.x
   deltap.y = deltap.y - delta_dot_wall * wall_normal.y
  else
   break
  end
 
 end -- for 4 iterations 
  
 -- return final tile index
 local entity_bbox_center = {
   x = p.x + entity_tile_bbox.x + 0.5 * entity_tile_bbox.w,
   y = p.y + entity_tile_bbox.y + 0.5 * entity_tile_bbox.h}
 local ti = { c = 1 + flr(entity_bbox_center.x/g_twp), l = 1 + flr(entity_bbox_center.y/g_twp)}
 return get_tile_index(ti.c, ti.l)
end

function drop_bomb(p)
 if p.has_bombs_left > 0 then
  -- place the bomb in the middle of the cells
  -- where the middle of the player bbox is 
  local player_tile_bbox = tiles["player"].bbox
  -- player bbox in pixel map space
  local player_bbox_center = {
   x = p.x + player_tile_bbox.x + 0.5 * player_tile_bbox.w,
   y = p.y + player_tile_bbox.y + 0.5 * player_tile_bbox.h
  }
 
  local bomb_tile = {
   x = g_twp * flr(player_bbox_center.x/g_twp),
   y = g_twp * flr(player_bbox_center.y/g_twp)
  }
  local bomb_ti = get_tile_index(
   1 + flr(player_bbox_center.x/g_twp), 
   1 + flr(player_bbox_center.y/g_twp))
  
  if maps[1][bomb_ti].b == 0 then
   sfx(0)
   maps[1][bomb_ti].b = 1
   add(bombs,{x=bomb_tile.x,y=bomb_tile.y,ti=bomb_ti,pi=p.index,t=g_bomb_timeout})
   p.has_bombs_left -= 1
  end
 end
end

function get_player_spr( p, dt )
 local pa = p.anims[p.anim]
 local sprf = pa.st + pa.f + ( 3 * p.face )
 return sprf
end

function update_player_anim( p, dt )
 -- update facing direction
 if p.dx == 0 and p.dy == 0 then
  -- leave face as it is
 elseif abs(p.dx) > abs(p.dy) then
  if p.dx > 0 then
   -- right
   p.face = 1
  else
   -- left
   p.face = 2
  end
 else  
  if p.dy > 0 then
   -- up
   p.face = 3
  else
   -- down
   p.face = 0
  end
 end
 
 p.anim_time += dt
 
 local old_anim = p.anim
 
 if p.is_alive == 1 then
 local th = 1
  if abs(p.dx) < th and abs(p.dy) < th then
    p.anim = "idle"
  else
    p.anim = "walk"
  end
 else 
  p.anim = "death"
 end
 
 if p.anim ~= old_anim then
  p.anim_time = 0
 end   
  
 local pa = p.anims[p.anim]
  -- scale anim time with speed pickup count
 local t = (p.pu.s+1)*(p.anim_time/pa.spd)
 
 if pa.m == 0 then -- anim type one-shot
 
  pa.f = flr(t)
  if pa.f > pa.sz-1 then pa.f = pa.sz-1 end
  
 elseif pa.m == 1 then -- anim type reflect cycle
 
  local lf = (0.5+pa.d*t)%(2*(pa.sz-1))
  if pa.d == 1 then
   if lf > (0.5+(pa.sz-1)) then
    pa.d = -1 
   end
  else
   if lf < 0.5 then
    pa.d = 1
   end
  end
  pa.f = flr(lf)
  
 else -- modulo cycle
 
  pa.f = flr( (p.anim_time/pa.spd) % p.anims[p.anim].sz )
  
 end 
 
end

function update_player( p, dt )
 -- 0-based player index for btn functions
 local i = p.index - 1
 local acc = { x = 0, y = 0 }
 -- set acceleration direction depending on the buttons hit
 if ( btn( 0, i ) ) acc.x -= 1
 if ( btn( 1, i ) ) acc.x += 1
 if ( btn( 2, i ) ) acc.y -= 1
 if ( btn( 3, i ) ) acc.y += 1
 
 if ( btnp( 4, i ) ) drop_bomb( p )
 -- todo: if ( btnp( 5, i ) ) try_punch_bomb( p )
 --if ( btnp( 5, i ) ) p.bomb_intensity += 1
 
 --if ( btn( 0, 1 ) ) extcmd("rec")
 --if ( btn( 1, 1 ) ) extcmd("video")
 
 --if ( btnp( 0, 1 ) ) p.speed -= 1
 --if ( btnp( 1, 1 ) ) p.speed += 1
 --if ( btnp( 2, 1 ) ) p.drag += 1
 --if ( btnp( 3, 1 ) ) p.drag -= 1
   
 -- collide and sweep  
 local ti = move_player( p, acc, dt )
 
 -- try to pick up
 pick_pu_under_player( p, ti )
 
 -- test if is on a fire zone
 test_die_by_fire( p, ti )
 
 -- facing dir, walk cycle step, death.
 update_player_anim( p, dt )
end

function update_players( dt )
 for p in all( players ) do
  if ( p.is_alive == 1 ) update_player( p, dt )
 end
end

function add_explosion( b )
 --sfx(1)
 local e = {
  x = b.x,
  y = b.y,
  ti = b.ti,
  pi = b.pi,
  t = g_explosion_duration,
  int = players[b.pi].bomb_intensity,
  -- info used at the end of the explosion to destroy blocks and remove fire.
  cells = {}
 }
 
 -- center of explosion contains fire and no destructible
 add(e.cells, {ti=b.ti,f=1,d=0,o=0})
 maps[1][b.ti].f += 1
 
 local bti = {c = 1 + flr(b.x/g_twp), l = 1 + flr(b.y/g_twp)}
 
 -- compute list of affected cells. put floor on fire.
 local dirs = {
  {c= 1, l= 0}, -- +x
  {c=-1, l= 0}, -- -x
  {c= 0, l= 1}, -- +y
  {c= 0, l=-1}} -- -y
   
 -- for each direction of the fire
 for d in all(dirs) do
  for i=1,e.int do
   local tc = bti.c + i * d.c
   local tl = bti.l + i * d.l
   local ti = get_tile_index(tc,tl)
   if ti == -1 then
    break
   end
   local tile = get_tile(tc,tl)
   local hidden_object = maps[1][ti].o
      
   if tile.d == 1 then -- destructible?
    add(e.cells,{ti=ti,f=0,d=1,o=hidden_object})
    break -- destroy breakable = stop fire spreading
   else
    if tile.tag == 1 then -- collides? (indestructible walls)
     break -- collides wall = stop fire spreading
    else
     if hidden_object ~= 0 then
      add(e.cells,{ti=ti,f=1,d=0,o=hidden_object}) -- floor with pickup to destroy
      maps[1][ti].f += 1
      break
     else
      add(e.cells,{ti=ti,f=1,d=0,o=0}) -- empty floor, just fire
      maps[1][ti].f += 1
     end
    end
   end 
  end
 end
   
 add(explosions,e)
end

function update_bombs( dt )
 for b in all(bombs) do
  local is_on_fire = ( maps[1][b.ti].f ~= 0 )
  b.t -= dt
  if b.t <= 0 or is_on_fire then
   maps[1][b.ti].b = 0 -- remove bomb tag
   add_explosion(b)
   players[b.pi].has_bombs_left += 1
   del(bombs,b)
  end
 end
end

function update_pickups( dt )
 for k, v in pairs(pickups) do
  v.t -= dt
  if v.t <= 0 then
   remove_powerup(k)
  end
 end
end

function add_powerup(tile_index,obj)
 if obj ~= 0 then
  maps[1][tile_index].o = obj
  pickups[tile_index] = {t=g_pickup_timeout,o=obj}
 end
end

function remove_powerup(ti)
 maps[1][ti].o = 0
 pickups[ti] = nil
end

function update_explosions( dt )
 for e in all(explosions) do
  -- todo: update anim frame
  e.t -= dt
  if e.t <= 0 then
    
   for c in all(e.cells) do
    -- remove fire
    if c.f ~= 0 then 
     maps[1][c.ti].f -= 1 
    end
    -- remove destructible
    if c.d == 1 then
     maps[1][c.ti].t = "floor"
     add_powerup(c.ti,c.o)
    else
     -- or remove powerup
     if c.o ~= 0 then
      remove_powerup(c.ti)
     end
    end 
   end
  
   del(explosions,e)
  end
 end
end

function check_endgame()
 local nb_players_alive = 0
 g_winning_player = 0
 for i=1,g_nb_players do
  if players[i].is_alive == 1 then 
   nb_players_alive += 1
   g_winning_player = i
  end
 end
 -- or time is up.
 if nb_players_alive == 1 or 
    nb_players_alive == 0 
 then 
  state = 2 
 end
end

function update_game()
 local dt = 1/30
 debug_rects={} -- leak but garbage collector?
 update_bombs( dt )
 update_explosions( dt )
 update_pickups( dt )
 update_players( dt )
 check_endgame()
end

function update_menu()
 local dt = 1/30
 for i=0,3 do
  -- left = cycle nb_players downwards
  if ( btnp( 0, i ) ) g_nb_players = 2 + g_nb_players % 3
  -- right = cycle nb_players upwards
  if ( btnp( 1, i ) ) g_nb_players = 2 + (g_nb_players -1)%3
  -- start game
  if ( btnp( 4, i ) ) then 
   init_game()
   state = 1 
  end
 end
end

function update_endgame()
 local dt = 1/30
 for i=0,g_nb_players-1 do
  if ( btnp( 4, i ) ) then
   init_game()
   state = 0
  end
 end
end

--
-- draw
--

function draw_map()
 map(0,0,0,0,16,16)
 local cm=1 -- current map index
 for l=1,g_tlc do
   for c=1,g_tcc do
     local i=(l-1)*g_tcc+c
     local tilename = maps[cm][i].t
     local object = maps[cm][i].o
     spr(tiles[tilename].idx, g_mop.x + g_twp*(c-1), g_mop.y + g_twp*(l-1))
     
     if tilename == "floor" and object > 0 then
      spr(tiles[powerups[object].t].idx, g_mop.x + g_twp*(c-1), g_mop.y + g_twp*(l-1))
     end
   end
 end
end

function draw_bombs()
 for b in all(bombs) do
  spr(32, g_mop.x + b.x, g_mop.y + b.y)
 end
end

function draw_explosions()
 local draw_items = {} -- i,x,y
 for e in all(explosions) do
  local middle_idx = {c=1+flr(e.x/g_twp),l=1+flr(e.y/g_twp)}
  add( draw_items, {i=tiles["fire_center"].idx,x=e.x,y=e.y} )
  
  local dirs = {
   {c= 1, l= 0, tm="fire_hor", te="fire_right_end"},  -- +x
   {c=-1, l= 0, tm="fire_hor", te="fire_left_end"}, -- -x
   {c= 0, l= 1, tm="fire_ver", te="fire_bottom_end"},  -- +y
   {c= 0, l=-1, tm="fire_ver", te="fire_top_end"}} -- -y
   
  -- for each direction of the fire
  for d in all(dirs) do
   for i=1,e.int do
    local tc = middle_idx.c + i * d.c
    local tl = middle_idx.l + i * d.l
    local tile = get_tile(tc, tl)
    local ti = get_tile_index(tc,tl)
    if ti == -1 then
     break
    end
    local coords = {x=e.x+d.c*g_twp*i,y=e.y+d.l*g_twp*i}
    
    if tile.d == 1 then -- destructible?
     add(draw_items,{i=tiles["block_expl"].idx,x=coords.x,y=coords.y})
     break -- collides = stop fire spreading
    elseif tile.tag == 1 then -- indestructible collides?
     break -- collides = stop fire spreading
    else
     local hidden_object = maps[1][ti].o
     -- floor with power up
     if hidden_object ~= 0 then
      add(draw_items,{i=tiles["block_expl"].idx,x=coords.x,y=coords.y})
      break
     else -- empty floor, fire spread.     
      if i == e.int then
       add(draw_items,{i=tiles[d.te].idx,x=coords.x,y=coords.y})
      else
       add(draw_items,{i=tiles[d.tm].idx,x=coords.x,y=coords.y})
      end
     end
    end
   end
  end
 end
 
 for di in all( draw_items ) do
  spr( di.i, g_mop.x + di.x, g_mop.y + di.y )
 end
end

function draw_player( p )
 if p.is_alive == 1 then 
  --spr( p.spr_index + p.face, g_mop.x + p.x, g_mop.y + p.y )
  local px = g_mop.x + p.x
  local py = g_mop.y + p.y
  local pspr = get_player_spr( p, dt )
  spr( pspr+16, px, py )
  spr( pspr,    px, py-8 )
 end
end

function draw_players()
 for p in all(players) do
  draw_player(p)
 end
end
 
function draw_debug_gui()
 for r in all(debug_rects) do
  rect(r.x0,r.y0,r.x1,r.y1,r.c)
 end
--[[
 print(#pickups,10,10,8)
 local pu_i = 1
 for k,p in pairs(pickups) do
  print("ti: "..k.." t:"..p.t.." o:"..p.o, 10, 10+8*pu_i, 8)
  pu_i += 1
 end
]]
--[[
 print(#bombs,10,10,8)
 for i=1,#bombs do
  print("x: "..bombs[i].x.." y:"..bombs[i].y.." pi:"..bombs[i].pi, 10, 10+8*i, 8)
 end
]]

local p = players[1]
local pa = p.anims[p.anim]
rectfill(0,64,127,127,1)
print("["..p.anim.."]", 1, 65, 9)
print("t: "..p.anim_time, 1, 71, 9)
print("st:"..pa.st.." sz:"..pa.sz.." spd: "..pa.spd.." f:"..pa.f, 1, 77, 9)
print("dx: "..p.dx.." dy: "..p.dy, 1, 83, 9)
print("adx: "..abs(p.dx).." ady: "..abs(p.dy), 1, 90, 9)

--[[
 print(#players,64,10,8)
 for i=1,#players do
  local ic = 1 + flr(players[i].x/8)
  local il = 1 + flr(players[i].y/8)
  local pi = players[i]
  print("x: "..pi.x.." y:"..pi.y.." c:"..ic.." l:"..il, 0, 0+16*(i-1), 7)
  print("s: "..pi.speed.." d:"..pi.drag.." dx:"..pi.dx.." dy:"..pi.dy, 0, 8+16*(i-1), 7)
 end
]]
 
--[[
 for i=1,#explosions do
  local e = explosions[i]
  print( "e.t: "..e.t, 10, 16+8*i, 9)
  for j=1,#e.cells do
   local c = e.cells[j]
   print("e.ti: "..c.ti, 10, 32+8*j, 9)
   --if ( c.f ) maps[1][e.ti].f -= 1
  end
 end
]]
--[[
 print(#explosions,10,64,9)
 for i=1,#explosions do
  print("x: "..explosions[i].x.." y:"..explosions[i].y.." pi:"..explosions[i].pi.." int:"..explosions[i].int, 10, 64+8*i, 9)
 end
]]
end
 


function draw_gui()
 
end

function draw_game()
 --cls()
 draw_map()
 draw_bombs()
 draw_explosions()
 draw_players()
 draw_gui()
-- draw_debug_gui()
end

function draw_menu()
 cls(2)
 print("nb_players: "..g_nb_players, 10, 10, 8)
end

function draw_endgame()
 cls(1)
 print("the end", 10, 10, 8)
 if g_winning_player == 0 then
  print("draw", 20, 20, 8)
 else
  print("player "..g_winning_player.." wins!", 20, 20, 8)
 end
end

--
-- main functions
--

function _init()
 state = 0
end

function _update()
 if state == 0 then
  update_menu()
 elseif state == 1 then
  update_game()
 else
  update_endgame()
 end
end

function _draw()
 if state == 0 then
  draw_menu()
 elseif state == 1 then
  draw_game()
 else
  draw_endgame()
 end
end

__gfx__
0007850058000000000000850058700000000000000000009e84d4dedddddddd0000000000000000000000000000000000008000000000000000000000000000
0777777007777700007777700777777000000000000000004d39e9e3666666660000000000000000000000000000000080889800000000000000000000000000
777777677777777007777777776666670000000000000000e84d3d39666666660000000000000000000000000000000008a99980000000000000000000000000
777676767777424004247777742442460000000000000000111111116666666600000000000000000000000000000000899aa980000000000000000000000000
7777676677679df00fd9767779dffd9600000000000000006666666611111111000000000000000000000000000000000089a800000000000000000000000000
076666600776666006666770077777700000000000000000666666669e84d4de00000000000000000000000000000000089aa980000000000000000000000000
0ecccce000ecce0000ecce000ecccce00000000000000000666666664d39e9e3000000000000000000000000000000000089aa98000000000000000000000000
004114000004040000404000004114000000000000000000dddddddde84d3d3900000000000000000000000000000000089aa980000000000000000000000000
07e8888007b3333007a9999000000000668888664de9ed396666666666666666666666669ed394de0000000000000000089aa980000000000000000000000000
72222228711111137444444900000000688888869e34de4d6666666666666666666666664de4d9e300000000000000000089aa98000000000000000000000000
e2e55548b1baa993a43b3aa90000000088878888d39e838966dddddddddddddddddddd66e8389d390000000000000000089aa980000000000000000000000000
8257552831aa99b394bbb3a90000000088888882e4d1111166d141244214124221241d6611111e4d0000000000000000089aa980000000000000000000000000
8255521831baaa93943b3b3900000000878887223891666666d4aa00aa00aa00aa002d6666661389000000000000000089aa9800000000000000000000000000
8252221831bba9b394a3bbb900000000688882269e81666666d2a00aa00aa00aa00a4d66666619e80000000000000000089aa980000000000000000000000000
82e111e831ba9bb394aa3b3900000000665ddd664d31666666d400aa00aa00aa00aa2d66666614d300000000000000000089aa98000000000000000000000000
0888888003333330099999900000000066777d66e841666d66d10aa00aa00aa00aa04d66d6661e840000000000000000089aa980000000000000000000000000
0000f4000080800075f7d6f66d7ffd66766666654de1666d66d1aa00aa00aa00aa002d66d66614de0000000000000800089aa980000080000080000000000000
00554100889898886777776566ffff66776666519e31666d66d2a00aa00aa00aa00a1d66d66619e300000000008089808999a998808898080898080000000000
0575552099a9a999d76666d1669ff46677766d11d391666d66d400aa00aa00aa00aa2d66d6661d39000000000898999899a9aa999899a9898999898000000000
05555220aaaaaaaaf76666d1664442f67766dd11e4d1666d66d20aa00aa00aa00aa04d66d6661e4d0000000089a9aaaaaaaaa99aa9aaaa9aaaaa9a9800000000
05552210aaaaaaaa57666dd17f44246d776ddd113891666d66d4aa00aa00aa00aa001d66d666138900000000899aa9a9a99aaaaaaaaa9aaa9a9aa99800000000
022221109a9a99a97766ddd16644421677dddd119e81666d66d1a00aa00aa00aa00a4d66d66619e80000000008a9989999aa9a999a9989a999999a8000000000
0021110089889898f6dddd516d442111751111114d31666d66d200aa00aa00aa00aa2d66d66614d30000000008988088899a9998898808988898898000000000
000000000800808065111111676d111151111111e841666d66d40aa00aa00aa00aa04d66d6661e840000000080800000089aa980080000800080080800000000
35f7d6f66d6666668888888852222225800d80009e81666d66d2aa00aa00aa00aa002d66d66619e800000000800d8000089aa980000000000000000000000000
67777763666f6d768eeeee281555555d090900004d31666666d4a00aa00aa00aa00a4d66666614d30000000009090000089a9800000000000000000000000000
d76666d16676f6668eeee2e81555555d0daa90d8e841666666d100aa00aa00aa00aa1d6666661e84000000000daa90d80089a980000000000000000000000000
f76666d1666666f68eee2ee81555555d9d9a9a909e81666666d20aa00aa00aa00aa04d66666619e8000000009d9a9a9000089a88000000000000000000000000
57666dd17f6f666d8ee2eee81555555d80adda094d31111166d142141424124241241d66111114d30000000080adda090089a980000000000000000000000000
3766ddd1d66676668e2eeee81555555d0a98a9809e8e89e866dddddddddddddddddddd66e89e89e8000000000a98a980089a9800000000000000000000000000
f6dddd5166f6666f82eeeee81555555d98000d004d3d34d3666666666666666666666666d34d34d30000000098000d008089a900000000000000000000000000
63111111666d6f6688888888533333350d008a90e8484e8466666666666666666666666684e84e84000000000d008a9000088080000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e888000008000000e88880
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e7e8880077777700e888888
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008e2f28007f5f57008f2ff28
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088fff8007ffff7008fffff8
00777700007777000077770000888800008888000088880000bbbb0000bbbb0000bbbb0000cccc0000cccc0000cccc000000000000888e00077777700888888e
077777700777777007777770077777700777777007777770077777700777777007777770077777700777777007777770000000000e0990e0008cc80000499940
7e777767777ee76777777e777e777767777ee76777777e777e777767777ee76777777e777e777767777ee76777777e7700000000001414000006600000099a00
dee7767677dee6766777dee6dee7767677dee6766777dee6dee7767677dee6766777dee6dee7767677dee6766777dee600000000000111000080080000440440
6dd67766766dd76666676dd66dd67766766dd76666676dd66dd67766766dd76666676dd66dd67766766dd76666676dd600000000000000000000000000000000
06666660076666600666666006666660076666600666666006666660076666600666666006666660076666600666666000000000000000000000000000000000
00dddd0e00dddd00e0dddd0000dddd0e00dddd00e0dddd0000dddd0e00dddd00e0dddd0000dddd0e00dddd00e0dddd0000000000000000000000000000000000
06cccc7007cccc7007cccc6006cccc7007cccc7007cccc6006cccc7007cccc7007cccc6006cccc7007cccc7007cccc6000000000000000000000000000000000
e0dccc00e0cccc0e00cccd0ee0dccc00e0cccc0e00cccd0ee0dccc00e0cccc0e00cccd0ee0dccc00e0cccc0e00cccd0e00000000000000000000000000000000
00eccd1001dccd1001dcce1000eccd1001dccd1001dcce1000eccd1001dccd1001dcce1000eccd1001dccd1001dcce1000000000000000000000000000000000
01111711117117111171111001111711117117111171111001111711117117111171111001111711117117111171111000000000000000000000000000000000
00111e1001e11e1001e1110000111e1001e11e1001e1110000111e1001e11e1001e1110000111e1001e11e1001e1110000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007777000000000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000
00000000007707700000000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000
00000000077700700000000000000000000700000000000000000000070000000000000000000000000070000000000000000000000000000000000000000000
00000000070700000000000000000000000077000000000000000000770000000000000000000000000070000000000000000000000000000000000000000000
00000000000700000000000000000777777777700000000000000007700000000000000000000000000070000000000000000000000000000000000000000000
00000000000700000000000000000000000007700000000000000077777777700000000000000000000070700000000000000000000000000000000000000000
00000000000700000000000000000000000770000000000000000077700000000000000000000000007770700000000000000000000000000000000000000000
00000000000700000000000000000000000700000000000000000000770000000000000000000000000777000000000000000000000000000000000000000000
00000000000070000000000000000000000000000000000000000000077000000000000000000000000077000000000000000000000000000000000000000000
00000000000070000000000000000000000000000000000000000000000000000000000000000000000077000000000000000000000000000000000000000000
00000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13131313131313131313131313131313131313131313131313131313131313131300000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
aa00aa00aa00aa00aa00aa0058000000000000850058700000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00aa00aa00aa00aa00aa00a07777700007777700777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aa00aa00aa00aa00aa00aa77777770077777777766666700000000000000000000000000000000000000000000000000000000000000000000000000000000
0aa888888888888888888aa077774240042477777424424600000000000000000000000000000000000000000000000000000000000000000000000000000000
aa08aa00aa00aa00aa008a0077679df00fd9767779dffd9600000000000000000000000000000000000000000000000000000000000000000000000000000000
a008a00aa00aa00aa00a800a07766660066667700777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a800aa00aa00aa00aa80aa00ecce0000ecce000ecccce000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aa80aa00aa00aa00aa08aa000040400004040000041140000000000000000000000000000000000000000000000000000000000000000000000000000000000
aa08aa00aa00aa00aa008a0058000000000000850058700000000000000000000000000000000000000000000000000000000000000000000000000000000000
a008a00aa00aa00aa00a800a07777700007777700777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a800aa00aa00aa00aa80aa77777770077777777766666700000000000000000000000000000000000000000000000000000000000000000000000000000000
0aa80aa00aa00aa00aa08aa077774240042477777424424600000000000000000000000000000000000000000000000000000000000000000000000000000000
aa08aa00aa00aa00aa008a0077679df00fd9767779dffd9600000000000000000000000000000000000000000000000000000000000000000000000000000000
a008a00aa00aa00aa00a800a07766660066667700777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a800aa00aa00aa00aa80aa00ecce0000ecce000ecccce000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aa80aa00aa00aa00aa08aa000040400004040000041140000000000000000000000000000000000000000000000000000000000000000000000000000000000
aa08aa00aa00aa00aa008a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a008a00aa00aa00aa00a800a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a800aa00aa00aa00aa80aa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aa80aa00aa00aa00aa08aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
aa0888888888888888888a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00aa00aa00aa00aa00aa00a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aa00aa00aa00aa00aa00aa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aa00aa00aa00aa00aa00aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
4de9ed399e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9ed394de
9e34de4d4d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34de4d9e3
d39e8389e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e8389d39
e4d11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111e4d
38916666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666661389
9e8166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666619e8
4d3166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666614d3
e841666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd6661e84
4de1666d666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666cccc666666d66614de
9e31666d6666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666677777766666d66619e3
d391666d66dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd777ee767dd66d6661d39
e4d1666d66d141244214124242141242421412424214124242141242421412424214124242141242421412424214124242141242421477dee6761d66d6661e4d
3891666d66d46d6777766d666666668888666d7ffd66668888666d6666666d6666666d666666668888666d7ffd666d6666666d666666766dd7662d66d6661389
9e81666d66d266777777666f6d766888888666ffff6668888886666f6d76666f6d76666f6d766888888666ffff66666f6d76666f6d76676666664d66d66619e8
4d31666d66d46777ee767676f66688878888669ff466888788886676f6666676f6666676f66688878888669ff4666676f6666676f66666dddd662d66d66614d3
e841666d66d1677dee67666666f688888882664442f688888882666666f6666666f6666666f688888882664442f6666666f6666666f667cccc764d66d6661e84
4de1666d66d17766dd766f6f666d878887227f44246d878887227f6f666d7f6f666d7f6f666d878887227f44246d7f6f666d7f6f666defcccc6e2d66d66614de
9e31666d66d2d6766666d6667666688882266644421668888226d6667666d6667666d66676666888822666444216d6667666d6667666d1dccd161d66d66619e3
d391666d66d466fddddf66f6666f665ddd666d442111665ddd6666f6666f66f6666f66f6666f665ddd666d44211166f6666f66f6666f117117112d66d6661d39
e4d1666d66d2667cccc7666d6f6666777d66676d111166777d66666d6f66666d6f66666d6f6666777d66676d1111666d6f66666d6f6661e11e164d66d6661e4d
3891666d66d46e6cccc6e66666656d7ffd66766666656d7ffd66766666656688886676666665668888667666666566888866766666656d6666661d66d6661389
9e81666d66d1661dccd17766665166ffff667766665166ffff6677666651688888867766665168888886776666516888888677666651666f6d764d66d66619e8
4d31666d66d26117117117766d11669ff46677766d11669ff46677766d118887888877766d118887888877766d118887888877766d116676f6662d66d66614d3
e841666d66d4661e11e17766dd11664442f67766dd11664442f67766dd11888888827766dd11888888827766dd11888888827766dd11666666f64d66d6661e84
4de1666d66d17f6f666d776ddd117f44246d776ddd117f44246d776ddd1187888722776ddd1187888722776ddd1187888722776ddd117f6f666d2d66d66614de
9e31666d66d2d666766677dddd116644421677dddd116644421677dddd116888822677dddd116888822677dddd116888822677dddd11d66676661d66d66619e3
d391666d66d466f6666f751111116d442111751111116d44211175111111665ddd6675111111665ddd6675111111665ddd667511111166f6666f2d66d6661d39
e4d1666d66d2666d6f6651111111676d111151111111676d11115111111166777d665111111166777d665111111166777d6651111111666d6f664d66d6661e4d
3891666d66d466888866668888666d7ffd666d7ffd666d7ffd66668888666d6666666d6666666d6666666d6666666d6666666d666666668888661d66d6661389
9e81666d66d1688888866888888666ffff6666ffff6666ffff6668888886666f6d76666f6d76666f6d76666f6d76666f6d76666f6d76688888864d66d66619e8
4d31666d66d28887888888878888669ff466669ff466669ff466888788886676f6666676f6666676f6666676f6666676f6666676f666888788882d66d66614d3
e841666d66d48888888288888882664442f6664442f6664442f688888882666666f6666666f6666666f6666666f6666666f6666666f6888888824d66d6661e84
4de1666d66d187888722878887227f44246d7f44246d7f44246d878887227f6f666d7f6f666d7f6f666d7f6f666d7f6f666d7f6f666d878887222d66d66614de
9e31666d66d2688882266888822666444216664442166644421668888226d6667666d6667666d6667666d6667666d6667666d6667666688882261d66d66619e3
d391666d66d4665ddd66665ddd666d4421116d4421116d442111665ddd6666f6666f66f6666f66f6666f66f6666f66f6666f66f6666f665ddd662d66d6661d39
e4d1666d66d266777d6666777d66676d1111676d1111676d111166777d66666d6f66666d6f66666d6f66666d6f66666d6f66666d6f6666777d664d66d6661e4d
3891666d66d46d7ffd6676666665668888667666666566888866766666656d6666667666666566888866766666656d666666766666656d6666661d66d6661389
9e81666d66d166ffff667766665168888886776666516888888677666651666f6d76776666516888888677666651666f6d7677666651666f6d764d66d66619e8
4d31666d66d2669ff46677766d118887888877766d118887888877766d116676f66677766d118887888877766d116676f66677766d116676f6662d66d66614d3
e841666d66d4664442f67766dd11888888827766dd11888888827766dd11666666f67766dd11888888827766dd11666666f67766dd11666666f64d66d6661e84
4de1666d66d17f44246d776ddd1187888722776ddd1187888722776ddd117f6f666d776ddd1187888722776ddd117f6f666d776ddd117f6f666d2d66d66614de
9e31666d66d26644421677dddd116888822677dddd116888822677dddd11d666766677dddd116888822677dddd11d666766677dddd11d66676661d66d66619e3
d391666d66d46d44211175111111665ddd6675111111665ddd667511111166f6666f75111111665ddd667511111166f6666f7511111166f6666f2d66d6661d39
e4d1666d66d2676d11115111111166777d665111111166777d6651111111666d6f665111111166777d6651111111666d6f6651111111666d6f664d66d6661e4d
3891666d66d46d7ffd6666888866668888666d7ffd666d6666666d6666666d666666668888666d666666668888666d6666666d6666666d6666661d66d6661389
9e81666d66d166ffff66688888866888888666ffff66666f6d76666f6d76666f6d7668888886666f6d7668888886666f6d76666f6d76666f6d764d66d66619e8
4d31666d66d2669ff4668887888888878888669ff4666676f6666676f6666676f666888788886676f666888788886676f6666676f6666676f6662d66d66614d3
e841666d66d4664442f68888888288888882664442f6666666f6666666f6666666f688888882666666f688888882666666f6666666f6666666f64d66d6661e84
4de1666d66d17f44246d87888722878887227f44246d7f6f666d7f6f666d7f6f666d878887227f6f666d878887227f6f666d7f6f666d7f6f666d2d66d66614de
9e31666d66d266444216688882266888822666444216d6667666d6667666d666766668888226d666766668888226d6667666d6667666d66676661d66d66619e3
d391666d66d46d442111665ddd66665ddd666d44211166f6666f66f6666f66f6666f665ddd6666f6666f665ddd6666f6666f66f6666f66f6666f2d66d6661d39
e4d1666d66d2676d111166777d6666777d66676d1111666d6f66666d6f66666d6f6666777d66666d6f6666777d66666d6f66666d6f66666d6f664d66d6661e4d
3891666d66d46d666666766666656d7ffd667666666566888866766666656d7ffd66766666656d7ffd66766666656688886676666665668888661d66d6661389
9e81666d66d1666f6d767766665166ffff6677666651688888867766665166ffff667766665166ffff66776666516888888677666651688888864d66d66619e8
4d31666d66d26676f66677766d11669ff46677766d118887888877766d11669ff46677766d11669ff46677766d118887888877766d11888788882d66d66614d3
e841666d66d4666666f67766dd11664442f67766dd11888888827766dd11664442f67766dd11664442f67766dd11888888827766dd11888888824d66d6661e84
4de1666d66d17f6f666d776ddd117f44246d776ddd1187888722776ddd117f44246d776ddd117f44246d776ddd1187888722776ddd11878887222d66d66614de
9e31666d66d2d666766677dddd116644421677dddd116888822677dddd116644421677dddd116644421677dddd116888822677dddd11688882261d66d66619e3
d391666d66d466f6666f751111116d44211175111111665ddd66751111116d442111751111116d44211175111111665ddd6675111111665ddd662d66d6661d39
e4d1666d66d2666d6f6651111111676d11115111111166777d6651111111676d111151111111676d11115111111166777d665111111166777d664d66d6661e4d
3891666d66d46d6666666d7ffd666d6666666d7ffd666d7ffd66668888666d6666666d6666666d66666666888866668888666d666666668888661d66d6661389
9e81666d66d1666f6d7666ffff66666f6d7666ffff6666ffff6668888886666f6d76666f6d76666f6d766888888668888886666f6d76688888864d66d66619e8
4d31666d66d26676f666669ff4666676f666669ff466669ff466888788886676f6666676f6666676f66688878888888788886676f666888788882d66d66614d3
e841666d66d4666666f6664442f6666666f6664442f6664442f688888882666666f6666666f6666666f68888888288888882666666f6888888824d66d6661e84
4de1666d66d17f6f666d7f44246d7f6f666d7f44246d7f44246d878887227f6f666d7f6f666d7f6f666d87888722878887227f6f666d878887222d66d66614de
9e31666d66d2d666766666444216d6667666664442166644421668888226d6667666d6667666d66676666888822668888226d6667666688882261d66d66619e3
d391666d66d466f6666f6d44211166f6666f6d4421116d442111665ddd6666f6666f66f6666f66f6666f665ddd66665ddd6666f6666f665ddd662d66d6661d39
e4d1666d66d2666d6f66676d1111666d6f66676d1111676d111166777d66666d6f66666d6f66666d6f6666777d6666777d66666d6f6666777d664d66d6661e4d
3891666d66d466888866766666656d7ffd66766666656d7ffd66766666656d666666766666656d666666766666656d666666766666656d7ffd661d66d6661389
9e81666d66d1688888867766665166ffff667766665166ffff6677666651666f6d7677666651666f6d7677666651666f6d767766665166ffff664d66d66619e8
4d31666d66d28887888877766d11669ff46677766d11669ff46677766d116676f66677766d116676f66677766d116676f66677766d11669ff4662d66d66614d3
e841666d66d4888888827766dd11664442f67766dd11664442f67766dd11666666f67766dd11666666f67766dd11666666f67766dd11664442f64d66d6661e84
4de1666d66d187888722776ddd117f44246d776ddd117f44246d776ddd117f6f666d776ddd117f6f666d776ddd117f6f666d776ddd117f44246d2d66d66614de
9e31666d66d26888822677dddd116644421677dddd116644421677dddd11d666766677dddd11d666766677dddd11d666766677dddd11664442161d66d66619e3
d391666d66d4665ddd66751111116d442111751111116d4421117511111166f6666f7511111166f6666f7511111166f6666f751111116d4421112d66d6661d39
e4d1666d66d266777d6651111111676d111151111111676d111151111111666d6f6651111111666d6f6651111111666d6f6651111111676d11114d66d6661e4d
3891666d66d46d6666666688886666888866668888666d7ffd666d7ffd666d7ffd66668888666d7ffd6666888866668888666d7ffd66668888661d66d6661389
9e81666d66d1666f6d7668888886688888866888888666ffff6666ffff6666ffff666888888666ffff66688888866888888666ffff66688888864d66d66619e8
4d31666d66d26676f666888788888887888888878888669ff466669ff466669ff46688878888669ff4668887888888878888669ff466888788882d66d66614d3
e841666d66d4666666f6888888828888888288888882664442f6664442f6664442f688888882664442f68888888288888882664442f6888888824d66d6661e84
4de1666d66d17f6f666d8788872287888722878887227f44246d7f44246d7f44246d878887227f44246d87888722878887227f44246d878887222d66d66614de
9e31666d66d2d66676666888822668888226688882266644421666444216664442166888822666444216688882266888822666444216688882261d66d66619e3
d391666d66d466f6666f665ddd66665ddd66665ddd666d4421116d4421116d442111665ddd666d442111665ddd66665ddd666d442111665ddd662d66d6661d39
e4d1666d66d2666d6f6666777d6666777d6666777d66676d1111676d1111676d111166777d66676d111166777d6666777d66676d111166777d664d66d6661e4d
3891666d66d466888866766666656d666666766666656d7ffd66766666656d7ffd667666666566888866766666656d7ffd66766666656d7ffd661d66d6661389
9e81666d66d16888888677666651666f6d767766665166ffff667766665166ffff6677666651688888867766665166ffff667766665166ffff664d66d66619e8
4d31666d66d28887888877766d116676f66677766d11669ff46677766d11669ff46677766d118887888877766d11669ff46677766d11669ff4662d66d66614d3
e841666d66d4888888827766dd11666666f67766dd11664442f67766dd11664442f67766dd11888888827766dd11664442f67766dd11664442f64d66d6661e84
4de1666d66d187888722776ddd117f6f666d776ddd117f44246d776ddd117f44246d776ddd1187888722776ddd117f44246d776ddd117f44246d2d66d66614de
9e31666d66d26888822677dddd11d666766677dddd116644421677dddd116644421677dddd116888822677dddd116644421677dddd11664442161d66d66619e3
d391666d66d4665ddd667511111166f6666f751111116d442111751111116d44211175111111665ddd66751111116d442111751111116d4421112d66d6661d39
e4d1666d66d266777d6651111111666d6f6651111111676d111151111111676d11115111111166777d6651111111676d111151111111676d11114d66d6661e4d
3891666d66d46688886666888866668888666d7ffd666d7ffd6666888866668888666d7ffd666688886666888866668888666d666666668888661d66d6661389
9e81666d66d168888886688888866888888666ffff6666ffff66688888866888888666ffff66688888866888888668888886666f6d76688888864d66d66619e8
4d31666d66d2888788888887888888878888669ff466669ff4668887888888878888669ff4668887888888878888888788886676f666888788882d66d66614d3
e841666d66d4888888828888888288888882664442f6664442f68888888288888882664442f6888888828888888288888882666666f6888888824d66d6661e84
4de1666d66d18788872287888722878887227f44246d7f44246d87888722878887227f44246d8788872287888722878887227f6f666d878887222d66d66614de
9e31666d66d26888822668888226688882266644421666444216688882266888822666444216688882266888822668888226d6667666688882261d66d66619e3
d391666d66d4665ddd66665ddd66665ddd666d4421116d442111665ddd66665ddd666d442111665ddd66665ddd66665ddd6666f6666f665ddd662d66d6661d39
e4d1666d66d266777d6666777d6666777d66676d1111676d111166777d6666777d66676d111166777d6666777d6666777d66666d6f6666777d664d66d6661e4d
3891666d66d46d666666766666656d7ffd66766666656d7ffd66766666656d666666766666656d7ffd66766666656d7ffd66766666656d6666661d66d6661389
9e81666d66d1666f6d767766665166ffff667766665166ffff6677666651666f6d767766665166ffff667766665166ffff6677666651666f6d764d66d66619e8
4d31666d66d26676f66677766d11669ff46677766d11669ff46677766d116676f66677766d11669ff46677766d11669ff46677766d116676f6662d66d66614d3
e841666d66d4666666f67766dd11664442f67766dd11664442f67766dd11666666f67766dd11664442f67766dd11664442f67766dd11666666f64d66d6661e84
4de1666d66d17fcccc6d776ddd117f44246d776ddd117f44246d776ddd117f6f666d776ddd117f44246d776ddd117f44246d776ddd117fcccc6d2d66d66614de
9e31666d66d2d777777677dddd116644421677dddd116644421677dddd11d666766677dddd116644421677dddd116644421677dddd11d77777761d66d66619e3
d391666d66d4777ee767751111116d442111751111116d4421117511111166f6666f751111116d442111751111116d44211175111111777ee7672d66d6661d39
e4d1666d66d277dee67651111111676d111151111111676d111151111111666d6f6651111111676d111151111111676d11115111111177dee6764d66d6661e4d
3891666d66d4766dd7666d6666666d7ffd666d66666666888866668888666d7ffd666d6666666d66666666888866668888666d666666766dd7661d66d6661389
9e81666d66d167666666666f6d7666ffff66666f6d76688888866888888666ffff66666f6d76666f6d766888888668888886666f6d76676666664d66d66619e8
4d31666d66d266dddd666676f666669ff4666676f6668887888888878888669ff4666676f6666676f66688878888888788886676f66666dddd662d66d66614d3
e841666d66d467cccc76666666f6664442f6666666f68888888288888882664442f6666666f6666666f68888888288888882666666f667cccc764d66d6661e84
4de1666d66d2efcccc6e7f6f666d7f44246d7f6f666d87888722878887227f44246d7f6f666d7f6f666d87888722878887227f6f666defcccc6e2d66d66614de
9e31666d66d4d1dccd16d666766666444216d6667666688882266888822666444216d6667666d66676666888822668888226d6667666d1dccd164d66d66619e3
d391666d66d11171171166f6666f6d44211166f6666f665ddd66665ddd666d44211166f6666f66f6666f665ddd66665ddd6666f6666f117117111d66d6661d39
e4d1666d66d261e11e16666d6f66676d1111666d6f6666777d6666777d66676d1111666d6f66666d6f6666777d6666777d66666d6f6661e11e164d66d6661e4d
3891666d66d1421414241242142412421424124214241242142412421424124214241242142412421424124214241242142412421424124241241d66d6661389
9e81666d66dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd66d66619e8
4d31666d6666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666d66614d3
e841666d6666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666d6661e84
9e81666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd66619e8
4d3166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666614d3
e8416666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666661e84
9e8166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666619e8
4d3111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111114d3
9e8e89e89e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4de9e84d4dee89e89e8
4d3d34d34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e34d39e9e3d34d34d3
e8484e84e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d39e84d3d3984e84e84

__map__
1506060606060606060606060606061932323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2516171717171717171717171717182932323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25263f3f3f3f3f3f3f3f3f3f3f3f282932322323232323242424242432323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25263f3f3f3f3f3f3f3f3f3f3f3f282932322331313123243131312432323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25263f3f3f3f3f3f3f3f3f3f3f3f282932322331313123243131312432323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25263f3f3f3f3f3f3f3f3f3f3f3f282932322323232323242424242432323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25263f3f3f3f3f3f3f3f3f3f3f3f282932323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25263f3f3f3f3f3f3f3f3f3f3f3f282932323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25263f3f3f3f3f3f3f3f3f3f3f3f282932323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25263f3f3f3f3f3f3f3f3f3f3f3f282932323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25263f3f3f3f3f3f3f3f3f3f3f3f282932323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25263f3f3f3f3f3f3f3f3f3f3f3f282932323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25263f3f3f3f3f3f3f3f3f3f3f3f282932323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25263f3f3f3f3f3f3f3f3f3f3f3f282932323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2536373737373737373737373737382932323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3507070707070707070707070707073932323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3130313131313131313131313131313131313131313131313131313131313131310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3130313131313131313131313131313131313131313131313131313131313131310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3130313131313131313131313131313131313131313131313131313131313131310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3130313131313131313131313131313131313131313131313131313131313131310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3130313131313131313131313131313131313131313131313131313131313131310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3130313131313131313131313131313131313131313131313131313131313131310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3130313131313131313131313131313131313131313131313131313131313131310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3130313131313131313131313131313131313131313131313131313131313131310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3130313131313131313131313131313131313131313131313131313131313131310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3130313131313131313131313131313131313131313131313131313131313131310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3130313131313131313131313131313131313131313131313131313131313131310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3130313131313131313131313131313131313131313131313131313131313131310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010900000c753077000770006700077000b700176001a6001c6001e6002060021600236002460022600206001d6001b6001760012600106000c600096001e20004600036002b2000000000000000000000000000
00040000146501365013650000001565018650000001c6500000021650286502665020650206500000022650256501e6501e6501f6501e6501965016650000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
005000000c7100c71009710047100571009710097100971009710097150471409710107100c7100c7100b7100b7100b7100b715107000c7000c7000c7000b7000b7000b7000b7000c7040c7040b7040b7040b704
01500000093520b3520b4020b402094520b4520940209402094520b4520c4520b452094520b452000000000009402094020b4020b4020c4020c4020b4020b40209402094020b4020b40200000000000000001400
__music__
01 0a4b4344
02 0a0b4344

