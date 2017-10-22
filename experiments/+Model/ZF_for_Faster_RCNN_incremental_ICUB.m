function model = ZF_for_Faster_RCNN_ICUB(model)

model.mean_image                                = fullfile(pwd, 'models', 'pre_trained_models', 'ZF', 'mean_image');
model.pre_trained_net_file                      = fullfile(pwd, 'models', 'pre_trained_models', 'ZF', 'ZF.caffemodel');
% Stride in input image pixels at the last conv layer
model.feat_stride                               = 16;

%% stage 1 rpn, inited from pre-trained network
model.stage1_rpn.solver_def_file                = fullfile(pwd, 'models', 'rpn_prototxts', 'ZF', 'solver_40k40k.prototxt');
model.stage1_rpn.test_net_def_file              = fullfile(pwd, 'models', 'rpn_prototxts', 'ZF', 'test.prototxt');
model.stage1_rpn.init_net_file                  = model.pre_trained_net_file;

% rpn test setting
model.stage1_rpn.nms.per_nms_topN             	= -1;
model.stage1_rpn.nms.nms_overlap_thres       	= 0.7;
model.stage1_rpn.nms.after_nms_topN          	= 2000;

%% stage 1 fast rcnn, inited from pre-trained network
model.stage1_fast_rcnn.solver_def_file          = fullfile(pwd, 'models', 'fast_rcnn_prototxts', 'ZF', 'solver_14k14k.prototxt');
model.stage1_fast_rcnn.test_net_def_file        = fullfile(pwd, 'models', 'fast_rcnn_prototxts', 'ZF', 'test.prototxt');
model.stage1_fast_rcnn.init_net_file            = model.pre_trained_net_file;

%% stage 2 rpn, only finetune fc layers
model.stage2_rpn.solver_def_file                = fullfile(pwd, 'models', 'rpn_prototxts', 'ZF_fc6', 'solver_40k40k.prototxt');
model.stage2_rpn.test_net_def_file              = fullfile(pwd, 'models', 'rpn_prototxts', 'ZF_fc6', 'test.prototxt');

% rpn test setting
model.stage2_rpn.nms.per_nms_topN             	= -1;
model.stage2_rpn.nms.nms_overlap_thres       	= 0.7;
model.stage2_rpn.nms.after_nms_topN           	= 2000;

%% stage 2 fast rcnn, only finetune fc layers
model.stage2_fast_rcnn.solver_def_file          = fullfile(pwd, 'models', 'fast_rcnn_prototxts', 'ZF_fc6', 'solver_14k14k.prototxt');
model.stage2_fast_rcnn.test_net_def_file        = fullfile(pwd, 'models', 'fast_rcnn_prototxts', 'ZF_fc6', 'test.prototxt');

%% feature extraction

model.feature_extraction.cache_name                 = 'feature_extraction_cache';
% model.feature_extraction.net_def_file             = model.feature_extraction.fast_rcnn.solver_def_file;
model.feature_extraction.rpn.nms.per_nms_topN       = 6000; % to speed up nms
model.feature_extraction.rpn.nms.nms_overlap_thres  = 0.7;
model.feature_extraction.rpn.nms.after_nms_topN     = 1000;
model.feature_extraction.rpn.cache_name             = 'feature_extraction_region_cache';
model.feature_extraction.rpn.solver_def_file        = model.stage2_rpn.test_net_def_file;

%% rls train setting



%% final test
model.final_test.nms.per_nms_topN              	= 6000; % to speed up nms
model.final_test.nms.nms_overlap_thres       	= 0.7;
model.final_test.nms.after_nms_topN           	= 1000;
end
