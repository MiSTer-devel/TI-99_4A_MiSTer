#!/usr/bin/env python3
# File: convertArchive.py
# Repository: pyTIrom
# Description: Create TI-99 memory images from a directory containing C, D and G roms.
# Author: GHPS
# License: GPL-3.0
# Modified by Flandango for new M99 rom format.

import argparse
import os
import sys
import hashlib
import pathlib
import datetime as dt
from createImage import createRom

dcNamingScheme={'None':['*.[CDG]', -1, '.', ''],                 # e.g. File Name: Name xxx.c  -> Cartridge: Name xxx'
                'Standard':['*.[CDG]', -1, '(', ['[a]','[o]']],  # e.g. Standard Archive: File Name: Name (Year) xxx.c -> Cartridge: Name'
                'Timrad':['*.Bin', -5, '.', ''],                 # e.g. Timrad Archive: File Name: NameC.bin -> Cartridge: Name'
                'Tosec':['*.bin', -6, '(', '']}                  # e.g. Tosec Archive: File Name: Name (Year) (xxxc).bin -> Cartridge: Name'
# Description: Archive Name: [Valid Extensions, Position File Type, End of Cartidge Name, Ignore Types]

def extractCartridgeName(stFileName, stNamingScheme):
    iEndCartridge=stFileName.find(dcNamingScheme[stNamingScheme][2])
    if iEndCartridge!=-1:
        stCartridgeName=stFileName[0:iEndCartridge-1]
    else:
        print('** Warning: File mismatches naming scheme - continuing with complete file name **')
        stCartridgeName=stFileName[0:-2]
    return stCartridgeName


if __name__ == "__main__":
    vParser = argparse.ArgumentParser()
    vParser.add_argument('--romPath', help='The path to the roms - C, D, G (default .).',type=str, default='')
    vParser.add_argument('--imagePath', help='The directory where the Rom files are created.',type=str,default='')
    vParser.add_argument('-l','--listing', help='Name of a listing file with all cartidges processed (.txt and .csv format supported).',type=str, default='')
    vParser.add_argument('-n','--naming', help='Naming scheme of the archive (None, Standard, Timrad, Tosec are supported)',type=str, default='Standard')
    vParser.add_argument('--simulate', help='Simulation run without creation of files.',action="store_true")
    vParser.add_argument('-c','--check', help='Checksum files - generate MD5 sums for input and output files (implies --verbose)',action="store_true")
    vParser.add_argument("-P","--paging", help='Rom Paging type. 0=Normal, 7=Paged7, 8=378, 9=379, M=MBX, MM=MiniMem', type=str, default='A')
    vParser.add_argument("-i","--internalname", help='Try to use internal program name for output filename.', action="store_true")
    vParser.add_argument("-t","--TreatUnknownAsCrom", help='If a rom can\'t be identified, treat it as a C-Rom.', action="store_true")
    
    vParser.add_argument('-v','--verbose', help='Display respective actions and results.',action="store_true")
    lsArguments=vParser.parse_args()

    if lsArguments.simulate: print('** SIMULATION **')

    stFileNameListing=lsArguments.listing
    stNamingScheme=lsArguments.naming

    if lsArguments.imagePath=='':
        lsArguments.imagePath=lsArguments.romPath
        print(lsArguments.imagePath)

    dtStartTime=dt.datetime.now()
    lsFiles=sorted(pathlib.Path(lsArguments.romPath).glob(dcNamingScheme[stNamingScheme][0]))

    dcFiles={}
    for pFileName in lsFiles:
        if dcNamingScheme[stNamingScheme][3]=='' or not any((stNamePart in pFileName.name for stNamePart in dcNamingScheme[stNamingScheme][3])):  # Select main version, not [o]ther or [a]lternative
            stCartridgeName=extractCartridgeName(pFileName.name, stNamingScheme)
            if lsArguments.verbose: print(f'Adding {pFileName.name} to {stCartridgeName}')
            stFileType=pFileName.name[dcNamingScheme[stNamingScheme][1]].upper()
            if stFileType in 'CDG':
                if stCartridgeName in dcFiles:
                    dcFiles.update({stCartridgeName:dcFiles[stCartridgeName]+[(str(pFileName), stFileType)]})
                else:
                    dcFiles.update({stCartridgeName:[(str(pFileName), stFileType)]})
            else:
                if lsArguments.TreatUnknownAsCrom:
                    stCartridgeName=pFileName.name[0:-4]
                    if stCartridgeName in dcFiles:
                        dcFiles.update({stCartridgeName:dcFiles[stCartridgeName]+[(str(pFileName), 'C')]})
                    else:
                        dcFiles.update({stCartridgeName:[(str(pFileName), 'C')]})
                    
                    
                elif lsArguments.verbose: print(f"Skipping {pFileName.name} since the ROM type can't be determined.")
        else:
            if lsArguments.verbose: print(f"Skipping {pFileName.name} since it's an alternative version.")

    iCartridgesConverted=0
    iExitCode=0
    for stCartridgeName in sorted(dcFiles):
        stCromFileName=''
        stDromFileName=''
        stGromFileName=''
        for stFileName, stFileType in dcFiles[stCartridgeName]:
            if stFileType=='C': stCromFileName=stFileName
            elif stFileType=='D': stDromFileName=stFileName
            elif stFileType=='G': stGromFileName=stFileName
        if lsArguments.verbose: print(f'== Creating cartrige {stCartridgeName} ==')
        if lsArguments.simulate:
            print('createRom(stOutputFile=',os.path.join(lsArguments.imagePath, stCartridgeName)+'.M99',
                  ',stCrom=',stCromFileName,',stDrom=',stDromFileName,',stGrom=',stGromFileName, ',blCheck=',lsArguments.check,
                  ',blVerbose=',lsArguments.verbose, ',stPagingType=',lsArguments.paging, ',blUseInternalName=',lsArguments.internalname, ')',sep='')
            iResult=-1
        else:
            iResult=createRom(stOutputFile=os.path.join(lsArguments.imagePath, stCartridgeName)+'.M99',
                              stCrom=stCromFileName,stDrom=stDromFileName,stGrom=stGromFileName, blCheck=lsArguments.check,
                              blVerbose=lsArguments.verbose, stPagingType=lsArguments.paging, blUseInternalName=lsArguments.internalname)

        if iResult==0:
            iCartridgesConverted+=1
        elif iExitCode==0:
            iExitCode=iResult
        print()

    if stFileNameListing:
        stListingFormat=stFileNameListing[-3:].lower()
        lsFiles=sorted([x for x in dcFiles])
        iMaxLength=len(max(lsFiles,key=len))
        with open(stFileNameListing,'w') as fListingFile:
            for stFile in lsFiles:
                with open(os.path.join(lsArguments.imagePath,stFile)+'.bin','rb') as fCurrentFile:
                    vSingleFile=fCurrentFile.read()
                    stChecksum=hashlib.md5(vSingleFile).hexdigest()
                if stListingFormat=='csv':
                    fListingFile.write(f'{stFile};{stChecksum};;;\n')
                elif stListingFormat=='txt':
                    fListingFile.write(f'| {stFile:<{iMaxLength}s} | {stChecksum:32s} |         |         |\n')
                else:
                    raise ValueError(f'Unknown file format {stListingFormat}')

    if lsArguments.verbose:
        if lsArguments.simulate:
            print('** SIMULATION **')
        else:
            dtTimeDelta=dt.datetime.now()-dtStartTime
            print(f'{iCartridgesConverted} cartridges created in {dtTimeDelta/dt.timedelta(seconds=1):2.2f} seconds.')
    sys.exit(iExitCode)
