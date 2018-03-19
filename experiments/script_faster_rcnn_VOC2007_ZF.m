function script_faster_rcnn_VOC2007_ZF()
% script_faster_rcnn_VOC2007_ZF()
% Faster rcnn training and testing with Zeiler & Fergus model
% --------------------------------------------------------
% Faster R-CNN
% Copyright (c) 2015, Shaoqing Ren
% Licensed under The MIT License [see LICENSE for details]
% --------------------------------------------------------

clc;
clear mex;
clear is_valid_handle; % to clear init_key
run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'startup'));
%% -------------------- CONFIG --------------------
opts.caffe_version          = 'caffe_faster_rcnn';
% opts.gpu_id                 = auto_select_gpu;
opts.gpu_id = 1;
active_caffe_mex(opts.gpu_id, opts.caffe_version);
addpath('./datasets/VOCdevkit2007/VOCdevkit/VOCcode_incremental');
% do validation, or not 
opts.do_val                 = false; 
% model
model                       = Model.ZF_for_Faster_RCNN_VOC2007_reduced;
% cache base
cache_base_proposal         = 'faster_rcnn_VOC2007_ZF';
cache_base_fast_rcnn        = '';
% train/test data
dataset                     = [];
use_flipped                 = false;
removed_classes          = {'cat','chair','cow','diningtable','dog','horse','motorbike','person','pottedplant','sheep','sofa','train','tvmonitor'};
%removed_classes = {};
imdb_cache_name = 'cache';
mkdir(['imdb/' imdb_cache_name]);
dataset                     = Dataset.voc2007_train(dataset, 'trainval', use_flipped, removed_classes, imdb_cache_name);
dataset                     = Dataset.voc2007_test(dataset, 'test', false, removed_classes, imdb_cache_name);
output_dir                  = 'output_VOC2007_20k10k_trainTime';

%% -------------------- TRAIN --------------------
complete_train_time = tic;
% conf
conf_proposal               = proposal_config('image_means', model.mean_image, 'feat_stride', model.feat_stride);
conf_fast_rcnn              = fast_rcnn_config('image_means', model.mean_image);
% set cache folder for each stage
model                       = Faster_RCNN_Train.set_cache_folder(cache_base_proposal, cache_base_fast_rcnn, model);
% generate anchors and pre-calculate output size of rpn network 
[conf_proposal.anchors, conf_proposal.output_width_map, conf_proposal.output_height_map] ...
                            = proposal_prepare_anchors(conf_proposal, model.stage1_rpn.cache_name, model.stage1_rpn.test_net_def_file);

%%  stage one proposal
fprintf('\n***************\nstage one proposal \n***************\n');
% train
model.stage1_rpn            = Faster_RCNN_Train.do_proposal_train(conf_proposal, dataset, model.stage1_rpn, opts.do_val, output_dir);
% test
dataset.roidb_train        	= cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage1_rpn, output_dir, x, y),  dataset.imdb_train, dataset.roidb_train, 'UniformOutput', false);
% dataset.roidb_train        	= cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage1_rpn, x, y), dataset.imdb_train, dataset.roidb_train, 'UniformOutput', false);
% dataset.roidb_test        	= Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage1_rpn, dataset.imdb_test, dataset.roidb_test);

%%  stage one fast rcnn
fprintf('\n***************\nstage one fast rcnn\n***************\n');
% train
model.stage1_fast_rcnn      = Faster_RCNN_Train.do_fast_rcnn_train(conf_fast_rcnn, dataset, model.stage1_fast_rcnn, opts.do_val, output_dir);
% test
% opts.mAP                    = Faster_RCNN_Train.do_fast_rcnn_test(conf_fast_rcnn, model.stage1_fast_rcnn, dataset.imdb_test, dataset.roidb_test);

%%  stage two proposal
% net proposal
fprintf('\n***************\nstage two proposal\n***************\n');
% train
model.stage2_rpn.init_net_file = model.stage1_fast_rcnn.output_model_file;
model.stage2_rpn            = Faster_RCNN_Train.do_proposal_train(conf_proposal, dataset, model.stage2_rpn, opts.do_val, output_dir);
% test
dataset.roidb_train       	= cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn,output_dir, x, y), dataset.imdb_train, dataset.roidb_train, 'UniformOutput', false);
% dataset.roidb_test       	= Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn, dataset.imdb_test, dataset.roidb_test);

%%  stage two fast rcnn
fprintf('\n***************\nstage two fast rcnn\n***************\n');
% train
last_stage = tic;
model.stage2_fast_rcnn.init_net_file = model.stage1_fast_rcnn.output_model_file;
model.stage2_fast_rcnn      = Faster_RCNN_Train.do_fast_rcnn_train(conf_fast_rcnn, dataset, model.stage2_fast_rcnn, opts.do_val, output_dir);

fprintf('time required for complete train models: %f seconds\n', toc(complete_train_time));
fprintf('time required for last stage train models: %f seconds\n', toc(last_stage));

%% final test
fprintf('\n***************\nfinal test\n***************\n');
save('workspaces/ZF_voc_reduced_time');
  %save workspace
model.stage2_rpn.nms        = model.final_test.nms;
if isstruct(dataset.roidb_test)
   tmp_roi = dataset.roidb_test;
   dataset = rmfield(dataset,'roidb_test');
   dataset.roidb_test{1} = tmp_roi;
end
if isstruct(dataset.imdb_test)
   tmp_imdb = dataset.imdb_test;
   dataset = rmfield(dataset,'imdb_test');
   dataset.imdb_test{1} = tmp_imdb;
end
dataset.roidb_test       	= cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn,output_dir, x, y), dataset.imdb_test, dataset.roidb_test, 'UniformOutput', false);
opts.final_mAP              = cellfun(@(x, y) Faster_RCNN_Train.do_fast_rcnn_test(conf_fast_rcnn, model.stage2_fast_rcnn,'output_prova', x, y), dataset.imdb_val, dataset.roidb_val, 'UniformOutput', false);

% save final models, for outside tester
Faster_RCNN_Train.gather_rpn_fast_rcnn_models(conf_proposal, conf_fast_rcnn, model, dataset);
save('workspaces/ZF_voc_reduced_time');
end

function [anchors, output_width_map, output_height_map] = proposal_prepare_anchors(conf, cache_name, test_net_def_file)
    [output_width_map, output_height_map] ...                           
                                = proposal_calc_output_size(conf, test_net_def_file);
    anchors                = proposal_generate_anchors(cache_name, ...
                                    'scales',  2.^[3:5]);
end
