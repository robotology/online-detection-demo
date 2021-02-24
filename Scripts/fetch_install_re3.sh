#!/bin/bash

# $1=/usr/local/MATLAB/R2019b  $2=/usr/local/cuda $3=16

# Fetch Faster R-CNN repository in external folder
cd external
git clone https://github.com/danielgordon10/re3-tensorflow

# Fetch CAFFE
FILE=re3_weights.tar.gz
URL=https://www.dropbox.com/s/y6b15l0clgyyq8p/re3_weights.tar.gz?dl=0
DIRECTORY=re3-tensorflow/logs

if [ ! -d "$DIRECTORY"  ]; then

mkdir $DIRECTORY

fi

cd $DIRECTORY

echo "Downloading Re3 weights in the external directory..."

wget $URL -O $FILE --no-check-certificate

echo "Unzipping Re3 weights..."

tar -xf $FILE

rm $FILE

echo "Re3 is ready."

echo "Done."
