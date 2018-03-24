pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--explosion test
--droune
--[[
todo
* multiple emitters per particle system / fx
* optimize simulation / do it once every other frame.
  have the emitters specify their update rate?
* less particles in the explosion.
* split 4 fire burst into 4 emitters, with different length.
* add central explo.
* add rocks explo (up to 4)
* think about how to handle multiple aligned
  explosions with many aligned rocks. Do you treat
  chain explosions in succession or simultaneously?
  do you explode 1 rock or as many as there are reaching bombs?
]]


-- debug vars
_explo_duration=0.25
_init_speed,_damp=300,9 --150,3
_lift_factor=100
_nb_particles_per_emission=25
_cam_shk_amnt = 6
_cam_shk_damp = .7

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
------------------
-- particle system
------------------

function create_particle_system(px,py)
 return {
  x = px or 64,
  y = py or 64,
  emitters = {},
  nb_emitters_alive = 0,
  is_active = false,
    
  init = function(this)
   this.is_active = true
   -- todo: use foreach syntax with function
   for e in all(this.emitters) do
    e:init()
   end
  end,
  
  update = function(this)
   local any_still_active = false  
   for e in all(this.emitters) do
    e:update(this.x,this.y)
    any_still_active = any_still_active or e.is_active
   end
   this.is_active = any_still_active
  end,
  
  draw = function(self)
   -- all drawn one on top of the other,
   -- no order of emitters.
   -- maybe each emitter should have its own
   -- particle array. derive from common emitter
   -- with particle update code.
   for e in all(self.emitters) do
    -- todo: add priority, or z-order
    e:draw()
   end
  end
 }
end

