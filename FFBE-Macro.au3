#include <Date.au3>
#include <GUIConstantsEx.au3>
#include <DateTimeConstants.au3>
#include <StaticConstants.au3>
#include <ScreenCapture.au3>
#include <GDIPlus.au3>
#include <File.au3>
#include <ColorConstants.au3>
#include <ButtonConstants.au3>
#include <APIGdiConstants.au3>
#include <WinAPIGdi.au3>
#include <EditConstants.au3>
#include <Misc.au3>

Opt("WinTitleMatchMode", -2)
Opt("MouseClickDragDelay", 1)
Opt("MouseClickDownDelay", 15)
Opt("GUIOnEventMode", 1)
Opt("MustDeclareVars", 1)

Global $ScriptName = "FFBE Macro"
Global $ScriptVersion = " Version 2019.10.10"

Global $IniFile = "C:\FFBE\FFBE.ini"										; Name of the ini file used to store settings for the script
Global $EmulatorName = "UniqueName"											; Name of Emulator, as found in the title of the window. Case-insensitive and can be a partial match
Global $EmulatorEXE = '"C:\Program Files\Microvirt\MEmu\MemuConsole.exe" MEmu'	; Executable for the emulator, including any necessary arguments
Global $y = 0, $x = 0														; Coordinates used by the ImageSearch function
Global $AllowReboot = False   												; Tells the script whether it is allowed to reboot the computer
Global $TimeOut = 300														; Number of seconds to wait before labelling a delay as a fatal timeout error
Global $OrbCheckInterval = 60												; Number of minutes between orb checks - will not be exact because it will be reset when orbs are used up
Global $DllHandle = DllOpen("ImageSearchDLL64.dll")							; Handle for the ImageSearch.dll file so it can stay open for faster processing
Global $SearchDirection = "Left"											; Direction to move the map when searching for a place to click that is off the screen, changed by script as needed
Global $NextWindowPositionCheck = ""										; Next time the position of the emulator should be checked, used to reduce the number of checks
Global $PositionCheckInterval = 60											; Interval for checking the window position in seconds
Global $EmulatorX1, $EmulatorY1, $EmulatorX2, $EmulatorY2					; Position coordinates of the emulator window
Global $FastTMFarm	= "OFF"													; Handle of the FastTMFarm.exe app, used to force-close it when it is no longer needed
Global $LoggingLevel = 5													; Tells the script how detailed the log should be, 0 to disable, 1 is the least, 5 logs everything (not implemented)
Global $NextPlannedAction = ""												; A new action that needs to occur, created through GUI interaction
Global $SimulatedPause = False, $PLIADetected = False						; Information passed to the _Pause function since it can't accept parameters
Global $TimeStyleDisplay = "hh:mm tt", $TimeStyleRead = "HH:mm:00"			; Allows for time to be displayed in a different style that it is read
Global $DefaultTimeOffset = 120												; Default time in minutes to add to the current time for start/stop time boxes
Global $TMPauseFile = "PauseEnabled.txt"									; File created by FastTMFarm.exe when it is set to stop on the results page so this script can check the values
Global $TMQuitFile = "EndFarm.txt"											; File that tells FastTMFarm.exe to quit if it exists
Global $DefaultTMFarmInterval = 300											; Default time in seconds between checks for TM progress
Global $TMFarmProgressCheckInterval = $DefaultTMFarmInterval				; Time in seconds between checks for TM progress, script adjusts this based on $TMWarningThreshold
Global $ScriptPaused = False, $PauseMessageOn = False, $PausePending = False; Set to true while script is paused, $PausePending set to true while button is yellow
Global $PauseMessage = ""													; Additional text to add to pause message, set automatically as needed
Global $TextEmailAddress = 0, $StandardEmailAddress = 0						; Email addresses for sending messages to, a text to email address and a standard email address
Global $GmailAccount = 0, $GmailPassword = 0								; Gmail account for sending emails
Global $Dalnakya = False													; Set to true during 1/2 NRG events to TM farm Dalnakya Cavern instead of Earth Shrine
Global $PartyConfirmed = False												; Used in TM farming to flag that we have already set the correct party, cleared when pausing
Global $PreserveArenaOrbs = False											; Tells the script to stop using arena orbs just before weekly reset to save them for the next week when set to True
Global $ArenaOrbPreserveTime = 2											; Number of hours to store arena orbs before weekly reset
Global $ArenaWeeklyStop = False												; Tells the script to turn off the arena before weekly reset to orbs can be used after reset with a new bonus unit
Global $ArenaWeeklyStopTime = 0, $DSTArenaWeeklyStopTime = 1				; Hour of the day (0-23) to stop the arena when $WeeklyArenaStop is set to True
Global $LastArenaWeeklyStopTime = _DateAdd("d", -7, _NowCalc())				; Last time the arena was stopped, stored in the .ini file, used to prevent multiple disables in a week
Global $LastFatalErrorEmail = 0												; Last time an email was sent for a fatal error, they won't be sent more than once an hour
Global $WeeklyResetDay = 6													; Day of the week (@WDAY format) when weekly reset happens (6 = Friday)
Global $DailyResetHour = 3, $DSTDailyResetHour = 4							; Hour of the day when daily/weekly reset happens and DST value
Global $MaintenanceStartDay = 5												; Day of the week when maintenance will begin (@WDAY format)
Global $MaintenanceStartHour = 2											; Hour of the day when maintenance will begin
Global $ContinueOnPLIA = False												; Determines whether to re-login immediately after a Please Log In Again message (use False when game is working normally)
Global $DeleteTempFiles = False, $TempFileNumber							; Determines whether to delete temp files used for OCR are deleted (use false for troubleshooting)
Global $AltHomeScreen = True												; Allows checks for the skinned holiday home screen, set to false automatically if the normal home screen is found
Global $LastAcceptableExpedition = 0										; Last expedition in the last that we are allowed to run
Global $AllowAncientCoins = True											; Determines whether we are allowed to use ancient coins
Global $LastAncientCoin = _DateAdd("d", -1, _NowCalc())						; Last time we used an ancient coin, limited to one per day
Global $AllowAutoSell = False												; Determines whether to automatically sell materials if we hit a material capacity reached screen
Global $HandleFallout = False												; Set automatically when the script is told to clean up cactuars/snappers after a raid summon
Global $ClaimAdReward = False												; Determines whether the script automatically claims the 500 lapis for watching 100 ads (True) or sends a text (False)


Const $ArraySize = 13, $ArrayItems = $ArraySize - 1							; $ArraySize is 1 higher than the number of items to handle since it starts at 0
Const $Inactive = 0, $TMFarm = 1, $ClaimDailies = 2, $DailyEP = 3			; Array positions
Const $SendGifts = 4,  $AdWheel = 5, $Expeditions = 6, $Arena = 7			; Array positions
Const $Raid = 8, $CactuarFusion = 9, $SellMaterials = 10					; Array positions
Const $SellSnappers = 11, $RaidSummons = 12									; Array positions
Const $NoGroup = 0, $Group1 = 1, $Group2 = 2								; TM Unit groupings
Global $FriendlyName[$ArraySize] = [$ArrayItems, "TM Farm", "Dailies", "Daily EP", "Send Gifts", "Ad Wheel", "Expeditions", "Arena", "Raid", "Cactuars", "Sell Mats", "Snappers", "Raid Summons"] ; Friendly names for display
Global $Enabled[$ArraySize] = [$ArrayItems, False, False, False, False, False, False, False, False, False, False, False, False]		; Enabled/disabled statuses
Global $StartTime[$ArraySize] = [$ArrayItems, "OFF", "OFF", "OFF", "OFF", "OFF", "OFF", "OFF", "OFF", "OFF", "OFF", "OFF", "OFF"]	; Start times
Global $StopTime[$ArraySize] = [$ArrayItems, "OFF", "OFF", "OFF", "OFF", "OFF", "OFF", "OFF", "OFF", "OFF", "OFF", "OFF", "OFF"]	; Stop times
Global $EnabledCheckbox[$ArraySize] = [$ArrayItems, "", "", "", "", "", "", "", "",  "", "", "", ""]		; Enabled checkboxes
Global $StartCheckbox[$ArraySize] = [$ArrayItems, "", "", "", "", "", "", "", "", "", "", "", ""]		; Start time checkboxes
Global $StopCheckbox[$ArraySize] = [$ArrayItems, "", "", "", "", "", "", "", "", "", "", "", ""]		; Stop time checkboxes
Global $StartTimeBox[$ArraySize] = [$ArrayItems, "", "", "", "", "", "", "", "", "", "", "", ""]		; Start time controls
Global $StopTimeBox[$ArraySize] = [$ArrayItems, "", "", "", "", "", "", "", "", "", "", "", ""]			; Stop time controls
Global $NextOrbTimeBox[$ArraySize] = [$ArrayItems, "", "", "", "", "", "", "", "", "", "", "", ""]		; Next orb time controls
Global $NextOrbCheck[$ArraySize] = [$ArrayItems, "", _NowCalc(), _NowCalc(), _NowCalc(), _NowCalc(), _NowCalc(), _NowCalc(), _NowCalc(), _NowCalc(), _NowCalc(), _NowCalc(), "OFF"] ; Next times to check for orbs
Global $PauseButton, $HomePauseButton, $LogOutPauseButton, $ApplyButton		; Button handles
Global $RaidSummonsButton													; Button handles
Global $DalnakyaCheckbox													; Dalnakya farming mode checkbox
Global $GUIHandle = "OFF"													; Window handle for the GUI
Global $DebugBox = ""														; Textbox that holds debugging information
Global $CurrentAction = $Inactive											; Tells the script what it is supposed to be doing
Global $UnitName[6] = [5, "Unit 1", "Unit 2", "Unit 3", "Unit 4", "Unit 5"]	; Names of each unit in TMR party, read by OCR when TM progress is checked
Global $UnitTMProgress[6] = [5, 0, 0, 0, 0, 0]								; TM progress level for each unit
Global $UnitTMVerified[6] = [5, False, False, False, False, False]			; Changes to true when the progress is verified by the script (as opposed to read from the .ini)
Global $UnitTMGroup[6] = [5, 0, 0, 0, 0, 0]									; Unit grouping for TM progress (like units going for combined 100% in same group)
Global $UnitTMTarget[6] = [5, 100, 100, 100, 100, 100]						; Target TM progress (normally 100%) for each unit (units in a group share this, it is not per unit)
Global $UnitTMExpeditionProgress[6] = [5, 0, 0, 0, 0, 0]					; TM progress level for each expedition unit
Global $UnitTMExpeditionVerified[6] = [5, False, False, False, False, False]; Changes to true when the progress is verified by the script (as opposed to read from the .ini)
Global $UnitTMExpeditionGroup[6] = [5, 0, 0, 0, 0, 0]						; Unit grouping for TM progress for TM Expedition
Global $UnitTMExpeditionTarget[6] = [5, 100, 100, 100, 100, 100]			; Target TM progress (normally 100%) for each unit (units in a group share this, it is not per unit)
Global $TMDisplayType = 0													; Holds the currently displayed TM information, 0 is the TM farming party, 1 is the TM expedition party
Global $TMGroupRadio[6][3]													; Radio buttons for TM progress groups
Global $TMTargetBox[6]														; GUI Input Boxes for unit TM targets
Global $UnitTMProgressDisplay[6], $UnitNameDisplay[6]						; GUI Text Labels for unit TM progress and unit names
Global $TMSwitchDisplayButton, $TMDisplayTypeBox							; GUI Controls for switching the TM party display
Global $TMWarningThreshold1[6] = [180, 1, 2, 3, 4, 5]						; Threshold levels (remaining TM percent) for more frequent TM progress checks
Global $TMWarningThreshold2[6] = [90, 0.3, 0.6, 0.9, 1.2, 1.5]				; [1]-[5] are checked for the threshold level depending on how many units are in the TM group
Global $TMWarningThreshold3[6] = [1, 0.1, 0.2, 0.3, 0.4, 0.5]				; [0] holds the frequency in seconds, setting it to 1 means check every time
Global $ExpeditionSpots = 3, $ExpeditionName = 1, $ExpeditionAllowItem = 2	; Array positions for $ExpeditionList
Global $ExpeditionTM = 0													; Array positions for $ExpeditionList
Global $ExpeditionList[1][$ExpeditionSpots]									; Holds the list of expeditions and item use status read from the .ini file
Global $MaterialsSpots = 3, $MaterialDescription = 1, $SaveStacks = 2		; Array positions for $MaterialsList
Global $MaterialsList[1][$MaterialsSpots]									; Holds the list of materials that can be sold
Global $MaxExperience[5] = [4, 89999, 409999, 1049999, 3999999]				; Maximum experience a cactuar can have and still be fused
Global $WorldClickTM, $TMSelect, $TMBattle, $TMNextButton, $TMFriend
Global $TMDepartButton, $TMInBattle



Const $InfiniteLoop = True			; Used for While/WEnd loops that aren't meant to end naturally
Const $UseApplyButton = True		; Tells the script whether to add an Apply button or to take changes on the fly (may miss some, seems buggy)
Const $OKButton = "OK_Button.bmp"
Const $ActiveRepeatButton = "Repeat_Button_Active.bmp"
Const $InactiveRepeatButton = "Repeat_Button_Inactive.bmp"
Const $ActiveMenuButton = "Menu_Button_Active.bmp"
Const $InactiveMenuButton = "Menu_Button_Inactive.bmp"
Const $ConnectionError = "Connection_Error.bmp"
Const $CrashError = "Crash_Error.bmp"
Const $HomeScreen = "Home_Screen.bmp"
Const $HomeScreenAlt = "Home_Screen_Alt.bmp"
Const $ResumeMission = "Resume_Mission.bmp"
Const $LapisContinue = "Lapis_Continue.bmp"
Const $LapisContinueConfirm = "Lapis_Continue_Confirm.bmp"
Const $ContinueNoButton = "Lapis_Continue_No_Button.bmp"
Const $ContinueConfirmButton = "Lapis_Continue_Confirm_Yes_Button.bmp"
Const $BattleMenuBackButton = "In_Battle_Menu_Back_Button.bmp"
Const $Startup1 = "Startup_1.bmp"
Const $Startup2 = "Startup_2.bmp"
Const $Startup3 = "Startup_3.bmp"
Const $LogonScreen = "Logon_Screen.bmp"
Const $ArenaMainPage = "Arena_Main.bmp"
Const $ArenaRulesPage = "Arena_Rules.bmp"
Const $ArenaSelectionPage = "Arena_Selection.bmp"
Const $ArenaOpponentConfirm = "Arena_Opponent_Confirm.bmp"
Const $ArenaBeginButton = "Arena_Begin_Button.bmp"
Const $ArenaInBattle = "Arena_In_Battle.bmp"
Const $ArenaWinPage = "Arena_Win.bmp"
Const $ArenaLossPage = "Arena_Loss.bmp"
Const $ArenaBattleCancelled = "Arena_Battle_Cancelled.bmp"
;Const $ArenaResultsPage = "Arena_Results.bmp"
;Const $ArenaRankUpPage = "Arena_Rank_Up.bmp"
Const $ArenaResultsOKButton = "Arena_Results_OK_Button.bmp"
Const $ArenaRankUpOKButton = "Arena_Rank_Up_OK_Button.bmp"
Const $ArenaOrbsEmpty = "Arena_No_Orbs.bmp"
Const $ArenaOrbsLeft = "Arena_Orb.bmp"
;Const $ArenaSetupButton = "Arena_Setup_Button.bmp"
Const $ArenaOKButton = "Arena_OK_Button.bmp"
Const $WorldMainPage = "World_Map_Main.bmp"				; Assumes Paladia is unlocked
Const $WorldMapGrandshelt = "World_Map_Grandshelt.bmp"
Const $WorldMapGrandsheltIsles = "World_Map_Grandshelt_Isles.bmp"
Const $WorldClickGrandshelt = "World_Grandshelt.bmp"
Const $WorldClickES = "World_Map_Earth_Shrine.bmp"
Const $WorldClickDalnakya = "World_Map_Dalnakya.bmp"
Const $WorldClickDalnakya2 = "World_Map_Dalnakya_2.bmp"
Const $ESSelect = "Earth_Shrine_Select_Battle.bmp"
Const $ESEntrance = "Earth_Shrine_Entrance.bmp"
Const $ESNextButton = "Earth_Shrine_Next_Button.bmp"
Const $ESFriend = "Earth_Shrine_Select_Friend.bmp"
Const $ESDepartButton = "Earth_Shrine_Depart_Button.bmp"
Const $ESInBattle = "Earth_Shrine_In_Battle.bmp"
Const $DalnakyaSelect = "Dalnakya_Select_Battle.bmp"
Const $DalnakyaCavern1 = "Dalnakya_Cavern_1.bmp"
Const $DalnakyaCavern2 = "Dalnakya_Cavern_2.bmp"
Const $DalnakyaCavern3 = "Dalnakya_Cavern_3.bmp"
Const $DalnakyaNextButton = "Earth_Shrine_Next_Button.bmp"
Const $DalnakyaFriend = "Earth_Shrine_Select_Friend.bmp"
Const $DalnakyaDepartButton = "Earth_Shrine_Depart_Button.bmp"
Const $DalnakyaInBattle1 = "Dalnakya_In_Battle_1.bmp"
Const $DalnakyaInBattle2 = "Dalnakya_In_Battle_2.bmp"
Const $DalnakyaInBattle3 = "Dalnakya_In_Battle_3.bmp"
Const $WorldVortexIcon = "World_Vortex_Icon.bmp"
;Const $BackButton = "Back_Button.bmp"
Const $TMFarmPartySelected = "TM_Party_Selected.bmp"
Const $BattleResultsPage = "Battle_Results.bmp"
Const $BattleResultsNextButton = "Battle_Results_Next_Button.bmp"
Const $BattleResultsTMPage = "Battle_Results_TM.bmp"
Const $BattleResultsItemPage = "Battle_Results_Items.bmp"
Const $BattleResultsItemsNextButton = "Battle_Results_Items_Next_Button.bmp"
Const $RaidInBattle = "Raid_In_Battle.bmp"	; Currently undefined, would likely have to change for every raid, so we may continue relying on it as an Else case
;Const $UnitEnabled1 = "Unit_Enabled1.bmp"	; Units 1 and 2
;Const $UnitEnabled2 = "Unit_Enabled2.bmp"	; Units 3 and 4
;Const $UnitEnabled3 = "Unit_Enabled3.bmp"	; Units 5 and 6
Const $UnitDisabled = "Unit_Disabled.bmp"
Const $OutOfNRG = "Out_Of_NRG.bmp"
Const $NRGRecoveryBackButton = "NRG_Recovery_Back_Button.bmp"
Const $DontRequestButton = "Dont_Request_Button.bmp"
Const $UnitDataUpdated = "Unit_Data_Updated.bmp"
Const $PleaseLogInAgain = "Please_Log_In_Again.bmp"
Const $AbilityBackButton = "Ability_Back_Button.bmp"
Const $WorldBackButton = "World_Back_Button.bmp"
Const $VortexBackButton = "Vortex_Back_Button.bmp"
Const $SmallHomeButton = "Small_Home_Button.bmp"
Const $VortexMainPage = "Vortex_Main_Page.bmp"
Const $ArenaDailyReward = "Arena_Daily_Reward.bmp"
Const $DailyQuest = "Daily_Quest.bmp"
Const $SelectOpponentButton = "Select_Opponent_Button.bmp"
Const $RaidBattleSelectionPage = "Raid_Battle_Selection.bmp"
;Const $RaidMissionsPage = "Raid_Missions.bmp"
Const $RaidDepartPage = "Raid_Depart.bmp"
Const $RaidFriendPage = "Raid_Select_Friend.bmp"
Const $OutOfRaidOrbs = "Out_of_Raid_Orbs.bmp"
Const $RaidNextButton = "Raid_Next_Button.bmp"
Const $RaidNextButton2 = "Raid_Next_Button_2.bmp"
Const $RaidNextButton3 = "Raid_Next_Button_3.bmp"
Const $RaidNextButton4 = "Raid_Next_Button_4.bmp"
Const $RaidBanner = "Raid_Banner.bmp"	; Optionally this can be a number - how many banners down from the top the raid banner sits
Const $RaidPartySelected = "Raid_Party_Selected.bmp"
Const $AppUpdateRequired = "App_Update_Required.bmp"
Const $AppUpdateButton = "App_Update_Button.bmp"
Const $AppUpdateComplete = "App_Update_Complete.bmp"
Const $LoginBonusOKButton = "Login_Bonus_OK_Button.bmp"
Const $LoginClaimButton = "Login_Claim_Button.bmp"
Const $FFBEIcon = "FFBE_Icon.bmp"
Const $AdsSpinButton = "Ads_Spin_Button.bmp"
Const $AdsSpinButton2 = "Ads_Spin_Button_2.bmp"
Const $AdRewardClaimButton = "Ad_Reward_Claim_Button.bmp"
Const $RewardsWheelPage = "Rewards_Wheel_Page.bmp"
Const $AdRewardAvailable = "Ad_Reward_Available.bmp"
Const $AdsUsedUp = "Ads_Used_Up.bmp"
Const $AdsNotAvailable = "Ads_Not_Available.bmp"
Const $RewardsWheelReady = "Rewards_Wheel_Ready.bmp"
Const $AdsNextButton = "Ads_Next_Button.bmp"
Const $ExpeditionNextButton = "Expedition_Next_Button.bmp"
Const $ExpeditionsCompleted = "Expeditions_Completed.bmp"
Const $ExpeditionsScreen = "Expeditions_Screen.bmp"
Const $ExpeditionsScreen2 = "Expeditions_Screen2.bmp"
Const $ExpeditionAutoFillButton = "Expedition_Auto_Fill_Button.bmp"
Const $ExpeditionAutoFillDisabled = "Expedition_Auto_Fill_Disabled.bmp"
Const $ExpeditionDepartButton1 = "Expedition_Depart_Button1.bmp"
Const $ExpeditionDepartButton2 = "Expedition_Depart_Button2.bmp"
Const $ExpeditionCancelScreen = "Expedition_Cancel_Screen.bmp"
Const $ExpeditionsRewardScreen = "Expeditions_Reward_Screen.bmp"
Const $ExpeditionsRewardScreen2 = "Expeditions_Reward_Screen2.bmp"
Const $ExpeditionClaimReward = "Expedition_Claim_Reward.bmp"
Const $ExpeditionRefreshFree = "Expedition_Refresh_Free.bmp"
Global $ExpeditionComplete[5] = [4, "Expedition_Complete1.bmp", "Expedition_Complete2.bmp", "Expedition_Complete3.bmp", "Expedition_Complete4.bmp"]
Const $DailyQuestScreen = "Daily_Quest_Screen.bmp"
Const $DailyQuestClaimAllButton = "Daily_Quest_Claim_All_Button.bmp"
Const $FriendsScreen = "Friends_Screen.bmp"
Const $ReceiveGiftsScreen = "Receive_Gifts_Screen.bmp"
Const $SendGiftsScreen = "Send_Gifts_Screen.bmp"
Const $ManagePartyScreen = "Manage_Party_Screen.bmp"
Const $SelectBaseScreen = "Select_Base_Screen.bmp"
Const $FilteredList = "Filtered_List.bmp"
Const $EnhanceUnitsScreen = "Enhance_Units_Screen.bmp"
Const $Level1Enhancer = "Level_1_Enhancer.bmp"
Const $MaterialUnitsScreen = "Material_Units_Screen.bmp"
Const $SortScreen = "Sort_Screen.bmp"
Const $FilterScreen = "Filter_Screen.bmp"
Const $UnitFilter1 = "Unit_Filter1.bmp"
Const $UnitFilter2 = "Unit_Filter2.bmp"
Const $UnitFilter3 = "Unit_Filter3.bmp"
Const $UnitFilter4 = "Unit_Filter4.bmp"
Const $UnitFilter5 = "Unit_Filter5.bmp"
Const $UnitFilter1Alt = "Unit_Filter1_Alt.bmp"
Const $UnitFilter3Alt = "Unit_Filter3_Alt.bmp"
Const $SkipButton = "Skip_Button.bmp"
Const $ItemSetScreen = "Item_Set_Screen.bmp"
Const $MaterialsScreen = "Materials_Screen.bmp"
Const $SellMaterialsScreen = "Sell_Materials_Screen.bmp"
Const $SellMaterialsBottom = "Sell_Materials_Bottom.bmp"
Const $MaterialCapacityReached = "Material_Capacity_Reached.bmp"
Const $EquipmentCapacityReached = "Equipment_Capacity_Reached.bmp"
Const $AbilityCapacityReached = "Ability_Capacity_Reached.bmp"
Const $ItemCapacityReached = "Item_Capacity_Reached.bmp"
Const $RaidSummonScreen = "Raid_Summon_Screen.bmp"
Const $RaidSummonConfirm = "Raid_Summon_Confirm.bmp"
Const $RaidSummonNextButton = "Raid_Summon_Next_Button.bmp"
Const $RaidSummonNextButton2 = "Raid_Summon_Next_Button2.bmp"
Const $RaidSummonNextButton3 = "Raid_Summon_Next_Button3.bmp"
Const $RaidSummonNextButton4 = "Raid_Summon_Next_Button4.bmp"
Const $SellUnitsScreen = "Sell_Units_Screen.bmp"
Const $ViewUnitsScreen = "View_Units_Screen.bmp"
Const $UnitSoldOKButton = "Unit_Sold_OK_Button.bmp"
Const $SaleFilter = "Sale_Filter.bmp"
Const $AppUpdateChooseApp = "App_Update_Choose_App.bmp"
Const $AnnouncementCloseButton = "Announcement_Close_Button.bmp"
Const $EquipButton = "Equip_Button.bmp"
Const $DownloadAcceptScreen = "Download_Accept_Screen.bmp"
Const $DownloadAcceptScreen2 = "Download_Accept_Screen_2.bmp"
Const $ExpeditionAccelerateButton = "Expedition_Accelerate_Button.bmp"
Const $ExpeditionRecallButtonTM = "Expedition_Recall_Button_TM.bmp"
Const $FusionUnitsTab = "Fusion_Units_Tab.bmp"
Const $ExpeditionTMDepartButton = "Expedition_TM_Depart_Button.bmp"
Const $SelectPartyScreen = "Select_Party_Screen.bmp"
Const $CannotVerifyAccount = "Cannot_Verify_Account.bmp"
Const $LoginOptionsButton = "Login_Options_Button.bmp"
Const $SignInWithGoogleButton = "Sign_In_With_Google_Button.bmp"
Const $ChooseAnAccountScreen = "Choose_An_Account_Screen.bmp"
Const $ChooseAccountScreen = "Choose_Account_Screen.bmp"
Const $GoogleAccessScreen = "Google_Access_Screen.bmp"
Const $ExistingAccountDataScreen = "Existing_Account_Data_Screen.bmp"
Const $OverwriteDeviceData = "Overwrite_Device_Data.bmp"
Const $MaterialFullStack = "Material_Full_Stack.bmp"
Const $MaterialsSellGilCap = "Materials_Sell_Gil_Cap.bmp"
Const $SummonPopUp = "Summon_Pop_Up.bmp"
Const $RaidTitle = "Raid_Title.bmp"	; Back-up method of detecting the raid battle selection screen, must be updated every raid
Const $GooglePlayGames = "Google_Play_Games.bmp"
Const $GooglePlayGames2 = "Google_Play_Games_2.bmp"
Const $ChamberOfEnlightenmentBanner = "Chamber_Of_Enlightenment_Banner.bmp"
Const $ChamberOfEnlightenment = "Chamber_Of_Enlightenment.bmp"
Const $EnlightenmentFreeDailyBanner = "Enlightenment_Free_Daily_Banner.bmp"
Const $BlankPartyText = "Blank_Party_Text.bmp"
Const $RaidPartyImage = "Raid_Party_Image.bmp"
Const $TMFarmPartyImage = "TM_Farm_Party_Image.bmp"
Const $ExpeditionsNew = "Expeditions_New.bmp"
Const $ExpeditionsNotCompleted = "Expeditions_Not_Completed.bmp"



; ===============================================================================================================================
; Variables for the _INetSmtpMailCom
; ===============================================================================================================================
Global Enum _
        $g__INetSmtpMailCom_ERROR_FileNotFound = 1, _
        $g__INetSmtpMailCom_ERROR_Send, _
        $g__INetSmtpMailCom_ERROR_ObjectCreation, _
        $g__INetSmtpMailCom_ERROR_COUNTER

Global Const $g__cdoSendUsingPickup = 1 ; Send message using the local SMTP service pickup directory.
Global Const $g__cdoSendUsingPort = 2 ; Send the message using the network (SMTP over the network). Must use this to use Delivery Notification
Global Const $g__cdoAnonymous = 0 ; Do not authenticate
Global Const $g__cdoBasic = 1 ; basic (clear-text) authentication
Global Const $g__cdoNTLM = 2 ; NTLM
Global $gs_thoussep = "."
Global $gs_decsep = ","
Global $sFileOpenDialog = ""

; Delivery Status Notifications
Global Const $g__cdoDSNDefault = 0 ; None
Global Const $g__cdoDSNNever = 1 ; None
Global Const $g__cdoDSNFailure = 2 ; Failure
Global Const $g__cdoDSNSuccess = 4 ; Success
Global Const $g__cdoDSNDelay = 8 ; Delay


If _Singleton($ScriptName, 1) = 0 Then
   MsgBox(64, $ScriptName & $ScriptVersion, "Script is already running. Only one instance is allowed.", 15)
   Exit
EndIf

If _Date_Time_GetTimeZoneInformation()[0] = 2 Then	; Returns 2 when daylight savings time is active
   $DailyResetHour = $DSTDailyResetHour
   $ArenaWeeklyStopTime = $DSTArenaWeeklyStopTime
EndIf


_Initialize()
_CreateGUI()
;_DailyEnlightenment()
;msgbox(0,"","fail")
;If _CactuarFusion() Then
;msgbox(64,"","success")
;Else
;   msgbox(64,"","ERROR")
;EndIf
;_SellMaterials()
;_CheckWindowPosition()
;for $counter = 1 to 10
;_ClickDrag(300, 625, 300, 521, 15)
;Sleep(500)
;_ClickDrag(300, 625, 300, 520, 15)
;Sleep(500)
;Next
;_GDIPlus_Startup()
;local $xx, $yy, $zz
;for $xx = 0 to 4
;   if $xx = 1 Then
;	  $zz = 2
;   else
;	  $zz = 0
;   EndIf
;   $yy &= _OCR(25 + Int($xx * 113.5) - $zz, 730, 75, 23) & " "
;Next
;msgbox(64,"",$yy)
;msgbox(64, "", _OCR(93, 869, 100, 25))
;   msgbox(64, "", "yay")
;EndIf
;_GDIPlus_Shutdown()
;			   _ClickDrag(570, 220, 570, 390, 10)	; Drag the scroll bar down
;Exit

;if _checkforimage($ExpeditionNextButton, $x, $y) Then
;   msgbox(64,"x","x")
;EndIf
;_SelectAbility(2, "Ability,Thunder Spear")
;msgbox(64,"",_OCR(95, 670, 175, 54))
;Exit
;_GetTMProgress()
;Exit
;While $InfiniteLoop
;   Sleep(1000)
;WEnd
;msgbox(64, _SetTimeBox($StartTime[$TMFarm]), _NowCalc())
;msgbox(64, _GetFullDate("12:22:22"), _ReadTimeCtrl($StartTimeBox[$TMFarm]))
;Exit
;_CheckWindowPosition()
_MainScript()
_Reboot()


Func _CreateGUI()
   Local $SetType, $UnitNumber, $xPos = 10, $yPos = 40, $yPosExtras = 190, $FirstRun = False, $UnitProgress
   Local $CurrentUnitName, $CurrentUnitTMTarget, $CurrentUnitTMGroup, $CurrentUnitTMProgress, $CurrentUnitTMVerified, $CurrentDisplayText
   HotKeySet("{PAUSE}", _HotKeyPause)
   If $GUIHandle = "OFF" Then
	  $FirstRun = True
	  $GUIHandle = GUICreate($ScriptName & $ScriptVersion, 760, 235, 2, @DesktopHeight - 305)
	  $PauseButton = GUICtrlCreateButton("Pause the Script", 10, 5, 150, 25)
	  GUICtrlSetOnEvent($PauseButton, "_PausePressed")
	  $HomePauseButton = GUICtrlCreateButton("Get Home Screen", 170, 5)
	  GUICtrlSetOnEvent($HomePauseButton, "_PausePressed")
	  $LogOutPauseButton = GUICtrlCreateButton("Log Out", 270, 5)
	  GUICtrlSetOnEvent($LogOutPauseButton, "_PausePressed")
	  $RaidSummonsButton = GUICtrlCreateButton("Raid Summons", 325, 5)
	  GUICtrlSetOnEvent($RaidSummonsButton, "_StartRaidSummons")
	  If $UseApplyButton Then
		 $ApplyButton = GUICtrlCreateButton("Apply Changes", 675, 5)
		 GUICtrlSetOnEvent($ApplyButton, "_ChangeSettings")
	  EndIf
	  $DebugBox = GUICtrlCreateInput("_CreateGUI", 440, 7, 210, 20)
	  GUICtrlCreateGraphic(1, $yPos - 3, 1, 150, $SS_BLACKRECT)
	  GUICtrlCreateGraphic(240, $yPos - 3, 1, 150, $SS_BLACKRECT)
	  GUICtrlCreateGraphic(1, $yPos - 3, 240, 1, $SS_BLACKRECT)
	  GUICtrlCreateGraphic(1, $yPosExtras - 3, 1, 43, $SS_BLACKRECT)
   EndIf
   For $ExtraBox = 1 TO 8	; Loops through extra enabled and time boxes on the bottom row
	  Switch $ExtraBox
		 Case 1
			$SetType = $SendGifts
		 Case 2
			$SetType = $ClaimDailies
		 Case 3
			$SetType = $DailyEP
		 Case 4
			$SetType = $AdWheel
		 Case 5
			$SetType = $Expeditions
		 Case 6
			$SetType = $CactuarFusion
		 Case 7
			$SetType = $SellSnappers
		 Case 8
			$SetType = $SellMaterials
	  EndSwitch
	  If $FirstRun Then
		 $EnabledCheckBox[$SetType] = GUICtrlCreateCheckbox($FriendlyName[$SetType], $xPos, $yPosExtras)
	  EndIf
	  If $Enabled[$SetType] Then
		 GUICtrlSetState($EnabledCheckbox[$SetType], $GUI_CHECKED)
	  Else
		 GUICtrlSetState($EnabledCheckbox[$SetType], $GUI_UNCHECKED)
	  EndIf
	  If $FirstRun Then
		 $NextOrbTimeBox[$SetType] = GUICtrlCreateDate(_SetTimeBox($NextOrbCheck[$SetType]), $xPos, $yPosExtras + 20, 70, 20, $DTS_TIMEFORMAT)
		 If NOT $UseApplyButton Then
			GUICtrlSetOnEvent($NextOrbTimeBox[$SetType], "_ChangeSettings")
		 EndIf
		 GUICtrlSendMsg($NextOrbTimeBox[$SetType], $DTM_SETFORMATW, 0, $TimeStyleDisplay)
		 If NOT $Enabled[$SetType] Then
			GUICtrlSetState($NextOrbTimeBox[$SetType], $GUI_DISABLE)
		 EndIf
	  EndIf
	  If $FirstRun Then
;		 GUICtrlCreateGraphic(1, $yPosExtras - 3, 1, 38, $SS_BLACKRECT)
		 GUICtrlCreateGraphic($xPos + 74, $yPosExtras - 3, 1, 43, $SS_BLACKRECT)
