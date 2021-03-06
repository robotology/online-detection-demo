%% TRAIN OPTIONS
disp('Adding required paths...');
addpath(genpath('../FALKON_paper'));

%% PATHS
disp('Configuring required paths...');
current_path            = pwd;
cnn_model_path          = [current_path '/Data/cnn_models/output_iCWT_features_20objs/faster_rcnn_final/faster_rcnn_ICUB_ZF']; %-------------------------------------------

feature_statistics_path = [current_path '/Data/cnn_models/features_statistics/ZF20_feature_Stats.mat' ]; %-------------------------------------------
% 
% cnn_model_path          = [current_path '/Data/cnn_models/output_feature_ZF_icub20/faster_rcnn_final/faster_rcnn_feature_ZF_icub20']; %-------------------------------------------
% 
% feature_statistics_path = [current_path '/Data/cnn_models/features_statistics/scale/feat_stats20_20.mat' ]; %-------------------------------------------



%% FILES
default_dataset_name      = 'def_dataset.mat'; %---------------------------------------------------------------------------------------------------------------
default_model_name        = 'def_model.mat';   %---------------------------------------------------------------------------------------------------------------
dataset_path              = '/Data/datasets/'; %---------------------------------------------------------------------------------------------------------------
model_path                = '/Data/models/'; %---------------------------------------------------------------------------------------------------------------

%% CAFFE
cnn_model.opts.caffe_version           = 'caffe_faster_rcnn';
cnn_model.opts.gpu_id                  = 1;

%% RPN PARAMS
disp('Configuring RPN params...');
cnn_model.opts.per_nms_topN            = 6000;
cnn_model.opts.nms_overlap_thres       = 0.7;
after_nms_topN_train                   = 500; %---------------------------------------------------------------------------------------------------------------
after_nms_topN_test                    = 300; %---------------------------------------------------------------------------------------------------------------
cnn_model.opts.use_gpu                 = true;
cnn_model.opts.test_scales             = 600;

%% FEATURES PARAMS
disp('Configuring Features params...');
ld = load(feature_statistics_path);
statistics.standard_deviation          = ld.standard_deviation;
statistics.mean_feat                   = ld.mean_feat;
statistics.mean_norm                   = ld.mean_norm;
clear ld;
is_share_feature = 1; %---------------------------------------------------------------------------------------------------

%% Classifier options
fprintf('Classifier options setting...\n');
cls_opts = struct;
cls_opts.cls_mod = 'FALKON';
max_img_for_new_class                  = 80; %---------------------------------------------------------------------------------------------------------------
max_img_for_old_class                  = max_img_for_new_class/2; 

negatives_selection.policy             = 'bootStrap';
negatives_selection.batch_size         = 2000; %---------------------------------------------------------------------------------------------------------------
negatives_selection.iterations         = 10; %---------------------------------------------------------------------------------------------------------------
negatives_selection.neg_ovr_thresh     = 0.3;
negatives_selection.evict_easy_thresh  = -0.9;
negatives_selection.select_hard_thresh = -0.7;
total_negatives = negatives_selection.batch_size*negatives_selection.iterations;
if total_negatives > max_img_for_new_class
   negatives_selection.neg_per_image = round(total_negatives/max_img_for_new_class);
else
   negatives_selection.neg_per_image = 1;
end
cls_opts.negatives_selection           = negatives_selection;
cls_opts.feat_layer                    = 'fc7'; %------------------------------------------------------------------------------------------------------------
detect_thresh                          = 0.15; %---------------------------------------------------------------------------------------------------------------

% FALKON options -----------------------------------------------------------------------------------------------------------
train_classifier_options               = struct;
train_classifier_options.memToUse      = 10;          % GB of memory to use (using "[]" will allow the machine to use all the free memory)
train_classifier_options.useGPU        = 1;           % flag for using or not the GPU
train_classifier_options.T             = 150;
train_classifier_options.M             = 1500;
train_classifier_options.lambda        = 0.001;
train_classifier_options.sigma         = 15;
train_classifier_options.kernel        = gaussianKernel(train_classifier_options.sigma); 
cls_opts.train_classifier_options      = train_classifier_options;
cls_opts.statistics                    = statistics;

%% Bbox regression options
bbox_opts = struct;
bbox_opts.min_overlap = 0.6;

tocs = 0;
tocs_counter = 0;

%% Application options
show_regions = false;
