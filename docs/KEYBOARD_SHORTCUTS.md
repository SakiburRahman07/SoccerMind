# ⌨️ Keyboard Shortcuts Reference

## SoccerMind - Complete Keyboard Shortcuts Guide

This document lists all keyboard shortcuts available in the SoccerMind game.

---

## 🎮 Game Controls

| Key | Action | Description |
|-----|--------|-------------|
| **Space** | Pause/Resume | Toggle game pause state. Button text changes between "Pause" and "Resume". |
| **R** | Manual Restart | Manually restart the match from center. Useful for testing and debugging. |
| **N** | Toggle Day/Night | Switch between day and night lighting modes for the field environment. |
| **T** | Test Score Update | Testing/debugging function that randomly updates the score display. |

---

## 📹 Camera Controls

| Key | Action | Description |
|-----|--------|-------------|
| **C** | Switch Camera Mode | Cycle through different camera perspectives (Overview, Follow Ball, Sideline, Goal View, Player View). |
| **+** or **=** | Zoom In | Zoom the camera in closer to the action. |
| **-** | Zoom Out | Zoom the camera out for a wider view. |
| **Home** | Reset Camera | Reset camera to default position and zoom level. |

---

## 🖥️ UI Panel Controls

| Key | Action | Description |
|-----|--------|-------------|
| **H** | Toggle help panel | Show/hide the help panel with all keyboard shortcuts and controls. |
| **S** | Toggle Statistics Panel | Show/hide the match statistics panel (right side of screen). |
| **M** | Toggle Minimap | Show/hide the minimap (bottom right corner). |

---

## 📋 AI Selection Screen (Pre-Game)

When the AI Selection Screen is active (before match starts):

- **Tab**: Navigate through dropdown menus (standard tab navigation)
- **Enter**: Confirm and start match (if "Start Match" button is focused)
- **Arrow Keys**: Navigate dropdown options
- **Escape**: Close/cancel (if implemented)

---

## 🎯 Quick Reference Card

```
╔═══════════════════════════════════════════════════╗
║          SOCCERMIND KEYBOARD SHORTCUTS            ║
╠═══════════════════════════════════════════════════╣
║ GAME CONTROLS                                      ║
║   [Space]  - Pause/Resume                         ║
║   [R]      - Manual Restart                       ║
║   [N]      - Toggle Day/Night                     ║
║   [T]      - Test Score (Debug)                   ║
╠═══════════════════════════════════════════════════╣
║ CAMERA CONTROLS                                    ║
║   [C]      - Switch Camera Mode                   ║
║   [+] / =  - Zoom In                              ║
║   [-]      - Zoom Out                             ║
║   [Home]   - Reset Camera                         ║
╠═══════════════════════════════════════════════════╣
║ UI PANELS                                          ║
║   [H]      - Toggle help panel                    ║
║   [S]      - Toggle Stats Panel                   ║
║   [M]      - Toggle Minimap                       ║
╚═══════════════════════════════════════════════════╝
```

---

## 📝 Notes

### Shortcut Behavior

- **Space**: Works even when game is paused (UI has PROCESS_MODE_ALWAYS)
- **H**: Opens/closes help panel which displays this same information in-game
- **Camera Shortcuts**: Work during gameplay to change viewing perspective
- **UI Panel Shortcuts**: Toggle visibility - panels remember their state

### Availability

- Most shortcuts work **during gameplay**
- **H**, **S**, **M**, and **Space** also work **when game is paused**
- Camera controls available **only during active gameplay**
- AI Selection Screen shortcuts available **only during pre-game setup**

---

## 🔧 Implementation Details

### Files with Keyboard Input Handling

1. **GameManager3D.gd** (`scripts3d/GameManager3D.gd`)
   - Handles: **N**, **R**

2. **UIController3D.gd** (`scripts3d/UIController3D.gd`)
   - Handles: **Space**, **H**, **S**, **M**, **T**

3. **CameraController3D.gd** (`scripts3d/CameraController3D.gd`)
   - Handles: **C**, **+**, **-**, **Home**

### Input Event Processing

- All shortcuts use `InputEventKey` with `event.pressed and not event.echo` to prevent key repeat
- UI shortcuts process input even when game is paused (`PROCESS_MODE_ALWAYS`)
- Game shortcuts are processed via `_unhandled_input()` or `_input()`

---

## 🎮 Gameplay Tips

1. **Quick Camera Switch**: Press **C** multiple times to cycle through all camera angles
2. **Pause Anytime**: Use **Space** to pause during intense moments for better analysis
3. **Monitor Stats**: Press **S** to see real-time match statistics
4. **Minimap Navigation**: Press **M** to toggle minimap visibility
5. **Help Reference**: Press **H** anytime to see this shortcut list in-game

---

**Last Updated**: Implementation as of AI Selection Feature addition
**Version**: SoccerMind 4.5 with Runtime AI Selection

