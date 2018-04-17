function [  ] = Demo_train_yarp(  )
%DEMO_TRAIN_YARP Summary of this function goes here
%   Detailed explanation goes here

%% -------------------- CONFIG --------------------
yarp_initialization;

configuration_script;

active_caffe_mex(cnn_model.opts.gpu_id, cnn_model.opts.caffe_version);

% cnn model
disp('Loading cnn model paths...');
cnn_model.proposal_detection_model    = load_proposal_detection_model(cnn_model_path);
cnn_model.proposal_detection_model.conf_proposal.test_scales = cnn_model.opts.test_scales;
cnn_model.proposal_detection_model.conf_detection.test_scales = cnn_model.opts.test_scales;
if cnn_model.opts.use_gpu
   cnn_model.proposal_detection_model.conf_proposal.image_means = gpuArray(cnn_model.proposal_detection_model.conf_proposal.image_means);
   cnn_model.proposal_detection_model.conf_detection.image_means = gpuArray(cnn_model.proposal_detection_model.conf_detection.image_means);
end

% proposal net
disp('Setting RPN...');
cnn_model.rpn_net = caffe.Net(cnn_model.proposal_detection_model.proposal_net_def, 'test');
cnn_model.rpn_net.copy_from(cnn_model.proposal_detection_model.proposal_net);
% fast rcnn net
disp('Setting Fast R-CNN...');
cnn_model.fast_rcnn_net = caffe.Net(cnn_model.proposal_detection_model.detection_net_def, 'test');
cnn_model.fast_rcnn_net.copy_from(cnn_model.proposal_detection_model.detection_net);

% set gpu/cpu
if cnn_model.opts.use_gpu
    caffe.set_mode_gpu();
else
    caffe.set_mode_cpu();
end   

%% -------------------- START TRAIN--------------------

h=480;
w=640;
pixSize=3;
tool=yarp.matlab.YarpImageHelper(h, w);
% Set the number of negative regions per image to pick
negatives_selection.batch_size        = 1500;
negatives_selection.iterations        = 10;
max_per_class                         = 1500;
total_negatives = negatives_selection.batch_size*negatives_selection.iterations;
if total_negatives > max_img_per_class
    neg_per_image = total_negatives/max_img_per_class;
else
    neg_per_image = 1;
end

%% Load old dataset if there is any
try
    %TO-DO-----------------------------------------------------------------------------------------------
catch
    %TO-DO-----------------------------------------------------------------------------------------------
end

for i=1:length(classes)
    curr_instances = 0;
    curr_negative_number = 0;
    pos_region_classifier = [];
    neg_region_classifier = [];
    pos_bbox_regressor = [];
    while curr_instances < max_img_per_class
        
        %% Receive image and annotation
        im = receive_image(); %TO-DO---------------------------------------------------------------------
        annotation = readFromPort(); %TO-DO--------------------------------------------------------------
        
        %% Extract regions from image and filtering
        regions_tic = tic;

        % test proposal
        [boxes, scores]             = proposal_im_detect(cnn_model.proposal_detection_model.conf_proposal, cnn_model.rpn_net, im);
        aboxes                      = boxes_filter([boxes, scores], cnn_model.opts.per_nms_topN, cnn_model.opts.nms_overlap_thres, ...
                                                    cnn_model.opts.after_nms_topN, cnn_model.opts.use_gpu);
        fprintf('--Region proposal prediction required %f seconds\n', toc(regions_tic));
        
        %% Select postive regions
        % Positive regions for bounding box regressor
        pos_bbox_regressor = select_positives_for_bbox(); %TO-DO-----------------------------------------
        % Positive regions for region classifier
        curr_cls_pos = select_postives(); %TO-DO---------------------------------------------------------
        pos_region_classifier = cat(1, pos_region_classifier, curr_cls_pos);
                
        %% Select negative samples for region classifier
        if curr_negative_number < total_negatives
            curr_cls_neg = select_negatives(); % TO-DO---------------------------------------------------
            neg_region_classifier = cat(1, neg_region_classifier, curr_cls_neg);
            curr_negative_number = curr_negative_number+1;
        end
        
        %% Extract features from regions
        features             = cnn_features_demo(cnn_model.proposal_detection_model.conf_detection, im, aboxes(:, 1:4), ...
                                                   cnn_model.fast_rcnn_net, [], 'fc7');  
        curr_instances = curr_instances +1;
    end
    
    %% Train region classifier
     
    %% Train Bounding box regressors
    
    %% Save dataset
    
end
end

