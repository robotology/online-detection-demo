function [ new_boxes, thresholded_scores ] = predict_FALKON( feat, cls_model, thresh, boxes )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
num_classes = length(cls_model.classes);
X_test = gpuArray(feat);
thresholded_scores = cell(num_classes, 1);
new_boxes = cell(num_classes, 1);

for j = 1:num_classes        
    z = KtsProd_onGPU(X_test,  cls_model.detectors.models{j}.opts.C, ...
                    cls_model.detectors.models{j}.alpha, 1, cls_model.detectors.models{j}.opts.kernel);
    scores = z(:,2);
    
    % apply NMS to each class and return final scored detections
    fprintf('Applying NMS...');
    I = find(scores(:) > thresh);
    scored_boxes = cat(2, boxes(I, :), scores(I));
    keep = nms(scored_boxes, 0.3); 
    scored_boxes = scored_boxes(keep, :);
    
    thresholded_scores{j} = scored_boxes(:,1:4);
    new_boxes{j} = scored_boxes(:,5);
end

end

