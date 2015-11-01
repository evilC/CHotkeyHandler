OutputDebug DBGVIEWCLEAR
#SingleInstance force


hh := new CHotkeyHandler("HotkeyChanged")
hotkeys := {}
hotkeys.hk1 := hh.AddHotkey("hk1", "HK1Pressed", "w200")
hotkeys.hk2 := hh.AddHotkey("hk2", "HK2Pressed", "w200")
LoadHotkeys()
Gui, Show, x0 y0
return

GuiClose:
	ExitApp
	return
	
HK1Pressed(event){
	global hotkeys
	ToolTip % "Hoktey 1 (" hotkeys.hk1.HumanReadable ") " (event ? "Pressed" : "Released")
	SetTimer, TT, -500
}

HK2Pressed(event){
	global hotkeys
	;ToolTip % "Hoktey 2 " (event ? "Pressed" : "Released")
	ToolTip % "Hoktey 2 (" hotkeys.hk2.HumanReadable ") " (event ? "Pressed" : "Released")
	SetTimer, TT, -500
}

; A Hotkey changed binding - save value to ini file
HotkeyChanged(name, hk){
	global hotkeys
	IniWrite, % hk, % A_ScriptName ".ini", Hotkeys, % name
	ToolTip % "Hotkey " name " Changed binding to: " hotkeys[name].HumanReadable
}

; Load hotkey bindings from INI file
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

/*
mc := new MyClass()
return

GuiClose:
	ExitApp
	return
	
Class MyClass {
	__New(){
		this.hh := new CHotkeyHandler()
		this.hh.AddHotkey("hk1", this.HKPressed.Bind(this, "hk1"), "w200")
		this.hh.AddHotkey("hk2", this.HKPressed.Bind(this, "hk2"), "w200")
		Gui, Show, x0 y0
	}
	
	HKPressed(name, event){
		ToolTip % "Hoktey " name " - " event
	}
}
*/

