/*
A simple example of usage, in a class-based scenario
CHotkeyHandler is passed BoundFunc objects.
*/
#SingleInstance force
#include CHotkeyHandler.ahk
OutputDebug DBGVIEWCLEAR

mc := new MyClass()
return

GuiClose:
	ExitApp
	
Class MyClass {
	__New(){
		; You could put a hotkey, ifwinactive command here to limit hotkeys to a specific application
		this.hh := new CHotkeyHandler(this.HotkeyChanged.Bind(this))
		this.hotkeys := {}
		this.hotkeys.hk1 := this.hh.AddHotkey("hk1", this.HKPressed.Bind(this, "hk1"), "w200")
		this.hotkeys.hk2 := this.hh.AddHotkey("hk2", this.HKPressed.Bind(this, "hk2"), "w200")
		; Load Hotkeys after declaring all hotkeys
		this.LoadHotkeys()
		Gui, Show, x0 y0
	}
	
	; A hotkey was pressed or released. event holds 1 for down, 0 for up.
	; Seeing as we bound the name to the callback, we also get the name as the first param
	HKPressed(name, event){
		ToolTip % "Hoktey " name " (" this.hotkeys[name].HumanReadable ") " (event ? "Pressed" : "Released")
		fn := this.TT.Bind(this)
		SetTimer, % fn, -500
	}

	; Load hotkey values from INI file
	LoadHotkeys(){
		for name, hk in this.hotkeys {
			IniRead, value, % A_ScriptName ".ini", Hotkeys, % name
			if (value != "" && value != "ERROR")
				this.hotkeys[name].value := value
		}
	}
	
	; A Hotkey changed binding - save value to ini file
	HotkeyChanged(name, hk){
		IniWrite, % hk, % A_ScriptName ".ini", Hotkeys, % name
		ToolTip % "Hotkey " name " Changed binding to: " this.hotkeys[name].HumanReadable
		fn := this.TT.Bind(this)
		SetTimer, % fn, -500
	}
	
	TT(){
		ToolTip
	}
}
