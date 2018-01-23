function script_faster_rcnn_incremental_ICUB_ZF()
% script_faster_rcnn_VOC0712_ZF()
% Faster rcnn training and testing with Zeiler & Fergus model
% --------------------------------------------------------
% Faster R-CNN
% Copyright (c) 2015, Shaoqing Ren
% Licensed under The MIT License [see LICENSE for details]
% --------------------------------------------------------

clc;
%clear mex;
clear is_valid_handle; % to clear init_key
run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'startup'));
%% -------------------- CONFIG --------------------
opts.caffe_version          = 'caffe_faster_rcnn';
opts.gpu_id                 = auto_select_gpu; %ELISA: todo
active_caffe_mex(opts.gpu_id, opts.caffe_version);

% do validation, or not 
opts.do_val                 = false; %ELISA: changed

% model
model                       = Model.ZF_for_Faster_RCNN_incremental_ICUB; %ELISA: changed
% cache base
cache_base_proposal         = 'faster_rcnn_ICUB_ZF'; %ELISA: changed
cache_base_fast_rcnn        = '';

% train/test data
dataset                     = [];
use_flipped                 = true;
dataset                     = Dataset.icub_trainval(dataset, 'TASK1_train', use_flipped); %ELISA: changed
dataset                     = Dataset.icub_test(dataset, 'TASK1_test', false); %ELISA: changed

output_dir                  = 'output_VOC2007_ZF_voc_mean';

%% -------------------- PRE-TRAIN --------------------
% conf
conf_proposal               = proposal_config('image_means', model.mean_image, 'feat_stride', model.feat_stride);
fprintf('proposal_config\n');
conf_fast_rcnn              = fast_rcnn_config('image_means', model.mean_image);
fprintf('fast_rcnn_config\n');
% set cache folder for each stage
model                       = Faster_RCNN_Train.set_cache_folder(cache_base_proposal, cache_base_fast_rcnn, model); %ELISA: to look if it is correct
fprintf('Faster_RCNN_Train.set_cache_folder\n');

% generate anchors and pre-calculate output size of rpn network 
[conf_proposal.anchors, conf_proposal.output_width_map, conf_proposal.output_height_map] = proposal_prepare_anchors(conf_proposal, model.stage1_rpn.cache_name, model.stage1_rpn.test_net_def_file); %ELISA: to look if it is correct
fprintf('proposal_prepare_anchors\n');

%%  stage one proposal
fprintf('\n***************\n stage one proposal \n***************\n');
% train
model.stage1_rpn            = Faster_RCNN_Train.do_proposal_train(conf_proposal, dataset.TASK1, model.stage1_rpn, opts.do_val, output_dir);
fprintf('Faster_RCNN_Train.do_proposal_train');

% extract regions for stage one fast rcnn
dataset.TASK1.roidb_train        	= cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage1_rpn, output_dir, x, y), dataset.TASK1.imdb_train, dataset.TASK1.roidb_train, 'UniformOutput', false);

%%  stage one fast rcnn
fprintf('\n***************\n stage one fast rcnn\n***************\n');
% train
model.stage1_fast_rcnn      = Faster_RCNN_Train.do_fast_rcnn_train(conf_fast_rcnn, dataset.TASK1, model.stage1_fast_rcnn, opts.do_val, output_dir);

%%  stage two proposal
% net proposal
fprintf('\n***************\n stage two proposal\n***************\n');
% train
model.stage2_rpn.init_net_file = model.stage1_fast_rcnn.output_model_file;
model.stage2_rpn            = Faster_RCNN_Train.do_proposal_train(conf_proposal, dataset.TASK1, model.stage2_rpn, opts.do_val, output_dir);

% extract regions for stage one fast rcnn
dataset.TASK1.roidb_train       	= cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn, output_dir, x, y), dataset.TASK1.imdb_train, dataset.TASK1.roidb_train, 'UniformOutput', false);

%%  stage two fast rcnn
fprintf('\n***************\n stage two fast rcnn\n***************\n');
% train
model.stage2_fast_rcnn.init_net_file = model.stage1_fast_rcnn.output_model_file;
% model.stage2_fast_rcnn.init_net_file = model.stage2_rpn.output_model_file;
model.stage2_fast_rcnn               = Faster_RCNN_Train.do_fast_rcnn_train(conf_fast_rcnn, dataset.TASK1, model.stage2_fast_rcnn, opts.do_val, output_dir);

% % save final models, for outside tester
Faster_RCNN_Train.gather_rpn_fast_rcnn_models(conf_proposal, conf_fast_rcnn, model, dataset, output_dir);

%% Test of trained net on TASK1
% fprintf('\n***************\n final test\n***************\n');
%      
model.stage2_rpn.nms        = model.final_test.nms;
dataset.roidb_test          = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn, output_dir, x, y), dataset.imdb_test, dataset.roidb_test, 'UniformOutput', false);
opts.final_mAP              = cellfun(@(x, y) Faster_RCNN_Train.do_fast_rcnn_test(conf_fast_rcnn, model.stage2_fast_rcnn, output_dir, x, y), dataset.imdb_test, dataset.roidb_test, 'UniformOutput', false);
 % 
% % % save final models, for outside tester
% Faster_RCNN_Train.gather_rpn_fast_rcnn_models(conf_proposal, conf_fast_rcnn, model, dataset);



