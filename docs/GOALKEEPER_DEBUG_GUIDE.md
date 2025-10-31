# Goalkeeper Debug Testing Guide

## Expected Behavior

### Team A Goalkeeper
- **Spawns at**: x ≈ +50 to +55
- **Defends goal at**: x = +58 (RIGHT goal)
- **Should kick toward**: x = -58 (LEFT goal - opponent's goal)
- **When ball enters x > 58**: Team A concedes, Team B scores

### Team B Goalkeeper  
- **Spawns at**: x ≈ -50 to -55
- **Defends goal at**: x = -58 (LEFT goal)
- **Should kick toward**: x = +58 (RIGHT goal - opponent's goal)
- **When ball enters x < -58**: Team B concedes, Team A scores

## What to Watch For

When running the game, watch the console output for these debug messages:

### 1. Goalkeeper Clearance Messages
```
🥅 GOALKEEPER CLEARANCE - Team B
   Own goal at: x=-58
   Ball position: (x, y, z)
   GK position: (x, y, z)
   Opponent goal: x=58
   Kick direction: (x, y, z)
   Kick force: 25.0
```

**Check**: 
- For Team B: `Opponent goal: x=58` should be **positive 58**
- For Team B: `Kick direction` X-component should be **POSITIVE** (toward right)

### 2. Safety Check Messages
```
🛡️ SAFETY CHECK - Team B Goalkeeper: Player_B_goalkeeper_0
   Own goal: x=-58
   Opponent goal: x=58
   Ball position: (x, y, z)
   Kick direction: (x, y, z)
   Kick target would be: x=...
   Distance to own goal: ...
   Distance to opponent goal: ...
```

**Check**:
- For Team B: `Own goal: x=-58` (negative 58)
- For Team B: `Opponent goal: x=58` (positive 58)
- If `Distance to own goal` < `Distance to opponent goal`, you'll see a redirect warning

### 3. Goal Scoring Messages
```
⚽ GOAL! Ball entered left goal at position: ...
⚽ Team A scores! (attacking left goal)
```
or
```
⚽ GOAL! Ball entered right goal at position: ...
⚽ Team B scores! (attacking right goal)
```

## Problem Scenarios

### If Team B scores own goal (ball enters LEFT goal x < -58):
1. Check who kicked the ball last
2. Look for Team B goalkeeper clearance messages before the goal
3. Check if the kick direction X-component was NEGATIVE (wrong - toward own goal)
4. Check if safety check triggered and redirected

### If you see safety redirects frequently:
This means the Goalkeeper3D.gd logic is producing wrong directions, but the safety net is catching them.

### If ball keeps entering x < -58 goal and Team A scores:
- Team B goalkeeper is kicking incorrectly
- Check the `opponent_goal_x` calculation in debug logs

## Testing Steps

1. **Run the game** in Godot
2. **Open the console** (Output panel at bottom)
3. **Watch for 2-3 minutes** of gameplay
4. **Note when goals are scored**
5. **Look for goalkeeper clearance messages** before goals
6. **Check if directions match expectations**

## Expected Console Output for Correct Behavior

When Team B goalkeeper clears:
```
🥅 GOALKEEPER CLEARANCE - Team B
   Own goal at: x=-58
   Opponent goal: x=58
   Kick direction: (POSITIVE_X, 3, Z_VALUE)
```

The X in `Kick direction` MUST be POSITIVE for Team B!

When Team A goalkeeper clears:
```
🥅 GOALKEEPER CLEARANCE - Team A
   Own goal at: x=58
   Opponent goal: x=-58
   Kick direction: (NEGATIVE_X, 3, Z_VALUE)
```

The X in `Kick direction` MUST be NEGATIVE for Team A!

## What to Report Back

After testing, please report:
1. Which team's goalkeeper is having issues?
2. What does the console show for `Opponent goal: x=` value?
3. What is the `Kick direction` X-component (positive or negative)?
4. Are safety redirects happening?
5. Screenshot or copy the console output when an own goal occurs

This will help diagnose if:
- The logic is correct but something else interferes
- The is_team_a flag is somehow wrong
- There's a sign error in the calculations
- The safety check is working but being bypassed
