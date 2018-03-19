function script_faster_rcnn_iCWT_ZF_fromT1_forT2()
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
model                       = Model.ZF_for_Faster_RCNN_iCWT_TASK2;
% cache base
cache_base_proposal         = 'faster_rcnn_VOC2007_ZF';
cache_base_fast_rcnn        = '';
% train/test data
dataset                     = [];
dataset.TASK1 = [];
use_flipped                 = false;

removed_classes = {};
chosen_classes_T1 = {'sodabottle2', 'mug1', 'pencilcase5', 'ringbinder4', 'wallet6', 'flower7', 'book6', 'bodylotion8', 'hairclip2', 'sprayer6'};

imdb_cache_name = 'cache_iCWT_TASK2_10objs';
mkdir(['imdb/' imdb_cache_name]);
dataset.TASK1                     = Dataset.icub_dataset(dataset.TASK1, 'train', use_flipped, imdb_cache_name, 'train_TASK2_10objs', chosen_classes_T1);
dataset.TASK1                     = Dataset.icub_dataset(dataset.TASK1, 'test', false, imdb_cache_name, 'test_TASK2_10objs', chosen_classes_T1);
dataset.TASK1.imdb_test{1}.removed_classes = removed_classes;
output_dir                        = 'output_iCWT_TASK2_finetune';

%% -------------------- TRAIN --------------------
% conf
conf_proposal               = proposal_config('image_means', model.mean_image, 'feat_stride', model.feat_stride);
conf_fast_rcnn              = fast_rcnn_config('image_means', model.mean_image);
% set cache folder for each stage
model                       = Faster_RCNN_Train.set_cache_folder_finetune(cache_base_proposal, cache_base_fast_rcnn, model);
% generate anchors and pre-calculate output size of rpn network 
[conf_proposal.anchors, conf_proposal.output_width_map, conf_proposal.output_height_map] ...
                            = proposal_prepare_anchors(conf_proposal,  model.stage2_rpn.cache_name, model.stage2_rpn.test_net_def_file)

model.stage2_rpn.nms        = model.final_test.nms;
dataset.TASK1.roidb_train       	= cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn,output_dir, x, y), dataset.TASK1.imdb_train, dataset.TASK1.roidb_train, 'UniformOutput', false);

%%  stage two fast rcnn
fprintf('\n***************\nstage two fast rcnn\n***************\n');
% train
model.stage2_fast_rcnn      = Faster_RCNN_Train.do_fast_rcnn_train_finetune(conf_fast_rcnn, dataset.TASK1, model.stage2_fast_rcnn, opts.do_val, output_dir);

%% final test
fprintf('\n***************\nfinal test\n***************\n');
model.stage2_rpn.nms        = model.final_test.nms;
fprintf('saving workspace...');
save('workspaces/ZF_voc2007_TASK2_finetune');

%fprintf('saving models...');
%Faster_RCNN_Train.gather_rpn_fast_rcnn_models(conf_proposal, conf_fast_rcnn, model, dataset.TASK1);


  %save workspace
if isstruct(dataset.TASK1.roidb_test)
   tmp_roi = dataset.TASK1.roidb_test;
   dataset.TASK1 = rmfield(dataset.TASK1,'roidb_test');
   dataset.TASK1.roidb_test{1} = tmp_roi;
end
if isstruct(dataset.TASK1.imdb_test)
   tmp_imdb = dataset.TASK1.imdb_test;
   dataset.TASK1 = rmfield(dataset.TASK1,'imdb_test');
   dataset.TASK1.imdb_test{1} = tmp_imdb;
end
dataset.TASK1.roidb_test       	= cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn,output_dir, x, y), dataset.TASK1.imdb_test, dataset.TASK1.roidb_test, 'UniformOutput', false);
opts.final_mAP                  = cellfun(@(x, y) Faster_RCNN_Train.do_fast_rcnn_test(conf_fast_rcnn, model.stage2_fast_rcnn,output_dir, x, y), dataset.TASK1.imdb_test, dataset.TASK1.roidb_test, 'UniformOutput', false);
save('workspaces/ZF_voc2007_TASK2_finetune');




% save final models, for outside tester
%Faster_RCNN_Train.gather_rpn_fast_rcnn_models(conf_proposal, conf_fast_rcnn, model, dataset);
%save('workspaces/ZF_voc2007train_40k20k');
end

function [anchors, output_width_map, output_height_map] = proposal_prepare_anchors(conf, cache_name, test_net_def_file)
    [output_width_map, output_height_map] ...                           
                                = proposal_calc_output_size(conf, test_net_def_file);
    anchors                = proposal_generate_anchors(cache_name, ...
                                    'scales',  2.^[3:5]);
end
