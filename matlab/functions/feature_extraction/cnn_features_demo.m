function feat = cnn_features_demo(conf, im, boxes, caffe_net, cnn_model, layer)
% feat = rcnn_features(im, boxes, cnn_model)
%   Compute CNN features on a set of boxes.
%
%   im is an image in RGB order as returned by imread
%   boxes are in [x1 y1 x2 y2] format with one box per row
%   cnn_model specifies the CNN Caffe net file to use.

% AUTORIGHTS
% ---------------------------------------------------------
% Copyright (c) 2014, Ross Girshick
% 
% This file is part of the R-CNN code and is available 
% under the terms of the Simplified BSD License provided in 
% LICENSE. Please retain this notice and LICENSE if you use 
% this file (or any portion of it) in your project.
% ---------------------------------------------------------
[im_blob, rois_blob, ~] = get_blobs(conf, im, boxes);
    
% When mapping from image ROIs to feature map ROIs, there's some aliasing
% (some distinct image ROIs get mapped to the same feature ROI).
% Here, we identify duplicate feature ROIs, so we only compute features
% on the unique subset.
[~, index, inv_index] = unique(rois_blob, 'rows');
rois_blob = rois_blob(index, :);
boxes = boxes(index, :);

% permute data into caffe c++ memory, thus [num, channels, height, width]
im_blob = im_blob(:, :, [3, 2, 1], :); % from rgb to brg
im_blob = permute(im_blob, [2, 1, 3, 4]);
im_blob = single(im_blob);
rois_blob = rois_blob - 1; % to c's index (start from 0)
rois_blob = permute(rois_blob, [3, 4, 2, 1]);
rois_blob = single(rois_blob);

% total_scores = cell(ceil(total_rois / max_rois_num_in_gpu), 1);
% total_box_deltas = cell(ceil(total_rois / max_rois_num_in_gpu), 1);

total_rois = size(rois_blob, 4);
% max_rois_num_in_gpu = cnn_model.max_rois_num_in_gpu;
% max_rois_num_in_gpu = check_gpu_memory(conf, caffe_net)

% compute features for each batch of region images
feat_dim = -1;
feat = [];
curr = 1;
batch_size = 150;

batch_padding = calculate_batch_padding(total_rois, batch_size);

for i = 1:ceil(total_rois / batch_size)

    sub_ind_start = 1 + (i-1) * batch_size;
    sub_ind_end = min(total_rois, i * batch_size);
    sub_rois_blob = rois_blob(:, :, :, sub_ind_start:sub_ind_end);

    net_inputs = {im_blob, sub_rois_blob};

    % Reshape net's input blobs
    caffe_net.reshape_as_input(net_inputs);
    scores = caffe_net.forward(net_inputs);
    f = caffe_net.blobs(layer).get_data(); %14 = fc7 to check
    f = f(:);
    
    % first batch, init feat_dim and feat
    if i == 1
        if strcmp(layer, 'fc7')
            feat_dim = 4096;
        elseif strcmp(layer, 'fc6')
            feat_dim = 4096;
        elseif strcmp(layer,'pool5')
            feat_dim = 2048;
        else
            error('Error: unrecognized layer');
        end
%       feat_dim = length(f)/batch_size;
      feat = zeros(size(boxes, 1), feat_dim, 'single');
    end
    other_dim = batch_size;

    % last batch, trim f to size
    if i == ceil(total_rois / batch_size)
      if batch_padding > 0
          other_dim = batch_size-batch_padding;
%         f = f(:, 1:end-batch_padding);
      end
    end

    f = reshape(f, [feat_dim other_dim]);  
    
    feat(curr:curr+size(f,2)-1,:) = f';
    curr = curr + batch_size;

end
feat = feat(inv_index, :);
end

function [data_blob, rois_blob, im_scale_factors] = get_blobs(conf, im, rois)
    [data_blob, im_scale_factors] = get_image_blob(conf, im);
    rois_blob = get_rois_blob(conf, rois, im_scale_factors);
