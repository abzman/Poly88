Monitor Rom from Ithaca Audio 1010 board
(2708, labelled "PERCOM", source listing is in the Percom CI-812 manual)

This dump matches the manual listing, except for 2 bytes:
it has the Stack pointer changed from CFFF to 00FF
These changes are actually shown in pencil in the manual

file descriptions:

check_ithaca.py                         Script to convert original double size dump to proper size, and
                                        convert SP changed version to match original printed listing
					
ithaca_audio_1010_percom_dump_2x.bin    Dump as 2716 (double size) using adapter
ithaca_audio_1010_percom_dump.bin       Original Rom image, Code at C000, SP at 00FF
ithaca_audio_1010_percom_dump.lst       DASMX disassembly

ithaca_audio_1010_percom.bin            File as printed in the manual
ithaca_audio_1010_percom.asm            Code at C000, SP at CFFF
ithaca_audio_1010_percom.lst

ithaca_audio_1010_percom_F000.bin       File as relocated for Polly to maximize low memory
ithaca_audio_1010_percom_F000.asm       Code at F000, SP at FFFF
ithaca_audio_1010_percom_F000.lst
