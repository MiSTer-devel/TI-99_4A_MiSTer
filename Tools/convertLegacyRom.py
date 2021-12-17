#!/usr/bin/env python3
import os
import argparse
import math
from zipfile import ZipFile

M99Ver=0

def cartType(x):
    match x:
        case 'A':
            return 0
        case '0':
            return 0
        case 'M':
            return 1
        case '7':
            return 2
        case '8':
            return 3
        case '9':
            return 4
        case 'MM':
            return 5
        case _:
            return 0

if __name__ == "__main__":
    vParser = argparse.ArgumentParser()
    vParser.add_argument('InputFile', help='The path to the legacy rom (288K rom file).',type=str)
    vParser.add_argument('--OutputFile', help="The memory image to be created. Default is use InputFile with M99 extension.", type=str, default=None)
    vParser.add_argument("-P","--paging", help='Rom Paging type. 0=Normal, 7=Paged7, 8=378, 9=379, M=MBX, MM=MiniMem', type=str, default='0')
    lsArguments=vParser.parse_args()

    with open(lsArguments.InputFile,'rb') as fInputFile:
        fullRom=fInputFile.read()
    romBuffer=bytearray()
    gromBuffer=bytearray()
    romBuffer.extend(fullRom[0:65536])
    gromBuffer.extend(fullRom[90112:131072])
    for ptr in range(len(romBuffer)-1,0, -1):
        if romBuffer[ptr] != 0:
            break;
    romSize = math.ceil(ptr/8192)
    for ptr in range(len(gromBuffer)-1,0, -1):
        if gromBuffer[ptr] != 0:
            break;
    gromSize = math.ceil(ptr/8192)
    if lsArguments.OutputFile is None:
        lsArguments.OutputFile=lsArguments.InputFile[0:-3]+"M99"
    with open(lsArguments.OutputFile,'wb') as fOutputFile:
        fOutputFile.write("M99".encode('utf-8'))
        fOutputFile.write(M99Ver.to_bytes(1,'little'))
        fOutputFile.write(cartType(lsArguments.paging).to_bytes(1,'little'))
        fOutputFile.write(math.ceil(romSize).to_bytes(2,'big'))
        fOutputFile.write(math.ceil(gromSize).to_bytes(2,'big'))
        vReservedSpace=bytes([0]*89)
        fOutputFile.write(vReservedSpace)
        vHeaderTail=bytes([255]*2)
        fOutputFile.write(vHeaderTail)
        fOutputFile.write(romBuffer[0:romSize*8192])
        fOutputFile.write(gromBuffer[0:gromSize*8192])
        