;		 GUICtrlCreateGraphic(1, $yPosExtras + 40, 125, 1, $SS_BLACKRECT)
	  EndIf
	  $xPos = $xPos + 84
   Next
   If $FirstRun Then
	  GUICtrlCreateGraphic(1, $yPosExtras - 3, $xPos - 10, 1, $SS_BLACKRECT)
	  GUICtrlCreateGraphic(1, $yPosExtras + 40, $xPos - 10, 1, $SS_BLACKRECT)
   EndIf
   $xPos = 10
   For $SetType = 1 TO $ArrayItems
	  If $SetType = $TMFarm OR $SetType = $Arena OR $SetType = $Raid Then		; Only these items get full setups on the GUI, others are handled differently
		 If $FirstRun Then
			$EnabledCheckbox[$SetType] = GUICtrlCreateCheckbox($FriendlyName[$SetType], 10, $yPos)
		 EndIf
		 If $Enabled[$SetType] Then
			GUICtrlSetState($EnabledCheckbox[$SetType], $GUI_CHECKED)
		 Else
			GUICtrlSetState($EnabledCheckbox[$SetType], $GUI_UNCHECKED)
		 EndIf
		 If $FirstRun Then
			If NOT $UseApplyButton Then
			   GUICtrlSetOnEvent($EnabledCheckbox[$SetType], "_ChangeSettings")
			EndIf
			$StartCheckbox[$SetType] = GUICtrlCreateCheckbox("Start at:", 90, $yPos)
			$StartTimeBox[$SetType] = GUICtrlCreateDate(_SetTimeBox($StartTime[$SetType]), 150, $yPos, 90, 20, $DTS_TIMEFORMAT)
			GUICtrlSendMsg($StartTimeBox[$SetType], $DTM_SETFORMATW, 0, $TimeStyleDisplay)
		 EndIf
		 If $StartTime[$SetType] <> "OFF" Then
			GUICtrlSetState($StartCheckbox[$SetType], $GUI_CHECKED)
			GUICtrlSetState($StartTimeBox[$SetType], $GUI_ENABLE)
			GUICtrlSetData($StartTimeBox[$SetType], _SetTimeBox($StartTime[$SetType], True))
		 Else
			GUICtrlSetState($StartCheckbox[$SetType], $GUI_UNCHECKED)
			GUICtrlSetState($StartTimeBox[$SetType], $GUI_DISABLE)
		 EndIf
		 If $FirstRun Then
			GUICtrlSetOnEvent($StartCheckbox[$SetType], "_ChangeCheckbox")
			$yPos = $yPos + 25
			$StopCheckbox[$SetType] = GUICtrlCreateCheckbox("Stop at:", 90, $yPos)
			$StopTimeBox[$SetType] = GUICtrlCreateDate(_SetTimeBox($StopTime[$SetType]), 150, $yPos, 90, 20, $DTS_TIMEFORMAT)
			GUICtrlSendMsg($StopTimeBox[$SetType], $DTM_SETFORMATW, 0, $TimeStyleDisplay)
			If $SetType = $TMFarm Then
			   $DalnakyaCheckbox = GUICtrlCreateCheckbox("Dalnakya", 10, $yPos)
			   If NOT $UseApplyButton Then
				  GUICtrlSetOnEvent($DalnakyaCheckbox, "_ChangeSettings")
			   EndIf
			   If $Dalnakya Then
				  GUICtrlSetState($DalnakyaCheckbox, $GUI_CHECKED)
			   Else
				  GUICtrlSetState($DalnakyaCheckbox, $GUI_UNCHECKED)
			   EndIf
			Else
			   $NextOrbTimeBox[$SetType] = GUICtrlCreateDate(_SetTimeBox($NextOrbCheck[$SetType]), 10, $yPos, 70, 20, $DTS_TIMEFORMAT)
			   If NOT $UseApplyButton Then
				  GUICtrlSetOnEvent($NextOrbTimeBox[$SetType], "_ChangeSettings")
			   EndIf
			   GUICtrlSendMsg($NextOrbTimeBox[$SetType], $DTM_SETFORMATW, 0, $TimeStyleDisplay)
			   If NOT $Enabled[$SetType] Then
				  GUICtrlSetState($NextOrbTimeBox[$SetType], $GUI_DISABLE)
			   EndIf
			EndIf
		 EndIf
		 If $StopTime[$SetType] <> "OFF" Then
			GUICtrlSetState($StopCheckbox[$SetType], $GUI_CHECKED)
			GUICtrlSetState($StopTimeBox[$SetType], $GUI_ENABLE)
			GUICtrlSetData($StopTimeBox[$SetType], _SetTimeBox($StopTime[$SetType], True))
		 Else
			GUICtrlSetState($StopCheckbox[$SetType], $GUI_UNCHECKED)
			GUICtrlSetState($StopTimeBox[$SetType], $GUI_DISABLE)
		 EndIf
		 If $FirstRun Then
			GUICtrlSetOnEvent($StopCheckbox[$SetType], "_ChangeCheckbox")
			$yPos = $yPos + 25
			GUICtrlCreateGraphic(1, $yPos - 3, 240, 1, $SS_BLACKRECT)
		 EndIf
	  EndIf
   Next
   Switch $TMDisplayType
	  Case 0	; TM farming party
		 $CurrentUnitName = $UnitName
		 $CurrentUnitTMTarget = $UnitTMTarget
		 $CurrentUnitTMGroup = $UnitTMGroup
		 $CurrentUnitTMProgress = $UnitTMProgress
		 $CurrentUnitTMVerified = $UnitTMVerified
		 $CurrentDisplayText = "TM Farming Party"
	  Case 1	; TM expedition party
		 Local $CurrentUnitName[6] = [5, "Unit 1", "Unit 2", "Unit 3", "Unit 4", "Unit 5"]	; We are not currently reading unit names for the expedition party
		 $CurrentUnitTMTarget = $UnitTMExpeditionTarget
		 $CurrentUnitTMGroup = $UnitTMExpeditionGroup
		 $CurrentUnitTMProgress = $UnitTMExpeditionProgress
		 $CurrentUnitTMVerified = $UnitTMExpeditionVerified
		 $CurrentDisplayText = "TM Expedition Party"
   EndSwitch
   If $FirstRun Then
	  $yPos = 40
	  $xPos = 265
	  GUICtrlCreateGraphic($xPos - 10, $yPos - 3, 1, 150, $SS_BLACKRECT)
	  GUICtrlCreateGraphic($xPos + 240, $yPos - 3, 1, 150, $SS_BLACKRECT)
	  GUICtrlCreateGraphic($xPos + 488, $yPos - 3, 1, 150, $SS_BLACKRECT)
	  GUICtrlCreateGraphic($xPos - 10, $yPos - 3, 498, 1, $SS_BLACKRECT)
	  GUICtrlCreateGraphic($xPos - 10, $yPos + 47, 498, 1, $SS_BLACKRECT)
	  GUICtrlCreateGraphic($xPos - 10, $yPos + 97, 498, 1, $SS_BLACKRECT)
	  GUICtrlCreateGraphic($xPos - 10, $yPos + 147, 498, 1, $SS_BLACKRECT)
   	  For $UnitNumber = 1 TO 5
;		 $UnitProgress = "N/A"										; Default setting for unit progress
;		 _GetSetting("Unit " & $UnitNumber & " TM", $UnitProgress)	; Get unit progress from ini file, which is stored in the correct format for display because of this usage
;		 $UnitProgress = StringReplace($UnitProgress, "%", "%*")	; Add a * to the end if this is a percentage because this is unverified at this point
		 $UnitNameDisplay[$UnitNumber] = GUICtrlCreateLabel($CurrentUnitName[$UnitNumber], $xPos + 1, $yPos + 3, 150, 15)
		 GUICtrlCreateLabel("TM:", $xPos + 168, $yPos + 3, 20, 15)
		 $UnitTMProgressDisplay[$UnitNumber] = GUICtrlCreateLabel($CurrentUnitTMProgress[$UnitNumber] & $UnitProgress, $xPos + 190, $yPos + 3, 45, 15)
		 GUICtrlCreateLabel("Target:", $xPos + 105, $yPos + 3, 35, 15)
		 $TMTargetBox[$UnitNumber] = GUICtrlCreateInput($CurrentUnitTMTarget[$UnitNumber], $xPos + 140, $yPos, 25, 20, $ES_NUMBER)
		 GUICtrlSetLimit($TMTargetBox[$UnitNumber], 3)
		 If NOT $UseApplyButton Then
			GUICtrlSetOnEvent($TMTargetBox[$UnitNumber], "_ChangeSettings")
		 EndIf
		 $yPos = $yPos + 25
		 GUIStartGroup()
		 $TMGroupRadio[$UnitNumber][$NoGroup] = GUICtrlCreateRadio("No Group", $xPos, $yPos, 70, 20)
		 If NOT $UseApplyButton Then
			GUICtrlSetOnEvent($TMGroupRadio[$UnitNumber][$NoGroup], "_ChangeSettings")
		 EndIf
		 $TMGroupRadio[$UnitNumber][$Group1] = GUICtrlCreateRadio("Group 1", $xPos + 80, $yPos, 70, 20)
		 If NOT $UseApplyButton Then
			GUICtrlSetOnEvent($TMGroupRadio[$UnitNumber][$Group1], "_ChangeSettings")
		 EndIf
		 $TMGroupRadio[$UnitNumber][$Group2] = GUICtrlCreateRadio("Group 2", $xPos + 160, $yPos, 70, 20)
		 If NOT $UseApplyButton Then
			GUICtrlSetOnEvent($TMGroupRadio[$UnitNumber][$Group2], "_ChangeSettings")
		 EndIf
		 $yPos = $yPos + 25
		 If $UnitNumber = 3 Then
			$xPos = $xPos + 250
			$yPos = $yPos - 150
		 EndIf
	  Next
	  $TMSwitchDisplayButton = GUICtrlCreateButton("Switch Display", $xPos + 1, $yPos + 3, 80, 25)
	  GUICtrlSetOnEvent($TMSwitchDisplayButton, "_SwitchDisplay")
	  $TMDisplayTypeBox = GUICtrlCreateLabel($CurrentDisplayText, $xPos + 91, $yPos + 8, 120, 15)
   EndIf
   For $UnitNumber = 1 TO 5
	  If $CurrentUnitTMVerified[$UnitNumber] Then
		 $UnitProgress = ""
	  Else
		 $UnitProgress = "*"
	  EndIf
	  GUICtrlSetData($UnitTMProgressDisplay[$UnitNumber], $CurrentUnitTMProgress[$UnitNumber] & " %" & $UnitProgress)
	  GUICtrlSetData($UnitNameDisplay[$UnitNumber], $CurrentUnitName[$UnitNumber])
	  GUICtrlSetData($TMTargetBox[$UnitNumber], $CurrentUnitTMTarget[$UnitNumber])
	  GUICtrlSetState($TMGroupRadio[$UnitNumber][$CurrentUnitTMGroup[$UnitNumber]], $GUI_CHECKED)
   Next
   GUICtrlSetData($TMDisplayTypeBox, $CurrentDisplayText)
   If $FirstRun Then
	  GUISetOnEvent($GUI_EVENT_CLOSE, "_ClosePressed")
	  GUISetState(@SW_SHOW, $GUIHandle)
   EndIf
EndFunc


Func _SwitchDisplay()
   $TmDisplayType = $TMDisplayType + 1
   If $TMDisplayType > 1 Then
	  $TMDisplayType = 0
   EndIf
   _CreateGUI()
EndFunc


Func _ClosePressed()
   $AllowReboot = False
   _Reboot()
EndFunc


Func _HotKeyPause()
   $SimulatedPause = True
   _PausePressed()
EndFunc


Func _ShowPauseMessage()
   If NOT $PauseMessageOn Then
	  GUICtrlSetBkColor($PauseButton, $COLOR_RED)
	  $PausePending = False
	  If $PauseMessage <> "" Then
		 ToolTip($PauseMessage, 50, @DesktopHeight - 460)
	  EndIf
	  $PauseMessageOn = True
   EndIf
   Sleep(1000)
EndFunc


Func _HidePauseMessage()
   If $PauseMessageOn Then
	  GUICtrlSetStyle($PauseButton, $GUI_SS_DEFAULT_BUTTON)
	  ToolTip("")
	  $PauseMessage = ""
	  $PauseMessageOn = False
	  If $NextPlannedAction = "Log Out" OR $NextPlannedAction = "Pause" Then
		 GUICtrlSetBkColor($PauseButton, $COLOR_YELLOW)
	  EndIf
   EndIf
EndFunc


Func _PausePressed()
   Local $ButtonPressed
   $PartyConfirmed = False
   If $SimulatedPause Then
	  $SimulatedPause = False
	  $ButtonPressed = 0
   Else
      $ButtonPressed = @GUI_CtrlId
   EndIf
   If $ButtonPressed = $HomePauseButton Then
	  $NextPlannedAction = "Pause"
	  $ScriptPaused = False
	  $PausePending = True
	  GUICtrlSetBkColor($PauseButton, $COLOR_YELLOW)
   ElseIf $ButtonPressed = $LogOutPauseButton Then
	  $NextPlannedAction = "Log Out"
	  $ScriptPaused = False
	  $PausePending = True
	  GUICtrlSetBkColor($PauseButton, $COLOR_YELLOW)
   Else
	  $ScriptPaused = NOT $ScriptPaused
	  If $ScriptPaused Then
		 $PausePending = True
		 GUICtrlSetBkColor($PauseButton, $COLOR_YELLOW)
		 _StopTMFarm()
	  ElseIf $NextPlannedAction = "Log Out" OR $NextPlannedAction = "Pause" Then	; We have manually unpaused, we don't want to continue these if they were pending when we manually paused
		 $NextPlannedAction = ""
	  EndIf
	  If $PausePending AND NOT $ScriptPaused Then
		 $PausePending = False
		 GUICtrlSetStyle($PauseButton, $GUI_SS_DEFAULT_BUTTON)
	  EndIf
   EndIf
EndFunc


Func _SetTimeBox($TimeVar, $Reset = False)	; The date has to be sent when resetting the control, but not with the initial set
   If $Reset Then
	  If $TimeVar = "OFF" Then
		 Return _DateAdd("n", $DefaultTimeOffset, _NowCalc())
	  Else
		 Return $TimeVar
	  EndIf
   Else
	  If $TimeVar = "OFF" Then
		 Return _GetTimeOnly(_DateAdd("n", $DefaultTimeOffset, _NowCalc()))
	  Else
		 Return _GetTimeOnly($TimeVar)
	  EndIf
   EndIf
EndFunc


Func _ReadTimeCtrl($CtrlHandle)
   GUICtrlSendMsg($CtrlHandle, $DTM_SETFORMATW, 0, $TimeStyleRead)
   Local $TimeValue = GUICtrlRead($CtrlHandle)
   GUICtrlSendMsg($CtrlHandle, $DTM_SETFORMATW, 0, $TimeStyleDisplay)
   Return $TimeValue
EndFunc


Func _GetTimeOnly($DateAndTime)
   Return StringRight($DateAndTime, StringLen($DateAndTime) - StringInStr($DateAndTime, " "))
EndFunc


Func _GetFullDate($TimeOnly, $OrbCheckFormat = False)	; This takes a time in HH:mm:ss format and adds todays date, unless it would be in the past, then it adds tomorrow's date
   If _NowCalcDate() & " " & $TimeOnly > _NowCalc() Then
	  Return _NowCalcDate() & " " & $TimeOnly
   ElseIf $OrbCheckFormat AND _NowCalcDate() & " " & $TimeOnly > _DateAdd("n", $OrbCheckInterval * -1, _NowCalc()) Then 	; Allow up to an orb check in the past and still use today
	  Return _NowCalcDate() & " " & $TimeOnly
   Else
	  Return _DateAdd("d", 1, _NowCalcDate()) & " " & $TimeOnly
   EndIf
EndFunc


Func _ChangeSettings()
   Local $CheckType, $UnitNumber, $CheckUnitNumber, $RadioButton, $MakeChange, $MsgBoxText, $ChangesDetected = False
   Local $CurrentUnitTMTarget, $CurrentUnitTMGroup, $TMTypeText
   For $CheckType = 1 TO $ArrayItems
	  If $Enabled[$CheckType] AND GUICtrlRead($EnabledCheckbox[$CheckType]) = $GUI_UNCHECKED Then
		 $ChangesDetected = True
		 $Enabled[$CheckType] = False
		 If $CheckType = $TMFarm Then
			_StopTMFarm()
		 Else
			GUICtrlSetState($NextOrbTimeBox[$CheckType], $GUI_DISABLE)
		 EndIf
		 IniWrite($IniFile, "Initialize", $FriendlyName[$CheckType] & " Enabled", $Enabled[$CheckType])
	  ElseIf NOT $Enabled[$CheckType] AND GUICtrlRead($EnabledCheckbox[$CheckType]) = $GUI_CHECKED Then
		 $ChangesDetected = True
		 $Enabled[$CheckType] = True
		 If $CheckType <> $TMFarm Then
			$NextOrbCheck[$CheckType] = _NowCalc()
			GUICtrlSetState($NextOrbTimeBox[$CheckType], $GUI_ENABLE)
			GUICtrlSetData($NextOrbTimeBox[$CheckType], _SetTimeBox($NextOrbCheck[$CheckType], True))
		 EndIf
		 IniWrite($IniFile, "Initialize", $FriendlyName[$CheckType] & " Enabled", $Enabled[$CheckType])
	  EndIf
	  If $CheckType = $TMFarm OR $CheckType = $Arena OR $CheckType = $Raid Then		; Only for types that have start/stop time boxes
		 If $StartTime[$CheckType] <> "OFF" AND GUICtrlRead($StartCheckbox[$CheckType]) = $GUI_UNCHECKED Then
			$ChangesDetected = True
			$StartTime[$CheckType] = "OFF"
			IniWrite($IniFile, "Initialize", $FriendlyName[$CheckType] & " Start Time", $StartTime[$CheckType])
		 ElseIf $StartTime[$CheckType] = "OFF" AND GUICtrlRead($StartCheckbox[$CheckType]) = $GUI_CHECKED Then
			$ChangesDetected = True
			$StartTime[$CheckType] = _GetFullDate(_ReadTimeCtrl($StartTimeBox[$CheckType]))
			IniWrite($IniFile, "Initialize", $FriendlyName[$CheckType] & " Start Time", $StartTime[$CheckType])
		 ElseIf $StartTime[$CheckType] <> "OFF" AND $StartTime[$CheckType] <> _GetFullDate(_ReadTimeCtrl($StartTimeBox[$CheckType])) Then
			$ChangesDetected = True
			$StartTime[$CheckType] = _GetFullDate(_ReadTimeCtrl($StartTimeBox[$CheckType]))
			IniWrite($IniFile, "Initialize", $FriendlyName[$CheckType] & " Start Time", $StartTime[$CheckType])
		 EndIf
		 If $StopTime[$CheckType] <> "OFF" AND GUICtrlRead($StopCheckbox[$CheckType]) = $GUI_UNCHECKED Then
			$ChangesDetected = True
			$StopTime[$CheckType] = "OFF"
			IniWrite($IniFile, "Initialize", $FriendlyName[$CheckType] & " Stop Time", $StopTime[$CheckType])
		 ElseIf $StopTime[$CheckType] = "OFF" AND GUICtrlRead($StopCheckbox[$CheckType]) = $GUI_CHECKED Then
			$ChangesDetected = True
			$StopTime[$CheckType] = _GetFullDate(_ReadTimeCtrl($StopTimeBox[$CheckType]))
			IniWrite($IniFile, "Initialize", $FriendlyName[$CheckType] & " Stop Time", $StopTime[$CheckType])
		 ElseIf $StopTime[$CheckType] <> "OFF" AND $StopTime[$CheckType] <> _GetFullDate(_ReadTimeCtrl($StopTimeBox[$CheckType])) Then
			$ChangesDetected = True
			$StopTime[$CheckType] = _GetFullDate(_ReadTimeCtrl($StopTimeBox[$CheckType]))
			IniWrite($IniFile, "Initialize", $FriendlyName[$CheckType] & " Stop Time", $StopTime[$CheckType])
		 EndIf
	  EndIf
	  If $CheckType = $TMFarm Then
		 If $Dalnakya AND GUICtrlRead($DalnakyaCheckbox) = $GUI_UNCHECKED Then
			$ChangesDetected = True
			$Dalnakya = False
			_SetTMVars()
			IniWrite($IniFile, "Initialize", "Dalnakya", $Dalnakya)
		 ElseIf NOT $Dalnakya AND GUICtrlRead($DalnakyaCheckbox) = $GUI_CHECKED Then
			$ChangesDetected = True
			$Dalnakya = True
			_SetTMVars()
			IniWrite($IniFile, "Initialize", "Dalnakya", $Dalnakya)
		 EndIf
	  Else
		 If $Enabled[$CheckType] AND $NextOrbCheck[$CheckType] <> _GetFullDate(_ReadTimeCtrl($NextOrbTimeBox[$CheckType]), True) Then
			If $NextOrbCheck[$CheckType] = _DateAdd("D", 1, _GetFullDate(_ReadTimeCtrl($NextOrbTimeBox[$CheckType]), True)) Then	; Orb time has passed and needs to be set to now
			   GUICtrlSetData($NextOrbTimeBox[$CheckType], _NowCalc())
			   $NextOrbCheck[$CheckType] = _GetFullDate(_ReadTimeCtrl($NextOrbTimeBox[$CheckType]), True)
			EndIf
			If _GetFullDate(_ReadTimeCtrl($NextOrbTimeBox[$CheckType]), True) > _DateAdd("n", 180, _NowCalc()) Then
			   GUICtrlSetData($NextOrbTimeBox[$CheckType], _NowCalc())
			   $NextOrbCheck[$CheckType] = _GetFullDate(_ReadTimeCtrl($NextOrbTimeBox[$CheckType]), True)
			EndIf
			$ChangesDetected = True
			$NextOrbCheck[$CheckType] = _GetFullDate(_ReadTimeCtrl($NextOrbTimeBox[$CheckType]), True)
			GUICtrlSetData($NextOrbTimeBox[$CheckType], _SetTimeBox($NextOrbCheck[$CheckType], True))
		 EndIf
	  EndIf
   Next
   Switch $TMDisplayType
	  Case 0	; TM farming party
		 $CurrentUnitTMTarget = $UnitTMTarget
		 $CurrentUnitTMGroup = $UnitTMGroup
		 $TMTypeText = ""
	  Case 1	; TM expedition party
		 $CurrentUnitTMTarget = $UnitTMExpeditionTarget
		 $CurrentUnitTMGroup = $UnitTMExpeditionGroup
		 $TMTypeText = " Expedition"
   EndSwitch
   For $UnitNumber = 1 TO 5
	  For $RadioButton = 0 TO 2
		 If GUICtrlRead($TMGroupRadio[$UnitNumber][$RadioButton]) = $GUI_CHECKED Then
			If $CurrentUnitTMGroup[$UnitNumber] <> $RadioButton Then
			   $ChangesDetected = True
			   $CurrentUnitTMGroup[$UnitNumber] = $RadioButton
			   IniWrite($IniFile, "Initialize", "Unit " & $UnitNumber & $TMTypeText & " TM Group", $CurrentUnitTMGroup[$UnitNumber])
			EndIf
		 EndIf
	  Next
   Next
   For $UnitNumber = 1 TO 5
	  If $CurrentUnitTMTarget[$UnitNumber] <> GUICtrlRead($TMTargetBox[$UnitNumber]) Then
		 If GUICtrlRead($TMTargetBox[$UnitNumber]) > 100 OR GUICtrlRead($TMTargetBox[$UnitNumber]) < 0 Then		; Out of range 0-100, force to default of 100
			GUICtrlSetData($TMTargetBox[$UnitNumber], 100)
		 EndIf
		 $ChangesDetected = True
		 $CurrentUnitTMTarget[$UnitNumber] = GUICtrlRead($TMTargetBox[$UnitNumber])
		 IniWrite($IniFile, "Initialize", "Unit " & $UnitNumber & $TMTypeText & " TM Target", $CurrentUnitTMTarget[$UnitNumber])
	  EndIf
	  For $CheckUnitNumber = 1 TO 5
		 If $CurrentUnitTMGroup[$CheckUnitNumber] = $CurrentUnitTMGroup[$UnitNumber] AND $CurrentUnitTMGroup[$UnitNumber] <> $NoGroup AND $CheckUnitNumber <> $UnitNumber Then
			$ChangesDetected = True
			$CurrentUnitTMTarget[$CheckUnitNumber] = $CurrentUnitTMTarget[$UnitNumber]
			GUICtrlSetData($TMTargetBox[$CheckUnitNumber], $CurrentUnitTMTarget[$CheckUnitNumber])
			IniWrite($IniFile, "Initialize", "Unit " & $CheckUnitNumber & $TMTypeText & " TM Target", $CurrentUnitTMTarget[$CheckUnitNumber])
		 EndIf
	  Next
   Next
   Switch $TMDisplayType	; Write temporary variables back into the main ones so changes are kept
	  Case 0	; TM farming party
		 $UnitTMTarget = $CurrentUnitTMTarget
		 $UnitTMGroup = $CurrentUnitTMGroup
	  Case 1	; TM expedition party
		 $UnitTMExpeditionTarget = $CurrentUnitTMTarget
		 $UnitTMExpeditionGroup = $CurrentUnitTMGroup
   EndSwitch
   If $UseApplyButton Then
	  If $ChangesDetected Then
		 MsgBox(64, $ScriptName & $ScriptVersion, "New settings applied", 5)	; Currently seems to always detect changes even when there aren't any
	  Else
		 MsgBox(64, $ScriptName & $ScriptVersion, "NO CHANGES DETECTED", 5)
	  EndIf
   EndIf
EndFunc


Func _ChangeCheckbox()
   Local $BoxChanged = @GUI_CtrlId, $CheckType
   For $CheckType = 1 TO $ArrayItems
	  If $BoxChanged = $StartCheckbox[$CheckType] Then
		 $StartTime[$CheckType] = _DateAdd("h", 2, _NowCalc())
		 GUICtrlSetData($StartTimeBox[$CheckType], _SetTimeBox($StartTime[$CheckType], True))
		 If GUICtrlRead($StartCheckbox[$CheckType]) = $GUI_UNCHECKED Then
			GUICtrlSetState($StartTimeBox[$CheckType], $GUI_DISABLE)
		 Else
			GUICtrlSetState($StartTimeBox[$CheckType], $GUI_ENABLE)
		 EndIf
	  ElseIf $BoxChanged = $StopCheckbox[$CheckType] Then
		 $StopTime[$CheckType] = _DateAdd("h", 2, _NowCalc())
		 GUICtrlSetData($StopTimeBox[$CheckType], _SetTimeBox($StopTime[$CheckType], True))
		 If GUICtrlRead($StopCheckbox[$CheckType]) = $GUI_UNCHECKED Then
			GUICtrlSetState($StopTimeBox[$CheckType], $GUI_DISABLE)
		 Else
			GUICtrlSetState($StopTimeBox[$CheckType], $GUI_ENABLE)
		 EndIf
	  EndIf
   Next
   If NOT $UseApplyButton Then
	  _ChangeSettings()
   EndIf
EndFunc


Func _OldPausePressed()
   Local $Message, $Message2 = "", $MsgBoxType, $TMFarming = False
   If $SimulatedPause Then
	  $SimulatedPause = False
	  Local $ButtonPressed = 0
   Else
      Local $ButtonPressed = @GUI_CtrlId
   EndIf
   If $FastTMFarm <> "OFF" Then
	  $TMFarming = True
	  _StopTMFarm()
   EndIf
   If $PLIADetected Then
	  $Message2 = "Please log in detected" & @CRLF & @CRLF
	  $PLIADetected = False
	  $TMFarming = False	; We would never want to restart Fast TM Farm in this situation
   EndIf
   If $ButtonPressed = $HomePauseButton Then
	  $NextPlannedAction = "Pause"
   ElseIf $ButtonPressed = $LogOutPauseButton Then
	  $NextPlannedAction = "Log Out"
   Else
	  If $TMFarming Then
		 $MsgBoxType = $MB_YESNOCANCEL + $MB_ICONQUESTION
		 $Message = "Do you want to restart Fast TM Farm? (Cancel to quit)"
	  Else
		 $MsgBoxType = $MB_OKCANCEL + $MB_ICONINFORMATION
		 $Message = "Press OK to unpause or Cancel to quit"
	  EndIf
	  Switch MsgBox($MsgBoxType, "FFBE Macro - PAUSED", $Message2 & $Message)
		 Case $IDCANCEL
			$AllowReboot = False
			_Reboot()
		 Case $IDYES
			_StartTMFarm()
		 Case $IDNO, $IDOK
			; No action required
	  EndSwitch
;	  $ScriptPaused = True
;	  ToolTip($Message2 & "Script is paused, press Pause/Unpause to continue...", 50, @DesktopHeight - 460)
;	  While $ScriptPaused
;		 Sleep(100)
;	  WEnd
;	  ToolTip("")
   EndIf
EndFunc


Func _SetTMVars()
   If $Dalnakya Then
	  $WorldClickTM = $WorldClickDalnakya
	  $TMSelect = $DalnakyaSelect
	  $TMBattle = $DalnakyaCavern1
	  $TMNextButton = $DalnakyaNextButton
	  $TMFriend = $DalnakyaFriend
	  $TMDepartButton = $DalnakyaDepartButton
	  $TMInBattle = $DalnakyaInBattle1
   Else
	  $WorldClickTM = $WorldClickES
	  $TMSelect = $ESSelect
	  $TMBattle = $ESEntrance
	  $TMNextButton = $ESNextButton
	  $TMFriend = $ESFriend
	  $TMDepartButton = $ESDepartButton
	  $TMInBattle = $ESInBattle
   EndIf
EndFunc


Func _SetScreenOrientation()
   Local $tDevMode, $aRet, $v
   $tDevMode = DllStructCreate($tagDEVMODE_DISPLAY)
   DllStructSetData($tDevMode, 'Size', DllStructGetSize($tDevMode))
   DllStructSetData($tDevMode, 'DriverExtra', 0)
   $aRet = DllCall('user32.dll', 'bool', 'EnumDisplaySettingsW', 'ptr', 0, 'dword', $ENUM_CURRENT_SETTINGS, 'struct*', $tDevMode)
   If @error Or Not $aRet[0] Then
	  Return False
   EndIf
   ; Flip orientation, but also switch width/height.
   $tDevMode.Fields = BitOR($tDevMode.Fields, $DM_DISPLAYORIENTATION)
   $tDevMode.DisplayOrientation = $DMDO_90
   $v = $tDevMode.PelsWidth
   $tDevMode.PelsWidth = $tDevMode.PelsHeight
   $tDevMode.PelsHeight = $v
   $aRet = DllCall("user32.dll", "LONG", "ChangeDisplaySettingsW", "ptr", DllStructGetPtr($tDevMode), "DWORD", 0)
   If @error Then
	  Return False
   Else
	  Return True
   EndIf
EndFunc


Func _Initialize()
   Local $CheckType, $UnitNumber, $ExpeditionData, $ExpeditionNumber, $MaterialData, $MaterialNumber
   _GetSetting("EmulatorName", $EmulatorName)
   _GetSetting("EmulatorEXE", $EmulatorEXE)
   _GetSetting("AllowReboot", $AllowReboot)
   For $CheckType = 1 TO $ArrayItems
	  _GetSetting($FriendlyName[$CheckType] & " Enabled", $Enabled[$CheckType])
	  _GetSetting($FriendlyName[$CheckType] & " Start Time", $StartTime[$CheckType])
	  _CheckForTime()	; Make sure we haven't already passed the time we just read
	  _GetSetting($FriendlyName[$CheckType] & " Stop Time", $StopTime[$CheckType])
	  _CheckForTime()	; Make sure we haven't already passed the time we just read
   Next
   For $UnitNumber = 1 TO 5
	  _GetSetting("Unit " & $UnitNumber, $UnitName[$UnitNumber])
	  _GetSetting("Unit " & $UnitNumber & " TM", $UnitTMProgress[$UnitNumber])
	  _GetSetting("Unit " & $UnitNumber & " TM Group", $UnitTMGroup[$UnitNumber])
	  _GetSetting("Unit " & $UnitNumber & " TM Target", $UnitTMTarget[$UnitNumber])
;	  $UnitTMProgress[$UnitNumber] = StringReplace(StringStripWS($UnitTMProgress[$UnitNumber], 8), "%", "")
	  _GetSetting("Unit " & $UnitNumber & " Expedition TM", $UnitTMExpeditionProgress[$UnitNumber])
	  _GetSetting("Unit " & $UnitNumber & " Expedition TM Group", $UnitTMExpeditionGroup[$UnitNumber])
	  _GetSetting("Unit " & $UnitNumber & " Expedition TM Target", $UnitTMExpeditionTarget[$UnitNumber])
   Next
   _GetSetting("LoggingLevel", $LoggingLevel)
   _GetSetting("Text Email Address", $TextEmailAddress)
   _GetSetting("Standard Email Address", $StandardEmailAddress)
   _GetSetting("Gmail Account", $GmailAccount)
   _GetSetting("Gmail Password", $GmailPassword)
   _GetSetting("Dalnakya", $Dalnakya)
   _GetSetting("Maintenance Start Day", $MaintenanceStartDay)
   _GetSetting("Maintenance Start Hour", $MaintenanceStartHour)
   _GetSetting("Weekly Reset Day", $WeeklyResetDay)
   _GetSetting("Daily Reset Hour", $DailyResetHour)
   _GetSetting("Preserve Arena Orbs", $PreserveArenaOrbs)
   _GetSetting("Continue On PLIA", $ContinueOnPLIA)
   _GetSetting("Allow Auto Sell", $AllowAutoSell)
   _GetSetting("Arena Weekly Stop", $ArenaWeeklyStop)
   _GetSetting("Last Arena Weekly Stop Time", $LastArenaWeeklyStopTime)
   _GetSetting("Last Fatal Error Email", $LastFatalErrorEmail)
   _GetSetting("Last Ancient Coin", $LastAncientCoin)
   _GetSetting("Allow Ancient Coins", $AllowAncientCoins)
   $ExpeditionNumber = 1
   While $InfiniteLoop
	  If _GetSetting($ExpeditionNumber, $ExpeditionData, "Expeditions") Then
		 If StringInStr($ExpeditionData, ",") > 0 Then
			ReDim $ExpeditionList[$ExpeditionNumber + 1][$ExpeditionSpots]
			$ExpeditionList[0][0] = $ExpeditionNumber
			If StringLower(StringLeft($ExpeditionData, 5)) = "true," Then
			   $ExpeditionList[$ExpeditionNumber][$ExpeditionAllowItem] = True
			   $ExpeditionList[$ExpeditionNumber][$ExpeditionTM] = False
			   $ExpeditionData = StringTrimLeft($ExpeditionData, 5)
			ElseIf StringLower(StringLeft($ExpeditionData, 6)) = "false," Then
			   $ExpeditionList[$ExpeditionNumber][$ExpeditionAllowItem] = False
			   $ExpeditionList[$ExpeditionNumber][$ExpeditionTM] = False
			   $ExpeditionData = StringTrimLeft($ExpeditionData, 6)
			Else	; Anything other than True or False will be treated as a marker for a TM expedition
			   $ExpeditionList[$ExpeditionNumber][$ExpeditionAllowItem] = False
			   $ExpeditionList[$ExpeditionNumber][$ExpeditionTM] = True
			   $ExpeditionData = StringTrimLeft($ExpeditionData, StringInStr($ExpeditionData, ","))
			EndIf
			$ExpeditionList[$ExpeditionNumber][$ExpeditionName] = StringStripWS($ExpeditionData, 8)
		 Else
			ExitLoop
		 EndIf
	  Else
		 ExitLoop
	  EndIf
	  $ExpeditionNumber = $ExpeditionNumber + 1
   WEnd
   _GetSetting("Last Acceptable Expedition", $LastAcceptableExpedition, "Expeditions")
   $MaterialNumber = 1
   While $InfiniteLoop
	  If _GetSetting($MaterialNumber, $MaterialData, "Materials") Then
