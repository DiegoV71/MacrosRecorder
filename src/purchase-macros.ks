#SingleInstance Force

recordingSlot := 0
recordingWindow := 0
recordingKey := ""
recordingName := ""
recordingWidth := 0
recordingHeight := 0
recordedClicks := []
recordingHeld := Map()
recordLastTick := 0
lastDragX := 0
lastDragY := 0
playing := false
cancelPlayback := false
noticeApp := "APPLICATION"
macroDir := A_ScriptDir "\macros"
DirCreate(macroDir)
CoordMode("Mouse", "Screen")

; Tactical overlay windows never activate and pass mouse input through.
noticeGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")
noticeGui.BackColor := "1A1D1B"
noticeGui.SetFont("s9 bold cD6C389", "Segoe UI")
noticeGui.AddText("x0 y0 w5 h74 +BackgroundC9B67C", "")
noticeHeading := noticeGui.AddText("x19 y10 w390 h18", "APPLICATION   /   MACROS")
noticeGui.SetFont("s11 bold cEDEEE6", "Segoe UI")
noticeText := noticeGui.AddText("x19 y34 w400 h27", "")

; Four columns by three rows; text controls are kept separate for live updates.
guideGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")
guideGui.BackColor := "171A18"
guideGui.SetFont("s9 bold cCBB77F", "Segoe UI")
guideHeading := guideGui.AddText("x26 y20 w790 h20", "APPLICATION   /   MACROS")
guideGui.SetFont("s20 bold cF0F0E8", "Segoe UI")
guideGui.AddText("x25 y42 w520 h39", "QUICK MACROS")
guideGui.SetFont("s9 cA6AD9F", "Segoe UI")
guideGui.AddText("x27 y86 w760 h20", "SELECT A SLOT   /   SHIFT + F1–F12 TO PLAY")
guideGui.AddText("x26 y111 w790 h2 +Background777459", "")
guideLabels := []
guideStatus := []
Loop 12 {
    col := Mod(A_Index - 1, 4)
    row := Floor((A_Index - 1) / 4)
    x := 26 + col * 198
    y := 128 + row * 82
    guideGui.AddText("x" x " y" y " w187 h72 +Background292D28", "")
    guideGui.AddText("x" x " y" y " w3 h72 +BackgroundA89969", "")
    guideGui.SetFont("s14 bold cD6C389", "Segoe UI")
    guideGui.AddText("x" (x + 13) " y" (y + 8) " w59 h26 +BackgroundTrans", "F" A_Index)
    guideGui.SetFont("s8 bold c8F9989", "Segoe UI")
    guideStatus.Push(guideGui.AddText("x" (x + 83) " y" (y + 12) " w91 h18 Right +BackgroundTrans", ""))
    guideGui.SetFont("s10 cF0F0E8", "Segoe UI")
    guideLabels.Push(guideGui.AddText("x" (x + 13) " y" (y + 39) " w161 h25 +BackgroundTrans", ""))
}
guideGui.SetFont("s8 c8F9989", "Segoe UI")
guideGui.AddText("x27 y387 w760 h18", "HOLD BOTH CTRL KEYS TO VIEW   /   CTRL + F1–F12 TO RECORD")
guideVisible := false
guideWindow := 0
SetTimer(UpdateGuide, 100)

Loop 12 {
    Hotkey("^F" A_Index, ToggleRecording)
    Hotkey("+F" A_Index, PlayMacro)
}

; Physical letter positions work regardless of the current keyboard layout.
for sc in ["SC010", "SC011", "SC012", "SC013", "SC014", "SC015", "SC016", "SC017", "SC018", "SC019", "SC01E", "SC01F", "SC020", "SC021", "SC022", "SC023", "SC024", "SC025", "SC026", "SC02C", "SC02D", "SC02E", "SC02F", "SC030", "SC031", "SC032"]
    {
        Hotkey("~*" sc, RecordKey)
        Hotkey("~*" sc " Up", RecordRelease)
    }
for button in ["LButton", "RButton", "MButton", "XButton1", "XButton2"] {
    Hotkey("~*" button, RecordMouse)
    Hotkey("~*" button " Up", RecordRelease)
}
for button in ["WheelUp", "WheelDown", "WheelLeft", "WheelRight"]
    Hotkey("~*" button, RecordMouse)
