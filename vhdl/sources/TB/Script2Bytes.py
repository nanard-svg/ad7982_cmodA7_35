########################################################
# Commands Generator Script
########################################################

import os
import sys
import getopt
import csv

##########################################################################
# Available Commands in Source_File, arg = PayLoad (6 bytes)
##########################################################################
C_SYNC_HEAD_0 = "52"
C_SYNC_HEAD_1 = "47"
C_SYNC_HEAD_2 = "52"
C_SYNC_HEAD_3 = "7B"
C_DORN_APID = "531"  # 11 bit

# Wait_us(int:microsecond"s)
# Send_START_SC_ACQ()
# Send_RESET_SC_ACQ()
# Send_POWER_OFF()
# Send_HK_REQUEST()
# Send_SC_REQUEST()
# Send_GET_STATUS()
# Send_SET_TIME()

# Send_CHANGE_PARAM()
# Send_READ_PARAM()
# Send_LOAD_CONFIG()
# Send_SAVE_CONFIG()

# Send_FLASH_ERASE()
# Send_FLASH_DUMP()

C_START_SC_ACQ = "AC"
C_RESET_SC_ACQ = "B0"
C_POWER_OFF = "18"
C_HK_REQUEST = "C1"
C_SC_REQUEST = "D6"
C_GET_STATUS = "57"
C_SET_TIME = "A7"

C_CHANGE_PARAM = "B4"
C_READ_PARAM = "D1"
C_LOAD_CONFIG = "1C"
C_SAVE_CONFIG = "5C"

C_FLASH_DUMP = "64"
C_FLASH_ERASE = "C3"

##################################
# BASIC HEXADECIMAL FUNCTIONS
##################################


def is_hex(s):
    try:
        int(s, 16)
        return True
    except ValueError:
        return False


def dec_to_hex(f_decValue, f_digitSize):
    hexString = hex(f_decValue)[-f_digitSize:].zfill(f_digitSize).upper()  # remove x, keep last f_digitSize
    return hexString


def hex_to_bin(hex_data, width_bin):
    return str(bin(int(hex_data.replace("x", ""), 16))[2:].zfill(width_bin))  # remove x and 0b


def bin_to_hex(bin_data: str) -> str:
    return hex(int(bin_data, 2))[2:].upper().zfill(12)  # remove 0x, format on 12-hex digits


##################################
# PARAMETER GENERATOR FUNCTION
##################################


