# GoldGdt
![icon](https://github.com/ratmarrow/GoldGdt/assets/155324574/5cbeb915-b896-4f1b-9a17-155b4f83ecc8)

Character controller add-on for Godot 4 that simulates the movement found in the GoldSrc engine.

## Changelog

### Update 1 (effectively Legacy Update 7.0)
- Completely restructured to use components as opposed to beeg script.
  - This was done to make building on top of the character controller much simpler.
- Improvements to mouse input.
  - Now screen size independant.
  - Hopefully more precise.
- Improvements to interpolation.
- Small fixes to make Godot Jolt less volatile.

## Roadmap

- Detection and response for stair-like geometry.
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

### Input Map

GoldGdt has pre-defined inputs that it is programmed around. Unless you want to go into the code and change them to your own input mappings, I recommend recreating these inputs in your Project Settings, binding them to whatever you see fit.

![image](https://github.com/ratmarrow/GoldGdt/assets/155324574/2bdd25bc-d9bf-41f4-acd9-6e9c4e38e9ae)

### Player Parameters

All bundled components require a reference to a Player Parameters resource, which contains things like player speed, acceleration, etc...

You can create a new Player Parameters resource by right clicking in your FileSystem, opening up the Create New Resource window, and creating a new Player Parameters resource.

Everything is self explanatory, but anything categorized as "Engine Dependant" *must* be in meters. If you want to convert speed from GoldSrc to Godot, remember that GoldSrc measures units in inches.

![image](https://github.com/ratmarrow/GoldGdt/assets/155324574/c7179e54-c690-4592-bc70-dfb8d169c0bc)
