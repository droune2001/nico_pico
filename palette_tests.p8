pico-8 cartridge // http://www.pico-8.com
version 15
__lua__
-- palette
-- droune

function _init()
 pal_idx=0
 init_palettes(39)
 
 -- effects:
 -- 0 = normal 
 -- 1 = fade-to-black-8
 -- 2 = fade-to-black-6
 -- 3 = fade-to-white-4
 -- 4 = fade-in-from-black-8
 -- 5 = fade-in-from-black-6
 -- 6 = fade-in-from-white-4
 fx = { id=0, active=0, pal_start=0, pal_end=0, curr_pal=0, t=0, max_t=2, dir=1, debug_t=0 }
 current_fx = 0
end
-->8
-- update

function _update()
 
 local dt = 1/30
 
 if btnp(0) then pal_idx = (pal_idx-1)%40 end
 if btnp(1) then pal_idx = (pal_idx+1)%40 end
 
 if btnp(2) then current_fx = ( current_fx + 1 ) % 7 end
 if btnp(3) then current_fx = ( current_fx - 1 ) % 7 end
 
 if btnp(4) then start_fx( current_fx ) end
 if btnp(5) then fx.active=0 end
 
 if not btnp(4) and not btnp(5) then
  update_fx(dt)
 end
end

function update_fx(dt)
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

function start_fx(id)
 fx.id = id
 fx.active=1
 fx.t=0
 fx.max_t=2
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

-->8
-- draw

function apply_palette_fx()
 if fx.active == 0 or fx.id == 0 then 
  set_palette(0) 
 else
  set_palette(fx.curr_pal)
 end
end

function draw_bg(dt)

 -- shit palette
 --set_palette(pal_idx)
 apply_palette_fx()
 -- draw stretched sprite.
 sspr(12*8,0,4*8,4*8,0,0,4*4*8,4*4*8)
 -- reset palette 
 pal()
 
end
 
function draw_text(dt)
 local a = 0.5 -- align center
 shprint("align text",64,10,4,a)
 shprint("center",64,20,4,a)
 a = 1 -- align right
 shprint("align text",64,40,4,a)
 shprint("right",64,50,4,a)
 a = 0 -- align left
 shprint("align text",64,70,4,a)
 shprint("left",64,80,4,a)
 
 shprint("palette_fx: "..current_fx,     0, 0,  15, 0)
 shprint("fx_active: "..fx.active,       0, 8,  15, 0)
 shprint("fx_pal_start: "..fx.pal_start, 0, 16, 15, 0)
 shprint("fx_pal_end: "..fx.pal_end,     0, 24, 15, 0)
 shprint("fx_pal: "..fx.curr_pal,        0, 32, 15, 0)
 shprint("fx_t: "..fx.t,                 0, 40, 15, 0)
 shprint("fx_debug_t: "..fx.debug_t,     0, 48, 15, 0)
end

function draw_palettes(dt)
 for p=0,39 do
  for c=0,15 do
   pset(p,127-15+c,peek(0x5000+shl(p,4)+c))
  end
 end
 pset(pal_idx%40,127-16,8)
end

function _draw()
 local dt = 1/30
 cls()
 draw_bg(dt)
 draw_palettes(dt)
 draw_text(dt)
end
-->8
-- utils

-- copies props to obj
-- if obj is nil, a new
-- object will be created,
-- so set(nil,{...}) copies
-- the object
function set(obj,props)
 obj=obj or {}
 for k,v in pairs(props) do
  obj[k]=v
 end
 return obj
end

-- calls fn(character,index)
-- for each character in str
function each_char(str,fn)
 for i=1,#str do
  fn(sub(str,i,i),i)
 end
end

-- helper, calls a given func
-- with a table of arguments
-- if fn is nil, returns the
-- arguments themselves - handy
-- for the e(...) serialization
-- trick
function call(fn,a)
 return fn
  and fn(a[1],a[2],a[3],a[4],a[5])
  or a
end

--lets us define constant
--objects with a single
--token by using multiline
--strings
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

