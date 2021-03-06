function cache_features(conf, cnn_model, imdb, roidb, layer, varargin)
% rcnn_cache_pool5_features(imdb, varargin)
%   Computes pool5 features and saves them to disk. We compute
%   pool5 features because we can easily compute fc6 and fc7
%   features from them on-the-fly and they tend to compress better
%   than fc6 or fc7 features due to greater sparsity.
%
%   Keys that can be passed in:
%
%   start             Index of the first image in imdb to process
%   end               Index of the last image in imdb to process
%   crop_mode         Crop mode (either 'warp' or 'square')
%   crop_padding      Amount of padding in crop
%   net_file          Path to the Caffe CNN to use
%   cache_name        Path to the precomputed feature cache

% AUTORIGHTS
% ---------------------------------------------------------
% Copyright (c) 2014, Ross Girshick
% 
% This file is part of the R-CNN code and is available 
% under the terms of the Simplified BSD License provided in 
% LICENSE. Please retain this notice and LICENSE if you use 
% this file (or any portion of it) in your project.
% ---------------------------------------------------------

ip = inputParser;
ip.addRequired('imdb', @isstruct);
ip.addOptional('start', 1, @isscalar);
ip.addOptional('end', 0, @isscalar);
ip.addOptional('crop_mode', 'warp', @isstr);
ip.addOptional('crop_padding', 16, @isscalar);
ip.addOptional('cache_name', ...
    'feature_extraction_cache', @isstr); % to check

ip.parse(imdb, varargin{:});
opts = ip.Results;

image_ids = imdb.image_ids;
if opts.end == 0
  opts.end = length(image_ids);
end

% Where to save feature cache
opts.output_dir = ['./feat_cache/' opts.cache_name '/' imdb.name '/']; %check name dir
mkdir_if_missing(opts.output_dir);

% Log feature extraction
timestamp = datestr(datevec(now()), 'dd.mmm.yyyy:HH.MM.SS');
diary_file = [opts.output_dir 'Incremental_Faster_RCNN_cache_fc7_features_' timestamp '.txt'];
diary(diary_file);
fprintf('Logging output in %s\n', diary_file);

fprintf('\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
fprintf('Feature caching options:\n');
disp(opts);
fprintf('~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n');

% load the region of interest database
% roidb = imdb.roidb_func(imdb);

% cnn_model = cnn_load_model(conf, cnn_model);
[cnn_model, caffe_net]=cnn_load_model(conf,cnn_model);

total_time = 0;
count = 0;
for i = opts.start:opts.end
  fprintf('%s: cache features: %d/%d\n', procid(), i, opts.end);

  save_file = [opts.output_dir image_ids{i} '.mat'];
  save_path =save_file(1:end-4);
  
  if exist(save_path) == 0
     fprintf('creation of %s', save_path);
     mkdir(save_path)
  end
  
  
  if exist(save_file, 'file') ~= 0
    fprintf(' [already exists]\n');
    continue;
  end
  count = count + 1;

  tot_th = tic;

  d = roidb.rois(i);
  im = imread(imdb.image_at(i));

  th = tic;
  d.feat = cnn_features(conf, im, d.boxes, caffe_net, cnn_model, layer);
  fprintf(' [features: %.3fs]\n', toc(th));

  th = tic;
  save(save_file, '-struct', 'd');
  fprintf(' [saving:   %.3fs]\n', toc(th));

  total_time = total_time + toc(tot_th);
  fprintf(' [avg time: %.3fs (total: %.3fs)]\n', ...
      total_time/count, total_time);
end
caffe.reset_all();