function [mean_norm, stdd, mean_feat] = cnn_feature_stats(imdb, layer, cache_dir)
% AUTORIGHTS
% ---------------------------------------------------------
% Copyright (c) 2014, Ross Girshick
% 
% This file is part of the R-CNN code and is available 
% under the terms of the Simplified BSD License provided in 
% LICENSE. Please retain this notice and LICENSE if you use 
% this file (or any portion of it) in your project.
% ---------------------------------------------------------

% conf = rcnn_config('sub_dir', imdb.name);
% 
% save_file = sprintf('%s/feature_stats_%s_layer_%d_%s.mat', ...
%                     cache_dir, imdb.name, layer, cnn_model.cache_name);


save_file = sprintf('./feat_cache/%s/feature_stats_%s_layer_%d.mat', ...
                    cache_dir, imdb.name, layer);

try
  ld = load(save_file);
  mean_norm = ld.mean_norm;
  stdd = ld.stdd;
  mean_feat = ld.mean_feat;
  clear ld;
catch
  % fix the random seed for repeatability
  prev_rng = seed_rand();

  image_ids = imdb.image_ids;

  %total number of features to evaluate: num_images x boxes_per_image
  num_images = min(length(image_ids), 200);
  boxes_per_image = 200;

  image_ids = image_ids(randperm(length(image_ids), num_images));
  
  %mean_feat initialization 
  d_ex = cnn_load_cached_pool5_features(cache_dir, imdb.name, image_ids{1});
  feat_dim = size(d_ex.feat,2);
  mean_feat = zeros(1,feat_dim);
   
  ns = [];
  count = 0;
  for i = 1:length(image_ids)
    tic_toc_print('feature stats: %d/%d\n', i, length(image_ids));

    d = cnn_load_cached_pool5_features(cache_dir, ...
        imdb.name, image_ids{i});
    
    %randomly choose boxes_per_image features per image
    X = d.feat(randperm(size(d.feat,1), min(boxes_per_image, size(d.feat,1))), :);
    %X = cnn_pool5_to_fcX(X, layer, cnn_model, caffe_net);
    
    %calculate sum of columns of X and add it to mean_feat
    sum_X = sum(X);
    mean_feat = sum_X + mean_feat;
    
    ns = cat(1, ns, sqrt(sum(X.^2, 2)));
    
    count = count + size(X,1);
  end
  %mean feat
  mean_feat = mean_feat / count;
  mean_norm = mean(ns);
  stdd = std(ns);
  save(save_file, 'mean_norm', 'stdd', 'mean_feat');

  % restore previous rng
  rng(prev_rng);
end
