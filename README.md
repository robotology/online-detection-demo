# detection-demo
==========================

This repo contains a **lua** code that acts as a manager for @Arya07's **detection-demo**. 

# Progress on detection demo
Project updates can be found [here](https://github.com/vtikha/detection-demo/projects/1?)

# Dependencies
 - lua
 - posix.signal
   - luarocks
   - luaposix
 
# Description

The user needs to choose which robot will be used at run time (eg: icub or r1)
```
eg: detection_demo.lua icub
```
The lua manager connects automatically to all required ports, otherwise, it complains of missing dependencies.

This manager script has various behaviours and accepts the following commands via its port `/detection/cmd:i` or via its `speech interface`.

- **look-around** or spoken **look around**:

This command enables an autonomous looking around behavior depending on the number of object detections. It gets the lists of detections and randomly choses where to look. 

- **where-is #objectName** or spoken **Where is the #objectName**:

This enables the robots to localise on one object chosen by the user. The robot will then use the spatial information to verbally locate the object with respect to others in the scene. Eg: The #targetObject is next to #objectName and the #objectName 

- **closest-to #objectName** or spoken **What is close to the #ObjectName**:

This enables the robots to localise on one object chosen by the user and locate the closest object to it. The robot will then use the spatial information to locate the closest object in the scene. Eg: The #targetObject is next to #objectName and the #objectName 

- **look #objectName** or spoken **look at the #objectName**:

- **home** or spoken **go home**:

Moves the head to its home location (looking down) stopping any previous behavior.

- **quit** or spoken **return to home position**:

Quits the module.