SetTimer(CaptureDrag, 20)

; Identify an application by executable path and window class, not its changing title.
WindowKey(hwnd) {
    return StrLower(WinGetProcessPath("ahk_id " hwnd)) "|" WinGetClass("ahk_id " hwnd)
}

WindowDisplayName(hwnd) {
    try {
        title := Trim(WinGetTitle("ahk_id " hwnd))
        if (title != "")
            return SubStr(title, 1, 45)
        SplitPath(WinGetProcessPath("ahk_id " hwnd), &exeName)
        return RegExReplace(exeName, "i)\.exe$", "")
    }
    return "APPLICATION"
}

MacroFolder(key) {
    global macroDir
    hash := 5381
    Loop Parse key
        hash := Mod(hash * 33 + Ord(A_LoopField), 2147483647)
    exePath := StrSplit(key, "|")[1]
    SplitPath(exePath, &exeName)
    name := RegExReplace(exeName, "i)\.exe$", "")
    name := RegExReplace(name, "[^a-zA-Z0-9_-]", "_")
    name := SubStr(name, 1, 80)
    if (name = "")
        name := "application"
    return macroDir "\" name "_" hash
}

MacroPath(key, slot) {
    return MacroFolder(key) "\F" slot ".txt"
}

; Offer an explicit copy when the executable or window class matches a previous identity.
OfferRebind(key, slot) {
    global macroDir
    current := StrSplit(key, "|")
    if (current.Length != 2)
        return false
    SplitPath(current[1], &currentExe)
    Loop Files, macroDir "\F" slot ".txt", "R" {
        candidate := A_LoopFileFullPath
        try {
            oldContent := FileRead(candidate, "UTF-8")
            oldLines := StrSplit(oldContent, "`n", "`r")
            oldIdentity := StrSplit(oldLines[1], "|")
            if (oldIdentity.Length != 2 || oldLines[1] = key)
                continue
            SplitPath(oldIdentity[1], &oldExe)
            if (StrLower(oldExe) != StrLower(currentExe) && oldIdentity[2] != current[2])
                continue
            question := "A similar F" slot " macro was found:" "`n`n" candidate "`n`nOriginal: " oldLines[1] "`n`nCurrent: " key "`n`nCopy and bind it to the current window? The original will be kept."
            if (MsgBox(question, "Bind existing macro", "YesNo Icon?") != "Yes")
                continue
            target := MacroPath(key, slot)
            if FileExist(target)
                return false
            DirCreate(MacroFolder(key))
            ; Replace only the identity line; do not modify the original file.
            newline := InStr(oldContent, "`n")
            if !newline
                return false
            FileAppend(key "`n" SubStr(oldContent, newline + 1), target, "UTF-8")
            return true
        } catch {
            continue
        }
    }
    return false
}

MacroNameFromLines(lines, slot) {
    for line in lines {
        if (SubStr(line, 1, 5) = "name=") {
            name := Trim(SubStr(line, 6))
            return name != "" ? name : "F" slot
        }
    }
    return "F" slot
}

MacroName(key, slot) {
    path := MacroPath(key, slot)
    if !FileExist(path)
        return "F" slot
    try {
        lines := StrSplit(FileRead(path, "UTF-8"), "`n", "`r")
        if (lines[1] = key)
            return MacroNameFromLines(lines, slot)
    }
    return "F" slot
}

UpdateGuide() {
    global guideGui, guideHeading, guideLabels, guideStatus, guideVisible, guideWindow
    if !(GetKeyState("LControl", "P") && GetKeyState("RControl", "P")) {
        if guideVisible {
            guideGui.Hide()
            guideVisible := false
            guideWindow := 0
        }
        return
    }
    hwnd := WinExist("A")
    if (!hwnd || (guideVisible && hwnd = guideWindow))
        return
    try key := WindowKey(hwnd)
    catch {
        if guideVisible
            guideGui.Hide()
        guideVisible := false
        guideWindow := 0
        return
    }
    guideHeading.Text := WindowDisplayName(hwnd) "   /   MACROS"
    Loop 12 {
        path := MacroPath(key, A_Index)
        label := "No macro"
        status := "EMPTY"
        if FileExist(path) {
            try {
                lines := StrSplit(FileRead(path, "UTF-8"), "`n", "`r")
                if (lines[1] = key) {
                    label := MacroNameFromLines(lines, A_Index)
                    status := "READY"
                }
            }
        }
        guideLabels[A_Index].Text := label
        guideStatus[A_Index].Text := status
    }
    x := Max(0, Round((A_ScreenWidth - 844) / 2))
    y := Max(0, Round((A_ScreenHeight - 420) / 2))
    guideGui.Show("NoActivate x" x " y" y " w844 h420")
    guideVisible := true
    guideWindow := hwnd
}

