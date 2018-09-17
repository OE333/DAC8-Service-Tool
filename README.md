# DAC8-Service-Tool
Service tool for T+A D/A converters DAC8 and DAC8DSD - update firmware, control the device via RS232, perform different service tasks

The tool is written in Pascal, using Lazarus IDE v 1.6 and is intended for use on a Windows PC.

For those only interested in upgrading the firmware of DAC8DSD:
a compiled version of this program can be found in the subfolder /executable.
To run this program a Windows PC with serial RS232 interface (COM poert) is needed.
A USB/RS232 converetr can be used in cases where there is no COM port available on the PC.
To connect the PC to the RS232 port of the PC a Sub-D9 -> T+A CTRL adapter is required.
Such an adapter is described in the DAC8DSD_RS232.pdf document contained in subfolder /related documents.

Please read the documents in the subfolder /related_documents.
Keep in mind that re-flashing a microprocessor (that is what this program does) 
is never free of risk. If anything goes wrong (loss of power, loss of connection) 
this can possibly damage the device to be flashed.
In worst case the device to be flashed could be bricked and will not work any more...

I believe that this program is sufficiently safe but I take no responsibility for any 
risks resulting from using this software.