def Parameters_Generator(File, Time, Value_Array, PCKT_ID):
    Error = 0
    DumpSettings = []
    PayLoad = []
    Parameters = []
    Command_Name = "NONE"

    print("Wait for ", Time, "us")

    ##################################
    # PAYLOAD GENERATION
    ##################################

    argument = (Value_Array[Value_Array.index("(") + 1:Value_Array.index(")")]).split(",")

    if PCKT_ID == C_CHANGE_PARAM or PCKT_ID == C_READ_PARAM:
        if len(argument) != 2:
            Error = 1
            print("\nError: Nb of arguments in", Value_Array, len(argument))
        else:
            for i in range(0, len(argument)):
                if argument[i][0] == "x":
                    if is_hex(argument[i][1:]):
                        PayLoad.append(argument[i][1:3])  # Byte 5 and 6
                        PayLoad.append(argument[i][3:5])  # Byte 7 and 8
                    else:
                        print("Argument does not start with \"x\"")
                        Error = 1
                else:
                    PayLoad.append(str(argument[0])[2:4])
                    PayLoad.append(str(argument[0])[4:6])

            PayLoad.append("00")  # Byte 9
            PayLoad.append("00")  # Byte 10

    ##################################
    elif PCKT_ID == C_FLASH_DUMP:
        if len(argument) != 3:
            Error = 1
            print("\nError: Nb of arguments in", Value_Array, len(argument))
        else:
            DumpSettings_size = [8, 24, 16]
            for i in range(0, len(argument)):
                if argument[i][0] == "x" and is_hex(argument[i][1:]):
                    DumpSettings.append(hex_to_bin(argument[i], DumpSettings_size[i]))
                else:
                    DumpSettings.append('')
                    Error = 1

            # print("DumpSettings =", DumpSettings)
            Concatenated_PayLoad = bin_to_hex(''.join(DumpSettings))
            # print("Concatenated =", Concatenated_PayLoad)
            for i in range(6):  # Byte 5, 6, 7, 8, 9, and 10
                PayLoad.append(Concatenated_PayLoad[2 * i:2 * i + 2])  # add byte to PayLoad

    ##################################
    elif PCKT_ID == C_FLASH_ERASE:
        if len(argument) != 4:
            Error = 1
            print("\nError: Nb of arguments in", Value_Array, len(argument))
        else:
            DumpSettings_size = [4, 12, 4, 12]
            for i in range(0, len(argument)):
                if argument[i][0] == "x" and is_hex(argument[i][1:]):
                    DumpSettings.append(hex_to_bin(argument[i], DumpSettings_size[i]))
                else:
                    DumpSettings.append('')
                    Error = 1

            DumpSettings.append('00000000')  # Byte 9
            DumpSettings.append('00000000')  # Byte 10

            # print("DumpSettings =", DumpSettings)
            Concatenated_PayLoad = bin_to_hex(''.join(DumpSettings))
            # print("Concatenated =", Concatenated_PayLoad)
            for i in range(6):  # Byte 5, 6, 7, 8, 9, and 10
                PayLoad.append(Concatenated_PayLoad[2 * i:2 * i + 2])  # add byte to PayLoad

    ##################################
    else:  # any other commands without arguments
        if len(argument) != 6:
            Error = 1
            print("\nError: Nb of arguments in", Value_Array, len(argument))
        else:
            for i in range(0, len(argument)):
                if argument[i][0] == "x":
                    if is_hex(argument[i][1:]):
                        PayLoad.append(argument[i][1:])
                    else:
                        Error = 1
                else:
                    PayLoad.append('%02X' % int(argument[i], 10))

    ##################################
    # Command GENERATION
    ##################################
    if Error == 0:
        # BYTE 0
        Parameters.append(C_SYNC_HEAD_0)
        # BYTE 1
        Parameters.append(C_SYNC_HEAD_1)
        # BYTE 2
        Parameters.append(C_SYNC_HEAD_2)
        # BYTE 3
        Parameters.append(C_SYNC_HEAD_3)
        # BYTE 4 = TC_ID
        Parameters.append(PCKT_ID)
        # BYTE 5 to BYTE N-1
        Parameters.extend(PayLoad)
        # BYTE N
        checksum = 0

        for i in range(4, len(Parameters)):  # Exclude first 4 SYNC_HEAD bytes
            checksum += int(Parameters[i], 16)  # CRC Sum
        Parameters.append(dec_to_hex(checksum, 2))  # 8 bits

        File.writelines("%d %s\n" % (Time, Parameters[0]))

        for i in range(1, len(Parameters)):
            File.writelines("0 %s\n" % (Parameters[i]))

        if Parameters[4] == C_START_SC_ACQ:
            Command_Name = "Send_START_SC_ACQ"
        elif Parameters[4] == C_RESET_SC_ACQ:
            Command_Name = "Send_RESET_SC_ACQ"
        elif Parameters[4] == C_POWER_OFF:
            Command_Name = "Send_POWER_OFF"
        elif Parameters[4] == C_HK_REQUEST:
            Command_Name = "Send_HK_REQUEST"
        elif Parameters[4] == C_SC_REQUEST:
            Command_Name = "Send_SC_REQUEST"
        elif Parameters[4] == C_GET_STATUS:
            Command_Name = "Send_GET_STATUS"
        elif Parameters[4] == C_SET_TIME:
            Command_Name = "Send_SET_TIME"

        elif Parameters[4] == C_CHANGE_PARAM:
            Command_Name = "Send_CHANGE_PARAM"
        elif Parameters[4] == C_READ_PARAM:
            Command_Name = "Send_READ_PARAM"
        elif Parameters[4] == C_LOAD_CONFIG:
            Command_Name = "Send_LOAD_CONFIG"
        elif Parameters[4] == C_SAVE_CONFIG:
            Command_Name = "Send_SAVE_CONFIG"

        elif Parameters[4] == C_FLASH_ERASE:
            Command_Name = "Send_FLASH_ERASE"
        elif Parameters[4] == C_FLASH_DUMP:
            Command_Name = "Send_FLASH_DUMP"

        else:
            print("Unknown command name: " + Parameters[4])

        print("%s: " % Command_Name, Parameters)
    else:
        print("ERROR in %s: " % Value_Array)
    return Error


