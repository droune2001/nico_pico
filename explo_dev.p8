pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--explosion test
--droune
--[[
todo
* optimize simulation / do it once every other frame.
  have the emitters specify their update rate?
* less particles in the explosion.
* add central explo.
* add rocks explo (up to 4)
* think about how to handle multiple aligned
  explosions with many aligned rocks. Do you treat
  chain explosions in succession or simultaneously?
  do you explode 1 rock or as many as there are reaching bombs?
]]

t=0
dt=.0166667

max_dist_cells=1

-->8
-----------
-- profiler
-----------

function print_outline(t,x,y,c,bc)
 color(bc or 0)
 print(t,x-1,y)print(t,x-1,y-1)print(t,x,y-1)print(t,x+1,y-1)
 print(t,x+1,y)print(t,x+1,y+1)print(t,x,y+1)print(t,x-1,y+1)
 print(t,x,y,c)
end

function create_profiler()
return {
 curr_frame=1,
 cpu_hist={},
 mem_hist={},
 cpu_update_mean=0,
 cpu_draw_mean=0,
 cpu_mean=0,
 mem_mean=0,
 
 init = function(this)
  for i=1,60 do
   -- upd,dra, pix norms
   this.cpu_hist[i]={0,0,0,0}
   -- real val, pix norm
   this.mem_hist[i]={0,0}
  end
 end,
 
 log_update_time = function(this)
  this.cpu_hist[this.curr_frame+1][1]=stat(1)
 end,
 
 log_draw_time = function(this)
  this.mem_hist[this.curr_frame+1][1]=stat(0)
  this.cpu_hist[this.curr_frame+1][2]=stat(1)
 end,
 
 -- normalize stats and compute means
 compute_frame_stats = function(this)
  this.curr_frame = (this.curr_frame+1)%60
  this.cpu_update_mean=0
  this.cpu_draw_mean=0
  this.cpu_mean=0
  this.mem_mean=0
  
  for i=1,60 do
   local c1=31*this.cpu_hist[i][1]
   local c2=31*this.cpu_hist[i][2]
  
   this.cpu_hist[i][3]=c1
   this.cpu_hist[i][4]=c2
  
   this.cpu_mean+=c2
   this.cpu_update_mean+=c1
   this.cpu_draw_mean+=c2-c1
  
   local m=62*(this.mem_hist[i][1]/2048.0)
   this.mem_mean+=m
   this.mem_hist[i][2]=m
  end

  this.cpu_mean = this.cpu_mean/60
  this.cpu_update_mean = this.cpu_update_mean/60
  this.cpu_draw_mean = this.cpu_draw_mean/60
  this.mem_mean = this.mem_mean / 60
 end,
 
 update = function(this)
  this:log_update_time()
 end,
 
 draw = function(this)
  this:log_draw_time()
  this:compute_frame_stats()
 
  local chox=1 -- cpu hist offset x
  local mhox=chox+66
  for i=1,60 do
   local c1=this.cpu_hist[i][3]
   local c2=this.cpu_hist[i][4]
   -- update time
   line(chox+i,126,chox+i,126-c1,6)
   -- draw time
   line(chox+i,126-c1-1,chox+i,126-c2,13)
   -- outline
   local mx=c2
   if i>1 then mx=max(mx,this.cpu_hist[i-1][4]) end
   if i<60 then mx=max(mx,this.cpu_hist[i+1][4]) end
   line(chox+i,126-mx,chox+i,126-c2,1)
  
   local m=this.mem_hist[i][2]
   if m > 0 then
    line(mhox+i,126,mhox+i,126-m,9)
    mx=m
    if i>1 then mx=max(mx,this.mem_hist[i-1][2]) end
    if i<60 then mx=max(mx,this.mem_hist[i+1][2]) end
    line(mhox+i,126-mx,mhox+i,126-m,1)
   end
  end
 
  line(chox+1,126-this.cpu_mean,chox+60,126-this.cpu_mean,8)
  print_outline("total",chox+13,126-this.cpu_mean-6,8)
 
  line(chox+1,126-this.cpu_update_mean,chox+60,126-this.cpu_update_mean,9)
  print_outline("upd",chox+34,126-this.cpu_update_mean-6,9)
 
  line(chox+1,126-this.cpu_draw_mean,chox+60,126-this.cpu_draw_mean,10)
  print_outline("drw",chox+47,126-this.cpu_draw_mean-6,10)
 
  line(mhox+1,126-this.mem_mean,126,126-this.mem_mean,5)

  -- containers
  line(chox,   127,   chox+61,127,   0) -- bottom
  line(chox,   127-32,chox+2, 127-32,0) -- 60 tick
  line(chox,   127-64,chox+2, 127-64,0) -- 30 tick
  line(chox,   127-64,chox,   127,   0) -- v left
  line(chox+61,127-64,chox+61,127,   0) -- v right
 
  line(mhox,127,   127,   127,   0) -- bottom
  line(mhox,127-32,mhox+2,127-32,0) -- 1M tick
  line(mhox,127-64,mhox+2,127-64,0) -- 2M tick
  line(mhox,127-64,mhox,  127,   0) -- v left
  line(127, 127-64,127,   127,   0) -- v right
 
  print_outline("30",chox+4,127-66,8)
  print_outline("60",chox+4,127-34,11)
 
  print_outline("2m",mhox+4,127-66,8)
  print_outline("1m",mhox+4,127-34,11)
  
  print_outline(stat(0).." k",mhox+3,127-7,7)
  print_outline(flr(stat(1)*100).."%",chox+3,127-7,7)
 end
}
end -- create_profiler


