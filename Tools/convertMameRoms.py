#!/usr/bin/env python3
import os
import argparse
import math
import xml.etree.ElementTree as ET
from zipfile import ZipFile


M99Ver=0


if __name__ == "__main__":
    vParser = argparse.ArgumentParser()
    vParser.add_argument('--xmlPath', help='The path to the TI99_4A Mame Software List xml (output of mame ti99_4a -listsoftware).',type=str, default='software.xml')
    vParser.add_argument('--romPath', help='The path to the TI99_4A Mame Rom Folder (default .).',type=str, default='')
    vParser.add_argument('--imagePath', help='The directory where the Rom files are created.',type=str,default='')
    vParser.add_argument("-d","--discriptiveFileName", help='Use rom Description/Title for Image Filename.', action="store_true")
    lsArguments=vParser.parse_args()



    mytree = ET.parse(lsArguments.xmlPath)
    myroot = mytree.getroot()
    softwarelist=myroot[0]
    for software in softwarelist:
        cartName=software.attrib['name']
        cartTitle=software.find("description").text
        cartPublisher=software.find("publisher").text
        cartInfo=software.find("info")
        if cartInfo!=None:
            if cartInfo.attrib["name"]=="serial": cartSerial=cartInfo.attrib["value"]
            else: cartSerial=None
        cartFeature=software.find("part").find("feature")
        cartDataArea=software.find("part").findall("dataarea")
        cartType=cartFeature.attrib["value"]
        cartRomSize=0
        cartGromSize=0
        zipRomFile=os.path.join(lsArguments.romPath,cartName+".zip")
        if os.path.exists(zipRomFile):
            with ZipFile(os.path.join(lsArguments.romPath,cartName+".zip"), 'r') as zip:
                
                for cartData in cartDataArea:
                    if cartData.attrib["name"]=="rom":
                        cartRomSize=cartData.attrib["size"]
                        padding=(math.ceil(int(cartRomSize)/8192)*8192)-int(cartRomSize)
                        romData=bytearray()
                        for rom in cartData:
                            romFile=rom.attrib["name"]
                            romSize=rom.attrib["size"]
                            romSha1=rom.attrib["sha1"]
                            romData.extend(zip.read(romFile))
                        if padding!=0: romData.extend(bytes([0]*padding))
        #                    print(f'file = {romFile}\t\t{romSize}\t{padding}')
                        
                    elif cartData.attrib["name"]=="grom":
                        cartGromSize=cartData.attrib["size"]
#                        print(f'# of roms = {len(cartData)}\t\tTotal Size={cartGromSize}')
                        gromData=bytearray()
                        for rom in cartData:
                            padding=0
                            romFile=rom.attrib["name"]
                            romSize=rom.attrib["size"]
                            romSha1=rom.attrib["sha1"]
                            if (len(cartData) > 1) & (int(cartGromSize) > 8192) & (rom!=cartData[-1]): padding=(math.ceil(int(romSize)/8192)*8192)-int(romSize)
                            gromData.extend(zip.read(romFile))
                            if padding!=0: gromData.extend(bytes([0]*padding))
#                            print(f'file = {romFile}\t\t{romSize}\t{padding}\t{rom==cartData[-1]}')
            if (cartType == "standard") | (cartType == "paged16k") | (cartType == "gromemu"): cartType=0
            elif cartType == "mbx": cartType=1
            elif cartType == "paged7": cartType=2
            elif cartType == "paged378": cartType=3
            elif cartType == "paged379i": cartType=4
            elif cartType == "minimem" : cartType=5
            else: cartType=0

            if lsArguments.discriptiveFileName:
                imageFileName=cartTitle.replace(' ','_')
                stFileNaimageFileNameme=imageFileName.replace('"','')
                imageFileName=imageFileName.replace('*','-')
                imageFileName=imageFileName.replace('?','')
                imageFileName=imageFileName.replace('/','-')
                imageFileName=imageFileName.replace(':','-')
                imageFileName=imageFileName.replace('\x00','')
                imageFileName=imageFileName.replace('_-_','-')
                imageFileName=imageFileName.split("__")[0]+".M99"
                imageFileName=imageFileName.replace('_.','.')
            else: imageFileName=cartName+".M99"
            with open(os.path.join(lsArguments.imagePath,imageFileName),'wb') as fOutputFile:
                fOutputFile.write("M99".encode('utf-8'))
                fOutputFile.write(M99Ver.to_bytes(1,'little'))
                fOutputFile.write(cartType.to_bytes(1,'little'))
                fOutputFile.write(math.ceil(int(cartRomSize)/8192).to_bytes(2,'big'))
                fOutputFile.write(math.ceil(int(cartGromSize)/8192).to_bytes(2,'big'))
                vReservedSpace=bytes([0]*89)
                fOutputFile.write(vReservedSpace)
                vHeaderTail=bytes([255]*2)
                fOutputFile.write(vHeaderTail)
                if cartRomSize!=0: fOutputFile.write(romData)
                if cartGromSize!=0: fOutputFile.write(gromData)
#            print(f'{cartName}\t\t{imageFileName}\t\tCartType = {cartType}')
#            print('----------------------------------------------')
#        print(f'{cartName} = {cartTitle}\t[{cartPublisher}]\tRom Size: {cartRomSize}\tGrom Size: {cartGromSize}')

