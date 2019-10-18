# Diznavis
FFBE AutoIT Script

If you enjoy using this script, please consider donating. It took an enormous amount of time to build it.
Donation link: https://gogetfunding.com/ffbe-autoit-script/

Download the entire package with all the required files at:
https://drive.google.com/drive/folders/1MNWW7U-qE3sk8eFcf6pt7gvhNj2y6bOm?usp=sharing

Requirements:

Dedicated 64-bit Windows computer (Windows 7 is the only one tested, it should work on 10 though, and no one uses 8 anyway)

1366x768 resolution (or higher), but the 1366 has to be vertical (so really 768x1366). Portrait mode may be needed to accomplish this.

Tesseract - screen reader - installer included in zip file, only version tested, probably works with newer versions, assuming there are any

Memu 5.1.1.1 - Only version really tested, though I had trouble with a newer version not showing the instance name in the title bar which caused the script to be unable to find the window. I'm sure the detection could be reworked to avoid this, but I didn't take the time to do it, just stuck with the version that works.

FFBE account either linked to google (preferred) or one that won't ask to re-login if linked to FB (would require script changes to make it work with this, I'm sure it's possible, but I never had a reason to do it)


Recommended:

Teamviewer (free) - remotely control the script. The script will automatically clear the sponsored session messages so they won't break it

Notes:
FFBE-Macro.au3 is the main brains of the script. FastTMFarm.au3 is called by FFBE-Macro, it should not be operated on its own. It allows the script to continue to know what is going on while TM farming - it doesn't have to interrupt what it is doing to do the clicking.

Getting Started:
Set up a 64-bit computer, 768x1366 resolution or better
install memu and tesseract
set memu to use 576x1024 resolution (critical)
Get your FFBE account working on Memu (must use amazon version at this time)
Recommend turning off all extra visual effects
Place FFBE icon in the top right of the first line of icon on the main home screen in memu
create C:\FFBE Macro and unzip the zip file into that folder
create C:\FFBE and place the FFBE.ini file there
Edit FFBE.ini with any changes you need to make
Create a shortcut to C:\FFBE Macro\FFBE-Macro.exe on the desktop. You'll also want one in the startup folder once you have everything working
Test, hopefully everything is working for you

