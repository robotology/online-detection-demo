#!/bin/bash

# $1=/usr/local/MATLAB/R2019b  $2=/usr/local/cuda $3=16

# Fetch Faster R-CNN repository in external folder
cd external
git clone https://github.com/ShaoqingRen/faster_rcnn.git
cd ..

# Fetch CAFFE
FILE=caffe.zip
URL=https://www.dropbox.com/s/b07yp2kgw0jf3qk/caffe.zip?dl=0
DIRECTORY=external/faster_rcnn/external

if [ ! -d "$DIRECTORY"  ]; then

mkdir $DIRECTORY

fi

cd $DIRECTORY

echo "Downloading caffe for Faster R-CNN in external directory..."

wget $URL -O $FILE --no-check-certificate

echo "Unzipping caffe..."

unzip $FILE

rm $FILE

echo "Caffe is ready."

# Make CAFFE
cd caffe
make MATLAB_DIR=$1 CUDA_DIR=$2 -j$3
make matcaffe MATLAB_DIR=$1 CUDA_DIR=$2
# Build Faster R-CNN
cd ../..
cd $DETECTION_DIR/external/faster_rcnn
matlab -nodisplay -nosplash -nodesktop -r "run('faster_rcnn_build.m');exit;"
matlab -nodisplay -nosplash -nodesktop -r "run('startup.m');exit;"

echo "Done."
