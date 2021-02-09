function [ pred_boxes ] = predict_bbox_refinement( bbox_model, feat, boxes, num_classes, inds )
%PREDICT_BBOX_REFINEMENT Summary of this function goes here
%   Detailed explanation goes here
pred_boxes = cell(num_classes, 1);
for i = 1:num_classes
    ex_boxes = boxes{i};
    cur_feat = [];
    cur_feat = feat(inds{i},:);
    if ~isempty(ex_boxes)

        % Predict regression targets
        Y = bsxfun(@plus, cur_feat*bbox_model.models{i}.Beta(1:end-1, :), bbox_model.models{i}.Beta(end, :));
        % Invert whitening transformation
        Y = bsxfun(@plus, Y*bbox_model.models{i}.T_inv, bbox_model.models{i}.mu);

        % Read out predictions
        dst_ctr_x = Y(:,1);
        dst_ctr_y = Y(:,2);
        dst_scl_x = Y(:,3);
        dst_scl_y = Y(:,4);

        src_w = ex_boxes(:,3) - ex_boxes(:,1) + eps;
        src_h = ex_boxes(:,4) - ex_boxes(:,2) + eps;
        src_ctr_x = ex_boxes(:,1) + 0.5*src_w;
        src_ctr_y = ex_boxes(:,2) + 0.5*src_h;

        pred_ctr_x = (dst_ctr_x .* src_w) + src_ctr_x;
        pred_ctr_y = (dst_ctr_y .* src_h) + src_ctr_y;
        pred_w = exp(dst_scl_x) .* src_w;
        pred_h = exp(dst_scl_y) .* src_h;
        pred_boxes{i} = [pred_ctr_x - 0.5*pred_w, pred_ctr_y - 0.5*pred_h, ...
                      pred_ctr_x + 0.5*pred_w, pred_ctr_y + 0.5*pred_h];


        pred_boxes{i}(:,1) = max(pred_boxes{i}(:,1), 1);
        pred_boxes{i}(:,2) = max(pred_boxes{i}(:,2), 1);
        pred_boxes{i}(:,3) = min(pred_boxes{i}(:,3), 640);
        pred_boxes{i}(:,4) = min(pred_boxes{i}(:,4), 480);
    else
        pred_boxes{i} = [];
    end
end

end

