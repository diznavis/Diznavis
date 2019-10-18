#include <File.au3>

Opt("WinTitleMatchMode", -2)
Opt("MouseClickDragDelay", 1)

Global $Running = True, $aEmulatorPosition, $PauseOnTMResults = False, $CycleCount = 0, $PauseCycles = 0, $x, $y, $Dalnakya
Global $DllHandle = DllOpen("ImageSearchDLL64.dll")	; Handle for the ImageSearch.dll file so it can stay open for faster processing
Global $QuitFile = "EndFarm.txt", $TMPauseFile = "PauseEnabled.txt"
Global $Emulator =  IniRead("C:\FFBE\FFBE.ini", "Initialize", "EmulatorName", "ERROR")

FileDelete($QuitFile)		; Leftover from a previous run if it exists, delete it so we don't immediately quit
FileDelete($TMPauseFile)	; Leftover from a previous run if it exists, will be recreated if appropriate

If $Emulator = "ERROR" Then
   MsgBox(64, "Fast TM Farm", "ERROR: Missing ini file")
   Exit
EndIf

If StringLower(IniRead("C:\FFBE\FFBE.ini", "Initialize", "Dalnakya", "False")) = "true" Then
   $Dalnakya = True
Else
   $Dalnakya = False
EndIf

If $CmdLine[0] > 0 Then				; Results page pause data, 0 = no pause, 1 = pause every time, other number is seconds between checks
   If Number($CmdLine[1]) > 1 Then	; Pause is not every cycle
	  $PauseCycles = Number($CmdLine[1])
	  If $CmdLine[0] = 1 Then		; Adding another parameter will disable the initial pause and wait until the interval is complete
		 $PauseOnTMResults = True
		 _FileCreate($TMPauseFile)
	  EndIf
   ElseIf Number($CmdLine[1]) = 1 Then
	  $PauseCycles = 1
	  $PauseOnTMResults = True
	  _FileCreate($TMPauseFile)
   EndIf
EndIf
If NOT WinExists($Emulator, "") Then
   MsgBox(64, "Fast TM Farm", "ERROR: Unable to find emulator window")
   Exit
EndIf

While $Running
   If $PauseCycles > 1 AND NOT $PauseOnTMResults Then
	  $CycleCount = $CycleCount + 1
	  If $CycleCount = $PauseCycles Then
		 $PauseOnTMResults = True
		 _FileCreate($TMPauseFile)
		 $CycleCount = 0
	  Else
		 $PauseOnTMResults = False
		 FileDelete($TMPauseFile)
	  EndIf
   EndIf
   $aEmulatorPosition = WinGetPos($Emulator, "")
   $EmulatorX1 = $aEmulatorPosition[0]
   $EmulatorY1 = $aEmulatorPosition[1]
   $EmulatorX2 = $EmulatorX1 + $aEmulatorPosition[2]
   $EmulatorY2 = $EmulatorX2 + $aEmulatorPosition[3]
   MouseClick("main", $EmulatorX1 + 270, $EmulatorY1 + 690, 1, 0)		; Hits earth shrine entrance and Unit 1
   _CheckForTMPage()
   MouseClick("main", $EmulatorX1 + 160, $EmulatorY1 + 780, 1, 0)		; Hits decline friend request and Unit 2
   _CheckForTMPage()
   MouseClick("main", $EmulatorX1 + 250, $EmulatorY1 + 925, 1, 0)		; Hits depart, next buttons and Unit 3, was 910
   _CheckForTMPage()
   If $Dalnakya Then
	  MouseClick("main", $EmulatorX1 + 560, $EmulatorY1 + 700, 1, 0)	; Hits Unit 4
	  _CheckForTMPage()
	  MouseClick("main", $EmulatorX1 + 560, $EmulatorY1 + 860, 1, 0)	; Hits Unit 5
	  _CheckForTMPage()
	  MouseClick("main", $EmulatorX1 + 300, $EmulatorY1 + 925, 1, 0)	; Hits depart, next buttons and Unit 6
	  _CheckForTMPage()
   EndIf
WEnd
_EndScript()


Func _EndScript()
   Sleep(1000)
   FileDelete($QuitFile)
   FileDelete($TMPauseFile)
   DllClose($DllHandle)
   Exit
EndFunc


Func _CheckForTMPage()
   Local $FoundPage = False
   If FileExists($QuitFile) Then _EndScript()
   If $PauseOnTMResults Then
	  Sleep(250)
	  While _ImageSearchArea("Battle_Results_TM.bmp", 0, $EmulatorX1 + 140, $EmulatorY1 + 140, $EmulatorX1 + 450, $EmulatorY1 + 200, $x, $y, 60) = 1
		 $FoundPage = True
		 If FileExists($QuitFile) Then _EndScript()
		 Sleep(2000)
	  WEnd
	  If $FoundPage Then
		 If $PauseCycles > 1 Then
			$PauseOnTMResults = False
			FileDelete($TMPauseFile)
		 EndIf
	  EndIf
   ElseIf $Dalnakya Then
	  Sleep(166)	; A sixth of a second so each cycle (6 pauses) is about 1 second
   Else
	  Sleep(333)	; A third of a second so each cycle (3 pauses) is about 1 second
   EndIf
EndFunc


; Copied from ImageSearch.au3 and modified to keep the .dll open for faster processing and to not return location because this script doesn't care about that
Func _ImageSearchArea($findImage, $resultPosition, $x1, $y1, $right, $bottom, ByRef $x, ByRef $y, $tolerance, $HBMP=0)
   If $tolerance > 0 Then $findImage = "*" & $tolerance & " " & $findImage
   If IsString($findImage) Then
	  $result = DllCall($DllHandle, "str", "ImageSearch", "int", $x1, "int", $y1, "int", $right, "int", $bottom, "str", $findImage, "ptr", $HBMP)
   Else
	  $result = DllCall($DllHandle, "str", "ImageSearch", "int", $x1, "int", $y1, "int", $right, "int", $bottom, "ptr", $findImage, "ptr", $HBMP)
   EndIf
   If $result[0]="0" Then
	  Return 0
   Else
	  Return 1
   EndIf
EndFunc