;		 $MaterialData = StringLower(StringStripWS($MaterialData, 8))		; Strip all while space and force lower case, this will match how we compare it later
		 $MaterialData = StringStripWS($MaterialData, 3)		; Strip leading and trailing while space
		 If StringInStr($MaterialData, ",") > 0 Then
			ReDim $MaterialsList[$MaterialNumber + 1][$MaterialsSpots]
			$MaterialsList[0][0] = $MaterialNumber
			$MaterialsList[$MaterialNumber][$SaveStacks] = StringRight($MaterialData, 1)	; We only support saving up to 9 stacks of a material
			While $InfiniteLoop
			   $MaterialData = StringLeft($MaterialData, StringLen($MaterialData) - 1)
			   If StringRight($MaterialData, 1) = "," OR StringLen($MaterialData) < 2 Then
				  $MaterialData = StringLeft($MaterialData, StringLen($MaterialData) - 1)
				  ExitLoop
			   EndIf
			WEnd
			$MaterialsList[$MaterialNumber][$MaterialDescription] = $MaterialData
		 Else
			ExitLoop
		 EndIf
	  Else
		 ExitLoop
	  EndIf
	  $MaterialNumber = $MaterialNumber + 1
   WEnd
   _SetTMVars()
   If @DesktopHeight < 900 AND @DesktopHeight < @DesktopWidth Then	; Low-resolution laptop screens need to be set to portrait mode and may not be correct when rebooting
;	  _SetScreenOrientation()	; Disabled for now
   EndIf
EndFunc


Func _GetSetting($SettingName, byRef $Setting, $SettingSection = "Initialize")
   Local $DataRead, $OriginalSetting = $Setting
   $DataRead = IniRead($IniFile, $SettingSection, $SettingName, "ERROR")
   If $DataRead <> "ERROR" Then
	  $Setting = StringStripWS($DataRead, 3)
	  If StringLower($Setting) = "true" Then
		 $Setting = True
	  ElseIf StringLower($Setting) = "false" Then
		 $Setting = False
	  EndIf
	  If $Setting <> $OriginalSetting Then
		 _AddToLog(1, $SettingName & " changed by config file to " & $Setting)
		 If $SettingSection <> "Initialize" AND $SettingSection <> "Expeditions" AND $SettingSection <> "Materials" Then	; Remove settings after they are read as these will be temporary settings
			IniDelete($IniFile, $SettingSection, $SettingName)
		 EndIf
		 Return True
	  EndIf
   EndIf
   Return False
EndFunc


Func _MainScript()
   Local $Disabled = False, $CurrentLocation, $CheckType
   If $CurrentAction = $Inactive Then
	  For $CheckType = 1 TO $ArrayItems
		 If $Enabled[$CheckType] Then
			$CurrentAction = $CheckType	; This will hold the last item that matches, so the highest number has the highest priority
		 EndIf
	  Next
   EndIf
   While $InfiniteLoop
	  GUICtrlSetData($DebugBox, "_MainScript " & $CurrentAction)
	  If NOT $Disabled AND NOT $ScriptPaused Then
		 _HidePauseMessage()
		 If $NextPlannedAction = "" Then
			$CurrentLocation = _WhereAmI("Everything")
			Switch $CurrentAction
			   Case $Raid
				  Switch $CurrentLocation
					 Case $HomeScreen
						_Click(160, 550)	; Vortex
					 Case $VortexMainPage, $RaidInBattle, $RaidFriendPage, $TMFriend, $RaidBattleSelectionPage, $RaidTitle, $RaidDepartPage
						; No action required, these are a placeholder for things that don't need _GetHomeScreen()
					 Case Else
						If NOT _GetHomeScreen() Then
						   _FatalError("_MainScript - Unable to get home screen")
						EndIf
				  EndSwitch
				  If _UseRaidOrbs() Then
					 If (@WDAY = $MaintenanceStartDay AND @HOUR = $MaintenanceStartHour - 1) OR (@WDAY = $MaintenanceStartDay - 1 AND @HOUR = 23 AND $MaintenanceStartHour = 0) Then
						$NextOrbCheck[$Raid] = _DateAdd("n", 5, _NowCalc())		; Next check in 5 minutes, we are within an hour of maintenance
					 Else
						$NextOrbCheck[$Raid] = _DateAdd("n", $OrbCheckInterval, _NowCalc())
					 EndIf
					 GUICtrlSetData($NextOrbTimeBox[$Raid], _SetTimeBox($NextOrbCheck[$Raid], True))
				  EndIf
			   Case $Arena
				  Switch $CurrentLocation
					 Case $HomeScreen
						_Click(75, 775)		; Arena
					 Case $ArenaInBattle, $ArenaMainPage & "0", $ArenaMainPage & "1", $ArenaRulesPage & "0", $ArenaRulesPage & "1", $ArenaSelectionPage
						; No action required, these are a placeholder for things that don't need _GetHomeScreen()
					 Case Else
						If NOT _GetHomeScreen() Then
						   _FatalError("_MainScript - Unable to get home screen")
						EndIf
				  EndSwitch
				  If _UseArenaOrbs() Then
					 If (@WDAY = $MaintenanceStartDay AND @HOUR = $MaintenanceStartHour - 1) OR (@WDAY = $MaintenanceStartDay - 1 AND @HOUR = 23 AND $MaintenanceStartHour = 0) Then
						$NextOrbCheck[$Arena] = _DateAdd("n", 5, _NowCalc())	; Next check in 5 minutes, we are within an hour of maintenance
					 Else
						$NextOrbCheck[$Arena] = _DateAdd("n", $OrbCheckInterval, _NowCalc())
					 EndIf
					 GUICtrlSetData($NextOrbTimeBox[$Arena], _SetTimeBox($NextOrbCheck[$Arena], True))
				  EndIf
			   Case $Expeditions
				  Switch $CurrentLocation
					 Case $HomeScreen
						_Click(480, 780)		; Expeditions
					 Case $ExpeditionsScreen, $ExpeditionsScreen2, $ExpeditionsRewardScreen, $ExpeditionsRewardScreen2
						; No action required, these are a placeholder for things that don't need _GetHomeScreen()
					 Case Else
						If NOT _GetHomeScreen() Then
						   _FatalError("_MainScript - Unable to get home screen")
						EndIf
				  EndSwitch
				  _HandleExpeditions()		; We don't currently care whether this was succesful, either way we are resetting the orb check
				  $NextOrbCheck[$Expeditions] = _DateAdd("n", $OrbCheckInterval, _NowCalc())
				  GUICtrlSetData($NextOrbTimeBox[$Expeditions], _SetTimeBox($NextOrbCheck[$Expeditions], True))
			   Case $AdWheel
				  Switch $CurrentLocation
					 Case $HomeScreen
						_Click(70, 200)		; Home screen shortcut to rewards wheel
					 Case $RewardsWheelPage, $RewardsWheelReady
						; No action required, these are a placeholder for things that don't need _GetHomeScreen()
					 Case Else
						If NOT _GetHomeScreen() Then
						   _FatalError("_MainScript - Unable to get home screen")
						EndIf
				  EndSwitch
				  If _HandleAdWheel() Then
					 $NextOrbCheck[$AdWheel] = _DateAdd("n", 20, _NextDailyReset())
					 GUICtrlSetData($NextOrbTimeBox[$AdWheel], _SetTimeBox($NextOrbCheck[$AdWheel], True))
				  ElseIf _DateAdd("h", 6, _NowCalc()) > _NextDailyReset() and _NextDailyReset() > _NowCalc() AND _DateAdd("h", 1, $LastFatalErrorEmail) < _NowCalc() AND $AllowReboot Then
					 _FatalError("Rebooting to try to get more ads")
				  Else
					 $NextOrbCheck[$AdWheel] = _DateAdd("n", $OrbCheckInterval, _NowCalc())
					 GUICtrlSetData($NextOrbTimeBox[$AdWheel], _SetTimeBox($NextOrbCheck[$AdWheel], True))
				  EndIf
			   Case $DailyEP
				  Switch $CurrentLocation
					 Case $HomeScreen
						_Click(160, 550)		; Vortex
					 Case $VortexMainPage
						; No action required, these are a placeholder for things that don't need _GetHomeScreen()
					 Case Else
						If NOT _GetHomeScreen() Then
						   _FatalError("_MainScript - Unable to get home screen")
						EndIf
				  EndSwitch
				  _DailyEnlightenment()
				  $NextOrbCheck[$DailyEP] = _DateAdd("n", $OrbCheckInterval, _NowCalc())
				  GUICtrlSetData($NextOrbTimeBox[$DailyEP], _SetTimeBox($NextOrbCheck[$DailyEP], True))
			   Case $ClaimDailies
				  Switch $CurrentLocation
					 Case $HomeScreen
						_Click(165, 200)		; Daily Quests
					 Case $DailyQuestScreen
						; No action required, these are a placeholder for things that don't need _GetHomeScreen()
					 Case Else
						If NOT _GetHomeScreen() Then
						   _FatalError("_MainScript - Unable to get home screen")
						EndIf
				  EndSwitch
				  _ClaimDailyQuests()
				  $NextOrbCheck[$ClaimDailies] = _DateAdd("n", $OrbCheckInterval, _NowCalc())
				  GUICtrlSetData($NextOrbTimeBox[$ClaimDailies], _SetTimeBox($NextOrbCheck[$ClaimDailies], True))
			   Case $RaidSummons
				  Switch $CurrentLocation
					 Case $RaidSummonScreen
						$HandleFallout = MsgBox(35, $ScriptName, "Automatically fuse cactuars and sell gil snappers when done?", 60)
						If $HandleFallout = $IDCANCEL OR $HandleFallout = $IDTIMEOUT Then
						   $Enabled[$RaidSummons] = False
						   $NextOrbCheck[$RaidSummons] = "OFF"
						EndIf
						If $HandleFallOut = $IDYES Then	; In case we fail and end up rebooting, set the .ini file settings so we will handle the fallout automatically
						   IniWrite($IniFile, "Initialize", $FriendlyName[$SellSnappers] & " Enabled", True)
						   IniWrite($IniFile, "Initialize", $FriendlyName[$CactuarFusion] & " Enabled", True)
						   GUICtrlSetState($EnabledCheckbox[$SellSnappers], $GUI_CHECKED)
						   GUICtrlSetState($EnabledCheckbox[$CactuarFusion], $GUI_CHECKED)
						EndIf
						If _RaidSummons() Then
						   $Enabled[$RaidSummons] = False	; This is a one-time run item, turn it off once it is finished
						   $NextOrbCheck[$RaidSummons] = "OFF"
						   If $HandleFallOut = $IDYES Then
							  $Enabled[$SellSnappers] = True
							  $Enabled[$CactuarFusion] = True
							  $NextOrbCheck[$SellSnappers] = _NowCalc()
							  $NextOrbCheck[$CactuarFusion] = _NowCalc()
							  IniWrite($IniFile, "Initialize", $FriendlyName[$SellSnappers] & " Enabled", $Enabled[$SellSnappers])
							  IniWrite($IniFile, "Initialize", $FriendlyName[$CactuarFusion] & " Enabled", $Enabled[$CactuarFusion])
							  GUICtrlSetState($EnabledCheckbox[$SellSnappers], $GUI_CHECKED)
							  GUICtrlSetState($EnabledCheckbox[$CactuarFusion], $GUI_CHECKED)
							  GUICtrlSetState($NextOrbTimeBox[$SellSnappers], $GUI_ENABLE)
							  GUICtrlSetData($NextOrbTimeBox[$SellSnappers], _SetTimeBox($StartTime[$SellSnappers], True))
							  GUICtrlSetState($NextOrbTimeBox[$CactuarFusion], $GUI_ENABLE)
							  GUICtrlSetData($NextOrbTimeBox[$CactuarFusion], _SetTimeBox($StartTime[$CactuarFusion], True))
						   EndIf
						ElseIf $Enabled[$RaidSummons] Then
						   $Enabled[$RaidSummons] = False	; This is a one-time run item, turn it off once it is finished
						   $NextOrbCheck[$RaidSummons] = "OFF"
						   _SendMail("Raid summons failed")
						EndIf
					 Case Else
						If _GetHomeScreen() Then
						   MsgBox(64, $ScriptName, "Please get the raid summon screen up and unpause the script")
						   _PausePressed()
						Else
						   _FatalError("_MainScript: Unable to get home screen for raid summons")
						EndIf
				  EndSwitch
			   Case $SendGifts
				  Switch $CurrentLocation
					 Case $HomeScreen
						_Click(530, 1000)		; Friends
					 Case $InfiniteLoop
						; No action required, these are a placeholder for things that don't need _GetHomeScreen()
					 Case Else
						If NOT _GetHomeScreen() Then
						   _FatalError("_MainScript - Unable to get home screen")
						EndIf
				  EndSwitch
				  _SendFriendGifts()
				  $NextOrbCheck[$SendGifts] = _DateAdd("n", $OrbCheckInterval, _NowCalc())
				  GUICtrlSetData($NextOrbTimeBox[$SendGifts], _SetTimeBox($NextOrbCheck[$SendGifts], True))
			   Case $SellMaterials
				  _SellMaterials()
				  $Enabled[$SellMaterials] = False	; This is a one-time run item, turn it off once it is finished
				  $NextOrbCheck[$SellMaterials] = "OFF"
				  GUICtrlSetState($EnabledCheckbox[$SellMaterials], $GUI_UNCHECKED)
				  IniWrite($IniFile, "Initialize", $FriendlyName[$SellMaterials] & " Enabled", $Enabled[$SellMaterials])
			   Case $CactuarFusion
				  _CactuarFusion()
				  $Enabled[$CactuarFusion] = False	; This is a one-time run item, turn it off once it is finished
				  $NextOrbCheck[$CactuarFusion] = "OFF"
				  GUICtrlSetState($EnabledCheckbox[$CactuarFusion], $GUI_UNCHECKED)
				  IniWrite($IniFile, "Initialize", $FriendlyName[$CactuarFusion] & " Enabled", $Enabled[$CactuarFusion])
			   Case $SellSnappers
				  _SellSnappers()
				  $Enabled[$SellSnappers] = False
				  $NextOrbCheck[$SellSnappers] = "OFF"
				  GUICtrlSetState($EnabledCheckbox[$SellSnappers], $GUI_UNCHECKED)
				  IniWrite($IniFile, "Initialize", $FriendlyName[$SellSnappers] & " Enabled", $Enabled[$SellSnappers])
			   Case $TMFarm
				  Switch $CurrentLocation
					 Case $HomeScreen
						_Click(300, 775)	; World
					 Case $TMInBattle, $WorldMainPage, $WorldMapGrandshelt, $WorldMapGrandsheltIsles, $TMSelect, $TMBattle & "1", $TMBattle & "2", $TMFriend, $RaidFriendPage
						; No action required, these are a placeholder for things that don't need _GetHomeScreen()
					 Case Else
						If NOT _GetHomeScreen() Then
						   _FatalError("_MainScript - Unable to get home screen")
						EndIf
				  EndSwitch
				  _TMFarm()
			   Case $Inactive
				  If $CurrentLocation <> $HomeScreen Then
					 If NOT _GetHomeScreen() Then
						_FatalError("_MainScript - Unable to get home screen")
					 EndIf
				  EndIf
				  For $CheckType = 1 TO $ArrayItems
					 If $CheckType <> $TMFarm Then
						If $Enabled[$CheckType] Then
						   If _DateAdd("n", Int($OrbCheckInterval / 4) * 3, _NowCalc()) > $NextOrbCheck[$CheckType] Then	; We are idle and 1/4 of the way to an orb check, check it now
							  $NextOrbCheck[$CheckType] = _NowCalc()
							  GUICtrlSetData($NextOrbTimeBox[$CheckType], _SetTimeBox($NextOrbCheck[$CheckType], True))
						   EndIf
						EndIf
					 EndIf
				  Next
				  Sleep(1000)
				  MsgBox(64, $ScriptName & $ScriptVersion, "Waiting for something to do...", 2)
				  Sleep(2000)
			EndSwitch
		 EndIf
		 Switch $NextPlannedAction
			Case $Raid, $Arena, $TMFarm, $AdWheel, $Expeditions, $ClaimDailies, $SendGifts, $CactuarFusion, $SellMaterials, $SellSnappers
			   $CurrentAction = $NextPlannedAction
			   $NextPlannedAction = ""
			Case "Pause", "Log Out"
			   If _GetHomeScreen() Then
				  If $NextPlannedAction = "Log Out" Then
					 _Click(530, 200)
					 Sleep(2000)
					 _Click(470, 255)
					 Sleep(2000)
					 _Click(400, 600)
				  EndIf
				  $NextPlannedAction = ""
				  $CurrentAction = $Inactive
				  $SimulatedPause = True
				  _PausePressed()
				  For $CheckType = 1 TO $ArrayItems
					 If (_NowCalc() > $NextOrbCheck[$CheckType] OR $CheckType = $TMFarm) AND $Enabled[$CheckType] Then
						$CurrentAction = $CheckType		; This will hold the last item that matches, so the highest number has the highest priority
					 EndIf
				  Next
			   Else
				  _FatalError("_MainScript - Unable to get home screen")
			   EndIf
			Case Else
			   _CheckForTime()
			   $CurrentAction = $Inactive
			   For $CheckType = 1 TO $ArrayItems
				  If (_NowCalc() > $NextOrbCheck[$CheckType] OR $CheckType = $TMFarm) AND $Enabled[$CheckType] Then	; We reached the orb check time or tm farm is enabled
					 $CurrentAction = $CheckType		; This will hold the last item that matches, so the highest number has the highest priority
				  EndIf
			   Next
			   $NextPlannedAction = ""
		 EndSwitch
;		 $Disabled = _CheckForDisableTime("StopTime")
		 If $AllowReboot AND NOT WinExists($EmulatorName, "") Then  ; The emulator is not running when it should be, this is a good reason to reboot the computer if we are allowed to
			_Reboot()
		 EndIf
	  ElseIf $ScriptPaused Then
		 _ShowPauseMessage()
	  Else	; We are in disabled mode, we are not allowed to do anything
		 ; Check for a restart time, restart if we have reached it
	  EndIf
   WEnd
EndFunc


Func _StartRaidSummons()
   $Enabled[$RaidSummons] = NOT $Enabled[$RaidSummons]
   If $Enabled[$RaidSummons] Then
	  $NextOrbCheck[$RaidSummons] = _NowCalc()
   Else
	  $NextOrbCheck[$RaidSummons] = "OFF"
   EndIf
EndFunc


Func _RaidSummons()
   Local $LoopCounter, $ConnectionErrorCount
   While $InfiniteLoop
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_RaidSummons")
		 If _CheckForInterrupt($RaidSummons) Then
			Return False
		 EndIf
		 Switch _WhereAmI($RaidSummons)
			Case $HomeScreen
			   Return False	; We are stuck, we are not scripting access to the raid banner because it will change with every raid
			Case $RaidSummonConfirm
			   _Click(60, 240)	; Back button, we shouldn't be on this screen at this point
			   Sleep(1000)
			Case $RaidSummonScreen
			   _Click(520, 720)	; Multi-Summon, if it is there, nothing if it isn't
			   Sleep(2000)
			   If _CheckForImage($RaidSummonConfirm, $x, $y) Then
				  _Click(300, 600)	; Multi-Summon
				  $LoopCounter = 0
				  $ConnectionErrorCount = 0
				  While $InfiniteLoop
					 _Click(300, 100)	; Safe click area to keep things moving
					 Sleep(1000)
					 If _CheckForImage($RaidSummonNextButton, $x, $y) Then
						_Click(300, 940)	; Next button
					 ElseIf _CheckForImage($RaidSummonNextButton2, $x, $y) Then
						_Click(300, 940)	; Next button
					 ElseIf _CheckForImage($RaidSummonNextButton3, $x, $y) Then	; This is when the unit list is short
						_Click(300, 860)	; Next button
					 ElseIf _CheckForImage($RaidSummonNextButton4, $x, $y) Then	; This is when the unit list is short
						_Click(300, 860)	; Next button
					 ElseIf _CheckForImage($RaidSummonScreen, $x, $y) Then
						ExitLoop
					 ElseIf _CheckForImage($ConnectionError, $x, $y) Then
						_Click(300, 630) ; OK button
						$ConnectionErrorCount = $ConnectionErrorCount + 1
						$LoopCounter = 0
					 ElseIf NOT $Enabled[$RaidSummons] Then
						Return False
					 Else
						$LoopCounter = $LoopCounter + 1
						If $LoopCounter = 45 Then
						   _Click(300, 860)	; Next button when unit list is short, failsafe because pictures are not working
						EndIf
						If $LoopCounter = 90 OR $ConnectionErrorCount = 10 Then
						   _FatalError("_RaidSummons: Summon Failed")
						EndIf
					 EndIf
				  WEnd
			   Else
				  Return True	; If we click multi-summon and don't get the next screen, we are out of raid coins (or have 100 left, but not worth special scripting for this possibility)
			   EndIf
			Case Else
			   If _GetHomeScreen() Then
				  Return False	; We can't get back to the raid summon screen, we are done
			   Else
				  Return False
			   EndIf
		 EndSwitch
	  EndIf
   WEnd
EndFunc


Func _SellMaterials()
   Local $ExtraScrollPoint = True, $RightSide = True
   Local $MaterialSold, $LoopCounter ;, $MaterialDescriptionRead
   For $LoopCounter = 1 TO $MaterialsList[0][0]
	  $MaterialsList[$LoopCounter][0] = 0	; Reset each material's [0] element to 0, it is used to count how many stacks of that material were found
   Next
   _StopTMFarm()
   While $InfiniteLoop
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_SellMaterials")
		 If _CheckForInterrupt($SellMaterials) Then
			Return False
		 EndIf
		 Switch _WhereAmI($SellMaterials)
			Case $HomeScreen
			   _Click(240, 1000)	; Home screen items button
			   Sleep(1000)
			Case $ItemSetScreen
			   _Click(450, 710)		; Materials
			   Sleep(1000)
			Case $MaterialsScreen
			   _Click(530, 270)		; Sell button
			   Sleep(1000)
			Case $SellMaterialsScreen
			   If _CheckForImage($SellMaterialsBottom, $x, $y) Then	; This could miss a few because it will stop as soon as it can see the bottom of the screen, but that shouldn't be a big deal
				  _Click(50, 1000)	; Home button at bottom
				  Sleep(1000)
				  Return True
			   EndIf
			   If $RightSide Then
				  _Click(150, 360)	; First material on right side
			   Else
				  _Click(450, 360)	; First material on left side
			   EndIf
			   Sleep(1000)
;			   _GDIPlus_Startup()
;			   $MaterialDescriptionRead = StringLower(StringStripWS(_OCR(130, 384, 400, 60), 8))
			   $MaterialSold = False
;			   If _OCR(220, 465, 100, 50) = 199 Then	; Only full stacks will even be checked
			   If _CheckForImage($MaterialFullStack, $x, $y) Then	; Only full stacks will be checked
				  For $LoopCounter = 1 TO $MaterialsList[0][0]
;					 If $MaterialDescriptionRead = $MaterialsList[$LoopCounter][$MaterialDescription] Then
					 If _CheckForImage($MaterialsList[$LoopCounter][$MaterialDescription], $x, $y) Then
						$MaterialsList[$LoopCounter][0] = $MaterialsList[$LoopCounter][0] + 1
						If $MaterialsList[$LoopCounter][0] > $MaterialsList[$LoopCounter][$SaveStacks] Then
						   $MaterialSold = True
						   _Click(410, 700)	; Sell button
						   Sleep(1000)
						   If _CheckForImage($MaterialsSellGilCap, $x, $y) Then
							  _Click(400, 595)	; Yes button
							  Sleep(2000)
						   EndIf
						   _Click(400, 600)	; Yes button
						   Sleep(1000)
						EndIf
						ExitLoop
					 EndIf
				  Next
			   EndIf
;			   _GDIPlus_Shutdown()
			   If NOT $MaterialSold Then
				  _Click(180, 700)			; Cancel button
				  Sleep(1000)
				  If NOT $RightSide Then
					 If NOT $ExtraScrollPoint Then	; Scroll down, need to alternate a 1 pixel difference for even scrolling
						_ClickDrag(300, 625, 300, 521, 15)
					 Else
						_ClickDrag(300, 625, 300, 520, 15)
					 EndIf
					 Sleep(500)
					 $ExtraScrollPoint = NOT $ExtraScrollPoint
				  EndIf
				  $RightSide = NOT $RightSide
			   EndIf
			Case Else
			   If _GetHomeScreen() Then
				  _Click(240, 1000)	; Home screen items button
			   Else
				  Return False
			   EndIf
		 EndSwitch
	  EndIf
   WEnd
EndFunc


Func _ClaimDailyQuests()
   Local $LoopCounter
   While $InfiniteLoop
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_ClaimDailyQuests")
		 If _CheckForInterrupt($ClaimDailies) Then
			Return False
		 EndIf
		 Switch _WhereAmI($ClaimDailies)
			Case $HomeScreen
			   _Click(165, 200)	; Home screen daily quest shortcut
			   Sleep(2000)
			Case $DailyQuestScreen
			   If _CheckForImage($DailyQuestClaimAllButton, $x, $y) Then
				  _Click(300, 975)	; Claim All button
				  Sleep(1000)
				  _Click(400, 600)	; Yes button
				  $LoopCounter = 0
				  While $InfiniteLoop
					 Sleep(1000)
					 If _CheckForImage($DailyQuestScreen, $x, $y) Then
						_Click(60, 100)	; Back button
						Sleep(1000)
						Return True
					 EndIf
					 $LoopCounter = $LoopCounter + 1
					 If $LoopCounter = 30 Then
						Return False
					 EndIf
				  WEnd
			   Else
				  Return True
			   EndIf
			Case Else
			   If _GetHomeScreen() Then
				  _Click(165, 200)	; Home screen daily quest shortcut
			   Else
				  Return False
			   EndIf
		 EndSwitch
	  EndIf
   WEnd
EndFunc


Func _SendFriendGifts()
   Local $LoopCounter
   While $InfiniteLoop
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_SendFriendGifts")
		 If _CheckForInterrupt($SendGifts) Then
			Return False
		 EndIf
		 Switch _WhereAmI($SendGifts)
			Case $HomeScreen
			   _Click(530, 1000)	; Friends
			   Sleep(1000)
			Case $FriendsScreen
			   _Click(450, 500)		; Gifts button
			   Sleep(1000)
			Case $ReceiveGiftsScreen
			   _Click(475, 260)		; Send button
			   Sleep(1000)
			Case $SendGiftsScreen
			   _Click(330, 260)		; Send All button
			   Sleep(1000)
			   _Click(50, 1000)		; Bottom Home button
			   Return True
			Case Else
			   If _GetHomeScreen() Then
				  _Click(530, 1000)	; Friends
			   Else
				  Return False
			   EndIf
		 EndSwitch
	  EndIf
   WEnd
EndFunc


Func _CheckForDisableTime($CheckType, $Check=_DateDayOfWeek(@WDay))
   Local $TimeFound = StringSplit(IniRead($IniFile, $CheckType, $Check, "NEVER"), ":")
   If $TimeFound[1]= "NEVER" Then
	  Return False
   EndIf
   If IsNumber($TimeFound[1]) Then
	  If $TimeFound[1] >= 0 AND $TimeFound[1] < 24 Then
;		 If $TimeFound[0] > 1 Then
		 If Int(@Hour) = Int($TimeFound[1]) Then
			Return True
		 EndIf
	  EndIf
   EndIf
   Return False
EndFunc


Func _GetTMProgress()		; This needs to be called when the TM results are known to be on the screen and will not be clicked away before it is done
   Local $yPos = 192, $ySize, $UnitNumber, $ProgressFound, $UnitNameFound, $x, $y
   _GDIPlus_Startup()
   Sleep(1000)		; This should prevent the screen from being read too soon (as the information comes in from the side)
   For $UnitNumber = 1 TO 5
	  Switch $UnitNumber
		 Case 3, 5
			$ySize = 26	; For some reason, these are one pixel shorter than the rest
		 Case Else
			$ySize = 27
	  EndSwitch
	  If NOT _CheckForImage($BattleResultsTMPage, $x, $y) Then	; We are not on the results page anymore, stop trying to read from it
		 _GDIPlus_Shutdown()
		 Return False
	  EndIf
	  $ProgressFound = _OCR(465, $yPos, 85, $ySize)
	  $UnitNameFound = _OCR(137, $yPos, 280, $ySize + 1)
	  If $UnitNameFound <> $UnitName[$UnitNumber] Then
		 $UnitName[$UnitNumber] = $UnitNameFound
		 If $TMDisplayType = 0 Then		; Only update the display if we are showing the TM farming party
			GUICtrlSetData($UnitNameDisplay[$UnitNumber], $UnitName[$UnitNumber])
		 EndIf
		 IniWrite($IniFile, "Initialize", "Unit " & $UnitNumber, $UnitName[$UnitNumber])
	  EndIf
;msgbox(64, "", "Unit " & $UnitName[$UnitNumber] & " received TMR progress info: " & $ProgressFound)
	  If Number($ProgressFound) > 0 AND Number($ProgressFound) <= 100 Then
		 $UnitTMProgress[$UnitNumber] = Number($ProgressFound)
		 $UnitTMVerified[$UnitNumber] = True
		 If $TMDisplayType = 0 Then
			GUICtrlSetData($UnitTMProgressDisplay[$UnitNumber], $ProgressFound & " %")
		 EndIf
		 IniWrite($IniFile, "Initialize", "Unit " & $UnitNumber & " TM", $ProgressFound)
	  ElseIf $ProgressFound = "0.0" Then
		 $UnitTMProgress[$UnitNumber] = 0
		 $UnitTMVerified[$UnitNumber] = True
		 If $TMDisplayType = 0 Then
			GUICtrlSetData($UnitTMProgressDisplay[$UnitNumber], $ProgressFound & " %")
		 EndIf
		 IniWrite($IniFile, "Initialize", "Unit " & $UnitNumber & " TM", $ProgressFound)
	  Else			; This may indicate an OCR error, log it and don't use the data
		 _AddToLog(1, "Unit " & $UnitNumber & " received TMR progress info: " & $ProgressFound)
	  EndIf
	  $yPos = $yPos + 147
   Next
   _GDIPlus_Shutdown()
EndFunc


Func _OCR($xPos, $yPos, $xSize, $ySize)		; This needs to be called when the TM results are known to be on the screen and will not be clicked away before it is done
   ; Requires Tesseract OCR software to be installed (free). Tested with Version 3.5
   If NOT $DeleteTempFiles Then
	  $TempFileNumber = $TempFileNumber + 1
   EndIf
   Local $Capture, $hImage1, $hImage2, $hBitmap, $hGraphic, $ImageHeight, $ImageWidth, $DataReceived, $CLSID
   Local $TempImageFile = "C:\FFBE\~FFBEMacroTemp" & $TempFileNumber & ".bmp", $TempText = "C:\FFBE\~FFBEMacroTemp" & $TempFileNumber, $TempTextFile = $TempText & ".txt"	; No spaces in temp files
   Local $TesseractExe = '"C:\Program Files (x86)\Tesseract-OCR\Tesseract.exe"', $TesseractExePath = "C:\Program Files (x86)\Tesseract-OCR"
;   _GDIPlus_Startup() ; This is handled by the calling function so it is not done repeatedly
   _CheckWindowPosition()
   $Capture = _ScreenCapture_Capture("", $EmulatorX1 + $xPos, $EmulatorY1 + $yPos, $EmulatorX1 + $xPos + $xSize, $EmulatorY1 + $yPos + $ySize)	; Capture screenshot
   $hImage2 = _GDIPlus_BitmapCreateFromHBITMAP($Capture)				; GPIPlus handle for the screenshot
   $ImageHeight = (_GDIPlus_ImageGetHeight($hImage2)) * 2				; Double the dimensions of the screenshot (drastically increases accuracy)
   $ImageWidth = (_GDIPlus_ImageGetWidth($hImage2)) * 2
   $hBitmap = _WinAPI_CreateBitmap($ImageWidth, $ImageHeight, 1, 32)	; Blank bitmap of the correct size
   $hImage1 = _GDIPlus_BitmapCreateFromHBITMAP($hBitmap)				; GDIPlus handle for the blank bitmap
   $hGraphic = _GDIPlus_ImageGetGraphicsContext($hImage1)				; GDIPlus graphics context for blank bitmap
   _GDIPlus_GraphicsDrawImageRect($hGraphic, $hImage2, 0, 0, $ImageWidth, $ImageHeight)	; Draw the screenshot onto the blank bitmap
   $CLSID = _GDIPlus_EncodersGetCLSID("bmp")							; CLSID for the GPIPlus encoder for .bmp format
   If $DeleteTempFiles Then
	  FileDelete($TempImageFile)										; Make sure the temp file doesn't already exist
   EndIf
   _GDIPlus_ImageSaveToFileEx($hImage1, $TempImageFile, $CLSID)			; Save the newly drawn bitmap to the temp file
   RunWait($TesseractExe & " " & $TempImageFile & " " & $TempText, $TesseractEXEPath, @SW_HIDE)	; Run Tesseract OCR on the temp file
   $DataReceived = StringReplace(StringStripWS(FileRead($TempTextFile), 8), "%", "")
   _GDIPlus_ImageDispose($hImage1)										; Release the resources
   _GDIPlus_ImageDispose($hImage2)
   _GDIPlus_GraphicsDispose($hGraphic)
   _WinAPI_DeleteObject($hBitmap)
   If $DeleteTempFiles Then
	  FileDelete($TempImageFile)										; Delete the temporary image file
	  FileDelete($TempTextFile)											; Delete the temporary output file
   EndIf
;   _GDIPlus_Shutdown()
   Return $DataReceived
EndFunc


Func _CheckTMStatus()
   Local $UnitNumber, $TMUnit, $TMGroupNumber, $TMGroupCount, $TMTotalProgress, $GroupUnit, $NewInterval, $TMWarning = 0, $TMCompleted = False
   For $TMGroupNumber = 0 TO 2
	  $TMTotalProgress = 0
	  $TMGroupCount = 0
	  $GroupUnit = 0
	  For $UnitNumber = 1 TO 5
		 If $UnitTMGroup[$UnitNumber] = $TMGroupNumber Then
			If $TMGroupNumber = $NoGroup Then
			   If $UnitTMProgress[$UnitNumber] >= $UnitTMTarget[$UnitNumber] Then
				  $TMCompleted = True
				  $TMUnit = $UnitName[$UnitNumber]
			   ElseIf $UnitTMProgress[$UnitNumber] >= ($UnitTMTarget[$UnitNumber] - $TMWarningThreshold3[1]) AND $TMWarning < 3 Then
				  $TMWarning = 3
			   ElseIf $UnitTMProgress[$UnitNumber] >= ($UnitTMTarget[$UnitNumber] - $TMWarningThreshold2[1]) AND $TMWarning < 2 Then
				  $TMWarning = 2
			   ElseIf $UnitTMProgress[$UnitNumber] >= ($UnitTMTarget[$UnitNumber] - $TMWarningThreshold1[1]) AND $TMWarning < 1 Then
				  $TMWarning = 1
			   EndIf
			Else
			   $TMTotalProgress = $TMTotalProgress + $UnitTMProgress[$UnitNumber]
			   $TMGroupCount = $TMGroupCount + 1
			   $GroupUnit = $UnitNumber				; Unit number of a unit in the group, doesn't really matter which one it is
			EndIf
		 EndIf
	  Next
	  If $TMGroupNumber <> $NoGroup AND $TMGroupCount > 0 Then
		 If $TMGroupCount > 1 Then		; Add the 5% bonus for each unit after the first to be fused
			$TMTotalProgress = $TMTotalProgress + (5 * ($TMGroupCount - 1))
		 EndIf
		 If $TMTotalProgress >= $UnitTMTarget[$GroupUnit] Then
			$TMCompleted = True
			$TMUnit = $UnitName[$GroupUnit]
		 ElseIf $TMTotalProgress >= ($UnitTMTarget[$GroupUnit] - $TMWarningThreshold3[$TMGroupCount]) AND $TMWarning < 3 Then
			$TMWarning = 3
		 ElseIf $TMTotalProgress >= ($UnitTMTarget[$GroupUnit] - $TMWarningThreshold2[$TMGroupCount]) AND $TMWarning < 2 Then
			$TMWarning = 2
		 ElseIf $TMTotalProgress >= ($UnitTMTarget[$GroupUnit] - $TMWarningThreshold1[$TMGroupCount]) AND $TMWarning < 1 Then
			$TMWarning = 1
		 EndIf
	  EndIf
   Next
   If $TMCompleted Then
	  $Enabled[$TMFarm] = False
	  IniWrite($IniFile, "Initialize", $FriendlyName[$TMFarm] & " Enabled", $Enabled[$TMFarm])
	  _SendMail("Trust master farming for " & $TMUnit & " has been completed")
	  _CreateGUI()
	  _StopTMFarm()
   Else
	  Switch $TMWarning
		 Case 0
			$NewInterval = $DefaultTMFarmInterval
		 Case 1
			$NewInterval = $TMWarningThreshold1[0]
		 Case 2
			$NewInterval = $TMWarningThreshold2[0]
		 Case 3
			$NewInterval = $TMWarningThreshold3[0]
	  EndSwitch
	  If $NewInterval <> $TMFarmProgressCheckInterval Then
		 $TMFarmProgressCheckInterval = $NewInterval
		 If $FastTMFarm <> "OFF" Then
			_StopTMFarm()
			_StartTMFarm("SkipFirstCheck")
		 EndIf
	  Else
		 Return False
	  EndIf
   EndIf
