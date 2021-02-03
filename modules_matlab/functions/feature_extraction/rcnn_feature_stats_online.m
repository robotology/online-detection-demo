function [mean_norm, stdd] = rcnn_feature_stats_online(imdb,cnn_model_path)
% AUTORIGHTS
% ---------------------------------------------------------
% Copyright (c) 2014, Ross Girshick
% 
% This file is part of the R-CNN code and is available 
% under the terms of the Simplified BSD License provided in 
% LICENSE. Please retain this notice and LICENSE if you use 
% this file (or any portion of it) in your project.
% ---------------------------------------------------------

conf = rcnn_config('sub_dir', imdb.name);
cnn_model.opts.caffe_version           = 'caffe_faster_rcnn';
active_caffe_mex(1, cnn_model.opts.caffe_version);
cnn_model.opts.per_nms_topN            = 6000;
cnn_model.opts.nms_overlap_thres       = 0.7;
cnn_model.opts.after_nms_topN          = 800; %---------------------------------------------------------------------------------------------------------------
cnn_model.opts.use_gpu                 = true;
cnn_model.opts.test_scales             = 600;    

cnn_model.proposal_detection_model = load_proposal_detection_model(cnn_model_path);
cnn_model.proposal_detection_model.conf_proposal.test_scales  = cnn_model.opts.test_scales;
cnn_model.proposal_detection_model.conf_detection.test_scales = cnn_model.opts.test_scales;

% proposal net
disp('Setting RPN...');
cnn_model.rpn_net = caffe.Net(cnn_model.proposal_detection_model.proposal_net_def, 'test');
cnn_model.rpn_net.copy_from(cnn_model.proposal_detection_model.proposal_net);
% fast rcnn net
disp('Setting Fast R-CNN...');
cnn_model.fast_rcnn_net = caffe.Net(cnn_model.proposal_detection_model.detection_net_def, 'test');
cnn_model.fast_rcnn_net.copy_from(cnn_model.proposal_detection_model.detection_net);


current_path = pwd;
dataset_path = [current_path '/datasets/iCubWorld-Transformations/'];
image_set = 'train_TASK2_10objs';

% image_ids = importdata([dataset_path, 'ImageSets/', image_set, '.txt']);

try
  ld = load(save_file);
  mean_norm = ld.mean_norm;
  stdd = ld.stdd;
  clear ld;
catch
  % fix the random seed for repeatability
  prev_rng = seed_rand();

  image_ids = imdb.image_ids;

  num_images = min(length(image_ids), 200);
  boxes_per_image = 200;

  image_ids = image_ids(randperm(length(image_ids), num_images));

  ns = [];
  for i = 1:length(image_ids)
    tic_toc_print('feature stats: %d/%d\n', i, length(image_ids));
    im = imread([dataset_path '/Images/' image_ids{i} '.jpg']);

    [boxes, scores]             = proposal_im_detect(cnn_model.proposal_detection_model.conf_proposal, cnn_model.rpn_net, im);
    aboxes                      = boxes_filter([boxes, scores], cnn_model.opts.per_nms_topN, cnn_model.opts.nms_overlap_thres, ...
                                                cnn_model.opts.after_nms_topN, cnn_model.opts.use_gpu);
                                            
    features             = cnn_features_demo(cnn_model.proposal_detection_model.conf_detection, im, aboxes(:, 1:4), ...
                                                   cnn_model.fast_rcnn_net, [], 'fc7'); 
    

    X = features(randperm(size(features,1), min(boxes_per_image, size(features,1))), :);
%     X = rcnn_pool5_to_fcX(X, layer, rcnn_model);

    ns = cat(1, ns, sqrt(sum(X.^2, 2)));
  end

  mean_norm = mean(ns);
  stdd = std(ns);
  save(save_file, 'mean_norm', 'stdd');

  % restore previous rng
  rng(prev_rng);
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