-->8
--------------
-- tweak vars
--------------
tweak_vars = {
 current = 1,
 var_list = {},
 
 add = function( tv, var_name, viz_name, incr )
  local one_var = { vn=var_name, vin=viz_name, i=incr }
  add(tv.var_list,one_var)
 end,
 
 update = function(tv)
  if btnp(3) then
   tv.current += 1
   if tv.current == #tv.var_list + 1 then
    tv.current = 1
   end
  end
  
  if btnp(2) then
   tv.current -= 1
   if tv.current == 0 then
    tv.current = #tv.var_list
   end
  end
  
  if btnp(0) then
   g_vars[tv.var_list[tv.current].vn] -= tv.var_list[tv.current].i
  end
  
  if btnp(1) then
   g_vars[tv.var_list[tv.current].vn] += tv.var_list[tv.current].i
  end
  
  if btnp(4) then
   tv:dump_to_clipboard()
  end
 end,
 
 draw = function(tv)
  -- draw list of viz_name and value
  for k,v in pairs(tv.var_list) do
   print_outline(v.vin..": <"..g_vars[v.vn]..">",0,(k-1)*8, k == tv.current and 8 or 7,1)
  end
  -- draw current in bold
  -- scroll view depending on current and direction and distance to brders
 end,
 
 dump_to_clipboard = function(tv)
  -- print g_vars object with name and values, to clipboard
  local str = "g_vars = { "
  for v in all(tv.var_list) do
   str = str..v.vn.."="..g_vars[v.vn]..", "
  end
  str = str.."}"
  printh(str, "@clip")
  -- find special clip command @clip ???
 end
}

-->8
------------------
-- particle system
------------------
i_ps = {
  init = function(ps)
   ps.is_active = true
   for e in all(ps.emitters) do
    e:init()
   end
  end,
  update = function(ps)
   local any_still_active = false  
   for e in all(ps.emitters) do
    e:update(ps.x,ps.y)
    any_still_active = any_still_active or e.is_active
   end
   ps.is_active = any_still_active
  end,
  draw = function(ps)
   -- all drawn one on top of the other,
   -- no order of emitters.
   for e in all(ps.emitters) do
    -- todo: add priority, or z-order
    e:draw()
   end
  end
}

function create_particle_system(px,py)
 return {
  x = px or 64,
  y = py or 64,
  emitters = {},
  is_active = false,
  init = i_ps.init,
  update = i_ps.update,
  draw = i_ps.draw
 }
end

