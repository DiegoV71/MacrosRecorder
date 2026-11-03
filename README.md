# MacrosRecorder

**Record and replay application-specific mouse and keyboard macros on Windows, including WARDOGS loadout purchases.**

[Русская версия](README.ru.md) · [Keysharp](https://github.com/keysharp-org/Keysharp)

MacrosRecorder is a Keysharp script for repeating sequences of clicks, scrolls and keystrokes. It stores separate F-key slots for each application window and shows a compact in-game style overlay.

## Use cases

- **WARDOGS loadouts:** record the clicks used to select equipment at the vendor, then replay them when the same shop layout is open.
- Repeat actions in desktop applications, such as navigating a fixed menu or completing a routine form.
- Record mouse wheel movements, modifier combinations, holds and dragging.

## Get started

1. Install [Keysharp](https://keysharp-org.github.io/KeysharpDocs/howto/Install.htm) on Windows.
2. Download `src/purchase-macros.ks` and run it with Keysharp.
3. Open the target application. Press **Ctrl + F1** to start recording; perform the actions; press **Ctrl + F1** again to save.
4. Return to the same screen and press **Shift + F1** to replay. Use F1–F12 for separate slots.

| Shortcut | Action |
|---|---|
| Ctrl + F1–F12 | Start or finish recording a slot |
| Shift + F1–F12 | Play a slot |
| Ctrl + Esc | Cancel recording |
| Shift + Esc | Stop playback |
| Left Ctrl + right Ctrl | Show available slots while held |

Release all recorded keys and buttons before finishing a recording. The overlay and injected inputs may not work in every game or exclusive fullscreen mode; test with a short sequence first. Follow the rules of the application or game where you use automation.

## WARDOGS purchase example

Open the vendor with the same window size and UI layout you intend to use later. Record a slot while selecting your preferred equipment. Finish recording, then return to the same vendor screen before playback. Start with a small test purchase and adjust the timing if the shop misses actions. This project is an independent community tool and is not affiliated with WARDOGS or its developers.

## Settings and storage

Macros are saved locally under `macros/<application>_<identity>/F1.txt` and are not included in this repository. Edit a macro's `name`, `delay_min`, `delay_max`, `move_ms`, `singlePointDelay`, and `samePointRadius` fields to tune it. Delays are in milliseconds and the radius is in pixels. The script preserves settings on re-recording and saves the previous version as `.bak`.

New recordings remember the window size; playback stops if it changes. Older macros without size metadata cannot be checked. If an application path changes, playing a missing slot can offer to copy a similar macro after confirmation. Matching by executable name or window class is approximate: inspect the paths before accepting.

Coordinate playback depends on the application, screen layout, scaling and input support. Hold and drag playback and scroll behaviour should be verified in the intended application. Recorded macros can contain application paths and input sequences; review them before sharing.

## Requirements

Windows and Keysharp. The repository provides source, not a standalone executable. For setup and current runtime requirements, consult the Keysharp installation guide above.

