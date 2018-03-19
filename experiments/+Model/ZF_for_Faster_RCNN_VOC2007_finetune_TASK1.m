function model = ZF_for_Faster_RCNN_VOC2007_finetune_TASK1(model)

% model.mean_image                                = fullfile(pwd, 'models', 'pre_trained_models', 'ZF', 'mean_image');
model.mean_image                                = fullfile(pwd, 'mean_images', 'voc2007_train_meanImage');
% model.pre_trained_net_file                      = fullfile(pwd, 'models10', 'pre_trained_models', 'ZF', 'ZF.caffemodel');
% Stride in input image pixels at the last conv layer
model.feat_stride                               = 16;

%% stage 1 rpn, inited from pre-trained network
% model.stage1_rpn.solver_def_file                = fullfile(pwd, 'models10', 'rpn_prototxts', 'ZF', 'solver_18k24k.prototxt');
% model.stage1_rpn.test_net_def_file              = fullfile(pwd, 'models10', 'rpn_prototxts', 'ZF', 'test.prototxt');
% model.stage1_rpn.init_net_file                  = model.pre_trained_net_file;
% 
% % rpn test setting
% model.stage1_rpn.nms.per_nms_topN              	= -1;
% model.stage1_rpn.nms.nms_overlap_thres        	= 0.7;
% model.stage1_rpn.nms.after_nms_topN           	= 2000;
% 
% %% stage 1 fast rcnn, inited from pre-trained network
% model.stage1_fast_rcnn.solver_def_file          = fullfile(pwd, 'models10', 'fast_rcnn_prototxts', 'ZF', 'solver_9k12k.prototxt');
% model.stage1_fast_rcnn.test_net_def_file        = fullfile(pwd, 'models10', 'fast_rcnn_prototxts', 'ZF', 'test.prototxt');
% model.stage1_fast_rcnn.init_net_file            = model.pre_trained_net_file;

%% stage 2 rpn, only finetune fc layers
model.stage2_rpn.solver_def_file                = fullfile(pwd, 'models10', 'rpn_prototxts', 'ZF_fc6', 'solver_18k24k.prototxt');
model.stage2_rpn.test_net_def_file              = fullfile(pwd, 'models10', 'rpn_prototxts', 'ZF_fc6', 'test.prototxt');
model.stage2_rpn.output_model_file              = fullfile(pwd, 'output_VOC2007_TASK1/rpn_cachedir/faster_rcnn_VOC2007_ZF_top-1_nms0_7_top2000_stage2_rpn/voc_2007_train', 'final');

% rpn test setting
model.stage2_rpn.nms.per_nms_topN             	= -1;
model.stage2_rpn.nms.nms_overlap_thres       	= 0.7;
model.stage2_rpn.nms.after_nms_topN           	= 2000;

%% stage 2 fast rcnn, only finetune fc layers
model.stage2_fast_rcnn.solver_def_file          = fullfile(pwd, 'models10', 'fast_rcnn_prototxts', 'ZF_fc6', 'solver_9k12k_TASK2.prototxt');
model.stage2_fast_rcnn.test_net_def_file        = fullfile(pwd, 'models10', 'fast_rcnn_prototxts', 'ZF_fc6', 'test_TASK2.prototxt');
model.stage2_fast_rcnn.init_net_file            = fullfile(pwd, 'output_VOC2007_TASK1/fast_rcnn_cachedir/faster_rcnn_VOC2007_ZF_top-1_nms0_7_top2000_stage2_fast_rcnn/voc_2007_train', 'final');
%% final test
model.final_test.nms.per_nms_topN            	= 6000; % to speed up nms
model.final_test.nms.nms_overlap_thres       	= 0.7;
model.final_test.nms.after_nms_topN          	= 1000;
end
