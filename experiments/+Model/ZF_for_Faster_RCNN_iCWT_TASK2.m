function model = ZF_for_Faster_RCNN_iCWT_TASK2(model)

% model.mean_image                                = fullfile(pwd, 'models', 'pre_trained_models', 'ZF', 'mean_image');
model.mean_image                                = fullfile(pwd, 'mean_images', 'icwtTASK1_10objs_train_meanImage');
% model.pre_trained_net_file                      = fullfile(pwd, 'models10', 'pre_trained_models', 'ZF', 'ZF.caffemodel');
% Stride in input image pixels at the last conv layer
model.feat_stride                               = 16;


%% stage 2 rpn, only finetune fc layers
model.stage2_rpn.solver_def_file                = fullfile(pwd, 'models10', 'rpn_prototxts', 'ZF_fc6', 'solver_30k40k.prototxt');
model.stage2_rpn.test_net_def_file              = fullfile(pwd, 'models10', 'rpn_prototxts', 'ZF_fc6', 'test.prototxt');
model.stage2_rpn.output_model_file            = fullfile(pwd, 'output_iCWT_TASK1_10objs_40k20k_newBatchSize/rpn_cachedir/faster_rcnn_ICUB_ZF_top-1_nms0_7_top2000_stage2_rpn/icub_train_TASK1_10objs/', 'final');

% rpn test setting
model.stage2_rpn.nms.per_nms_topN             	= -1;
model.stage2_rpn.nms.nms_overlap_thres       	= 0.7;
model.stage2_rpn.nms.after_nms_topN           	= 2000;

%% stage 2 fast rcnn, only finetune fc layers
model.stage2_fast_rcnn.solver_def_file          = fullfile(pwd, 'models10', 'fast_rcnn_prototxts', 'ZF_fc6', 'solver_15k20k_finetune.prototxt');
model.stage2_fast_rcnn.test_net_def_file        = fullfile(pwd, 'models10', 'fast_rcnn_prototxts', 'ZF_fc6', 'test_finetune.prototxt');
model.stage2_fast_rcnn.init_net_file            = fullfile(pwd, 'output_iCWT_TASK1_10objs_40k20k_newBatchSize/fast_rcnn_cachedir/faster_rcnn_ICUB_ZF_top-1_nms0_7_top2000_stage2_fast_rcnn/icub_train_TASK1_10objs', 'final');

%% final test
model.final_test.nms.per_nms_topN              	= 6000; % to speed up nms
model.final_test.nms.nms_overlap_thres       	= 0.7;
model.final_test.nms.after_nms_topN           	= 1000;

end