EndFunc


Func _HandleAdWheel()
   Local $SleepCounter, $ClaimedReward = False, $NothingFoundCount
   While $InfiniteLoop
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_HandleAdWheel")
		 If _CheckForInterrupt($AdWheel) Then
			Return False
		 EndIf
		 Switch _WhereAmI($AdWheel)
		 Case $HomeScreen
			   $NothingFoundCount = 0
			   _Click(70, 200)	; Home screen reward wheel shortcut
			   Sleep(2000)
			Case $RewardsWheelPage
			   If _CheckForImage($AdRewardAvailable, $x, $y) Then
				  $NothingFoundCount = 0
				  If $ClaimAdReward Then
					 Sleep(4000)	; wait for the moogle to go across the screen
					 _Click(525, 850)	; Treasure chest
					 For $SleepCounter = 1 TO 15	; Allow 15 seconds to click the claim button
						If _CheckForImage($AdRewardClaimButton, $x, $y) Then
						   _Click(300, 675)	; Claim button
						   $ClaimedReward = True
						   ExitLoop
						EndIf
						Sleep(1000)
					 Next
					 If NOT $ClaimedReward Then
						_FatalError("_HandleAdWheel: Unable to claim reward")
					 EndIf
				  Else
					 _SendMail("_HandleAdWheel: Ad Reward Available!")
					 Return True
				  EndIf
			   ElseIf _CheckForImage($AdsUsedUp, $x, $y) Then
				  _Click(50, 1000)	; Home button on bottom bar
				  Sleep(1000)
				  Return True
			   ElseIf _CheckForImage($AdsNotAvailable, $x, $y) Then
				  _Click(50, 1000)	; Home button on bottom bar
				  Sleep(1000)
				  Return False
			   ElseIf _CheckForImage($AdsSpinButton, $x, $y) Then
				  $NothingFoundCount = 0
				  _Click(300, 745)	; Spin button (first screen)
				  Sleep(2000)
			   ElseIf _CheckForImage($AdsSpinButton2, $x, $y) Then
				  $NothingFoundCount = 0
				  _Click(300, 635)	; Spin button (second screen, starts ad)
				  For $SleepCounter = 1 TO 60	; Wait for ad to finish, allow 60 seconds
					 GUICtrlSetData($DebugBox, "_HandleAdWheel - Sleep " & 60 - $SleepCounter)
					 Sleep(1000)
				  Next
				  GUICtrlSetData($DebugBox, "_HandleAdWheel")
				  _CheckWindowPosition("Force")
				  If $EmulatorX2 > $EmulatorY2 Then		; Window orientation has been changed by the ad
					 _Click(750, 320)	; Emulator back button (hopefully)
					 For $SleepCounter = 1 TO 60	; Wait up to 60 seconds for emulator to go back to the correct orientation
						GUICtrlSetData($DebugBox, "_HandleAdWheel - Sleep " & 60 - $SleepCounter)
						Sleep(1000)
						_CheckWindowPosition("Force")
						If $EmulatorY2 > $EmulatorX2 Then		; Window orientation has returned to normal
						   Sleep(3000)	; Make sure everything is okay
						   ExitLoop
						EndIf
					 Next
					 GUICtrlSetData($DebugBox, "_HandleAdWheel")
					 If $EmulatorX2 > $EmulatorY2 Then		; Window orientation has not returned to normal
						_Click(750, 320)	; Emulator back button, last ditch effort to prevent a fatal error
						Sleep(5000)
						If $EmulatorX2 > $EmulatorY2 Then		; Window orientation still has not returned to normal
						   _FatalError("_HandleAdWheel - failed to handle sideways ad")
						EndIf
					 EndIf
				  Else
					 _Click(600, 940)	; Emulator back button
					 Sleep(1000)
				  EndIf
;				  _Click(560, 50)	; X button for ad
;				  Sleep(1000)
			   Else
				  $NothingFoundCount += 1
				  If $NothingFoundCount > 30 Then
					 _SendMail("_HandleAdWheel: Unrecognized condition on rewards wheel page")
					 Return False
				  EndIf
				  Sleep(1000)
			   EndIf
			Case $RewardsWheelReady
			   $NothingFoundCount = 0
			   _SpinWheel()
			Case Else
			   If _GetHomeScreen() Then
				  _Click(70, 200)	; Home screen reward wheel shortcut
			   Else
				  Return False
			   EndIf

		 EndSwitch
	  EndIf
   WEnd
EndFunc


Func _SpinWheel()
   Local $SleepCounter = 0
   While NOT _CheckForImage($AdsNextButton, $x, $y)
	  _Click(300, 100)	; Safe area in case we end up somewhere else
	  Sleep(1000)
	  $SleepCounter = $SleepCounter + 1
	  If $SleepCounter > 90 Then		; Something went wrong, we should have found the next button a long time ago
		 ExitLoop
	  EndIf
   WEnd
   If _CheckForImage($AdsNextButton, $x, $y) Then
	  _Click(300, 950)	; Next Button
   EndIf
EndFunc


Func _HandleExpeditions()
   Local $Expedition, $LoopCounter, $ConnectionErrorCount, $FoundNextButton, $Reward, $ClaimedExpeditions = False, $ClaimedRewards = False
   Local $ExpeditionFound, $ExpeditionChosen, $ExpeditionChosenRank, $ExpeditionRemoved
   Local $CurrentUnit, $Failed, $TMGroupProgress[3], $TMProgressRead, $UnitFound
   ; Due to a bug introduced on 9/5/19, the title bar is no longer a viable test for where we are, it does not properly update between screens
   ; Testing must now be done with the brightness of the new and ongoing buttons and just hoping we are still on the rewards screen once we get there
   While $InfiniteLoop
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_HandleExpeditions")
		 If _CheckForInterrupt($Expeditions) Then
			Return False
		 EndIf
		 Switch _WhereAmI($Expeditions)
			Case $HomeScreen
			   _Click(480, 780)	; Expeditions
			   Sleep(2000)
			Case $ExpeditionsScreen, $ExpeditionsScreen2, $ExpeditionsRewardScreen, $ExpeditionsRewardScreen2
			   If NOT $ClaimedRewards Then
				  _Click(520, 265)	; Rewards button
				  $Reward = 1
				  $LoopCounter = 0
				  While $InfiniteLoop
					 Sleep(1000)
					 If _CheckForImage($ExpeditionClaimReward, $x, $y) Then
						_Click(300, 690)	; Claim button
						Sleep(1000)
						_Click(515, 490)	; X on rewards window
						$Reward = $Reward + 1
					 ;ElseIf _CheckForImage($ExpeditionsRewardScreen, $x, $y) OR _CheckForImage($ExpeditionsRewardScreen2, $x, $y) Then ; Broken by bug
					 ElseIf _CheckForImage($ExpeditionsRewardScreen, $x, $y) OR _CheckForImage($ExpeditionsRewardScreen2, $x, $y) OR _CheckForImage($ExpeditionsScreen, $x, $y) OR _CheckForImage($ExpeditionsScreen2, $x, $y) Then
						Switch $Reward
						   Case 1
							  _Click(200, 840)
						   Case 2
							  _Click(245, 750)
						   Case 3
							  _Click(275, 670)
						   Case 4
							  _Click(295, 580)
						   Case Else
							  ExitLoop
						EndSwitch
					 EndIf
					 $LoopCounter = $LoopCounter + 1
					 If $LoopCounter = 40 Then
						Return False
					 EndIf
				  WEnd
				  $ClaimedRewards = True
			   ElseIf NOT $ClaimedExpeditions Then
				  _Click(300, 370)	; Ongoing
				  Sleep(2000)
				  If _CheckForImage($ExpeditionsCompleted, $x, $y) Then
					 For $Expedition = 5 TO 1 Step -1
						If NOT _CheckForImage($ExpeditionsCompleted, $x, $y) Then
						   ExitLoop
						EndIf
						_Click(460, 300 + (150 * $Expedition))	; Each expedition slot, 1 = 450, 2 = 600, etc, away from the recall/accelerate buttons
						Sleep(1000)
						$LoopCounter = 0
						$ConnectionErrorCount = 0
						$FoundNextButton = False
						While $InfiniteLoop
						   _Click(300, 100)
						   Sleep(1000)
						   If _CheckForImage($ExpeditionAccelerateButton, $x, $y) OR _CheckForImage($ExpeditionRecallButtonTM, $x, $y) Then
							  _Click(515, 380)		; X on Expedition Accelerate Screen
							  Sleep(1500)
							  ExitLoop
						   EndIf
						   If (_CheckForImage($ExpeditionsCompleted, $x, $y) AND $LoopCounter > 3) Then
							  ExitLoop
						   EndIf
						   ;If _CheckForImage($ExpeditionsScreen2, $x, $y) Then	; Broken by bugs
							;  ExitLoop 2
						   ;EndIf
						   If _CheckForImage($ExpeditionsNew, $x, $y) Then
							  _Click(300, 370)	; Ongoing
							  Sleep(1000)
						   EndIf
						   If _CheckForImage($ExpeditionNextButton, $x, $y) Then
							  _Click(300, 1010)	; Next button
							  Sleep(1000)
							  $FoundNextButton = True
						   EndIf
						   If _CheckForImage($ExpeditionsNotCompleted, $x, $y) Then
							  ExitLoop 2
						   EndIf
						   If _CheckForImage($ConnectionError, $x, $y) Then
							  _Click(300, 630)	; OK button
							  $LoopCounter = 0	; Reset the time if we get a connection error
							  $ConnectionErrorCount = $ConnectionErrorCount + 1
						   EndIf
						   If $FoundNextButton Then
							  ;If _CheckForImage($ExpeditionsScreen, $x, $y) Then ; Broken by bug
							  If _CheckForImage($ExpeditionsScreen, $x, $y) OR _CheckForImage($ExpeditionsScreen2, $x, $y) OR _CheckForImage($ExpeditionsRewardScreen, $x, $y) OR _CheckForImage($ExpeditionsRewardScreen2, $x, $y) Then
								 ExitLoop
							  EndIf
						   EndIf
						   $LoopCounter = $LoopCounter + 1
						   If $LoopCounter = 60 OR $ConnectionErrorCount = 10 Then	; If we are here too long, something went wrong
							  ExitLoop 2
						   EndIf
						WEnd
					 Next
				  EndIf
				  $ClaimedExpeditions = True
			   Else
				  _Click(100, 370)	; New tab
				  Sleep(2000)
				  $ExpeditionChosen = 0
				  $ExpeditionChosenRank = 0
				  _GDIPlus_Startup() ; Required for _OCR to work
				  For $Expedition = 1 TO 3
					 $ExpeditionFound = StringStripWS(_OCR(136, 465 + (151 * ($Expedition - 1)), 310, 27), 8)	; OCR from correct place on screen for expedition number $Expedition
					 For $ExpeditionCheck = 1 TO $ExpeditionList[0][0]
						If $ExpeditionCheck > $LastAcceptableExpedition AND $LastAcceptableExpedition > 0 Then
						   ExitLoop	; There are no more expeditions we are allowed to run
						EndIf
;						msgbox(64,stringlower($expeditionfound), stringlower($ExpeditionList[$ExpeditionCheck][$ExpeditionName]))
						If StringLower($ExpeditionFound) = StringLower($ExpeditionList[$ExpeditionCheck][$ExpeditionName]) Then
						   If $ExpeditionChosenRank > $ExpeditionCheck OR $ExpeditionChosenRank = 0 Then
							  $ExpeditionChosen = $Expedition
							  $ExpeditionChosenRank = $ExpeditionCheck
						   EndIf
						EndIf
					 Next
				  Next
				  _GDIPlus_Shutdown() ; Done with _OCR for now
				  If $ExpeditionChosen = 0 Then
					 If _CheckForImage($ExpeditionRefreshFree, $x, $y) Then
						_Click(300, 1010)	; Refresh button
						Sleep(2000)
						_Click(400, 685)	; Yes button
						Sleep(1000)
					 ElseIf _DateAdd("d", -1, _NextDailyReset()) > $LastAncientCoin AND $AllowAncientCoins Then
						$LastAncientCoin = _NowCalc()
						_Click(300, 1010)	; Refresh button
						Sleep(1000)
						_Click(180, 740)	; Ancient Coin Refresh button
						Sleep(1000)
						_Click(400, 600)	; Yes button
						Sleep(1000)
						IniWrite($IniFile, "Initialize", "Last Ancient Coin", $LastAncientCoin)
					 Else
						Return False		; No selectable expeditions found, giving up
					 EndIf
				  Else
					 Switch $ExpeditionChosen
						Case 1
						   _Click(300, 500)		; First expedition in list
						Case 2
						   _Click(300, 650)		; Second expedition in list
						Case 3
						   _Click(300, 800)		; Third expedition in list
					 EndSwitch
					 $LoopCounter = 0
					 $ExpeditionRemoved = False
					 While $InfiniteLoop
						Sleep(1000)
						If _CheckForImage($ExpeditionAutoFillButton, $x, $y) Then
						   _Click(150, 1000)	; Auto Fill button
						   ExitLoop
						ElseIf $ExpeditionList[$ExpeditionChosenRank][$ExpeditionTM] AND _CheckForImage($ExpeditionTMDepartButton, $x, $y) Then
						   _GDIPlus_Startup() ; Required for _OCR
						   $Failed = False
						   $TMGroupProgress[1] = 0
						   $TMGroupProgress[2] = 0
						   For $CurrentUnit = 1 TO 5
							  _Click(60 + (($CurrentUnit - 1) * 115), 700)	; Unit
							  Sleep(1000)
							  _Click(60 + (($CurrentUnit - 1) * 115), 700)	; Unit again, to get unit screen
							  Sleep(1000)
							  $LoopCounter = 0
							  While $InfiniteLoop
								 If _CheckForImage($EquipButton, $x, $y) Then
									$TMProgressRead = _OCR(93, 869, 100, 25)
									If $TMProgressRead = "" Then
									   $Failed = True
									   _Click(60, 200)	; Back button
									   Sleep(2000)
									   ExitLoop 2
									EndIf
									$UnitTMExpeditionProgress[$CurrentUnit] = Number($TMProgressRead)
									$UnitTMExpeditionVerified[$CurrentUnit] = True
									If $TMDisplayType = 1 Then
									   GUICtrlSetData($UnitTMProgressDisplay[$CurrentUnit], $TMProgressRead & " %")
									EndIf
									IniWrite($IniFile, "Initialize", "Unit " & $CurrentUnit & " Expedition TM", $TMProgressRead)
									$TMGroupProgress[$UnitTMExpeditionGroup[$CurrentUnit]] += Number($TMProgressRead)
									_Click(60, 200)	; Back button
									Sleep(2000)
									ExitLoop
								 ElseIf _CheckForImage($SelectPartyScreen, $x, $y) Then	; There was no unit selected, this is a failure
									$Failed = True
									_Click(60, 200)	; Back button
									Sleep(2000)
									ExitLoop 2
								 EndIf
								 $LoopCounter = $LoopCounter + 1
								 If $LoopCounter = 15 Then
									$Failed = True
									_Click(60, 200)	; Back button
									Sleep(2000)
									ExitLoop 2
								 EndIf
								 Sleep(1000)
							  WEnd
						   Next
						   _GDIPlus_Shutdown() ; Done with _OCR for now
						   If $Failed Then
							  _SendMail("There is a problem with the TM expedition, it has been temporarily disabled")
						   Else
							  For $CurrentGroup = 0 TO 2
								 If $CurrentGroup > 0 Then
									$UnitFound = 0
									For $CurrentUnit = 1 TO 5
									   If $UnitTMExpeditionGroup[$CurrentUnit] = $CurrentGroup Then
										  If $UnitFound > 0 Then
											 $TMGroupProgress[$CurrentGroup] += 5
										  Else
											 $UnitFound = $CurrentUnit
										  EndIf
									   EndIf
									Next
									If $TMGroupProgress[$CurrentGroup] >= $UnitTMExpeditionTarget[$UnitFound] AND NOT $Failed Then
									   $Failed = True
									   _SendMail("Trust Master Completed on Expedition Group" & $CurrentGroup& ". Remember to close/reopen the script to re-enable the TM Expedition")
									EndIf
								 Else
									For $CurrentUnit = 1 TO 5
									   If $UnitTMExpeditionProgress[$CurrentUnit] >= $UnitTMExpeditionTarget[$CurrentUnit] Then ;AND NOT $Failed Then
										  $Failed = True
										  msgbox(64, $UnitTMExpeditionProgress[$CurrentUnit], $UnitTMExpeditionTarget[$CurrentUnit])
										  ;_SendMail("Trust Master Completed on Expedition Unit " & $CurrentUnit & ". Remember to close/reopen the script to re-enable the TM Expedition")
									   EndIf
									Next
								 EndIf
							  Next
						   EndIf
						   If $Failed Then
							  $ExpeditionList[$ExpeditionChosenRank][$ExpeditionName] = "Expedition removed, it will come back the next time the script starts up"
							  $ExpeditionRemoved = True
							  Sleep(1000)
							  _Click(60, 200)	; Back button
							  Sleep(2000)
						   EndIf
						   ExitLoop
						ElseIf _CheckForImage($ExpeditionCancelScreen, $x, $y) Then
						   _Click(180, 600)		; No button
						   Sleep(2000)
						   _Click(60, 240)		; Back button
						   Sleep(2000)
						   Return True
						ElseIf _CheckForImage($ExpeditionAutoFillDisabled, $x, $y) Then
						   $ExpeditionList[$ExpeditionChosenRank][$ExpeditionName] = "Expedition removed, it will come back the next time the script starts up"
						   $ExpeditionRemoved = True
						   _Click(60, 240)		; Back button
						   Sleep(2000)
						   ExitLoop
						EndIf
						$LoopCounter = $LoopCounter + 1
						If $LoopCounter = 30 Then
						   Return False
						EndIf
					 WEnd
					 If NOT $ExpeditionRemoved Then
						$LoopCounter = 0
						While $InfiniteLoop
						   Sleep(1000)
						   If _CheckForImage($ExpeditionDepartButton2, $x, $y) Then
							  If $ExpeditionList[$ExpeditionChosenRank][$ExpeditionAllowItem] Then
								 _Click(475, 555)		; Item check box
								 Sleep(1000)
							  EndIf
							  _Click(300, 785)		; Depart button
							  Sleep(1000)
							  ExitLoop
						   ElseIf _CheckForImage($ExpeditionDepartButton1, $x, $y) Then
							  _Click(450, 1000)		; Depart button
						   ElseIf _CheckForImage($ExpeditionTMDepartButton, $x, $y) Then
							  _Click(300, 1000)		; Depart button
							  Sleep(1000)
							  ExitLoop
						   EndIf
						   $LoopCounter = $LoopCounter + 1
						   If $LoopCounter = 30 Then
							  Return False
						   EndIf
						WEnd
					 EndIf
				  EndIf
			   EndIf
   			Case Else
			   If _GetHomeScreen() Then
				  _Click(480, 780)		; Expeditions
			   Else
				  Return False
			   EndIf
		 EndSwitch
	  EndIf
   WEnd
EndFunc


Func _CheckForHomeScreen()
   If $AltHomeScreen Then
	  If _CheckForImage($HomeScreenAlt, $x, $y) Then
		 Return True
	  EndIf
   EndIf
   If _CheckForImage($HomeScreen, $x, $y) Then
	  $AltHomeScreen = False
	  Return True
   EndIf
   Return False
EndFunc


Func _GetHomeScreen($QuickCheck = False)
   Local $CurrentLocation, $CurrentUnit
   Local Const $TimeOutLength = 300
   Local $SearchTimeOut = _DateAdd("s", $TimeOutLength, _NowCalc())	; Time out after specified time, if we can't get home in this amount of time, we never will
   Local $HardStopTimeOut = _DateAdd("s", $TimeOutLength * 2, _NowCalc())	; This time out can't be reset, no matter what happens, we will time out after this one
   While NOT _CheckForHomeScreen()
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_GetHomeScreen")
		 _TeamViewerCheck()
		 If _CheckForImage($OutOfNRG, $x, $y) Then
			_Click(335, 670)	; Back button
			Sleep(1000)
		 ElseIf _CheckForImage($SmallHomeButton, $x, $y) Then
			_ClickItem("General", $x, $y)
			Sleep(1000)
		 ElseIf _CheckForImage($WorldBackButton, $x, $y) Then
			_ClickItem("General", $x, $y)
			Sleep(1000)
		 ElseIf _CheckForImage($VortexBackButton, $x, $y) Then
			_ClickItem("General", $x, $y)
			Sleep(1000)
		 Else
			$CurrentLocation = _WhereAmI("Everything", $QuickCheck)
			Switch $CurrentLocation
			   Case $HomeScreen
				  Return True
			   Case $WorldMainPage, $WorldMapGrandshelt, $WorldMapGrandsheltIsles, $TMSelect, $TMBattle & "1", $TMBattle & "2", $TMFriend
				  _Click(60, 240)	; Back button
			   Case $ArenaMainPage & "0", $ArenaMainPage & "1", $ArenaRulesPage & "0", $ArenaRulesPage & "1", $ArenaSelectionPage
				  _Click(60, 240)	; Back button
			   Case $ExpeditionsScreen, $ExpeditionsScreen2, $ExpeditionsRewardScreen
				  _Click(60, 240)	; Back button
			   Case $FriendsScreen, $ReceiveGiftsScreen, $SendGiftsScreen
				  _Click(50, 1000)	; Home button on bottom bar
			   Case $ManagePartyScreen, $SelectBaseScreen, $EnhanceUnitsScreen, $MaterialUnitsScreen, $SortScreen, $FilterScreen
				  _Click(50, 1000)	; Home button on bottom bar
			   Case $DailyQuestScreen
				  _Click(60, 100)	; Back button
			   Case $VortexMainPage
				  _Click(60, 100)	; Back button
			   Case $RaidSummonScreen, $RaidSummonConfirm
				  _Click(60, 240)	; Back button
			   Case $RaidBattleSelectionPage, $RaidTitle
				  _Click(530, 250)	; Home Buttom
			   Case $RaidDepartPage
				  _Click(60, 240)	; Back button
				  Sleep(1000)
				  _Click(60, 240)	; Back button
				  Sleep(1000)
				  _Click(530, 250)	; Home button
			   Case $RaidFriendPage
				  _Click(60, 240)	; Back button
				  Sleep(1000)
				  _Click(530, 250)	; Home button
			   Case $OutOfRaidOrbs
				  _Click(175, 630)
			   Case $OutOfNRG
				  _Click(335, 670)	; Back button
			   Case $TMInBattle
				  For $CurrentUnit = 1 TO 6
					 Sleep(250)
					 _ActivateUnit($CurrentUnit)
				  Next
				  Sleep(250)
			   Case $ArenaOpponentConfirm
				  _Click(175, 615)
			   Case $ArenaBeginButton
				  _Click(300, 915)	; Can't avoid the arena battle at this point, we have to start it
			   Case $ArenaInBattle
				  _BattleSequence($Arena)
				  $SearchTimeOut = _DateAdd("s", $TimeOutLength, _NowCalc())	; Reset the timeout since the battle could have taken a little while
			   Case $RaidInBattle
				  _BattleSequence($Raid)
				  $SearchTimeOut = _DateAdd("s", $TimeOutLength, _NowCalc())	; Reset the timeout since the battle could have taken a little while
			   Case $RewardsWheelPage
				  _Click(50, 1000)	; Home button on bottom bar
			   Case $RewardsWheelReady
				  _SpinWheel()
				  $SearchTimeOut = _DateAdd("s", $TimeOutLength, _NowCalc())	; Reset the timeout since the spin could have taken a little while
			   Case "Unknown"
				  Return False
			   Case Else
				  _FatalError("_GetHomeScreen - Missing case for " & $CurrentLocation)
			EndSwitch
		 EndIf
		 If _NowCalc() > $SearchTimeOut OR _NowCalc() > $HardStopTimeOut Then
			Return False
		 EndIf
	  EndIf
   WEnd
   Return True
EndFunc


Func _CheckForTime()
   Local $CheckType
   For $CheckType = 1 TO $ArrayItems
	  If _NowCalc() > $StartTime[$CheckType] Then
		 $Enabled[$CheckType] = True
		 $StartTime[$CheckType] = "OFF"
		 If $CheckType <> $TMFarm Then
			$NextOrbCheck[$CheckType] = _DateAdd("s", -1, _NowCalc())
		 EndIf
		 IniWrite($IniFile, "Initialize", $FriendlyName[$CheckType] & " Enabled", $Enabled[$CheckType])
		 IniWrite($IniFile, "Initialize", $FriendlyName[$CheckType] & " Start Time", $StartTime[$CheckType])
		 _CreateGUI()
	  ElseIf _NowCalc() > $StopTime[$CheckType] Then
		 $Enabled[$CheckType] = False
		 $StopTime[$CheckType] = "OFF"
		 IniWrite($IniFile, "Initialize", $FriendlyName[$CheckType] & " Enabled", $Enabled[$CheckType])
		 IniWrite($IniFile, "Initialize", $FriendlyName[$CheckType] & " Stop Time", $StopTime[$CheckType])
		 _CreateGUI()
	  EndIf
   Next
EndFunc


Func _CheckForInterrupt($CurrentActionType)
   Local $CheckType
   _CheckForTime()
   For $CheckType = 1 TO $ArrayItems
	  If $CurrentActionType = $CheckType AND NOT $Enabled[$CheckType] Then
		 Return True
	  ElseIf $CheckType <> $TMFarm AND $CheckType > $CurrentActionType Then	; We will only check for things with a higher priority than what we are already doing
		 If _NowCalc() > $NextOrbCheck[$CheckType] AND $Enabled[$CheckType] AND $NextOrbCheck[$CheckType] <> "OFF" Then
			Return True
		 EndIf
	  EndIf
   Next
   If $NextPlannedAction <> "" AND $NextPlannedAction <> $CurrentActionType Then
	  Return True
   Else
	  $NextPlannedAction = ""	; This will either already be blank or match our current action and need to be cleared
	  Return False
   EndIf
EndFunc


Func _GetTMBattle()
   Local $LoopCounter = 0, $ChangedDirection = 0, $x1, $y1
   Local $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
   While $InfiniteLoop
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_GetTMBattle")
		 If _CheckForInterrupt($TMFarm) Then
			_StopTMFarm()
			Return False
		 EndIf
		 $LoopCounter = $LoopCounter + 1
		 Switch _WhereAmI("World")
			Case $HomeScreen
			   _Click(300, 775)
			Case $WorldMainPage
			   If $ChangedDirection = 0 Then
				  $SearchDirection = "Right"
				  $ChangedDirection = 1
			   EndIf
			   If _CheckForImage($WorldClickGrandshelt, $x, $y) Then
				  _ClickItem("General", $x, $y)
				  $ChangedDirection = 0
				  $LoopCounter = 0
			   Else
				  _WorldMapDrag($x, $y)
				  If _CheckForImage($WorldClickGrandshelt, $x, $y) Then
					 _ClickItem("General", $x, $y)
					 $ChangedDirection = 0
					 $LoopCounter = 0
				  Else
					 If $LoopCounter / 3 = Int($LoopCounter / 3) Then
						Switch StringLower($SearchDirection)
						   Case "left"
							  $SearchDirection = "Right"
						   Case "right"
							  $SearchDirection = "Left"
						EndSwitch
					 EndIf
				  EndIf
			   EndIf
			Case $WorldMapGrandshelt
			   _Click(425, 480)	; Grandshelt Isles
			Case $WorldMapGrandsheltIsles
			   If $ChangedDirection = 0 Then
				  If $Dalnakya Then
					 $SearchDirection = "Down"
				  Else
					 $SearchDirection = "Left"
				  EndIf
				  $ChangedDirection = 1
			   EndIf
			   If _CheckForImage($WorldClickTM, $x, $y) Then
				  _ClickItem("General", $x, $y)
				  $ChangedDirection = 0
				  $LoopCounter = 0
			   ElseIf $Dalnakya AND _CheckForImage($WorldClickDalnakya2, $x, $y) Then
				  _ClickItem("General", $x, $y)
				  $ChangedDirection = 0
				  $LoopCounter = 0
			   Else
				  If _CheckForImage($WorldVortexIcon, $x, $y) Then
					 _WorldMapDrag($x, $y)
				  Else
					 _FatalError("_GetTMBattle - missing vortex icon in Grandshelt Isles screen")
				  EndIf
				  If _CheckForImage($WorldClickGrandshelt, $x, $y) Then
					 _ClickItem("General", $x, $y)
					 $ChangedDirection = 0
					 $LoopCounter = 0
				  Else
					 If $ChangedDirection < 5 Then
						$ChangedDirection = $ChangedDirection + 1
						Switch StringLower($SearchDirection)
						   Case "up"
							  $SearchDirection = "Left"
						   Case "left"
							  $SearchDirection = "Down"
						   Case "down"
							  $SearchDirection = "Right"
						   Case "right"
							  $SearchDirection = "Up"
						EndSwitch
					 Else ; We tried moving in a pattern and still haven't found it, time to randomize movements
						Switch Random(1, 4, 1)
						   Case 1
							  $SearchDirection = "Left"
						   Case 2
							  $SearchDirection = "Down"
						   Case 3
							  $SearchDirection = "Right"
						   Case 4
							  $SearchDirection = "Up"
						EndSwitch
					 EndIf
				  EndIf
			   EndIf
			Case $TMSelect
			   _ClickItem("General", $x, $y)
			   Return True
			Case Else	; We are somewhere we don't belong, we need to return to the home screen and try again
			   If _GetHomeScreen() Then
				  _Click(300, 775)
			   Else
				  Return False
			   EndIf
		 EndSwitch
		 Sleep(500)
	  EndIf
	  If _NowCalc > $SearchTimeOut Then
		 Return False
	  EndIf
   WEnd
EndFunc


Func _TMFarm()
   Local $x1, $y1, $CheckType
   $PartyConfirmed = False
   While $InfiniteLoop
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_TMFarm")
		 If _CheckForInterrupt($TMFarm) Then
			_StopTMFarm()
			Return True
		 EndIf
		 Switch _WhereAmI($TMFarm)
			Case $TMSelect
			   If $FastTMFarm = "OFF" Then
				  _ClickItem("General", $x, $y)
			   EndIf
			Case $TMBattle & "1"
			   If $FastTMFarm = "OFF" Then
				  _ClickItem("General", $x, $y)
			   EndIf
			Case $TMFriend, $RaidFriendPage
			   _ClickItem("Friend", $x, $y)
			Case $TMBattle & "2"
			   If NOT $PartyConfirmed Then
				  If NOT _CheckForImage($TMFarmPartySelected, $x, $y) Then
					 _GetParty($TMFarmPartySelected)
				  EndIf
			   EndIf
			   $PartyConfirmed = True
			   If $TMFarm = "OFF" Then
				  _Click(300, 935) 	; Depart button
			   EndIf
			Case $TMInBattle, "In Battle"
			   If $FastTMFarm = "OFF" Then
				  _BattleSequence($TMFarm, $PartyConfirmed)
			   EndIf
			Case $BattleResultsTMPage
			   If $FastTMFarm = "OFF" OR FileExists($TMPauseFile) Then
				  _GetTMProgress()
				  _CheckTMStatus()
				  _Click(300, 100)	; Safe click area
			   EndIf
			Case $OutOfNRG	; This could be set up to use lapis and/or NRG pots to keep going, but I prefer to do these manually, so I didn't script those options
			   For $CheckType = 1 TO $ArrayItems
				  If $CheckType <> $TMFarm Then
					 If $Enabled[$CheckType] Then
						If _DateAdd("n", Int($OrbCheckInterval / 3) * 2, _NowCalc()) > $NextOrbCheck[$CheckType] Then	; We are out of NRG and a third of the way to an orb check, check it now
						   $NextOrbCheck[$CheckType] = _NowCalc()
						   GUICtrlSetData($NextOrbTimeBox[$CheckType], _SetTimeBox($NextOrbCheck[$CheckType], True))
						EndIf
					 EndIf
				  EndIf
			   Next
			   Sleep(5000)
			   If _CheckForInterrupt($TMFarm) Then
				  _StopTMFarm()
				  _Click(335, 670)	; Back Button
				  Sleep(1000)
				  _Click(530, 240)	; Home button
				  Sleep(1000)
				  _GetHomeScreen()
				  Return True
			   EndIf
			   _Click(335, 670)	; Back button
			Case Else	; We are somewhere we don't belong, we need to get the earth shrine
			   _StopTMFarm()
			   If NOT _GetTMBattle() Then
				  Return False
			   EndIf
		 EndSwitch
		 If $PartyConfirmed Then
			_StartTMFarm()
		 EndIf
	  EndIf
   WEnd
EndFunc


