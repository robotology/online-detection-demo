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
% if cnn_model.opts.use_gpu
%    cnn_model.proposal_detection_model.conf_proposal.image_means = gpuArray(cnn_model.proposal_detection_model.conf_proposal.image_means);
%    cnn_model.proposal_detection_model.conf_detection.image_means = gpuArray(cnn_model.proposal_detection_model.conf_detection.image_means);
% end

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
    negatives_selection.neg_per_image = round(total_negatives/max_img_per_class);
else
    negatives_selection.neg_per_image = 1;
end

%% Load old dataset if there is any
try                                 %TO-DO-----------------------------------------------------------------------------------------------
    disp('Loading dataset..');
    dataset = struct;               
    dataset.bbox_regressor = cell(0);
    dataset.reg_classifier = cell(0);
    dataset.classes = cell(0);
    disp('Loaded dataset for classes:');
    disp(dataset.classes);
catch
    disp('Old dataset not found, creating a new one...');
    dataset = struct;
    dataset.bbox_regressor = cell(0);
    dataset.reg_classifier = cell(0);
    dataset.classes = cell(0);
    disp('Done.')
end

for i=1:length(classes)
    curr_instances = 0;
    curr_negative_number = 0;
    
    dataset.classes{length(dataset.classes)+1} = classes{i};
    
    pos_region_classifier         = struct;
    pos_region_classifier.box    = [];
    pos_region_classifier.feat    = [];
    
    neg_region_classifier      = struct;
    neg_region_classifier.box  = [];
    neg_region_classifier.feat = [];
    
    pos_bbox_regressor         = struct;
    pos_bbox_regressor.box    = [];
    pos_bbox_regressor.feat    = [];
    
    y_bbox_regressor           = [];
    
    total_tic = tic;
    while curr_instances < max_img_per_class
        %% Receive image and annotation
        fetch_tic = tic;
        disp('Waiting image from port...');
        annotations = yarp.Bottle();
        yarpImage   = portImage.read(true);                           % get the yarp image from port
        portAnnotation.read(annotations);
        if (sum(size(yarpImage)) ~= 0 && annotations.size() ~= 0)     % check size of bottle 
            process_tic = tic;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%% NEED FOR A TSTAMP CHECK %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      
            % Gathering mat image and gpuarray
            TEST = reshape(tool.getRawImg(yarpImage), [h w pixSize]); % need to reshape the matrix from 1D to h w pixelSize       
            im=uint8(zeros(h, w, pixSize));                           % create an empty image with the correct dimentions
            im(:,:,1)= cast(TEST(:,:,1),'uint8');                     % copy the image to the previoulsy create matrix
            im(:,:,2)= cast(TEST(:,:,2),'uint8');
            im(:,:,3)= cast(TEST(:,:,3),'uint8');         
%             im_gpu = gpuArray(im);
            
            % Gathering GT box and label 
            for j = 1:length(annotations)
                ann = annotations.pop();
                gt_boxes = [ann.asList().get(0).asDouble(), ann.asList().get(1).asDouble(), ...
                            ann.asList().get(2).asDouble(), ann.asList().get(3).asDouble()];  % bbox format: [tl_x, tl_y, br_x, br_y]
                label    =  ann.asList().get(4).asString(); % Is it really required?
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%% NEED FOR A LABEL CHECK %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            fprintf('Fetching image and annotation required %f seconds\n', toc(fetch_tic));

            %% Extract regions from image and filtering
            regions_tic = tic;

            [boxes, scores]                 = proposal_im_detect(cnn_model.proposal_detection_model.conf_proposal, cnn_model.rpn_net, im);
            aboxes                          = boxes_filter([boxes, scores], cnn_model.opts.per_nms_topN, cnn_model.opts.nms_overlap_thres, ...
                                                        cnn_model.opts.after_nms_topN, cnn_model.opts.use_gpu);
            fprintf('--Region proposal prediction required %f seconds\n', toc(regions_tic));

            %% Select positive regions
            overlaps = boxoverlap(aboxes, gt_boxes); %TO-CHECK-------------------------------------------------------------------------------------------------

            % Positive regions for bounding box regressor
            [cur_bbox_pos, cur_bbox_y]      = select_positives_for_bbox(aboxes, gt_boxes, overlaps, bbox_opts.min_overlap); %TO-CHECK-------------------------------------------------------
            pos_bbox_regressor.box          = cat(1, pos_bbox_regressor.box, cur_bbox_pos);
            y_bbox_regressor                = cat(1,y_bbox_regressor,cur_bbox_y);          
          
            % Positive regions for region classifier
            pos_region_classifier.box       = cat(1, pos_region_classifier.box, gt_boxes);

            %% Select negative samples for region classifier
            if curr_negative_number < total_negatives
                curr_cls_neg                = select_negatives_for_cls(aboxes, overlaps, negatives_selection); % TO-CHECK-------------------------------------------------
                neg_region_classifier.box = cat(1, neg_region_classifier.box, curr_cls_neg);
                curr_negative_number        = curr_negative_number + size(curr_cls_neg,1);
            else
                curr_cls_neg = [];
                neg_region_classifier.box = [];
            end

            %% Extract features from regions         
            % Select regions to extract features from
            regions_for_features           = cat(1, cur_bbox_pos, curr_cls_neg); % cur_bbox_pos contains gt_box too so no need to repeat it  % TO-CHECK
           
            % Network forward
            features                       = cnn_features_demo(cnn_model.proposal_detection_model.conf_detection, im, regions_for_features(:, 1:4), ...
                                                       cnn_model.fast_rcnn_net, [], 'fc7');            
            % Divide extracted features by usage 
            cur_pos_bbox_regressor_feat    = features(1:size(cur_bbox_pos,1),:); % TO-CHECK---------------------------------------------------
            cur_pos_region_classifier_feat = features(1,:); % TO-CHECK-----------------------------------------------------------------------------------
            cur_neg_region_classifier_feat = features(size(cur_bbox_pos,1)+1:(size(cur_bbox_pos,1)+size(curr_cls_neg,1)),:); % TO-CHECK----------------
            
            % Update total features datasets
            pos_bbox_regressor.feat        = cat(1, pos_bbox_regressor.feat, cur_pos_bbox_regressor_feat);
            pos_region_classifier.feat     = cat(1, pos_region_classifier.feat, cur_pos_region_classifier_feat);
            neg_region_classifier.feat     = cat(1, neg_region_classifier.feat, cur_neg_region_classifier_feat);

            curr_instances = curr_instances +1;
            fprintf('one image processed in %d seconds',toc(process_tic));
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
    region_classifier = Train_region_classifier(dataset.reg_classifier, cls_opts); %TO-CHECK-------------------------------------------------------------------------
    
    %% Train Bounding box regressors
    bbox_regressor    = train_bbox_regressor(dataset.bbox_regressor); %TO-CHECK----------------------------------------------------------------------------
    
    fprintf('All training process required %f seconds\n', toc(total_tic));
    %% Save dataset
    save('boh_dataset.mat', 'dataset')
