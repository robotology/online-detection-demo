function [ model_classifier ] = GURLS_classifiers_train(train_options, config, cnn_model, imdb, varargin )

ip = inputParser;
ip.addRequired('imdb', @isstruct);
ip.addRequired('cnn_model', @isstruct);

ip.parse(imdb, cnn_model, varargin{:});
opts = ip.Results;

opts.min_overlap = 0.6;
opts.net_file = ip.Results.cnn_model.binary_file;
opts.net_def_file =  ip.Results.cnn_model.net_def_file;
opts.cache_name = ip.Results.cnn_model.cache_name;
opts.layer = 7;

conf.cache_dir = train_options.cache_dir;
conf.use_gpu =   config.use_gpu;
if ~exist(conf.cache_dir)
    mkdir(conf.cache_dir);
end
% Record a log of the training and test procedure
timestamp = datestr(datevec(now()), 'dd.mmm.yyyy:HH.MM.SS');
diary_file = [conf.cache_dir 'rcnn_train_' timestamp '.txt'];
diary(diary_file);
fprintf('Logging output in %s\n', diary_file);

fprintf('\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
fprintf('Training options:\n');
disp(opts);
fprintf('~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n');

% ------------------------------------------------------------------------
% Create a new cnn model
rcnn_model = add_SVMs_model(cnn_model);
[rcnn_model, caffe_net]  = cnn_load_model(config, rcnn_model);
rcnn_model.classes = imdb.classes;
% ------------------------------------------------------------------------
% ------------------------------------------------------------------------
% Get the average norm of the features
if(train_options.subtract_mean)
    [opts.feat_norm_mean, opts.stdd, opts.mean_feat] = cnn_feature_stats(imdb, opts.layer, rcnn_model, caffe_net , opts.cache_name);
    fprintf('average norm = %.3f\n', opts.feat_norm_mean);
    rcnn_model.training_opts = opts;
end
% ------------------------------------------------------------------------

% ------------------------------------------------------------------------
% Get all positive examples
% We cache only the pool5 features and convert them on-the-fly to
% fc6 or fc7 as required
if (train_options.gt_regions)
    save_file = sprintf('./feat_cache/%s/%s/gt_pos_layer_5_cache_gt.mat', rcnn_model.cache_name, imdb.name);
else
    save_file = sprintf('./feat_cache/%s/%s/gt_pos_layer_5_cache_iou.mat', rcnn_model.cache_name, imdb.name);
end

try
  load(save_file);
  fprintf('Loaded saved positives from ground truth boxes\n');
catch
  [X_pos, keys_pos] = get_positive_pool5_features(imdb, opts, train_options.gt_regions);
  save(save_file, 'X_pos', 'keys_pos', '-v7.3');
end
% Init training caches
caches = {};
X = [];
for i = imdb.class_ids
  fprintf('%14s has %6d positive instances\n', imdb.classes{i}, size(X_pos{i},1));
  % X_pos{i} = cnn_pool5_to_fcX(X_pos{i}, opts.layer, rcnn_model, caffe_net);
  if(train_options.subtract_mean)
      X_pos{i} = GURLS_subtract_mean_features(X_pos{i}, opts.mean_feat);
  end
  X = cat(1, X, X_pos{i});
  caches{i} = init_cache(X_pos{i}, keys_pos{i});
end
% ------------------------------------------------------------------------
Y = ones(size(X,1),1);
last = 0;
for i = imdb.class_ids
    first = last+1;
    last = first + size(X_pos{i},1)-1;
    Y(first:last)=i;
end
 model_classifier = gurls_train(X, Y, train_options.gurlsOptions);

  
% save the final rcnn_model
save([conf.cache_dir 'gurls_classifier'], 'model_classifier');
% ------------------------------------------------------------------------




% ------------------------------------------------------------------------
function [X_pos, keys] = get_positive_pool5_features(imdb, opts, gt_regions)
% ------------------------------------------------------------------------
X_pos = cell(max(imdb.class_ids), 1);
keys = cell(max(imdb.class_ids), 1);

if(gt_regions)
    for i = 1:length(imdb.image_ids)
      tic_toc_print('%s: pos features %d/%d\n', ...
                    procid(), i, length(imdb.image_ids));

      d = cnn_load_cached_pool5_features(opts.cache_name, ...
          imdb.name, imdb.image_ids{i});

     for j = imdb.class_ids
        if isempty(X_pos{j})
          X_pos{j} = single([]);
          keys{j} = [];
        end
        sel = find(d.class == j);
        if ~isempty(sel)
          X_pos{j} = cat(1, X_pos{j}, d.feat(sel,:));
          keys{j} = cat(1, keys{j}, [i*ones(length(sel),1) sel]);
        end
     end
    end
else
    for i = 1:length(imdb.image_ids)
      tic_toc_print('%s: pos features %d/%d\n', ...
                    procid(), i, length(imdb.image_ids));

      d = cnn_load_cached_pool5_features(opts.cache_name, ...
          imdb.name, imdb.image_ids{i});

        for j = imdb.class_ids
            if isempty(X_pos{j})
              X_pos{j} = single([]);
              keys{j} = [];
            end
    %     sel = find(d.class == j);
            if find(d.class == j)
                max_ov = max(d.overlap, [], 2);
                sel = find(max_ov >= opts.min_overlap);
                if ~isempty(sel)
                  X_pos{j} = cat(1, X_pos{j}, d.feat(sel,:));
                  keys{j} = cat(1, keys{j}, [i*ones(length(sel),1) sel]);
                end
            end
        end
    end
end



% ------------------------------------------------------------------------
function cache = init_cache(X_pos, keys_pos)
% ------------------------------------------------------------------------
cache.X_pos = X_pos;
cache.X_neg = single([]);
cache.keys_neg = [];
cache.keys_pos = keys_pos;
cache.num_added = 0;
cache.retrain_limit = 2000;
cache.evict_thresh = -1.2;
cache.hard_thresh = -1.0001;
cache.pos_loss = [];
cache.neg_loss = [];
cache.reg_loss = [];
cache.tot_loss = [];

