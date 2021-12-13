#!/usr/bin/env python3
import os
import argparse
from zipfile import ZipFile


if __name__ == "__main__":
    vParser = argparse.ArgumentParser()
    vParser.add_argument('--romPath', help='The path to the Mame PCode Rom File (ti99_pcode.zip).',type=str, default='ti99_pcode.zip')
    vParser.add_argument('OutputFile', help="The memory image to be created.", type=str)
    lsArguments=vParser.parse_args()

    gromList=["pcode_grom0.u11", "pcode_grom1.u13", "pcode_grom2.u14", "pcode_grom3.u16", "pcode_grom4.u19", "pcode_grom5.u20", "pcode_grom6.u21", "pcode_grom7.u22"]
    romList=["pcode_rom0.u1", "pcode_rom1.u18"]
    with ZipFile(lsArguments.romPath,'r') as zip:
        pcodeRom=bytearray()
        for rom in romList:
            pcodeRom.extend(zip.read(rom))
        for grom in gromList:
            pcodeRom.extend(zip.read(grom))
            pcodeRom.extend(bytes([0]*2048))
    with open(lsArguments.OutputFile,'wb') as fOutputFile:
        fOutputFile.write(pcodeRom)
