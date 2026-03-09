SilTech Industries - Flash Tool
================================

Production firmware flashing tool for factory workers.
Just select a device, then press ENTER to flash. Repeat.


HOW TO USE
----------
1. Put device firmware folders in firmware\ folder
   Each folder needs: firmware.bin + bootloader.bin + partitions.bin

   Example:
     firmware\
       BusLog_4G_v2\
         bootloader.bin
         partitions.bin
         firmware.bin
       BusLog_4G_Lite\
         bootloader.bin
         partitions.bin
         firmware.bin

2. Double-click flash.bat
3. Select device type (number)
4. Connect device via USB
5. Press ENTER to flash
6. Watch serial output for errors
7. Press Q + Enter to stop monitor
8. Disconnect, connect next device
9. Press ENTER to flash again
10. Repeat!


WHAT IT DOES
------------
- Detects USB adapter automatically
- Flashes bootloader + partitions + app (if all files present)
- Flashes app-only if bootloader/partitions missing
- Hard resets device after flash
- Starts serial monitor automatically
- Counts successful/failed flashes
- Logs everything to logs\ folder


REQUIREMENTS
------------
- Windows 10/11
- CH340 or CP2102 USB-to-serial adapter
- USB driver installed (CH340: wch-ic.com/downloads)


TROUBLESHOOTING
---------------
"No USB adapter detected"
  -> Install CH340 driver
  -> Try different USB port

"Flash failed"
  -> Hold BOOT button while flashing
  -> Check TX/RX/GND wires
  -> Try again

"Monitor shows garbage"
  -> Normal on first boot sometimes
  -> Wait for device to finish init
