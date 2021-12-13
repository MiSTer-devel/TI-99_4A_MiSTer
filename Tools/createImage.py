#!/usr/bin/env python3
# File: createImage.py
# Repository: pyTIrom
# Description: Create a TI-99 memory image from C, D, G and system roms.
# Author: GHPS
# License: GPL-3.0
# Modified by Flandango for new M99 rom format.

import argparse
import hashlib
import os.path
import math

M99Ver=0

def createRom(stOutputFile='',
              stCrom='', stDrom='', stGrom='', stRomPath='',
              blCheck=False, blVerbose=False, blUseInternalName=False, stPagingType='A'):

    bCromFile='';
    bDromFile='';
    bGromFile='';
    internalName='';
#    lsMemoryMap=[[None, None, None]]

    if stCrom:
        romFile=os.path.join(stRomPath,stCrom)
        CromSize=os.path.getsize(romFile)/8192
        CromType=os.path.splitext(romFile)[0][-1]
        if CromType.upper()=='C':
            CromType='0'
        with open(romFile,'rb') as fCurrentFile:
            bCromFile=fCurrentFile.read()
        if blUseInternalName & (len(bCromFile) > 20):
            try:
                if bCromFile[0]==170:
                    if bCromFile[7]!=0:
                        vNameLen = bCromFile[bCromFile[7]+4]
                        if vNameLen!=0:
                            internalName=bCromFile[bCromFile[7]+5:bCromFile[7]+5+vNameLen].decode('utf-8').split("  ")[0]
            except BaseException:
                if blVerbose: print(f'Couldn\'t retrieve Program Name from {romFile}')

    else:
        CromSize=0
        CromType='0'
    if stDrom:
        romFile=os.path.join(stRomPath,stDrom)
        DromSize=os.path.getsize(romFile)/8192
        with open(romFile,'rb') as fCurrentFile:
            bDromFile=fCurrentFile.read()
        if blUseInternalName & (len(internalName)==0) & (len(bDromFile) > 20):
            try:
                if bDromFile[0]==170:
                    if bDromFile[7]!=0:
                        vNameLen = bDromFile[bDromFile[7]+4]
                        if vNameLen!=0:
                            internalName=bDromFile[bDromFile[7]+5:bDromFile[7]+5+vNameLen].decode('utf-8').split("  ")[0]
            except BaseException:
                if blVerbose: print(f'Couldn\'t retrieve Program Name from {romFile}')

    else:
        DromSize=0
    if stGrom:
        romFile=os.path.join(stRomPath,stGrom)
        GromSize=os.path.getsize(romFile)/8192
        with open(romFile,'rb') as fCurrentFile:
            bGromFile=fCurrentFile.read()
        if blUseInternalName & (len(internalName)==0) & (len(bGromFile) > 20):
            try:
                if bGromFile[0]==170:
                    if bGromFile[7]!=0:
                        vNameLen = bGromFile[bGromFile[7]+4]
                        print(f'Name Len = {vNameLen}')
                        if vNameLen!=0:
                            internalName=bGromFile[bGromFile[7]+5:bGromFile[7]+5+vNameLen].decode('utf-8').split("  ")[0]
            except BaseException:
                if blVerbose: print(f'Couldn\'t retrieve Program Name from {romFile}')
    else:
        GromSize=0

    romSize = (CromSize+DromSize)
    if stPagingType!='A':
        CromType=stPagingType
    if blCheck: blVerbose=True

    if blUseInternalName & (len(internalName)!=0):
        stFileName=internalName.replace(' ','_')
        stFileName=stFileName.replace('"','')
        stFileName=stFileName.replace('*','-')
        stFileName=stFileName.replace('?','')
        stFileName=stFileName.replace('/','-')
        stFileName=stFileName.replace(':','-')
        stFileName=stFileName.replace('\x00','')
        stFileName=stFileName.split("__")[0]+".M99"
        stFileName=stFileName.replace('_.','.')

        outputPath=os.path.dirname(os.path.abspath(stOutputFile))
        stOutputFile=os.path.join(outputPath,stFileName)
        
    if blVerbose & blUseInternalName & len(internalName)!=0: print(f'Found program name [{internalName}].  Using {stOutputFile} as output filename.')
    if blVerbose: print('-- Copying input files --\n\n|--------------\n|Image Map\n|--------------')
    print(f'Filename= {stOutputFile}')
    with open(stOutputFile,'wb') as fOutputFile:
        fOutputFile.write("M99".encode('utf-8'))
        fOutputFile.write(M99Ver.to_bytes(1,'little'))
        fOutputFile.write(cartType(CromType).to_bytes(1,'little'))
        fOutputFile.write(math.ceil(romSize).to_bytes(2,'big'))
        fOutputFile.write(math.ceil(GromSize).to_bytes(2,'big'))
        vReservedSpace=bytes([0]*89)
        fOutputFile.write(vReservedSpace)
        vHeaderTail=bytes([255]*2)
        fOutputFile.write(vHeaderTail)
        
        
        if romSize!=0:
            iPaddingSize=math.ceil(romSize)*8192
            if len(bCromFile)!=0:
                if blCheck:
                    stChecksum=hashlib.md5(bCromFile).hexdigest()
                fOutputFile.write(bCromFile)
                if blVerbose: print('done',end='')
                if blCheck: print(f', MD5 Checksum: {stChecksum}', end=' ')
                if blVerbose: print(f' ({len(bCromFile)/1024}k occupied)', sep='')
                iPaddingSize-=len(bCromFile)
            if len(bDromFile)!=0:
                if blCheck:
                    stChecksum=hashlib.md5(bDromFile).hexdigest()
                fOutputFile.write(bDromFile)
                if blVerbose: print('done',end='')
                if blCheck: print(f', MD5 Checksum: {stChecksum}', end=' ')
                if blVerbose: print(f' ({len(bDromFile)/1024}k occupied)', sep='')
                iPaddingSize-=len(bDromFile)
               
            if iPaddingSize>0:
                if blVerbose: print(f'|  Applying {iPaddingSize} bytes of padding.')
                vPadding=bytes([0]*iPaddingSize)
                fOutputFile.write(vPadding)
                iPaddingSize=0
        if blVerbose: print('|--------------')
                
        if GromSize!=0:
            if len(bGromFile)!=0:
                if blCheck:
                    stChecksum=hashlib.md5(bGromFile).hexdigest()
                fOutputFile.write(bGromFile)
                if blVerbose: print('done',end='')
                if blCheck: print(f', MD5 Checksum: {stChecksum}', end=' ')
                if blVerbose: print(f' ({len(bGromFile)/1024}k occupied)', sep='')
        if blVerbose: print('|--------------')

    if blVerbose: print(f'\nTarget ROM {stOutputFile} created',end='')
    if blCheck:
        with open(stOutputFile,'rb') as fOutputFile:
            vSingleFile=fOutputFile.read()
            stChecksum=hashlib.md5(vSingleFile).hexdigest()
        print(f', MD5 Checksum: {stChecksum}')
    else:
        print('')
    return 0

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
    vParser.add_argument('OutputFile', help="The memory image to be created.", type=str)
    vParser.add_argument('--Crom', help="The C Rom file to use.", type=str)
    vParser.add_argument('--Drom', help="The D Rom file to use.", type=str)
    vParser.add_argument('--Grom', help="The G Rom file to use.", type=str)
    vParser.add_argument('--romPath', help="The path to the all roms - C, D, G and system roms (default .).", type=str, default='')
    vParser.add_argument("-P","--paging", help='Rom Paging type. 0=Normal, 7=Paged7, 8=378, 9=379, M=MBX, MM=MiniMem', type=str, default='A')
    vParser.add_argument("-c","--check", help='Checksum files - generate MD5 sums for input and output files (implies --verbose).',action="store_true")
    vParser.add_argument("-i","--internalname", help='Try to use internal program name for output filename.', action="store_true")
    vParser.add_argument("-v","--verbose", help='Display respective actions and results.', action="store_true")
    lsArguments=vParser.parse_args()

    createRom(stOutputFile=lsArguments.OutputFile,
              stCrom=lsArguments.Crom, stDrom=lsArguments.Drom, stGrom=lsArguments.Grom, stRomPath=lsArguments.romPath, 
              blCheck=lsArguments.check, blVerbose=lsArguments.verbose, stPagingType=lsArguments.paging, blUseInternalName=lsArguments.internalname)
