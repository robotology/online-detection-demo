#!/bin/bash

FILE=caffe.tar.gz
URL=https://www.dropbox.com/s/dh3gvm1s6vo9rm2/caffe.tar.gz?dl=0
DIRECTORY=external/faster_rcnn/external

if [ ! -d "$DIRECTORY"  ]; then

mkdir $DIRECTORY

fi

cd $DIRECTORY

echo "Downloading caffe for Faster R-CNN in external directory..."

wget $URL -O $FILE --no-check-certificate

echo "Unzipping..."

tar zxvf $FILE

rm $FILE

echo "Done."
