%% Add paths for evaluation Pascal Code and for FALKON classifier
addpath('./datasets/VOCdevkit2007/VOCcode_incremental');
addpath(genpath('../FALKON_paper'));

%% Loading workspace 
fprintf('loading training workspace..\n')
load('workspaces/ZF_voc2007_TASK1');  %---------------------------------------------------------------------------------------------

%% Dataset TASK2
dataset.TASK2 = [];
fprintf('Dataset preparing for task 2...\n');
% all_classes = {'aeroplane', 'bicycle', 'bird', 'boat', 'bottle', 'bus', 'car', 'cat', 'chair', 'cow', 'diningtable','dog','horse','motorbike','person','pottedplant','sheep','sofa','train','tvmonitor'};
removed_classes_T2 = {'aeroplane', 'bicycle', 'bird', 'boat', 'bottle', 'bus', 'car', 'cat', 'chair', 'cow'};

imdb_cache_name = 'cache_voc2007_TASK2';
mkdir(['imdb/' imdb_cache_name]);
dataset.TASK2                     = Dataset.voc2007_train(dataset.TASK2, 'train', use_flipped, removed_classes_T2, imdb_cache_name);
dataset.TASK2                     = Dataset.voc2007_test(dataset.TASK2, 'test', false, removed_classes_T2, imdb_cache_name);
TASK2_proposals_suffix = '_TASK2';
fprintf('Test set format preparing...\n');

if isstruct(dataset.TASK2.roidb_test)
   tmp_roi = dataset.TASK2.roidb_test;
   dataset.TASK2 = rmfield(dataset.TASK2,'roidb_test');
   dataset.TASK2.roidb_test{1} = tmp_roi;
   clear tmp_roi;
end
if isstruct(dataset.TASK2.imdb_test)
   tmp_imdb = dataset.TASK2.imdb_test;
   dataset.TASK2 = rmfield(dataset.TASK2,'imdb_test');
   dataset.TASK2.imdb_test{1} = tmp_imdb;
   clear tmp_imdb
end

%% Faster and features settings
model.stage2_rpn.nms                  = model.final_test.nms;
model.feature_extraction.binary_file  = model.stage2_fast_rcnn.output_model_file;
model.feature_extraction.net_def_file = model.stage2_fast_rcnn.test_net_def_file;
feature_layer                         = 'fc7';

model.feature_extraction.cache_name = 'TASK1features_voc2007_for_TASK2'; %-----------------------------------------------------

model.classifiers.binary_file = model.feature_extraction.binary_file;
model.classifiers.net_def_file = model.feature_extraction.net_def_file;
model.classifiers.training_opts.cache_name = model.feature_extraction.cache_name;
model.classifiers.classes = dataset.TASK2.imdb_test{1}.classes;

fprintf('Creating results and output directories...\n');
results_dir = ['results_TASK1_FALKON_voc2007_7000bkg_for_TASK2/']; %----------------------------------------------------------------
results_file_name = ['results.txt'];
imdb_val_cache_name = imdb_cache_name; %-------------------------------------------------------------------------------------------

boxes_dir = ['cachedir/voc_2007_test_FALKON_7000bkg_TASK2/']; %------------------------------------------------------------------
bbox_model_suffix = '_TASK2'; %---------------------------------------------------------------------------------------

mkdir(results_dir);
mkdir(boxes_dir);

conf_fast_rcnn.boxes_dir = boxes_dir;


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
train_classifier_options.T= iterations;