ShowNotice(message, duration := 2000, status := "STATUS") {
    global noticeGui, noticeText, noticeHeading, noticeApp
    SetTimer(HideNotice, 0)
    noticeHeading.Text := SubStr(noticeApp, 1, 24) "   /   " status
    noticeText.Text := message
    x := Round((A_ScreenWidth - 438) / 2)
    y := Max(0, A_ScreenHeight - 140)
    noticeGui.Show("NoActivate x" x " y" y " w438 h74")
    if (duration > 0)
        SetTimer(HideNotice, -duration)
}

; Short, distinct cues; no sound is played for individual recorded actions.
AudioCue(kind) {
    if (kind = "record") {
        SoundBeep(650, 60)
        SoundBeep(950, 90)
    } else if (kind = "save") {
        SoundBeep(800, 60)
        SoundBeep(1050, 110)
    } else if (kind = "cancel") {
        SoundBeep(700, 60)
        SoundBeep(400, 110)
    } else if (kind = "play") {
        SoundBeep(850, 65)
    } else if (kind = "complete") {
        SoundBeep(1000, 85)
    } else {
        SoundBeep(300, 90)
        SoundBeep(300, 130)
    }
}

HideNotice() {
    global noticeGui
    noticeGui.Hide()
}

#HotIf recordingSlot
^Esc:: {
    CancelRecording("recording cancelled")
}
#HotIf

+Esc:: {
    global playing, cancelPlayback
    if playing
        cancelPlayback := true
}

