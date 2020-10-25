# -*- coding: utf-8 -*-
"""
Created on Wed Sep  4 15:03:01 2019

@author: palazzol
"""

from PIL import Image

def drawImage(img, chars):
    numchars = int(img.size[0]/8 * img.size[1]/20) 
    pixels = img.load()
    for i in range(0,numchars):
        for j in range(0,10):
            c = chars[i*16+j]
            for bit in range(0,8):
                if (c>>bit)&0x01 == 1:
                    pixels[(i%32)*8+7-bit,int(i/32)*10*2+j*2] = (0, 255, 0)
                    pixels[(i%32)*8+7-bit,int(i/32)*10*2+j*2+1] = (0, 255, 0)


img = Image.new('RGB', (32*8, 10*8), color = 'black')
fin = open('zrt80chr.obj','rb')
orig = fin.read(128*16)
fin.close()
drawImage(img, orig)
img.save('orig.png')

fin = open('901447-10m.bin','rb')
newstuff = fin.read(256*8)

fout = open('zrt80dbl.bin','wb')
fout.write(orig)

for i in range(0,128):
    if i < 32:  # reuse 0-31 ASCII control codes for now
        fout.write(orig[i*16:i*16+16])
    elif i < 64:    # Punctuation and numbers from new rom
        j = 1*8*32+(i-32)*8
        fout.write(newstuff[j:j+8])
        fout.write(b'\x00\x00\x00\x00\x00\x00\x00\x00')
    elif i < 94:
        j = 0*8*32+(i-64)*8 # Upper case letters but re-use ^ and _
        fout.write(newstuff[j:j+8])
        fout.write(b'\x00\x00\x00\x00\x00\x00\x00\x00')
    elif (i > 96) and (i < 123):
        j = 4*8*32+(i-96)*8 # lower case letters but reuse ` { | } ~
        fout.write(newstuff[j:j+8])
        fout.write(b'\x00\x00\x00\x00\x00\x00\x00\x00')
    elif (i == 127): # Basement Designs logo - nerd glasses
        fout.write(b'\x6c\x82\x82\x82\xee\xba\xee\x00\x00\x00\x00\x00\x00\x00\x00\x00')
    else:
        fout.write(orig[i*16:i*16+16])

fin.close()
fout.close()


img = Image.new('RGB', (32*8, 10*8*2), color = 'black')
fin = open('zrt80dbl.bin','rb')
great = fin.read(2*128*16)
fin.close()
drawImage(img, great)
img.save('merged.png')

# now, swap the fonts
fin = open('zrt80dbl.bin','rb')
fout = open('zrt80swp.bin','wb')
a = fin.read(2048);
b = fin.read(2048);
fout.write(b);
fout.write(a);
fin.close();
fout.close();

img = Image.new('RGB', (32*8, 10*8*2), color = 'black')
fin = open('zrt80swp.bin','rb')
great = fin.read(2*128*16)
fin.close()
drawImage(img, great)
img.save('swapped.png')