end

function [blob, im_scales] = get_image_blob(conf, im)
    [ims, im_scales] = arrayfun(@(x) prep_im_for_blob(im, conf.image_means, x, conf.test_max_size), conf.test_scales, 'UniformOutput', false);
    im_scales = cell2mat(im_scales);
    blob = im_list_to_blob(ims);    
end

function [rois_blob] = get_rois_blob(conf, im_rois, im_scale_factors)
    [feat_rois, levels] = map_im_rois_to_feat_rois(conf, im_rois, im_scale_factors);
    rois_blob = single([levels, feat_rois]);
end

function [feat_rois, levels] = map_im_rois_to_feat_rois(conf, im_rois, scales)
    im_rois = single(im_rois);
    
    if length(scales) > 1
        widths = im_rois(:, 3) - im_rois(:, 1) + 1;
        heights = im_rois(:, 4) - im_rois(:, 2) + 1;
        
        areas = widths .* heights;
        scaled_areas = bsxfun(@times, areas(:), scales(:)'.^2);
        [~, levels] = min(abs(scaled_areas - 224.^2), [], 2); 
    else
        levels = ones(size(im_rois, 1), 1);
    end
    
    feat_rois = round(bsxfun(@times, im_rois-1, scales(levels))) + 1;
end

function [batch_padding] = calculate_batch_padding(num_boxes,  batch_size)
    batch_padding = batch_size - mod(num_boxes, batch_size);
    if batch_padding == batch_size
      batch_padding = 0;
    end
end

% function max_rois_num = check_gpu_memory(conf, caffe_net)
% %%  try to determine the maximum number of rois
% 
%     max_rois_num = 0;
%     for rois_num = 500:500:5000
%         % generate pseudo testing data with max size
%         im_blob = single(zeros(conf.max_size, conf.max_size, 3, 1));
%         rois_blob = single(repmat([0; 0; 0; conf.max_size-1; conf.max_size-1], 1, rois_num));
%         rois_blob = permute(rois_blob, [3, 4, 1, 2]);
% 
%         net_inputs = {im_blob, rois_blob};
% 
%         % Reshape net's input blobs
%         caffe_net.reshape_as_input(net_inputs);
% 
%         caffe_net.forward(net_inputs);
%         gpuInfo = gpuDevice();
% 
%         max_rois_num = rois_num;
%             
%         if gpuInfo.FreeMemory < 2 * 10^9  % 2GB for safety
%             break;
%         end
%     end
% 
% end

% %% RCNN
% % make sure that caffe has been initialized for this model
% if cnn_model.cnn.init_key ~= caffe('get_init_key')
%   error('You probably need to call rcnn_load_model');
% end
% 
% % Each batch contains 256 (default) image regions.
% % Processing more than this many at once takes too much memory
% % for a typical high-end GPU.
% [batches, batch_padding] = extract_regions(im, boxes, cnn_model);
% batch_size = cnn_model.cnn.batch_size;
% 
% % compute features for each batch of region images
% feat_dim = -1;
% feat = [];
% curr = 1;
% for j = 1:length(batches)
%   % forward propagate batch of region images 
%   f = caffe('forward', batches(j)); %ELISA guardare come fa forward in im_detect
%   f = f{1};
%   f = f(:);
%   
%   % first batch, init feat_dim and feat
%   if j == 1
%     feat_dim = length(f)/batch_size;
%     feat = zeros(size(boxes, 1), feat_dim, 'single');
%   end
% 
%   f = reshape(f, [feat_dim batch_size]);
% 
%   % last batch, trim f to size
%   if j == length(batches)
%     if batch_padding > 0
%       f = f(:, 1:end-batch_padding);
%     end
%   end
% 
%   feat(curr:curr+size(f,2)-1,:) = f';
%   curr = curr + batch_size;
% end
