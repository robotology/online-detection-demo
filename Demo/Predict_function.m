function [  ] = Predict_function( image_set, classes, cnn_model_dir, cls_model, bbox_model, gpu_id )
%INFERENCE Summary of this function goes here
%   Detailed explanation goes here

%% -------------------- CONFIG --------------------
opts.caffe_version          = 'caffe_faster_rcnn';
opts.gpu_id                 = gpu_id;
active_caffe_mex(opts.gpu_id, opts.caffe_version);

opts.per_nms_topN           = 6000;
opts.nms_overlap_thres      = 0.7;
opts.after_nms_topN         = 300;
opts.use_gpu                = true;

opts.test_scales            = 600;
detect_thresh               = 0.5;


%% -------------------- INIT_MODEL --------------------
proposal_detection_model    = load_proposal_detection_model(cnn_model_dir);
proposal_detection_model.conf_proposal.test_scales = opts.test_scales;
proposal_detection_model.conf_detection.test_scales = opts.test_scales;
if opts.use_gpu
    proposal_detection_model.conf_proposal.image_means = gpuArray(proposal_detection_model.conf_proposal.image_means);
    proposal_detection_model.conf_detection.image_means = gpuArray(proposal_detection_model.conf_detection.image_means);
end

% proposal net
rpn_net = caffe.Net(proposal_detection_model.proposal_net_def, 'test');
rpn_net.copy_from(proposal_detection_model.proposal_net);
% fast rcnn net
fast_rcnn_net = caffe.Net(proposal_detection_model.detection_net_def, 'test');
fast_rcnn_net.copy_from(proposal_detection_model.detection_net);

% set gpu/cpu
if opts.use_gpu
    caffe.set_mode_gpu();
else
    caffe.set_mode_cpu();
end       

%% -------------------- START PREDICTION --------------------
prediction_tic = tic;

image_ids = textread([dataset_path, 'ImageSets/', image_set, '.txt']);

for j = 1:length(image_ids)
    %% Fetch image
    fetch_tic = tic;
    
    im = imread(fullfile(dataset_path, 'Images', image_ids{j}));    
    im_gpu = gpuArray(im);
    
    fprintf('fetching images required %f seconds', toc(fetch_tic));

    %% Region proposals
    regions_tic = tic;
    
    % test proposal
    [boxes, scores]             = proposal_im_detect(proposal_detection_model.conf_proposal, rpn_net, im_gpu);
    aboxes                      = boxes_filter([boxes, scores], opts.per_nms_topN, opts.nms_overlap_thres, opts.after_nms_topN, opts.use_gpu);
    fprintf('region proposal prediction required %f seconds', toc(regions_tic));

    %feature extraction from regions    
    feature_tic = tic;
    if proposal_detection_model.is_share_feature
        % TO-CHECK if features is already a gpuArray
        features             = cnn_features_shared_conv(proposal_detection_model.conf_detection, im_gpu, aboxes(:, 1:4), fast_rcnn_net, [], layer, ...
                                                    rpn_net.blobs(proposal_detection_model.last_shared_output_blob_name));
    else
%         [boxes, scores]             = fast_rcnn_im_detect(proposal_detection_model.conf_detection, fast_rcnn_net, im, ...
%             aboxes(:, 1:4), opts.after_nms_topN);
        fprintf('Wrong!');
    end
    features = rcnn_scale_features(features, cls_model.training_opts.feat_norm_mean);
    fprintf('feature extraction and region proposal prediction required %f seconds', toc(feature_tic));
    
    %% Regions classification and scores thresholding
    cls_tic = tic;
    [boxes, cls_scores] = predict_FALKON(features, cls_model, detect_thresh);
    fprintf('Region classification required %f seconds', toc(cls_tic));

    %% Bounding boxes refinement
    bbox_tic = tic;
    boxes = predict_bbox_refinement( bbox_model, feat, boxes, length(classes) );
    fprintf('Bounding box refinement required %f seconds', toc(bbox_tic));

    %% Detections visualization
    vis_tic = tic;
    boxes_cell = cell(length(classes), 1);
    for i = 1:length(boxes_cell)
        boxes_cell{i} = [boxes(:, (1+(i-1)*4):(i*4)), cls_scores(:, i)];
    end
    f = figure(j);
    showboxes(im, boxes_cell, classes, 'voc');
    fprintf('Visualization required %f seconds', toc(vis_tic));

    fprintf('Prediction required %f seconds', toc(prediction_tic));
end


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
