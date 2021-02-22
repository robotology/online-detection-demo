# On-line Detection Application
In this repository, we collect the source code of the **On-line Detection Application**, a pipeline for efficiently training an object detection system on a humanoid robot. This allows to iteratively adapt an object detection model to novel scenarios, by exploiting: (i) a teacher-learner pipeline, (ii) weakly supervised learning techniques to reduce the human labeling effort and (iii) an on-line learning approach for fast model re-training. The application is the result of the implementation of three works, rispectively reported in the following publications:
- [_Interactive data collection for deep learning object detectors on humanoid robots_](https://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=8246973)
- [_On-line object detection: a robotics challenge_](https://link.springer.com/article/10.1007/s10514-019-09894-9)
- [_A Weakly Supervised Strategy for Learning Object Detection on a Humanoid Robot_](https://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=9035067)


The diagram of the final application is as follows:

![image](https://user-images.githubusercontent.com/3706242/108543828-e4678980-72e5-11eb-9c5d-10968c46e997.png)

The proposed pipeline allows therefore to train a detection model in few seconds, within two different modalities:
- **Teacher-learner modality**: the user shows the object of interest to the robot under different viewposes, handling it in hand (Fig.2 a).
- **Exploration modality**: the robot autonomously explores the sorrounding scenario (e.g. a table-top) acquiring images with self supervision or by asking questions to the human in case of doubts (Fig.2 b). 

While these modalities can be freely interchanged, a possible use could be to initially train the detection model with the **Teacher-learner modality**. The goal of this initial interaction is that of “bootstrapping” the system, with an initial object detection model. After that, the robot relies on this initial knowledge to adapt to new settings, by actively exploring the environment and asking for limited human intervention, with the **Exploration modality**. During this phase, it iteratively builds new training sets by using both (i) high confidence predictions of the current models with a _self-supervision_ strategy and (ii) asking to a human expert to refine/correct low confidence predicitions. In this latter case, the user rovides refined annotations using a graphical interface on a tablet.

The application is composed by several modules, each one accounting for the different components of the pipeline. We tested it on the R1 humanoid robot. 

![Slide1](https://user-images.githubusercontent.com/3706242/108711056-1ad71b80-7515-11eb-838d-905009ee57a6.jpg)


## Usage
In order to use this application, you first need to **clone** it in your system and execute the **installation instructions** and the system **setup actions** that you can find at this [link](https://github.com/Arya07/online-detection-demo/blob/main/INSTALL.md).

After setting up your system, you can choose among several versions of this application, according to your needs. Here, we will cover the complete version, comprising all types of interaction with the robot, but others are available as xml applications in the folder `app/scripts`. To execute the complete version you should:
- **Run all the modules** of the _Weakly Supervised Online Detection_ application, represented by the `app/scripts/WS_onlineDetection.xml` file, **except** the `detection_demo.lua` module.
- **Run** the **matlab detection** module (i.e., you should run the maltab script `Detection_main.m `, from the folder `modules/modules_matlab`)
- **Connect alla available ports** from the _Weakly Supervised Online Detection_ application
- **Run** the `detection_demo.lua` and **connect** all again

Once everything is running, you can interact with the application by one of the following options:
- Giving commands using the terminal (you can find the list of possible commands at this [link](https://github.com/Arya07/online-detection-demo/blob/main/MODULES_GUIDE.md#detection_demolua)) 
- Giving commands using the speech interface
