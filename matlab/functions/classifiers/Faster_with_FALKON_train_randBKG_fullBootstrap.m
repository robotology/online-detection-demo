function [ rcnn_model ] = Faster_with_FALKON_train_randBKG_fullBootstrap(train_options, config, cnn_model, imdb, negatives_selection, rebalancing, fid, varargin )

%% Parse inputs
ip = inputParser;
ip.addRequired('imdb',                                               @isstruct);
ip.addRequired('negatives_selection',                                @isstruct);
ip.addParamValue('layer',               7,                           @isscalar);
ip.addParamValue('cache_name',          'feature_extraction_cache',  @isstr);
ip.addParamValue('rebal_alpha',         0.5,                         @isscalar);
ip.addParamValue('svm_C',           10^-3,  @isscalar);
ip.addParamValue('bias_mult',       10,     @isscalar);
ip.addParamValue('pos_loss_weight', 2,      @isscalar);
ip.addParamValue('k_folds',         2,      @isscalar);
ip.addParamValue('checkpoint',      0,      @isscalar);
ip.addParamValue('crop_mode',       'warp', @isstr);
ip.addParamValue('crop_padding',    16,     @isscalar);
ip.parse(imdb, negatives_selection, varargin{:});
opts = ip.Results;

opts.negatives_selection = negatives_selection;
opts.train_classifier_options = train_options;
opts.train_classifier_options.kernel = gaussianKernel(opts.train_classifier_options.sigma); 

opts.net_file = cnn_model.binary_file;
opts.net_def_file = cnn_model.net_def_file;

%% Configure options
conf = rcnn_config('sub_dir', imdb.name);
conf.cache_dir = train_options.cache_dir;
conf.use_gpu =   config.use_gpu;

