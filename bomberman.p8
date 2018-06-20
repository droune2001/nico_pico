pico-8 cartridge // http://www.pico-8.com
version 16
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

g_normal_dt=0.016667
g_slow_dt=g_normal_dt / 3 -- victory slowdown
g_delta_time=g_normal_dt

state="menu" -- menu, game, endgame
menu_state="start_fade_in" -- start_fade_in, end_fade_in, ask_nb_players, player_config, start_fade_out, end_fade_out
game_state="start_fade_in" -- start_fade_in, end_fade_in, start_countdown, start_game, start_banner, end_banner, start_fade, end_fade
endgame_state="start_fade_in" -- start_fade_in, end_fade_in, start_fade_out, end_fade_out

players={}
bombs={}
explosions={}
pickups={} -- active powerups on field
tiles={} -- tile map by name, stores id, bbox and flags.
maps={}
powerups={}
debug_rects={} -- map space pixels {x0,y0,x1,y1,color}

game_is_init = false
g_countdown_time = 3.0
g_cd_time_left = 0.0

g_nb_players = 2 -- 2..4
g_nb_cups_per_game = 2
g_max_nb_cups = 3

g_match_winning_player = 0
g_game_winning_player = 0

g_conf_index = 0


g_twp = 8 -- global tile width in pixels
--g_mop = {x=12,y=12} -- global map offsets in pixels
g_mop = {x=12,y=17	} -- global map offsets in pixels
g_tlc = 13 -- global number of tile lines
g_tcc = 13 -- global number of tile columns

g_pu_bomb = 1
g_pu_speed = 2
g_pu_fire = 3

g_max_pu_bomb = 5
g_max_pu_speed = 3
g_max_pu_fire = 12 -- maybe have a non-linear progress? quadratic?

g_bomb_timeout = 2 -- nb seconds before explosion
g_explosion_duration = 0.8 -- nb seconds during which fire is harmful
g_pickup_timeout = 999 -- 8 -- nb seconds before pickup disappears
g_bomb_spr = 23

-- effects:
-- 0 = normal 
-- 1 = fade-to-black-8
-- 2 = fade-to-black-6
-- 3 = fade-to-white-4
-- 4 = fade-in-from-black-8
-- 5 = fade-in-from-black-6
-- 6 = fade-in-from-white-4
g_fx = { id=0, active=0, pal_start=0, pal_end=0, curr_pal=0, t=0, max_t=2, dir=1, debug_t=0 }

--
-- init/create
--

-- sprsh is optional. if provided, packed contains indices into sprsh
function unpack(packed,sprsh)
 unpacked={} -- global, no re create each time
 for i=1,#packed,2 do
  local num = packed[i]
  local val = sprsh and sprsh[packed[i+1]] or packed[i+1]
  for j=1,num do
   add(unpacked,val)
  end
 end
 return unpacked
end

function init_anims()
 anims = {}
 
 -- note: optimize using offsets.
 -- player
 local top_spr={   64, 64+1, 64+2, 64+1+32} 
 local right_spr={ 67, 67+1, 67+2, 67+1+32}
 local left_spr={  70, 70+1, 70+2, 70+1+32}
 local bottom_spr={73, 73+1, 73+2, 73+1+32}
 
 local death_spr={64,65,66} -- todo
 
 local idle_fr={ 15,2, 15,4}
 local run0_fr={ 11,1,  8,2, 11,3, 8,2}
 local run1_fr={  9,1,  6,2,  9,3, 6,2}
 local run2_fr={  7,1,  5,2,  7,3, 5,2}
 local run3_fr={  5,1,  4,2,  5,3, 4,2}
 local death_fr={10,1,  8,2, 10,3, 8,2}
 
 anims.idle_top={dir=1,frames=unpack(idle_fr,top_spr)}
 anims.idle_right={dir=1,frames=unpack(idle_fr,right_spr)}
 anims.idle_left={dir=1,frames=unpack(idle_fr,left_spr)}
 anims.idle_bottom={dir=1,frames=unpack(idle_fr,bottom_spr)}
 
 anims.run0_top={dir=1,frames=unpack(run0_fr,top_spr)}
 anims.run0_right={dir=1,frames=unpack(run0_fr,right_spr)}
 anims.run0_left={dir=1,frames=unpack(run0_fr,left_spr)}
 anims.run0_bottom={dir=1,frames=unpack(run0_fr,bottom_spr)}
 
 anims.run1_top={dir=1,frames=unpack(run1_fr,top_spr)}
 anims.run1_right={dir=1,frames=unpack(run1_fr,right_spr)}
 anims.run1_left={dir=1,frames=unpack(run1_fr,left_spr)}
 anims.run1_bottom={dir=1,frames=unpack(run1_fr,bottom_spr)}
 
 anims.run2_top={dir=1,frames=unpack(run2_fr,top_spr)}
 anims.run2_right={dir=1,frames=unpack(run2_fr,right_spr)}
 anims.run2_left={dir=1,frames=unpack(run2_fr,left_spr)}
 anims.run2_bottom={dir=1,frames=unpack(run2_fr,bottom_spr)}
 
 anims.run3_top={dir=1,frames=unpack(run3_fr,top_spr)}
 anims.run3_right={dir=1,frames=unpack(run3_fr,right_spr)}
 anims.run3_left={dir=1,frames=unpack(run3_fr,left_spr)}
 anims.run3_bottom={dir=1,frames=unpack(run3_fr,bottom_spr)}
 
 anims.death={dir=2,frames=unpack(death_fr,death_spr)}
 
 -- bomb
 local bomb_spr={55,56,57,58,59,60}
 anims.idle_bomb={dir=1,frames=unpack({5,1, 5,2, 7,3, 7,4, 5,5},bomb_spr)} 
