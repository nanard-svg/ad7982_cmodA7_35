import serial
import binascii

import math
import matplotlib.pyplot as plt
import numpy as np


decimal_list=[]

ser = serial.Serial (port="COM10", baudrate=115200,
                      bytesize=serial.EIGHTBITS, parity=serial.PARITY_ODD,
                      stopbits=serial.STOPBITS_ONE,
                      timeout=None,
                      xonxoff=False,
                      rtscts=False,
                      write_timeout=None,
                      dsrdtr=False,
                      inter_byte_timeout=None)



ser.write(b'S')

for y in range(100):
    for i in range(100):
        x = ser.read(1)
        hexadecimal = binascii.hexlify(x)
        decimal = int(hexadecimal, 16)
        decimal_list.append(decimal)

print(decimal_list)
plt.plot(decimal_list)
plt.show()

ser.close()