function faster_rcnn_build()
% faster_rcnn_build()
% --------------------------------------------------------
% Faster R-CNN
% Copyright (c) 2015, Shaoqing Ren
% Licensed under The MIT License [see LICENSE for details]
% --------------------------------------------------------

% Compile nms_mex
if ~exist('nms_mex', 'file')
  fprintf('Compiling nms_mex\n');

  mex -O -outdir bin ...
      CXXFLAGS="\$CXXFLAGS -std=c++11"  ...
      -largeArrayDims ...
      functions/nms/nms_mex.cpp ...
      -output nms_mex;
end

if ~exist('nms_gpu_mex', 'file')
   fprintf('Compiling nms_gpu_mex\n');
   addpath(fullfile(pwd, 'functions', 'nms'));
   nvmex('functions/nms/nms_gpu_mex.cu', 'bin');
   delete('nms_gpu_mex.o');
end

% Compile liblinear
if ~exist('liblinear_train')
  fprintf('Compiling liblinear version 1.94\n');
  fprintf('Source code page:\n');
  fprintf('   http://www.csie.ntu.edu.tw/~cjlin/liblinear/\n');
  mex -outdir bin ...
      CFLAGS="\$CFLAGS -std=c99 -O3 -fPIC" -largeArrayDims ...
      external/liblinear-1.94/matlab/train.c ...
      external/liblinear-1.94/matlab/linear_model_matlab.c ...
      external/liblinear-1.94/linear.cpp ...
      external/liblinear-1.94/tron.cpp ...
      "external/liblinear-1.94/blas/*.c" ...
      -output liblinear_train;
end