fprintf('\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
fprintf('Training options:\n');
disp(opts);
fprintf('~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n');

%% Create a new rcnn model
rcnn_model = gurls_create_model(opts.net_def_file, opts.net_file, opts.cache_name);
% rcnn_model = rcnn_create_model(opts.net_def_file, opts.net_file, opts.cache_name);
% rcnn_model = rcnn_load_model(rcnn_model, conf.use_gpu);
rcnn_model.detectors.crop_mode = opts.crop_mode;
rcnn_model.detectors.crop_padding = opts.crop_padding;
rcnn_model.classes = imdb.classes;

% [opts.mean_norm, opts.standard_deviation, opts.mean_feat] = extract_feature_statistics(imdb, opts.layer, rcnn_model);
% fprintf('average norm = %.3f\n', opts.feat_norm_mean);
rcnn_model.training_opts = opts;

% ------------------------------------------------------------------------
% Get the average norm of the features
opts.feat_norm_mean = rcnn_feature_stats(imdb, opts.layer, rcnn_model);
fprintf('average norm = %.3f\n', opts.feat_norm_mean);
rcnn_model.training_opts = opts;
% ------------------------------------------------------------------------

%% Get all positive examples
save_file = sprintf('./feat_cache/%s/%s/gt_pos_layer_5_cache.mat', rcnn_model.cache_name, imdb.name);

try
  load(save_file);
  fprintf('Loaded saved positives from ground truth boxes\n');
catch
  [X_pos, keys_pos] = get_positive_features(imdb, opts);
  save(save_file, 'X_pos', 'keys_pos', '-v7.3');
end
% Init training caches with positive samples
caches = {};
for i = imdb.class_ids
  fprintf('%14s has %6d positive instances\n', imdb.classes{i}, size(X_pos{i},1));
  fprintf(fid, '%14s has %6d positive instances\n', imdb.classes{i}, size(X_pos{i},1));
  X_pos{i} = rcnn_scale_features(X_pos{i}, opts.feat_norm_mean);
  caches{i} = init_cache(X_pos{i}, keys_pos{i});
end

% ------------------------------------------------------------------------
% Train with hard negative mining
first_time = true;
% one pass over the data is enough
max_hard_epochs = 1;
opts.train_classifier_options = struct;
opts.train_classifier_options.M = 4000;
opts.train_classifier_options.lambda = 0.0001;
opts.train_classifier_options.T = 150;
opts.train_classifier_options.cache_dir = '';
opts.train_classifier_options.memToUse = 10;          % GB of memory to use (using "[]" will allow the machine to use all the free memory)
opts.train_classifier_options.useGPU = 1;
opts.train_classifier_options.sigma = 28;
opts.train_classifier_options.kernel = gaussianKernel(opts.train_classifier_options.sigma); 

train_time = tic;
for hard_epoch = 1:max_hard_epochs
  for i = 1:length(imdb.image_ids)
    fprintf('%s: hard neg epoch: %d/%d image: %d/%d\n', ...
            procid(), hard_epoch, max_hard_epochs, i, length(imdb.image_ids));

    % Get hard negatives for all classes at once (avoids loading feature cache
    % more than once)
    [X, keys] = sample_negative_features(first_time, rcnn_model, caches, ...
        imdb, i);

    % Add sampled negatives to each classes training cache, removing
    % duplicates
    for j = imdb.class_ids
      if ~isempty(keys{j})
        if ~isempty(caches{j}.keys_neg)
          [~, ~, dups] = intersect(caches{j}.keys_neg, keys{j}, 'rows');
          assert(isempty(dups));
        end
        caches{j}.X_neg = cat(1, caches{j}.X_neg, X{j});
        caches{j}.keys_neg = cat(1, caches{j}.keys_neg, keys{j});
        caches{j}.num_added = caches{j}.num_added + size(keys{j},1);
      end

      % Update model if
      %  - first time seeing negatives
      %  - more than retrain_limit negatives have been added
      %  - its the final image of the final epoch
      is_last_time = (hard_epoch == max_hard_epochs && i == length(imdb.image_ids));
      hit_retrain_limit = (caches{j}.num_added > caches{j}.retrain_limit);
      if (first_time || hit_retrain_limit || is_last_time) && ...
          ~isempty(caches{j}.X_neg)
        fprintf('>>> Updating %s detector <<<\n', imdb.classes{j});
        fprintf('Cache holds %d pos examples %d neg examples\n', ...
                size(caches{j}.X_pos,1), size(caches{j}.X_neg,1));
        [model] = update_model(caches{j}, opts);
        rcnn_model.detectors.models{j} = model;
        caches{j}.num_added = 0;

        X_neg_GPU = gpuArray(caches{j}.X_neg);
        z_neg = KtsProd_onGPU(X_neg_GPU,  rcnn_model.detectors.models{j}.opts.C, ...
                        rcnn_model.detectors.models{j}.alpha, 1, rcnn_model.detectors.models{j}.opts.kernel);
                    
        z_neg = z_neg(:,2);

        % evict easy examples
        easy = find(z_neg < caches{j}.evict_thresh);
        caches{j}.X_neg(easy,:) = [];
        caches{j}.keys_neg(easy,:) = [];
        fprintf('  Pruning easy negatives\n');
        fprintf('  Cache holds %d pos examples %d neg examples\n', ...
                size(caches{j}.X_pos,1), size(caches{j}.X_neg,1));
        fprintf('  %d neg support vectors\n', numel(find(z_neg > -1 - eps)));
      end
    end
    first_time = false;

    if opts.checkpoint > 0 && mod(i, opts.checkpoint) == 0
      save([conf.cache_dir 'rcnn_model'], 'rcnn_model');
    end
  end
end
fprintf('time required for training: %f seconds\n',toc(train_time));

% save the final rcnn_model
save([conf.cache_dir 'rcnn_model'], 'rcnn_model');
% ------------------------------------------------------------------------

% ------------------------------------------------------------------------
% if opts.k_folds > 0
%   rcnn_k_fold_model = rcnn_model;
%   [W, B, folds] = update_model_k_fold(rcnn_model, caches, imdb);
%   rcnn_k_fold_model.folds = folds;
%   for f = 1:length(folds)
%     rcnn_k_fold_model.detectors(f).W = W{f};
%     rcnn_k_fold_model.detectors(f).B = B{f};
%   end
%   save([conf.cache_dir 'rcnn_k_fold_model'], 'rcnn_k_fold_model');
% else
%   rcnn_k_fold_model = [];
% end
% ------------------------------------------------------------------------
end

% ------------------------------------------------------------------------
function [X_neg, keys] = sample_negative_features(first_time, rcnn_model, ...
                                                  caches, imdb, ind)
% ------------------------------------------------------------------------
opts = rcnn_model.training_opts;

d = cnn_load_cached_pool5_features(opts.cache_name, ...
    imdb.name, imdb.image_ids{ind});

class_ids = imdb.class_ids;

if isempty(d.feat)
  X_neg = cell(max(class_ids), 1);
  keys = cell(max(class_ids), 1);
  return;
end

% d.feat = rcnn_pool5_to_fcX(d.feat, opts.layer, rcnn_model);
d.feat = rcnn_scale_features(d.feat, opts.feat_norm_mean);

neg_ovr_thresh = 0.3;

if first_time
  for cls_id = class_ids
    I = find(d.overlap(:, cls_id) < neg_ovr_thresh);
    X_neg{cls_id} = d.feat(I,:);
    keys{cls_id} = [ind*ones(length(I),1) I];
  end
else
%   zs = bsxfun(@plus, d.feat*rcnn_model.detectors.W, rcnn_model.detectors.B);
  x_feat_gpu = gpuArray(d.feat);
%   zs = KtsProd_onGPU(x_feat_gpu,  rcnn_model.detectors.models{j}.opts.C, ...
%                         rcnn_model.detectors.models{j}.alpha, 1, rcnn_model.detectors.models{j}.opts.kernel);
  for cls_id = class_ids
%     z = zs(:, cls_id);
    z = KtsProd_onGPU(x_feat_gpu,  rcnn_model.detectors.models{cls_id}.opts.C, ...
                        rcnn_model.detectors.models{cls_id}.alpha, 1, rcnn_model.detectors.models{cls_id}.opts.kernel);
    z = z(:,2);
    I = find((z > caches{cls_id}.hard_thresh) & (d.overlap(:, cls_id) < neg_ovr_thresh));

    % Avoid adding duplicate features
    keys_ = [ind*ones(length(I),1) I];
    if ~isempty(caches{cls_id}.keys_neg) && ~isempty(keys_)
      [~, ~, dups] = intersect(caches{cls_id}.keys_neg, keys_, 'rows');
      keep = setdiff(1:size(keys_,1), dups);
      I = I(keep);
    end

    % Unique hard negatives
    X_neg{cls_id} = d.feat(I,:);
    keys{cls_id} = [ind*ones(length(I),1) I];
  end
end
end

% ------------------------------------------------------------------------
function [model] = update_model(cache, opts, pos_inds, neg_inds)
% ------------------------------------------------------------------------
solver = 'liblinear';
liblinear_type = 3;  % l2 regularized l1 hinge loss
%liblinear_type = 5; % l1 regularized l2 hinge loss

if ~exist('pos_inds', 'var') || isempty(pos_inds)%ENTRA QUA
  num_pos = size(cache.X_pos, 1);
  pos_inds = 1:num_pos;
else
  num_pos = length(pos_inds);
  fprintf('[subset mode] using %d out of %d total positives\n', ...
      num_pos, size(cache.X_pos,1));
end
if ~exist('neg_inds', 'var') || isempty(neg_inds)%ENTRA QUA
  num_neg = size(cache.X_neg, 1);
  neg_inds = 1:num_neg;
else
  num_neg = length(neg_inds);
  fprintf('[subset mode] using %d out of %d total negatives\n', ...
      num_neg, size(cache.X_neg,1));
end

%Features adpted to format: n x d matrix
X = zeros(size(cache.X_pos,2), num_pos+num_neg);
X(:,1:num_pos) = cache.X_pos(pos_inds,:)';
X(:,num_pos+1:end) = cache.X_neg(neg_inds,:)';
X = X';

%Labels adpted to format: n x T matrix (T = 2, [bkg, cls])
y = cat(1, ones(num_pos,1), -ones(num_neg,1));
y = cat(2, -y, y);


cobj = [];
callback = @(alpha, cobj) [];
% opts.train_classifier_options.C = Nystrom_centres_choice( cache.X_pos, cache.X_neg, opts.train_classifier_options.M );
opts.train_classifier_options.C = X;
model.opts = opts.train_classifier_options;
model.alpha = falkon(X , opts.train_classifier_options.C , ...
                         opts.train_classifier_options.kernel, y, ...
                         opts.train_classifier_options.lambda, ...
                         opts.train_classifier_options.T, cobj, callback, ...
                         opts.train_classifier_options.memToUse, ...
                         opts.train_classifier_options.useGPU);

end


% ------------------------------------------------------------------------
function [W, B, folds] = update_model_k_fold(rcnn_model, caches, imdb)
% ------------------------------------------------------------------------
opts = rcnn_model.training_opts;
num_images = length(imdb.image_ids);
folds = create_folds(num_images, opts.k_folds);
W = cell(opts.k_folds, 1);
B = cell(opts.k_folds, 1);

fprintf('Training k-fold models\n');
for i = imdb.class_ids
  fprintf('\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  fprintf('Training folds for class %s\n', imdb.classes{i});
  fprintf('~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n');
  for f = 1:length(folds)
    fprintf('Holding out fold %d\n', f);
    [pos_inds, neg_inds] = get_cache_inds_from_fold(caches{i}, folds{f});
    [new_w, new_b] = update_model(caches{i}, opts, ...
        pos_inds, neg_inds);
    W{f}(:,i) = new_w;
    B{f}(i) = new_b;
  end
end
end

% ------------------------------------------------------------------------
function [pos_inds, neg_inds] = get_cache_inds_from_fold(cache, fold)
% ------------------------------------------------------------------------
pos_inds = find(ismember(cache.keys_pos(:,1), fold) == false);
neg_inds = find(ismember(cache.keys_neg(:,1), fold) == false);
end

% ------------------------------------------------------------------------
function [X_pos, keys] = get_positive_pool5_features(imdb, opts)
% ------------------------------------------------------------------------
X_pos = cell(max(imdb.class_ids), 1);
keys = cell(max(imdb.class_ids), 1);

for i = 1:length(imdb.image_ids)
  tic_toc_print('%s: pos features %d/%d\n', ...
                procid(), i, length(imdb.image_ids));

  d = rcnn_load_cached_pool5_features(opts.cache_name, ...
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
% cache.evict_thresh = -1.2;
% cache.hard_thresh = -1.0001;
cache.evict_thresh = -1.0;
cache.hard_thresh = -0.9;
cache.pos_loss = [];
cache.neg_loss = [];
cache.reg_loss = [];
cache.tot_loss = [];
end
