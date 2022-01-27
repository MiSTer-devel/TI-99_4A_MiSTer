#!/usr/bin/env python3
import os
import argparse
from zipfile import ZipFile


if __name__ == "__main__":
    vParser = argparse.ArgumentParser()
    vParser.add_argument('--romPath', help='The path to the Mame Roms Folder.',type=str, default='.')
    vParser.add_argument('OutputPath', help="The path to put the generated roms.", type=str, default='.')
    lsArguments=vParser.parse_args()

    if os.path.exists(lsArguments.romPath+"/ti99_4a.zip"):
        print(f'Found ti99_4a.zip')
        gromList=["994a_grom0.u500", "994a_grom1.u501", "994a_grom2.u502"]
        romList=["994a_rom_hb.u610", "994a_rom_lb.u611"]
        SGrom0=bytearray()
        SGrom1=bytearray()
        SGrom2=bytearray()
        with ZipFile(lsArguments.romPath+"/ti99_4a.zip",'r') as zip:
            SystemRom=bytearray()
            Hbuff = zip.read(romList[0])
            Lbuff = zip.read(romList[1])
            for index in range (0 , len(Hbuff)):
                SystemRom.extend(Hbuff[index:index+1])
                SystemRom.extend(Lbuff[index:index+1])
            
            SGrom0.extend(zip.read(gromList[0]))
            SGrom0.extend(bytes([0]*2048))
            SGrom1.extend(zip.read(gromList[1]))
            SGrom1.extend(bytes([1]*2048))
            SGrom2.extend(zip.read(gromList[2]))
            SGrom2.extend(bytes([2]*2048))

        with open(lsArguments.OutputPath+"/994ARom.BIN",'wb') as fOutputFile:
            fOutputFile.write(SystemRom)
        with open(lsArguments.OutputPath+"/994AGrom.BIN",'wb') as fOutputFile:
            fOutputFile.write(SGrom0)
            fOutputFile.write(SGrom1)
            fOutputFile.write(SGrom2)
        print(f'    Created {lsArguments.OutputPath}/994ARom.BIN')
        print(f'    Created {lsArguments.OutputPath}/994AGrom.BIN\n')

    if os.path.exists(lsArguments.romPath+"/ti99_4qi.zip"):
        print(f'Found ti99_4qi.zip')
        SQiGrom0=bytearray()
        with ZipFile(lsArguments.romPath+"/ti99_4qi.zip",'r') as zip:
            SQiGrom0.extend(zip.read("994qi_grom0.u29"))
            SQiGrom0.extend(bytes([1]*2048))
        with open(lsArguments.OutputPath+"/994AGrom-QI.BIN",'wb') as fOutputFile:
            fOutputFile.write(SQiGrom0)
            fOutputFile.write(SGrom1)
            fOutputFile.write(SGrom2)
        print(f'    Created {lsArguments.OutputPath}/994AGrom-QI.BIN\n')

    if os.path.exists(lsArguments.romPath+"/ti99_4ev.zip"):
        print(f'Found ti99_4ev.zip')
        SEvGrom1=bytearray()
        with ZipFile(lsArguments.romPath+"/ti99_4ev.zip",'r') as zip:
            SEvGrom1.extend(zip.read("994ev_grom1.u501"))
            SEvGrom1.extend(bytes([1]*2048))
        with open(lsArguments.OutputPath+"/994AGrom-EV.BIN",'wb') as fOutputFile:
            fOutputFile.write(SGrom0)
            fOutputFile.write(SEvGrom1)
            fOutputFile.write(SGrom2)
        print(f'    Created {lsArguments.OutputPath}/994AGrom-EV.BIN\n')

    if os.path.exists(lsArguments.romPath+"/ti99_pcode.zip"):
        print(f'Found ti99_pcode.zip')
        gromList=["pcode_grom0.u11", "pcode_grom1.u13", "pcode_grom2.u14", "pcode_grom3.u16", "pcode_grom4.u19", "pcode_grom5.u20", "pcode_grom6.u21", "pcode_grom7.u22"]
        romList=["pcode_rom0.u1", "pcode_rom1.u18"]
        with ZipFile(lsArguments.romPath+"/ti99_pcode.zip",'r') as zip:
            pcodeRom=bytearray()
            for rom in romList:
                pcodeRom.extend(zip.read(rom))
            for grom in gromList:
                pcodeRom.extend(zip.read(grom))
                pcodeRom.extend(bytes([0]*2048))
        with open(lsArguments.OutputPath+"/PCode.BIN",'wb') as fOutputFile:
            fOutputFile.write(pcodeRom)
        print(f'    Created {lsArguments.OutputPath}/PCode.BIN\n')

    if os.path.exists(lsArguments.romPath+"/ti99_speech.zip"):
        print(f'Found ti99_speech.zip')
        romList=["cd2325a.u2a", "cd2326a.u2b"]
        SpeechRom=bytearray()
        with ZipFile(lsArguments.romPath+"/ti99_speech.zip",'r') as zip:
            for rom in romList:
                Sbuff=zip.read(rom)
                for index in range(0, len(Sbuff)):
                    SpeechRom.extend(int('{:08b}'.format(Sbuff[index])[::-1], 2).to_bytes(1,'big'))
        with open(lsArguments.OutputPath+"/Speech.BIN",'wb') as fOutputFile:
            fOutputFile.write(SpeechRom)
        print(f'    Created {lsArguments.OutputPath}/Speech.BIN\n')

    if os.path.exists(lsArguments.romPath+"/ti99_fdc.zip"):
        print(f'Found ti99_fdc.zip')
        romList=["fdc_dsr.u26", "fdc_dsr.u27"]
        DiskRom=bytearray()
        with ZipFile(lsArguments.romPath+"/ti99_fdc.zip",'r') as zip:
            for rom in romList:
                DiskRom.extend(zip.read(rom))
        with open(lsArguments.OutputPath+"/Disk.BIN",'wb') as fOutputFile:
            fOutputFile.write(DiskRom)
        print(f'    Created {lsArguments.OutputPath}/Disk.BIN\n')

    if os.path.exists(lsArguments.romPath+"/ti99_ddcc1.zip"):
        print(f'Found ti99_ddcc1.zip')
        romList=["ddcc1.u3"]
        DiskRom=bytearray()
        with ZipFile(lsArguments.romPath+"/ti99_ddcc1.zip",'r') as zip:
            for rom in romList:
                DiskRom.extend(zip.read(rom))
        with open(lsArguments.OutputPath+"/Myarc.BIN",'wb') as fOutputFile:
            fOutputFile.write(DiskRom)
        print(f'    Created {lsArguments.OutputPath}/Myarc.BIN\n')
