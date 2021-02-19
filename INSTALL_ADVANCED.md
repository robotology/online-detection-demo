
## Advanced instructions for installing Faster R-CNN
If the installation using the `Scripts/fetch_install_faster_rcnn.sh` failed or you prefer to install Faster R-CNN by yourself, you will find the list of isntructions in this section.
In the remaining of this file we will refer to `$DETECTION_DIR` as the directory where you cloned the repository `online-detection-demo`.

Faster R-CNN needs the a specific version of the [Caffe framework](http://caffe.berkeleyvision.org/), wich contains layers specifically created for it.
We provide instructions to fetch that version and compile it, but you can also refer to the official Caffe's fork [link](https://github.com/ShaoqingRen/caffe/tree/faster-R-CNN).
However, note that, we modified the provided version in order to use Resnet50 and Resnet101 models.

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

## Advanced instructions for installing Falkon
If the installation using the `Scripts/fetch_install_falkon.sh` failed or you prefer to install Falkon by yourself, you will find the list of isntructions in this section.
In the remaining of this file we will refer to `$DETECTION_DIR` as the directory where you cloned the repository `online-detection-demo`.
```
cd $DETECTION_DIR/
./Scripts/fetch_falkon.sh
cd external/FALKON_paper/FALKON
mex -largeArrayDims ./tri_solve_d.cpp -lmwblas -lmwlapack
mex -largeArrayDims ./inplace_chol.cpp -lmwblas -lmwlapack
```


## CMake options

- **OOD_Weak_supervision**: if ON, it enables the modules that allow for a weakly supervised learning of the detection model (default ON)
- **OOD_detectionExtract**: if ON, it enables the module to extract the mask of an object given a predicted detection (default OFF)
- **OOD_humanStructure**: if ON, it enables the module to use a set of predicted human joints as a way of interaction (e.g., as an alternative for extracting in hand ground truth) (default OFF)
- **OOD_augmentation**: if ON, it enables the module to use data augmentation technique on the acquired dataset (default OFF)
- **OOD_dispBlobber**: if ON, it enables the module to use closest blob technique to acquire autmatically annotated images of handheld objects (default ON)
- **OOD_multiviewer**: if ON, it enables the module to show the list of known objects in the form of a matrix of pictures of the objects (default ON)
- **OOD_offline**if ON, it enables the modules tha tcan be used for offline experiments (default OFF)
