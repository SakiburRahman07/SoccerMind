# How to Fix "Could not parse global class Player3D" Error

## The Problem
Godot's parser cache sometimes doesn't refresh when script files are fixed, causing persistent "Could not parse global class" errors even after syntax errors are resolved.

## Solution: Clear Godot's Cache

### Method 1: Delete .godot folder (Recommended)
1. **Close Godot completely**
2. Navigate to your project folder: `D:\4-1 Academic\Sessional\CSE 4110 AI\soccer-mind`
3. Delete the `.godot` folder (it's hidden, so enable "Show hidden files" in Windows)
4. **Reopen Godot** and let it reimport the project
5. Wait for the import to complete (check bottom-right progress bar)

### Method 2: Reimport Project
1. Close Godot
2. Navigate to project folder
3. Rename `project.godot` to `project_backup.godot`
4. Open Godot
5. Click "Import" and select your project folder
6. Godot will create a new `project.godot` file

### Method 3: Force Reload Scripts
1. In Godot, go to **Project > Reload Current Project** (or press F5)
2. Or use **File > Reload Scripts**

## What Was Fixed
- Removed duplicate `to_ball` variable declaration by scoping it properly
- Changed `@onready var animation_player` to regular variable initialized in `setup()`
- All variable scopes are now correct

## After Clearing Cache
The `Player3D` class should now be recognized correctly in all files that use `is Player3D` or `var p: Player3D`.