; CHotkeyHandler controls ALL hotkeys. Users call this class to create a new hotkey guicontrol, and it instantiates a CHotkeyControl class for each one.
; Flow of control for adding and binding of a hotkey:
; 1) User selects the "Select Binding" option from an instance of the CHotkeyControl class
; 2) The CHotkeyControl instance calls the CInputDetector class and passes it a callback to itself.
; 3) The CInputDetector class presents a dialog instructing the user to pick a key.
;    Once the user selects a hotkey, CInputDetector fires the callback to the CHotkeyControl instance.
; 4) The CHotkeyControl instance then makes a call to CHotkeyHandler to ask it to bind this hotkey.
;    If the key is already bound in another CHotkeyControl instance, CHotkeyHandler presents a dialog saying that the hotkey conflicts with another...
;    ... then returns a value to the CHotkeyControl instance to instruct it to not accept that binding.
Class CHotkeyHandler {
	_BindMode := 0
	; Hotkey lookup arrays. Each hotkey has a NAME and a BINDSTRING (eg "^+a")
	_HotkeyObjects := {}		; All the instantiated Hotkey objects. name -> object
	_HotkeyCallbacks := {}		; The (user) callbacks for all the hotkeys. name -> callback
	_HotkeyBindings := {}		; The parameters used for the hotkey command. name -> bindstring
	_BoundKeys := {}			; Currently bound hotkeys. Used to detect attempt to bind same hotkey twice. NOTE: ~ is filtered out, as it does not affect uniqueness. bindstring -> name
	_HeldHotkeys := {}			; A list of Hotkeys currently in the Down state (Used for repeat supression), name -> nothing
	
	; Public Methods ------------------------------------------------------------------------
	__New(callback := 0){
		if (callback != 0 && !IsObject(callback))
			callback := Func(callback)
		this._callback := callback
		this._InputDetector := new this.CInputDetector(this)
	}
	
	; Add a Hotkey GuiControl to a script
	AddHotkey(name, callback, options){
		if (!IsObject(callback))
			callback := Func(callback)
		this._HotkeyCallbacks[name] := callback
		this._HotkeyObjects[name] := new this.CHotkeyControl(this, name, options)
		return this._HotkeyObjects[name]
	}

	; Private Methods -------------------------------------------------------------------------
	
	; Request to enter Bind Mode
	RequestBindMode(name, callback){
		if (this._BindMode){
			return 0
		} else {
			this._BindMode := 1
			this.DisableHotkeys()
			this._InputDetector.SelectBinding(callback)
			return 1
		}
	}
	
	; After we enter Bind Mode and a binding is chosen, this gets called to decide whether or not to accept the binding
	RequestBinding(name, hk){
		; Is this instance already bound?
		;if (ObjHasKey(this._HotkeyBindings, name)){
		;	this.UpdateBinding(name, "")
		;}
		StringReplace, hktmp, hk, ~
		if (ObjHasKey(this._BoundKeys, hktmp) && this._BoundKeys[hktmp] != name){
			; Duplicate hotkey
			SplashTextOn, 300, 50, Bind  Mode, % "This key combination is already bound to the following hotkey: " this._BoundKeys[hktmp]
			Sleep 2000
			SplashTextOff
			; Re-enable the hotkeys
			this.EnableHotkeys()
			; Pass false - binding not allowed
			return 0
		}
		
		if (hk = ""){
			this.DisableHotkey(name)
		}
		OutputDebug % name " Hotkey Changed to " hk
		return 1
	}
	
	; A hotkey finished detecting a user binding
	BindModeEnded(name, hk){
		this.EditBinding(name, hk)
		this.EnableHotkeys()
		this._BindMode := 0
		if (this._callback !=0){
			this._callback.call(name, hk)
		}
	}
	
	; Updates the record for a given binding
	EditBinding(name, hk){
		if (hk = ""){
			; Update arrays
			this._BoundKeys.Delete(this._HotkeyBindings[name])
			this._HotkeyBindings.Delete(name)
		} else {
			; Update arrays to register what we bound
			StringReplace, hktmp, hk, ~
			this._HotkeyBindings[name] := hk
			this._BoundKeys[hktmp] := name
		}
	}
	
	; Binds a given hotkey GuiControl to a bindstring
	EnableHotkey(name, hk){
		; If the guicontrol is already bound, remove the existing binding
		if (ObjHasKey(this._HotkeyBindings, name) && this._HotkeyBindings[name] != hk){
			this.DisableHotkey(name)
		}
		; Make the new binding
		if (hk != ""){
			try {
				fn := this._HotkeyEvent.Bind(this, name, 1)
				hotkey, % "$" hk, % fn, On
				fn := this._HotkeyEvent.Bind(this, name, 0)
				hotkey, % "$" hk " up", % fn, On
				this.EditBinding(name, hk)
			} catch {
				OutputDebug % "Enable Hotkey for " name " failed! " - hk
			}
		}
	}
	
	; Disables (but does not delete) a binding for a guicontrol
	DisableHotkey(name){
		hk := this._HotkeyBindings[name]
		try {
			Hotkey, % "$" hk, Off
			Hotkey, % "$" hk " up", Off
		} catch {
			OutputDebug % "Disable hotkey for " name " failed - " hk
		}
	}
	
	; Enable all hotkeys
	EnableHotkeys(){
		this._HeldHotkeys := {}
		for name, hk in this._HotkeyBindings {
			this.EnableHotkey(name, hk)
		}
	}

	; Disable all hotkeys
	DisableHotkeys(){
		this._HeldHotkeys := {}
		for name, hk in this._HotkeyBindings {
			this.DisableHotkey(name)
		}
	}
	
	; Called whenever a hotkey goes down or up.
	_HotkeyEvent(name, event){
		if (event){
			if (this._HotkeyObjects[name]._norepeat && ObjHasKey(this._HeldHotkeys, name))
				return
			else 
				this._HeldHotkeys[name] := 1
		} else {
			this._HeldHotkeys.Delete(name)
		}
		OutputDebug % "Hotkey " name " - " event
		this._HotkeyCallbacks[name].(event)
	}
	
	; CHotkeyControl handles the GUI for an individual Hotkey GuiControl.
	; It facilitates selection of hotkey options (wild, passthrough, repeat supression etc) and displaying of the selected hotkey in a human-readable format.
	Class CHotkeyControl {
		; Internal vars describing the bindstring
		_value := ""		; The bindstring of the hotkey (eg ~*^!a). The getter for .value returns this
		_hotkey := ""		; The bindstring without any modes (eg ^!a)
		_wild := 0			; Whether Wild (*) mode is on
		_passthrough := 1	; Whether Passthrough (~) mode is on
		_norepeat := 0		; Whether or not to supress repeat down events
		; Other internal vars
		_DefaultBanner := "Drop down list to select a binding"
		_modifiers := {"^": "Ctrl", "+": "Shift", "!": "Alt", "#": "Win"}
		_modes := {"~": 1, "*": 1}
		; Constructor.
		; Params:
		; handler: The Hotkey Handler class. Will call various methods of this class to eg request a binding, set a hotkey
		; name: The (unique) name assigned to this hotkey
		; options: The AHK GuiControl options to apply to the ComboBox (eg "w300")
		__New(handler, name, options){
			this._name := name
			this._handler := handler
			
			Gui, Add, ComboBox, % "hwndhwnd " options
			this.hwnd := hwnd
			this._hEdit := DllCall("GetWindow","PTR",this.hwnd,"Uint",5) ;GW_CHILD = 5
			
			fn := this.OptionSelected.Bind(this)
			GuiControl +g, % this.hwnd, % fn
			
			this.BuildOptions()
			this.SetCueBanner()
		}
		
		; Setters and getters re-route .value to ._value
		; Set of value triggers update of GUI, but does not request setting of hotkey
		value[]{
			get {
				return this._value
			}
			
			set {
				this.SetValue(value)
			}
		}
		
		; Set the entire state of the hotkey - Modifier, Keys *and* Modes.
		; This code is currently only to support programatically setting a hotkey by .value (eg when loading binding state from an INI file)
		SetValue(value){
			max := StrLen(value)
			str := ""
			this._wild := this._passthrough := 0
			loop % max {
				i := A_Index
				c := SubStr(value, A_Index, 1)
				if (ObjHasKey(this._modes, c)){
					if (c = "*")
						this._wild := 1
					if (c = "~")
						this._passthrough := 1
					max--
					str .= c
				} else {
					break
				}
			}
			hk := SubStr(value, i, max)
			value := str this._hotkey
			if (this._handler.RequestBinding(this._name, value))
				this._UpdateValue(hk, value)
			; else ??
		}
		
		; The Binding (That is, only the Modifiers and EndKeys) Changed
		; Modes (eg ~, *) are not set by this routine
		; This is so that if the user enables passthrough, and then changes binding, passthrough is not reset
		; Requests permission from the Handler to accept this bindstring (It may reply no if another Hotkey control is already bound to that bindstring)
		ChangeHotkey(hk){
			value := this.BuildValue(hk)
			; Request Binding from hotkey handler
			if (!this._handler.RequestBinding(this._name, value)){
				; Binding rejected - end bind mode, pass original value
				this._handler.BindModeEnded(this._name, this._value)
				return
			}
			this._UpdateValue(hk, value)
			
			; End Bind Mode and pass new value
			this._handler.BindModeEnded(this._name, value)
		}
		
		; Updates the state of the hotkey
		_UpdateValue(hk, value){
			this._hotkey := hk
			this._value := value
			this.HumanReadable := this.BuildHumanReadable()
			this.SetCueBanner()
			this.BuildOptions()
		}

		; An option was selected from the list
		OptionSelected(){
			; Find index of dropdown list. Will be really big number if key was typed
			SendMessage 0x147, 0, 0,, % "ahk_id " this.hwnd  ; CB_GETCURSEL
			o := ErrorLevel
			GuiControl, Choose, % this.hwnd, 0
			if (o < 100){
				o++
				; Option selected from list
				if (o = 1){
					this._handler.RequestBindMode(this._name, this.ChangeHotkey.Bind(this))
					return
				} else if (o = 2){
					this._wild := !this._wild
				} else if (o = 3){
					this._passthrough := !this._passthrough
				} else if (o = 4){
					this._norepeat := !this._norepeat
				} else if (o = 5){
					this._hotkey := ""
				} else {
					; not one of the options from the list, user must have typed in box
					return
				}
				this.ChangeHotkey(this._hotkey)
			}
		}

		; Builds the list of options in the DropDownList
		BuildOptions(){
			str := "|Select Binding|Wild: " (this._wild ? "On" : "Off") "|Passthrough: " (this._passthrough ? "On" : "Off") "|Repeat Supression: " (this._norepeat ? "On" : "Off") "|Clear Binding"
			GuiControl, , % this.hwnd, % str
		}
		
		; Builds an AHK hotkey string (eg "~*^C") from .hotkey and ._wild/._passthrough etc
		BuildValue(hk){
			str := ""
			if (hk != ""){
				if (this._wild)
					str .= "*"
				if (this._passthrough)
					str .= "~"
				str .= hk
			}
			return str
		}
		
		; Build Human-Readable string for a hotkey
		BuildHumanReadable(){
			if (this._hotkey = "")
				return ""
			str := ""
			prefix := ""
			if (this._wild)
				prefix .= "W"
			if (this._passthrough)
				prefix .= "P"
			
			if (prefix)
				str .= "(" prefix ") "
			
			max := StrLen(this._hotkey)
			loop % max {
				i := A_Index
				c := SubStr(this._hotkey, i, 1)
				if (ObjHasKey(this._modifiers, c)){
					str .= this._modifiers[c] " + "
					max--
				} else {
					break
				}
			}
			str .= SubStr(this._hotkey, i, max)
			return str
		}
		
		; Sets the "Cue Banner" for the ComboBox
		SetCueBanner(){
			static EM_SETCUEBANNER:=0x1501
			if (this._hotkey = "")
				Text := this._DefaultBanner
			else
				Text := this.BuildHumanReadable()
			DllCall("User32.dll\SendMessageW", "Ptr", this._hEdit, "Uint", EM_SETCUEBANNER, "Ptr", True, "WStr", text)
			return this
		}
		
	}
	
	; Handles Bind Mode
	Class CInputDetector {
		DebugMode := 1 ; 0 = Block all, 1 = Dont block LMB/RMB, 2 = Don't block any
		_StartBindMode := 0
		_Modifiers := ({91: {s: "#", v: "<"},92: {s: "#", v: ">"}
		,160: {s: "+", v: "<"},161: {s: "+", v: ">"}
		,162: {s: "^", v: "<"},163: {s: "^", v: ">"}
		,164: {s: "!", v: "<"},165: {s: "!", v: ">"}})

		__New(handler){
			this._handler := handler
		}
		
		; Public method that gets called when a user wishes to select a hotkey.
		; Callback will be called whent the user finishes selecting the hotkey.
		SelectBinding(callback){
			this._callback := callback
			this.SetHotkeyState(1)
		}
		
		; Turns on or off the binding detection hotkeys.
		; When turning off, pass the bindstring that the user selected as the 2nd param
		SetHotkeyState(state, binding := 0){
			static pfx := "$*"
			static current_state := 0
			static updown := [{e: 1, s: ""}, {e: 0, s: " up"}]
			onoff := state ? "On" : "Off"
			if (state = current_state)
				return
			if (state){
				SplashTextOn, 300, 30, Bind  Mode, Press a key combination to bind
				; Set flag to tell ProcessInput we want to initialize Bind Mode
				this._StartBindMode := 1
			}
			; Cycle through all keys
			Loop 256 {
				; Get the key name
				i := A_Index
				code := Format("{:x}", A_Index)
				n := GetKeyName("vk" code)
				if (n = "")
					continue
				; Down event, then Up event
				Loop 2 {
					blk := this.DebugMode = 2 || (this.DebugMode = 1 && i <= 2) ? "~" : ""

					fn := this.ProcessInput.Bind(this, {keyname: n, event: updown[A_Index].e, vk: i})
					if (state)
						hotkey, % pfx blk n updown[A_Index].s, % fn
					hotkey, % pfx blk n updown[A_Index].s, % fn, % onoff
				}
			}
			if (!state){
				SplashTextOff
				; Fire callback
				this._callback.(binding)
			}
			current_state := state
		}
		
		; Whenever a key changes state, this is called.
		; Set this._StartBindMode to 1 before binding hotkeys, to tell it to reset vars
		ProcessInput(i){
			static HeldModifiers := {}, EndKey := 0, ModifierCount := 0
			
			; Look for flag that gets set after hotkeys are turned on
			if (this._StartBindMode){
				; Initialize Bind Mode
				HeldModifiers := {}
				ModifierCount := 0
				EndKey := 0
				; reset flag
				this._StartBindMode := 0
			}
			
			is_modifier := ObjHasKey(this._Modifiers, i.vk)

			; filter repeats
			if (i.event && (is_modifier ? ObjHasKey(HeldModifiers, i.vk) : EndKey) )
				return
			
			; Are the conditions met for end of Bind Mode? (Up event of non-modifier key)
			if (is_modifier ? (!i.event && ModifierCount = 1) : !i.event) {
				; End Bind Mode
				this.SetHotkeyState(0, this.RenderHotkey({HeldModifiers: HeldModifiers, EndKey: EndKey}))
				return
			} else {
				; Process Key Up or Down event
				if (is_modifier){
					; modifier went up or down
					if (i.event){
						HeldModifiers[i.vk] := i
						ModifierCount++
					} else {
						HeldModifiers.Delete(i.vk)
						ModifierCount--
					}
				} else {
					; key went down
					EndKey := i
				}
			}
			
			; Mouse Wheel has no Up event, so simulate it to trigger it as an EndKey
			if (i.event && (i.vk = 158 || i.vk = 159)){
				i.event := 0
				this.ProcessInput(i)
			}
		}
		
		; Converts the output from ProcessInput into a standard ahk hotkey string (eg ^a)
		RenderHotkey(hk){
			if (!hk.endkey){
				for vk, obj in hk.HeldModifiers {
					return obj.Keyname
				}
			}
			str := ""
			for vk, obj in hk.HeldModifiers {
				str .= this._Modifiers[vk].s
			}
			str .= hk.Endkey.keyname
			return str
		}
	}

}