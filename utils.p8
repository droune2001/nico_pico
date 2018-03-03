pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--utils
--droune

--
-- jose guerra
--

-- lenght of 2d vector
-- i suppose this is to avoid too big numbers
-- when doing xx+yy, because of 16bits...??
function mag(x,y)
  local d=max(abs(x),abs(y))
  local n=min(abs(x),abs(y))/d
  return sqrt(n*n+1)*d
end

--
function normalize(x,y)
  local m=mag(x,y)
  return x/m,y/m,m
end


-- objectize the behavior of button presses
-- with extra info
function create_button(btn_num)
 return 
 {
  time_since_press=100,
  last_time_held=0,
  time_held=0,
  time_released=0,
  button_number=btn_num,

  button_init=function(b)
   b.time_since_press,b.time_held=100,0
  end,

  button_update=function(b)
   b.time_since_press+=one_frame

   if btn(b.button_number) then
    if b.time_held==0 then
     b.time_since_press=0
    end
  
    b.time_held+=one_frame
   else
    if(b.time_held!=0)b.time_released=0
    b.last_time_held=b.time_held
    b.time_held=0
    b.time_released+=one_frame
   end
  end,

  button_consume=function(b)
   b.time_since_press=100
  end,
 }
end

-- global
jump_button=create_button(5)
shoot_button=create_button(4)

-- on start
jump_button:button_init()

-- on update
jump_button:button_update()
-- update player
if jump_button.time_since_press<.2 then
 -- reset internal timer
 jump_button:button_consume()
end




-- numer list. saves tokens.
-- usage: colors = nl("3,3,11,11,3,11,11,7,10")
function nl(s)
 local a={}
 local ns=""
 
 while #s>0 do
  local d=sub(s,1,1)
  if d=="," then
   add(a,ns+0) -- +0 -> atoi(ns)
   ns=""
  else
   ns=ns..d -- concatenate subsequent digits to make numbers
  end
  
  s=sub(s,2)
 end
 
 return a
end


-- cam shake
cam_shake_x,cam_shake_y,cam_shake_damp=0,0,0

-- start shake
function screenshake(max_radius,damp)
 local a=rnd()
 cam_shake_x,cam_shake_y=max_radius*cos(a),max_radius*sin(a)
 cam_shake_damp=damp
end

screenshake(6,.7)
screenshake(6,.8)

-- update
function update_screeneffects()
 cam_shake_x*=cam_shake_damp+rnd(.1)
 cam_shake_y*=cam_shake_damp+rnd(.1)
 if abs(cam_shake_x)<1 and abs(cam_shake_y)<1 then
  cam_shake_x,cam_shake_y=0,0
 end
end

-- draw
camera(cam_x+cam_shake_x,cam_y+cam_shake_y)



--
-- Celeste
--

-- object model, by composition?

car_type = {
 init=function(this)
  -- adds members to whom calls init
  this.var1=1
 end,
 update=function(this)
  this.var += 1
 end,
 draw=function(this)
  circfill(10,10,this.var1,7)
 end
}

add(types,car_type)

plane_type={
 -- ...
}

add(types,plane_type)

function init_object(type,x,y)
 local obj={}
 -- common members to all objects.
 obj.x = x
 obj.y = y
 -- holds a ref to an object with
 -- a common interface but different
 -- implementation. the "virtual" part
 -- of the object.
 obj.type = type
 
 obj.is_colliding=function(px,py)
  -- here we can access obj which is an
  -- "external local variable". Closure.
  -- call obj.is_colliding(x,y), not
  -- obj:is_colliding(x,y), it does not
  -- need the "this" in this case.
 end,
 
 
 -- adds the object to a global array
 -- on which we can foreach and calls
 -- init, update and draw (and more)
 add(objects,obj)
 
	if obj.type.init~=nil then
  -- use the type.init function with obj data,
  -- which adds members of type to obj.
		obj.type.init(obj)
  -- obj.type:init() would have init the unique
  -- type object. We dont want that, it serves as
  -- an interface.
	end
	return obj
 
end

-- usage. adds an object with a generic obj part
-- and a specific "car_type" part.
-- adds it to the global object array, and returns it.
init_object(car_type, 64, 50)
-- can even directly add members.
init_object(plane_type,4,2).has_wings = true

-- type is just a ref to the unique object instance
-- representing the type.
if objects[i].type==player then 
end

tile = xxx -- read from map
-- find the corresponding type
-- and spawn an object.
foreach(types, 
				function(type) 
					if type.tile == tile then
						init_object(type,x,y) 
					end 
				end)
    
function destroy_object(obj)
	del(objects,obj)
end

foreach(objects,destroy_object)

function draw_object(obj)
	if obj.type.draw ~=nil then
  -- call draw on obj, not on type
		obj.type.draw(obj)
 end
end

-- draw objects
foreach(objects, function(o)
	if o.type~=platform and o.type~=big_chest then
		draw_object(o)
	end
end)




	-- screenshake
	if shake>0 then
		shake-=1
		camera()
		if shake>0 then
			camera(-2+rnd(5),-2+rnd(5))
		end
	end
 
 
function sign(v)
	return v>0 and 1 or
								v<0 and -1 or 0
end

function maybe()
	return rnd(1)<0.5
end
