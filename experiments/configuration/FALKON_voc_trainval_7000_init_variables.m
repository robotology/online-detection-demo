%% Add paths for evaluation Pascal Code and for FALKON classifier
addpath('./datasets/VOCdevkit2007/VOCcode_incremental');
addpath(genpath('../FALKON_paper'));

%% Loading workspace 
fprintf('loading training workspace..\n')
load('workspaces/ZF_voc2007train_40k20k.mat');  %---------------------------------------------------------------------------------------------

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

%% Faster and features settings
model.stage2_rpn.nms                  = model.final_test.nms;
model.feature_extraction.binary_file  = model.stage2_fast_rcnn.output_model_file;
model.feature_extraction.net_def_file = model.stage2_fast_rcnn.test_net_def_file;
feature_layer                         = 'fc7';

model.feature_extraction.cache_name = 'features_full_voc2007train_faster_40k20k'; %-----------------------------------------------------

model.classifiers.binary_file = model.feature_extraction.binary_file;
model.classifiers.net_def_file = model.feature_extraction.net_def_file;
model.classifiers.training_opts.cache_name = model.feature_extraction.cache_name;
model.classifiers.classes = dataset.imdb_test{1}.classes;

fprintf('Creating results and output directories...\n');
results_dir = ['results_40k20k_FALKON_voc2007_7000bkg/']; %----------------------------------------------------------------
results_file_name = ['results.txt']; %-----------------------------------------------------------------------------
imdb_val_cache_name = 'cache_full_Pascal07';

boxes_dir = ['cachedir/voc_2007_test_FALKON_7000bkg/']; %------------------------------------------------------------------
bbox_model_suffix = '_full'; %---------------------------------------------------------------------------------------

mkdir(results_dir);
mkdir(boxes_dir);

conf_fast_rcnn.boxes_dir = boxes_dir;


%% Classifier options
fprintf('Classifier options setting...\n');
cls_mode = 'rls_falkon_try'; %---------------------------------------------------------------------------------------------

train_classifier_options = struct;
train_classifier_options.cross_validation = struct;
train_classifier_options.cross_validation.required = true;

negatives_selection.policy = 'from_all';
rebalancing = 'inv_freq';

%FALKON options -----------------------------------------------------------------------------------------------------------
train_classifier_options.cache_dir = '';
train_classifier_options.memToUse = 10;          % GB of memory to use (using "[]" will allow the machine to use all the free memory)
train_classifier_options.useGPU = 1;             % flag for using or not the GPU