i_emitter = {
  init = function(e)
   e.is_active = true
   for i=1,e.max_particles do
    add(e.particles,{is_alive = false}) -- todo: trade a bool for computation, if need be.
   end
  end,
  update = function(e,psx,psy)
   
   -- emit
   if e.emit_time_left > 0 then
    e:emit(psx+e.x,psy+e.y)
    e.emit_time_left -= dt
    if e.emit_time_left - .001 < 0 then
      e.emit_time_left = 0
    end
   end
   
   -- update particles
   local e_particles = e.particles
   local e_nb_particles = e.nb_particles
   local p_update = e_nb_particles > 0 and e_particles[1].update or nil
   local i=1
   while i <= e_nb_particles do
    local p = e_particles[i]
    p.age -= dt
    if p.age < 0 then
     p.is_alive = false -- deprecated ?
     -- swap with last particle.
     local tmp = e_particles[e_nb_particles]
     e_particles[e_nb_particles] = p
     e_particles[i] = tmp
     e_nb_particles -= 1
    else
     --p:update()
     p_update(p)
     i+=1
    end
   end
   
   -- check for end of fx
   if e.nb_particles == 0 then
    if e.emit_time_left == 0 then
     e.is_active = false
    end
    -- +check if not in pre-emit state.
   end
   
   e.nb_particles = e_nb_particles
   
  end,
  -- move to specific emitter impl
  emit = function(e,px,py)
   local e_spawn_particle = e.spawn_particle
   local num_to_emit = e.n or 10
   while e.nb_particles < e.max_particles and num_to_emit > 0 do
    -- pop head of list, list points to next
    local f = e.nb_particles + 1
    e_spawn_particle(e,e.particles[f],px,py)
    num_to_emit -= 1
    e.nb_particles += 1
   end
  end
}
 
function create_emitter(t,max_nb_parts,cx,cy)
 return {
  x = cx or 0,
  y = cy or 0,
  particles = {},
  max_particles = max_nb_parts or 100,
  nb_particles = 0,
  
  emit_time_left = t,
  is_active = false,
  init = i_emitter.init,
  update = i_emitter.update,
  emit = i_emitter.emit,
  draw = i_emitter.draw
 }
end

function create_rock_explo_emitter()
-- todo
end

function create_bomb_emitter(x,y)
-- todo
end

function create_fire_emitter(x,y,dirx,diry,length)
 -- create generic emitter
 local e = create_emitter(g_vars.explo_duration,100,x,y)

 -- complete it with specifics
 e.n = g_vars.nb_particles_per_emission
 e.pcolors = {10,9,9,8,13,13,13}
 e.kd = g_vars.damp
 e.kl = g_vars.lift_factor
 e.dirx = dirx
 e.diry = diry
 
 -- replace e.draw
 e.draw = function(e)
  local colors = e.pcolors -- one lookup for all particles
  local nb_colors = #colors
  local particles = e.particles
  for i=1,e.nb_particles do
   local p = particles[i]
   -- color ramp by age
   local color = colors[1+flr(nb_colors*(p.max_age-p.age)*p.inv_max_age)]
   -- todo: radius evolve with age!
   if p.radius < 1.5 then
    pset(p.x,p.y,color)
   else
    circfill(p.x,p.y,p.radius,color)
   end 
  end
 end

 e.spawn_particle = function(e,part,cx,cy)
   
   local ox = rnd(6)-3 -- -3,3
   local oy = rnd(6)-3 -- -3,3
   local ex = abs(ox*oy)*0.1--/(3*3+1) -- excentricity: 0 center, 1 corner
   --local ex2 = ex*ex
   --local _ex = .99-ex -- inv excentricity. 
   local _ex2 = (.99-ex)*(.99-ex)--_ex*_ex

   local speed = g_vars.init_speed+rnd(0.15*g_vars.init_speed)
   --local life = .2+rnd(.6)
   local life = 0.7+rnd(0.2)

   -- fill preallocated particle
   part.is_alive = true
   part.x = cx+ox
   part.y = cy+oy
   part.vx = _ex2*speed*e.dirx
   part.vy = _ex2*speed*e.diry
   --part.radius = .5+_ex2*rnd(3)
   part.radius = g_vars.min_part_size + _ex2 * g_vars.max_part_size
   part.age = life
   part.max_age = life
   part.inv_max_age = 1./life
    -- todo: add variability in speed
    -- slow external particles move more
    -- randomly than central high speed parts.
    
   --part.draw = i_fire_particle.draw
   part.update = function(p)
    i_fire_particle.update(p,e.kd,e.kl)
   end
 end -- spawn_particle
 
 
 
 
 return e
