## Installation

### Dependencies:

* [YARP](https://github.com/robotology/yarp)
* [OpenCV](http://opencv.org/downloads.html) (Tested version: 2.4.11 and 2.4.13)
* [Cuda](http://docs.nvidia.com/cuda/cuda-installation-guide-linux/#axzz4BkDT7m6r) (Tested version: 8, 9, 10)
* [Matlab] (https://it.mathworks.com/)
* [Matlab Parallel Computing Toolbox] (https://it.mathworks.com/products/parallel-computing.html) 
* [Python](https://www.python.org/downloads/) (Tested version: 2.7, 3.5)
* [Faster R-CNN](https://github.com/ShaoqingRen/faster_rcnn)
* [Caffe](http://caffe.berkeleyvision.org/)
* [FALKON](https://github.com/LCSL/FALKON_paper)
* Other required packages: `blas`, `protobuf`, `glog`, `gflags`, `hdf5`, `boost`, `google flags`, `LevelDB`, `lmdb`, `Snappy`


While you can follow official instructions to install the first four dependencies (YARP, Opencv, Cuda and Python), we suggest to follow the provided steps to install Faster R-CNN and the correct version of Caffe.

We also list the commands to install the packages required by Caffe.

#### Required packages installation

**Caffe requirements:**

* OpenBLAS library:
`sudo apt-get install libopenblas-dev`

* Boost C++ library:
`sudo apt-get install libboost-all-dev`

* Google Protobuf Buffers C++:
`sudo apt-get install libprotobuf-dev protobuf-compiler`

* Google Logging:
`sudo apt-get install libgoogle-glog-dev`

* Google Flags:
`sudo apt-get install libgflags-dev`

* LevelDB:
`sudo apt-get install libleveldb-dev`

* HDF5:
`sudo apt-get install libhdf5-serial-dev`

* LMDB:
`sudo apt-get install liblmdb-dev`

* Snappy:
`sudo apt-get install libsnappy-dev`


In the following we will refer to `$DETECTION_DIR` as the directory where you cloned the repository `online-detection`
 
#### Faster R-CNN and Caffe installation
Faster R-CNN needs the `caffe-fast-rcnn` version of [Caffe framework](http://caffe.berkeleyvision.org/), wich contains layers specifically created for it.

In the following we provide instructions to fetch that version and compile it, but you can also refer to the official Caffe's fork link:<br>
https://github.com/ShaoqingRen/caffe/tree/faster-R-CNN .

Note that, we modified the provided version in order to use Resnet50 and Resnet101 models

Instructions provided below will place `caffe` directory in `external/faster_rcnn/external` folder and will compile it locally and compile Faster R-CNN.

```
cd $DETECTION_DIR/external/
git clone https://github.com/ShaoqingRen/faster_rcnn.git
cd $DETECTION_DIR
./scripts/fetch_caffe.sh
cd external/faster_rcnn/external/caffe
make
make matcaffe
cd $DETECTION_DIR/external/faster_rcnn
matlab faster_rcnn_build
matlab startup
```

Please, refer to the installation instructions of Faster RCNN at this [link](https://github.com/ShaoqingRen/faster_rcnn#preparation-for-testing) for further details.

#### FALKON installation
In order to install FALKON, please follow the following instructions:
~~
cd $DETECTION_DIR/external/
git clone https://github.com/LCSL/FALKON_paper.git
~~
And then please, follow instructions of the [official repository](https://github.com/LCSL/FALKON_paper).


Finally, please, type:
```
cd $DETECTION_DIR/
matlab online_detection_build
matlab startup
```


## Usage
This module allows to train a detection model online, in just few seconds. It relies on Faster R-CNN for feature extraction and on FALKON + Minibootstrap procedure for classification. Please, refer to the [paper](https://www.semanticscholar.org/paper/Speeding-Up-Object-Detection-Training-for-Robotics-Maiettini-Pasquale/6a8a3b27a78c78bc80984fca29554de3269d34d3) for further details about the algorithm.

You can use your own Faster R-CNN pretrained weights as feature extraction module. We made available a ZF model, trained on 20 bjects of the iCubWorld Transformation dataset. In order to use it you can run the script fetch_model.sh by doing the following:
```
cd $DETECTION_DIR
./scripts/fetch_model.sh
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