%% -------------------- TRAIN RLS --------------------
% region proposals generation
model.stage2_rpn.nms        = model.final_test.nms;
dataset.roidb_train             = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal,model.stage2_rpn, output_dir, x, y), dataset.imdb_train, dataset.roidb_train, 'UniformOutput', false);

dataset.TASK1.roidb_train             = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal,model.stage2_rpn, output_dir, x, y), dataset.TASK1.imdb_train, dataset.TASK1.roidb_train, 'UniformOutput', false);
model.feature_extraction.binary_file  = model.stage2_fast_rcnn.output_model_file;
model.feature_extraction.net_def_file = model.stage2_fast_rcnn.test_net_def_file;

% features extraction
feature_layer = 'fc7';
cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_extract_features(conf_fast_rcnn, model.feature_extraction, feature_layer, x, y), dataset.imdb_train, dataset.roidb_train);

cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_extract_features(conf_fast_rcnn, model.feature_extraction, feature_layer, x, y), dataset.TASK1.imdb_train, dataset.TASK1.roidb_train);

% bbox regressor train
model.bbox_regressors                = cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_bbox_regressor_train(conf_fast_rcnn, model.feature_extraction, x, y), dataset.TASK1.imdb_train, dataset.TASK1.roidb_train);
model.bbox_regressors                = cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_bbox_regressor_train(conf_fast_rcnn, model.feature_extraction, x, y), dataset.imdb_train, dataset.roidb_train);

% classifier train
% SVM
%model.classifiers                    = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifier_train(conf_fast_rcnn, model.feature_extraction, 'SVMs', x), dataset.TASK1.imdb_train, 'UniformOutput', false);
% GURLS
 train_classifier_options = struct;
% train_classifier_options.gurlsOptions = struct;
% train_classifier_options.gurlsOptions.kernelfun = 'rbf';
% train_classifier_options.gt_regions = 1; %1 = gt regions, 0 = proposals with iou > thresh
% train_classifier_options.subtract_mean = 1; % 1 = feature mean subtraction
 train_classifier_options.cache_dir = 'cache_classifiers/inc_VOC2007_gt_gauss_voc_mean_19objs_alpha0/';
 model.feature_extraction.cache_name = 'feature_extraction_cache';

% model.classifiers.gurlsOpt                    = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifier_train(conf_fast_rcnn, model.feature_extraction, 'gurls', train_classifier_options, x), dataset.imdb_train, 'UniformOutput', false);
% model.classifiers.gurlsOpt                    = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifier_train(conf_fast_rcnn, model.feature_extraction, 'gurls', train_classifier_options, x), dataset.imdb_test, 'UniformOutput', false);
% 
% model.classifiers.gurlsOpt                    = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifier_train(conf_fast_rcnn, model.feature_extraction, 'gurls', train_classifier_options, x), dataset.TASK1.imdb_train, 'UniformOutput', false);

fprintf('\n***************\n the end \n***************\n');

%%  -------------------- TEST RLS ---------------------
fprintf('\n***************\n final test\n***************\n');
      
model.stage2_rpn.nms        = model.final_test.nms;

% region proposals generation
dataset.roidb_test          = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn , output_dir, x, y), dataset.imdb_test, dataset.roidb_test, 'UniformOutput', false);
dataset.roidb_test          = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn , output_dir, x, y), dataset.imdb_test, dataset.roidb_test, 'UniformOutput', false);

% features extraction
feature_layer = 'fc7';
cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_extract_features(conf_fast_rcnn, model.feature_extraction, feature_layer, x, y), dataset.imdb_test, dataset.roidb_test);

% classifier test
model.classifiers.binary_file = model.feature_extraction.binary_file;
model.classifiers.net_def_file = model.feature_extraction.net_def_file;
% model.classifiers.models  = 
for i = length(model.classifiers.models{1}{1}{1})
    curr_classifier = model.classifiers.models{1}{1}{1}{i};
    curr_classifier.binary_file = model.classifiers.binary_file;
    curr_classifier.net_def_file = model.classifiers.net_def_file;
    opts.cls_mAP{i}                = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifiers_test(train_classifier_options.cache_dir, conf_fast_rcnn, '',  'incremental', curr_classifier, x), dataset.imdb_test, 'UniformOutput', false);
end

% bbox regressor test
opts.final_mAP              = cellfun(@(x) Incremental_Faster_RCNN_Train.do_regressor_test(conf_fast_rcnn, model.bbox_regressors, model.stage2_fast_rcnn, x), dataset.imdb_test, 'UniformOutput', false);
opts.final_mAP              = cellfun(@(x) Incremental_Faster_RCNN_Train.do_regressor_test(conf_fast_rcnn, model.bbox_regressors, model.stage2_fast_rcnn, x), dataset.imdb_test, 'UniformOutput', false);


% % save final models, for outside tester
model_name = 'model_prova.mat';
opts_name = 'opts_prova.mat';
save(model_name,'-struct', 'model');
save(opts_name, '-struct', 'opts');
end

function [anchors, output_width_map, output_height_map] = proposal_prepare_anchors(conf, cache_name, test_net_def_file)
    [output_width_map, output_height_map] ...                           
                                = proposal_calc_output_size(conf, test_net_def_file);
    anchors                = proposal_generate_anchors(cache_name, ...
                                    'scales',  2.^[3:5]);
end
