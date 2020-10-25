# -*- coding: utf-8 -*-
"""
Created on Mon Aug 19 19:10:24 2019

@author: palazzol
"""

fin = open('ithaca_audio_1010_percom_dump_2x.bin','rb')
fout = open('ithaca_audio_1010_percom_dump.bin','wb')
barray = fin.read(0x400)
fout.write(barray)
fin.close()
fout.close()

fin = open('ithaca_audio_1010_percom_dump.bin','rb')
fout = open('ithaca_audio_1010_percom.bin','wb')
barray = fin.read(0x400)
for i in range(0,0x400):
	if (i == 0x0007) or (i == 0x0102):
		fout.write(b'\xcf')
	else:
		fout.write(bytes([barray[i]]))
fin.close()
fout.close()

        