function [  ] = Predict( imageset,cnn_model, cls_model, bbox_model )
%INFERENCE Summary of this function goes here
%   Detailed explanation goes here

prediction_tic = tic;


image_ids = textread(sprintf(VOCopts.imgsetpath, image_set), '%s');


for j = 1:length(image_ids)
    %% Fetch image
    fetch_tic = tic;
    
    im = imread(fullfile(pwd, image_ids{j}));    
    im = gpuArray(im);
    
    fprintf('fetching images required %f seconds', toc(fetch_tic));

    %% Region proposals and features extraction
    feature_tic = tic;
    
    % test proposal
    %th = tic();
    [boxes, scores]             = proposal_im_detect(proposal_detection_model.conf_proposal, rpn_net, im);
    t_proposal = toc(th);
    %th = tic();
    aboxes                      = boxes_filter([boxes, scores], opts.per_nms_topN, opts.nms_overlap_thres, opts.after_nms_topN, opts.use_gpu);
    %t_nms = toc(th);

    fprintf('feature extraction and region proposal prediction required %f seconds', toc(feature_tic));
    
    %% Regions classification
    cls_tic = tic;
    %
    %Stuff
    %
    fprintf('Region classification required %f seconds', toc(cls_tic));

    %% Thresholding
    th_tic = tic;
    %
    %Stuff
    %
    fprintf('Thresholding bounding boxes required %f seconds', toc(th_tic));

    %% Bounding boxes refinement
    bbox_tic = tic;
    %
    %Stuff
    %
    fprintf('Bounding box refinement required %f seconds', toc(bbox_tic));

    fprintf('Prediction required %f seconds', toc(prediction_tic));
end




end

