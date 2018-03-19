%Load models and imdb
load('workspaces/ZF_voc2007train_40k20k.mat');  %---------------------------------------------------------------------------------------------
addpath('./datasets/VOCdevkit2007/VOCcode_incremental');
addpath(genpath('../FALKON_paper'));


results_dir = ['results_40k20k_FALKON_voc2007_trainvalTest_18sigma/']; %----------------------------------------------------------------
results_file_name = ['results.txt'];

boxes_dir = ['cachedir/voc_2007_test_FALKON_trainvalTest_18sigma/']; %------------------------------------------------------------------
bbox_model_suffix = '_full_trainvalTest'; %---------------------------------------------------------------------------------------
reg_mode = 'no_norm';

mkdir(results_dir);
mkdir(boxes_dir);

conf_fast_rcnn.boxes_dir = boxes_dir;
imdb_cache_name = 'cache_trainval_test';
mkdir(['imdb/' imdb_cache_name]);
dataset                     = Dataset.voc2007_test(dataset, 'test', false, {}, imdb_cache_name);
dataset                     = Dataset.voc2007_train(dataset, 'trainval', use_flipped, {}, imdb_cache_name);

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

fprintf('loaded workspace\n');

cls_mode = 'rls_falkon_try_try'; %------------------------------------------------------------------------------------------------------

model.stage2_rpn.nms                  = model.final_test.nms;
model.feature_extraction.binary_file  = model.stage2_fast_rcnn.output_model_file;
model.feature_extraction.net_def_file = model.stage2_fast_rcnn.test_net_def_file;

feature_layer                         = 'fc7';

%FALKON options
fprintf('FALKON options setting\n');
train_classifier_options = struct;
train_classifier_options.cache_dir = '';
train_classifier_options.memToUse = 10;          % GB of memory to use (using "[]" will allow the machine to use all the free memory)
train_classifier_options.useGPU = 1;             % flag for using or not the GPU
train_classifier_options.M = 6000;               % number of Nystrom centers
train_classifier_options.T = 150;                % number of iterations

train_classifier_options.cross_validation = struct;
train_classifier_options.cross_validation.required = true;

negatives_selection.policy = 'from_all';
rebalancing = 'inv_freq';


model.feature_extraction.cache_name = 'features_full_voc2007train_faster_40k20k'; %-----------------------------------------------------

model.classifiers.binary_file = model.feature_extraction.binary_file;
model.classifiers.net_def_file = model.feature_extraction.net_def_file;
model.classifiers.training_opts.cache_name = model.feature_extraction.cache_name;
model.classifiers.classes = dataset.imdb_test{1}.classes;

