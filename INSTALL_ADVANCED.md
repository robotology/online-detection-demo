
### Advanced instructions for installing Faster R-CNN
If the installation using the `Scripts/fetch_install_faster_rcnn.sh` failed or you prefer to install Faster R-CNN by yourself, you will find the list of isntructions in this file.
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

### Advanced instructions for installing Falkon
```
cd $DETECTION_DIR/
./Scripts/fetch_falkon.sh
cd external/FALKON_paper/FALKON
mex -largeArrayDims ./tri_solve_d.cpp -lmwblas -lmwlapack
mex -largeArrayDims ./inplace_chol.cpp -lmwblas -lmwlapack
```