Func _DailyEnlightenment()
   Local $Check, $TimeOutTime = _DateAdd("n", 5, _NowCalc())
   While $InfiniteLoop
	  GUICtrlSetData($DebugBox, "_DailyEnlightenment")
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
;		 If _CheckForInterrupt($DailyEP) Then
;			Return False
;		 EndIf
		 If _NowCalc() > $TimeOutTime Then
			_GetHomeScreen()
			Return False
		 EndIf
		 Switch _WhereAmI($DailyEP)
			Case $HomeScreen
			   _Click(160, 550)	; Vortex
			Case $VortexMainPage
			   _Click(220, 220)	; Enhance Tab
			   Sleep(5000)
			   For $Check = 1 TO 30	; Allow up to 30 seconds for the chamber of enlightenment banner to appear
				  Sleep(1000)
				  If _CheckForImage($ChamberOfEnlightenmentBanner, $x, $y) Then
					 _Click($x, $y)
					 For $Check = 1 TO 30	; Allow up to 30 seconds for the chamber of enlightenment to appear
						Sleep(1000)
						If NOT _CheckForImage($VortexMainPage, $x, $y) Then
						   $Check = -1
						   ExitLoop 2
						EndIf
					 Next
					 ExitLoop
				  EndIf
			   Next
			   If $Check = -1 Then
				  $TimeOutTime = _DateAdd("s", 15, _NowCalc())	; We have entered the Chamber of Enlightenment, allow 15 seconds to find the title bar
			   Else
				  _SendMail("_DailyEnlightenment: Unable to select Chamber of Enlightenment", False)
				  _Click(60, 100)	; Back button, something is wrong if we got here without $Check being set to -1
				  Sleep(1000)
				  Return False
			   EndIf
			Case $ChamberOfEnlightenment
			   Sleep(1000)
			   If _CheckForImage($EnlightenmentFreeDailyBanner, $x, $y) Then
				  _Click(300, 400)	; Free Daily Mission
				  Sleep(8000)
				  _Click(300, 450)	; First companion unit
				  Sleep(8000)
				  If NOT _CheckForImage($TMFarmPartySelected, $x, $y) Then
					 _GetParty($TMFarmPartySelected)
				  EndIf
				  Sleep(1000)
				  $TimeOutTime = _DateAdd("n", 5, _NowCalc())	; 5 minute limit to finish
				  While $InfiniteLoop
					 _Click(300, 930)	; Depart Button
					 Sleep(5000)
					 If _CheckForImage($OutOfNRG, $x, $y) Then
						_Click(335, 670)	; Back button
						Sleep(5000)
					 Else
						ExitLoop
					 EndIf
					 If _NowCalc() > $TimeOutTime Then
						If NOT _GetHomeScreen() Then
						   _FatalError("_DailyEnlightenment: Unable to depart")
						EndIf
						Return False
					 EndIf
				  WEnd
				  $TimeOutTime = _DateAdd("n", 5, _NowCalc())	; 5 minute limit to finish
				  While $InfiniteLoop
					 If _CheckForImageExact($ActiveRepeatButton, $x, $y) Then	; We are in the battle
						_ActivateUnit(1)
						Sleep(1000)
						_ActivateUnit(3)
					 ElseIf _CheckForImage($ConnectionError, $x, $y) Then
						_Click(300, 630)	; OK button
					 ElseIf _CheckForImage($RaidNextButton, $x, $y) OR _CheckForImage($RaidNextButton2, $x, $y) Then
						_Click(300, 935)
					 ElseIf _CheckForImage($ChamberOfEnlightenment, $x, $y) Then
						_Click(60, 240)	; Back Button
						Sleep(2000)
						_Click(60, 100)	; Vortex Back Button
						Sleep(1000)
						Return True
					 Else
						_Click(300, 100)	; Safe place to click to continue progress
					 EndIf
					 If _NowCalc() > $TimeOutTime Then
						If NOT _GetHomeScreen() Then
						   _FatalError("_DailyEnlightenment: Unable to depart")
						EndIf
						Return False
					 EndIf
					 Sleep(1000)
				  WEnd
			   Else	; The free daily banner is not here, it must have already been run
				  _Click(60, 240)	; Back Button
				  Sleep(2000)
				  _Click(60, 100)	; Vortex Back Button
				  Sleep(1000)
				  Return False
			   EndIf
		 EndSwitch
	  EndIf
   WEnd
EndFunc


Func _UseRaidOrbs()
   Local $Counter, $ClickPosition, $PartyConfirmed = False, $VortexTimeOut = "NONE", $FirstTimeOut = False, $SecondTimeOut = False
   While $InfiniteLoop
	  GUICtrlSetData($DebugBox, "_UseRaidOrbs")
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 If _CheckForInterrupt($Raid) Then
			Return False
		 EndIf
		 Switch _WhereAmI($Raid)
			Case $HomeScreen
			   _Click(160, 550)	; Vortex
			Case $OutOfRaidOrbs, $OutOfNRG
			   _Click(175, 625)	; No button
			   Sleep(1000)
			   _Click(60, 240)
			   Sleep(1000)
			   _Click(60, 100)
			   _GetHomeScreen()
			   Return True
			Case $VortexMainPage
			   If IsNumber($RaidBanner) Then	; Raid banner selected by position, somewhat dangerous because it could change unexpectedly
				  If $RaidBanner > 3 Then
					 For $Counter = 1 TO ($RaidBanner - 3)
						_ClickDrag(300, 500, 300, 300, 10) ; NOT TESTED YET
						Sleep(1000)
					 Next
					 $ClickPosition = 3
				  Else
					 $ClickPosition = $RaidBanner
				  EndIf
				  _Click(300, 140 + ($ClickPosition * 230))	; 370, 600, 830 are the 3 positions
			   Else
				  If $VortexTimeOut = "NONE" Then
					 $VortexTimeOut = _DateAdd("s", 90, _NowCalc())
					 $FirstTimeOut = False
					 $SecondTimeOut = False
				  ElseIf _NowCalc() > $VortexTimeOut Then	; We couldn't find the raid banner within 90 seconds, something is wrong - raid is over or there is a problem with the banner image
					 _SendMail("Unable to locate raid banner", False)
					 Return True		; Mark the raid check as completed so we can move on to other actions
				  ElseIf _NowCalc() > _DateAdd("s", -60, $VortexTimeOut) AND NOT $SecondTimeOut Then
					 $SecondTimeOut = True
					 _Click(60, 100)	; Back button, return to home page to reset the vortex page
					 Sleep(2000)
				  ElseIf _NowCalc() > _DateAdd("s", -30, $VortexTimeOut) AND NOT $FirstTimeOut Then
					 $FirstTimeOut = True
					 _Click(60, 100)	; Back button, return to home page to reset the vortex page
					 Sleep(2000)
				  Else
					 For $Counter = 1 TO 3	; More than 3 scroll downs will have an increased delay as it rechecks with _WhereAmI()
						Sleep(1000)
						If _CheckForImage($RaidBanner, $x, $y) Then
						   _ClickItem("button", $x, $y)
						   Sleep(1000)
						   $VortexTimeOut = "NONE"
						   $FirstTImeOut = False
						   $SecondTimeOut = False
						   ExitLoop
						Else
						   _ClickDrag(300, 500, 300, 300, 10)	; NOT TESTED YET
						EndIf
					 Next
				  EndIf
			   EndIf
			Case $RaidBattleSelectionPage, $RaidTitle
			   _Click(300, 620)	; Top battle in the list (presumably ELT)
;		 	Case $RaidMissionsPage
;				_Click(300, 935)
			Case $RaidFriendPage, $TMFriend	; We could get $TMFriend returned here, it is the same (as of when this was written)
			   _Click(300, 385)	; Take the first friend in the list. This could be much more complicated if a specific friend is needed.
			Case $RaidDepartPage
			   If NOT $PartyConfirmed Then
				  If NOT _CheckForImage($RaidPartySelected, $x, $y) Then
					 _GetParty($RaidPartySelected)
				  EndIf
				  $PartyConfirmed = True
			   EndIf
			   _Click(300, 935)
			Case $RaidInBattle, "In Battle"
			   _BattleSequence($Raid)
			Case Else
			   If _GetHomeScreen() Then
				  _Click(160, 550)		; Vortex
			   Else
				  Return False
			   EndIf
		 EndSwitch
	  EndIf
   WEnd
EndFunc


Func _NextDailyReset()
   Local $DailyResetTime
   If $DailyResetHour < 10 Then
	  $DailyResetTime = "0" & $DailyResetHour & ":00:00"
   Else
	  $DailyResetTime = $DailyResetHour & ":00:00"
   EndIf
   If @HOUR >= $DailyResetHour Then
	  Return _DateAdd("d", 1, _NowCalcDate()) & " " & $DailyResetTime
   Else
	  Return _NowCalcDate() & " " & $DailyResetTime
   EndIf
EndFunc


Func _ArenaWeeklyStop()
   If $ArenaWeeklyStop Then
	  If @WDAY = $WeeklyResetDay Then	; This would need more coding if it becomes possible to need to stop before midnight on the previous day
		 If _DateAdd("h", $ArenaWeeklyStopTime, _NowCalc()) > _NextDailyReset() Then	; We are within $ArenaWeeklyStopTime hours of daily reset
			If _NowCalc() < _NextDailyReset() Then		; but haven't reached it yet
			   If _DateAdd("d", 1, $LastArenaWeeklyStopTime) < _NowCalc() Then		; We haven't stopped the arena within the last day
				  $Enabled[$Arena] = False
				  $StartTime[$Arena] = _DateAdd("h", 5, _NowCalc())	; Auto-start Arena again in 5 hours in case we don't get a chance to use the saved orbs
				  $LastArenaWeeklyStopTime = _NowCalc()
				  GUICtrlSetState($EnabledCheckbox[$Arena], $GUI_UNCHECKED)
				  GUICtrlSetState($NextOrbTimeBox[$Arena], $GUI_DISABLE)
				  GUICtrlSetState($StartCheckbox[$Arena], $GUI_CHECKED)
				  GUICtrlSetState($StartTimeBox[$Arena], $GUI_ENABLE)
				  GUICtrlSetData($StartTimeBox[$Arena], _SetTimeBox($StartTime[$Arena], True))
				  IniWrite($IniFile, "Initialize", $FriendlyName[$Arena] & " Enabled", $Enabled[$Arena])
				  IniWrite($IniFile, "Initialize", $FriendlyName[$Arena] & " Start Time", $StartTime[$Arena])
				  IniWrite($IniFile, "Initialize", "Last Arena Weekly Stop Time", $LastArenaWeeklyStopTime)

				  Return True
			   EndIf
			EndIf
		 EndIf
	  EndIf
   Else
	  Return False
   EndIf
EndFunc


Func _ArenaOrbHoldTime()
   If $DailyResetHour = $ArenaOrbPreserveTime Then
	  If @WDAY = $WeeklyResetDay AND @HOUR < $DailyResetHour Then
		 Return True
	  EndIf
   ElseIf $DailyResetHour > $ArenaOrbPreserveTime Then
	  If @WDAY = $WeeklyResetDay AND @HOUR < $DailyResetHour Then
		 Return True
	  ElseIf $WeeklyResetDay > 1 Then
		 If @WDAY = $WeeklyResetDay - 1 AND @HOUR > $DailyResetHour + (23 - $ArenaOrbPreserveTime) Then 	; Day before falls into the window
			Return True
		 EndIf
	  Else
		 If @WDAY = 6 AND @HOUR > $DailyResetHour + (23 - $ArenaOrbPreserveTime) Then						; Day before falls into the window and wraps around on @WDAY
			Return True
		 EndIf
	  EndIf
   EndIf
   Return False
EndFunc


Func _UseArenaOrbs()
   If ($PreserveArenaOrbs AND _ArenaOrbHoldTime()) OR _ArenaWeeklyStop() Then
	  Return True	; We are in the time period just before weekly reset and are preserving orbs to be used on the next week
   EndIf
   While $InfiniteLoop
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_UseArenaOrbs")
		 If _CheckForInterrupt($Arena) Then
			Return False
		 EndIf
		 Switch _WhereAmI($Arena)
			Case $HomeScreen
			   _Click(75, 775)	; Arena
			Case $OutOfNRG
			   _Click(335, 670)	; Back button
			   Sleep(1000)
			   _Click(60, 240)
			   Sleep(1000)
			   _Click(60, 240)
			   _GetHomeScreen()
			   Return True
			Case $ArenaMainPage & "0"
			   _Click(60, 240)
			   Return True
			Case $ArenaRulesPage & "0"
			   _Click(60, 240)
			   Sleep(1000)
			   _Click(60, 240)
			   Return True
			Case $ArenaMainPage & "1", $ArenaRulesPage & "1"
			   _Click(300, 1000)
			Case $ArenaSelectionPage
			   _Click(300, 560)
			Case $ArenaOpponentConfirm
			   _Click(400, 615)
			Case $ArenaBeginButton
			   _Click(300, 915)
			Case $ArenaInBattle, "In Battle"
			   _BattleSequence($Arena)
			Case Else
			   If _GetHomeScreen() Then
				  _Click(75, 775)
			   Else
				  Return False
			   EndIf
		 EndSwitch
	  EndIf
   WEnd
EndFunc


Func _Click($x, $y)
   _CheckWindowPosition()
   MouseMove($EmulatorX1 + $x, $EmulatorY1 + $y, 0)
   Sleep(10)		; Additional delay needed to make sure some clicks are registered properly, mouseclickdowndelay also higher than default
   MouseClick("main", $EmulatorX1 + $x, $EmulatorY1 + $y, 1, 0)
EndFunc


Func _ClickHold($x, $y, $HoldTime = 1000)
   _CheckWindowPosition()
   MouseMove($EmulatorX1 + $x, $EmulatorY1 + $y, 0)
   Sleep(100)		; Additional delay needed to make sure some clicks are registered properly, mouseclickdowndelay also higher than default
   MouseDown("main")
   Sleep($HoldTime)
   MouseUp("main")
EndFunc


Func _ClickDrag($x1, $y1, $x2, $y2, $DragSpeed)
   _CheckWindowPosition()
   MouseClickDrag("main", $EmulatorX1 + $x1, $EmulatorY1 + $y1, $EmulatorX1 + $x2, $EmulatorY1 + $y2, $DragSpeed)
EndFunc


Func _StartTMFarm($AdditionalParameter = "")
   If $FastTMFarm <> "OFF" Then
	  If NOT ProcessExists($FastTMFarm) Then	; We think its running, but its not, reset variable
		 $FastTMFarm = "OFF"
	  EndIf
   EndIf
   If $FastTMFarm = "OFF" AND $Enabled[$TMFarm] AND NOT $ScriptPaused Then
	  $FastTMFarm = Run("FastTMFarm.exe " & $TMFarmProgressCheckInterval & " " & $AdditionalParameter)
   EndIf
EndFunc


Func _StopTMFarm()
   Local $LoopCount = 0
   If $FastTMFarm <> "OFF" Then
	  _FileCreate($TMQuitFile)
	  If @error Then msgbox(64,"", @error)
	  While ProcessExists($FastTMFarm)
		 $LoopCount = $LoopCount + 1
		 Sleep(500)
		 If $LoopCount = 20 Then		; Waited too long, time to force-close
			ProcessClose($FastTMFarm)
		 ElseIf $LoopCount = 120 Then
			_FatalError("_StopTMFarm - Failed to stop fast farming")
		 EndIf
	  Wend
	  $FastTMFarm = "OFF"
   EndIf
EndFunc


Func _ReadDataFile($Section, $ActionNumber)
   Local $Data = IniRead($IniFIle, $Section, $ActionNumber, "ERROR")
   If $Data = "ERROR" Then
	  Return False
   Else
	  Return StringLower(StringStripWS($Data, 8))	; Removes all spaces, spaces are not supported in any part of the battle sections, returns in all lower case
   EndIf
EndFunc


Func _HandleBattle($BattleType)
   Local $CurrentActionNumber = 1, $Done, $CurrentUnit, $CurrentAction, $SplitCurrentAction, $TestCondition
   Local $OnHoldActionNumber[1], $UnitSetUp[7]
   $OnHoldActionNumber[0] = 0
   For $CurrentUnit = 1 TO 6
	  $UnitSetUp[$CurrentUnit] = False
   Next
   While $InfiniteLoop
	  GUICtrlSetData($DebugBox, "_HandleBattle " & $BattleType)
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 _TeamViewerCheck()
;	  	If _CheckForInterrupt($BattleType) Then
;		 	Return False
;	  	EndIf
		 $Done = False
		 While NOT $Done
			$CurrentAction = _ReadDataFile($FriendlyName[$BattleType], $CurrentActionNumber)
			If NOT $CurrentAction Then
			   If $CurrentActionNumber = 1 Then
				  _FatalError("_HandleBattle(" & $FriendlyName[$BattleType] & ") - No data available")
			   ElseIf $OnHoldActionNumber[0] > 0 Then
				  $CurrentActionNumber = $OnHoldActionNumber[$OnHoldActionNumber[0]]
				  $OnHoldActionNumber[0] = $OnHoldActionNumber[0] - 1
				  ReDim $OnHoldActionNumber[$OnHoldActionNumber[0] + 1]
			   Else
				  Return True
			   EndIf
			Else
			   $Done = True
			EndIf
		 WEnd
		 $SplitCurrentAction = StringSplit($CurrentAction, ";,")
		 $CurrentActionNumber = $CurrentActionNumber + 1	; Have to do this early because conditionals will break if the number is added at the end of the loop
		 Switch $SplitCurrentAction[1]
			Case "sleep"
			   If $SplitCurrentAction[0] <> 1 Then
				  If IsNumber($SplitCurrentAction[2]) Then
					 Sleep($SplitCurrentAction[2])
				  Else
					 Sleep(1000)
				  EndIf
			   Else
				  Sleep(1000)
			   EndIf
			Case "select"
			   If $SplitCurrentAction[0] > 2 Then
				  If NOT $UnitSetUp[$SplitCurrentAction[2]] Then	; We won't try to change the same unit we already set up, this allows backup actions if the primary is unavailable
					 If _SelectAbility($SplitCurrentAction[2], StringRight($CurrentAction, StringLen($CurrentAction) - (StringLen($SplitCurrentAction[1]) + StringLen($SplitCurrentAction[2]) + 2))) Then
						$UnitSetUp[$SplitCurrentAction[2]] = True
					 EndIf
				  EndIf
			   EndIf
			Case "activate"
			   For $CurrentUnit = 2 TO $SplitCurrentAction[0]
				  _ActivateUnit($SplitCurrentAction[$CurrentUnit])
			   Next
			Case "end"
			   Return True
			Case "ifnotavailable", "ifavailable", "ifnotsetup", "ifsetup"
			   If $SplitCurrentAction[0] > 3 Then
				  If IsNumber($SplitCurrentAction[2]) Then
					 If $SplitCurrentAction[2] >= 1 AND $SplitCurrentAction[2] <= 6 Then
						Switch $SplitCurrentAction[1]
						   Case "ifnotavailable"
							  $TestCondition = NOT _IsUnitAvailable($SplitCurrentAction[2])
						   Case "ifavailable"
							  $TestCondition = _IsUnitAvailable($SplitCurrentAction[2])
						   Case "ifnotsetup"
							  $TestCondition = NOT $UnitSetup[$SplitCurrentAction[2]]
						   Case "ifsetup"
							  $TestCondition = $UnitSetup[$SplitCurrentAction[2]]
						   Case "ifdead"
							  ; To be created - function that checks for dead unit(s) specified or "any", "1/2/3", "all/1/2/3", "any/1/2/3" as available option
						   Case "ifstopped"
							  ; To be created
						   Case "ifailment"
							  ; To be created
						   Case "ifnomp"
							  ; To be created
						EndSwitch
						If $TestCondition Then
						   Switch $SplitCurrentAction[3]
							  Case "skipto"
								 If IsNumber($SplitCurrentAction[4]) Then
									$CurrentActionNumber = $SplitCurrentAction[4]
								 ElseIf $SplitCurrentAction[4] = "end" Then
									Return True
								 EndIf
							  Case "goto"
								 If IsNumber($SplitCurrentAction[4]) Then
									$OnHoldActionNumber[0] = $OnHoldActionNumber[0] + 1
									ReDim $OnHoldActionNumber[$OnHoldActionNumber[0] + 1]
									$OnHoldActionNumber[$OnHoldActionNumber[0]] = $CurrentActionNumber
									$CurrentActionNumber = $SplitCurrentAction[4]
								 ElseIf $SplitCurrentAction[4] = "end" Then
									Return True
								 EndIf
						   EndSwitch
						EndIf
					 EndIf
				  EndIf
			   EndIf
		 EndSwitch
	  EndIf
   WEnd
EndFunc


Func _BattleSequence($BattleType, $SpeedClick = False)
   Local $Done = False, $x1, $y1, $TurnTimeOut, $TurnTimedOut, $TurnChange, $CurrentTime, $CurrentTurn = 1, $CurrentUnit, $CurrentLocation, $ArenaPauseDone = False
   Local $NextFullCheck
   While $InfiniteLoop
	  GUICtrlSetData($DebugBox, "_BattleSequence " & $BattleType & " L1")
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 If _CheckForInterrupt($BattleType) Then
			_StopTMFarm()
		 EndIf
		 If $BattleType = $Arena AND NOT $ArenaPauseDone Then	; Arena briefly shows an active repeat button when first loading, even when going second, needs a pause on initial detection
			If _CheckForImageExact($ActiveRepeatButton, $x1, $y1) AND _CheckForImageExact($ActiveMenuButton, $x1, $y1) Then
			   Sleep(5000)
			   $ArenaPauseDone = True
			EndIf
		 ElseIf _CheckForImageExact($ActiveRepeatButton, $x1, $y1) AND _CheckForImageExact($ActiveMenuButton, $x1, $y1) Then
			; Safe to begin attack processes
			If $BattleType = $TMFarm Then ; Skipping status checks, they should never be needed in a TM farm scenario
			   _ActivateUnit(1)
			   Sleep(200)
			   _ActivateUnit(3)
			   If $Dalnakya Then
				  Sleep(200)
				  _ActivateUnit(2)
				  Sleep(200)
				  _ActivateUnit(4)
				  Sleep(200)
				  _ActivateUnit(5)
				  Sleep(200)
				  _ActivateUnit(6)
			   EndIf
			ElseIf $BattleType = $Arena OR $BattleType = $Raid Then
			   Sleep(1000)
			   _HandleBattle($BattleType)
			EndIf
			;After attacking
			$TurnChange = False
			$TurnTimeOut = _DateAdd("n", 1, _NowCalc())
			$NextFullCheck = _DateAdd("s", 10, _NowCalc())
			$TurnTimedOut = False
			While NOT $TurnChange	; We will stay in this loop until our turn or the battle is over
			   GUICtrlSetData($DebugBox, "_BattleSequence " & $BattleType & " L2")
			   If $ScriptPaused Then
				  _ShowPauseMessage()
			   Else
				  _HidePauseMessage()
				  If _CheckForInterrupt($BattleType) Then
					 _StopTMFarm()
				  EndIf
				  $CurrentTime = _NowCalc()
;					If _CheckForImageExact($InactiveRepeatButton, $x1, $y1) OR _CheckForImageExact($InactiveMenuButton, $x1, $y1) Then
				  If _IsUnitAvailable(1) Then
					 $CurrentTurn = $CurrentTurn + 1
					 $TurnChange = True
				  ElseIf $BattleType <> $TMFarm OR $CurrentTime > $NextFullCheck Then
					 If _IsUnitAvailable(2) Then
						$CurrentTurn = $CurrentTurn + 1
						$TurnChange = True
					 ElseIf _IsUnitAvailable(3) Then
						$CurrentTurn = $CurrentTurn + 1
						$TurnChange = True
					 ElseIf _IsUnitAvailable(4) Then
						$CurrentTurn = $CurrentTurn + 1
						$TurnChange = True
					 ElseIf _IsUnitAvailable(5) Then
						$CurrentTurn = $CurrentTurn + 1
						$TurnChange = True
					 ElseIf _IsUnitAvailable(6) Then
						$CurrentTurn = $CurrentTurn + 1
						$TurnChange = True
					 EndIf
				  EndIf
				  If _CheckForImage($ArenaMainPage, $x1, $y1) Then
					 Return True
				  ElseIf _CheckForImage($BattleResultsPage, $x1, $y1) Then
					 Return True
				  ElseIf $CurrentTime > $NextFullCheck Then
					 If _CheckForImage($ConnectionError, $x1, $y1) Then
						If _CheckForImage($OKButton, $x1, $y1) Then
						   _ClickItem("Button", $x1, $y1)
						   Return True
						Else
						   _FatalError("_BattleSequence - Connection Error Missing OK Button")
						EndIf
					 ElseIf _CheckForImage($LapisContinue, $x1, $y1) Then
						If _CheckForImage($ContinueNoButton, $x1, $y1) Then
						   _ClickItem("Button", $x1, $y1)
						   Sleep(2000)
						   If _CheckForImage($LapisContinueConfirm, $x1, $y1) Then
							  If _CheckForImage($ContinueConfirmButton, $x1, $y1) Then
								 _ClickItem("Button", $x1, $y1)
								 Return True
							  Else
								 _FatalError("_BattleSequence - Confirm no lapis continue button missing")
							  EndIf
						   Else
							  _FatalError("_BattleSequence - Confirm no lapis continue message missing")
						   EndIf
						Else
						   _FatalError("_BattleSequence - Lapis continue no button missing")
						EndIf
					 Else
						$CurrentLocation = _WhereAmI($BattleType)
						Switch $CurrentLocation
						   Case $ArenaInBattle
							  If $BattleType <> $Arena Then
								 Return False
							  EndIf
						   Case $RaidInBattle
							  If $BattleType <> $Raid Then
								 Return False
							  EndIf
						   Case $TMInBattle
							  If $BattleType <> $TMFarm Then
								 Return False
							  EndIf
						   Case "In Battle"
							  ; No action required
						   Case Else
							  Return False	; We are not in the battle anymore, we need to get out of this function
						EndSwitch
					 EndIf
					 $NextFullCheck = _DateAdd("s", 10, _NowCalc())
				  ElseIf $CurrentTime > $TurnTimeOut Then
					 If _CheckForImageExact($ActiveRepeatButton, $x1, $y1) Then
						If $TurnTimedOut Then
						   _FatalError("_BattleSequence - Turn timed out a second time after sending all units")
						Else
						   $TurnTimedOut = True
						   For $CurrentUnit = 1 TO 6
							  _ActivateUnit($CurrentUnit)
							  Sleep(250)
						   Next
						   $TurnTimeOut = _DateAdd("n", 1, _NowCalc())
						EndIf
					 Else	; We are no longer in the battle, something is wrong
						Return False
					 EndIf
				  EndIf
				  If $BattleType = $Arena Then
					 _Click(300, 100)	; Click at the top middle to keep things moving
;					 If NOT _CheckForImage($HomeScreen, $x, $y) Then
;						If NOT _CheckForImage($ArenaMainPage, $x, $y) Then
;						   If NOT _CheckForImage($ArenaSelectionPage, $x, $y) Then
;							  _Click(360, 920)		; Click the OK buttons at the end of an arena battle, imagesearch fails to find them sometimes
;							  _Click(360, 965)		; This should not be done on the home screen, arena main page, or arena opponent selection page
;						   Else
;							  Return True
;						   EndIf
;						Else
;						   Return True
;						EndIf
;					 Else
;						Return False
;					 EndIf
				  ElseIf $BattleType = $Raid Then
					 _Click(300, 100)	; Click at the top middle to keep things moving
					 Sleep(100)
					 _Click(300, 100)
					 Sleep(100)
					 _Click(300, 100)
					 If _CheckForImage($RaidNextButton, $x, $y) Then
						_ClickItem("button", $x, $y)
					 ElseIf _CheckForImage($RaidNextButton2, $x, $y) Then
						_ClickItem("button", $x, $y)
					 ElseIf _CheckForImage($RaidNextButton3, $x, $y) Then	; This was not updated for v3.4
						_ClickItem("button", $x, $y)
					 ElseIf _CheckForImage($RaidNextButton4, $x, $y) Then	; This was not updated for v3.4
						_ClickItem("button", $x, $y)
					 EndIf
;			   If NOT _CheckForImage($ActiveMenuButton, $x, $y) Then
;				  If NOT _CheckForImage($RaidBattleSelectionPage, $x, $y) Then	; This should not be done on the battle selection page or in battle
;					 If NOT _CheckForImage($VortexMainPage, $x, $y) Then		; Can't be on the main vortex page either, only relevant for _WhereAmI
;						_Click(360, 920)	; Click where a next button will appear
;					 Else
;						Return $VortexMainPage
;					 EndIf
;				  Else
;					 Return True
;				  EndIf
;			   EndIf
				  EndIf
;			_Click(470, 70)	; Click in the top right corner to keep things moving since finding the arena win/loss pages is unreliable
			   EndIf
			WEnd
		 ElseIf _CheckForImage($BattleResultsPage, $x1, $y1) Then
			Return True
		 ElseIf _CheckForImage($ArenaResultsOKButton, $x1, $y) Then
			_Click(300, 920)
			Return True
		 Else
			$CurrentLocation = _WhereAmI($BattleType)
			Switch $CurrentLocation
			   Case $ArenaInBattle
				  If $BattleType <> $Arena Then
					 Return False
				  EndIf
			   Case $RaidInBattle
				  If $BattleType <> $Raid Then
					 Return False
				  EndIf
			   Case $TMInBattle
				  If $BattleType <> $TMFarm Then
					 Return False
				  EndIf
			   Case "In Battle"
				  ; No action required
			   Case $OutOfNRG
				  Return True
			   Case Else
				  Return False	; We are not in the battle anymore, need to get out of this function
			EndSwitch
		 EndIf
		 If $BattleType = $Arena Then
			_Click(300, 100)	; Click in neutral area to keep things moving
;			If NOT _CheckForImage($HomeScreen, $x, $y) Then
;			   If NOT _CheckForImage($ArenaMainPage, $x, $y) Then
;				  If NOT _CheckForImage($ArenaSelectionPage, $x, $y) Then
;					 _Click(360, 920)		; Click the OK buttons at the end of an arena battle, imagesearch fails to find them sometimes
;					 _Click(360, 965)		; This should not be done on the home screen, arena main page, or arena opponent selection page
;				  Else
;					 Return True
;				  EndIf
;			   Else
;				  Return True
;			   EndIf
;			Else
;			   Return False
;			EndIf
		 ElseIf $BattleType = $Raid Then
			_Click(300, 100)	; Click in a neutral area to keep things moving
			Sleep(100)
			_Click(300, 100)
			Sleep(100)
			_Click(300, 100)
			If _CheckForImage($RaidNextButton, $x, $y) Then
			   _ClickItem("button", $x, $y)
			ElseIf _CheckForImage($RaidNextButton2, $x, $y) Then
			   _ClickItem("button", $x, $y)
			ElseIf _CheckForImage($RaidNextButton3, $x, $y) Then
			   _ClickItem("button", $x, $y)
			ElseIf _CheckForImage($RaidNextButton4, $x, $y) Then
			   _ClickItem("button", $x, $y)
			EndIf
;		 If NOT _CheckForImage($ActiveMenuButton, $x, $y) Then
;			If NOT _CheckForImage($RaidBattleSelectionPage, $x, $y) Then	; This should not be done on the battle selection page or in battle
;			   _Click(360, 920)	; Click where a next button will appear
;			Else
;			   Return True
;			EndIf
;		 EndIf
		 EndIf
;	  _Click(470, 70)	; Click in the top right corner to keep things moving since finding the arena win/loss pages is unreliable
	  EndIf
   WEnd
EndFunc


Func _CancelAbilitySelection()
   While $InfiniteLoop
	  If _CheckForImage($AbilityBackButton, $x, $y) Then
		 _Click(500, 978)	; Tight fit to make sure this can't accidentally click menu or unit 6 if the back button disappears
		 Sleep(1000)
	  Else
		 Return True
	  EndIf
   WEnd
EndFunc


Func _SelectAbility($UnitNumber, $Ability)		; Select an ability for a unit, based on either position or picture
   Local $x1, $y1, $x2, $y2, $CurrentAbility, $ActiveAbility, $DragNeeded, $PreviousMethod = "None", $CurrentMethod
   Local $MoveCounter, $AbilityCounter, $FirstSlotShown = 1, $MovePosition = 1, $MoveDirection = "Down"
   Local $CurrentAttempt
   Local Const $DragSpeed = 15
   Local Const $DragDistance = 97		; 97 is about 1 ability block, used for selecting by ability Number
   Local Const $SlowDragDistance = 49	; Used for image checking, should be lower than $DragDistance for greater accuracy
   Local Const $MaxMoves = 14
   Local $AbilityList = StringSplit($Ability, ";")	; Split the list of abilities needed into an array
   If NOT _IsUnitAvailable($UnitNumber) Then
	  Return False
   EndIf
;   _CheckWindowPosition()
   If $UnitNumber = 1 OR $UnitNumber = 2 OR $UnitNumber = 3 Then
	  $x1 = 200
   ElseIf $UnitNumber = 4 OR $UnitNumber = 5 OR $UnitNumber = 6 Then
	  $x1 = 400
   Else
	  Return False	; Bad unit number provided
   EndIf
   If $UnitNumber = 1 OR $UnitNumber = 4 Then
	  $y1 = 700
   ElseIf $UnitNumber = 2 OR $UnitNumber = 5 Then
	  $y1 = 800
   ElseIf $UnitNumber = 3 OR $UnitNumber = 6 Then
	  $y1 = 900
   EndIf
   For $CurrentAbility = 1 TO $AbilityList[0]
	  $ActiveAbility = StringSplit($AbilityList[$CurrentAbility], ",")
	  $DragNeeded = False
	  Switch StringLower(StringStripWS($ActiveAbility[1], 3))
		 Case "attack"
			$x2 = $x1
			$y2 = $y1 - 100
			$DragNeeded = True
		 Case "defend"
			$x2 = $x1
			$y2 = $y1 + 100
			$DragNeeded = True
		 Case "item"
			$x2 = $x1 - 100
			$y2 = $y1
			$DragNeeded = True
		 Case "ability"
			$x2 = $x1 + 100
			$y2 = $y1
			If NOT _CheckForImage($AbilityBackButton, $x, $y) Then	; We don't need to drag if the back button is present
			   If $CurrentAbility > 1 Then	; We failed to properly select the ability, but we did select something
				  ; this could be changed to remove the selection first if desired
				  ; it was left like this to compensate for disabled multi-abilities in the arena, it will use a single cast this way
				  Return False
			   EndIf
			   $DragNeeded = True
			EndIf
		 Case "select"
			If $ActiveAbility[0] > 1 Then
			   If StringLower(StringStripWS($ActiveAbility[2], 3)) = "any" Then
				  $CurrentAttempt = 1
				  While $InfiniteLoop
					 _ActivateUnit($CurrentAttempt)
					 Sleep(500)
					 If NOT _CheckForImage($SelectOpponentButton, $x, $y) Then
						ExitLoop
					 EndIf
					 $CurrentAttempt = $CurrentAttempt + 1
					 If $CurrentAttempt = 7 Then
						_CancelAbilitySelection()
						Return False
					 EndIf
				  WEnd
			   ElseIf IsNumber($ActiveAbility[2]) Then
				  If $ActiveAbility[2] >= 1 AND $ActiveAbility[2] <= 6 Then
					 _ActivateUnit($ActiveAbility[2])
					 If NOT _CheckForImage($SelectOpponentButton, $x, $y) Then
						_CancelAbilitySelection()
						Return False
					 EndIf
				  Else
					 _CancelAbilitySelection()
					 Return False
				  EndIf
			   Else
				  _CancelAbilitySelection()
				  Return False
			   EndIf
			Else
			   _CancelAbilitySelection()
			   Return False
			EndIf
	  EndSwitch
	  If $DragNeeded Then
		 _ClickDrag($x1, $y1, $x2, $y2, $DragSpeed)
	  EndIf
	  Switch StringLower(StringStripWS($ActiveAbility[1], 3))
		 Case "attack", "defend", "select"
			If $CurrentAbility = $AbilityList[0] Then
			   Return True
			EndIf
		 Case "ability", "additional"
			If $ActiveAbility[0] > 1 Then
