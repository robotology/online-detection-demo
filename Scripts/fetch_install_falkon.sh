#!/bin/bash

# $1=/usr/local/MATLAB/R2019b  $2=/usr/local/cuda $3=16

# Fetch Faster R-CNN repository in external folder
cd external

# Fetch Falkon
FILE=FALKON_paper.zip
URL=https://www.dropbox.com/s/rxo2twzhc2nwvz3/FALKON_paper.zip?dl=0

echo "Downloading falkon in external directory..."

wget $URL -O $FILE --no-check-certificate

echo "Unzipping falkon..."

unzip $FILE

rm $FILE

echo "falkon is ready."

# Make CAFFE
cd FALKON_paper/FALKON
mex -largeArrayDims ./tri_solve_d.cpp -lmwblas -lmwlapack
mex -largeArrayDims ./inplace_chol.cpp -lmwblas -lmwlapack

echo "Done."