end
end
function [cur_bbox_X, cur_bbox_Y] = select_positives_for_bbox(boxes, gt_boxes, overlaps, min_overlap)

sel_ex = find(overlaps >= min_overlap); 

cur_bbox_X = boxes(sel_ex, :);
cur_bbox_Y = [];

for j = 1:size(cur_bbox_X, 1)
    ex_box = cur_bbox_X(j, :);
%     ov = boxoverlap(gt_boxes, ex_box);
%     [max_ov, assignment] = max(ov);
    gt_box = gt_boxes;
%     cls = gt_classes(assignment);

    src_w = ex_box(3) - ex_box(1) + eps;
    src_h = ex_box(4) - ex_box(2) + eps;
    src_ctr_x = ex_box(1) + 0.5*src_w;
    src_ctr_y = ex_box(2) + 0.5*src_h;

    gt_w = gt_box(3) - gt_box(1) + eps;
    gt_h = gt_box(4) - gt_box(2) + eps;
    gt_ctr_x = gt_box(1) + 0.5*gt_w;
    gt_ctr_y = gt_box(2) + 0.5*gt_h;

    dst_ctr_x = (gt_ctr_x - src_ctr_x) * 1/src_w;
    dst_ctr_y = (gt_ctr_y - src_ctr_y) * 1/src_h;
    dst_scl_w = log(gt_w / src_w);
    dst_scl_h = log(gt_h / src_h);

    target = [dst_ctr_x dst_ctr_y dst_scl_w dst_scl_h];

    cur_bbox_Y = cat(1,cur_bbox_Y,target);
end
end

function curr_cls_neg = select_negatives_for_cls(aboxes, overlaps, negatives_selection)
    I = find(overlaps < negatives_selection.neg_ovr_thresh);
    idx = randperm(length(I), negatives_selection.neg_per_image);
    curr_cls_neg = aboxes(idx,:);
end

function proposal_detection_model = load_proposal_detection_model(model_dir)
    ld                          = load(fullfile(model_dir, 'model'));
    proposal_detection_model    = ld.proposal_detection_model;
    clear ld;
    
    proposal_detection_model.proposal_net_def ...
                                = fullfile(model_dir, proposal_detection_model.proposal_net_def);
    proposal_detection_model.proposal_net ...
                                = fullfile(model_dir, proposal_detection_model.proposal_net);
    proposal_detection_model.detection_net_def ...
                                = fullfile(model_dir, proposal_detection_model.detection_net_def);
    proposal_detection_model.detection_net ...
                                = fullfile(model_dir, proposal_detection_model.detection_net);
    
end

function aboxes = boxes_filter(aboxes, per_nms_topN, nms_overlap_thres, after_nms_topN, use_gpu)
    % to speed up nms
    if per_nms_topN > 0
        aboxes = aboxes(1:min(length(aboxes), per_nms_topN), :);
    end
    % do nms
    if nms_overlap_thres > 0 && nms_overlap_thres < 1
        aboxes = aboxes(nms(aboxes, nms_overlap_thres, use_gpu), :);       
    end
    if after_nms_topN > 0
        aboxes = aboxes(1:min(length(aboxes), after_nms_topN), :);
    end
end