CurrentModifiers() {
    mods := ""
    if GetKeyState("Ctrl", "P")
        mods .= "^"
    if GetKeyState("Shift", "P")
        mods .= "+"
    if GetKeyState("Alt", "P")
        mods .= "!"
    if (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
        mods .= "#"
    return mods
}

UpdateRecordingNotice() {
    global recordingSlot, recordingName, recordedClicks, noticeText
    if recordingSlot
        noticeText.Text := "Recording " recordingName " (F" recordingSlot ")  |  " recordedClicks.Length " actions"
}

RecordEvent(kind, key, x := "", y := "") {
    global recordingHeld, recordedClicks, recordLastTick
    now := A_TickCount
    elapsed := recordingHeld.Count ? Max(0, now - recordLastTick) : -1
    recordedClicks.Push("event," kind "," key "," x "," y "," CurrentModifiers() "," elapsed)
    recordLastTick := now
    UpdateRecordingNotice()
}

RecordKey(hotkey) {
    global recordingSlot, recordingWindow, recordingHeld, playing
    if !(recordingSlot && !playing && WinActive("ahk_id " recordingWindow))
        return
    key := SubStr(hotkey, 3)
    if recordingHeld.Has(key)
        return
    RecordEvent("down", key)
    recordingHeld[key] := true
}

RecordMouse(hotkey) {
    global recordingSlot, recordingWindow, recordingHeld, recordedClicks, playing, lastDragX, lastDragY
    if !(recordingSlot && !playing && WinActive("ahk_id " recordingWindow))
        return
    MouseGetPos(&x, &y)
    WinGetPos(&wx, &wy,,, "ahk_id " recordingWindow)
    button := SubStr(hotkey, 3)
    if (SubStr(button, 1, 5) = "Wheel") {
        RecordEvent("wheel", button, x - wx, y - wy)
    } else if !recordingHeld.Has(button) {
        RecordEvent("down", button, x - wx, y - wy)
        recordingHeld[button] := true
        lastDragX := x - wx
        lastDragY := y - wy
    }
}

RecordRelease(hotkey) {
    global recordingSlot, recordingWindow, recordingHeld, lastDragX, lastDragY
    if !recordingSlot
        return
    key := SubStr(hotkey, 3, StrLen(hotkey) - 5)
    if !recordingHeld.Has(key)
        return
    if !WinActive("ahk_id " recordingWindow) {
        CancelRecording("Window lost focus")
        return
    }
    if InStr(key, "Button") {
        MouseGetPos(&x, &y)
        WinGetPos(&wx, &wy,,, "ahk_id " recordingWindow)
        RecordEvent("up", key, x - wx, y - wy)
    } else
        RecordEvent("up", key)
    recordingHeld.Delete(key)
}

CaptureDrag() {
    global recordingSlot, recordingWindow, recordingHeld, lastDragX, lastDragY
    if !recordingSlot || !recordingHeld.Count
        return
    if !WinActive("ahk_id " recordingWindow) {
        CancelRecording("Window lost focus")
        return
    }
    dragging := false
    for key in recordingHeld {
        if InStr(key, "Button") {
            dragging := true
            break
        }
    }
    if !dragging
        return
    MouseGetPos(&x, &y)
    WinGetPos(&wx, &wy,,, "ahk_id " recordingWindow)
    x -= wx
    y -= wy
    if (x != lastDragX || y != lastDragY) {
        RecordEvent("move", "", x, y)
        lastDragX := x
        lastDragY := y
    }
}

CancelRecording(reason) {
    global recordingSlot, recordingName, recordedClicks, recordingHeld
    if !recordingSlot
        return
    slot := recordingSlot
    recordingSlot := 0
    recordedClicks := []
    recordingHeld := Map()
    ShowNotice(recordingName " (F" slot "): " reason, 2000, "RECORDING CANCELLED")
    AudioCue("cancel")
}

ToggleRecording(hotkey) {
    global recordingSlot, recordingWindow, recordingKey, recordingName, recordingWidth, recordingHeight, recordedClicks, recordingHeld, recordLastTick, playing, noticeApp
    if playing
        return
    slot := Integer(SubStr(hotkey, 3))
    if recordingSlot {
        if (recordingSlot != slot) {
            AudioCue("error")
            return
        }
        if recordingHeld.Count {
            ShowNotice("Release held keys and buttons first", 0, "RECORDING")
            AudioCue("error")
            return
        }
        recordingSlot := 0
        if recordedClicks.Length {
            path := MacroPath(recordingKey, slot)
            settings := Map("delay_min", "100", "delay_max", "150", "move_ms", "50", "singlePointDelay", "50", "samePointRadius", "3")
            ; Never overwrite a different window identity in the event of a hash collision.
            if FileExist(path) {
                oldLines := StrSplit(FileRead(path, "UTF-8"), "`n", "`r")
                if (oldLines[1] != recordingKey) {
                    ShowNotice("Error: macro belongs to another window", 2000, "ERROR")
                    AudioCue("error")
                    return
                }
                for line in oldLines {
                    if RegExMatch(line, "^(delay_min|delay_max|move_ms|singlePointDelay|samePointRadius)=(\d+)$", &setting)
                        settings[setting[1]] := setting[2]
                }
            }
            DirCreate(MacroFolder(recordingKey))
            content := recordingKey "`nname=" recordingName "`nwindow_width=" recordingWidth "`nwindow_height=" recordingHeight "`n"
            for settingName, settingValue in settings
                content .= settingName "=" settingValue "`n"
            for action in recordedClicks
                content .= action "`n"
            ; Write first, then back up the previous version and replace it.
            tempPath := path ".new"
            try {
                if FileExist(tempPath)
                    FileDelete(tempPath)
                FileAppend(content, tempPath, "UTF-8")
                if FileExist(path)
                    FileCopy(path, path ".bak", true)
                FileMove(tempPath, path, true)
            } catch {
                ShowNotice("Save failed; previous macro kept", 2000, "ERROR")
                AudioCue("error")
                return
            }
            ShowNotice(recordingName " (F" slot "): saved " recordedClicks.Length " actions", 2000, "RECORDING SAVED")
            AudioCue("save")
        } else {
            ShowNotice(recordingName " (F" slot "): no actions; previous macro kept", 2000, "EMPTY RECORDING")
            AudioCue("cancel")
        }
    } else {
        hwnd := WinExist("A")
        if !hwnd {
            AudioCue("error")
            return
        }
        try key := WindowKey(hwnd)
        catch {
            AudioCue("error")
            return
        }
        noticeApp := WindowDisplayName(hwnd)
        WinGetPos(,, &recordingWidth, &recordingHeight, "ahk_id " hwnd)
        recordedClicks := []
        recordingHeld := Map()
        recordLastTick := A_TickCount
        recordingWindow := hwnd
        recordingKey := key
        recordingName := MacroName(key, slot)
        recordingSlot := slot
        ShowNotice("Recording " recordingName " (F" slot ")  |  0 actions", 0, "RECORDING")
        AudioCue("record")
    }
}

PlayMacro(hotkey) {
    global recordingSlot, playing, cancelPlayback, noticeApp
    if (recordingSlot || playing)
        return
    hwnd := WinExist("A")
    if !hwnd
        return
    try key := WindowKey(hwnd)
    catch {
        AudioCue("error")
        return
    }
    noticeApp := WindowDisplayName(hwnd)
    slot := Integer(SubStr(hotkey, 3))
    path := MacroPath(key, slot)
    if !FileExist(path) {
        if OfferRebind(key, slot) {
            ShowNotice("F" slot " copied. Activate the app and press Shift+F" slot, 5000, "MACRO BOUND")
            AudioCue("save")
            return
        }
        ShowNotice("No F" slot " macro for this window", 2000, "ERROR")
        AudioCue("error")
        return
    }
    lines := StrSplit(FileRead(path, "UTF-8"), "`n", "`r")
    if (lines[1] != key) {
        AudioCue("error")
        return
    }
    macroName := MacroNameFromLines(lines, slot)
    savedWidth := 0
    savedHeight := 0
    for line in lines {
        if RegExMatch(line, "^window_width=(\d+)$", &sizeMatch)
            savedWidth := Integer(sizeMatch[1])
        else if RegExMatch(line, "^window_height=(\d+)$", &sizeMatch)
            savedHeight := Integer(sizeMatch[1])
    }
    if (savedWidth > 0 && savedHeight > 0) {
        WinGetPos(,, &currentWidth, &currentHeight, "ahk_id " hwnd)
        if (currentWidth != savedWidth || currentHeight != savedHeight) {
            ShowNotice("Window " currentWidth "x" currentHeight " / recorded " savedWidth "x" savedHeight, 6000, "WINDOW SIZE MISMATCH")
            AudioCue("error")
            return
        }
    }
    delayMin := 100
    delayMax := 150
    for line in lines {
        if RegExMatch(line, "^(delay|delay_min|delay_max)=(.*)$", &setting) {
            if !RegExMatch(setting[2], "^\d+$") {
                AudioCue("error")
                return
            }
            value := Integer(setting[2])
            if (setting[1] = "delay") {
                delayMin := value
                delayMax := value
            } else if (setting[1] = "delay_min")
                delayMin := value
            else
                delayMax := value
        }
    }
    if (delayMin > delayMax) {
        AudioCue("error")
        return
    }
    moveMs := 50
    for line in lines {
        if (SubStr(line, 1, 8) = "move_ms=") {
            value := SubStr(line, 9)
            if !RegExMatch(value, "^\d+$") {
                AudioCue("error")
                return
            }
            moveMs := Integer(value)
            break
        }
    }
    singlePointDelay := 50
    for line in lines {
        if (SubStr(line, 1, 17) = "singlePointDelay=") {
            value := SubStr(line, 18)
            if !RegExMatch(value, "^\d+$") {
                AudioCue("error")
                return
            }
            singlePointDelay := Integer(value)
        }
    }
    samePointRadius := 3
    for line in lines {
        if (SubStr(line, 1, 16) = "samePointRadius=") {
            value := SubStr(line, 17)
            if !RegExMatch(value, "^\d+$") {
                AudioCue("error")
                return
            }
            samePointRadius := Integer(value)
        }
    }
    cancelPlayback := false
    playing := true
    ShowNotice("Playing " macroName " (F" slot ")...", 0, "PLAYBACK")
    AudioCue("play")
    heldInputs := Map()
    heldMods := Map()
    playbackFailed := false
    try {
        KeyWait("Shift")
        lastAction := 0
        previousMouse := false
        previousX := 0
        previousY := 0
        for index, line in lines {
            if (index = 1 || line = "" || InStr(line, "="))
                continue
            if (cancelPlayback || !WinActive("ahk_id " hwnd))
                break
            parts := StrSplit(line, ",")
            if (parts[1] = "event") {
                if !PlaybackEvent(parts, hwnd, &heldInputs, &heldMods, &lastAction, delayMin, delayMax, moveMs, singlePointDelay, samePointRadius, &previousMouse, &previousX, &previousY) {
                    playbackFailed := true
                    break
                }
                continue
            }
            isMouse := false
            isWheel := false
            if (parts[1] = "key" && parts.Length = 3) {
                key := parts[2]
                mods := parts[3]
                if !RegExMatch(key, "i)^SC[0-9A-F]{3}$")
                    continue
            } else if (parts[1] = "mouse" && parts.Length = 5) {
                button := parts[2]
                x := Integer(parts[3])
                y := Integer(parts[4])
                mods := parts[5]
                if !RegExMatch(button, "^(LButton|RButton|MButton|XButton1|XButton2)$")
                    continue
                isMouse := true
            } else if (parts[1] = "wheel" && parts.Length = 5) {
                button := parts[2]
                x := Integer(parts[3])
                y := Integer(parts[4])
                mods := parts[5]
                if !RegExMatch(button, "^(WheelUp|WheelDown|WheelLeft|WheelRight)$")
                    continue
                isWheel := true
            } else if (parts.Length = 2 || parts.Length = 3) {
                ; Compatibility with the earlier coordinate-only format.
                button := "LButton"
                x := Integer(parts[1])
                y := Integer(parts[2])
                mods := parts.Length = 3 ? parts[3] : ""
                isMouse := true
            } else
                continue
            if !RegExMatch(mods, "^[\^+!#]*$")
                continue
            interval := (isMouse && previousMouse && (x - previousX) ** 2 + (y - previousY) ** 2 <= samePointRadius ** 2)
                ? singlePointDelay : Random(delayMin, delayMax)
            if (isMouse || isWheel) {
                WinGetPos(&wx, &wy,,, "ahk_id " hwnd)
                targetX := wx + x
                targetY := wy + y
                ; Do not spend longer moving than the interval between actions.
                duration := lastAction ? Min(moveMs, interval) : moveMs
                if !MoveSmooth(targetX, targetY, duration, hwnd)
                    break
            }
            if lastAction {
                remaining := interval - (A_TickCount - lastAction)
                while (remaining > 0 && !cancelPlayback && WinActive("ahk_id " hwnd)) {
                    Sleep(Min(remaining, 10))
                    remaining := interval - (A_TickCount - lastAction)
                }
            }
            if (cancelPlayback || !WinActive("ahk_id " hwnd))
                break
            if (isMouse || isWheel)
                Send(mods "{" button "}")
            else
                Send(mods "{" key "}")
            lastAction := A_TickCount
            previousMouse := isMouse
            if isMouse {
                previousX := x
                previousY := y
            }
        }
    } finally {
        ReleaseHeldInputs(heldInputs, heldMods)
        playing := false
        if cancelPlayback {
            ShowNotice(macroName " (F" slot ") stopped", 2000, "PLAYBACK STOPPED")
            AudioCue("cancel")
        } else if (playbackFailed || !WinActive("ahk_id " hwnd)) {
            ShowNotice(macroName " (F" slot "): interrupted", 2000, "PLAYBACK INTERRUPTED")
            AudioCue("error")
        } else {
            ShowNotice(macroName " (F" slot ") complete", 2000, "PLAYBACK COMPLETE")
            AudioCue("complete")
        }
    }
}

; Modifier state is kept throughout holds and always released during cleanup.
SyncModifiers(wanted, heldMods) {
    for symbol, key in Map("^", "Ctrl", "+", "Shift", "!", "Alt", "#", "LWin") {
        active := InStr(wanted, symbol) > 0
        if (active && !heldMods.Has(key)) {
            Send("{Blind}{" key " down}")
            heldMods[key] := true
        } else if (!active && heldMods.Has(key)) {
            Send("{Blind}{" key " up}")
            heldMods.Delete(key)
        }
    }
}

ReleaseHeldInputs(heldInputs, heldMods) {
    for key in heldInputs {
        try Send("{Blind}{" key " up}")
    }
    heldInputs.Clear()
    for key in heldMods {
        try Send("{Blind}{" key " up}")
    }
    heldMods.Clear()
}

PlaybackEvent(parts, hwnd, &heldInputs, &heldMods, &lastAction, delayMin, delayMax, moveMs, singlePointDelay, samePointRadius, &previousMouse, &previousX, &previousY) {
    global cancelPlayback
    if (parts.Length != 7 || !RegExMatch(parts[7], "^-?\d+$"))
        return false
    kind := parts[2], key := parts[3], mods := parts[6], elapsed := Integer(parts[7])
    if !RegExMatch(mods, "^[\^+!#]*$")
        return false
    isMove := kind = "move"
    isWheel := kind = "wheel"
    if (!isMove && !isWheel && kind != "down" && kind != "up")
        return false
    if (isWheel && !RegExMatch(key, "^(WheelUp|WheelDown|WheelLeft|WheelRight)$"))
        return false
    if (!isMove && !isWheel && !RegExMatch(key, "i)^(SC[0-9A-F]{3}|LButton|RButton|MButton|XButton1|XButton2)$"))
        return false
    isMouse := isMove || isWheel || InStr(key, "Button")
    if (isMouse && (!RegExMatch(parts[4], "^-?\d+$") || !RegExMatch(parts[5], "^-?\d+$")))
        return false
    if (kind = "up" && !heldInputs.Has(key))
        return false
    if (kind = "down" && heldInputs.Has(key))
        return false
    if isMouse {
        x := Integer(parts[4]), y := Integer(parts[5])
        WinGetPos(&wx, &wy,,, "ahk_id " hwnd)
        targetX := wx + x, targetY := wy + y
    }
    interval := elapsed >= 0 ? elapsed : Random(delayMin, delayMax)
    if (elapsed < 0 && isMouse && previousMouse && (x - previousX) ** 2 + (y - previousY) ** 2 <= samePointRadius ** 2)
        interval := singlePointDelay
    if (isMouse && !heldInputs.Count && (kind = "down" || isWheel)) {
        if !MoveSmooth(targetX, targetY, lastAction ? Min(moveMs, interval) : moveMs, hwnd)
            return false
    }
    if lastAction {
        remaining := interval - (A_TickCount - lastAction)
        while (remaining > 0 && !cancelPlayback && WinActive("ahk_id " hwnd)) {
            Sleep(Min(remaining, 10))
            remaining := interval - (A_TickCount - lastAction)
        }
    }
    if (cancelPlayback || !WinActive("ahk_id " hwnd))
        return false
    SyncModifiers(mods, heldMods)
    if (isMouse && (heldInputs.Count || isMove || kind = "up"))
        MouseMove(targetX, targetY, 0)
    if (kind = "down") {
        Send("{Blind}{" key " down}")
        heldInputs[key] := true
    } else if isWheel {
        Send("{Blind}{" key "}")
        if !heldInputs.Count
            SyncModifiers("", heldMods)
    } else if (kind = "up") {
        Send("{Blind}{" key " up}")
        heldInputs.Delete(key)
        if !heldInputs.Count
            SyncModifiers("", heldMods)
    }
    lastAction := A_TickCount
    if (kind = "up" && isMouse && !isWheel) {
        previousMouse := true, previousX := x, previousY := y
    } else if (kind != "move" && !isMouse)
        previousMouse := false
    return true
}

; Smooth ease-in/ease-out movement; stop if the target window loses focus.
MoveSmooth(targetX, targetY, duration, hwnd) {
    global cancelPlayback
    MouseGetPos(&startX, &startY)
    if (duration <= 0) {
        MouseMove(targetX, targetY, 0)
        return true
    }
    startTime := A_TickCount
    loop {
        if (cancelPlayback || !WinActive("ahk_id " hwnd))
            return false
        t := Min(1, (A_TickCount - startTime) / duration)
        progress := t * t * (3 - 2 * t)
        MouseMove(Round(startX + (targetX - startX) * progress), Round(startY + (targetY - startY) * progress), 0)
        if (t >= 1)
            break
        Sleep(10)
    }
    return true
}

