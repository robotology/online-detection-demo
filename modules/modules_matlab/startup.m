%  --------------------------------------------------------
%  Online-Object-Detection Demo
%  Author: Elisa Maiettini
%  --------------------------------------------------------
function startup()

    curdir = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(curdir, 'utils')));
    addpath(genpath(fullfile(curdir, 'functions')));
    addpath(genpath(fullfile(curdir, 'bin')));
    addpath(genpath(fullfile(curdir, 'Src')));
    addpath(genpath(fullfile(curdir, 'Conf')));
    addpath(genpath(fullfile(curdir, 'external', 'faster_rcnn', 'functions')));
    addpath(genpath(fullfile(curdir, 'external', 'faster_rcnn', 'utils')));

    mkdir_if_missing(fullfile(curdir, 'Data'));
    mkdir_if_missing(fullfile(curdir, 'Data', 'datasets'));
    mkdir_if_missing(fullfile(curdir, 'Data', 'cnn_weights'));
    mkdir_if_missing(fullfile(curdir, 'Data', 'cnn_models'));
    addpath(genpath(fullfile(curdir, 'Data')));

    mkdir_if_missing(fullfile(curdir, 'external'));

    caffe_path = fullfile(curdir, 'external', 'faster_rcnn', 'external', 'caffe', 'matlab');
    if exist(caffe_path, 'dir') == 0
        error('matcaffe is missing from external/caffe/matlab; See README.md');
    end
    addpath(genpath(caffe_path));
    addpath(genpath(fullfile(curdir, 'external', 'FALKON_paper')));


    fprintf('online_detection_demo startup done\n');
    
end
