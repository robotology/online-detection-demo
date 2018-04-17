function startup()
% startup()
% --------------------------------------------------------
% Faster R-CNN
% Copyright (c) 2015, Shaoqing Ren
% Licensed under The MIT License [see LICENSE for details]
% --------------------------------------------------------

    curdir = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(curdir, 'utils')));
    addpath(genpath(fullfile(curdir, 'functions')));
    addpath(genpath(fullfile(curdir, 'bin')));
    addpath(genpath(fullfile(curdir, 'experiments')));
    addpath(genpath(fullfile(curdir, 'imdb')));
     addpath(genpath(fullfile(curdir, 'Demo')));
%     addpath([curdir '/../yarp-matlab-bindings/build/install/mex']);
%     javaaddpath('/home/IIT.LOCAL/emaiettini/workspace/yarp/build');
%     javaaddpath('/home/IIT.LOCAL/emaiettini/workspace/yarp/build/yarp');
%     javaaddpath('/home/IIT.LOCAL/emaiettini/workspace/yarp/build/lib');

    mkdir_if_missing(fullfile(curdir, 'datasets'));

    mkdir_if_missing(fullfile(curdir, 'external'));

    caffe_path = fullfile(curdir, 'external', 'caffe', 'matlab');
    if exist(caffe_path, 'dir') == 0
        error('matcaffe is missing from external/caffe/matlab; See README.md');
    end
    addpath(genpath(caffe_path));

    mkdir_if_missing(fullfile(curdir, 'imdb', 'cache'));

    mkdir_if_missing(fullfile(curdir, 'output'));

    mkdir_if_missing(fullfile(curdir, 'models'));

    fprintf('fast_rcnn startup done\n');
    
%     run(fullfile(getenv('Gurls_ROOT'),'gurls/utils/gurls_install.m'))
    run('/home/IIT.LOCAL/emaiettini/workspace/Repos/GURLS/gurls/utils/gurls_install.m')
end
