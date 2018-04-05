%% TRAIN OPTIONS
load('workspaces/ZF_iCWT_TASK1');
addpath('./datasets/VOCdevkit2007/VOCdevkit/VOCcode_incremental');
addpath(genpath('../FALKON_paper'));

%% PATHS
current_path = pwd;
classes = importdata([current_path '/Demo/Conf/Classes_T2.txt' ]);
cls_model_path = [current_path '/Demo/Models/cls_model.mat' ];
bbox_model_path = [current_path '/Demo/Models/bbox_model.mat' ];
dataset_path = [current_path '/datasets/iCubWorld-Transformations/'];
cnn_model_path=[current_path '/output_iCWT_TASK1_10objs_40k20k_newBatchSize/faster_rcnn_final'];

%% FILES
image_set = 'test_TASK2_10objs';

%% CAFFE
cnn_model.opts.caffe_version          = 'caffe_faster_rcnn';
cnn_model.opts.gpu_id                 = 2;

%% DETECTION PARAMS
cnn_model.opts.per_nms_topN           = 6000;
cnn_model.opts.nms_overlap_thres      = 0.7;
cnn_model.opts.after_nms_topN         = 1000;
cnn_model.opts.use_gpu                = true;

cnn_model.opts.test_scales            = 600;
detect_thresh                         = 0.5;

