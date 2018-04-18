function [  ] = Demo_train_yarp(  )
%DEMO_TRAIN_YARP Summary of this function goes here
%   Detailed explanation goes here

%% -------------------- CONFIG --------------------
yarp_initialization_train;

configuration_script_train;

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
total_negatives = negatives_selection.batch_size*negatives_selection.iterations;
if total_negatives > max_img_per_class
    neg_per_image = total_negatives/max_img_per_class;
else
    neg_per_image = 1;
end

%% Load old dataset if there is any
try
    dataset = struct;%TO-DO-----------------------------------------------------------------------------------------------
    dataset.bbox_regressor = cell(0);
    dataset.reg_classifier = cell(0);
catch
    dataset = struct;
    dataset.bbox_regressor = cell(0);
    dataset.reg_classifier = cell(0);
end

for i=1:length(classes)
    curr_instances = 0;
    curr_negative_number = 0;
    
    pos_region_classifier = struct;
    neg_region_classifier = struct;
    
    pos_bbox_regressor = struct;
    y_bbox_regressor = [];
    total_tic = tic;
    while curr_instances < max_img_per_class
        %% Receive image and annotation
        fetch_tic = tic;
        disp('Waiting image from port...');
      
        yarpImage   = portImage.read(true);                           % get the yarp image from port
        annotations = portAnnotation.read(true);                      % get the annotation from port
        if (sum(size(yarpImage)) ~= 0 && annotations.size() ~= 0)     % check size of bottle 

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%% NEED FOR A TSTAMP CHECK %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      
            % Gathering mat image and gpuarray
            TEST = reshape(tool.getRawImg(yarpImage), [h w pixSize]); % need to reshape the matrix from 1D to h w pixelSize       
            im=uint8(zeros(h, w, pixSize));                           % create an empty image with the correct dimentions
            im(:,:,1)= cast(TEST(:,:,1),'uint8');                     % copy the image to the previoulsy create matrix
            im(:,:,2)= cast(TEST(:,:,2),'uint8');
            im(:,:,3)= cast(TEST(:,:,3),'uint8');         
            im_gpu = gpuArray(im);
            
            % Gathering GT box and label 
            gt_boxes = [annotations.get(1).asDouble(), annotations.get(2).asDouble(), ...
                        annotations.get(3).asDouble(), annotations.get(4).asDouble()];  % bbox format: [tl_x, tl_y, br_x, br_y]
            label    =  annotations.get(5).asString(); % Is it really required?
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%% NEED FOR A LABEL CHECK %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            fprintf('Fetching image and annotation required %f seconds\n', toc(fetch_tic));

            %% Extract regions from image and filtering
            regions_tic = tic;

            [boxes, scores]                 = proposal_im_detect(cnn_model.proposal_detection_model.conf_proposal, cnn_model.rpn_net, im_gpu);
            aboxes                          = boxes_filter([boxes, scores], cnn_model.opts.per_nms_topN, cnn_model.opts.nms_overlap_thres, ...
                                                        cnn_model.opts.after_nms_topN, cnn_model.opts.use_gpu);
            fprintf('--Region proposal prediction required %f seconds\n', toc(regions_tic));

            %% Select positive regions
            % Positive regions for bounding box regressor
            [cur_bbox_pos, cur_bbox_y]       = select_positives_for_bbox(aboxes, gt_boxes); %TO-DO-------------------------------------------------------
            pos_bbox_regressor.bbox         = cat(1, pos_bbox_regressor.bbox, cur_bbox_pos);
            y_bbox_regressor                = cat(1,y_bbox_regressor,cur_bbox_y);          
          
            % Positive regions for region classifier
            pos_region_classifier.boxes     = cat(1, pos_region_classifier.boxes, gt_boxes);

            %% Select negative samples for region classifier
            if curr_negative_number < total_negatives
                curr_cls_neg                = select_negatives(aboxes, gt_boxes, neg_per_image); % TO-DO-------------------------------------------------
                neg_region_classifier.boxes = cat(1, neg_region_classifier.boxes, curr_cls_neg);
                curr_negative_number        = curr_negative_number+1;
            end

            %% Extract features from regions         
            % Select regions to extract features from
            regions_for_features           = cat(1, cur_bbox_pos, curr_cls_neg); % cur_bbox_pos contains gt_box too so no need to repeat it  % TO-CHECK
           
            % Network forward
            features                       = cnn_features_demo(cnn_model.proposal_detection_model.conf_detection, im_gpu, regions_for_features, ...
                                                       cnn_model.fast_rcnn_net, [], 'fc7');            
            % Divide extracted features by usage 
            cur_pos_bbox_regressor_feat    = features(1:size(pos_bbox_regressor.bbox,1),:); % TO-CHECK---------------------------------------------------
            cur_pos_region_classifier_feat = features(1,:); % TO-CHECK-----------------------------------------------------------------------------------
            cur_neg_region_classifier_feat = features(size(pos_bbox_regressor.bbox,1)+1:size(neg_region_classifier.bbox,1),:); % TO-CHECK----------------
            
            % Update total features datasets
            pos_bbox_regressor.feat        = cat(1, pos_bbox_regressor.feat, cur_pos_bbox_regressor_feat);
            pos_region_classifier.feat     = cat(1, pos_region_classifier.feat, cur_pos_region_classifier_feat);
            neg_region_classifier.feat     = cat(1, neg_region_classifier.feat, cur_neg_region_classifier_feat);

            curr_instances = curr_instances +1;
        end
    end
    %% Update dataset with data from new class
    new_cls_idx = length(dataset.bbox_regressor) + 1;
    
    dataset.bbox_regressor{new_cls_idx}                       = struct;
    dataset.bbox_regressor{new_cls_idx}.pos_bbox_regressor    = pos_bbox_regressor;
    dataset.bbox_regressor{new_cls_idx}.y_bbox_regressor      = y_bbox_regressor; 
    
    dataset.reg_classifier{new_cls_idx}                       = struct;
    dataset.reg_classifier{new_cls_idx}.pos_region_classifier = pos_region_classifier;
    dataset.reg_classifier{new_cls_idx}.neg_region_classifier = neg_region_classifier;
    
    
    %% Train region classifier
    region_classifier = train_region_classifier(dataset.reg_classifier); %TO-DO-------------------------------------------------------------------------
    
    %% Train Bounding box regressors
    bbox_regressor    = train_bbox_regressor(dataset.bbox_regressor); %TO-DO----------------------------------------------------------------------------
    
    fprintf('All training process required %f seconds\n', toc(total_tic));
    %% Save dataset
    save('boh_dataset.mat', dataset)
end
end
