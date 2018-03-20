pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- mouse
-- droune2001

mouse = {
 x = 0,
 y = 0,
 -- only left button
 is_pressed = false,
 just_pressed = false,
 just_released = false,
 init = function()
   poke(0x5f2d, 1)
 end,
 update = function(this)
  this.x,this.y=this:pos()
  local b = this:button()
  if band(b,1) == 1 then
   if this.is_pressed then 
    this.just_pressed = false
   else
    this.is_pressed = true
    this.just_pressed = true
	this.just_released = false
   end
  else
   if this.is_pressed then
    this.just_released = true
	this.just_pressed = false
	this.is_pressed = false
   end
  end
 end,
 -- return int:x, int:y
 pos = function()
   return stat(32)-1,stat(33)-1
 end,
 -- return int:button [0..4]
 -- 0 .. no button
 -- 1 .. left
 -- 2 .. right
 -- 4 .. middle
 button = function()
   return stat(34)
 end
}

buttons = {}

function create_button(tlx,tly,title,color,callback)
 return {
  x=tlx,
  y=tly,
  w=2+4*#title,
  h=2+6+2,
  t=title,
  c=color,
  cb=callback,
  intersects = function(this,mx,my)
   return mx >= this.x and mx <= this.x+this.w and
          my >= this.y and my <= this.y+this.h
  end,
  draw = function(b)
   rectfill(b.x,b.y,b.w,b.h,b.c)
   print(b.t,b.x+2,b.y+2,7)
  end,
 }
end

function check_buttons_clicked()
 local mx,my=mouse.x,mouse.y
 if mouse.just_pressed then
  for b in all(buttons) do
   if b:intersects(mx,my) then
    b.cb()
   end
  end
 end
end

function draw_buttons()
 for b in all(buttons) do
  b:draw()
 end
end

function on_test_button()
 print("toto",rnd(100),rnd(100),7)
end

function _init()
 mouse.init()
 add(buttons,create_button(0,0,"test",4,on_test_button))
end

function _update60()
 mouse:update()
end

function _draw()
  cls()
  check_buttons_clicked()
  
  local x,y = mouse.pos()
  local b = mouse.button()
  print("x:"..x.." y:"..y.." b:"..b, 0,120,7)
  
  draw_buttons()
  
  spr(0,x,y)
end