end

i_fire_particle = {
 -- put in particle, use as a clojure with e.kd and e.kl access
 update = function(p,kd,kl)
  
  local px = p.x
  local py = p.y
  local pvx = p.vx
  local pvy = p.vy
  local age_pct = (p.max_age-p.age)*p.inv_max_age
  local lift = age_pct*age_pct
  
  -- drag + vertical lift
  local fx = -kd * pvx
  local fy = -kd * pvy - kl * lift
  
  p.x = px + pvx * dt
  p.y = py + pvy * dt
  
  p.vx = pvx + fx * dt
  p.vy = pvy + fy * dt
 end -- update
}

function create_quad_fire_emitter(x,y)
 -- create generic emitter
 local e = create_emitter(g_vars.explo_duration,400,x,y)
 -- complete it with specifics
 e.n = g_vars.nb_particles_per_emission
 --colors={10,9,9,8,8,8,13,13,13,13}
 e.pcolors = {10,9,9,8,13,13,13}
 e.kd = g_vars.damp
 e.kl = g_vars.lift_factor
   
 -- replace e.draw
 e.draw = function(e)
  local colors = e.pcolors -- one lookup for all particles
  local nb_colors = #colors
  local particles = e.particles
  for i=1,e.nb_particles do
   local p = particles[i]
   -- color ramp by age
   local color = colors[1+flr(nb_colors*(p.max_age-p.age)*p.inv_max_age)]
   -- todo: radius evolve with age!
   if p.radius < 1.5 then
    pset(p.x,p.y,color)
   else
    circfill(p.x,p.y,p.radius,color)
   end 
  end
 end

 e.spawn_particle = function(e,part,cx,cy)
   local dir = flr(rnd(4))/4 -- 4 quadrants for the sin/cos funcs
   --local speed = 150+rnd(25)
   
   local ox = rnd(6)-3 -- -3,3
   local oy = rnd(6)-3 -- -3,3
   local ex = abs(ox*oy)*0.1--/(3*3+1) -- excentricity: 0 center, 1 corner
   --local ex2 = ex*ex
   --local _ex = .99-ex -- inv excentricity. 
   local _ex2 = (.99-ex)*(.99-ex)--_ex*_ex

   local speed = g_vars.init_speed+rnd(0.15*g_vars.init_speed)
   --local life = .2+rnd(.6)
   local life = 0.7+rnd(0.2)

   -- fill preallocated particle
   part.is_alive = true
   part.x = cx+ox
   part.y = cy+oy
   part.vx = _ex2*speed*cos(dir)
   part.vy = _ex2*speed*sin(dir)
   part.radius = .5+_ex2*rnd(3)
   part.age = life
   part.max_age = life
   part.inv_max_age = 1./life
    -- todo: add variability in speed
    -- slow external particles move more
    -- randomly than central high speed parts.
    
   --part.draw = i_fire_particle.draw
   part.update = function(p)
    i_fire_particle.update(p,e.kd,e.kl)
   end
 end -- spawn_particle
 
 return e
end

function start_explosion(x,y)
  -- new ps
  ps = create_particle_system(x,y)
  -- insert emitters
  --local em = create_quad_fire_emitter(0,0)
  --add(ps.emitters,em)

  local fe_left = create_fire_emitter(0,0,-1,0,2)
  add(ps.emitters,fe_left)

  local fe_right = create_fire_emitter(0,0,1,0,2)
  add(ps.emitters,fe_right)

  local fe_top = create_fire_emitter(0,0,0,-1,2)
  add(ps.emitters,fe_top)

  local fe_bottom = create_fire_emitter(0,0,0,1,2)
  add(ps.emitters,fe_bottom)
  
  ps:init()
  
  add(pss,ps)
end


function update_fxs()
 for ps in all(pss) do
  ps:update()
  if not ps.is_active then
   del(pss,ps)
  end
 end
end

-- camera shake effect

cam_shk_x = 0
cam_shk_y = 0
cam_shk_amnt = 0
cam_shk_damp = 0
 
function start_screen_shake(max_radius,damp)
 cam_shk_x = 0
 cam_shk_y = 0
 cam_shk_amnt = max_radius
 cam_shk_damp = damp
end

