# -*- coding: utf-8 -*-
"""
Created on Sun Sep 15 12:15:58 2019

@author: palazzol
"""

import serial
import sys

if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <filename.bas>")
    sys.exit(-1)
    
ser = serial.Serial('COM6', 9600, timeout=1)

with open(sys.argv[1],'r') as f:
    for line in f.readlines():
        for c in line:
            print(c, end='')
            ser.write(c.encode('UTF-8'))
            ser.read(1)
        ser.write(b'\r')
        ser.read(1)


