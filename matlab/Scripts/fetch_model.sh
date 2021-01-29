#!/bin/bash

FILE=ZF_model_20objs.tar.gz
URL_model=https://www.dropbox.com/s/410xryxh17uv13x/ZF_model_20objs.tar.gz?dl=0
URL_stats=https://www.dropbox.com/s/6bbrofwx29b1sle/ZF20_feature_Stats.mat?dl=0
DIRECTORY=external/faster_rcnn/Data/cnn_models

if [ ! -d "$DIRECTORY"  ]; then

mkdir $DIRECTORY

fi

cd $DIRECTORY

echo "Downloading Faster R-CNN pretrained weights..."

wget $URL_model -O $FILE --no-check-certificate

echo "Unzipping the weights..."

tar zxvf $FILE

rm $FILE

cd features_statistics
wget $URL_stats --no-check-certificate


echo "Done."
