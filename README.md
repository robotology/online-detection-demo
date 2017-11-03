# detection-demo
==========================

This file contains a **lua** code that acts as a manager for the detection-demo. 

# Progress on detection demo
Project updates can be found [here](https://github.com/vtikha/detection-demo/projects/1?)

# Dependencies
 - lua
 - posix.signal
   - luarocks
   - luaposix
 

# Description

The user needs to choose at run time which robot will be used (eg: icub or r1)
```
eg: detection_demo.lua icub
```
It then connects automatically to all ports required and otherwise complains of a missing dependency.

The lua scripts has various behaviours and accepts the following commands via its port `/detection/cmd:i`:

**look-around**:
This enables an autonomous looking around behavior depending on the number of object detections. It gets the lists of detections and randomly choses where to look. 

**look #objectName**:
This enables the robots to focalise on one object chosen by the user. The user must provide the name of the target and the robot will move the head accordingly.

**home**:
Moves the head to its home location (looking down) stopping any previous behavior.

**quit**:
Quits the module.



