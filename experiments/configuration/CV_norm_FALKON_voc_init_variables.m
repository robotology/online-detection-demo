%% Add paths for evaluation Pascal Code and for FALKON classifier
addpath('./datasets/VOCdevkit2007/VOCcode_incremental');
addpath(genpath('../FALKON_paper'));

%% Faster and features settings
fprintf('loading training workspace..\n')
load('workspace_20k10k'); %---------------------------------------------------------------------------------------------

model.stage2_rpn.nms                  = model.final_test.nms;
model.feature_extraction.binary_file  = model.stage2_fast_rcnn.output_model_file;
model.feature_extraction.net_def_file = model.stage2_fast_rcnn.test_net_def_file;
feature_layer                         = 'fc7';

model.feature_extraction.cache_name = 'feature_extraction_cache'; %-----------------------------------------------------

model.classifiers.binary_file = model.feature_extraction.binary_file;
model.classifiers.net_def_file = model.feature_extraction.net_def_file;
model.classifiers.training_opts.cache_name = model.feature_extraction.cache_name;
model.classifiers.classes = dataset.imdb_test{1}.classes;

fprintf('Creating results and output directories...\n');
results_dir = ['results_20k10k_FALKON_voc2007_CV_norm_target/']; %----------------------------------------------------------------
results_file_name = ['CV_norm_target.txt']; %-----------------------------------------------------------------------------

boxes_dir = ['cachedir/voc_2007_test_FALKON_CV_norm_target/']; %------------------------------------------------------------------
bbox_model_suffix = '_reduced'; %---------------------------------------------------------------------------------------

mkdir(results_dir);
mkdir(boxes_dir);

conf_fast_rcnn.boxes_dir = boxes_dir;

%% Dataset format
fprintf('Dataset format preparing...\n');

if isstruct(dataset.roidb_test)
   tmp_roi = dataset.roidb_test;
   dataset = rmfield(dataset,'roidb_test');
   dataset.roidb_test{1} = tmp_roi;
   clear tmp_roi;
end
if isstruct(dataset.imdb_test)
   tmp_imdb = dataset.imdb_test;
   dataset = rmfield(dataset,'imdb_test');
   dataset.imdb_test{1} = tmp_imdb;
   clear tmp_imdb
end


%% Classifier options
fprintf('Classifier options setting...\n');
cls_mode = 'rls_falkon_try_try'; %---------------------------------------------------------------------------------------------

train_classifier_options = struct;
train_classifier_options.cross_validation = struct;
train_classifier_options.cross_validation.required = true;

negatives_selection.policy = 'from_all';
rebalancing = 'inv_freq';

%FALKON options -----------------------------------------------------------------------------------------------------------
train_classifier_options.cache_dir = '';
train_classifier_options.memToUse = 10;          % GB of memory to use (using "[]" will allow the machine to use all the free memory)
train_classifier_options.useGPU = 1;             % flag for using or not the GPU
%train_classifier_options.N_centres = 5000;       % number of Nystrom centers
% train_classifier_options.T = 35;                 %number of iterations