function update_camera_shake()
 -- dampen shake intensity
 cam_shk_amnt*=cam_shk_damp+rnd(.1)
 -- new random direction at each frame?
 local a=rnd()
 cam_shk_x,cam_shk_y = cam_shk_amnt*cos(a), cam_shk_amnt*sin(a)
 if cam_shk_amnt<1 then
  cam_shk_amnt,cam_shk_x,cam_shk_y=0,0,0
 end
end



-->8
---------
-- MAIN
---------

-- initial good ones for quad fire emitter, with too omuch particles.
--g_vars = { explo_duration=0.25, init_speed=300, damp=9, lift_factor=100, nb_particles_per_emission=30, cam_shk_amnt=6, cam_shk_damp=0.7, }

-- init good ones for 4 separate emitters
--g_vars = { explo_duration=0.25, init_speed=300, damp=9, lift_factor=100, nb_particles_per_emission=5, cam_shk_amnt=6, cam_shk_damp=0.7, }

--g_vars = { min_part_size=.5,max_part_size=3,part_size_variance=0.1,explo_duration=0.25, init_speed=300, damp=9, lift_factor=100, nb_particles_per_emission=5, cam_shk_amnt=6, cam_shk_damp=0.7, }
g_vars = { min_part_size=0.5, max_part_size=3.5, part_size_variance=0.1, explo_duration=0.25, init_speed=300, damp=9, lift_factor=100, nb_particles_per_emission=2, cam_shk_amnt=6, cam_shk_damp=0.7, }

function _init()
 profiler = create_profiler()
 profiler:init()
 pss={}
 
 tweak_vars:add("min_part_size","mips",0.1)
 tweak_vars:add("max_part_size","maps",0.1)
 tweak_vars:add("part_size_variance","psv",0.1)
 
 tweak_vars:add("explo_duration","ed",0.1)
 tweak_vars:add("init_speed","is",10)
 tweak_vars:add("damp","d",0.1)
 tweak_vars:add("lift_factor","lf",10)
 tweak_vars:add("nb_particles_per_emission","nbp",1)
 tweak_vars:add("cam_shk_amnt","ska",1)
 tweak_vars:add("cam_shk_damp","skd",0.1)
end

function _update60()

 t+=dt
 
 if btnp(4) then 
  start_screen_shake(g_vars.cam_shk_amnt,g_vars.cam_shk_damp) 
  start_explosion(64+4, 64-4)
 end
 
 if btnp(5) then 
  start_screen_shake(g_vars.cam_shk_amnt,g_vars.cam_shk_damp) 
  start_explosion(64+rnd(50), 64+rnd(50))
 end
 
 
 update_fxs()
 update_camera_shake()
 tweak_vars:update()
 profiler:update()
end

function _draw()
 cls(12)
 camera(cam_shk_x,cam_shk_y)
 draw_fake_map()
 draw_fxs()
 debug_draw()
 profiler:draw()
 tweak_vars:draw()
end


function draw_fxs()
 for ps in all(pss) do
  ps:draw()
 end
end

function draw_fake_map()
 map(0,0,0,0,16,16)
end

