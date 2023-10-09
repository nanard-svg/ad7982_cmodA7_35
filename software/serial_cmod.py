import serial
import binascii

import math
import matplotlib.pyplot as plt
import numpy as np

toggle = 0
decimal_list=[]
res_twos_complement_list=[]
msb_list=[]
lsb_list=[]
counter=0

def twos_complement(val, nbits):
    """Compute the 2's complement of int value val"""
    if val < 0:
        val = (1 << nbits) + val
    else:
        if (val & (1 << (nbits - 1))) != 0:
            # If sign bit is set.
            # compute negative value.
            val = val - (1 << nbits)
    return val

ser = serial.Serial (port="COM10", baudrate=115200,
                      bytesize=serial.EIGHTBITS, parity=serial.PARITY_ODD,
                      stopbits=serial.STOPBITS_ONE,
                      timeout=None,
                      xonxoff=False,
                      rtscts=False,
                      write_timeout=None,
                      dsrdtr=False,
                      inter_byte_timeout=None)


ser.write(b'0')
ser.write(b'S') #start data counter inside fpga

for y in range(131000):
        x = ser.read(1)
        hexadecimal = binascii.hexlify(x)
        #print(type(hexadecimal))
        decimal = int(hexadecimal, 16)
        #print(type(decimal))
        if toggle == 0 :
            lsb = decimal
            toggle = 1
        else:
            msb = decimal
            #data = bin(bin(msb) | bin(lsb))
            toggle = 0
            res_decimal = msb*((2**8))+lsb
            #print("res_decimal:{}".format(res_decimal))
            #res_bin = ''.join(format(i, '08b') for i in bytearray(str(res_decimal), encoding ='utf-8'))
            res_twos_complement = twos_complement(res_decimal, 16)
            if y == 1 or y == 130999 :
                print("res_twos_complement:{}".format(res_twos_complement))
            counter = counter+1
            #print("counter:{},res:{}".format(counter,res_decimal))
            #print(res_bin)
            decimal_list.append(res_twos_complement)
            msb_list.append(msb)
            lsb_list.append(lsb)

print("Mean of res_twos_complement is ", np.mean(decimal_list))
plt.plot(decimal_list)
plt.show()

ser.write(b'0')

ser.close()