##################################
# MAIN PROGRAM
##################################
def main(argv):
    infile = 'Test_Flash.scr'  # adapt file name

    try:
        opts, args = getopt.getopt(argv, "hi:")
    except getopt.GetoptError:
        print("Usage : Script2Bytes.py -i <script.scr>")
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print("Usage : Script2Bytes.py -i <script.scr>")
            sys.exit()
        elif opt in "-i":
            infile = arg

    if infile == '':
        print("Usage : Script2Bytes.py -i <script.scr>")
        sys.exit(3)

    outfile = os.path.splitext(infile)[0] + ".byte"

    ########################################################
    # Files PATHS
    ########################################################
    Source_File = open(infile, 'r')
    Target_File = open(outfile, 'w')
    ########################################################

    Time = 0
    errorCmd = 0

    print("#############################")
    print("# Commands Generator Script")
    print("#############################\n")

    for line in Source_File.readlines():
        if not line.startswith("#") and not line.isspace():
            Value_Array = line.replace(" ", "")  # remove space after commas in command script

            if "Wait_us" in Value_Array:
                Time = int(Value_Array[Value_Array.index("(") + 1:Value_Array.index(")")])

            ##################################
            # START_SC_ACQ
            ##################################
            elif "START_SC_ACQ" in Value_Array:
                PCKT_ID = C_START_SC_ACQ
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # RESET_SC_ACQ
            ##################################
            elif "RESET_SC_ACQ" in Value_Array:
                PCKT_ID = C_RESET_SC_ACQ
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # POWER OFF
            ##################################
            elif "POWER_OFF" in Value_Array:
                PCKT_ID = C_POWER_OFF
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # Send_HK_REQUEST
            ##################################
            elif "Send_HK_REQUEST" in Value_Array:
                PCKT_ID = C_HK_REQUEST
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # Send_SC_REQUEST
            ##################################
            elif "Send_SC_REQUEST" in Value_Array:
                PCKT_ID = C_SC_REQUEST
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # Send_GET_STATUS
            ##################################
            elif "Send_GET_STATUS" in Value_Array:
                PCKT_ID = C_GET_STATUS
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # Send_SET_TIME
            ##################################
            elif "Send_SET_TIME" in Value_Array:
                PCKT_ID = C_SET_TIME
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # CHANGE_PARAM
            ##################################
            elif "CHANGE_PARAM" in Value_Array:
                PCKT_ID = C_CHANGE_PARAM
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # READ_PARAM
            ##################################
            elif "READ_PARAM" in Value_Array:
                PCKT_ID = C_READ_PARAM
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # LOAD_CONFIG
            ##################################
            elif "LOAD_CONFIG" in Value_Array:
                PCKT_ID = C_LOAD_CONFIG
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # SAVE_CONFIG
            ##################################
            elif "SAVE_CONFIG" in Value_Array:
                PCKT_ID = C_SAVE_CONFIG
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # FLASH_ERASE
            ##################################
            elif "FLASH_ERASE" in Value_Array:
                PCKT_ID = C_FLASH_ERASE
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # FLASH_DUMP
            ##################################
            elif "FLASH_DUMP" in Value_Array:
                PCKT_ID = C_FLASH_DUMP
                errorCmd += Parameters_Generator(Target_File, Time, Value_Array, PCKT_ID)

            ##################################
            # UNKNOWN
            ##################################
            else:
                print("Unknown command name: " + Value_Array)
                errorCmd += 1

    Source_File.close()
    Target_File.close()
    print("\n## Errors detected in command file:", errorCmd)
    print("## Script source file:", infile)
    print("## Destination file:", outfile)

    print("\n#############################")
    print("# End of Script")
    print("#############################\n")

##############################################


if __name__ == "__main__":
    main(sys.argv[1:])

