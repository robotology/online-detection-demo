#!/bin/bash

FILE=ZF_model_20objs.tar.gz
URL_model=https://www.dropbox.com/s/410xryxh17uv13x/ZF_model_20objs.tar.gz
URL_stats=https://www.dropbox.com/s/6bbrofwx29b1sle/ZF20_feature_Stats.mat
DIRECTORY=Data/cnn_models

if [ ! -d "$DIRECTORY"  ]; then

mkdir $DIRECTORY

fi

cd $DIRECTORY

echo "Downloading Faster R-CNN pretrained weights..."

wget $URL_model -O $FILE --no-check-certificate

echo "Unzipping the weights..."

tar zxvf $FILE

rm $FILE

mkdir features_statistics
cd features_statistics

echo "Downloading Faster R-CNN feature statistics..."
wget $URL_stats --no-check-certificate


echo "Done."