;			   If StringInStr($ActiveAbility[2], ".") Then		; There will need to be a . in any picture file name
;				  $CurrentMethod = "Picture"
			   If StringIsDigit(StringStripWS($ActiveAbility[2], 3)) Then
				  $CurrentMethod = "Number"
			   Else
				  $CurrentMethod = "OCR"	; This is not working and has been abandoned
			   EndIf
			   If $CurrentMethod <> $PreviousMethod AND $PreviousMethod <> "None" Then
				  For $MoveCounter = 1 TO Int($MaxMoves / 2.5)
					 _ClickDrag(120, 600, 120, 800, $DragSpeed)	; Scroll Back Up - quickly ; NOT TESTED YET
					 Sleep(50)
				  Next
				  $FirstSlotShown = 1
				  $MovePosition = 1
				  $MoveDirection = "Down"
			   EndIf
			Else
			   _CancelAbilitySelection()
			   Return False
			EndIf
			Switch $CurrentMethod
			   Case "Number"
				  While $InfiniteLoop
					 If $ActiveAbility[2] >= $FirstSlotShown AND $ActiveAbility[2] <= $FirstSlotShown + 5 Then
						Sleep(500)
						_ActivateAbility($ActiveAbility[2] - ($FirstSlotShown - 1))
						Sleep(1000)
						If $CurrentAbility = $AbilityList[0] Then
						   If _CheckForImage($AbilityBackButton, $x, $y) Then
							  _CancelAbilitySelection()
							  Return False
						   Else
							  Return True
						   EndIf
						Else
						   ExitLoop
						EndIf
					 EndIf
					 If $ActiveAbility[2] > $FirstSlotShown + 5 Then
						_ClickDrag(120, 780, 120, 780 - $DragDistance, $DragSpeed)	; Scroll Down
						$FirstSlotShown = $FirstSlotShown + 2
					 Else
						_ClickDrag(120, 780 - $DragDistance, 120, 780, $DragSpeed)	; Scroll Back Up
						$FirstSlotShown = $FirstSlotShown - 2
					 EndIf
				  WEnd
			   Case "OCR"		; This does not work well either, abandoned
				  For $MoveCounter = 1 TO $MaxMoves
					 If _OCRAbilityCheck($ActiveAbility[2]) Then
						_ClickItem("button", $x, $y)
						Sleep(1000)
						If $CurrentAbility = $AbilityList[0] Then
						   If _CheckForImage($AbilityBackButton, $x, $y) Then
							  _CancelAbilitySelection()
							  Return False
						   Else
							  Return True
						   EndIf
						Else
						   ExitLoop
						EndIf
					 EndIf
					 If $MoveDirection = "Down" Then
						_ClickDrag(120, 780, 120, 780 - $DragDistance, $DragSpeed)	; Scroll Down
						$MovePosition = $MovePosition + 1
						If $MovePosition = $MaxMoves Then
						   $MoveDirection = "Up"
						EndIf
					 Else
						_ClickDrag(120, 780 - $DragDistance, 120, 780, $DragSpeed)	; Scroll Back Up
						$MovePosition = $MovePosition - 1
						If $MovePosition = 1 Then
						   $MoveDirection = "Down"
						EndIf
					 EndIf
				  Next
			   Case "Picture"				; This does not work well, pictures are unreliable, replaced with OCR
				  For $MoveCounter = 1 TO $MaxMoves
					 If _CheckForImage($ActiveAbility[2], $x, $y) Then
						_ClickItem("button", $x, $y)
						Sleep(1000)
						If $CurrentAbility = $AbilityList[0] Then
						   If _CheckForImage($AbilityBackButton, $x, $y) Then
							  _CancelAbilitySelection()
							  Return False
						   Else
							  Return True
						   EndIf
						Else
						   ExitLoop
						EndIf
					 EndIf
					 If $MoveDirection = "Down" Then
						_ClickDrag(120, 780, 120, 780 - $SlowDragDistance, $DragSpeed)	; Scroll Down, half speed
						$MovePosition = $MovePosition + 1
						If $MovePosition = $MaxMoves Then
						   $MoveDirection = "Up"
						EndIf
					 Else
						_ClickDrag(120, 780 - $SlowDragDistance, 120, 780, $DragSpeed)	; Scroll Back Up, half speed
						$MovePosition = $MovePosition - 1
						If $MovePosition = 1 Then
						   $MoveDirection = "Down"
						EndIf
					 EndIf
				  Next
			EndSwitch
	  EndSwitch
   Next
   Sleep(1000)
   If _CheckForImage($AbilityBackButton, $x, $y) Then
	  _CancelAbilitySelection()
	  Return False
   Else
	  Return True
   EndIf
EndFunc


Func _OCRAbilityCheck($AbilityName)
   Local $CurrentCheckX, $CurrentCheckY, $xPos, $yPos
   _GDIPlus_Startup() ; Initialize the GDIPlus functionality
   For $CurrentCheckX = 1 TO 2		; Unit positions going across
	  If $CurrentCheckX = 1 Then
		 $xPos = 95
	  Else
		 $xPos = 375
	  EndIf
	  $yPos = 675
	  For $CurrentCheckY = 1 TO 3		; Unit positions going down
;		 msgbox(64, StringLower(StringStripWS($AbilityName, 8)), StringLower(StringStripWS(_OCR($xPos, $yPos, 175, 24), 8)))
		 If StringLower(StringStripWS(_OCR($xPos, $yPos, 175, 24), 8)) = StringLower(StringStripWS($AbilityName, 8)) Then
			Return True
		 EndIf
		 $yPos = $yPos + 96
	  Next
   Next
   _GDIPlus_Shutdown() ; Shut down the GDIPlus functionality
   Return False
EndFunc


Func _IsUnitAvailable($UnitNumber)
   Local $TopSide, $BottomSide, $LeftSide, $RightSide, $x1 = $x, $y1 = $y		;x1, y1 maybe irrelevant now
   If $UnitNumber = 1 OR $UnitNumber = 2 OR $UnitNumber = 3 Then
	  $LeftSide = 0
	  $RightSide = 290
   ElseIf $UnitNumber = 4 OR $UnitNumber = 5 OR $UnitNumber = 6 Then
	  $LeftSide = 290
	  $RightSide = 570
   Else
	  Return False	; Bad unit number provided
   EndIf
   If $UnitNumber = 1 OR $UnitNumber = 4 Then
	  $TopSide = 660
	  $BottomSide = 760
   ElseIf $UnitNumber = 2 OR $UnitNumber = 5 Then
	  $TopSide = 770
	  $BottomSide = 860
   ElseIf $UnitNumber = 3 OR $UnitNumber = 6 Then
	  $TopSide = 870
	  $BottomSide = 960
   EndIf
   ; Each unit's sword icon used to indicate they are available is slightly different, so there is a picture for each one
   If _CheckForImageArea("Unit_Enabled" & $UnitNumber & ".bmp", $x1, $y1, $LeftSide, $TopSide, $RightSide, $BottomSide) Then
 	  Return True
   Else
	  Return False
   EndIf
EndFunc


Func _ActivateUnit($UnitNumber)		; Numbered with 1-3 on the left and 4-6 on the right
   Local $x1, $y1
   If $UnitNumber = 1 OR $UnitNumber = 2 OR $UnitNumber = 3 Then
	  $x1 = 200
   Else
	  $x1 = 400
   EndIf
   If $UnitNumber = 1 OR $UnitNumber = 4 Then
	  $y1 = 700
   ElseIf $UnitNumber = 2 OR $UnitNumber = 5 Then
	  $y1 = 800
   Else
	  $y1 = 900
   EndIf
   _Click($x1, $y1)
EndFunc


Func _ActivateAbility($AbilityNumber)	; Numbered across then down, 1-2 on the first line, 3-4 on the second line, 5-6 on the third line
   Local $x1, $y1
   If $AbilityNumber = 1 OR $AbilityNumber = 3 OR $AbilityNumber = 5 Then
	  $x1 = 200
   Else
	  $x1 = 400
   EndIf
   If $AbilityNumber = 1 OR $AbilityNumber = 2 Then
	  $y1 = 700
   ElseIf $AbilityNumber = 3 OR $AbilityNumber = 4 Then
	  $y1 = 800
   Else
	  $y1 = 900
   EndIf
   _Click($x1, $y1)
EndFunc


Func _GetParty($DesiredPartyName)
   Local $x1, $y1, $WorkaroundImage
   For $Attempt = 1 TO 10
	  If _CheckForImage($DesiredPartyName, $x1, $y1) Then
		 Return True
	  Else
		 _Click(575, 405)	; Right party change arrow
;		 If _CheckForImage($BackButton, $x1, $y1) Then
;			_ClickItem("Party Change", $x1, $y1)
;		 Else
;			_FatalError("_GetParty - Missing back button")
;		 EndIf
	  EndIf
	  Sleep(2000)
   Next
   If _CheckForImage($BlankPartyText, $x1, $y1) Then  ; Workaround for bug that prevents the party names from displaying
	  Switch $DesiredPartyName
		 Case $TMFarmPartySelected
			$WorkaroundImage = $TMFarmPartyImage
		 Case $RaidPartySelected
			$WorkaroundImage = $RaidPartyImage
		 Case Else
			_FatalError("_GetParty - Missing case for " & $DesiredPartyName)
	  EndSwitch
	  For $Attempt = 1 TO 10
		 If _CheckForImage($WorkaroundImage, $x1, $y1) Then
			Return True
		 Else
			_Click(575, 405)	; Right party change arrow
		 EndIf
		 Sleep(2000)
	  Next
	  _FatalError("_GetParty - Failed to locate correct party in workaround mode")
   EndIf
   _FatalError("_GetParty - Failed to locate correct party")
EndFunc


Func _SellSnappers()
   Local $FilterApplied = False, $LoopCounter, $CurrentPositionX, $CurrentPositionY, $UnitsSelected, $UnitSelectionPosition
   _StopTMFarm()
   While $InfiniteLoop
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_SellSnappers")
		 If NOT $Enabled[$SellSnappers] Then
			_GetHomeScreen()
			Return False
		 EndIf
		 Switch _WhereAmI($SellSnappers)
			Case $HomeScreen
			   _Click(150, 1000)	; Units
			   Sleep(1000)
			Case $ManagePartyScreen
			   _Click(180, 700)		; View/Sell button
			   Sleep(1000)
			Case $ViewUnitsScreen
			   _Click(530, 270)		; Sell button
			   Sleep(1000)
			Case $SellUnitsScreen
			   $LoopCounter = 0
			   While NOT _CheckForImage($FusionUnitsTab, $x, $y)
				  _Click(330, 350)		; Fusion/Sale Units tab
				  Sleep(1000)
				  $LoopCounter = $LoopCounter + 1
				  If $LoopCounter > 15 Then
					 _FatalError("_SellSnappers: Unable to get Fusion/Sale Tab")
				  EndIf
			   WEnd
			   If NOT $FilterApplied Then
				  _Click(470, 260)	; Sort/Filter button
				  Sleep(1000)
			   ElseIf NOT _CheckForImage($FilteredList, $x, $y) Then		; Filter was removed, this means we hit the end of the list and clicked on remove filter, we are ready to sell and exit
				  Sleep(4000)	; Allow time to make sure it is not a false positive
				  If NOT _CheckForImage($FilteredList, $x, $y) Then	; Situation has not changed, continue
					 If $UnitsSelected > 0 Then
						_CompleteSnapperSale()
					 EndIf
					 _Click(50, 1000)	; Home button
					 Return True
				  EndIf
			   Else
				  $UnitSelectionPosition = $UnitSelectionPosition + 1
				  $UnitsSelected = $UnitsSelected + 1
				  If $UnitsSelected = 100 Then	; We have selected 99 units, we have to sell
					_CompleteSnapperSale()
					$UnitsSelected = 0
					$UnitSelectionPosition = 0
				  Else
					 If $UnitSelectionPosition = 16 Then
						_ClickDrag(300, 625, 300, 463, 15)		; Scroll down so the bottom row will have the unit we want
						$UnitSelectionPosition = 11
					 EndIf
					 For $LoopCounter = 0 TO 2
						Switch $LoopCounter	; Y position set each time through the loop, overwriting the previous one
						   Case 0
							  $CurrentPositionY = 440
						   Case 1
							  $CurrentPositionY = 610
						   Case 2
							  $CurrentPositionY = 770
;						   Case 3
;							  $CurrentPositionY = 880
						EndSwitch
						Switch $UnitSelectionPosition - ($LoopCounter * 5)	; will only hit when the Y position is correct, so we will have an exact match and need to end the loop
						   Case 1
							  $CurrentPositionX = 60
							  ExitLoop
						   Case 2
							  $CurrentPositionX = 175
							  ExitLoop
						   Case 3
							  $CurrentPositionX = 290
							  ExitLoop
						   Case 4
							  $CurrentPositionX = 405
							  ExitLoop
						   Case 5
							  $CurrentPositionX = 520
							  ExitLoop
						EndSwitch
					 Next
					 _Click($CurrentPositionX, $CurrentPositionY)
					 Sleep(1000)
				  EndIf
			   EndIf
			Case $SortScreen
			   _Click(460, 120)	; Filter, sort is irrelevant for this
			   Sleep(1000)
			Case $FilterScreen
			   _Click(90, 890)	; Clear select button
			   Sleep(1000)
			   _ClickDrag(570, 220, 570, 790, 10)	; Drag the scroll bar down
			   Sleep(1000)
			   _Click(280, 330)	; For Sale
			   Sleep(1000)
			   If NOT _CheckForImage($SaleFilter, $x, $y) Then
				  _FatalError("_SellSnappers: Unable to confirm proper filter selection")
			   EndIf
			   _Click(300, 890)	; Confirm Button
			   Sleep(1000)
			   $FilterApplied = True
			Case $EquipButton	; Oops, we long clicked on a unit
			   _Click(60, 200)	; Back button
			   Sleep(2000)
			   $UnitSelectionPosition = $UnitSelectionPosition - 1
			Case Else
			   If _GetHomeScreen() Then
				  _Click(150, 1000)	; Units
				  Sleep(1000)
			   Else
				  _FatalError("_SellSnappers: Unable to get home screen")
			   EndIf
		 EndSwitch
	  EndIf
   WEnd
EndFunc


Func _CompleteSnapperSale()
   Local $LoopCounter, $ConnectionErrorCount
   _Click(300, 880)	; Sell button
   Sleep(2000)
   _Click(440, 840)	; Yes button
   Sleep(2000)
   _Click(400, 600)	; Yes button
   $LoopCounter = 0
   $ConnectionErrorCount = 0
   While $InfiniteLoop
	  Sleep(1000)
	  If _CheckForImage($ConnectionError, $x, $y) Then
		 _Click(300, 630)	; OK button
		 $LoopCounter = 0
		 $ConnectionErrorCount = $ConnectionErrorCount + 1
	  ElseIf _CheckForImage($UnitSoldOKButton, $x, $y) Then
		 _Click(300, 600)	; OK button
		 Sleep(1000)
		 Return True
	  Else
		 $LoopCounter = $LoopCounter + 1
		 If $LoopCounter = 60 OR $ConnectionErrorCount = 10 Then
			_FatalError("_CompleteSnapperSale: Unable to complete sale")
		 EndIf
	  EndIf
   WEnd
EndFunc


Func _CactuarFusion()
   Local $UnitSelectFilterSet[3] = [False, False, False], $MaterialSelectFilterSet[3] = [False, False, False]	; 0 = overall, 1 = sort, 2 = filter
   Local $CurrentRarity = 3, $MaxRarity = 4, $UnitSelectionPosition = 1, $CurrentPosition, $CurrentPositionX, $CurrentPositionY
   Local $LastScreen, $LoopCounter, $ConnectionErrorCount, $ExperienceRead, $EnhancerSelected = False
   _StopTMFarm()
   While $InfiniteLoop
	  If $ScriptPaused Then
		 _ShowPauseMessage()
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_CactuarFusion")
		 If NOT $Enabled[$CactuarFusion] Then
			_GetHomeScreen()
			Return False
		 EndIf
		 Switch _WhereAmI($CactuarFusion)
			Case $HomeScreen
			   _Click(150, 1000)	; Units
			   Sleep(1000)
			Case $ManagePartyScreen
			   _Click(175, 850)		; Enhance Units
			   Sleep(1000)
			Case $SelectBaseScreen
			   Sleep(1000)
			   $LoopCounter = 0
			   While NOT _CheckForImage($FusionUnitsTab, $x, $y)
				  _Click(330, 350)		; Fusion/Sale Units tab
				  Sleep(1000)
				  $LoopCounter = $LoopCounter + 1
				  If $LoopCounter > 15 Then
					 _FatalError("_CactuarFusion: Unable to get Fusion/Sale Tab")
				  EndIf
			   WEnd
			   $LastScreen = $SelectBaseScreen
			   If NOT $UnitSelectFilterSet[0] Then
				  _Click(470, 260)	; Sort/Filter
				  Sleep(1000)
			   ElseIf NOT _CheckForImage($FilteredList, $x, $y) Then		; Filter was removed, this means we hit the end of the list and clicked on remove filter, we are done
				  Sleep(4000)	; Allow time to make sure we didn't get a false positive since the test is for a missing image
				  If NOT _CheckForImage($FilteredList, $x, $y) Then	; Filter is still off, this should not be a false positive from a slowdown
					 If $CurrentRarity = $MaxRarity Then	; No more rarities to do, completely done
						_GetHomeScreen()
						Return True
					 Else
						$CurrentRarity = $CurrentRarity + 1
						For $LoopCounter = 0 TO 2
						   $UnitSelectFilterSet[$LoopCounter] = False
						   $MaterialSelectFilterSet[$LoopCounter] = False
						Next
						;$UnitSelectPosition = 1
						If _GetHomeScreen() Then
						   _Click(150, 1000)	; Units
						   Sleep(1000)
						Else
						   _FatalError("_CactuarFusion: Unable to get home screen")
						EndIf
					 EndIf
				  EndIf
			   Else
;				  For $LoopCounter = 1 TO Int($UnitSelectionPosition / 5)
;					 _ClickDrag(300, 625, 300, 787, 15)		; Scroll back to the top so we know where we are
;					 Sleep(500)
;				  Next
;				  If $UnitSelectionPosition > 20 Then
;					 $LoopCounter = $UnitSelectionPosition - 20
;					 While $InfiniteLoop
;						_ClickDrag(300, 625, 300, 463, 15)		; Scroll down so the bottom row will have the unit we want
;						Sleep(500)
;						$LoopCounter = $LoopCounter - 5
;						If $LoopCounter < 1 Then
;						   ExitLoop
;						EndIf
;					 WEnd
;					 $CurrentPosition = $LoopCounter + 20	; add 15 because we are on the bottom row and another 5 because we over-subtracted in the loop
;				  Else
;					 $CurrentPosition = $UnitSelectionPosition
;				  EndIf
;				  For $LoopCounter = 0 TO 3
;					 Switch $LoopCounter	; Y position set each time through the loop, overwriting the previous one
;						Case 0
;						   $CurrentPositionY = 390
;						Case 1
;						   $CurrentPositionY = 560
;						Case 2
;						   $CurrentPositionY = 720
;						Case 3
;						   $CurrentPositionY = 880
;					 EndSwitch
;					 Switch $CurrentPosition - ($LoopCounter * 5)	; will only hit when the Y position is correct, so we will have an exact match and need to end the loop
;						Case 1
;						   $CurrentPositionX = 60
;						   ExitLoop
;						Case 2
;						   $CurrentPositionX = 175
;						   ExitLoop
;						Case 3
;						   $CurrentPositionX = 290
;						   ExitLoop
;						Case 4
;						   $CurrentPositionX = 405
;						   ExitLoop
;						Case 5
;						   $CurrentPositionX = 520
;						   ExitLoop
;					 EndSwitch
;				  Next
;				  _Click($CurrentPositionX, $CurrentPositionY)
				  $EnhancerSelected = False
				  _Click(60, 440) ; First unit in list
				  Sleep(1000)
;				  Sleep(2000)
;				  If _CheckForImage($SelectBaseScreen, $x, $y) Then	; We are still on the select base screen, we click on nothing, we must be done
;					 If $CurrentRarity = 4 Then	; No more rarities to do, completely done
;						$CactuarFusionEnabled = False
;						_GetHomeScreen()
;						Return True
;					 Else
;						$CurrentRarity = $CurrentRarity + 1
;						For $LoopCounter = 0 TO 2
;						   $UnitSelectFilterSet[$LoopCounter] = False
;						   $MaterialSelectFilterSet[$LoopCounter] = False
;						Next
;						$UnitSelectPosition = 1
;						If _GetHomeScreen() Then
;						   _Click(150, 1000)	; Units
;						   Sleep(1000)
;						Else
;						   _FatalError("_CactuarFusion: Unable to get home screen")
;						EndIf
;					 EndIf
;				  EndIf
			   EndIf
			Case $EnhanceUnitsScreen
			   If $EnhancerSelected Then
				  _Click(300, 890)	; Fuse
				  $LoopCounter = 0
				  $ConnectionErrorCount = 0
				  While $InfiniteLoop
					 Sleep(1000)
					 If _CheckForImage($ConnectionError, $x, $y) Then
						_Click(300, 630)	; OK button
						$LoopCounter = 0
						$ConnectionErrorCount = $ConnectionErrorCount + 1
					 ElseIf _CheckForImage($EnhanceUnitsScreen, $x, $y) Then
						_Click(60, 240)		; Back button
						Sleep(1000)
						$EnhancerSelected = False
						ExitLoop
					 ElseIf _CheckForImage($SelectBaseScreen, $x, $y) Then
						$EnhancerSelected = False
						ExitLoop
					 ElseIf _CheckForImage($SkipButton, $x, $y) Then
						_Click(515, 885)	; Skip button
						Sleep(1000)
					 EndIf
					 _Click(300, 100)	; Safe place to click to keep things moving
					 $LoopCounter = $LoopCounter + 1
					 If $LoopCounter = 60 OR $ConnectionErrorCount = 10 Then
						_FatalError("_CactuarFusion: Fuse never finished")
					 EndIf
				  WEnd
			   Else
				  If _CheckForImage($Level1Enhancer, $x, $y) Then
					 _Click(60, 720)
					 Sleep(1000)
					 $EnhancerSelected = True
				  Else	; Enhancer is not at level 1, we are done
					 If $CurrentRarity = $MaxRarity Then	; No more rarities to do, completely done
						_GetHomeScreen()
						Return True
					 Else
						$CurrentRarity = $CurrentRarity + 1
						For $LoopCounter = 0 TO 2
						   $UnitSelectFilterSet[$LoopCounter] = False
						   $MaterialSelectFilterSet[$LoopCounter] = False
						Next
;						$UnitSelectPosition = 1
						If _GetHomeScreen() Then
						   _Click(150, 1000)	; Units
						   Sleep(1000)
						Else
						   _FatalError("_CactuarFusion: Unable to get home screen")
						EndIf
					 EndIf
;					 $UnitSelectionPosition = $UnitSelectionPosition + 1
;					 _Click(60, 240)	; Back button
;					 Sleep(1000)
				  EndIf
			   EndIf
			Case $MaterialUnitsScreen
			   Sleep(1000)
			   $LoopCounter = 0
			   While NOT _CheckForImage($FusionUnitsTab, $x, $y)
				  _Click(330, 350)		; Fusion/Sale Units tab
				  Sleep(1000)
				  $LoopCounter = $LoopCounter + 1
				  If $LoopCounter > 15 Then
					 _FatalError("_CactuarFusion: Unable to get Fusion/Sale Tab")
				  EndIf
			   WEnd
			   $LastScreen = $MaterialUnitsScreen
			   If NOT $MaterialSelectFilterSet[0] Then
				  _Click(470, 260)	; Sort/Filter
				  Sleep(1000)
			   ElseIf NOT _CheckForImage($FilteredList, $x, $y) Then		; Filter was removed, this means we hit the end of the list and clicked on remove filter, we are done
				  Sleep(4000)	; Allow time to prevent a false positive since this is detected by a missing image
				  If NOT _CheckForImage($FilteredList, $x, $y) Then		; This is not a false positive, continue
					 If $CurrentRarity = $MaxRarity Then	; No more rarities to do, completely done
						_GetHomeScreen()
						Return True
					 Else
						$CurrentRarity = $CurrentRarity + 1
						For $LoopCounter = 0 TO 2
						   $UnitSelectFilterSet[$LoopCounter] = False
						   $MaterialSelectFilterSet[$LoopCounter] = False
						Next
						;$UnitSelectPosition = 1
						If _GetHomeScreen() Then
						   _Click(150, 1000)	; Units
						   Sleep(1000)
						Else
						   _FatalError("_CactuarFusion: Unable to get home screen")
						EndIf
					 EndIf
				  EndIf
			   Else
				  _Click(60, 440)	; First item in list, this will always be what we select
				  Sleep(1000)
				  If NOT _CheckForImage($FilteredList, $x, $y) Then		; Filter was removed, this means we hit the end of the list and clicked on remove filter, we are done
					 Sleep(4000)
					 If NOT _CheckForImage($FilteredList, $x, $y) Then
						If $CurrentRarity = $MaxRarity Then	; No more rarities to do, completely done
						   _GetHomeScreen()
						   Return True
						Else
						   $CurrentRarity = $CurrentRarity + 1
						   For $LoopCounter = 0 TO 2
							  $UnitSelectFilterSet[$LoopCounter] = False
							  $MaterialSelectFilterSet[$LoopCounter] = False
						   Next
						   ;$UnitSelectPosition = 1
						   If _GetHomeScreen() Then
							  _Click(150, 1000)	; Units
							  Sleep(1000)
						   Else
							  _FatalError("_CactuarFusion: Unable to get home screen")
						   EndIf
						EndIf
					 EndIf
				  EndIf
				  If _CheckForImage($FilteredList, $x, $y) Then		; Filter is still there, check the experience and lock the unit or fuse
					 _GDIPlus_Startup()
					 $ExperienceRead = _OCR(110, 805, 130, 25)
					 If $ExperienceRead > $MaxExperience[$CurrentRarity] AND $MaxExperience[$CurrentRarity] > 0 Then		; Enhancer has too much experience, lock it and start a new one
						_ClickHold(60, 390, 2000)	; Click and hold on the first unit to bring up the screen where we can lock it
						Sleep(5000)
						_Click(415, 220)	; Lock button
						Sleep(1000)
						_Click(60, 220)	; Back button
						Sleep(2000)
					 ElseIf $ExperienceRead = 0 Then
						_FatalError("_CactuarFusion: Unable to read experience from unit")
					 Else
						_Click(300, 890)	; OK button
						Sleep(1000)
					 EndIf
					 _GDIPlus_Shutdown()
				  EndIf
			   EndIf
			Case $SortScreen
			   If $LastScreen = $SelectBaseScreen Then
				  If $UnitSelectFilterSet[1] Then
					 If $UnitSelectFilterSet[2] Then
						$UnitSelectFilterSet[0] = True
						_Click(300, 890)	; Confirm
						Sleep(1000)
					 Else
						_Click(460, 120)	; Filter
						Sleep(1000)
					 EndIf
				  Else
					 _Click(100, 890)	; Ascending
					 Sleep(1000)
					 _Click(150, 225)	; LVL
					 Sleep(1000)
					 $UnitSelectFilterSet[1] = True
					 If $UnitSelectFilterSet[2] Then
						_Click(300, 890)	; Confirm
						Sleep(1000)
						$UnitSelectFilterSet[0] = True
					 Else
						_Click(460, 120)	; Filter
						Sleep(1000)
					 EndIf
				  EndIf
			   ElseIf $LastScreen = $MaterialUnitsScreen Then
				  If $MaterialSelectFilterSet[1] Then
					 If $MaterialSelectFilterSet[2] Then
						$MaterialSelectFilterSet[0] = True
						_Click(300, 890)	; Confirm
						Sleep(1000)
					 Else
						_Click(460, 120)	; Filter
						Sleep(1000)
					 EndIf
				  Else
					 _Click(485, 890)	; Descending
					 Sleep(1000)
					 _Click(150, 225)	; LVL
					 Sleep(1000)
					 $MaterialSelectFilterSet[1] = True
					 If $MaterialSelectFilterSet[2] Then
						_Click(300, 890)	; Confirm
						Sleep(1000)
						$MaterialSelectFilterSet[0] = True
					 Else
						_Click(460, 120)	; Filter
						Sleep(1000)
					 EndIf
				  EndIf
			   EndIf
			Case $FilterScreen
			   If $LastScreen = $SelectBaseScreen Then
				  If $UnitSelectFilterSet[2] Then
					 _Click(240, 120)	; Sort
					 Sleep(1000)
				  Else
					 _Click(100, 890)		; Clear Select, we don't need any rogue filters breaking this
					 Sleep(1000)
					 Switch $CurrentRarity
						Case 2
						   _Click(185, 235)	; 2 star
						Case 3
						   _Click(290, 235)	; 3 star
						Case 4
						   _Click(400, 235)	; 4 star
						Case 5
						   _Click(510, 235)	; 5 star
						Case Else
						   _FatalError("_CactuarFusion: Invalid current rarity")
					 EndSwitch
					 Sleep(1000)
					 _ClickDrag(570, 220, 570, 390, 10)	; Drag the scroll bar down
					 ; These drags are extremely sensitive to interference, they must be perfect or it will break the script
					 Sleep(1000)
					 _Click(220, 500)	; Non-MAX unit level
					 Sleep(1000)
					 If NOT (_CheckForImage($UnitFilter1, $x, $y) OR _CheckForImage($UnitFilter1Alt, $x, $y)) Then	; Make sure we selected the right thing, fatal error out if we can't confirm it
						_FatalError("_CactuarFusion: Failed to confirm filter selection " & $UnitFilter1)
					 EndIf
					 _ClickDrag(570, 390, 570, 830, 10)	; Drag the scroll bar from the last position we left it all the way to the bottom
					 Sleep(1000)
					 _Click(480, 360)	; Enhance unit type
					 Sleep(1000)
					 If NOT _CheckForImage($UnitFilter2, $x, $y) Then	; Make sure we selected the right thing, fatal error out if we can't confirm it
						_FatalError("_CactuarFusion: Failed to confirm filter selection " & $UnitFilter2)
					 EndIf
					 $UnitSelectFilterSet[2] = True
					 If $UnitSelectFilterSet[1] Then
						_Click(300, 890)	; Confirm
						Sleep(1000)
						$UnitSelectFilterSet[0] = True
					 Else
						_Click(240, 120)	; Sort
						Sleep(1000)
					 EndIf
				  EndIf
			   ElseIf $LastScreen = $MaterialUnitsScreen Then
				  If $MaterialSelectFilterSet[2] Then
					 _Click(240, 120)	; Sort
					 Sleep(1000)
				  Else
					 _Click(100, 890)		; Clear Select, we don't need any rogue filters breaking this
					 Sleep(1000)
					 Switch $CurrentRarity
						Case 2
						   _Click(185, 235)	; 2 star
						Case 3
						   _Click(290, 235)	; 3 star
						Case 4
						   _Click(400, 235)	; 4 star
						Case 5
						   _Click(510, 235)	; 5 star
						Case Else
						   _FatalError("_CactuarFusion: Invalid current rarity")
					 EndSwitch
					 Sleep(1000)
					 _ClickDrag(570, 220, 570, 390, 10)	; Drag the scroll bar down
					 ; These drags are extremely sensitive to interference, they must be perfect or it will break the script
					 Sleep(1000)
					 _Click(220, 500)	; Non-MAX unit level
					 Sleep(1000)
					 If NOT (_CheckForImage($UnitFilter3, $x, $y) OR _CheckForImage($UnitFilter3Alt, $x, $y)) Then	; Make sure we selected the right thing, fatal error out if we can't confirm it
						_FatalError("_CactuarFusion: Failed to confirm filter selection " & $UnitFilter3)
					 EndIf
					 _ClickDrag(570, 390, 570, 830, 10)	; Drag the scroll bar from the last position we left it all the way to the bottom
					 Sleep(1000)
					 _Click(480, 340)	; Enhance unit type
					 Sleep(1000)
					 _Click(140, 780)	; Craftable can fuse
					 Sleep(1000)
					 If NOT _CheckForImage($UnitFilter4, $x, $y) Then	; Make sure we selected the right thing, fatal error out if we can't confirm it
						_FatalError("_CactuarFusion: Failed to confirm filter selection " & $UnitFilter4)
					 EndIf
					 If NOT _CheckForImage($UnitFilter5, $x, $y) Then	; Make sure we selected the right thing, fatal error out if we can't confirm it
						_FatalError("_CactuarFusion: Failed to confirm filter selection " & $UnitFilter5)
					 EndIf
					 $MaterialSelectFilterSet[2] = True
					 If $MaterialSelectFilterSet[1] Then
						_Click(300, 890)	; Confirm
						Sleep(1000)
						$MaterialSelectFilterSet[0] = True
					 Else
						_Click(240, 120)	; Sort
						Sleep(1000)
					 EndIf
				  EndIf
			   EndIf
			Case Else
			   If _GetHomeScreen() Then
				  _Click(150, 1000)	; Units
				  Sleep(1000)
			   Else
				  _FatalError("_CactuarFusion: Unable to get home screen")
			   EndIf
		 EndSwitch
	  EndIf
   WEnd
EndFunc


Func _Reboot()
   _StopTMFarm()
   DllClose($DllHandle)
   If $AllowReboot Then
	  Run(@ComSpec & " /c shutdown /r /f /t 30")
	  WinClose($EmulatorName, "")
   EndIf
   Exit
EndFunc


Func _UpdateAppVersion()
   Local $UpdateTimeOut = _DateAdd("n", 6, _NowCalc())	; Hard 6 minute limit on updating
   Local $OriginalDebug = GUICtrlRead($DebugBox)
   Local $DelayCounter
   Local Const $UpdateMethod = "Blind Click"	; Added because google play was giving inconsistent buttons, some emulators were a few pixels off, causing image recognition to fail
   If _CheckForImage($AppUpdateRequired, $x, $y) Then
	  _StopTMFarm()
	  _Click(300, 600)	; OK button
	  For $DelayCounter = 1 TO 10
		 GUICtrlSetData($DebugBox, "_UpdateAppVersion - Sleep " & 11 - $DelayCounter)
		 Sleep(1000)
	  Next
	  GUICtrlSetData($DebugBox, "_UpdateAppVersion")
	  If $UpdateMethod = "Blind Click" Then
		 If _CheckForImage($AppUpdateChooseApp, $x, $y) Then
			GUICtrlSetData($DebugBox, "_UpdateAppVersion - Entering Google Play")
			Sleep(1000)	; Clicking too soon might keep the click from being registered
			_ClickItem("general", $x, $y)	; location could vary, click where the image was found
			Sleep(3000)
			_Click(515, 1015)	; Always
			For $DelayCounter = 1 TO 10
			   GUICtrlSetData($DebugBox, "_UpdateAppVersion - Entering Google Play - Sleep " & 11 - $DelayCounter)
			   Sleep(1000)
			Next
		 EndIf
		 _Click(430, 300)	; Update button
		 GUICtrlSetData($DebugBox, "_UpdateAppVersion - Updating")
		 For $DelayCounter = 1 TO 120
			GUICtrlSetData($DebugBox, "_UpdateAppVersion - Updating - Sleep " & 121 - $DelayCounter)
			Sleep(1000)
		 Next
		 _Click(430, 300)	; Open button
		 For $DelayCounter = 1 TO 10
			GUICtrlSetData($DebugBox, "_UpdateAppVersion - Return to FFBE - Sleep " & 11 - $DelayCounter)
			Sleep(1000)
		 Next
		 GUICtrlSetData($DebugBox, $OriginalDebug)
		 Return True
	  Else
		 While $InfiniteLoop
			If _CheckForImage($AppUpdateButton, $x, $y) Then
			   GUICtrlSetData($DebugBox, "_UpdateAppVersion - Updating")
			   Sleep(1000)	; Clicking too soon might keep the click from being registered
			   _Click(430, 300)	; Update button
			   For $DelayCounter = 1 TO 10
				  GUICtrlSetData($DebugBox, "_UpdateAppVersion - Updating - Sleep " & 11 - $DelayCounter)
				  Sleep(1000)
			   Next
			   GUICtrlSetData($DebugBox, "_UpdateAppVersion - Updating")
			ElseIf _CheckForImage($AppUpdateComplete, $x, $y) Then
			   GUICtrlSetData($DebugBox, "_UpdateAppVersion - Update Complete")
			   Sleep(1000)	; Clicking too soon might keep the click from being registered
			   _Click(430, 300)	; Open button
			   For $DelayCounter = 1 TO 10
				  GUICtrlSetData($DebugBox, "_UpdateAppVersion - Return to FFBE - Sleep " & 11 - $DelayCounter)
				  Sleep(1000)
			   Next
			   GUICtrlSetData($DebugBox, $OriginalDebug)
			   Return True
			ElseIf _CheckForImage($AppUpdateChooseApp, $x, $y) Then
			   GUICtrlSetData($DebugBox, "_UpdateAppVersion - Entering Google Play")
			   Sleep(1000)	; Clicking too soon might keep the click from being registered
			   _ClickItem("general", $x, $y)	; location could vary, click where the image was found
			   Sleep(3000)
			   _Click(515, 1015)	; Always
			   For $DelayCounter = 1 TO 10
				  GUICtrlSetData($DebugBox, "_UpdateAppVersion - Entering Google Play - Sleep " & 11 - $DelayCounter)
				  Sleep(1000)
			   Next
			   GUICtrlSetData($DebugBox, "_UpdateAppVersion - Entering Google Play")
			ElseIf _NowCalc() > $UpdateTimeOut Then
			   _FatalError("_UpdateAppVersion - Update took too long")
			EndIf
			Sleep(2000)
		 WEnd
	  EndIf
   Else
	  Return False
   EndIf
