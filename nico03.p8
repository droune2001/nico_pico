pico-8 cartridge // http://www.pico-8.com
version 15
__lua__
t=0
::_::
cls()
t+=.006
f=32*(1+.6*sin(t/4))
s=abs(sin(t))
q=abs(cos(t))
m=f+f*s+8*s*s
a=m*max(s,q)
d=q*a
e=s*a
x=64-8*m
for i=0,16 do
 x+=m 
 y=64-8*m
 for j=0,16 do
  y+=m
  line(x-e,y+d,x+e,y-d,7)
  line(x-d,y-e,x+d,y+e,7)
 end
end
flip()
goto _
