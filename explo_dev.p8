pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--explosion test
--droune

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





function create_particle_system(max_nb_parts,px,py)
 local particle_system = {
  particles = {},
  emitter = nil,
  emit_time_left = 0, -- put in emitters
  max_particles = max_nb_parts or 1000,
  nb_active_particles = 0,
  first_free_cell = 1, -- 0 if full
  x = px or 0,
  y = py or 0,
  is_active = false,
  
  allocate_particle = function(this,n)
   return {
    is_alive = false,
    next_free_cell = n+1
   }
  end,
  
  init = function(this)
   this.is_active = true
   for i=1,this.max_particles do
    add(this.particles, this:allocate_particle(i))
   end
   this.particles[this.max_particles].next_free_cell = 0
  end,
  
  update = function(this)   
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

   if this.emit_time_left > 0 then
    this:emit()
    this.emit_time_left -= dt
    if this.emit_time_left - .001 < 0 then
      this.emit_time_left = 0
    end
   end
   
   -- check for end of fx
   if this.nb_active_particles == 0 then
    -- todo: for all emitters
    if this.emit_time_left == 0 then
     this.is_active = false
    end
    -- +check if not in pre-emit state.
   end
  end,
  
  draw = function(this)
   for p in all(this.particles) do
    if p.is_alive then 
     p:draw()
    end
   end
  end,
  
  emit = function(this)
   if this.emitter ~= nil then
    local e = this.emitter
    local num_to_emit = e.n
    while this.first_free_cell > 0 and num_to_emit > 0 do
     -- pop head of list, list points to next
     local f = this.first_free_cell
     this.first_free_cell = this.particles[f].next_free_cell
     this.particles[f] = e:spawn_particle(this.x,this.y)
     num_to_emit -= 1
     this.nb_active_particles += 1
    end
   end
  end
 }
 particle_system:init()
 return particle_system
end

function create_omni_emitter()
 return {
  n = 50,
  
  spawn_particle = function(this,cx,cy)
   local r = rnd(25)+10
   local theta = rnd(1)
   return {
    is_alive = true,
    x = cx+4+rnd(4)-2,
    y = cy+4+rnd(4)-2,
    dx = r*cos(theta),
    dy = r*sin(theta),
    damp = 1,
    col = 1+flr(rnd(15)), -- no 0
    radius = 2+rnd(4),
    age = rnd(5),
    next_free_cell = 0, -- will be set upon dying
    
    draw = function(p)
     palt(0,false)
     circfill(p.x,p.y,p.radius+1,0)
     circfill(p.x,p.y,p.radius,p.col)
    end,
    
    update = function(p)
     p.x += dt * p.dx
     p.y += dt * p.dy
    end
   }
  end
 }
end



function create_quad_fire_emitter()
 return {
  n = _nb_particles_per_emission,
  
  spawn_particle = function(e,cx,cy)
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

   return {
    is_alive = true,
    x = cx+ox,
    y = cy+oy,
    vx = _ex2*speed*cos(dir),
    vy = _ex2*speed*sin(dir),
    -- todo: add variability in speed
    -- slow external particles move more
    -- randomly than central high speed parts.
    fx = 0,
    fy = 0,
    ax = 0,
    ay = 0,
    m = 1,
    kd = _damp,
    kl = _lift_factor, -- lift factor
    --colors={10,9,9,8,8,8,13,13,13,13},
    colors={10,9,9,8,13,13,13},
    radius = .5+_ex2*rnd(3),
    age = life,
    max_age = life,
    next_free_cell = 0, -- will be set upon dying
    
    draw = function(p)
     -- color ramp by age
     local color = p.colors[1+flr(#p.colors*(p.max_age-p.age)/p.max_age)]
     if p.radius < 1.5 then
      pset(p.x,p.y,color)
     else
      circfill(p.x,p.y,p.radius,color)
     end
     
    end,
    
    update = function(p)
     
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
     
     p.ax = p.fx / p.m
     p.ay = p.fy / p.m
     
     p.x += p.vx * dt
     p.y += p.vy * dt
     
     p.vx += p.ax * dt
     p.vy += p.ay * dt
     
    end
   }
  end
 }
end

function start_explosion(x,y)
  -- new ps
  ps = create_particle_system(1000,x,y)
  -- insert emitters
  ps.emitter = create_quad_fire_emitter()
  ps.emit_time_left = _explo_duration -- duuration should be for each emitter
  
  
  
  
  
  
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
 pss={}
 --ps = create_particle_system(1000, 64+4, 64-4)
 -- mettre plusieurs emitters dans un ps.
 --ps.emitter = create_quad_fire_emitter()
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
 
end

function _draw()
 cls(12)
 camera(cam_shk_x,cam_shk_y)
 draw_fake_map()
 draw_fxs()
 debug_draw()
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
  print("fx["..i.."].nb_alive: "..pss[i].nb_active_particles,0,8,8)
 end
 --print("shk_amnt: ".._cam_shk_amnt.." "..cam_shk_amnt,0,8,12)
 --print("shk_damp: ".._cam_shk_damp,0,16,12)
 --print("_init_speed: ".._init_speed,0,8,12)
 --print("_damp: ".._damp,0,16,12)
 --print("_explo_duration: ".._explo_duration,0,8,12)
 --print("_nb_parts_per_em: ".._nb_particles_per_emission,0,16,12)
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
