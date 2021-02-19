

## CMake options

- OOD_Weak_supervision
- OOD_detectionExtract
- OOD_humanStructure
- OOD_augmentation
- OOD_dispBlobber
- OOD_multiviewer
- OOD_offline

### Dependencies:

* [YARP](https://github.com/robotology/yarp)
* [OpenCV](http://opencv.org/downloads.html)
* [Cuda](http://docs.nvidia.com/cuda/cuda-installation-guide-linux/#axzz4BkDT7m6r)
* [Matlab] (https://it.mathworks.com/)
* [Matlab Parallel Computing Toolbox] (https://it.mathworks.com/products/parallel-computing.html) 
* [Python](https://www.python.org/downloads/)
* [Faster R-CNN](https://github.com/ShaoqingRen/faster_rcnn)
* [Caffe](http://caffe.berkeleyvision.org/)
* [FALKON](https://github.com/LCSL/FALKON_paper)
* Other required packages: OpenBLAS, Boost C++, Google Protobuf Buffers C++, Google Logging, Google Flags, LevelDB, HDF5, LMDB, Snappy


While you can follow the official instructions to install the first dependencies (namely, YARP, Opencv, Cuda, Matlab and Python), we suggest to follow the provided steps to install Faster R-CNN, the correct version of Caffe and FALKON.

We also list the commands to install the packages required by Caffe.

#### Faster R-CNN and Caffe installation
In the following we will refer to `$DETECTION_DIR` as the directory where you cloned the repository `online-detection-demo`

```
sudo apt-get install libopenblas-dev libboost-all-dev libprotobuf-dev protobuf-compiler \
libgoogle-glog-dev libgflags-dev libleveldb-dev libhdf5-serial-dev liblmdb-dev libsnappy-dev
```


```
# $1=/usr/local/MATLAB/R2019b  $2=/usr/local/cuda $3=16
./Scripts/fetch_install_faster_rcnn.sh $1 $2 $3
```

### Advanced

Faster R-CNN needs the `caffe-fast-rcnn` version of [Caffe framework](http://caffe.berkeleyvision.org/), wich contains layers specifically created for it.

In the following we provide instructions to fetch that version and compile it, but you can also refer to the official Caffe's fork link:<br>
https://github.com/ShaoqingRen/caffe/tree/faster-R-CNN .

Note that, we modified the provided version in order to use Resnet50 and Resnet101 models.

The instructions provided below will place `caffe` directory in `external/faster_rcnn/external` folder and will compile it locally and compile Faster R-CNN.

```
cd $DETECTION_DIR/external/
git clone https://github.com/ShaoqingRen/faster_rcnn.git
cd $DETECTION_DIR
./Scripts/fetch_caffe.sh
cd external/faster_rcnn/external/caffe
make MATLAB_DIR=/usr/local/MATLAB/R2019b CUDA_DIR=/usr/local/cuda 
make matcaffe MATLAB_DIR=/usr/local/MATLAB/R2019b CUDA_DIR=/usr/local/cuda
cd $DETECTION_DIR/external/faster_rcnn
matlab faster_rcnn_build
matlab startup
```

Please, refer to the [official repository](https://github.com/ShaoqingRen/faster_rcnn#preparation-for-testing) for further details.

#### FALKON installation
In order to install FALKON, please follow the following instructions:
```
cd $DETECTION_DIR/
./Scripts/fetch_install_falkon.sh
```
Please, refer to the [official repository](https://github.com/LCSL/FALKON_paper) for further details.


Finally, please, type:

```
cd $DETECTION_DIR/
matlab online_detection_build
matlab startup
```
