function [cls_scores  boxes] = Predict(im_gpu, classes, cnn_model, cls_model, bbox_model, detect_thresh)
%INFERENCE Summary of this function goes here
%   Detailed explanation goes here

    %% Region proposals
    regions_tic = tic;
    
    % test proposal
    [boxes, scores]             = proposal_im_detect(cnn_model.proposal_detection_model.conf_proposal, cnn_model.rpn_net, im_gpu);
    aboxes                      = boxes_filter([boxes, scores], cnn_model.opts.per_nms_topN, cnn_model.opts.nms_overlap_thres, cnn_model.opts.after_nms_topN, cnn_model.opts.use_gpu);
    fprintf('region proposal prediction required %f seconds', toc(regions_tic));

    %feature extraction from regions    
    feature_tic = tic;
    if cnn_model.proposal_detection_model.is_share_feature
        % TO-CHECK if features is already a gpuArray
        features             = cnn_features_shared_conv(cnn_model.proposal_detection_model.conf_detection, im_gpu, aboxes(:, 1:4), cnn_model.fast_rcnn_net, [], cnn_model.layer, ...
                                                    cnn_model.rpn_net.blobs(cnn_model.proposal_detection_model.last_shared_output_blob_name));
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