function create_emitter(t,max_nb_parts,cx,cy)
 return {
  x = cx or 0,
  y = cy or 0,
  particles = {},
  max_particles = max_nb_parts or 100,
  nb_particles = 0,
  
  emit_time_left = t, -- put in emitters
  is_active = false,
  
  init = function(this)
   this.is_active = true
   for i=1,this.max_particles do
    add(this.particles,{is_alive = false}) -- todo: trade a bool for computation, if need be.
   end
  end,
  
  update = function(this,psx,psy)
   
   -- emit
   if this.emit_time_left > 0 then
    this:emit(psx+this.x,psy+this.y)
    this.emit_time_left -= dt
    if this.emit_time_left - .001 < 0 then
      this.emit_time_left = 0
    end
   end
   
   -- update particles
   for i=1,this.nb_particles do
    local p = this.particles[i]
    p.age -= dt
    if p.age < 0 then
     p.is_alive = 0 -- deprecated ?
     -- swap p with the tail of acctive particles
     -- note: dnt even need to put p at the end whn we
     -- get rid of is_alive.
     local tmp = this.particles[this.nb_particles]
     this.particles[this.nb_particles] = p
     this.particles[i] = tmp
     tmp.age -= dt
     -- todo: the swapped particle is no longer updated!!
     -- and we are touching the index used in the for loop!!
     -- use a while loop, abruti!
     this.nb_particles -= 1
    else
     p:update()
    end
   end
   --[[
   for i,p in pairs(this.particles) do
    if p.is_alive then
     p.age -= dt
     if p.age < 0 then
      p.is_alive = false
      this.nb_active_particles -= 1
      -- set as head of free list
      p.next_free_cell = this.first_free_cell
      this.first_free_cell = i
     else
      p:update()
     end
    end
   end
   ]]
   
   -- check for end of fx
   if this.nb_particles == 0 then
    if this.emit_time_left == 0 then
     this.is_active = false
    end
    -- +check if not in pre-emit state.
   end
  end,
  
  -- move to specific emitter impl
  emit = function(this,px,py)
   local num_to_emit = this.n or 10
   while this.nb_particles < this.max_particles and num_to_emit > 0 do
    -- pop head of list, list points to next
    local f = this.nb_particles + 1
    if this.spawn_particle ~= nil then 
     this:spawn_particle(this.particles[f],px,py)
     num_to_emit -= 1
     this.nb_particles += 1
    end
   end
  end,
  
  draw = function(self)
   for i=1,self.nb_particles do
    self.particles[i]:draw()
   end
  end
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
 local e = create_emitter(_explo_duration,300,x,y)
 -- complete it with specifics
 -- ...
 return e
end

function create_quad_fire_emitter(x,y)
 -- create generic emitter
 local e = create_emitter(_explo_duration,400,x,y)
 -- complete it with specifics
 e.n = _nb_particles_per_emission
  
 -- todo: takes a particle param "p"
 -- use p.toto and no return statement.
 e.spawn_particle = function(e,part,cx,cy)
   local dir = flr(rnd(4))/4 -- 4 quadrants for the sin/cos funcs
   --local speed = 150+rnd(25)
   
   local ox = rnd(4)-2+rnd(2)-1 -- -3,3
   local oy = rnd(4)-2+rnd(2)-1 -- -3,3
   local ex = abs(ox*oy)/(3*3+1) -- excentricity: 0 center, 1 corner
   local ex2 = ex*ex
   local _ex = .99-ex -- inv excentricity. 
   local _ex2 = _ex*_ex

   local speed = _init_speed+rnd(0.15*_init_speed)
   --local life = .2+rnd(.6)
   local life = 0.7+rnd(0.2)

   -- fill preallocated particle
   part.is_alive = true
   part.x = cx+ox
   part.y = cy+oy
   part.vx = _ex2*speed*cos(dir)
   part.vy = _ex2*speed*sin(dir)
    -- todo: add variability in speed
    -- slow external particles move more
    -- randomly than central high speed parts.
   part.fx = 0
   part.fy = 0
   part.ax = 0
   part.ay = 0
   part.m = 1
   part.kd = _damp
   part.kl = _lift_factor -- lift factor
    --colors={10,9,9,8,8,8,13,13,13,13}
   part.colors={10,9,9,8,13,13,13}
   part.radius = .5+_ex2*rnd(3)
   part.age = life
   part.max_age = life
   part.next_free_cell = 0 -- will be set upon dying
    
   part.draw = function(p)
    -- color ramp by age
    local color = p.colors[1+flr(#p.colors*(p.max_age-p.age)/p.max_age)]
    if p.radius < 1.5 then
     pset(p.x,p.y,color)
    else
     circfill(p.x,p.y,p.radius,color)
    end 
   end
    
   part.update = function(p)
     
    local age_pct = (p.max_age-p.age)/p.max_age
    local lift = age_pct*age_pct
    
    -- accum forces. drag, gravity, ...
    p.fx = 0
    p.fy = 0
    
    -- drag
    p.fx += -p.kd * p.vx
    p.fy += -p.kd * p.vy
    
    -- go up when dying. smoke if lighter.
    p.fy += -p.kl * lift
    
    p.ax = p.fx --/ p.m
    p.ay = p.fy --/ p.m
    
    p.x += p.vx * dt
    p.y += p.vy * dt
    
    p.vx += p.ax * dt
    p.vy += p.ay * dt
    
   end -- update
 end -- spawn_particle
 
 return e
end

function start_explosion(x,y)
  -- new ps
  ps = create_particle_system(x,y)
  -- insert emitters
  local em = create_quad_fire_emitter(0,0)
  add(ps.emitters,em)
  
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
   del(pss, ps)
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





function _init()
 profiler = create_profiler()
 profiler:init()
 pss={}
end

function _update60()

 t+=dt
 
-- if btnp(0) then _cam_shk_damp += .1 end
-- if btnp(1) then _cam_shk_damp -= .1 end

-- if btnp(2) then _cam_shk_amnt += 1 end
-- if btnp(3) then _cam_shk_amnt -= 1 end

-- if btnp(0) then _init_speed += 10 end
-- if btnp(1) then _init_speed -= 10 end

-- if btnp(2) then _damp += .1 end
-- if btnp(3) then _damp -= .1 end

-- if btnp(0) then _explo_duration -= .1 end
-- if btnp(1) then _explo_duration += .1 end

 if btnp(0) then _lift_factor -= 1 end
 if btnp(1) then _lift_factor += 1 end

 if btnp(2) then _nb_particles_per_emission -= 1 end
 if btnp(3) then _nb_particles_per_emission += 1 end

 if btnp(4) then 
  start_screen_shake(_cam_shk_amnt,_cam_shk_damp) 
  start_explosion(64+4, 64-4)
 end
 
 if btnp(5) then 
  start_screen_shake(_cam_shk_amnt,_cam_shk_damp) 
  start_explosion(64+rnd(50), 64+rnd(50))
 end
 
 
 update_fxs()
 update_camera_shake()
 
 profiler:update()
end

function _draw()
 cls(12)
 camera(cam_shk_x,cam_shk_y)
 draw_fake_map()
 draw_fxs()
 debug_draw()
 profiler:draw()
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
 print("nb_fxs: "..#pss,0,0,8)
 for i=1,#pss do
  --print("fx["..i.."].nb_alive: "..pss[i].nb_active_particles,0,8*i,8)
 end
 --print("shk_amnt: ".._cam_shk_amnt.." "..cam_shk_amnt,0,8,12)
 --print("shk_damp: ".._cam_shk_damp,0,16,12)
 --print("_init_speed: ".._init_speed,0,8,12)
 --print("_damp: ".._damp,0,16,12)
 --print("_explo_duration: ".._explo_duration,0,8,12)
 print("_nb_parts_per_em: ".._nb_particles_per_emission,0,16,12)
 --print("_lift_factor: ".._lift_factor,0,16,12)
 
 -- black-to-white color ramp
 local colors={0,8,9,10}
 
 for i=0,6 do
  for j=0,6 do
   local ox = i-3
   local oy = j-3
   local ex = abs(ox*oy)/(3*3+1) -- excentricity: 0 center, 1 corner
   local ex2 = ex*ex
   local _ex = .99-ex
   local _ex2 = _ex*_ex
   
   local ex_col = colors[1+flr(#colors * ex)]
   local ex2_col = colors[1+flr(#colors * ex2)]
   local _ex_col = colors[1+flr(#colors * _ex)]
   local _ex2_col = colors[1+flr(#colors * _ex2)]
   pset(10+ox,120+oy,ex_col)
   pset(20+ox,120+oy,ex2_col)
   pset(30+ox,120+oy,_ex_col)
   pset(40+ox,120+oy,_ex2_col)
  end
 end
 
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
