# Installation guide
In this file, we report the list of instructions for the installation of the `online-detection-demo` considering the **MATLAB** version of the detection algorithm. We start covering the list of the [dependencies](#dependencies) of the application and the [instructions]() for the installation of the external repositories used. Finally, we provide instructions for compiling and installing the modules of the application.

## Dependencies:
The list of dependencies is as follows:

* [YARP](https://github.com/robotology/yarp)
* [OpenCV](http://opencv.org/downloads.html)
* [Cuda](http://docs.nvidia.com/cuda/cuda-installation-guide-linux/#axzz4BkDT7m6r)
* [Python](https://www.python.org/downloads/)
* [Matlab] (https://it.mathworks.com/)
* [Matlab Parallel Computing Toolbox] (https://it.mathworks.com/products/parallel-computing.html) 
* Other required packages: OpenBLAS, Boost C++, Google Protobuf Buffers C++, Google Logging, Google Flags, LevelDB, HDF5, LMDB, Snappy

You can follow the installtion instructions in the official repositories of the first dependencies (namely, YARP, Opencv, Cuda, Matlab and Python), while you can install the list of packages with the following command:

```
sudo apt-get install libopenblas-dev libboost-all-dev libprotobuf-dev protobuf-compiler \
libgoogle-glog-dev libgflags-dev libleveldb-dev libhdf5-serial-dev liblmdb-dev libsnappy-dev
```

## External repositories
The external repositories required for the matlab version of this application is as follows:
* [Faster R-CNN](https://github.com/ShaoqingRen/faster_rcnn)
* [Caffe](http://caffe.berkeleyvision.org/)
* [FALKON](https://github.com/LCSL/FALKON_paper)

#### Faster R-CNN and Caffe installation
For this step, we prepared the script `fetch_install_faster_rcnn.sh` for your convinience. The script will clone the official repository of Faster R-CNN in the `external` folder, fetch the correct CAFFE version and compile both of them in the correct location. 

Run the script as follows, substituing the variables `$1 $2 $3` with, respectively, the matlab location, the cuda location and the number of jobs you want to use for compilation. This is an example: `$1`: `/usr/local/MATLAB/R2019b`  `$2`: `/usr/local/cuda` `$3`: `16`
```
./Scripts/fetch_install_faster_rcnn.sh $1 $2 $3
```
If using the script you get some errors or if you prefer to install Faster R-CNN by yourself, you will find the list of instructions at this [link](https://github.com/Arya07/online-detection-demo/blob/main/INSTALL_ADVANCED.md). 

#### FALKON installation
For this step, we prepared the script `fetch_install_falkon.sh` for your convinience. The script will fetch the correct version of Falkon and compile it in the correct location. Run the script as follows:

```
./Scripts/fetch_install_falkon.sh
```
If using the script you get some errors or if you prefer to install Faster R-CNN by yourself, you will find the list of instructions at this [link](https://github.com/Arya07/online-detection-demo/blob/main/INSTALL_ADVANCED.md). 

Finally, please, type:

```
cd $DETECTION_DIR/
matlab online_detection_build
matlab startup
```



## CMake options

- OOD_Weak_supervision
- OOD_detectionExtract
- OOD_humanStructure
- OOD_augmentation
- OOD_dispBlobber
- OOD_multiviewer
- OOD_offline
