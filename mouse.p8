pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- mouse
-- droune2001

--[[ todo:
- checkable buttons
- sliders
- spinbox
]]

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
i_button = {
  on_mouse_press_event = function(b)
    if b.chkbl then 
     b.chkd = not b.chkd
     b.cb(b.chkd)
    else
     b.cb()
    end
  end,
  intersects = function(b,mx,my)
   return mx >= b.x and mx <= b.x+b.w and
          my >= b.y and my <= b.y+b.h
  end,
  draw = function(b)
   local x1,x2,y1,y2 = b.x,b.x+b.w,b.y,b.y+b.h-2
   local c1,c2 = b.chkd and 5 or 6,b.chkd and 6 or 5
   palt(b.c,false)
   rectfill(x1+1,y1+1,x2-1,y2-1,b.c)
   line(x1,y1,x2,y1,c1)
   line(x1,y1,x1,y2,c1)
   line(x2,y1,x2,y2,c2)
   line(x1,y2,x2,y2,c2)
   print(b.t,x1+2,y1+2,7)
  end
}

function create_button(tlx,tly,title,color,callback,checkable)
 return {
  x=tlx,
  y=tly,
  w=2+4*#title,
  h=2+6+2,
  t=title,
  c=color,
  chkbl=checkable or false,
  chkd=false,
  cb=callback 
 }
end

function check_buttons_clicked()
 local mx,my=mouse.x,mouse.y
 if mouse.just_pressed then
  for b in all(buttons) do
   if i_button.intersects(b,mx,my) then
    i_button.on_mouse_press_event(b)
   end
  end
 end
 -- on hover
 -- on right clik
 -- on release
end

function draw_buttons()
 for b in all(buttons) do
  i_button.draw(b)
 end
end

function on_test_button()
 print("toto",rnd(100),rnd(100),9)
end

function on_test_checkable_button(chkd)
 print("titi chkd:"..(chkd and "true" or "false"),rnd(100),rnd(100),8)
end


-------------------------
-- var list
-------------------------
g_vars = {
 nb_part_emit = 25,
 life = 1.5 
}

tweak_vars = {
 current = 1,
 var_list = {},
 
 add_tweak_var = function( tv, var_name, viz_name, incr )
  local one_var = { vn=var_name, vin=viz_name, i=incr }
  add(tv.var_list,one_var)
 end,
 
 update = function(tv)
  if btnp(2) then
   tv.current += 1
   if tv.current == #tv.var_list + 1 then
    tv.current = 1
   end
  end
  
  if btnp(3) then
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
   print(v.vin..": <"..g_vars[v.vn]..">",0,(k-1)*8, k == tv.current and 8 or 7)
  end
  -- draw current in bold
  -- scroll view depending on current and direction and distance to brders
 end,
 
 dump_to_clipboard = function(tv)
  -- print g_vars object with name and values, to clipboard
  local str = "g_vars = {"
  for v in all(tv.var_list) do
   str = str.."\""..v.vn.."\" = "..g_vars[v.vn]..","
  end
  str = str.."}"
  printh(str, "@clip")
  -- find special clip command @clip ???
 end
}

function _init()
 mouse.init()
 add(buttons,create_button(0,0,"test",4,on_test_button))
 add(buttons,create_button(0,10,"test_chkbl",8,on_test_checkable_button,true))
 add(buttons,create_button(0,20,"test",12,on_test_button))
 add(buttons,create_button(0,30,"test_chkbl",13,on_test_checkable_button,true))
 
 tweak_vars:add_tweak_var( "nb_part_emit", "emit num", 1 )
 tweak_vars:add_tweak_var( "life", "liffe", 0.1 )
end

function _update60()
 mouse:update()
 tweak_vars:update()
end

function _draw()
  cls()
  check_buttons_clicked()
  
  local x,y = mouse.pos()
  local b = mouse.button()
  print("x:"..x.." y:"..y.." b:"..b, 0,120,7)
  
  draw_buttons()
  
  tweak_vars:draw()
  
  print(g_vars.nb_part_emit.." "..g_vars.life,64,64,9)
  
  
  spr(0,x,y)
end
