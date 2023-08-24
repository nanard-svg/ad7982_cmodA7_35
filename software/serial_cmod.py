import serial
import binascii

import math
import matplotlib.pyplot as plt
import numpy as np

toggel = 0
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

for y in range(655):
    for i in range(100):
        x = ser.read(1)
        hexadecimal = binascii.hexlify(x)
        decimal = int(hexadecimal, 16)
        if toggel == 0 :
            lsb = decimal
            print(bin(lsb))
            toggel = 1
        else:
            msb = decimal
            print(bin(msb))

            #data = bin(bin(msb) | bin(lsb))

            print("data:{}".format(msb))
            toggel = 0

            decimal_list.append(msb)



print(decimal_list)
plt.plot(decimal_list)
plt.show()

ser.close()