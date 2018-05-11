%% Add paths for evaluation Pascal Code and for FALKON classifier
addpath('./datasets/VOCdevkit2007/VOCdevkit/VOCcode_incremental');
addpath(genpath('../FALKON_paper'));

%% Loading workspace 
%fprintf('loading training workspace..\n')
%load('workspaces/ZF_iCWT_TASK1');  %---------------------------------------------------------------------------------------------
%% Loading
%cnn_model_dir                = 'output_VOC2007_ZF';
ld                       = load(fullfile([cnn_model_dir '/faster_rcnn_final/faster_rcnn_ICUB_ZF' ], 'model'));
proposal_detection_model = ld.proposal_detection_model;
clear ld;

proposal_detection_model.proposal_net_def  = fullfile([cnn_model_dir '/faster_rcnn_final/faster_rcnn_ICUB_ZF' ], proposal_detection_model.proposal_net_def);
proposal_detection_model.proposal_net      = fullfile([cnn_model_dir '/faster_rcnn_final/faster_rcnn_ICUB_ZF' ], proposal_detection_model.proposal_net);
proposal_detection_model.detection_net_def = fullfile([cnn_model_dir '/faster_rcnn_final/faster_rcnn_ICUB_ZF' ], proposal_detection_model.detection_net_def);
proposal_detection_model.detection_net     = fullfile([cnn_model_dir '/faster_rcnn_final/faster_rcnn_ICUB_ZF' ], proposal_detection_model.detection_net);

%% Dataset TASK2
dataset.TASK2 = [];
fprintf('Dataset preparing for task 2...\n');  %---------------------------------------------------------------------------------------------
dataset_path       = '/home/IIT.LOCAL/emaiettini/workspace/Datasets/Demo_data';
chosen_classes_T2  = {'sodabottle', 'mug', 'flower', 'sprayer', 'toy'};
              
imdb_cache_name    = 'cache_dump_for_exp_demo_5objs_voc'; %---------------------------------------------------------------------------------------------
train_imagest_name = 'train_for_exp_demo_5objs'; %---------------------------------------------------------------------------------------------
test_imagest_name  = 'test_for_exp_demo_5objs'; %---------------------------------------------------------------------------------------------
% val_imageset_name = 'val_TASK2_10objs'; %---------------------------------------------------------------------------------------------
mkdir(['imdb/' imdb_cache_name]);

dataset.TASK2 = Dataset.general_dataset(dataset.TASK2, 'train', 0, imdb_cache_name, train_imagest_name, chosen_classes_T2, dataset_path);
dataset.TASK2 = Dataset.general_dataset(dataset.TASK2, 'test', false, imdb_cache_name, test_imagest_name, chosen_classes_T2, dataset_path);

dataset.TASK2.imdb_train{1}.removed_classes = {};
dataset.TASK2.imdb_test{1}.removed_classes  = {};

TASK2_proposals_suffix = '_TASK2_exp_for_demo_voc_features_real';  %---------------------------------------------------------------------------------------------

fprintf('Test set format preparing...\n');
if isstruct(dataset.TASK2.roidb_test)
   tmp_roi                     = dataset.TASK2.roidb_test;
   dataset.TASK2               = rmfield(dataset.TASK2,'roidb_test');
   dataset.TASK2.roidb_test{1} = tmp_roi;
   clear tmp_roi;
end
if isstruct(dataset.TASK2.imdb_test)
   tmp_imdb                    = dataset.TASK2.imdb_test;
   dataset.TASK2               = rmfield(dataset.TASK2,'imdb_test');
   dataset.TASK2.imdb_test{1}  = tmp_imdb;
   clear tmp_imdb
end

%% Faster and features settings
model.stage2_rpn.output_model_file               = proposal_detection_model.proposal_net;     % TO CHECK
model.stage2_rpn.test_net_def_file               = proposal_detection_model.proposal_net_def; % TO CHECK  
model.stage2_rpn.cache_name                      = 'cache_rpn_vocF';
model.stage2_rpn.nms.per_nms_topN                = 6000; % to speed up nms
model.stage2_rpn.nms.nms_overlap_thres        	 = 0.7;

model.feature_extraction.binary_file       = proposal_detection_model.detection_net;     % TO CHECK
model.feature_extraction.net_def_file      = proposal_detection_model.detection_net_def; % TO CHECK
feature_layer                              = 'fc7';

model.feature_extraction.cache_name        = 'VOCfeatures_for_exp_demo_5objs_real'; %-----------------------------------------------------

model.classifiers.binary_file              = model.feature_extraction.binary_file;
model.classifiers.net_def_file             = model.feature_extraction.net_def_file;
model.classifiers.training_opts.cache_name = model.feature_extraction.cache_name;
model.classifiers.classes                  = dataset.TASK2.imdb_test{1}.classes;

conf_proposal  = proposal_detection_model.conf_proposal;
conf_fast_rcnn = proposal_detection_model.conf_detection;



fprintf('Creating results and output directories...\n');
results_dir         = ['results_vocFeatures_FALKON_for_exp_demo_5objs_real/']; %---------------
results_file_name   = ['results.txt'];       %unused
imdb_val_cache_name = imdb_cache_name;       %------------------------------------------------------------------

boxes_dir           = ['cachedir/test_voc/'];    %-----------------------------------------------------------------
bbox_model_suffix   = '_for_exp_demo_5objs_voc_features'; %-----------------------------------------------------------------

mkdir(results_dir);
mkdir(boxes_dir);

conf_fast_rcnn.boxes_dir = boxes_dir;


%% Classifier options
fprintf('Classifier options setting...\n');
cls_mode = 'rls_falkon_miniBootstrap_demo'; %---------------------------------------------------------------------------------------------

train_classifier_options                           = struct;
train_classifier_options.cross_validation          = struct;
train_classifier_options.cross_validation.required = true;

negatives_selection.policy     = 'bootStrap';
negatives_selection.btstr_size = 1500;
negatives_selection.iterations = 10;
rebalancing                    = 'inv_freq';

%FALKON options -----------------------------------------------------------------------------------------------------------
train_classifier_options.cache_dir = '';
train_classifier_options.memToUse  = 10;          % GB of memory to use (using "[]" will allow the machine to use all the free memory)
train_classifier_options.useGPU    = 1;             % flag for using or not the GPU
train_classifier_options.T         = 150;
