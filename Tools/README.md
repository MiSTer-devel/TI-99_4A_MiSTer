# Python Scripts to Create/Convert M99 Cartridge Roms
Python 3.10 or above is required to run these scripts
As always, run these scripts on files you have backups for.

# What is M99
M99 is a rom header and format to create a single "ROM" file for TI-99/4A Cartridges that have multiple rom/grom files (i.e. c/d/g files).
Since MiSter cores only have access to filename extensions only, using existing naming conventions (_8.bin, _9.bin ...)is not possible, so M99, with the help of Tmop, was created.
It can also be used to tell the TI-99/4A core what Cartridge Type/Paging to use with the Rom.
The header has room for future expansion (ex. Tell the core to Enable/Disable SAMS or pre-select NTSC/PAL video modes.) 
The following Scripts help with creating M99 rom files, either from seperate C/D/G files, from Mame Rom sets or converting the legacy "full" 288k .bin romsets.

# createImage.py
Edited version from GHPS's pyTIrom
Syntax: **createImage.py --Crom cartC.bin --Drom cartD.bin --Grom cartG.bin -p -i -c -v OUTPUTFILE
Options:     --Crom          [Optional*] Specifies the Cartridge's C rom file.
             --Drom          [Optional]  Specifies the Cartridge's D rom file.
             --Grom          [Optional*] Specifies the Cartridge's G rom file.
             -p              [Optional]  Specify the Paging System it uses 0=Normal, 7=Paged7, 8=378, 9=379, M=MBX, MM=MiniMem.
             -i              [Optional]  Attempt to base the rom name on Cartridge's System Menu name/title.  If not, defaults to OUTPUTFILE
             -c              [Optional]  Display Checksums for each file used.
             -v              [Optional]  Verbose.  Spew a bunch of processing info.  Mostly useful for debugging.
             OUTPUTFILE      [Required]  The filename of the resulting ROM.
(*) Must specify at least one Crom or Grom file.

# convertArchive.py
Edited version from GHPS's pyTIrom
This script goes through *romPath*, identifies roms and calls createImage.py to generate the roms.  Great for a folder full of C/D/G roms.
Syntax: **convertArchive.py --romPath {path} --imagePath {path} --simulate -l -n -c -p -i -t -v
Options:     --romPath       [Optional]  Specifies the folder/path of rom files to convert to M99.  Defaults to current folder.
             --imagePath     [Optional]  Specifies the output folder where the converted roms will be stored.  Defaults to current folder.
			 --simulate      [Optional]  Doesn't actually create the roms, but goes through the steps.
			 -l | --listing  [Optional]  Specifies an output file to list roms processed either in CSV or TXT format depending on file extension.
			 -n | --naming   [Optional]  Specifies the input rom naming convention. None, Standard, Timrad and Tosec are supported.
			 -c | --check    [Optional]  Generate Checksums for Input and Output files.
			 -p | --paging   [Optional]  Specify the Paging System it uses 0=Normal, 7=Paged7, 8=378, 9=379, M=MBX, MM=MiniMem.  (Ideal if all the roms use the same Paging System)
			 -i              [Optional]  Attempt to base the rom name on Cartridge's System Menu name/title.  If not, defaults to original rom's name.
			 -t              [Optional]  If a rom can't be identified, treat it as a C-Rom.
			 -v              [Optional]  Verbose.  See CreateImage.py.

# createSystemRoms.py
If you have the Mame rom set for TI-99/4A, use this script to generate the System Roms, Groms and DSRs to use with the core.
Files it will look for: ti99_4a.zip, ti99_4qi.zip, ti99_4ev.zip(*), ti99_pcode.zip, ti99_speech.zip and ti99_fdc.zip
(*) While groms for this system will be generated, the core doesn't currently support it.
Syntax: **createSystemRoms.py --romPath OUTPUTPATH
Options:     --romPath       [Optional]  Specifies the folder/path to the Mame Roms.  Defaults to current folder.
             OUTPUTPATH      [Required]  Specifies the folder/path where to store the processed system files.

# createPCodeRom.py
Subset of createSystemRoms.py but only creates the PCode rom needed by the core for the PCode System.
Syntax: **createPCodeRom.py --romPath OUTPUTFILE
Options:     --romPath       [Optional]  Specifies the full path and filename of the MAME Pcode rom file (ti99_pcode.zip).  Defaults ti99_pcode.zip in current folder.
             OUTPUTPATH      [Required]  Specifies the output filename of the processed PCode rom.

# convertMameRoms.py
This script goes through MAME roms and creates M99 roms out of them.
It utilizes a software list XML file created by Mame to identify the roms, they Paging type and Cartridge/Game/App title.
First create the XML file using mame with the following command (In this example, I used TI99_4A_carts.xml, but you can use whatever you want and can even specify output folder):
	*   mame ti99_4a -listsoftware > TI99_4A_carts.xml
Then run the script:
Syntax: **convertMameRoms.py --xmlPath /path/to/TI99_4A_carts.xml --romPath {MameRomPath} --imagePath {outputPath} -d
Options:     --xmlPath       [Optional]  Specifies the full path and filename of the XML file generated by MAME.  Defaults to software.xml in current folder.
             --romPath       [Optional]  Specifies the MAME rom path with TI99 cart roms to convert.  Defaults to current folder.
			 --imagePath     [Optional]  Specifies the output folder where the converted roms will be stored.  Defaults to current folder.
			 -d              [Optional]  Use the Description/Title of the cartridge found in the XML file for output rom filename.  Otherwise it will base it on the rom's zip filename.

# convertLegacyRom.py
Use this script if you want to convert a legacy rom (288k) to the new M99 rom format.
**This will not extract system roms/groms, speech rom or Disk dsr.
Syntax: **convertLegacyRom.py --OutputFile -p InputFile
Options:     --OutputFile    [Optional]  Specifies the filename of the converted rom.  Defaults to using the filename of inputfile with m99 extension.
             -p | --paging   [Optional]  Specify the Paging System it uses 0=Normal, 7=Paged7, 8=378, 9=379, M=MBX, MM=MiniMem.  (Ideal if all the roms use the same Paging System)
             InputFile       [Required]  The 288k rom file you want to convert.