EndFunc


Func _StartEmulator()
   If WinExists($EmulatorName, "") Then
	  Return False
   Else
	  _StopTMFarm()
	  Sleep(5000) ; Wait 5 seconds and try again
   EndIf
   If WinExists($EmulatorName, "") Then
	  Return False
   Else
	  Run($EmulatorEXE)
	  If WinWait($EmulatorName, "", 300) Then	; Wait up to 300 seconds for the emulator to start
		 WinMove($EmulatorName, "", 1, 1)		; Move to the top left corner
		 Return True
	  Else
		 _FatalError("_StartEmulator - Unable to start emulator")
	  EndIf
   EndIf
EndFunc


Func _StartFFBE()    ; Starts the app on the emulator and clicks past the logon screen
   Local $StartTimeOut = _DateAdd("s", Int($TimeOut / 2), _NowCalc()), $WasPaused = False
   If _CheckForImage($FFBEIcon, $x, $y) Then
	  _StopTMFarm()
	  _ClickItem("Icon", $x, $y)
	  While $InfiniteLoop
		 If $ScriptPaused Then
			_ShowPauseMessage()
			$WasPaused = True
		 Else
			_HidePauseMessage()
			If $WasPaused Then
			   Return True			; Returning false could cause an instant fatal error because the timer wouldn't be reset in WhereAmI
			EndIf
			If _CheckForImage($ConnectionError, $x, $y) Then
			   If _CheckForImage($OKButton, $x, $y) Then
				  _ClickItem("Button", $x, $y)
			   Else
				  _FatalError("_StartFFBE Missing OK Button")
			   EndIf
;			ElseIf _CheckForImage($Startup1, $x, $y) Then
;			   _ClickItem("General", $x, $y)
;			ElseIf _CheckForImage($Startup2, $x, $y) Then
;			   _ClickItem("General", $x, $y)
;			ElseIf _CheckForImage($Startup3, $x, $y) Then
;			   _ClickItem("General", $x, $y)
			ElseIf _CheckForImage($LogonScreen, $x, $y) Then
			   _ClickItem("General", $x, $y)
			   Return True
			ElseIf _CheckForImage($OKButton, $x, $y) Then   ; Found an unexpected OK button
			   Return False
			Else
			   Sleep(1000) ; Wait a second and try again
			EndIf
			If _NowCalc() > $StartTimeOut Then
			   Return False
			EndIf
		 EndIf
	  WEnd
   Else
	  Return False
   EndIf
EndFunc


Func _TeamViewerCheck()			; Removes any unwanted messages create by Team Viewer
   If WinExists("Sponsored session") Then	; Get rid of team viewer message if it exists
	  WinActivate("Sponsored session")
	  Send("{ENTER}")
   EndIf
   If WinExists("Session timeout") Then	; Get rid of team viewer message if it exists
	  WinActivate("Session timeout")
	  Send("{ENTER}")
   EndIf
EndFunc


Func _WhereAmI($TypeToCheck, $QuickCheck = False)    ; Returns where we currently are by getting us to a state that matches one of its return options if we aren't already at one
   Local $x1, $y1, $x2, $y2, $PerformFullCheck = False, $BlockContinueClicks = False
;   Local $NextFullCheck = _DateAdd("s", 5, _NowCalc())
   Local $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
   Local $OriginalDebug = GUICtrlRead($DebugBox)
   While $InfiniteLoop  ; This will keep looping until we can return a value or we time out
	  If $ScriptPaused Then
		 _ShowPauseMessage()
		 Sleep(1000)
		 $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
		 $PerformFullCheck = True	; Will be set to false when the loop starts again
	  Else
		 _HidePauseMessage()
		 GUICtrlSetData($DebugBox, "_WhereAmI " & $TypeToCheck & " " & $OriginalDebug)
		 _TeamViewerCheck()
;	  If NOT WinActive($EmulatorName) Then
;		 WinActivate($EmulatorName)
;	  EndIf
;		 If _NowCalc() > $NextFullCheck Then
;			$PerformFullCheck = True
;		 EndIf
		 $PerformFullCheck = NOT $PerformFullCheck ; We will only check a subset of expected locations, but every other loop, we will check everything in case we aren't where we expect to be
		 If $TypeToCheck = "Everything" OR $PerformFullCheck Then
			If _StartEmulator() Then
			   _AddToLog(1, "Started emulator")
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _StartFFBE() Then
			   _AddToLog(1, "Started FFBE App")
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _UpdateAppVersion() Then
			   _AddToLog(1, "Updated FFBE to latest version")
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForHomeScreen() Then
			   Return $HomeScreen
			ElseIf _CheckForImage($CannotVerifyAccount, $x, $y) Then
			   $BlockContinueClicks = True
			   _Click(300, 630)	; OK button
			   Sleep(1000)
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($SignInWithGoogleButton, $x, $y) Then
			   $BlockContinueClicks = True	; These will crash FFBE if they happen during a google sign-in
			   _Click(300, 600)	; Sign in with google button
			   Sleep(3000)
			   _Click(400, 630)	; OK button
			   Sleep(5000)
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($ChooseAnAccountScreen, $x, $y) OR _CheckForImage($ChooseAccountScreen, $x, $y) Then
			   $BlockContinueClicks = True
			   Sleep(5000)
			   _Click(300, 580)	; Top account in list
			   Sleep(3000)
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($GoogleAccessScreen, $x, $y) Then
			   $BlockContinueClicks = True
			   Sleep(2000)
			   _Click(510, 945)	; Allow button
			   Sleep(1000)
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($ExistingAccountDataScreen, $x, $y) Then
			   $BlockContinueClicks = True
			   Sleep(1000)
			   _Click(400, 630)	; OK button
			   Sleep(2000)
			ElseIf _CheckForImage($OverwriteDeviceData, $x, $y) Then
			   $BlockContinueClicks = True
			   _Click(400, 600)	; Yes button
			   Sleep(1000)
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($LogonScreen, $x, $y) Then
			   _AddToLog(5, "Logged into FFBE")
			   _ClickItem("General", $x, $y)
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($ResumeMission, $x, $y) Then
			   _AddToLog(1, "Resumed running mission")
			   _Click(400, 615)	; Yes button
			   Sleep(2000)
			ElseIf _CheckForImage($SummonPopUp, $x1, $y1) Then
			   _Click(525, 240)	; X on summon popup
			   Sleep(1000)
			ElseIf _CheckForImage($LapisContinue, $x1, $y1) Then
			   If _CheckForImage($ContinueNoButton, $x1, $y1) Then
				  _ClickItem("Button", $x1, $y1)
				  Sleep(2000)
				  $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			   Else
				  _FatalError("_WhereAmI - Lapis continue no button missing")
			   EndIf
			ElseIf _CheckForImage($LapisContinueConfirm, $x1, $y1) Then
			   If _CheckForImage($ContinueConfirmButton, $x1, $y1) Then
				  _ClickItem("Button", $x1, $y1)
				  $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			   Else
				  _FatalError("_WhereAmI - Confirm no lapis continue button missing")
			   EndIf
			ElseIf _CheckForImage($CrashError, $x, $y) Then
			   _AddToLog(1, "FFBE Crash detected")
			   _Click(490, 590)		; Click the OK button
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($GooglePlayGames, $x, $y) Then
			   _Click(420, 935)		; Click the Allow button
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($GooglePlayGames2, $x, $y) Then
			   _Click(400, 1020)	; Click the Turn On button
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($LoginClaimButton, $x, $y) Then
			   _Click(540, 175)		; Click the X to close the daily login reward box
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($LoginBonusOKButton, $x1, $y1) Then
			   _ClickItem("Button", $x1, $y1)
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($AbilityCapacityReached, $x, $y) Then
			   _FatalError("Ability Capacity Reached")
			ElseIf _CheckForImage($EquipmentCapacityReached, $x, $y) Then
			   _FatalError("Equipment Capacity Reached")
			ElseIf _CheckForImage($ItemCapacityReached, $x, $y) Then
			   _FatalError("Item Capacity Reached")
			ElseIf _CheckForImage($MaterialCapacityReached, $x, $y) Then
			   _Click(180, 640)		; Click the Items button
			   Sleep(1000)
			   If $AllowAutoSell Then
				  $Enabled[$SellMaterials] = True
				  GUICtrlSetState($EnabledCheckbox[$SellMaterials], $GUI_CHECKED)
				  IniWrite($IniFile, "Initialize", $FriendlyName[$SellMaterials] & " Enabled", $Enabled[$SellMaterials])
				  _SellMaterials()
				  $Enabled[$SellMaterials] = False
				  $NextOrbCheck[$SellMaterials] = "OFF"
				  GUICtrlSetState($EnabledCheckbox[$SellMaterials], $GUI_UNCHECKED)
				  IniWrite($IniFile, "Initialize", $FriendlyName[$SellMaterials] & " Enabled", $Enabled[$SellMaterials])
				  $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			   Else
				  _FatalError("Material capacity reached")
			   EndIf
			ElseIf _CheckForImage($AnnouncementCloseButton, $x, $y) Then
			   _Click(300, 1000)	; Announcement Close button
			ElseIf _CheckForImage($DownloadAcceptScreen, $x, $y) Then
			   _Click(360, 660)		; Yes button
			ElseIf _CheckForImage($DownloadAcceptScreen2, $x, $y) Then
			   _Click(360, 660)		; OK button
			ElseIf _CheckForImage($PleaseLogInAgain, $x, $y) Then	; We will pause the script immediately and send a text if we are kicked off by another device
			   _SendMail("Please log in again detected")
			   _Click(300, 600)
			   _StopTMFarm()
			   If NOT $ContinueOnPLIA Then
				  $SimulatedPause = True
				  $PLIADetected = True
				  _PausePressed()
			   Else
				  $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			   EndIf
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $Arena OR $PerformFullCheck Then
			If _CheckForImage($OutOfNRG, $x, $y) Then
			   Return $OutOfNRG
			ElseIf _CheckForImage($ArenaMainPage, $x, $y) Then
			   If _CheckForImage($ArenaOrbsEmpty, $x, $y) Then
				  Return $ArenaMainPage & "0"
			   Else
				  Return $ArenaMainPage & "1"
			   EndIf
			ElseIf _CheckForImage($ArenaRulesPage, $x, $y) Then
			   If _CheckForImage($ArenaOrbsEmpty, $x, $y) Then
				  Return $ArenaRulesPage & "0"
			   Else
				  Return $ArenaRulesPage & "1"
			   EndIf
			ElseIf _CheckForImage($ArenaOpponentConfirm, $x, $y) Then
			   Return $ArenaOpponentConfirm
			ElseIf _CheckForImage($ArenaSelectionPage, $x, $y) Then
			   Return $ArenaSelectionPage
			ElseIf _CheckForImage($ArenaBeginButton, $x, $y) Then
			   Return $ArenaBeginButton
			ElseIf _CheckForImage($ArenaResultsOKButton, $x1, $y) Then
			   _Click(300, 920)	; Arena results page OK button
			ElseIf _CheckForImage($ArenaRankUpOKButton, $x, $y) Then
			   _Click(300, 965)	; Arena rank up page OK button
			ElseIf _CheckForImage($ArenaDailyReward, $x, $y) Then
			   _Click(300, 700)	; OK button
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($ArenaBattleCancelled, $x, $y) Then
			   _Click(300, 630)	; OK button
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf $TypeToCheck = $Arena AND NOT $BlockContinueClicks Then
			   _Click(300, 100)	; click in a neutral area to keep things moving
;			   If NOT _CheckForImage($HomeScreen, $x, $y) Then		; This will be bad if the home screen is active, make sure its not right before we start
;				  If NOT _CheckForImage($ArenaMainPage, $x, $y) Then
;					 If NOT _CheckForImage($ArenaSelectionPage, $x, $y) Then
;						_Click(360, 920)		; Click the OK buttons at the end of an arena battle, imagesearch fails to find them sometimes
;						_Click(360, 965)
;					 Else
;						Return $ArenaSelectionPage
;					 EndIf
;				  EndIf
;			   Else
;				  Return $HomeScreen
;			   EndIf
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = "World" OR $PerformFullCheck Then
			If _CheckForImage($WorldMainPage, $x, $y) Then
			   Return $WorldMainPage
			ElseIf _CheckForImage($WorldMapGrandshelt, $x, $y) Then
			   Return $WorldMapGrandshelt
			ElseIf _CheckForImage($WorldMapGrandsheltIsles, $x, $y) Then
			   Return $WorldMapGrandsheltIsles
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = "World" OR $TypeToCheck = $TMFarm OR $PerformFullCheck Then
			If _CheckForImage($TMSelect, $x, $y) Then
			   Return $TMSelect
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $Raid OR $PerformFullCheck Then
			If _CheckForImage($VortexMainPage, $x, $y) Then
			   Return $VortexMainPage
			ElseIf _CheckForImage($RaidBattleSelectionPage, $x, $y) Then
			   Return $RaidBattleSelectionPage
			ElseIf _CheckForImage($RaidTitle, $x, $y) Then
			   Return $RaidTitle
;			 ElseIf _CheckForImage($RaidMissionsPage, $x, $y) Then
;				Return $RaidMissionsPage
			ElseIf _CheckForImage($RaidDepartPage, $x, $y) Then
			   Return $RaidDepartPage
			ElseIf _CheckForImage($OutOfRaidOrbs, $x, $y) Then
			   Return $OutOfRaidOrbs
			ElseIf $TypeToCheck = $Raid Then
			   If NOT $BlockContinueClicks Then
				  _Click(300, 100)		; Click at the top middle to keep things moving, can't click anything there
				  Sleep(100)
				  _Click(300, 100)
				  Sleep(100)
				  _Click(300, 100)
			   EndIf
			   If _CheckForImage($RaidNextButton, $x, $y) Then
				  _ClickItem("button", $x, $y)
				  $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			   ElseIf _CheckForImage($RaidNextButton2, $x, $y) Then
				  _ClickItem("button", $x, $y)
				  $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			   ElseIf _CheckForImage($RaidNextButton3, $x, $y) Then
				  _ClickItem("button", $x, $y)
				  $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			   ElseIf _CheckForImage($RaidNextButton4, $x, $y) Then
				  _ClickItem("button", $x, $y)
				  $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			   EndIf
;				If NOT _CheckForImage($ActiveMenuButton, $x, $y) Then
;				   If NOT _CheckForImage($RaidBattleSelectionPage, $x, $y) Then	; This should not be done on the battle selection page or in battle
;					  _Click(360, 920)	; Click where a next button will appear
;			   	Else
;					  Return $RaidBattleSelectionPage
;				   EndIf
;				EndIf
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $TMFarm OR $PerformFullCheck Then
			If _CheckForImage($OutOfNRG, $x, $y) Then
			   Return $OutOfNRG
			ElseIf _CheckForImage($TMFriend, $x, $y) Then
			   Return $TMFriend
			ElseIf _CheckForImage($BattleResultsPage, $x, $y) Then
			   _Click(300, 930)
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($BattleResultsTMPage, $x, $y) Then
			   If $TypeToCheck = $TMFarm Then	; We only need to stop on this page if we are TM farming so we can collect TM progress information
				  Return $BattleResultsTMPage
			   Else
				  _ClickItem("General", $x, $y)
				  $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			   EndIf
			ElseIf _CheckForImage($BattleResultsItemPage, $x, $y) Then
			   _Click(300, 930)
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($TMBattle, $x, $y) Then
			   If _CheckForImage($TMNextButton, $x, $y) Then
				  Return $TMBattle & "1"
			   ElseIf _CheckForImage($TMDepartButton, $x, $y) Then
				  Return $TMBattle & "2"
			   EndIf
			ElseIf $Dalnakya Then 		; Must be last ElseIf in the set or nothing else can be checked when $Dalnakya is True
			   If _CheckForImage($DalnakyaCavern2, $x, $y) OR _CheckForImage($DalnakyaCavern3, $x, $y) Then
				  If _CheckForImage($TMNextButton, $x, $y) Then
					 Return $TMBattle & "1"
				  ElseIf _CheckForImage($TMDepartButton, $x, $y) Then
					 Return $TMBattle & "2"
				  EndIf
			   EndIf
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $TMFarm OR $TypeToCheck = $Raid OR $PerformFullCheck Then
			If _CheckForImage($DontRequestButton, $x, $y) Then
			   _ClickItem("button", $x, $y)
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			ElseIf _CheckForImage($UnitDataUpdated, $x, $y) Then
			   _Click(300, 625)
			ElseIf _CheckForImage($DailyQuest, $x, $y) Then
			   _Click(150, 670)
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			EndIf
		 EndIf
		 If _CheckForImageExact($ActiveRepeatButton, $x1, $y1) Then	; Should only appear in a battle, so let's figure out which one
			If $TypeToCheck = $TMFarm OR $TypeToCheck = $Arena OR $TypeToCheck = $Raid Then
			   ; Will assume we are in the correct battle if we are in a specific search mode
			   $x = $x1
			   $y = $y1
			   Return "In Battle"
			EndIf
			If _CheckForImage($ActiveMenuButton, $x, $y) Then
			   _ClickItem("Button", $x, $y)
			   Sleep(2000)
			   If _CheckForImage($BattleMenuBackButton, $x2, $y2) Then
				  If _CheckForImage($ArenaInBattle, $x, $y) Then
					 $x = $x1
					 $y = $y1
					 _ClickItem("button", $x2, $y2)
					 Return $ArenaInBattle
				  ElseIf _CheckForImage($RaidInBattle, $x, $y) Then
					 $x = $x1
					 $y = $y1
					 _ClickItem("button", $x2, $y2)
					 Return $RaidInBattle
				  ElseIf _CheckForImage($TMInBattle, $x, $y) Then
					 $x = $x1
					 $y = $y1
					 _ClickItem("button", $x2, $y2)
					 Return $TMInBattle
				  ElseIf _CheckForImage($DalnakyaInBattle2, $x, $y) Then
					 $x = $x1
					 $y = $y1
					 _ClickItem("button", $x2, $y2)
					 Return $TMInBattle
				  ElseIf _CheckForImage($DalnakyaInBattle3, $x, $y) Then
					 $x = $x1
					 $y = $y1
					 _ClickItem("button", $x2, $y2)
					 Return $TMInBattle
				  Else	; We are in an unrecognized battle, will assume it is a raid battle
					 $x = $x1
					 $y = $y1
					 _ClickItem("button", $x2, $y2)
					 Return $RaidInBattle
				  EndIf
			   Else
				  ; Turned this off, it was occurring too often when trying to change modes, we will let it continue until it finds something else or fail on a timeout instead
				  ;_FatalError("_WhereAmI - Missing back button in battle menu")
			   EndIf
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $AdWheel OR $PerformFullCheck Then
			If _CheckForImage($RewardsWheelPage, $x, $y) Then
			   Return $RewardsWheelPage
			ElseIf _CheckForImage($RewardsWheelReady, $x, $y) Then
			   Return $RewardsWheelReady
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $Expeditions OR $PerformFullCheck Then
			If _CheckForImage($ExpeditionsScreen, $x, $y) Then
			   Return $ExpeditionsScreen
			ElseIf _CheckForImage($ExpeditionsScreen2, $x, $y) Then
			   Return $ExpeditionsScreen2
			ElseIf _CheckForImage($ExpeditionsRewardScreen, $x, $y) Then
			   Return $ExpeditionsRewardScreen
			ElseIf _CheckForImage($ExpeditionsRewardScreen2, $x, $y) Then	; First view of the screen appears with text on 2 lines, no need to differentiate this here
			   Return $ExpeditionsRewardScreen
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $ClaimDailies OR $PerformFullCheck Then
			If _CheckForImage($DailyQuestScreen, $x, $y) Then
			   Return $DailyQuestScreen
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $SendGifts OR $PerformFullCheck Then
			If _CheckForImage($FriendsScreen, $x, $y) Then
			   Return $FriendsScreen
			ElseIf _CheckForImage($ReceiveGiftsScreen, $x, $y) Then
			   Return $ReceiveGiftsScreen
			ElseIf _CheckForImage($SendGiftsScreen, $x, $y) Then
			   Return $SendGiftsScreen
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $CactuarFusion OR $PerformFullCheck Then
			If _CheckForImage($SelectBaseScreen, $x, $y) Then
			   Return $SelectBaseScreen
			ElseIf _CheckForImage($EnhanceUnitsScreen, $x, $y) Then
			   Return $EnhanceUnitsScreen
			ElseIf _CheckForImage($MaterialUnitsScreen, $x, $y) Then
			   Return $MaterialUnitsScreen
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $SellSnappers OR $TypeToCheck = $CactuarFusion OR $PerformFullCheck Then
			If _CheckForImage($ManagePartyScreen, $x, $y) Then
			   Return $ManagePartyScreen
			ElseIf _CheckForImage($SortScreen, $x, $y) Then
			   Return $SortScreen
			ElseIf _CheckForImage($FilterScreen, $x, $y) Then
			   Return $FilterScreen
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $SellSnappers OR $PerformFullCheck Then
			If _CheckForImage($ViewUnitsScreen, $x, $y) Then
			   Return $ViewUnitsScreen
			ElseIf _CheckForImage($SellUnitsScreen, $x, $y) Then
			   Return $SellUnitsScreen
			ElseIf $TypeToCheck = $SellSnappers AND _CheckForImage($EquipButton, $x, $y) Then	; This would show up if there was an accidental long click on a unit we are trying to sell
			   Return $EquipButton
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $SellMaterials OR $PerformFullCheck Then
			If _CheckForImage($ItemSetScreen, $x, $y) Then
			   Return $ItemSetScreen
			ElseIf _CheckForImage($MaterialsScreen, $x, $y) Then
			   Return $MaterialsScreen
			ElseIf _CheckForImage($SellMaterialsScreen, $x, $y) Then
			   Return $SellMaterialsScreen
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $RaidSummons OR $PerformFullCheck Then
			If _CheckForImage($RaidSummonScreen, $x, $y) Then
			   Return $RaidSummonScreen
			ElseIf _CheckForImage($RaidSummonConfirm, $x, $y) Then
			   Return $RaidSummonConfirm
			EndIf
		 EndIf
		 If $TypeToCheck = "Everything" OR $TypeToCheck = $DailyEP OR $PerformFullCheck Then
			If _CheckForImage($ChamberOfEnlightenment, $x, $y) Then
			   Return $ChamberOfEnlightenment
			EndIf
		 EndIf
		 If _CheckForImage($ConnectionError, $x, $y) Then
			_AddToLog(5, "Connection Error detected")
			If _CheckForImage($OKButton, $x, $y) Then
			   _ClickItem("Button", $x, $y)
			   $SearchTimeOut = _DateAdd("s", $TimeOut, _NowCalc())
			Else
			   _FatalError("_WhereAmI Connection Error Missing OK Button")
			EndIf
		 EndIf
		 If $PerformFullCheck Then
			If $QuickCheck Then
			   Return "Unknown"
			EndIf
;			$PerformFullCheck = False
;			$NextFullCheck = _DateAdd("s", 5, _NowCalc())
		 EndIf
		 If _NowCalc() > $SearchTimeOut Then
			_Click(540, 175)	; Make an attempt to click the X for daily rewards since nothing else is detecting that screen
			If _GetHomeScreen(True) Then	; Make a quick attempt to get the home screen before giving up
			   Return $HomeScreen
			Else
			   _FatalError("WhereAmI - unable to get to a valid state")
			EndIf
		 EndIf
;	  _Click(470, 70)	; Click in the top right corner to keep things moving since finding the arena win/loss pages is unreliable
;	  Sleep(1000) ; Wait a second and try again - disabled as this seems to take time anyway
	  EndIf
   WEnd
EndFunc


Func _AddToLog($LogLevel, $LogText)
   If $LoggingLevel >= $LogLevel Then
	  ;msgbox(64, $ScriptName & $ScriptVersion, $LogText)
   EndIf
EndFunc


Func _ClickItem($ItemType, $x, $y)   ; Shortcut for clicking with offsets
   MouseClick("main", $x + _Offset("x", $ItemType), $y + _Offset("y", $ItemType), 1, 0)
EndFunc


Func _WorldMapDrag($x, $y)   ; Shortcut for clicking with offsets
;   Local $x2 = $x + _Offset("x", "World Map Drag"), $y2 = $y + _Offset("y", "World Map Drag")
   Local $x2 = 240, $y2 = 400
   Switch StringLower($SearchDirection)
	  Case "up"
		 $y2 = $y2 + 200
	  Case "down"
		 $y2 = $y2 - 200
	  Case "left"
		 $x2 = $x2 + 200
	  Case "right"
		 $x2 = $x2 - 200
   EndSwitch
   _ClickDrag(240, 400, $x2, $y2, 10)
;   MouseClickDrag("main", $x + _Offset("x", "World Map Drag"), $y + _Offset("y", "World Map Drag"), $x2, $y2)
EndFunc


Func _Offset($XY, $OffsetType)   ; How far from the corner of the detected image to click. Future feature of random variance to prevent detection
   Local $OffsetX, $OffsetY
   Switch StringLower($OffsetType)
	  Case "icon"
		 $OffsetX = 10
		 $OffsetY = -10
	  Case "button"
		 $OffsetX = 10
		 $OffsetY = 10
	  Case "general"
		 $OffsetX = 0
		 $OffsetY = 0
	  Case "arena button"
		 $OffsetX = 0
		 $OffsetY = 10
	  Case "scrollbar"
		 $OffsetX = 2
		 $OffsetY = 10
	  Case "arena opponent"  ; Offset from the scrollbar, current method of finding the opponent click area
		 $OffsetX = -100
		 $OffsetY = 20
	  Case "world map drag"
		 $OffsetX = -100
		 $OffsetY = 250
	  Case "friend"
		 $OffsetX = 250
		 $OffsetY = 140
	  Case "tm party change"
		 $OffsetX = 100
		 $OffsetY = 100
	  Case "party change"
		 $OffsetX = 460
		 $OffsetY = 160
	  Case Else
		 _FatalError("Syntax Error _Offset - " & $OffsetType)
   EndSwitch
   Switch StringLower($XY)
	  Case "x"
		 Return $OffsetX
	  Case "y"
		 Return $OffsetY
	  Case Else
		 _FatalError("Syntax Error _Offset - " & $XY)
  EndSwitch
EndFunc


Func _FatalError($FatalErrorText)
   Local $MsgBoxTimeOut, $SendEmail = False
   _AddToLog(1, "FATAL ERROR: " & $FatalErrorText)
   _StopTMFarm()
   If $AllowReboot Then
	  $MsgBoxTimeOut = 60
   Else
	  $MsgBoxTimeOut = 0
   EndIf
   If $LastFatalErrorEmail = 0 Then
	  $SendEmail = True
   ElseIf _NowCalc() > _DateAdd("n", 60, $LastFatalErrorEmail) Then	; It has been more than an hour since the last time an email was sent for a fatal error
	  $SendEmail = True
   EndIf
   If $SendEmail Then
	  _CheckWindowPosition()
	  If _ScreenCapture_Capture("Fatal_Error_Screenshot.jpg", $EmulatorX1, $EmulatorY1, $EmulatorX2, $EmulatorY2, False) Then
		 _SendMail("Fatal Error: " & $FatalErrorText, False, "Fatal_Error_Screenshot.jpg")
		 FileDelete("Fatal_Error_Screenshot.jpg")
	  Else
		 _SendMail("Fatal Error: " & $FatalErrorText & @CRLF & "Screenshot failed", False)
	  EndIf
	  IniWrite($IniFile, "Initialize", "Last Fatal Error Email", _NowCalc())
   EndIf
   MsgBox($MB_ICONQUESTION, "Fatal Error", "Fatal Error: " & $FatalErrorText, $MsgBoxTimeOut)
   _Reboot()
EndFunc


Func _CheckWindowPosition($Force = "")
   If _NowCalc() > $NextWindowPositionCheck OR $Force = "Force" Then
	  Local $aEmulatorPosition = WinGetPos($EmulatorName, "")
	  If isArray($aEmulatorPosition) Then
		 $EmulatorX1 = $aEmulatorPosition[0]
		 $EmulatorY1 = $aEmulatorPosition[1]
		 $EmulatorX2 = $EmulatorX1 + $aEmulatorPosition[2]
		 $EmulatorY2 = $EmulatorY1 + $aEmulatorPosition[3]
		 $NextWindowPositionCheck = _DateAdd("s", $PositionCheckInterval, _NowCalc())
	  Else
		 _FatalError("_CheckWindowPosition - unable to find window")
	  EndIf
   EndIf
EndFunc


