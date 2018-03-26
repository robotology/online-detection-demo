%% TRAIN OPTIONS


%% PATHS
current_path = pwd;
classes = importdata([current_path '/Demo/Conf/Classes.txt' ]);
cls_model_path = [current_path '/Demo/Models/classifier' ];
bbox_model_path = [current_path '/Demo/Models/bbox_ref' ];
dataset_path = [current_path '/datasets/iCubWorld-Transformations/'];

%% FILES
image_set = 'test_TASK1_10objs';

%% CAFFE
cnn_model.opts.caffe_version          = 'caffe_faster_rcnn';
cnn_model.opts.gpu_id                 = 1;

%% DETECTION PARAMS
cnn_model.opts.per_nms_topN           = 6000;
cnn_model.opts.nms_overlap_thres      = 0.7;
cnn_model.opts.after_nms_topN         = 300;
cnn_model.opts.use_gpu                = true;

cnn_model.opts.test_scales            = 600;
detect_thresh                         = 0.5;

