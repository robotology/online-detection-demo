%Load models and imdb
load('workspace_20k10k.mat');
addpath('./datasets/VOCdevkit2007/VOCcode_incremental');

if isstruct(dataset.roidb_test)
   tmp_roi = dataset.roidb_test;
   dataset = rmfield(dataset,'roidb_test');
   dataset.roidb_test{1} = tmp_roi;
end
if isstruct(dataset.roidb_test)
   tmp_imdb = dataset.imdb_test;
   dataset = rmfield(dataset,'imdb_test');
   dataset.imdb_test{1} = tmp_imdb;
end

fprintf('loaded workspace');
cls_mode =  'rls_randBKG';

model.stage2_rpn.nms                  = model.final_test.nms;
model.feature_extraction.binary_file  = model.stage2_fast_rcnn.output_model_file;
model.feature_extraction.net_def_file = model.stage2_fast_rcnn.test_net_def_file;

feature_layer                         = 'fc7';


%cache_name
% negatives_selection.policy = 'from_all';

%GURLS options
train_classifier_options = struct;
train_classifier_options.gurlsOptions = struct;
train_classifier_options.gurlsOptions.kernelfun = 'rbf';
train_classifier_options.cache_dir = 'cache_classifiers/Faster_with_rls/';

% train_classifier_options.gt_regions = 1; %1 = gt regions, 0 = proposals with iou > thresh
% train_classifier_options.subtract_mean = 1; % 1 = feature mean subtraction

% rebalancing = 'inv_freq';
% rebal_alpha = 0.5;


mkdir 'cache_classifiers/Faster_with_rls/';
mkdir 'results/';
model.feature_extraction.cache_name = 'feature_extraction_cache';



model.classifiers.binary_file = model.feature_extraction.binary_file;
model.classifiers.net_def_file = model.feature_extraction.net_def_file;
model.classifiers.training_opts.cache_name = 'feature_extraction_cache';
model.classifiers.classes = dataset.imdb_test{1}.classes;