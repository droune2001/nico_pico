pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- anim test
-- droune2001
--[[ todo

]]

function unpack(packed)
 unpacked={}
 for i=1,#packed,2 do
  local num = packed[i]
  local val = packed[i+1]
  for j=1,num do
   add(unpacked,val)
  end
 end
 return unpacked
end

function create_bomb(_f,_x,_y)
 local entity = {
  --sprites={23,24,25,26,27,28},
  sprites={55,56,57,58,59,60},
  anims={
   -- dir: 1=loop,2=once
   --idle={dir=1,frames=unpack({25,1, 4,2, 40,4, 4,5, 3,3})},
   idle={dir=1,frames=unpack({5,1, 5,2, 7,3, 7,4, 5,5})},
  },
  f=_f or 0, -- current anim frame index. 0-based.
  anim="idle",
  x=_x,
  y=_y,
  
  play_anim = function(self,a)
   self.anim = a
   self.f = 0
  end,
  
  update = function(self)
   local a = self.anims[self.anim]
   local nb_frames = #a.frames
   self.f = 
    (a.dir == 1) 
    and ( self.f + 1 ) % nb_frames 
    or min(nb_frames-1,self.f+1)
  end,
  
  draw = function(self)
   local sprite = self.sprites[self.anims[self.anim].frames[self.f+1]] -- to 1-based
   palt(3,true)
   palt(0,false)
   spr(sprite,self.x,self.y)
   pal()
  end
 }
 
 return entity
end

function create_dude(base_spr,_x,_y,_anim)
 local entity = {
  -- left, middle, right, idle 2(crouch)
  sprites={base_spr,base_spr+1,base_spr+2,base_spr+1+32},
  anims={
   -- dir: 1=loop,2=once
   idle={dir=1,frames=unpack({15,2,15,4})},
   walk={dir=1,frames=unpack({11,1,8,2,11,3,8,2})},
   run1={dir=1,frames=unpack({ 9,1,6,2, 9,3,6,2})},
   run2={dir=1,frames=unpack({ 7,1,5,2, 7,3,5,2})},
   run3={dir=1,frames=unpack({ 5,1,4,2, 5,3,4,2})},
   death={dir=2,frames=unpack({10,1,8,2,10,3,8,2})}
  },
  f=0, -- current anim frame index. 0-based.
  anim=_anim or "idle",
  x=_x or 64,
  y=_y or 64,
  
  play_anim = function(self,a)
   self.anim = a
   self.f = 0
  end,
  
  update = function(self)
   local a = self.anims[self.anim]
   local nb_frames = #a.frames
   self.f = 
    (a.dir == 1) 
    and ( self.f + 1 ) % nb_frames 
    or min(nb_frames-1,self.f+1)
  end,
  
  draw = function(self)
   local sprite = self.sprites[self.anims[self.anim].frames[self.f+1]] -- to 1-based
   if sprite ~= nil then
    palt(3,true)
    palt(0,false)
    spr(sprite,self.x,self.y)
    spr(sprite+16,self.x,self.y+8)
   end
  end
 }
 
 return entity
end

-->8
--------------
-- entry points
--------------

function _init()
 -- 64,67,70,73,...,81
 dudes = {
  create_dude(64,8,8,"idle"),create_dude(64,24,8,"walk"),create_dude(64,40,8,"run1"),create_dude(64,56,8,"run2"),create_dude(64,72,8,"run3"),
  create_dude(67,8,24,"idle"),create_dude(67,24,24,"walk"),create_dude(67,40,24,"run1"),create_dude(67,56,24,"run2"),create_dude(67,72,24,"run3"),
  create_dude(70,8,40,"idle"),create_dude(70,24,40,"walk"),create_dude(70,40,40,"run1"),create_dude(70,56,40,"run2"),create_dude(70,72,40,"run3"),
  create_dude(73,8,56,"idle"),create_dude(73,24,56,"walk"),create_dude(73,40,56,"run1"),create_dude(73,56,56,"run2"),create_dude(73,72,56,"run3"),
  --create_dude(108,8,72,"death"),
 }
 bombs = { 
  create_bomb(0,24,80),
  create_bomb(5,32,80),
  create_bomb(10,40,80),
  create_bomb(15,48,80),
  create_bomb(20,56,80)
 }
end

curr_anim_idx = 0
function _update60()
 local changed_anim = false
 local anim_names = {"idle","walk","run1","run2","run3","death"}
 if btnp(0) then 
  curr_anim_idx = ( curr_anim_idx - 1 ) % #anim_names
  changed_anim = true
 end
 if btnp(1) then 
  curr_anim_idx = ( curr_anim_idx + 1 ) % #anim_names
  changed_anim = true
 end
 for dude in all(dudes) do 
  --if changed_anim then
   --dude:play_anim(anim_names[curr_anim_idx+1])
  --end
  dude:update() 
 end
 for bomb in all(bombs) do
  bomb:update()
 end
end

function _draw()
 cls(15)
 map(0,0,0,0,16,16)
 for dude in all(dudes) do
  dude:draw()
 end
 for bomb in all(bombs) do
  bomb:draw()
 end
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
00000000000000000000000000000000000000000000000000000000333333333333333333000ff333000f433333f43333333333000000000000000000000000
0000000000000000000000000000000000000000000000000000000033333333333333333000f4033000f4033300f43333333f43000000000000000000000000
0000000000000000000000000000000000000000000000000000000033333333333333330700010037001103307001033300f433000000000000000000000000
0000000000000000000000000000000000000000000000000000000033333f433000ff0300000000300000033000000330700103000000000000000000000000
0000000000000000000000000000000000000000000000000000000033300433007004f000000010300000133000010330000003000000000000000000000000
00000000000000000000000000000000000000000000000000000000330700330000001000000110300001133300103330000103000000000000000000000000
000000000000000000000000000000000000000000000000000000003300103300000100300011033d0011d33dd55dd333001033000000000000000000000000
0000000000000000000000000000000000000000000000000000000033d00d33d000100d3d0000d333dddd3333dddd333dd55dd3000000000000000000000000
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
__map__
2a2a2a2a2a2a2a2a2a2a2a282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2829282928292829282a282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2d292d292d292d292d2a282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2d292d292d292d292d2a282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2d292d292d292d292d2a282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2d292d292d292d292d2a282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2d292d292d292d292d2a282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2d292d292d292d292d2a282800300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2d292d292d292d292d2a282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a282828282c282c28282a282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2c282c282c28282c282a282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a28282c2828282828282a2c2800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2828282828282c28282a282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2a2a2a2a2a2a2a2a2a2a282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