Func _CheckForImage($ImageFile, byRef $x, byRef $y)
   Local $OffsetX1, $OffsetX2, $OffsetY1, $OffsetY2, $CurrentCheck
   Switch $ImageFile	; reads only the part of the screen that is necessary for each image file to improve performance
	  Case $HomeScreen, $HomeScreenAlt	; covers world icon area on home screen
		 $OffsetX1 = 190
		 $OffsetY1 = 700
		 $OffsetX2 = 400
		 $OffsetY2 = 890
	  Case $OutOfNRG	; covers area where Energy recovery text appears in its window
		 $OffsetX1 = 205
		 $OffsetY1 = 410
		 $OffsetX2 = 375
		 $OffsetY2 = 450
	  Case $SmallHomeButton	; covers upper right side where this can appear on world map or in battle selection
		 $OffsetX1 = 490
		 $OffsetY1 = 190
		 $OffsetX2 = 575
		 $OffsetY2 = 285
	  Case $WorldBackButton	; covers area where back button appears on the world maps
		 $OffsetX1 = 0
		 $OffsetY1 = 190
		 $OffsetX2 = 120
		 $OffsetY2 = 280
	  Case $VortexBackButton	; covers area where back button appears on the vortex pages
		 $OffsetX1 = 10
		 $OffsetY1 = 70
		 $OffsetX2 = 110
		 $OffsetY2 = 135
	  Case $WorldClickGrandshelt	; covers entire area below icons on world maps
		 $OffsetX1 = 0
		 $OffsetY1 = 280
		 $OffsetX2 = 580
		 $OffsetY2 = 1055
	  Case $WorldClickTM, $WorldClickDalnakya2, $WorldClickDalnakya, $WorldClickES	; covers entire area below icons on world maps
		 $OffsetX1 = 0
		 $OffsetY1 = 280
		 $OffsetX2 = 580
		 $OffsetY2 = 1055
	  Case $WorldVortexIcon	; covers area where vortex icon appears on the world map
		 $OffsetX1 = 380
		 $OffsetY1 = 200
		 $OffsetX2 = 465
		 $OffsetY2 = 285
	  Case $TMFarmPartySelected, $RaidPartySelected, $BlankPartyText	; covers area where party name shows up on battle depart page
		 $OffsetX1 = 380
		 $OffsetY1 = 285
		 $OffsetX2 = 575
		 $OffsetY2 = 335
	  Case $TMFarmPartyImage, $RaidPartyImage	; covers area where unit pictures appear in a party when starting a battle
		 $OffsetX1 = 0
		 $OffsetY1 = 340
		 $OffsetX2 = 570
		 $OffsetY2 = 480
	  Case $RaidBanner, $ChamberOfEnlightenmentBanner, $EnlightenmentFreeDailyBanner	; covers the entire area where banners can appear
		 $OffsetX1 = 10
		 $OffsetY1 = 250
		 $OffsetX2 = 565
		 $OffsetY2 = 1015
	  Case $ArenaMainPage, $ArenaSelectionPage, $ArenaRulesPage	; covers area where back button and title are on the arena setup screens
		 $OffsetX1 = 10
		 $OffsetY1 = 200
		 $OffsetX2 = 325
		 $OffsetY2 = 285
	  Case $BattleResultsPage	; covers area where gil text and icon appear on the battle results page
		 $OffsetX1 = 165
		 $OffsetY1 = 420
		 $OffsetX2 = 290
		 $OffsetY2 = 475
	  Case $ConnectionError	; covers area where text of connection error box appears, expanded down to account for the version that kicks to title screen (not tested yet)
		 $OffsetX1 = 75
		 $OffsetY1 = 450
		 $OffsetX2 = 390
		 $OffsetY2 = 525
	  Case $OKButton	; covers area where OK button appears for connection error box, much larger than necessary because it may be used elsewhere
		 $OffsetX1 = 0
		 $OffsetY1 = 475
		 $OffsetX2 = 580
		 $OffsetY2 = 750
	  Case $LapisContinue	; covers area where Continue? text appears on lapis continue first screen
		 $OffsetX1 = 210
		 $OffsetY1 = 240
		 $OffsetX2 = 370
		 $OffsetY2 = 285
	  Case $ContinueNoButton	; covers area where buttons appear on lapis continue first screen
		 $OffsetX1 = 75
		 $OffsetY1 = 500
		 $OffsetX2 = 510
		 $OffsetY2 = 580
	  Case $LapisContinueConfirm	; covers area where text shows up on lapis continue second screen
		 $OffsetX1 = 75
		 $OffsetY1 = 260
		 $OffsetX2 = 510
		 $OffsetY2 = 430
	  Case $ContinueConfirmButton	; covers area where buttons show up on lapis continue second screen
		 $OffsetX1 = 75
		 $OffsetY1 = 500
		 $OffsetX2 = 510
		 $OffsetY2 = 580
	  Case $RaidNextButton, $RaidNextButton2, $RaidNextButton3, $RaidNextButton4	; covers area where next buttons appear on various raid screens
		 $OffsetX1 = 220
		 $OffsetY1 = 900
		 $OffsetX2 = 355
		 $OffsetY2 = 985
	  Case $AbilityBackButton	; covers area where the back button appears when selecting an ability
		 $OffsetX1 = 450
		 $OffsetY1 = 960
		 $OffsetX2 = 560
		 $OffsetY2 = 1050
	  Case $SelectOpponentButton	; covers area where select target appears when an ability that can target a specific ally is selected
		 $OffsetX1 = 10
		 $OffsetY1 = 990
		 $OffsetX2 = 285
		 $OffsetY2 = 1055
	  Case $AppUpdateRequired	; covers area where A new version of the app is available text appears
		 $OffsetX1 = 70
		 $OffsetY1 = 495
		 $OffsetX2 = 500
		 $OffsetY2 = 570
	  Case $AppUpdateButton, $AppUpdateComplete	; covers area where Update and Open buttons appear on the google play app page
		 $OffsetX1 = 300
		 $OffsetY1 = 270
		 $OffsetX2 = 560
		 $OffsetY2 = 325
	  Case $AppUpdateChooseApp	; covers area where Play Store choice shows up if the play store isn't already a default for app updates
		 $OffsetX1 = 1
		 $OffsetY1 = 600
		 $OffsetX2 = 560
		 $OffsetY2 = 1050
	  Case $FFBEIcon	; covers area where FFBE icon text is on the emulator home screen
		 $OffsetX1 = 450
		 $OffsetY1 = 420
		 $OffsetX2 = 540
		 $OffsetY2 = 460
	  Case $LogonScreen	; covers area where logon screen screenshot was taken
		 $OffsetX1 = 75
		 $OffsetY1 = 160
		 $OffsetX2 = 260
		 $OffsetY2 = 360
	  Case $ResumeMission	; covers area where Quest Restart text appears in its box
		 $OffsetX1 = 220
		 $OffsetY1 = 470
		 $OffsetX2 = 365
		 $OffsetY2 = 505
	  Case $CrashError	; covers area where Unfortunately FFEXVIUS has stopped text appears if the app crashes
		 $OffsetX1 = 110
		 $OffsetY1 = 475
		 $OffsetX2 = 465
		 $OffsetY2 = 570
	  Case $LoginClaimButton	; covers area where claim button appears for daily reward notice
		 $OffsetX1 = 205
		 $OffsetY1 = 835
		 $OffsetX2 = 375
		 $OffsetY2 = 900
	  Case $LoginBonusOKButton	; covers area where OK button appears on a special daily login reward notice
		 $OffsetX1 = 200
		 $OffsetY1 = 900
		 $OffsetX2 = 380
		 $OffsetY2 = 975
	  Case $PleaseLogInAgain	; covers area where Please log in again text appears
		 $OffsetX1 = 75
		 $OffsetY1 = 485
		 $OffsetX2 = 280
		 $OffsetY2 = 540
	  Case $ArenaOrbsEmpty	; covers area where arena orbs are shown on arena setup pages
		 $OffsetX1 = 210
		 $OffsetY1 = 940
		 $OffsetX2 = 365
		 $OffsetY2 = 980
	  Case $ArenaOpponentConfirm	; covers area where Select an opponent text appears on the arena opponent confirmation screen
		 $OffsetX1 = 80
		 $OffsetY1 = 485
		 $OffsetX2 = 280
		 $OffsetY2 = 520
	  Case $ArenaBeginButton	; covers area where the arena begin button appears
		 $OffsetX1 = 100
		 $OffsetY1 = 860
		 $OffsetX2 = 460
		 $OffsetY2 = 950
	  Case $ArenaDailyReward
		 $OffsetX1 = 220
		 $OffsetY1 = 360
		 $OffsetX2 = 360
		 $OffsetY2 = 405
	  Case $WorldMainPage	; covers the area where the paladia icon shows up on the world main page
		 $OffsetX1 = 370
		 $OffsetY1 = 205
		 $OffsetX2 = 465
		 $OffsetY2 = 280
	  Case $WorldMapGrandshelt, $WorldMapGrandSheltIsles	; covers area where the back button and text are on the world sub-maps
		 $OffsetX1 = 10
		 $OffsetY1 = 200
		 $OffsetX2 = 315
		 $OffsetY2 = 275
	  Case $DalnakyaSelect	; covers area where icon and text for second battle in selection screen appears
		 $OffsetX1 = 20
		 $OffsetY1 = 500
		 $OffsetX2 = 445
		 $OffsetY2 = 560
	  Case $ESSelect	; covers area where icon and text for third battle in selection screen appears
		 $OffsetX1 = 20
		 $OffsetY1 = 660
		 $OffsetX2 = 445
		 $OffsetY2 = 710
	  Case $VortexMainPage	; covers area where Dimensional Vortex text appears on main vortex page
		 $OffsetX1 = 100
		 $OffsetY1 = 100
		 $OffsetX2 = 310
		 $OffsetY2 = 135
	  Case $RaidBattleSelectionPage	; covers area where rewards button appears on raid battle selection page
		 $OffsetX1 = 385
		 $OffsetY1 = 210
		 $OffsetX2 = 475
		 $OffsetY2 = 285
	  Case $RaidTitle	; covers area where the title of the section (next to the back button) appears
		 $OffsetX1 = 105
		 $OffsetY1 = 230
		 $OffsetX2 = 325
		 $OffsetY2 = 280
	  Case $RaidDepartPage	; covers area where Use 1 raid orb appears on raid depart page
		 $OffsetX1 = 10
		 $OffsetY1 = 890
		 $OffsetX2 = 145
		 $OffsetY2 = 945
	  Case $OutOfRaidOrbs	; covers area where Insufficient raid orbs text appears when raid orbs are gone
		 $OffsetX1 = 190
		 $OffsetY1 = 450
		 $OffsetX2 = 400
		 $OffsetY2 = 510
	  Case $TMFriend, $ESEntrance, $DalnakyaCavern1, $DalnakyaCavern2, $DalnakyaCavern3, $RaidFriendPage	; covers area where text appears next to the back button on battle selection screens
		 $OffsetX1 = 100
		 $OffsetY1 = 230
		 $OffsetX2 = 325
		 $OffsetY2 = 270
	  Case $BattleResultsTMPage	; covers area where unit exp text appears on the battle results TM page
		 $OffsetX1 = 165
		 $OffsetY1 = 155
		 $OffsetX2 = 335
		 $OffsetY2 = 185
	  Case $BattleResultsItemPage	; covers area where Items Obtained text appears on the battle results items page
		 $OffsetX1 = 200
		 $OffsetY1 = 150
		 $OffsetX2 = 370
		 $OffsetY2 = 185
	  Case $TMNextButton	; covers area where next button appears on the battle missions page
		 $OffsetX1 = 225
		 $OffsetY1 = 900
		 $OffsetX2 = 355
		 $OffsetY2 = 965
	  Case $TMDepartButton	; covers area where depart button appears on the battle depart page
		 $OffsetX1 = 160
		 $OffsetY1 = 890
		 $OffsetX2 = 415
		 $OffsetY2 = 965
	  Case $DontRequestButton	; covers area where the don't request button appears for a non-friend companion
		 $OffsetX1 = 20
		 $OffsetY1 = 740
		 $OffsetX2 = 275
		 $OffsetY2 = 820
	  Case $UnitDataUpdated
		 $OffsetX1 = 75
		 $OffsetY1 = 445
		 $OffsetX2 = 500
		 $OffsetY2 = 550
	  Case $DailyQuest
		 $OffsetX1 = 150
		 $OffsetY1 = 290
		 $OffsetX2 = 430
		 $OffsetY2 = 345
	  Case $ActiveMenuButton	; covers area where menu button appears during battle
		 $OffsetX1 = 430
		 $OffsetY1 = 985
		 $OffsetX2 = 575
		 $OffsetY2 = 1055
	  Case $BattleMenuBackButton	; covers area where back button appears when you enter the menu during battle
		 $OffsetX1 = 460
		 $OffsetY1 = 825
		 $OffsetX2 = 565
		 $OffsetY2 = 910
	  Case $ArenaResultsOKButton	; covers area where OK button appears on the arena results page
		 $OffsetX1 = 210
		 $OffsetY1 = 865
		 $OffsetX2 = 375
		 $OffsetY2 = 930
	  Case $ArenaBattleCancelled	; covers area where arena battle cancelled text appears
		 $OffsetX1 = 75
		 $OffsetY1 = 450
		 $OffsetX2 = 515
		 $OffsetY2 = 560
	  Case $ArenaRankUpOKButton	; covers area where OK button appears on the arena rank up page
		 $OffsetX1 = 200
		 $OffsetY1 = 955
		 $OffsetX2 = 375
		 $OffsetY2 = 1020
	  Case $ArenaInBattle, $RaidInBattle, $ESInBattle, $DalnakyaInBattle1, $DalnakyaInBattle2, $DalnakyaInBattle3	; covers area where battle name appears in menu during battle
		 $OffsetX1 = 35
		 $OffsetY1 = 155
		 $OffsetX2 = 550
		 $OffsetY2 = 195
	  Case $ActiveRepeatButton, $ActiveMenuButton	; covers the bottom of the screen where the buttons appear during battle
		 $OffsetX1 = 1
		 $OffsetY1 = 975
		 $OffsetX2 = 580
		 $OffsetY2 = 1055
	  Case $AdRewardAvailable	; covers the area where the next and number appear near the treasure chest on the ad wheel screen
		 $OffsetX1 = 370
		 $OffsetY1 = 885
		 $OffsetX2 = 460
		 $OffsetY2 = 915
	  Case $AdRewardClaimButton	; covers the area where the ad reward claim button appears
		 $OffsetX1 = 210
		 $OffsetY1 = 645
		 $OffsetX2 = 375
		 $OffsetY2 = 705
	  Case $RewardsWheelPage	; covers the area where the rewards wheel text appears next to the back button
		 $OffsetX1 = 110
		 $OffsetY1 = 230
		 $OffsetX2 = 290
		 $OffsetY2 = 280
	  Case $AdsSpinButton	; covers the area where the spin button appears on the rewards wheel page
		 $OffsetX1 = 190
		 $OffsetY1 = 685
		 $OffsetX2 = 390
		 $OffsetY2 = 765
	  Case $AdsSpinButton2	; covers the area where the spin button appears on the spin confirmation window
		 $OffsetX1 = 190
		 $OffsetY1 = 625
		 $OffsetX2 = 390
		 $OffsetY2 = 705
	  Case $RewardsWheelReady	; covers the area where the center of the rewards wheel appears
		 $OffsetX1 = 260
		 $OffsetY1 = 510
		 $OffsetX2 = 330
		 $OffsetY2 = 580
	  Case $AdsNotAvailable, $AdsUsedUp	; covers the area where the text appears on the rewards wheel page
		 $OffsetX1 = 40
		 $OffsetY1 = 685
		 $OffsetX2 = 440
		 $OffsetY2 = 765
	  Case $ExpeditionNextButton	; covers the area where the next button appears when claiming an expedition
		 $OffsetX1 = 225
		 $OffsetY1 = 980
		 $OffsetX2 = 350
		 $OffsetY2 = 1045
	  Case $ExpeditionsCompleted, $ExpeditionsNotCompleted	; covers the area where the ongoing button appears on the expeditions screen
		 $OffsetX1 = 220
		 $OffsetY1 = 345
		 $OffsetX2 = 360
		 $OffsetY2 = 390
	  Case $ExpeditionsNew	; covers the area where the new button appears on the expeditions screen
		 $OffsetX1 = 10
		 $OffsetY1 = 320
		 $OffsetX2 = 170
		 $OffsetY2 = 400
	  Case $ExpeditionsScreen, $ExpeditionsScreen2, $ExpeditionsRewardScreen, $ExpeditionsRewardScreen2	; covers the area where the text appears next to the back button on the expeditions screen
		 $OffsetX1 = 105
		 $OffsetY1 = 240
		 $OffsetX2 = 300
		 $OffsetY2 = 295
	  Case $ExpeditionComplete[1]	; covers the area where the complete text appears when an expedition in slot 1 is complete
		 $OffsetX1 = 195
		 $OffsetY1 = 495
		 $OffsetX2 = 425
		 $OffsetY2 = 550
	  Case $ExpeditionComplete[2]	; covers the area where the complete text appears when an expedition in slot 2 is complete
		 $OffsetX1 = 195
		 $OffsetY1 = 640
		 $OffsetX2 = 425
		 $OffsetY2 = 695
	  Case $ExpeditionComplete[3]	; covers the area where the complete text appears when an expedition in slot 3 is complete
		 $OffsetX1 = 195
		 $OffsetY1 = 785
		 $OffsetX2 = 425
		 $OffsetY2 = 840
	  Case $ExpeditionComplete[4]	; covers the area where the complete text appears when an expedition in slot 4 is complete
		 $OffsetX1 = 195
		 $OffsetY1 = 930
		 $OffsetX2 = 425
		 $OffsetY2 = 985
	  Case $ExpeditionAutoFillButton, $ExpeditionAutoFillDisabled	; covers the area where the auto fill button appears when starting an expedition
		 $OffsetX1 = 15
		 $OffsetY1 = 960
		 $OffsetX2 = 275
		 $OffsetY2 = 1040
	  Case $ExpeditionCancelScreen	; covers the area where the expedition cancel screen appears when trying to start too many expeditions
		 $OffsetX1 = 70
		 $OffsetY1 = 480
		 $OffsetX2 = 505
		 $OffsetY2 = 555
	  Case $ExpeditionDepartButton1	; covers the area where the depart button appeats when starting an expedition
		 $OffsetX1 = 305
		 $OffsetY1 = 960
		 $OffsetX2 = 560
		 $OffsetY2 = 1040
	  Case $ExpeditionDepartButton2	; covers the area where the depart button appears on the item add screen with starting an expedition
		 $OffsetX1 = 200
		 $OffsetY1 = 755
		 $OffsetX2 = 370
		 $OffsetY2 = 815
	  Case $ExpeditionClaimReward	; covers the area where the achievement rewards text appears on the expedition claim reward window
		 $OffsetX1 = 120
		 $OffsetY1 = 485
		 $OffsetX2 = 470
		 $OffsetY2 = 525
	  Case $ExpeditionRefreshFree	; covers the area where the refresh button appears on the expeditions screen
		 $OffsetX1 = 195
		 $OffsetY1 = 975
		 $OffsetX2 = 385
		 $OffsetY2 = 1050
	  Case $DailyQuestScreen	; covers the area where the quests text appears at the top of the daily quest screen
		 $OffsetX1 = 105
		 $OffsetY1 = 90
		 $OffsetX2 = 300
		 $OffsetY2 = 145
	  Case $DailyQuestClaimAllButton	; covers the area where the claim all button appears on the daily quest screen
		 $OffsetX1 = 175
		 $OffsetY1 = 950
		 $OffsetX2 = 390
		 $OffsetY2 = 1000
	  Case $FriendsScreen, $ReceiveGiftsScreen, $SendGiftsScreen	; covers the area where the text appears next to the back button on the friends screens
		 $OffsetX1 = 105
		 $OffsetY1 = 230
		 $OffsetX2 = 250
		 $OffsetY2 = 280
	  Case $ManagePartyScreen, $SelectBaseScreen, $EnhanceUnitsScreen, $MaterialUnitsScreen	; covers the area where the text appears next to the back button on the various enhancement screens
		 $OffsetX1 = 105
		 $OffsetY1 = 230
		 $OffsetX2 = 250
		 $OffsetY2 = 280
	  Case $FilteredList	; covers the area where the filtered button appears when the unit lists are filtered
		 $OffsetX1 = 370
		 $OffsetY1 = 235
		 $OffsetX2 = 500
		 $OffsetY2 = 285
	  Case $Level1Enhancer	; covers the area where the unit level number appears on the enhance units screen
		 $OffsetX1 = 235
		 $OffsetY1 = 285
		 $OffsetX2 = 330
		 $OffsetY2 = 315
	  Case $SortScreen	; covers the area where the sort tab appears on the sort/filter screen
		 $OffsetX1 = 125
		 $OffsetY1 = 75
		 $OffsetX2 = 340
		 $OffsetY2 = 155
	  Case $FilterScreen	; covers the area where the filter tab appears on the sort/filter screen
		 $OffsetX1 = 350
		 $OffsetY1 = 75
		 $OffsetX2 = 570
		 $OffsetY2 = 155
	  Case $UnitFilter1, $UnitFilter2, $UnitFilter3, $UnitFilter4, $UnitFilter5, $UnitFilter1Alt, $UnitFilter3Alt	; covers the area where the unit filters appear on the screen (most of the screen, but this is not usually checked)
		 $OffsetX1 = 0
		 $OffsetY1 = 155
		 $OffsetX2 = 580
		 $OffsetY2 = 840
	  Case $SkipButton	; covers the area where the skip button appears when enhancing a unit
		 $OffsetX1 = 465
		 $OffsetY1 = 860
		 $OffsetX2 = 560
		 $OffsetY2 = 910
	  Case $ItemSetScreen, $MaterialsScreen, $SellMaterialsScreen ; covers the area where the text appears next to the back button on the various materials screens
		 $OffsetX1 = 105
		 $OffsetY1 = 230
		 $OffsetX2 = 250
		 $OffsetY2 = 280
	  Case $SellMaterialsBottom	; covers the area at the bottom of the materials list where a blank area appars when the end of the list is reached
		 $OffsetX1 = 0
		 $OffsetY1 = 885
		 $OffsetX2 = 300
		 $OffsetY2 = 930
	  Case $MaterialCapacityReached, $EquipmentCapacityReached, $AbilityCapacityReached, $ItemCapacityReached	; covers the area where the capacity reached text appears
		 $OffsetX1 = 140
		 $OffsetY1 = 440
		 $OffsetX2 = 455
		 $OffsetY2 = 485
	  Case $RaidSummonScreen ; covers the area where the text appears next to the back button on the raid summon screen
		 $OffsetX1 = 105
		 $OffsetY1 = 230
		 $OffsetX2 = 250
		 $OffsetY2 = 280
	  Case $RaidSummonNextButton, $RaidSummonNextButton2 ; covers the area where the next buttons appear when raid summon screens are ready to be cleared
		 $OffsetX1 = 230
		 $OffsetY1 = 910
		 $OffsetX2 = 355
		 $OffsetY2 = 980
	  Case $RaidSummonNextButton3, $RaidSummonNextButton4 ; covers the area where the next button appears when raid summon screens are ready to be cleared with a short unit list
		 $OffsetX1 = 230
		 $OffsetY1 = 835
		 $OffsetX2 = 355
		 $OffsetY2 = 895
	  Case $RaidSummonConfirm ; covers the area where the raid summon text appears on the confirm summon screen
		 $OffsetX1 = 100
		 $OffsetY1 = 430
		 $OffsetX2 = 500
		 $OffsetY2 = 475
	  Case $ViewUnitsScreen, $SellUnitsScreen ; covers the area where the text appears next to the back button on the view/sell units screens
		 $OffsetX1 = 105
		 $OffsetY1 = 230
		 $OffsetX2 = 250
		 $OffsetY2 = 280
	  Case $UnitSoldOKButton ; covers the area where the ok button appears when completing a unit sale
		 $OffsetX1 = 205
		 $OffsetY1 = 565
		 $OffsetX2 = 375
		 $OffsetY2 = 630
	  Case $SaleFilter ; covers the area where the unit filters appear (most of the screen)
		 $OffsetX1 = 0
		 $OffsetY1 = 155
		 $OffsetX2 = 580
		 $OffsetY2 = 840
	  Case $AnnouncementCloseButton	; covers the area where the close button appears on announcement screens
		 $OffsetX1 = 225
		 $OffsetY1 = 975
		 $OffsetX2 = 355
		 $OffsetY2 = 1025
	  Case $EquipButton	; covers the area where the equip button appears on a unit page
		 $OffsetX1 = 20
		 $OffsetY1 = 465
		 $OffsetX2 = 165
		 $OffsetY2 = 525
	  Case $DownloadAcceptScreen	; covers the area where the proceed with download text appears on the download acceptance screen with the Yes button
		 $OffsetX1 = 60
		 $OffsetY1 = 560
		 $OffsetX2 = 340
		 $OffsetY2 = 620
	  Case $DownloadAcceptScreen2	; covers the area where the proceed with download text appears on the download acceptance screen with the OK button
		 $OffsetX1 = 60
		 $OffsetY1 = 570
		 $OffsetX2 = 340
		 $OffsetY2 = 630
	  Case $ExpeditionAccelerateButton	; covers the area where the accelerate button appears when clicking on an active expedition
		 $OffsetX1 = 185
		 $OffsetY1 = 650
		 $OffsetX2 = 395
		 $OffsetY2 = 715
	  Case $ExpeditionRecallButtonTM	; covers the area where the recall button appears when clicking on an active expedition TM expedition
		 $OffsetX1 = 185
		 $OffsetY1 = 625
		 $OffsetX2 = 395
		 $OffsetY2 = 690
	  Case $FusionUnitsTab	; covers the area where the fusion units tab appears when selecting a unit to enhance
		 $OffsetX1 = 190
		 $OffsetY1 = 315
		 $OffsetX2 = 385
		 $OffsetY2 = 375
	  Case $SelectPartyScreen ; covers the area where the text appears next to the back button on the select party screen
		 $OffsetX1 = 105
		 $OffsetY1 = 230
		 $OffsetX2 = 250
		 $OffsetY2 = 280
	  Case $ExpeditionTMDepartButton ; covers the area where the depart button appears on the expedition screen for TM expeditions
		 $OffsetX1 = 160
		 $OffsetY1 = 960
		 $OffsetX2 = 420
		 $OffsetY2 = 1040
	  Case $CannotVerifyAccount ; covers the area where the cannot verify account text appears with google login and switching devices
		 $OffsetX1 = 75
		 $OffsetY1 = 480
		 $OffsetX2 = 460
		 $OffsetY2 = 555
	  Case $LoginOptionsButton ; covers the area where the login options button appears on the logon screen
		 $OffsetX1 = 180
		 $OffsetY1 = 885
		 $OffsetX2 = 400
		 $OffsetY2 = 950
	  Case $SignInWithGoogleButton ; covers the area where the sign in with google button appears
		 $OffsetX1 = 115
		 $OffsetY1 = 570
		 $OffsetX2 = 465
		 $OffsetY2 = 625
	  Case $ChooseAnAccountScreen, $ChooseAccountScreen ; covers the area where the choose an account or choose account text appears when selecting the google account
		 $OffsetX1 = 100
		 $OffsetY1 = 420
		 $OffsetX2 = 460
		 $OffsetY2 = 490
	  Case $GoogleAccessScreen ; covers the area where the FFEXVIUS would like to: text appears when selecting the google account
		 $OffsetX1 = 20
		 $OffsetY1 = 210
		 $OffsetX2 = 320
		 $OffsetY2 = 255
	  Case $ExistingAccountDataScreen ; covers the area where the existing account data message appears during a google login
		 $OffsetX1 = 120
		 $OffsetY1 = 440
		 $OffsetX2 = 470
		 $OffsetY2 = 485
	  Case $OverwriteDeviceData ; covers the area where the overwrite device data text appears during a google login
		 $OffsetX1 = 175
		 $OffsetY1 = 515
		 $OffsetX2 = 420
		 $OffsetY2 = 570
	  Case $MaterialFullStack ; covers the area where the 199 text appears on a full stack of materials
		 $OffsetX1 = 215
		 $OffsetY1 = 460
		 $OffsetX2 = 330
		 $OffsetY2 = 520
	  Case $MaterialsSellGilCap ; covers the area where the you will reach your gil capacity text appears when selling materials at the gil cap
		 $OffsetX1 = 70
		 $OffsetY1 = 480
		 $OffsetX2 = 510
		 $OffsetY2 = 575
	  Case $SummonPopUp ; covers the area where the summon now button appears on the summon popup
		 $OffsetX1 = 205
		 $OffsetY1 = 795
		 $OffsetX2 = 375
		 $OffsetY2 = 860
	  Case $GooglePlayGames ; covers the area where ffbe ww wants to access your google account appears when google play games wants permissions (again)
		 $OffsetX1 = 90
		 $OffsetY1 = 125
		 $OffsetX2 = 460
		 $OffsetY2 = 305
	  Case $GooglePlayGames2 ; covers the area where turn on automatic sign-in? appears when google play games wants permissions (again)
		 $OffsetX1 = 15
		 $OffsetY1 = 815
		 $OffsetX2 = 375
		 $OffsetY2 = 860
	  Case $ChamberOfEnlightenment ; covers the area where the chamber of enlightenment text appears next to the back button
		 $OffsetX1 = 100
		 $OffsetY1 = 230
		 $OffsetX2 = 375
		 $OffsetY2 = 270

	  Case Else	; anything undefined will use the entire emulator window, this should be avoided unless absolutely necessary, it is extremely slow, especially if making multiple calls
		 $OffsetX1 = 0
		 $OffsetY1 = 0
		 $OffsetX2 = $EmulatorX2
		 $OffsetY2 = $EmulatorY2
		 For $CurrentCheck = 1 TO $MaterialsList[0][0]
			If $ImageFile = $MaterialsList[$CurrentCheck][$MaterialDescription] Then	; covers area where the item name appears on the material sale screen
			   $OffsetX1 = 30
			   $OffsetY1 = 340
			   $OffsetX2 = 250
			   $OffsetY2 = 380
			   ExitLoop
			EndIf
		 Next
   EndSwitch
   _CheckWindowPosition()
   If _ImageSearchArea($ImageFile, 0, $EmulatorX1 + $OffsetX1, $EmulatorY1 + $OffsetY1, $EmulatorX1 + $OffsetX2, $EmulatorY1 + $OffsetY2, $x, $y, 60) = 1 Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc


Func _CheckForImageExact($ImageFile, byRef $x, byRef $y)   ; This will not allow any color deviations on the image, used to tell when buttons are disabled
   _CheckWindowPosition()
   If _ImageSearchArea($ImageFile, 0, $EmulatorX1, $EmulatorY1, $EmulatorX2, $EmulatorY2, $x, $y, 0) = 1 Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc


Func _CheckForImageArea($ImageFile, byRef $x, byRef $y, $LeftSide, $TopSide, $RightSide, $BottomSide)
   _CheckWindowPosition()
   If _ImageSearchArea($ImageFile, 0, $EmulatorX1 + $LeftSide, $EmulatorY1 + $TopSide, $EmulatorX1 + $RightSide, $EmulatorY1 + $BottomSide, $x, $y, 60) = 1 Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc


; Copied from ImageSearch.au3 and modified to keep the .dll open for faster processing

;===============================================================================
Func _ImageSearch($findImage, $resultPosition, ByRef $x, ByRef $y, $tolerance, $HBMP=0)
   return _ImageSearchArea($findImage, $resultPosition, 0, 0, @DesktopWidth, @DesktopHeight, $x, $y, $tolerance, $HBMP)
EndFunc


Func _ImageSearchArea($findImage, $resultPosition, $x1, $y1, $right, $bottom, ByRef $x, ByRef $y, $tolerance, $HBMP=0)
   Local $result, $array
	;MsgBox(0,"asd","" & $x1 & " " & $y1 & " " & $right & " " & $bottom)
	If $tolerance > 0 Then $findImage = "*" & $tolerance & " " & $findImage
   If IsString($findImage) Then
	  $result = DllCall($DllHandle, "str", "ImageSearch", "int", $x1, "int", $y1, "int", $right, "int", $bottom, "str", $findImage, "ptr", $HBMP)
   Else
	  $result = DllCall($DllHandle, "str", "ImageSearch", "int", $x1, "int", $y1, "int", $right, "int", $bottom, "ptr", $findImage, "ptr", $HBMP)
   EndIf

	; If error exit
    if $result[0]="0" then return 0

	; Otherwise get the x,y location of the match and the size of the image to
	; compute the centre of search
	$array = StringSplit($result[0],"|")

   $x=Int(Number($array[2]))
   $y=Int(Number($array[3]))
   if $resultPosition=1 then
      $x=$x + Int(Number($array[4])/2)
      $y=$y + Int(Number($array[5])/2)
   endif
   return 1
EndFunc


Func _SendMail($sBody, $SendAsText = True, $sAttachFiles = "")
   Local $sSmtpServer = "smtp.gmail.com" ; address for the smtp-server to use - REQUIRED
   Local $sFromName = $ScriptName ; name from who the email was sent
   Local $sFromAddress = $GmailAccount ; address from where the mail should come
   If $SendAsText Then
	  Local $sToAddress = $TextEmailAddress ; destination address of the email - REQUIRED
   Else
	  Local $sToAddress = $StandardEmailAddress ; destination address of the email - REQUIRED
   EndIf
   Local $sSubject = $EmulatorName ; subject from the email - can be anything you want it to be
;  Local $sBody = "test" ; the messagebody from the mail - can be left blank but then you get a blank mail
;  Local $sAttachFiles = "" ; the file(s) you want to attach seperated with a ; (Semicolon) - leave blank if not needed
   Local $sCcAddress = "" ; address for cc - leave blank if not needed
   Local $sBccAddress = "" ; address for bcc - leave blank if not needed
   Local $sImportance = "Normal" ; Send message priority: "High", "Normal", "Low"
   Local $sUsername = $GmailAccount ; username for the account used from where the mail gets sent - REQUIRED
   Local $sPassword = $GmailPassword ; password for the account used from where the mail gets sent - REQUIRED
   Local $iIPPort = 465 ; GMAIL port used for sending the mail
   Local $bSSL = True ; GMAIL enables/disables secure socket layer sending - set to True if using httpS
   Local $bIsHTMLBody = False
   Local $iDSNOptions = $g__cdoDSNDefault
   _INetSmtpMailCom($sSmtpServer, $sFromName, $sFromAddress, $sToAddress, $sSubject, $sBody, $sAttachFiles, $sCcAddress, $sBccAddress, $sImportance, $sUsername, $sPassword, $iIPPort, $bSSL, $bIsHTMLBody, $iDSNOptions)
EndFunc


#Region UDF Functions
; The UDF
; #FUNCTION# ====================================================================================================================
; Name ..........: _INetSmtpMailCom
; Description ...:
; Syntax ........: _INetSmtpMailCom($s_SmtpServer, $s_FromName, $s_FromAddress, $s_ToAddress[, $s_Subject = ""[, $as_Body = ""[,
;                  $s_AttachFiles = ""[, $s_CcAddress = ""[, $s_BccAddress = ""[, $s_Importance = "Normal"[, $s_Username = ""[,
;                  $s_Password = ""[, $IPPort = 25[, $bSSL = False[, $bIsHTMLBody = False[, $iDSNOptions = $g__cdoDSNDefault]]]]]]]]]]]])
; Parameters ....: $s_SmtpServer        - A string value.
;                  $s_FromName          - A string value.
;                  $s_FromAddress       - A string value.
;                  $s_ToAddress         - A string value.
;                  $s_Subject           - [optional] A string value. Default is "".
;                  $s_Body              - [optional] A string value. Default is "".
;                  $s_AttachFiles       - [optional] A string value. Default is "".
;                  $s_CcAddress         - [optional] A string value. Default is "".
;                  $s_BccAddress        - [optional] A string value. Default is "".
;                  $s_Importance        - [optional] A string value. Default is "Normal".
;                  $s_Username          - [optional] A string value. Default is "".
;                  $s_Password          - [optional] A string value. Default is "".
;                  $IPPort              - [optional] An integer value. Default is 25.
;                  $bSSL                - [optional] A binary value. Default is False.
;                  $bIsHTMLBody         - [optional] A binary value. Default is False.
;                  $iDSNOptions         - [optional] An integer value. Default is $g__cdoDSNDefault.
; Return values .: None
; Author ........: Jos
; Modified ......: mLipok
; Remarks .......:
; Related .......: http://www.autoitscript.com/forum/topic/23860-smtp-mailer-that-supports-html-and-attachments/
; Link ..........: http://www.autoitscript.com/forum/topic/167292-smtp-mailer-udf/
; Example .......: Yes
; ===============================================================================================================================
Func _INetSmtpMailCom($s_SmtpServer, $s_FromName, $s_FromAddress, $s_ToAddress, $s_Subject = "", $s_Body = "", $s_AttachFiles = "", $s_CcAddress = "", $s_BccAddress = "", $s_Importance = "Normal", $s_Username = "", $s_Password = "", $IPPort = 25, $bSSL = False, $bIsHTMLBody = False, $iDSNOptions = $g__cdoDSNDefault)
    ; init Error Handler
    _INetSmtpMailCom_ErrObjInit()

    Local $objEmail = ObjCreate("CDO.Message")
    If Not IsObj($objEmail) Then Return SetError($g__INetSmtpMailCom_ERROR_ObjectCreation, Dec(_INetSmtpMailCom_ErrHexNumber()), _INetSmtpMailCom_ErrDescription())

    ; Clear previous Err information
    _INetSmtpMailCom_ErrHexNumber(0)
    _INetSmtpMailCom_ErrDescription('')
    _INetSmtpMailCom_ErrScriptLine('')

    $objEmail.From = '"' & $s_FromName & '" <' & $s_FromAddress & '>'
    $objEmail.To = $s_ToAddress

    If $s_CcAddress <> "" Then $objEmail.Cc = $s_CcAddress
    If $s_BccAddress <> "" Then $objEmail.Bcc = $s_BccAddress
    $objEmail.Subject = $s_Subject

    ; Select whether or not the content is sent as plain text or HTM
    If $bIsHTMLBody Then
        $objEmail.Textbody = $s_Body & @CRLF
    Else
        $objEmail.HTMLBody = $s_Body
    EndIf

    ; Add Attachments
    If $s_AttachFiles <> "" Then
        Local $S_Files2Attach = StringSplit($s_AttachFiles, ";")
        For $x = 1 To $S_Files2Attach[0]
            $S_Files2Attach[$x] = _PathFull($S_Files2Attach[$x])
            If FileExists($S_Files2Attach[$x]) Then
                ConsoleWrite('+> File attachment added: ' & $S_Files2Attach[$x] & @LF)
                $objEmail.AddAttachment($S_Files2Attach[$x])
            Else
                ConsoleWrite('!> File not found to attach: ' & $S_Files2Attach[$x] & @LF)
                Return SetError($g__INetSmtpMailCom_ERROR_FileNotFound, 0, 0)
            EndIf
        Next
    EndIf

    ; Set Email Configuration
    $objEmail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/sendusing") = $g__cdoSendUsingPort
    $objEmail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpserver") = $s_SmtpServer
    If Number($IPPort) = 0 Then $IPPort = 25
    $objEmail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpserverport") = $IPPort
    ;Authenticated SMTP
    If $s_Username <> "" Then
        $objEmail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpauthenticate") = $g__cdoBasic
        $objEmail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/sendusername") = $s_Username
        $objEmail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/sendpassword") = $s_Password
    EndIf
    $objEmail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpusessl") = $bSSL

    ;Update Configuration Settings
    $objEmail.Configuration.Fields.Update

    ; Set Email Importance
    Switch $s_Importance
        Case "High"
            $objEmail.Fields.Item("urn:schemas:mailheader:Importance") = "High"
        Case "Normal"
            $objEmail.Fields.Item("urn:schemas:mailheader:Importance") = "Normal"
        Case "Low"
            $objEmail.Fields.Item("urn:schemas:mailheader:Importance") = "Low"
    EndSwitch

    ; Set DSN options
    If $iDSNOptions <> $g__cdoDSNDefault And $iDSNOptions <> $g__cdoDSNNever Then
        $objEmail.DSNOptions = $iDSNOptions
        $objEmail.Fields.Item("urn:schemas:mailheader:disposition-notification-to") = $s_FromAddress
;~      $objEmail.Fields.Item("urn:schemas:mailheader:return-receipt-to") = $s_FromAddress
    EndIf

    ; Update Importance and Options fields
    $objEmail.Fields.Update

    ; Sent the Message
    $objEmail.Send

    If @error Then
        _INetSmtpMailCom_ErrObjCleanUp()
        Return SetError($g__INetSmtpMailCom_ERROR_Send, Dec(_INetSmtpMailCom_ErrHexNumber()), _INetSmtpMailCom_ErrDescription())
    EndIf

    ; CleanUp
    $objEmail = ""
    _INetSmtpMailCom_ErrObjCleanUp()

EndFunc   ;==>_INetSmtpMailCom

;
; Com Error Handler
Func _INetSmtpMailCom_ErrObjInit($bParam = Default)
    Local Static $oINetSmtpMailCom_Error = Default
    If $bParam == 'CleanUp' And $oINetSmtpMailCom_Error <> Default Then
        $oINetSmtpMailCom_Error = ''
        Return $oINetSmtpMailCom_Error
    EndIf
    If $oINetSmtpMailCom_Error = Default Then
        $oINetSmtpMailCom_Error = ObjEvent("AutoIt.Error", "_INetSmtpMailCom_ErrFunc")
    EndIf
    Return $oINetSmtpMailCom_Error
EndFunc   ;==>_INetSmtpMailCom_ErrObjInit

Func _INetSmtpMailCom_ErrObjCleanUp()
    _INetSmtpMailCom_ErrObjInit('CleanUp')
EndFunc   ;==>_INetSmtpMailCom_ErrObjCleanUp

Func _INetSmtpMailCom_ErrHexNumber($vData = Default)
    Local Static $vReturn = 0
    If $vData <> Default Then $vReturn = $vData
    Return $vReturn
EndFunc   ;==>_INetSmtpMailCom_ErrHexNumber

Func _INetSmtpMailCom_ErrDescription($sData = Default)
    Local Static $sReturn = ''
    If $sData <> Default Then $sReturn = $sData
    Return $sReturn
EndFunc   ;==>_INetSmtpMailCom_ErrDescription

Func _INetSmtpMailCom_ErrScriptLine($iData = Default)
    Local Static $iReturn = ''
    If $iData <> Default Then $iReturn = $iData
    Return $iReturn
EndFunc   ;==>_INetSmtpMailCom_ErrScriptLine

Func _INetSmtpMailCom_ErrFunc()
    _INetSmtpMailCom_ErrObjInit()
    _INetSmtpMailCom_ErrHexNumber(Hex(_INetSmtpMailCom_ErrObjInit().number, 8))
    _INetSmtpMailCom_ErrDescription(StringStripWS(_INetSmtpMailCom_ErrObjInit().description, 3))
    _INetSmtpMailCom_ErrScriptLine(_INetSmtpMailCom_ErrObjInit().ScriptLine)
    SetError(1) ; something to check for when this function returns
    Return
EndFunc   ;==>_INetSmtpMailCom_ErrFunc

#EndRegion UDF Functions