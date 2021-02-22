## detection_demo.lua

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

## Matlab detection modules
The inputs of the module are listed below:

* It receives a streaming of images in input from the `BufferedPortImageRgb` named `/detection/img:i`.<br>
* When in training phase, it receives a streaming of bounding boxes from the `BufferedPortBottle` named `/detection/annotations:i`.<br> , that will be taken as ground truth.
* It receives commands from the `BufferedPortBottle` named `/detection/command:i`.<br> , which you can connect to, by typing `yarp write ... /detection/command:i`. The available commands are the following:
    * `quit` to quit the application
    * `train *label*` to train an object, providing the label. An acquisition phase will start where the user is requested to show the object to the robot. It will last for about 30 seconds (this time can be tuned by increasing/decreasing the number of images requested for training). After acquisition a training phase of few seconds will start.
    * `forget *label*` to forget an object providing the label.
    * `load dataset *dataset_name*` to load a dataset, providing its name. A training phase will start. If a dataset already exists, it will be substituted by the selcted one.
    * `save dataset *dataset_name*` to save the current dataset. If the specified name already exists, it will be saved adding a "new_" flag
    * `load model *model_name*` to load a model, providing its name. If a model already exists, it will be substituted by the selcted one.
    * `save model *model_name*` to save the current model. If the specified name already exists, it will be saved adding a "new_" flag

The outputs of the module are listed below:

* From port `/detection/dets:o`: List of detections of the form: (x_min, y_min, x_max, y_max, score, string_label). Note that, during training time, instead, it outputs the bounding box used as ground truth (The conclusion of training phase is declared by sending "Done.").

* From port `/detection/img:o`: streaming of images corresponding to the list of detections.(They can be visualized connecting this port with the input port of a [YarpView](http://www.yarp.it/yarpview.html))