function debug_draw()
 --print("nb_fxs: "..#pss,0,0,8)
 --[[
 local y=8
 for i=1,#pss do
  print("fx["..i.."].nb_emitters: "..#pss[i].emitters,0,y,8) y+=8
  for j=1,#pss[i].emitters do
   print("  e["..j.."].nb_particles_alive: "..pss[i].emitters[j].nb_particles,0,y,8) y+=8
  end
 end
 ]]
end
__gfx__
00000000ffffffffffffffffffffffff11dfffff11111111ff111111111111110000000000000000000000000000000000000000000000000000000000000000
00000000f7777775ffffffffff77776d1177776d1177776dff77776d1177776d0000000000000000000000000000000000000000000000000000000000000000
00700700f76666d51ffffffff7dd6d7117dd6d71d7dd6d7117dd6d7117dd6d710000000000000000000000000000000000000000000000000000000000000000
00077000f76666d511fffffff766766117667661f766766117667661176676610000000000000000000000000000000000000000000000000000000000000000
00077000f7666dd511dffffffd77d6d11d77d6d1fd77d6d11d77d6d11d77d6d10000000000000000000000000000000000000000000000000000000000000000
00700700f766ddd511dffffff7dd666d17dd666df7dd666d17dd666d17dd666d0000000000000000000000000000000000000000000000000000000000000000
00000000f7dddd5511dffffff7d66d6117d66d61f7d66d6117d66d6117d66d610000000000000000000000000000000000000000000000000000000000000000
00000000f555555511dffffffd11d1111d11d111fd11d1111d11d1111d11d1110000000000000000000000000000000000000000000000000000000000000000
00000000ff11111111dfffff00000000ffffffffffffffffffffffffffffffff0000000000000000ffffffff00000000ffffffff000000000000000000000000
00000000fff1111111dfffff00000000f7777775f7777775f7777775ffffffff0000000000000000ffffffff00000000f7777775000000000000000000000000
00000000ffffdddddddfffff00000000f76666d5176666d5176666d51fffffff00000000000000001fffffff00000000176666d5000000000000000000000000
00000000ffffffffffffffff00000000f76666d5176666d5176666d511ffffff000000000000000011ffffff00000000176666d5000000000000000000000000
00000000ffffffffffffffff00000000f7666dd517666dd517666dd511dfffff000000000000000011dfffff0000000017666dd5000000000000000000000000
00000000ffffffffffffffff00000000f766ddd51766ddd51766ddd511dfffff000000000000000011dfffff000000001766ddd5000000000000000000000000
00000000ffffffffffffffff00000000f7dddd5517dddd5517dddd5511dfffff000000000000000011dfffff0000000017dddd55000000000000000000000000
00000000ffffffffffffffff00000000f5555555155555551555555511dfffff000000000000000011dfffff0000000015555555000000000000000000000000
00000000ffffffffff11111100000000ff111111111111111111111111dfffff00000000ff11111111dfffff0000000011111111000000000000000000000000
00000000fffffffffff1111100000000f777777517777775177777751777777500000000f777777511dfffff0000000011d11111000000000000000000000000
00000000ffffffff1fffdddd00000000f76666d5176666d5176666d5176666d500000000f76666d51ddfffff00000000dddfdddd000000000000000000000000
00000000ffffffff11ffffff00000000f76666d5176666d5176666d5176666d500000000f76666d511ffffff00000000ffffffff000000000000000000000000
00000000ffffffff11dfffff00000000f7666dd517666dd517666dd517666dd500000000f7666dd511dfffff00000000ffffffff000000000000000000000000
00000000ffffffff11dfffff00000000f766ddd51766ddd51766ddd51766ddd500000000f766ddd511dfffff00000000ffffffff000000000000000000000000
00000000ffffffff11dfffff00000000f7dddd5517dddd5517dddd5517dddd5500000000f7dddd5511dfffff00000000ffffffff000000000000000000000000
00000000ffffffff11dfffff00000000f555555515555555155555551555555500000000f555555511dfffff00000000ffffffff000000000000000000000000
00000000ff1111111111111111dfffffff1111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000
00000000f77777751777777517777775f7777775177777751777777511d111111777777500000000000000000000000000000000000000000000000000000000
00000000176666d5d76666d5176666d5f76666d5176666d5176666d51ddfddddd76666d500000000000000000000000000000000000000000000000000000000
00000000176666d5f76666d5176666d5f76666d5176666d5176666d511fffffff76666d500000000000000000000000000000000000000000000000000000000
0000000017666dd5f7666dd517666dd5f7666dd517666dd517666dd511dffffff7666dd500000000000000000000000000000000000000000000000000000000
000000001766ddd5f766ddd51766ddd5f766ddd51766ddd51766ddd511dffffff766ddd500000000000000000000000000000000000000000000000000000000
0000000017dddd55f7dddd5517dddd55f7dddd5517dddd5517dddd5511dffffff7dddd5500000000000000000000000000000000000000000000000000000000
0000000015555555f555555515555555f5555555155555551555555511dffffff555555500000000000000000000000000000000000000000000000000000000
__map__
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212114151602212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
212121212121212407262a212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121141515151531373233151602212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
21212407372c2c2c12112c05262a212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
212134353315151502141531362a212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121112c2c2c2c382a24372c2c12212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
21212121212121242a242a212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
212121212121212404312a212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
212121212121213436362a212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
21212121212121112c2c12212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
