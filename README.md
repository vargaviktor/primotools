# primotools
Mikrokey Primo tape image converters (between ptp and pri, and a checksummer)

To learn about the Mikrokey Primo computer check the http://primo.homeserver.hu/ page.

Compile:
- with FreePascal


Pri2PTP
-------
Converts Pri files (.PRG) to .PTP files.

Use:

pri2ptp inputfile outputfile [-n]

       	 inputfile: PRI (.PRG) file
 	outputfile: PTP file (existing or new Primo Tape file)
	        -n: if this switch is there, you will be asked for the filename
                    which will be stored into the .ptp file, else the default name
                    will be stored: "pri2ptp conv."

A PTP file can include more than one tape image, so you can use existing tape file name, 
and the converted file going to the end of the file.

You can use the -n parameter, because in the PTP file the Primo filename is stored.
I you dont give it, the pconverter will add automaticaly the string "pri2ptp conv." 
and with this, we can mark these files were converted.

(It generates RAW CRC, which is a check sum of all DATA bytes. Headings, and synchronization 
are not included in this checksum. If there is two version of a program and they have different
size and they are not binary equal, these differences can come from the different block sizes.
If the RAW CRC is equal, the programs are equal.)


PTP2Pri
-------
Converts PTP file to .Pri (.PRG) files.

Use: 

ptp2pri inputfile
   	
	inputfile: PTP file

Because the PTP file includes the filename, the output file names will be derived from the 
filename stored in PTP file. The the file name is invalid under DOS or exists, the program will 
ask for the filename.

(It generates RAW CRC, which is a check sum of all DATA bytes. Headings, and synchronization 
are not included in this checksum. If there is two version of a program and they have different
size and they are not binary equal, these differences can come from the different block sizes.
If the RAW CRC is equal, the programs are equal.)

CRCPrimo
--------
Checks a file for blocks, internal CRC, and RAW CRC.

Use: 
crcprimo -s|-l inputfile [inputfile] [inputfile...]
	 
	 inputfiles are PRI (.PRG) or PTP file
 	 -s: short info (name, raw CRC, start address
	 -l: long info with block information

This program cheks files, for internal CRC (only in PTP file, Pri file doesnot have), for block
structure, and generates RAW CRC.

RAW CRC is a check sum of all DATA bytes. Headings, and synchronization are not included in this
checksum. If there is two version of a program and they have different size and they are not 
binary equal, these differences can come from the different block sizes. If the RAW CRC is equal,
the programs are equal.

