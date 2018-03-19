function script_faster_rcnn_iCWT_ZF_finetune()

clc;
clear mex;
clear is_valid_handle; % to clear init_key
run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'startup'));
%% -------------------- CONFIG --------------------
opts.caffe_version          = 'caffe_faster_rcnn';
opts.gpu_id = 1;
active_caffe_mex(opts.gpu_id, opts.caffe_version);
addpath('./datasets/VOCdevkit2007/VOCcode_incremental');
% do validation, or not 
opts.do_val                 = false; 
% model
model                       = Model.ZF_for_Faster_RCNN_iCWT_finetune;
% cache base
cache_base_proposal         = 'faster_rcnn_VOC2007_ZF';
cache_base_fast_rcnn        = '';
% train/test data
dataset                     = [];
dataset.TASK1 = [];
use_flipped                 = false;
removed_classes = {};
chosen_classes_T1 = {'cellphone1','cellphone2', 'mouse2', 'mouse5', 'perfume1', 'perfume4', ...
                  'remote4', 'remote5', 'soapdispenser1', 'soapdispenser4', 'sunglasses4', ...
                  'sunglasses5',  'glass6', 'glass8', 'hairbrush1', 'hairbrush4', 'ovenglove1', ...
                  'ovenglove7', 'squeezer5', 'squeezer8'};

% removed_classes_T2 = {'aeroplane', 'bicycle', 'bird', 'boat', 'bottle', 'bus', 'car', 'cat', 'chair', 'cow'};

imdb_cache_name = 'cache_icub_T1';
mkdir(['imdb/' imdb_cache_name]);
dataset.TASK1                     = Dataset.icub_dataset(dataset.TASK1, 'train', use_flipped, imdb_cache_name, 'train_TASK1_20objs', chosen_classes_T1);
dataset.TASK1                     = Dataset.icub_dataset(dataset.TASK1, 'test', false, imdb_cache_name, 'test_TASK1_20objs', chosen_classes_T1);
dataset.TASK1.imdb_test{1}.removed_classes = removed_classes;
output_dir                        = 'output_VOC2007_finetune_icub_T1';

%% -------------------- TRAIN --------------------
% conf
conf_proposal               = proposal_config('image_means', model.mean_image, 'feat_stride', model.feat_stride);
conf_fast_rcnn              = fast_rcnn_config('image_means', model.mean_image);
% set cache folder for each stage
model                       = Faster_RCNN_Train.set_cache_folder_finetune(cache_base_proposal, cache_base_fast_rcnn, model);
% generate anchors and pre-calculate output size of rpn network 
[conf_proposal.anchors, conf_proposal.output_width_map, conf_proposal.output_height_map] ...
                            = proposal_prepare_anchors(conf_proposal, model.stage2_rpn.cache_name, model.stage2_rpn.test_net_def_file);


%%  stage two fast rcnn
fprintf('\n***************\nstage two fast rcnn\n***************\n');
% train
%Extracting regions from train-set TASK1 using features from task 1
dataset.TASK1.roidb_train       	= cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn,output_dir, x, y), dataset.TASK1.imdb_train, dataset.TASK1.roidb_train, 'UniformOutput', false);

% model.stage2_fast_rcnn.init_net_file = model.stage1_fast_rcnn.output_model_file;
model.stage2_fast_rcnn      = Faster_RCNN_Train.do_fast_rcnn_train_finetune(conf_fast_rcnn, dataset.TASK1, model.stage2_fast_rcnn, opts.do_val, output_dir);

%% final test
fprintf('\n***************\nfinal test\n***************\n');
model.stage2_rpn.nms        = model.final_test.nms;
fprintf('saving workspace...');
% load('workspaces/ZF_icwt_finetune_on_T1');

%fprintf('saving models...');
%Faster_RCNN_Train.gather_rpn_fast_rcnn_models(conf_proposal, conf_fast_rcnn, model, dataset.TASK1);

if isstruct(dataset.TASK1.roidb_test)
   tmp_roi = dataset.TASK1.roidb_test;
   dataset.TASK1 = rmfield(dataset.TASK1,'roidb_test');
   dataset.TASK1.roidb_test{1} = tmp_roi;
end
if isstruct(dcd w   ataset.TASK1.imdb_test)
   tmp_imdb = dataset.TASK1.imdb_test;
   dataset.TASK1 = rmfield(dataset.TASK1,'imdb_test');
   dataset.TASK1.imdb_test{1} = tmp_imdb;
end
dataset.TASK1.roidb_test       	= cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn,output_dir, x, y), dataset.TASK1.imdb_test, dataset.TASK1.roidb_test, 'UniformOutput', false);
opts.final_mAP                  = cellfun(@(x, y) Faster_RCNN_Train.do_fast_rcnn_test(conf_fast_rcnn, model.stage2_fast_rcnn,output_dir, x, y), dataset.TASK1.imdb_test, dataset.TASK1.roidb_test, 'UniformOutput', false);
save('workspaces/ZF_icwt_finetune_on_T1');


end

function [anchors, output_width_map, output_height_map] = proposal_prepare_anchors(conf, cache_name, test_net_def_file)
    [output_width_map, output_height_map] ...                           
                                = proposal_calc_output_size(conf, test_net_def_file);
    anchors                = proposal_generate_anchors(cache_name, ...
                                    'scales',  2.^[3:5]);
end
