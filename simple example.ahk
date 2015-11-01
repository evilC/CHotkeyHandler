/*
A simple example of usage, just using functions and labels 
CHotkeyHandler is passed strings of function names.
*/
#SingleInstance force
#include CHotkeyHandler.ahk
OutputDebug DBGVIEWCLEAR

; You could put a hotkey, ifwinactive command here to limit hotkeys to a specific application
hh := new CHotkeyHandler("HotkeyChanged")
hotkeys := {}
hotkeys.hk1 := hh.AddHotkey("hk1", "HK1Pressed", "w200")
hotkeys.hk2 := hh.AddHotkey("hk2", "HK2Pressed", "w200")
; Load Hotkeys after declaring all hotkeys
LoadHotkeys()
Gui, Show, x0 y0
return

GuiClose:
	ExitApp

; Hotkey 1 was pressed or released. event holds 1 for down, 0 for up
HK1Pressed(event){
	global hotkeys
	ToolTip % "Hoktey 1 (" hotkeys.hk1.HumanReadable ") " (event ? "Pressed" : "Released")
	SetTimer, TT, -500
}

; Hotkey 2 was pressed or released. event holds 1 for down, 0 for up
HK2Pressed(event){
	global hotkeys
	ToolTip % "Hoktey 2 (" hotkeys.hk2.HumanReadable ") " (event ? "Pressed" : "Released")
	SetTimer, TT, -500
}

; A Hotkey changed binding - save value to ini file
HotkeyChanged(name, hk){
	global hotkeys
	IniWrite, % hk, % A_ScriptName ".ini", Hotkeys, % name
	ToolTip % "Hotkey " name " Changed binding to: " hotkeys[name].HumanReadable
}

; Load hotkey values from INI file
LoadHotkeys(){
	global hotkeys
	for name, hk in hotkeys {
		IniRead, value, % A_ScriptName ".ini", Hotkeys, % name
		if (value != "" && value != "ERROR")
			hotkeys[name].value := value
	}
}

TT:
	ToolTip
