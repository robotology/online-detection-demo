%  --------------------------------------------------------
%  Online-Object-Detection Demo
%  Author: Elisa Maiettini
%  --------------------------------------------------------
function online_detection_build()

% Compile nms_mex
if ~exist('nms_mex', 'file')
  fprintf('Compiling nms_mex\n');

  mex -O -outdir bin ...
      CXXFLAGS="\$CXXFLAGS -std=c++11"  ...
      -largeArrayDims ...
      ../../external/faster_rcnn/functions/nms/nms_mex.cpp ...
      -output nms_mex;
end

if ~exist('nms_gpu_mex', 'file')
   fprintf('Compiling nms_gpu_mex\n');
   addpath(fullfile(pwd, '..', '..', 'external', 'faster_rcnn', 'functions', 'nms'));
   nvmex('../../external/faster_rcnn/functions/nms/nms_gpu_mex.cu', 'bin');
   delete('nms_gpu_mex.o');
end

