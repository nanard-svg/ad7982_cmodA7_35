import serial
import binascii

import math
import matplotlib.pyplot as plt
import numpy as np

decimal_theo=1
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



ser.write(b'S') #start data counter inside fpga

for y in range(1000):
    for i in range(100):
        x = ser.read(1)
        hexadecimal = binascii.hexlify(x)
        decimal = int(hexadecimal, 16)
        if decimal_theo != decimal: # control data from fpga
            print('error')
            print(decimal)
            print(decimal_theo)

        if decimal_theo == 255:
            decimal_theo = 0
        else:
            decimal_theo += 1

        decimal_list.append(decimal)



#print(decimal_list)
plt.plot(decimal_list)
plt.show()

ser.close()