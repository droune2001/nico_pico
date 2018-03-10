pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--explosion test
--droune

-- debug vars
_explo_duration=0.25
--_init_speed,_damp=150,3
_init_speed,_damp=300,9
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
  emit_time_left = 0,
  max_particles = max_nb_parts or 1000,
  nb_active_particles = 0,
  first_free_cell = 1, -- 0 if full
  x = px or 0,
  y = py or 0,

  allocate_particle = function(this,n)
   return {
    is_alive = false,
    next_free_cell = n+1
   }
  end,
  
  init = function(this)
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
   local ex = abs(ox*oy)/(3*3) -- excentricity: 0 center, 1 corner
   local ex2 = ex*ex
   local _ex = 1.-ex
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
    --colors={10,9,9,8,8,8,13,13,13,13},
    colors={10,9,9,8,13,13,13},
    radius = 1.+_ex2*rnd(3),
    age = life,
    max_age = life,
    next_free_cell = 0, -- will be set upon dying
    
    draw = function(p)
     -- color ramp by age
     local color = p.colors[1+flr(#p.colors*(p.max_age-p.age)/p.max_age)]
     circfill(p.x,p.y,p.radius,color)
    end,
    
    update = function(p)
     
     -- accum forces. drag, gravity, ...
     p.fx = 0
     p.fy = 0
     
     p.fx += -p.kd * p.vx
     p.fy += -p.kd * p.vy
     
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

function start_explosion(durationSeconds)
  ps.emit_time_left = durationSeconds
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
 ps = create_particle_system(1000, 64+4, 64-4)
 -- mettre plusieurs emitters dans un ps.
 ps.emitter = create_quad_fire_emitter()
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


 if btnp(0) then _explo_duration -= .1 end
 if btnp(1) then _explo_duration += .1 end

 if btnp(2) then _nb_particles_per_emission -= 1 end
 if btnp(3) then _nb_particles_per_emission += 1 end

 if btnp(4) then 
  start_screen_shake(_cam_shk_amnt,_cam_shk_damp) 
  start_explosion(_explo_duration)
 end
 --if btn(4) then ps:emit() end
 
 ps:update()
 update_camera_shake()
 
end

function _draw()
 cls(12)
 camera(cam_shk_x,cam_shk_y)
 draw_fake_map()
 ps:draw()
 debug_draw()
end

function draw_fake_map()
 map(0,0,0,0,16,16)
end

function debug_draw()
 print("nb_alive: "..ps.nb_active_particles,0,0,8)
 --print("shk_amnt: ".._cam_shk_amnt.." "..cam_shk_amnt,0,8,12)
 --print("shk_damp: ".._cam_shk_damp,0,16,12)
 --print("_init_speed: ".._init_speed,0,8,12)
 --print("_damp: ".._damp,0,16,12)
 print("_explo_duration: ".._explo_duration,0,8,12)
 print("_nb_parts_per_em: ".._nb_particles_per_emission,0,16,12)
end
__gfx__
00000000ffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000f7777775ffffffffff77776d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700f76666d51ffffffff7dd6d71000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000f76666d511fffffff7667661000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000f7666dd511dffffffd77d6d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700f766ddd511dffffff7dd666d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000f7dddd5511dffffff7d66d61000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000f555555511dffffffd11d111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ff11111111dfffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000fff1111111dfffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffdddddddfffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffff11111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000fffffffffff1111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffff1fffdddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffff11ffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffff11dfffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffff11dfffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffff11dfffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffff11dfffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212101010102212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212101030102212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2101010101010101020101010101010200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2101030311111111121111030303010200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2101010101010101020101010101010200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2111111111111101020122111111111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212101020102212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212101030102212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212101010102212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212111111112212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
