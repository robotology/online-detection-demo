# On-line Detection Application
In this repository, we collect the source code of the **On-line Detection Application**, a pipeline for efficiently training an object detection system on a humanoid robot. This to iteratively adapt an object detection model to novel scenarios, by exploiting: (i) a teacher-learner pipeline, (ii) weakly supervised learning techniques to reduce the human labeling effort and (iii) an on-line learning approach for fast model re-training. The diagram of the final application is as follows:

![image](https://user-images.githubusercontent.com/3706242/108543828-e4678980-72e5-11eb-9c5d-10968c46e997.png)

The proposed pipeline allows therefore to train a detection model in few seconds, within two different modalities:
- **Teacher-learner modality**: the user shows the object of interest to the robot under different viewposes, handling it in hand (Fig.2 a).
- **Exploration modality**: the robot autonomously explores the sorrounding scenario (e.g. a table-top) acquiring images with self supervision or by asking questions to the human in case of doubts (Fig.2 b). 

While these modalities can be interchange, a possible use could be to initially train the detection model with the **Teacher-learner modality**. The goal of this initial interaction is that of “bootstrapping” the system, with an initial object detection model. After that, the robot relies on this initial knowledge to adapt to new settings, by actively exploring the environment and asking for limited human intervention, with the **Exploration modality**. During this phase, it iteratively builds new training sets by using both (i) high confidence predictions of the current models with a _self-supervision_ strategy and (ii) asking to a human expert to refine/correct low confidence predicitions. In this latter case, the user rovides refined annotations using a graphical interface on a tablet.

The application is composed by several modules, each one accounting for the different components of the pipeline. We tested it on the R1 humanoid robot. 

![Slide1](https://user-images.githubusercontent.com/3706242/108711056-1ad71b80-7515-11eb-838d-905009ee57a6.jpg)


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


## Usage
This module allows to train a detection model online, in just few seconds. It relies on Faster R-CNN for feature extraction and on FALKON + Minibootstrap procedure for classification. Please, refer to the [paper](https://www.semanticscholar.org/paper/Speeding-Up-Object-Detection-Training-for-Robotics-Maiettini-Pasquale/6a8a3b27a78c78bc80984fca29554de3269d34d3) for further details about the algorithm.

You can use your own Faster R-CNN pretrained weights as feature extraction module. We made available a ZF model, trained on 20 bjects of the iCubWorld Transformation dataset. In order to use it you can run the script fetch_model.sh by doing the following:
```
cd $DETECTION_DIR
./Scripts/fetch_model.sh

```

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