--lets us define large lookup
--tables using one token, via
--string parsing and multiline
--strings
-- multilines are [[ ]]
-- each line is one object
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

 -- 0x5000 is an adress inside the personal address space 0x4300-0x5dff 
 local a=0x5000 
 
 -- n: the number of columns of palettes to read from the spritesheet.
 -- sod -> for each column p in the spritesheet
 for p=0,n do
 
  -- The spritesheet starts at address 0x0000,
  -- so "pri" is the starting address of a column
  -- in the spritesheet. 
  -- pri will go from 0 to 23, then 16(x8) and 17(x8)
  -- sec will stay at 8 for x24, then 0..7 2 times.
  local pri=p
  local sec=8
  
  -- after the 24 first palettes
  -- read 16 other palettes, as 2 sets of 8 palettes
  -- column 16 and 17 reorder the palette gradient
  -- we read from column 8 to 16.
  if p>=24 then
   pri=13+p/8
   sec+=p%8
  end
  
  -- 16 colors to read
  for c=0,15 do
  
   -- use indirection to build further palettes.
   -- one column reorders the palette, and point to
   -- a 8 values decay.
   -- not useful for normal palette.
   local v=sget(sec,sget(pri,c))
   
   -- c = 3 is dark green, used for transparency.
   -- if that color is found in the palette, set
   -- the transparency bit (8th bit -> 0x80)
   if (c==3) v+=0x80
   
   -- store c-th color replacement in personal
   -- address space. 16 indices in a row.
   poke(a,v)
   
   -- advance personal address space dest by 1.
   a+=1
  end
 end
end

function set_palette(no)
 -- shl(x,4) = x16, palettes are 16 bytes long
 -- copy 16 for the same reason.
 -- flr(no or 8): flr for float-to-int. if no == 0
 -- copy palette nb 8, which is our identity palette.
 -- 0x5f00 is the address of the draw palette.
 --memcpy(0x5f00, 0x5000+shl(flr(no or 8),4), 16)
 memcpy(0x5f00,0x5000+shl(flr(no),4),16)
end

function dim_object(o,mx)
 set_palette(scr.psh+
  mid((o.pos.y-lgt.pos.y)*0.4+o.z*0.5,
      0,mx)
 )
end

__gfx__
00000000000000000000005700000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333
1110001111000000101015d700000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333
22110025211000005121249700000000000000000000000000000000000000000000000000000000000000000000000033330000000000000000000000003333
333110333311000033333bf700000000000000000000000000000000000000000000000000000000000000000000000033330111111111111111111111103333
4221102d44221000d14149a700000000000000000000000000000000000000000000000000000000000000000000000033330222222220222222222222203333
551110555511000055555d6700000000000000000000000000000000000000000000000000000000000000000000000033330444000044400040440044403333
66d5106666dd51006666677700000000000000000000000000000000000000000000000000000000000000000000000033330555550550550550550555503333
776d1077776dd5507f79777700000000000000000000000000000000000000000000000000000000000000000000000033330666660660660660060066603333
882210188882210088888ee700000000000000000000000000000000000000000000000000000000000000000000000033330777777777077777777777703333
9422104c9994210062949a7700000000000000000000000000000000000000000000000000000000000000000000000033330888888888880008888888803333
a9421047aa99421074a9a77700000000000000000000000000000000000000000000000000000000000000000000000033330999999999090099999999903333
bb3310bbbbb331001929bf7700000000000000000000000000000000000000000000000000000000000000000000000033330aaaaaaaaa0a000aaaaaaaa03333
ccd510ccccdd5110ccccc77700000000000000000000000000000000000000000000000000000000000000000000000033330bbbbbbbbbbbbbbbbbbbbbb03333
d55110dddd511000ddddd67700000000000000000000000000000000000000000000000000000000000000000000000033330ccc0cc0c00c00cc00ccccc03333
ee82101eee882210eeeeef7700000000000000000000000000000000000000000000000000000000000000000000000033330ddd0000d0dd00dd0dddddd03333
f94210f7fff9421079f9f77700000000000000000000000000000000000000000000000000000000000000000000000033330eee0ee0e00e0e0e00eeeee03333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033330ffffffffffffffffffffff03333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033330000000000000000000000003333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333555555555553333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333577777777763333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333579999999863333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333579bbbbba863333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333579bdddca863333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333579bdfeca863333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333579beeeca863333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333579ccccca863333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333357aaaaaaa863333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333588888888863333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333666666666663333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333
