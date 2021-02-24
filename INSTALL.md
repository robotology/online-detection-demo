# Installation guide
In this file, we report the list of instructions for the installation of the `online-detection-demo` considering the **MATLAB** version of the detection algorithm. We start covering the list of the [dependencies](#dependencies) of the application and the instructions for the installation of the [external repositories](#external-repositories) used. Finally, we provide [instructions](#installation) for compiling and installing the modules of the application.

## Dependencies:
The list of dependencies is as follows:

* [YARP](https://github.com/robotology/yarp)
* [OpenCV](http://opencv.org/downloads.html)
* [Cuda](http://docs.nvidia.com/cuda/cuda-installation-guide-linux/#axzz4BkDT7m6r)
* [Python](https://www.python.org/downloads/)
* [Matlab](https://it.mathworks.com/)
* [Matlab Parallel Computing Toolbox](https://it.mathworks.com/products/parallel-computing.html) 
* Lua
* Posix.signal
   - luarocks
   - luaposix
* The following Python packages:
    - **numpy** (tested version: 1.13.1)
    - **opencv-python** (tested version: 3.3.0.10)
    - **tensorflow-gpu** (tested versions: 1.5.0 for Cuda 9.0 and 1.13.1 for Cuda 10.0)
* Other required packages: OpenBLAS, Boost C++, Google Protobuf Buffers C++, Google Logging, Google Flags, LevelDB, HDF5, LMDB, Snappy

You can follow the installtion instructions in the official repositories of the first dependencies (namely, YARP, Opencv, Cuda, Matlab, Python and lua), while you can install the list of packages with the following commands:

```
sudo apt-get install libopenblas-dev libboost-all-dev libprotobuf-dev protobuf-compiler \
libgoogle-glog-dev libgflags-dev libleveldb-dev libhdf5-serial-dev liblmdb-dev libsnappy-dev
python3.5 -m pip install numpy==1.13.1
python3.5 -m pip install opencv-python==3.3.0.10
python3.5 -m pip install opencv-python==1.5.0
```

## External repositories
The external repositories required for the matlab version of this application is as follows:
* [Faster R-CNN](https://github.com/ShaoqingRen/faster_rcnn)
* [Caffe](http://caffe.berkeleyvision.org/)
* [FALKON](https://github.com/LCSL/FALKON_paper)
* [Re3 tracker](https://github.com/moorejee/Re3)

### Faster R-CNN and Caffe installation
For this step, we prepared the script `fetch_install_faster_rcnn.sh` for your convinience. The script will clone the official repository of Faster R-CNN in the `external` folder, fetch the correct CAFFE version and compile both of them in the correct location. 

Run the script as follows, substituing the variables `$1 $2 $3` with, respectively, the matlab location, the cuda location and the number of jobs you want to use for compilation. This is an example: `$1`: `/usr/local/MATLAB/R2019b`  `$2`: `/usr/local/cuda` `$3`: `16`
```
./Scripts/fetch_install_faster_rcnn.sh $1 $2 $3
```
If using the script you get some errors or if you prefer to install Faster R-CNN by yourself, you will find the list of instructions at this [link](https://github.com/Arya07/online-detection-demo/blob/main/INSTALL_ADVANCED.md). 

### FALKON installation
For this step, we prepared the script `fetch_install_falkon.sh` for your convinience. The script will fetch the correct version of Falkon and compile it in the correct location. Run the script as follows:

```
./Scripts/fetch_install_falkon.sh
```

If using the script you get some errors or if you prefer to install Falkon by yourself, you will find the list of instructions at this [link](https://github.com/Arya07/online-detection-demo/blob/main/INSTALL_ADVANCED.md). 

### Re3 Tracker installation
For this step, we prepared the script `fetch_install_re3.sh` for your convinience. The script will fetch the correct version of the Re3 tracker and compile it in the correct location. Run the script as follows:

```
./Scripts/fetch_install_re3.sh
```

If using the script you get some errors or if you prefer to install the Re3 Tracker by yourself, you will find the list of instructions at this [link](https://github.com/Arya07/online-detection-demo/blob/main/INSTALL_ADVANCED.md). 

## Installation

#### Build matlab modules
Run the following scripts:
```
matlab -nodisplay -nosplash -nodesktop -r "run('modules/modules_matlab/online_detection_build.m');exit;"
matlab -nodisplay -nosplash -nodesktop -r "run('modules/modules_matlab/startup.m');exit;"
```
#### Build all other modules
Follow these instructions:
```
mkdir build
ccmake ../
make 
make install
```
**Note**: Please, consider that while doing Cmake you can flag different options, depending on the modules that you want to compile. The default options will allow you to compile the basic version of the demo. Please refer to this [description](https://github.com/Arya07/online-detection-demo/blob/main/INSTALL_ADVANCED.md) for details about the different options

## Setting up the system
The implemented detection algorithm allows to train a new model online, in just few seconds. It relies on Faster R-CNN for feature extraction and on FALKON + Minibootstrap procedure for classification (more details [here](https://www.semanticscholar.org/paper/Speeding-Up-Object-Detection-Training-for-Robotics-Maiettini-Pasquale/6a8a3b27a78c78bc80984fca29554de3269d34d3)).

You can use your own Faster R-CNN pretrained weights as feature extraction module but we made available the ones used for our experiments. You can download them running the following command in the folder of the repository.
```
./Scripts/fetch_model.sh

```
