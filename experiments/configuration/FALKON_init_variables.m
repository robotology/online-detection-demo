%Load models and imdb
load('workspace_20k10k.mat');
addpath('./datasets/VOCdevkit2007/VOCcode_incremental');

cls_dir = ['cache_classifiers/Faster_with_FALKON_' int2str(bkg_numbs) '/'];
results_dir = ['results_20k15k_FALKON_' int2str(bkg_numbs) '/'];
boxes_dir = ['cachedir/voc_2007_test_FALKON_' int2str(bkg_numbs) '/'];
bbox_model_suffix = '_full';


mkdir(cls_dir);
mkdir(results_dir);

conf_fast_rcnn.boxes_dir = boxes_dir;

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

fprintf('loaded workspace\n');
cls_mode = 'rls_falkon';

model.stage2_rpn.nms                  = model.final_test.nms;
model.feature_extraction.binary_file  = model.stage2_fast_rcnn.output_model_file;
model.feature_extraction.net_def_file = model.stage2_fast_rcnn.test_net_def_file;

feature_layer                         = 'fc7';

%FALKON options
addpath(genpath('../FALKON_paper'));
fprintf('FALKON options setting\n');
train_classifier_options = struct;
train_classifier_options.cache_dir = cls_dir;
train_classifier_options.memToUse = 10;          % GB of memory to use (using "[]" will allow the machine to use all the free memory)
train_classifier_options.useGPU = 1;             % flag for using or not the GPU
train_classifier_options.N_centres = 5000;       % number of Nystrom centers

train_classifier_options.T = 35;                 %number of iterations


model.feature_extraction.cache_name = 'feature_extraction_cache';

model.classifiers.binary_file = model.feature_extraction.binary_file;
model.classifiers.net_def_file = model.feature_extraction.net_def_file;
model.classifiers.training_opts.cache_name = 'feature_extraction_cache';
model.classifiers.classes = dataset.imdb_test{1}.classes;