end

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
 
 tiles["wall"] = {idx=39,tag=1,d=1,bbox={x=1,y=1,w=6,h=6}}
 tiles["floor"] = {idx=40,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["wood_plot"] = {idx=41,tag=1,d=1,bbox={x=0,y=0,w=8,h=8}}
 tiles["hard_wall"] = {idx=42,tag=1,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["champi"] = {idx=43,tag=1,d=1,bbox={x=0,y=0,w=8,h=8}}
 
 tiles["pu_bomb"] = {idx=7,tag=0,d=1,bbox={x=0,y=0,w=8,h=8}}
 tiles["pu_speed"] = {idx=8,tag=0,d=1,bbox={x=0,y=0,w=8,h=8}}
 tiles["pu_fire"] = {idx=9,tag=0,d=1,bbox={x=0,y=0,w=8,h=8}}
 
 tiles["block_expl"] = {idx=252,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_center"] = {idx=237,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_hor"] = {idx=238,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_ver"] = {idx=254,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_left_end"] = {idx=236,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_right_end"] = {idx=239,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_top_end"] = {idx=255,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 tiles["fire_bottom_end"] = {idx=253,tag=0,d=0,bbox={x=0,y=0,w=8,h=8}}
 
 tiles["cup"] = {idx=48,tag=0,d=0,bbox={x=0,y=0,w=7,h=7}}
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
 p.is_alive = true
 p.is_killable = true
 p.is_human = true
 p.x = player_starting_position(index).x -- in pixel map space [0..12*8=96]
 p.y = player_starting_position(index).y
 p.vic = 0 -- number of victories
 p.pu = {b=0,s=0,f=0} -- bomb, speed, fire
 p.has_bombs_left = 1
 p.bomb_intensity = 1
 -- slow: 200 8 -- keep it for a slowdown pickup
 -- normal: 400 10
 -- x2: 800 14
 -- x4: 1600 22
 -- x8: 3200 38
 -- formulae = 2^(powerup)*100, 6+2^pu
 p.speed = 400
 p.drag = 10
 p.dx = 0
 p.dy = 0
 --p.tag = 0
 p.face = "top" -- 3 -- facing direction
 
 p.anim = "idle_bottom" -- current anim in global anims array
 p.f = 0 -- current anim frame, 0-based
 
 -- play anim "a" from frame "f"
 p.play_anim = function(a,f)
  p.anim = a or "idle_bottom"
  p.f = f or 0
 end
 
 p.update_current_anim = function()
  local a = anims[p.anim]
  local nb_frames = #a.frames
  -- cycle
  p.f = 
   (a.dir == 1) 
   and ( p.f + 1 ) % nb_frames 
   or min(nb_frames-1,p.f+1)
 end

 return p
end

function init_players()
 players = {}
 for i=1,g_nb_players do
  players[i] = create_player(i)
 end
end

function reset_players()
 for i=1,g_nb_players do
  local p=players[i]
  p.is_alive = true
  p.is_killable = true
  p.x = player_starting_position(i).x -- in pixel map space [0..12*8=96]
  p.y = player_starting_position(i).y
  p.pu = {b=0,s=0,f=0} -- bomb, speed, fire
  p.has_bombs_left = 1
  p.bomb_intensity = 1
  p.speed = 400
  p.drag = 10
  p.dx = 0
  p.dy = 0
  p.face = "top" -- 3 -- facing direction
  p.anim = "idle_bottom" -- current anim in global anims array
  p.f = 0 -- current anim frame, 0-based
 end
end

function config_players()
 for i=0,g_nb_players-1 do -- for each player controller
  if (btnp(⬅️,i)) then 
   if g_conf_index == 0 then
    g_nb_cups_per_game = max(g_nb_cups_per_game-1,1)
   else
    players[g_conf_index].is_human = not players[g_conf_index].is_human
   end
  end
  if (btnp(➡️,i)) then
  if g_conf_index == 0 then
    g_nb_cups_per_game = min(g_nb_cups_per_game+1,g_max_nb_cups)
   else
    players[g_conf_index].is_human = not players[g_conf_index].is_human
   end
  end
  if (btnp(⬆️,i)) then
   g_conf_index = (g_conf_index-1)%(g_nb_players+1)
  end
  if (btnp(⬇️,i)) then
   g_conf_index = (g_conf_index+1)%(g_nb_players+1)
  end
  if (btnp(🅾️,i)) then -- 4 
   return true
  end
 end
 return false
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
   
   -- fill with pickups
   --local rnd_object = max(0,flr(rnd(12) - 8.5)) -- 3/4 chance to have 0, then 1,2,3
   local rnd_object = flr(rnd(3))+1 -- 3/4 chance to have 0, then 1,2,3
   map0[ti].o = rnd_object
   pickups[ti] = {t=g_pickup_timeout,o=rnd_object}
   
   
   --[[
    -- normal fill code
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
    ]]

	
   end
  end
 end
 add(maps,map0)
end

function init_score()
 reset_winners()
 for i=1,g_nb_players do
  players[i].vic = 0
 end
end

function reset_winners()
 g_match_winning_player = 0
 g_game_winning_player = 0
end

function reset_renderables()
 bombs={} -- active bombs on field
 explosions={} -- active explosions on field
 pickups={} -- active powerups on field
 debug_rects={}
end

function init_first_game()
 --music(0)
 reset_renderables() 
 init_powerups()
 init_tiles()
 init_map()
 init_anims()
 --init_players() -- done in menu
 init_score()
 game_is_init = true
end

function init_next_game()
 --music(0)
 reset_renderables() 
 init_map()
 reset_players()
 reset_winners()
end

--
-- fx
--

function start_fx(fx,id,duration)
 fx.id = id
 fx.active=1
 fx.t=0
 fx.max_t=duration
 if id == 0 then
  fx.pal_start=0
  fx.pal_end=0
  fx.dir=1
 elseif id == 1 then
  fx.pal_start=8
  fx.pal_end=15
  fx.dir=1
  --fx.max_t=8
 elseif id == 2 then
  fx.pal_start=0
  fx.pal_end=5
  fx.dir=1
 elseif id == 3 then
  fx.pal_start=20
  fx.pal_end=23
  fx.dir=1
 elseif id == 4 then
  fx.pal_start=15
  fx.pal_end=8
  fx.dir=-1
 elseif id == 5 then
  fx.pal_start=5
  fx.pal_end=0
  fx.dir=-1
 elseif id == 6 then
  fx.pal_start=23
  fx.pal_end=20
  fx.dir=-1
 end
 fx.curr_pal=fx.pal_start
end

function update_fx(fx,dt)
  if fx.active == 1 then
    fx.t += dt
    if fx.t >= fx.max_t then
     fx.active = 0
     -- todo(nfauvet): add callback on fx end.
    else
      local t = fx.t/fx.max_t
      fx.debug_t = t
      -- offset by 1 if dir==-1, offset 0 if dir==1
      local offset = (1-fx.dir)/2
      -- floating. set_palette applies a flr()
      fx.curr_pal = fx.pal_start + offset + t * fx.dir * ( 1 + abs(fx.pal_end-fx.pal_start) )
    end
  end
end

function apply_palette_fx(fx)
 if fx.active == 0 or fx.id == 0 then 
  set_palette(0) 
 else
  set_palette(fx.curr_pal)
 end
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
 if(p.is_killable) p.is_alive = false
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
   add(bombs, create_bomb(bomb_tile.x, bomb_tile.y, bomb_ti, p.index, g_bomb_timeout))
   p.has_bombs_left -= 1
  end
 end
end

function create_bomb(x,y,ti,pi,t)
 local b = {}
 b.x = x
 b.y = y
 b.ti = ti
 b.pi = pi
 b.t = t
 
 b.anim = "idle_bomb" -- current anim in global anims array
 b.f = 0 -- current anim frame, 0-based
 
 -- play anim "a" from frame "f"
 b.play_anim = function(a,f)
  b.anim = a or "idle_bomb"
  b.f = f or 0
 end
 
 b.update_current_anim = function()
  local a = anims[b.anim]
  local nb_frames = #a.frames
  -- cycle
  b.f = 
   (a.dir == 1) 
   and ( b.f + 1 ) % nb_frames 
   or min(nb_frames-1,b.f+1)
 end
 
 return b
end

function get_entity_spr(e)
 return anims[e.anim].frames[e.f+1] -- to 1-based
end

function update_player_anim( p, dt )
 -- update facing direction
 if p.dx == 0 and p.dy == 0 then
  -- leave face as it is
 elseif abs(p.dx) > abs(p.dy) then
  if p.dx > 0 then
   -- right
   p.face = "right" -- 1
  else
   -- left
   p.face = "left" --2
  end
 else  
  if p.dy > 0 then
   -- up
   p.face = "top" --3
  else
   -- down
   p.face = "bottom" --0
  end
 end
 
 
 local old_anim = p.anim
 local new_anim = old_anim
 
 if p.is_alive then
 local th = 1
  if abs(p.dx) < th and abs(p.dy) < th then
   p.anim = "idle".."_"..p.face
  else
   p.anim = "run"..p.pu.s.."_"..p.face
  end
 else 
  p.anim = "death"
 end
 
 if new_anim == old_anim then
  p:update_current_anim()
 else
  p:play_anim(new_anim)
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
  if ( p.is_alive ) update_player( p, dt )
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
  else
   b.update_current_anim()
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

function check_match_victory()
 local nb_players_alive = 0
 local winning_player = 0
 for i=1,g_nb_players do
  if players[i].is_alive then 
   nb_players_alive += 1
   winning_player = i
  end
 end
 -- or time is up.
 if nb_players_alive == 1 or 
    nb_players_alive == 0 
 then 
  return winning_player 
 else
  return 0  
 end
end

function check_game_victory()
 for i=1,g_nb_players do
  if players[i].vic == g_nb_cups_per_game then 
   return i
  end
 end
 return 0
end

function start_countdown(t)
 g_cd_time_left = t
end

function update_countdown(dt)
 g_cd_time_left -= dt
end

function countdown_finished()
 return g_cd_time_left <= 0
end

function update_game()

 if game_state == "start_fade_in" then
 
  if not game_is_init then init_first_game() end
  start_fx(g_fx,4,0.5)
  game_state="fading_in"
 
 elseif game_state == "fading_in" then
 
 update_fx(g_fx,g_normal_dt)
  
  if g_fx.active == 0 then 
   game_state = "end_fade_in" 
  end

 elseif game_state == "end_fade_in" then -- todo: merge end_fade_in and start_countdown
  
  game_state = "start_countdown"

 elseif game_state == "start_countdown" then

  start_countdown(g_countdown_time)
  game_state = "counting_down"

 elseif game_state == "counting_down" then
  
  update_countdown(g_normal_dt)
  if countdown_finished() then
   game_state = "end_countdown"
  end

 elseif game_state == "end_countdown" then -- todo: merge end_game and play_game states

  game_state = "play_game"

 elseif game_state == "play_game" then

  debug_rects={} -- leak but garbage collector?
  update_bombs( g_delta_time )
  update_explosions( g_delta_time )
  update_pickups( g_delta_time )
  update_players( g_delta_time )
  g_match_winning_player = check_match_victory() 
  if g_match_winning_player > 0 then
   players[g_match_winning_player].vic += 1
   game_state = "victory_match_start_announce"
  end
 
 elseif game_state == "victory_match_start_announce" then
 
  start_fx(g_fx,3,3.0)
  start_countdown(g_countdown_time) -- tmp, just to draw a banner
  -- invincible players during slowdown
  for p in all( players ) do
   if(p.is_alive) p.is_killable = false
  end
  game_state = "victory_match_announcing"
  
 elseif game_state == "victory_match_announcing" then
 
  update_fx(g_fx,g_normal_dt)
  update_countdown(g_normal_dt)
  
  --
  debug_rects={} -- leak but garbage collector?
  update_bombs( g_slow_dt )
  update_explosions( g_slow_dt )
  update_pickups( g_slow_dt )
  update_players( g_slow_dt )
  --
  
  
  if g_fx.active == 0 then 
   game_state = "victory_match_end_announce" 
  end
  
 elseif game_state == "victory_match_end_announce" then
 
  g_game_winning_player = check_game_victory()
  if g_game_winning_player > 0 then
   state = "end_game"
   endgame_state = "start_fade_in"
  else
   -- restart new match
   game_state = "start_fade_in"
   init_next_game()
  end
 
 end
 
end

function update_menu()
 if menu_state == "start_fade_in" then
  start_fx(g_fx,4,1.0)
  menu_state="fading_in"
 elseif menu_state == "fading_in" then
  update_fx(g_fx,g_delta_time)
  if g_fx.active == 0 then 
   menu_state = "end_fade_in" 
  end
 elseif menu_state == "end_fade_in" then
  g_nb_players=2
  menu_state="ask_nb_players"
 elseif menu_state == "ask_nb_players" then
  for i=0,3 do -- for each player controller
   -- left = cycle nb_players downwards
   if ( btnp( 0, i ) ) g_nb_players = 2 + g_nb_players % 3
   -- right = cycle nb_players upwards
   if ( btnp( 1, i ) ) g_nb_players = 2 + (g_nb_players -1)%3
   -- start game
   if ( btnp( 4, i ) ) then 
    menu_state="player_config"
	init_players()
   end
  end
 elseif menu_state == "player_config" then
  if config_players() then
   menu_state="start_fade_out"
  end
 elseif menu_state == "start_fade_out" then
  start_fx(g_fx,1, 0.6)
  menu_state="fading_out"
 elseif menu_state == "fading_out" then
  update_fx(g_fx,g_delta_time)
  if g_fx.active == 0 then 
   menu_state = "end_fade_out" 
  end
 elseif menu_state == "end_fade_out" then
  state = "game"
  game_state = "start_fade_in"
  game_is_init = false
 end 
end

function update_endgame()
 if endgame_state == "start_fade_in" then
  start_fx(g_fx,1, 0.6)
  endgame_state = "fading_in"
 elseif endgame_state == "fading_in" then
  update_fx(g_fx,g_delta_time)
  if g_fx.active == 0 then 
   endgame_state = "end_fade_in"
  end
 elseif endgame_state == "end_fade_in" then -- todo: remove
  endgame_state = "wait_for_return"
 elseif endgame_state == "wait_for_return" then
  for i=0,g_nb_players-1 do
   if ( btnp( 4, i ) ) then
    endgame_state = "start_fade_out"
   end
 end
 elseif endgame_state == "start_fade_out" then
  start_fx(g_fx,1, 0.6)
  endgame_state = "fading_out"
 elseif endgame_state == "fading_out" then
  update_fx(g_fx,g_delta_time)
  if g_fx.active == 0 then 
   endgame_state = "end_fade_out"
  end
 elseif endgame_state == "end_fade_out" then
  state = "menu"
  menu_state = "start_fade_in"
 end
end

--
-- draw
--

function draw_map(dt)
 --map(0,0,0,0,16,16)
 cls(1)
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

function draw_bombs(dt)
 palt(3,true)
 palt(0,false)
 for b in all(bombs) do
  local bsprite = get_entity_spr(b)
  spr(bsprite, g_mop.x + b.x, g_mop.y + b.y)
 end
 palt()
end

function draw_explosions(dt)
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

function draw_player( p, dt )
 if p.is_alive then 
  local px = g_mop.x + p.x
  local py = g_mop.y + p.y
  local pspr = get_entity_spr( p )
  palt(3,true)
  palt(0,false)
  spr( pspr+16, px, py )
  spr( pspr,    px, py-8 )
  palt()
 end
end

function draw_players(dt)
 for p in all(players) do
  draw_player(p,dt)
 end
end
 
function draw_debug_gui()
 for r in all(debug_rects) do
  rect(r.x0,r.y0,r.x1,r.y1,r.c)
 end

--[[ 
 shprint("state = "..state, 1, 92, 2, 0)
 shprint("m_state = "..menu_state, 1, 100, 2, 0)
 shprint("g_state = "..game_state, 1, 108, 2, 0)
 shprint("e_state = "..endgame_state, 1, 116, 2, 0)
 ]]
 
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

--[[
local p = players[1]
local pa = p.anims[p.anim]
rectfill(0,64,127,127,1)
print("["..p.anim.."]", 1, 65, 9)
print("t: "..p.anim_time, 1, 71, 9)
print("st:"..pa.st.." sz:"..pa.sz.." spd: "..pa.spd.." f:"..pa.f, 1, 77, 9)
print("dx: "..p.dx.." dy: "..p.dy, 1, 83, 9)
print("adx: "..abs(p.dx).." ady: "..abs(p.dy), 1, 90, 9)
]]

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
 
-- t: time
-- d: duration
function ease_in_quad(t,d)
 t /= d
 if (t<0) return 0
 if (t>1) return 1
 return t*t
end

function ease_out_quad(t,d)
 t /= d
 if (t<0) return 1
 if (t>1) return 0
 return (t-1)*(t-1)
end

function draw_game_gui(dt)
 rectfill(0,0,128,8,9)
 for i=1,g_nb_players do
  shprint("p"..i, 2+32*(i-1), 2, 6, 0)
  for j=1,g_nb_cups_per_game do
   local tile_index = players[i].vic >= j and tiles["cup"].idx or tiles["cup"].idx+1
   palt(3,true)
   palt(0,false)
   spr(tile_index,11+32*(i-1)+7*(j-1),1)
   palt()
  end
 end
end

function draw_banners(dt)
 if game_state == "counting_down" then
  local ease_duration = 0.1*g_countdown_time
  local eit = g_countdown_time - g_cd_time_left -- 0__3sec
  local eot = ease_duration - g_cd_time_left -- -2.6__0__0.4
  local ei = ease_in_quad(eit,ease_duration)  -- 0___1_1_1_1_1
  local eo = ease_out_quad(eot,ease_duration) -- 1_1_1_1_1___0
  local eio = ei * eo                         -- 0___1_1_1___0 
   
  local dy = 9 * eio
  local by = 66 - dy
  local ey = 66 + dy
  rectfill(0,by,128,ey,2)
  line(0,by,128,by,7)
  line(0,ey,128,ey,7)
  local int_cd = ceil(g_cd_time_left)
  shprint(""..int_cd, 64,64,7,0.5)
 end
 
 if game_state == "victory_match_announcing" then
  -- todo: if exactly the same as above, factor code.
  local ease_duration = 0.1*g_countdown_time
  local eit = g_countdown_time - g_cd_time_left -- 0__3sec
  local eot = ease_duration - g_cd_time_left -- -2.6__0__0.4
  local ei = ease_in_quad(eit,ease_duration)  -- 0___1_1_1_1_1
  local eo = ease_out_quad(eot,ease_duration) -- 1_1_1_1_1___0
  local eio = ei * eo                         -- 0___1_1_1___0 
   
  local dy = 9 * eio
  local by = 66 - dy
  local ey = 66 + dy
  rectfill(0,by,128,ey,2)
  line(0,by,128,by,7)
  line(0,ey,128,ey,7)
  local int_cd = ceil(g_cd_time_left)
  -- todo: anim text right to left.
  shprint("player "..g_match_winning_player.." wins!", 64,64,7,0.5)
  local winning_player_vic = players[g_match_winning_player].vic
  for i=1,winning_player_vic-1 do
   palt(3,true)
   palt(0,false)
   spr(tiles["cup"].idx,92+8*(i-1),63)
   palt()
  end
  local sprite_px = 8 * (tiles["cup"].idx % 16)
  local sprite_py = 8 * (flr(tiles["cup"].idx / 16))
  palt(3,true)
  palt(0,false)
  sspr(sprite_px, sprite_py,7,7,
  92+8*(winning_player_vic-1)+4-ei*4,
  63+4-ei*4,
  1+ei*6,1+ei*6)
  palt()
 end
end
 
function draw_game()
 if game_is_init then
  apply_palette_fx(g_fx)
  
  local dt = g_normal_dt
  if game_state == "victory_match_announcing" then
   dt = g_slow_dt
  end
  
  draw_map(dt)
  draw_bombs(dt)
  draw_explosions(dt)
  draw_players(dt)
  draw_game_gui(g_normal_dt)
  
  pal()
  
  draw_banners(g_normal_dt)
 else
  cls()
 end
end

function draw_menu()
 
 apply_palette_fx(g_fx)
 sspr(96,32,4*8,4*8,0,0,128,128)
 
 if menu_state == "ask_nb_players" then
  print("nb_players: "..g_nb_players, 10, 80, 7)
 elseif menu_state == "player_config" then
  local base_y = 80
  print("victories: "..g_nb_cups_per_game, 10, base_y, 7)
  for i=0,g_nb_players-1 do
   local player_index = i+1
   local player_is_human_str = players[player_index].is_human and "hum" or "com"
   print("player  "..player_index..": "..player_is_human_str, 10, base_y+8+8*i, 7)
  end
  local cursor_pos = base_y + 8*g_conf_index
  print(">", 2, cursor_pos, 7)
 end 
 
 -- reset palette 
 pal()
end

function draw_endgame()
 
 apply_palette_fx(g_fx)
 
 cls(8)
 local t=t()
 local dist=30+5*cos(2.0*t)
 local x=64+dist*cos(0.3*t)
 local y=64-dist*sin(0.3*t)
 local col=7+14*sin(0.1*t)
 local radius=10+2*sin(0.5*t)
 
 palt(0,false)
 --for i=1,10 do end
 circfill(x,y,radius,col)
 circfill(x,y,radius,col)
 circfill(x,y,radius,col)
 circfill(x,y,radius,col)
 palt()
 
 if endgame_state == "start_fade_in" then
 elseif endgame_state == "fading_in" then
 elseif endgame_state == "end_fade_in" then -- todo: remove
 elseif endgame_state == "wait_for_return" then
 
 --cls(1)
 print("the end", 10, 10, 9)
 print("player "..g_game_winning_player.." wins!", 20, 20, 9)
 
 elseif endgame_state == "start_fade_out" then
 elseif endgame_state == "fading_out" then
 elseif endgame_state == "end_fade_out" then
 end
 
 pal()
end

--
-- utils
--

function set(obj,props)
 obj=obj or {}
 for k,v in pairs(props) do
  obj[k]=v
 end
 return obj
end

function each_char(str,fn)
 for i=1,#str do
  fn(sub(str,i,i),i)
 end
end

function call(fn,a)
 return fn
  and fn(a[1],a[2],a[3],a[4],a[5])
  or a
end

function ob(str,props)
 local result,s,n,inpar=
  {},1,1,0
 each_char(str,function(c,i)
  local sc,nxt=sub(str,s,s),i+1
  if c=="(" then
   inpar+=1
  elseif c==")" then
   inpar-=1
  elseif inpar==0 then
   if c=="=" then
    n,s=sub(str,s,i-1),nxt
   elseif c=="," and s<i then
	   result[n]=sc=='"'
	    and sub(str,s+1,i-2)
	    or sub(str,s+1,s+1)=="("
	    and call(obfn[sc],ob(
	     sub(str,s+2,i-2)..","
	    ))
	    or sc!="f"
	    and band(sub(str,s,i-1)+0,0xffff.fffe)
	   s=nxt
	   if (type(n)=="number") n+=1
   elseif sc!='"' and c==" " or c=="\n" then
    s=nxt
   end
  end
 end)
 return set(props,result)
end

function lut(str)
 local result,s={},1
 each_char(str,function(c,i)
  if c=="\n" then
   add(result,ob(sub(str,s,i)))
   s=i
  end
 end)
 return result
end

------------------------------
-- pretty text
-- draws shadows around the text
-- a: 1   = align right
-- a: 0.5 = align middle
-- a: 0   = align left
------------------------------

shpr=lut([[
 x=0,y=-1,c=0,
 x=0,y=1,c=0,
 x=1,y=0,c=0,
 x=-1,y=0,c=0,
 x=-1,y=-1,c=0,
 x=-1,y=1,c=0,
 x=1,y=1,c=0,
 x=1,y=-1,c=0,
 x=0,y=0,c=1,
]])
function shprint(s,x,y,c,a)
 x-=a*4*#(s.."")
 for d in all(shpr) do
  print(s,x+d.x,y+d.y,c*d.c)
 end
end


-------------------------------
-- palette effects
-------------------------------

-- we will store (n) palettes in personal address space, 
-- extracted from the spritesheed.
function init_palettes(n)
 local a=0x5000 
 for p=0,n do
  local pri=p
  local sec=8
  if p>=24 then
   pri=13+p/8
   sec+=p%8
  end
  for c=0,15 do
   local v=sget(sec,sget(pri,c))
   if (c==3) v+=0x80
   poke(a,v)
   a+=1
  end
 end
end

function set_palette(no)
 memcpy(0x5f00,0x5000+shl(flr(no),4),16)
end


--
-- main functions
--

function _init()
 --cartdata("droune2001-bomberfun-0.01")
 init_palettes(39)
 state = "menu"
 --state = "end_game"
end

function _update60()
 if state == "menu" then
  update_menu()
 elseif state == "game" then
  update_game()
 elseif state == "end_game" then
  update_endgame()
 end
end

function _draw()
 if state == "menu" then
  draw_menu()
 elseif state == "game" then
  draw_game()
 elseif state == "end_game" then
  draw_endgame()
 end
 
 draw_debug_gui()
end

__gfx__
0000000000000000000000570000000000000000000000000000000007e8888007b3333007a9999007d55550076cccc000000000000000000000000000000000
1110001111000000101015d700000000000000000000000000000000722222287111111374444449711111157111111c00000000000000000000000000000000
22110025211000005121249700000000000000000000000000000000e2e55548b1baa993a43b3aa9d1ddddd56166666c00000000000000000000000000000000
333110333311000033333bf7000000000000000000000000000000008257552831aa99b394bbb3a951ddddd5c166666c00000000000000000000000000000000
4221102d44221000d14149a7000000000000000000000000000000008255521831baaa93943b3b3951ddddd5c166666c00000000000000000000000000000000
551110555511000055555d67000000000000000000000000000000008252221831bba9b394a3bbb951ddddd5c166666c00000000000000000000000000000000
66d5106666dd5100666667770000000000000000000000000000000082e111e831ba9bb394aa3b3951ddddd5c166666c00000000000000000000000000000000
776d1077776dd5507f79777700000000000000000000000000000000088888800333333009999990055555500cccccc000000000000000000000000000000000
882210188882210088888ee700000000000000000000000000000000333333333333333333000f4333000f4333333f4333333333000000000000000000000000
9422104c9994210062949a770000000000000000000000000000000033333333333333333000f4133000f4033300f43333333f43000000000000000000000000
a9421047aa99421074a9a777000000000000000000000000000000003333333333333f430700010037001103307001033300f433000000000000000000000000
bb3310bbbbb331001929bf770000000000000000000000000000000033333f433000f40300000000300000033000000330700103000000000000000000000000
ccd510ccccdd5110ccccc77700000000000000000000000000000000333004330070010000000010300000133000010330000003000000000000000000000000
d55110dddd511000ddddd67700000000000000000000000000000000330700330000000000000110300001133300103330000103000000000000000000000000
ee82101eee882210eeeeef7700000000000000000000000000000000330010330000010030001103330011333335533333001033000000000000000000000000
f94210f7fff9421079f9f77700000000000000000000000000000000333003333000100333000033333333333333333333355333000000000000000000000000
0000000000000000000000000000000000000000000000000000000035f7d6f66d6666666d7ffd6676666665668888666d666666999999990000000000000000
0000000000000000000000000000000000000000000000000000000067777763666f6d7666ffff66776666516888888666666666999999990000000000000000
00000000000000000000000000000000000000000000000000000000d76666d16676f666669ff46677766d118887888866666666999999990000000000000000
00000000000000000000000000000000000000000000000000000000f76666d1666666f6664442f67766dd118888888266666666999999990000000000000000
0000000000000000000000000000000000000000000000000000000057666dd17f6f666d7f44246d776ddd11878887227666666d999999990000000000000000
000000000000000000000000000000000000000000000000000000003766ddd1d66676666644421677dddd1168888226d6666666999999990000000000000000
00000000000000000000000000000000000000000000000000000000f6dddd5166f6666f6d44211175111111665ddd666666666f999999990000000000000000
0000000000000000000000000000000000000000000000000000000063111111666d6f66676d11115111111166777d66666d6666999999990000000000000000
30333033333333333a333a3300000000000000000000000000000000333333333333333333000ff333000f433333f43333333333000000000000000000000000
040007033a333a33aaaaaaa30000000000000000000000000000000033333333333333333000f4033000f4033300f43333333f43000000000000000000000000
0499a7033aaaaa33aaaaaaa30000000000000000000000000000000033333333333333330700010037001103307001033300f433000000000000000000000000
3049903333aaa3333aaaaa330000000000000000000000000000000033333f433000ff0300000000300000033000000330700103000000000000000000000000
330a0333333a333333aaa3330000000000000000000000000000000033300433007004f000000010300000133000010330000003000000000000000000000000
3099703333aaa3333aaaaa3300000000000000000000000000000000330700330000001000000110300001133300103330000103000000000000000000000000
330003333333333333aaa333000000000000000000000000000000003300103300000100300011033d0011d33dd55dd333001033000000000000000000000000
3333333333333333333333330000000000000000000000000000000033d00d33d000100d3d0000d333dddd3333dddd333dd55dd3000000000000000000000000
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333398989999999999999999999999999999
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333389898989898999899999999999999999
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333398989899989999999999999999999999
33333333337777333333333333377333337777333337733333377333337777333337733333333333337777333333333388898989898989898999999999999999
33777733377777733377773337777773ee777773e777777337777773377777ee3777777e33777733377777733377773398924248999999999999944999999999
37777773777ee776377777737ee77777ee6777776777777777777ee7777776ee7777777637777773777ee7763777777388822222898989899989942599999999
7ee77767777eed6d77777ee67ee677746d6764247777424247776ee7424676d6242477777ee77767777eed6d77777ee688422221422248222222442224424299
7eed767d767676dd77777eed76d67779767769df77769dfd97776d67fd967767dfd967777eed767d767676dd77777eed88822222221224212222242122222219
66dd77dd3766ddd3767676dd37777769777769996776999996777773999677779999677666dd77dd3766ddd3767676dd98422222221222212212222142141229
3666ddd3336d55333766ddd333776ddd3677766d36777666ddd67733d6677763666777633666ddd3336d55333766ddd388822221122222212212222225522214
33cd553e37cccd63e3cd553336cdd53e3336d5333366d53ee35ddc63335d6333e35d663333cd553e37cccd63e3cd553388821111485112419259144151441519
37cccd67e3ccdd3e67cccd63e3cccc763337cc33377ccc6667cccc3e33cc733366ccc77337cccd67e3ccdd3e67cccd6388888888888988898989898989998999
e3ccdd3333cddd3333ccdd3e33cccd333337ec33e3cccd3333dccc3333ce733333dccc3ee3ccdd3333cddd3333ccdd3e88889888989898989898999999999999
31eddc133171161331cdde1331d7dd63331ccc1331c7dd3336dd7d1331ccc13331dd7c1331eddc133171161331cdde1388888888888889898989898989899999
3100171111e00e11117100131e76001e311171111e607113e11167e111171113111716e13100071111e00e111170011388888888889898989898989998999999
33110e133111111331e01133310001113310e01331000e0133111113310e013331e1111333110e133111111331e0113388888888888888888889898989898989
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333388888888988898989898989899999999
33333333333333333333333333333333333333333333333333333333333333333333333333373333333333333333333388888888888888888988898989898989
33333333333333333333333333333733333333333333333333733333333333333333333333373333333333333333333388888888888888989898989898999899
33373333333333333333333333333373333333333333333337333333333333333333333333373333333333333333333388888888888888888888888989898989
33777333337777333333333337777777333777733333333377777773377773333333333337373733337777333333333388888888888888889898989898989999
37373733377ee77333333333333333733ee77777333333333733333377777ee33333333333777333377ee7733333333388888888888888888888888889898989
33373333777ee67633333333333337333ee77999333333333373333399977ee33333333333373333777ee6763333333388888888888888888898889898989898
333733337777dd6d333333333333333333d769df3333333333333333fd967d3333333333333333337777dd6d3333333388888888888888888888888888898889
33373333767776dd333333333333333333776fdf3333333333333333fdf677333333333333333333767776dd3333333388888888888888888888989898989898
333333333766ddd333333333333333333337777733333333333333337777733333333333333333333766ddd33333333388888888888888888888888888888989
33333333336d55333333333333333333336ddd0e3333333333333333e0ddd6333333333333333333336d55333333333388888888888888888888888888989898
33333333e7cccd6e33333333333333333e3ccc77333333333333333377ccc3e33333333333333333e7cccd6e3333333388888888888888888888888888888889
3333333333ccdd333333333333333333333ccc33333333333333333333ccc333333333333333333333ccdd333333333388888888888888888888888898889898
3333333317cddd6133333333333333333317cd13333333333333333331dc7133333333333333333317cddd613333333388888888888888888888888888888888
3333333310e00e01333333333333333331e71171333333333333333317117e13333333333333333310e00e013333333388888888888888888888888888888898
333333333111111333333333333333333311111e3333333333333333e11111333333333333333333311111133333333388888888888888888888888888888888
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
000785005800000000000085005870000000000000000000000000009e84d4dedddddddd00000000000000000000000000000000000000000000000000000000
077777700777770000777770077777700000000000000000000000004d39e9e36666666600000000000000000000000000000000000000000000000000000000
77777767777777700777777777666667000000000000000000000000e84d3d396666666600000000000000000000000000000000000000000000000000000000
77767676777742400424777774244246000000000000000000000000111111116666666600000000000000000000000000000000000000000000000000000000
7777676677679df00fd9767779dffd96000000000000000000000000666666661111111100000000000000000000000000000000000000000000000000000000
07666660077666600666677007777770000000000000000000000000666666669e84d4de00000000000000000000000000000000000000000000000000000000
0ecccce000ecce0000ecce000ecccce0000000000000000000000000666666664d39e9e300000000000000000000000000000000000000000000000000000000
00411400000404000040400000411400000000000000000000000000dddddddde84d3d3900000000000000000000000000000000000000000000000000000000
0e888000008000000e8888000000000000000000000000004de9ed396666666666666666666666669ed394de0000000000000000000000000000000000000000
e7e8880077777700e88888800000000000000000000000009e34de4d6666666666666666666666664de4d9e30000000000000000000000000000000000000000
8e2f28007f5f57008f2ff280000000000000000000000000d39e838966dddddddddddddddddddd66e8389d390000000000000000000000000000000000000000
88fff8007ffff7008fffff80000000000000000000000000e4d1111166d141244214124221241d6611111e4d0000000000000000000000000000000000000000
0888e00077777700888888e00000000000000000000000003891666666d4aa00aa00aa00aa002d66666613890000000000000000000000000000000000000000
e0990e0008cc8000049994000000000000000000000000009e81666666d2a00aa00aa00aa00a4d66666619e80000000000000000000000000000000000000000
01414000006600000099a0000000000000000000000000004d31666666d400aa00aa00aa00aa2d66666614d30000000000000000000000000000000000000000
001110000800800004404400000000000000000000000000e841666d66d10aa00aa00aa00aa04d66d6661e840000000000000000000000000000000000000000
3333f43300000000000000000000000000000000000000004de1666d66d1aa00aa00aa00aa002d66d66614de0000000000000800089aa9800000800000800000
3355413300000000000000000000000000000000000000009e31666d66d2a00aa00aa00aa00a1d66d66619e300000000008089808999a9988088980808980800
357555230000000000000000000000000000000000000000d391666d66d400aa00aa00aa00aa2d66d6661d39000000000898999899a9aa999899a98989998980
355552230000000000000000000000000000000000000000e4d1666d66d20aa00aa00aa00aa04d66d6661e4d0000000089a9aaaaaaaaa99aa9aaaa9aaaaa9a98
3555221300000000000000000000000000000000000000003891666d66d4aa00aa00aa00aa001d66d666138900000000899aa9a9a99aaaaaaaaa9aaa9a9aa998
3222211300000000000000000000000000000000000000009e81666d66d1a00aa00aa00aa00a4d66d66619e80000000008a9989999aa9a999a9989a999999a80
3321113300000000000000000000000000000000000000004d31666d66d200aa00aa00aa00aa2d66d66614d30000000008988088899a99988988089888988980
333333330000000000000000000000000000000000000000e841666d66d40aa00aa00aa00aa04d66d6661e840000000080800000089aa9800800008000800808
0080800075f7d6f68888888852222225800d8000000000009e81666d66d2aa00aa00aa00aa002d66d66619e800000000800d8000089aa980089aa98000008000
88989888677777658eeeee281555555d09090000000000004d31666666d4a00aa00aa00aa00a4d66666614d30000000009090000089a98000089aa9880889800
99a9a999d76666d18eeee2e81555555d0daa90d800000000e841666666d100aa00aa00aa00aa1d6666661e84000000000daa90d80089a980089aa98008a99980
aaaaaaaaf76666d18eee2ee81555555d9d9a9a90000000009e81666666d20aa00aa00aa00aa04d66666619e8000000009d9a9a9000089a88089aa980899aa980
aaaaaaaa57666dd18ee2eee81555555d80adda09000000004d31111166d142141424124241241d66111114d30000000080adda090089a98089aa98000089a800
9a9a99a97766ddd18e2eeee81555555d0a98a980000000009e8e89e866dddddddddddddddddddd66e89e89e8000000000a98a980089a9800089aa980089aa980
89889898f6dddd5182eeeee81555555d98000d00000000004d3d34d3666666666666666666666666d34d34d30000000098000d008089a9000089aa980089aa98
080080806511111188888888533333350d008a9000000000e8484e8466666666666666666666666684e84e84000000000d008a9000088080089aa980089aa980
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
d6c7c7c7c7c7c7c7c7c7c7c7c7c7c7da32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6d7d8d8d8d8d8d8d8d8d8d8d8d8d9ea32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6e7d1d1d1d1d1d1d1d1d1e8e8e8e9ea32322323232323242424242432323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6e7d1d1d1d1d1d1d1d1e8e8e8e8e9ea32322331313123243131312432323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6e7d1d1d1d1d1d1d1d1e8e8e8e8e9ea32322331313123243131312432323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6e7d1d1d1d1d1e8e8e8e8e8e8e8e9ea32322323232323242424242432323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6e7d1d1d1d1e8e8e8e8e8e8e8e8e9ea32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6e7d1d1e8e8e8e8e8e8e8e8e8e8e9ea32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6e7d1e8e8e8e8e8e8e8e8e8e8e8e9ea32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6e7e8e8e8e8e8e8e8e8e8e8e8e8e9ea32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6e7e8e8e8e8e8e8e8e8e8e8e8e8e9ea32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6e7e8e8e8e8e8e8e8e8e8e8e8e8e9ea32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6e7e8e8e8e8e8e8e8e8e8e8e8e8e9ea32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6e7e8e8e8e8e8e8e8e8e8e8e8e8e9ea32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e6f7f8f8f8f8f8f8f8f8f8f8f8f8f9ea32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f6c8c8c8c8c8c8c8c8c8c8c8c8c8c8fa32323232323232323232323232323232320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

