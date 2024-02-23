# GoldGdt
![icon](https://github.com/ratmarrow/GoldGdt/assets/155324574/5cbeb915-b896-4f1b-9a17-155b4f83ecc8)

Character controller add-on for Godot 4 that simulates the movement found in the GoldSrc engine.

## Attribution

### Trace class, `_cast_trace()` function, and `_move_step()` function
- [Q_Move](https://github.com/Btan2/Q_Move) by [Btan2](https://github.com/Btan2)
- [Godot-Math-Lib](https://github.com/sinewavey/Godot-Math-Lib) by [sinewave](https://github.com/sinewavey)

## Changelog

### Update 3
- Made a more thorough pass on step detection logic, and now most issues _should_ be fixed.
- Added in the new `GoldGdt_Pawn` component, which currently only provides the ability to change desired view rotation with a function. 
  - Also works in editor when you edit the pitch and yaw variables, thanks `@tool`!
- Added in a condition to `_move_body()` inside of the `GoldGdt_Body` component that toggles "Stop on Slope" based on movement.
  - This fixes two issues in one fell swoop. Issue 1 was Jolt Physics caused player to jitter while standing still if "Stop on Slope" was false, but it has to be false for wall-strafing to work, so now both should be working as intended.
  - If there is a better fix that involves changing Jolt Physics settings, please let me know!

## Roadmap

- Creating a system for ladder and water movement.
- Viewmodel system (ancillary change).
- 1P/3P model swapping system (ancillary change).

## Installation

### From GitHub:
1. Open your Godot project.
2. Copy the "addons" folder from this repository into the project folder for your Godot project.
3. Enable "GoldGdt" in your project's addon page.
4. Reload your project.
5. Drop the "Pawn" scene into whatever other scenes you need it in.

## Setup

### Foreword

I ***heavily*** recommend using [Godot Jolt](https://github.com/godot-jolt/godot-jolt) for the physics engine, but this add-on should still work with GodotPhysics if you so choose.

### Input Map

GoldGdt has pre-defined inputs that it is programmed around. Unless you want to go into the code and change them to your own input mappings, I recommend recreating these inputs in your Project Settings, binding them to whatever you see fit.

![image](https://github.com/ratmarrow/GoldGdt/assets/155324574/2bdd25bc-d9bf-41f4-acd9-6e9c4e38e9ae)

### Player Parameters

All bundled components require a reference to a Player Parameters resource, which contains things like player speed, acceleration, etc...

You can create a new Player Parameters resource by right clicking in your FileSystem, opening up the Create New Resource window, and creating a new Player Parameters resource.

Everything is self explanatory, but anything categorized as "Engine Dependant" *must* be in meters. If you want to convert speed from GoldSrc to Godot, remember that GoldSrc measures units in inches.

![image](https://github.com/ratmarrow/GoldGdt/assets/155324574/c7179e54-c690-4592-bc70-dfb8d169c0bc)
