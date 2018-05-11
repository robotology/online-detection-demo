function feat = cnn_features_shared_conv(conf, im, boxes, caffe_net, layer, conv_feat_blob)

[rois_blob, ~] = get_blobs(conf, im, boxes);
    
% Here, we identify duplicate feature ROIs, so we only compute features
% on the unique subset.
[~, index, inv_index] = unique(rois_blob, 'rows');
rois_blob = rois_blob(index, :);
boxes = boxes(index, :);

% permute data into caffe c++ memory, thus [num, channels, height, width]
% im_blob = im_blob(:, :, [3, 2, 1], :); % from rgb to brg
% im_blob = permute(im_blob, [2, 1, 3, 4]);
% im_blob = single(im_blob);
rois_blob = rois_blob - 1; % to c's index (start from 0)
rois_blob = permute(rois_blob, [3, 4, 2, 1]);
rois_blob = single(rois_blob);

caffe_net.blobs('data').copy_data_from(conv_feat_blob);

total_rois = size(rois_blob, 4);
% max_rois_num_in_gpu = cnn_model.max_rois_num_in_gpu;
% max_rois_num_in_gpu = check_gpu_memory(conf, caffe_net)

% compute features for each batch of region images
feat_dim = -1;
feat = [];
curr = 1;
batch_size = 256;

batch_padding = calculate_batch_padding(total_rois, batch_size);

for i = 1:ceil(total_rois / batch_size)

    sub_ind_start = 1 + (i-1) * batch_size;
    sub_ind_end = min(total_rois, i * batch_size);
    sub_rois_blob = rois_blob(:, :, :, sub_ind_start:sub_ind_end);

    net_inputs = {[], sub_rois_blob};

    % Reshape net's input blobs
    caffe_net.reshape_as_input(net_inputs);
    scores = caffe_net.forward(net_inputs);
    f = caffe_net.blobs(layer).get_data(); %14 = fc7 to check
    f = f(:);
    
    % first batch, init feat_dim and feat
    if i == 1
        if layer == 'fc7'
            feat_dim = 4096;
        elseif layer == 'fc6'
            feat_dim = 4096;
        elseif layer == 'pool5'
            feat_dim = 9216;
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

function [batch_padding] = calculate_batch_padding(num_boxes,  batch_size)
    batch_padding = batch_size - mod(num_boxes, batch_size);
    if batch_padding == batch_size
      batch_padding = 0;
    end
end

function [rois_blob, im_scale_factors] = get_blobs(conf, im, rois)
    im_scale_factors = get_image_blob_scales(conf, im);
    rois_blob = get_rois_blob(conf, rois, im_scale_factors);
end

function im_scales = get_image_blob_scales(conf, im)
    im_scales = arrayfun(@(x) prep_im_for_blob_size(size(im), x, conf.test_max_size), conf.test_scales, 'UniformOutput', false);
    im_scales = cell2mat(im_scales); 
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
        levels = max(abs(scaled_areas - 224.^2), 2); 
    else
        levels = ones(size(im_rois, 1), 1);
    end
    
    feat_rois = round(bsxfun(@times, im_rois-1, scales(levels))) + 1;
end

function boxes = clip_boxes(boxes, im_width, im_height)
    % x1 >= 1 & <= im_width
    boxes(:, 1:4:end) = max(min(boxes(:, 1:4:end), im_width), 1);
    % y1 >= 1 & <= im_height
    boxes(:, 2:4:end) = max(min(boxes(:, 2:4:end), im_height), 1);
    % x2 >= 1 & <= im_width
    boxes(:, 3:4:end) = max(min(boxes(:, 3:4:end), im_width), 1);
    % y2 >= 1 & <= im_height
    boxes(:, 4:4:end) = max(min(boxes(:, 4:4:end), im_height), 1);
end
  

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
