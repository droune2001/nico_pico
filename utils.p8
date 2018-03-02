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
