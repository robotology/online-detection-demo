%% TRAIN OPTIONS
disp('Adding required paths...');
% load('workspaces/ZF_iCWT_TASK1');
addpath('./datasets/VOCdevkit2007/VOCdevkit/VOCcode_incremental');
addpath(genpath('../FALKON_paper'));

%% PATHS
disp('Configuring required paths...');
current_path = pwd;
model_version = '10x1500_250_new';
classes = importdata([current_path '/Demo/Conf/Classes_T2.txt' ]);
cls_model_path = [current_path '/Demo/Models/cls_model_' model_version '.mat' ];
bbox_model_path = [current_path '/Demo/Models/bbox_model_' model_version '.mat' ];
dataset_path = [current_path '/datasets/iCubWorld-Transformations/'];
cnn_model_path=[current_path '/output_iCWT_TASK1_10objs_40k20k_newBatchSize/faster_rcnn_final'];

%% FILES
image_set = 'test_TASK2_10objs';

%% CAFFE
cnn_model.opts.caffe_version          = 'caffe_faster_rcnn';
cnn_model.opts.gpu_id                 = 1;

%% DETECTION PARAMS
disp('Configuring detection params...');
cnn_model.opts.per_nms_topN           = 6000;
cnn_model.opts.nms_overlap_thres      = 0.7;
cnn_model.opts.after_nms_topN         = 1000;
cnn_model.opts.use_gpu                = true;

cnn_model.opts.test_scales            = 600;
detect_thresh                         = 0.5;

%% Classifier options
fprintf('Classifier options setting...\n');
cls_mode = 'falkon_miniBootstrap'; %---------------------------------------------------------------------------------------------
max_img_per_class                         = 1500;

train_classifier_options = struct;
% train_classifier_options.cross_validation = struct;
% train_classifier_options.cross_validation.required = true;

negatives_selection.policy = 'bootStrap';
negatives_selection.batch_size = 1500;
negatives_selection.iterations = 10;
% rebalancing = 'inv_freq';

%FALKON options -----------------------------------------------------------------------------------------------------------
% train_classifier_options.cache_dir = '';
train_classifier_options.memToUse = 10;          % GB of memory to use (using "[]" will allow the machine to use all the free memory)
train_classifier_options.useGPU = 1;             % flag for using or not the GPU
train_classifier_options.T= 150;
train_classifier_options.M=250;