# Open workbook
En_Banana = False
fileName = "banana_7_7_7_2_2_2_Phi_19.txt"
if os.path.exists(fileName) and En_Banana:
    with open(fileName, 'r') as csvFile:
        text = csv.reader(csvFile)
        banana = []
        for row in text:
            banana.append([element.strip() for element in row])
        csvFile.close()
        print("Number of lines read =", len(banana))

    # Memory initialization array
    Mem_Context = []
    # Initial_value = 0  # Decimal number
    for i in range(0, 2048):
        # print(banana[i][0][:-2])
        decValue = int(banana[i][0][:-2])  # Use first row and remove ".0" in numbers
        binStr = bin(decValue)
        # print(binStr)
        Mem_Context.append(binStr[2:].zfill(24))

    print("    constant C_RAM_Banana_Coeff_2kx24 : string := (")
    for i in range(0, 2048, 4):  # 4 data written per line
        if i < 2044:
            print("    \"" + str(Mem_Context[i]) + "," + str(Mem_Context[i + 1]) + "," + str(Mem_Context[i + 2]) + "," + str(Mem_Context[i + 3]) + ",\" &")
        else:  # Last line, i = 2044
            print("    \"" + str(Mem_Context[i]) + "," + str(Mem_Context[i + 1]) + "," + str(Mem_Context[i + 2]) + "," + str(Mem_Context[i + 3]) + "\");")
    print("Length =", len(Mem_Context))
else:
    print("No file found or Enable = False")


# Open workbook
En_Base_pulse = False
fileName = "Base_Pulse_inigo_50.csv"
if os.path.exists(fileName) and En_Base_pulse:
    with open(fileName, 'r') as csvFile:
        text = csv.reader(csvFile)
        pulse = []
        for row in text:
            pulse.append([element.strip() for element in row])
        csvFile.close()
        print("Number of lines read =", len(pulse))

    # Memory initialization array
    Mem_Context = []
    for i in range(2048):
        Mem_Context.append(str(bin(int(pulse[i][0]))[2:].zfill(24)))  # RAM_Init_2kx24

    print("    constant C_RAM_Input_Pulse_2kx24 : string := (       -- Generated by Python script")
    for i in range(0, 2048, 4):  # 4 data written per line
        if i < 2044:
            print("    \"" + str(Mem_Context[i]) + "," + str(Mem_Context[i + 1]) + "," + str(Mem_Context[i + 2]) + "," + str(Mem_Context[i + 3]) + ",\" &")
        else:  # Last line, i = 2044
            print("    \"" + str(Mem_Context[i]) + "," + str(Mem_Context[i + 1]) + "," + str(Mem_Context[i + 2]) + "," + str(Mem_Context[i + 3]) + "\");")
    print("Length =", len(Mem_Context))
else:
    print("No file found or Enable = False")

# Memory initialization array
# Mem_Context = []
# for i in range(2048): # Counter
#     Mem_Context.append(str(bin(i)[2:].zfill(24)))  # RAM_Init_2kx24
#
# print("    constant C_RAM_Input_Pulse_2kx24 : string := (       -- Generated by Python script")
# for i in range(0, 2048, 4):  # 4 data written per line
#     if i < 2044:
#         print("    \"" + str(Mem_Context[i]) + "," + str(Mem_Context[i + 1]) + "," + str(Mem_Context[i + 2]) + "," + str(Mem_Context[i + 3]) + ",\" &")
#     else:  # Last line, i = 2044
#         print("    \"" + str(Mem_Context[i]) + "," + str(Mem_Context[i + 1]) + "," + str(Mem_Context[i + 2]) + "," + str(Mem_Context[i + 3]) + "\");")
# print("Length =", len(Mem_Context))

# CRC XOR check
# Start_Flag = "AAA000"
# Stop_Flag = "000555"
Timestamp = "8009C4"
Raw_Header = "400000"


def CRC_XOR_Calculator():
    f_CRC_XOR = int(Timestamp, 16)
    for i in range(20):
        f_CRC_XOR ^= int(Raw_Header, 16) + i
    return hex(f_CRC_XOR)[2:].upper()


CRC_XOR = CRC_XOR_Calculator()
print(CRC_XOR)
