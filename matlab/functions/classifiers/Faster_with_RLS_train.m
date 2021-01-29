function [ rcnn_model ] = Faster_with_RLS_train(train_options, config, cnn_model, imdb, varargin )
%FASTER_WITH_RLS_TRAIN Summary of this function goes here
%   Detailed explanation goes here

ip = inputParser;
ip.addRequired('imdb', @isstruct);
ip.addParamValue('svm_C',           10^-3,  @isscalar);
ip.addParamValue('bias_mult',       10,     @isscalar);
ip.addParamValue('pos_loss_weight', 2,      @isscalar);
ip.addParamValue('layer',           7,      @isscalar);
ip.addParamValue('k_folds',         2,      @isscalar);
ip.addParamValue('checkpoint',      0,      @isscalar);
ip.addParamValue('crop_mode',       'warp', @isstr);
ip.addParamValue('crop_padding',    16,     @isscalar);
% ip.addParamValue('net_file', './data/caffe_nets/finetune_voc_2007_trainval_iter_70k', @isstr);
ip.addParamValue('cache_name', 'feature_extraction_cache', @isstr);
ip.addParamValue('rebalancing', true, @isboolean);

ip.parse(imdb, varargin{:});
opts = ip.Results;

opts.net_file = cnn_model.binary_file;
opts.net_def_file = cnn_model.net_def_file;

%DA CONTROLLARE
conf = rcnn_config('sub_dir', imdb.name);
conf.cache_dir = train_options.cache_dir;
conf.use_gpu =   config.use_gpu;

% Record a log of the training and test procedure
timestamp = datestr(datevec(now()), 'dd.mmm.yyyy:HH.MM.SS');
diary_file = [conf.cache_dir 'rcnn_train_' timestamp '.txt'];
diary(diary_file);
fprintf('Logging output in %s\n', diary_file);

fprintf('\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
fprintf('Training options:\n');
disp(opts);
fprintf('~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n');

% Create a new rcnn model
%DA CONTROLLARE
rcnn_model = gurls_create_model(opts.net_def_file, opts.net_file, opts.cache_name); %MODIFICATO
% rcnn_model = cnn_load_model(cnn_model, conf.use_gpu);
[rcnn_model, caffe_net]  = cnn_load_model(config, cnn_model);
rcnn_model.detectors.crop_mode = opts.crop_mode;
rcnn_model.detectors.crop_padding = opts.crop_padding;
rcnn_model.classes = imdb.classes;

%DA CONTROLLARE
% [mean_norm, stdd, mean_feat] = cnn_feature_stats(imdb, opts.layer,
% cache_dir);
% opts.feat_norm_mean = mean_norm;
%DA CAMBIARE IN FUTURO
opts.feat_norm_mean = rcnn_feature_stats(imdb, opts.layer, rcnn_model); %OK
fprintf('average norm = %.3f\n', opts.feat_norm_mean);
rcnn_model.training_opts = opts;%Save the final model
% ------------------------------------------------------------------------

% ------------------------------------------------------------------------
% Get all positive examples
% We cache only the pool5 features and convert them on-the-fly to
% fc6 or fc7 as required
save_file = sprintf('./feat_cache/%s/%s/gt_pos_layer_5_cache.mat', rcnn_model.cache_name, imdb.name);

try
  load(save_file);
  fprintf('Loaded saved positives from ground truth boxes\n');
catch
  [X_pos, keys_pos] = get_positive_pool5_features(imdb, opts);
  save(save_file, 'X_pos', 'keys_pos', '-v7.3');
end
% Init training caches
caches = {};
for i = imdb.class_ids
  fprintf('%14s has %6d positive instances\n', imdb.classes{i}, size(X_pos{i},1));
  
  % NON DOVREBBE SERVIRE DATO CHE GI? ESTRAGGO FC7
%   X_pos{i} = rcnn_pool5_to_fcX(X_pos{i}, opts.layer, rcnn_model);
  X_pos{i} = rcnn_scale_features(X_pos{i}, opts.feat_norm_mean);

  caches{i} = init_cache(X_pos{i}, keys_pos{i});
end
% ------------------------------------------------------------------------

% ------------------------------------------------------------------------
% Train with hard negative mining
first_time = true;
% one pass over the data is enough
max_hard_epochs = 1;

for hard_epoch = 1:max_hard_epochs
  for i = 1:length(imdb.image_ids)
    fprintf('%s: hard neg epoch: %d/%d image: %d/%d\n', ...
            procid(), hard_epoch, max_hard_epochs, i, length(imdb.image_ids));

    % Get hard negatives for all classes at once (avoids loading feature cache
    % more than once)
    %CAMBIATA IMPLEMENTAZIONE DI PARTE DEGLI HARD NEGATIVES
    [X, keys] = sample_negative_features(first_time, rcnn_model, caches, imdb, i);

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
%       if (first_time || hit_retrain_limit || is_last_time) && ...
%           ~isempty(caches{j}.X_neg)
        if (first_time || hit_retrain_limit) && ...
          ~isempty(caches{j}.X_neg)
        fprintf('>>> Updating %s detector <<<\n', imdb.classes{j});
        fprintf('Cache holds %d pos examples %d neg examples\n', ...
                size(caches{j}.X_pos,1), size(caches{j}.X_neg,1));
            
        %CAMBIATO
        rcnn_model.detectors.models{j} = update_model(caches{j}, opts);
        caches{j}.num_added = 0;

        
        %CAMBIATO DA TESTARE
        z_neg = gurls_test(rcnn_model.detectors.models{j}, caches{j}.X_neg);
        
        % evict easy examples
        easy = find(z_neg(:,2) <= caches{j}.evict_thresh);
        caches{j}.X_neg(easy,:) = [];
        caches{j}.keys_neg(easy,:) = [];
        fprintf('  Pruning easy negatives\n');
        fprintf('  Cache holds %d pos examples %d neg examples\n', ...
                size(caches{j}.X_pos,1), size(caches{j}.X_neg,1));
      end
    end
    first_time = false;

    if opts.checkpoint > 0 && mod(i, opts.checkpoint) == 0
      save([conf.cache_dir 'rcnn_model'], 'rcnn_model');
    end
  end
end
% save the final rcnn_model
save([conf.cache_dir 'rls_model'], 'rcnn_model');
% -----------------------------------------------------------------------

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
  %IMPLEMENTATA, DA TESTARE
%   zs = predict_all_gurls( d.feat, rcnn_model.detectors.models, class_ids);
  for cls_id = class_ids
    z1 = gurls_test(rcnn_model.detectors.models{cls_id}, d.feat);
    z = z1(:,2);
    I = find((z > caches{cls_id}.hard_thresh) & ...
             (d.overlap(:, cls_id) < neg_ovr_thresh));

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

%FUNZIONE DA CONTROLLARE
function y_predicted = predict_all_gurls(x_test, models, class_ids)
    y_predicted = zeros(size(x_test,1), length(class_ids));
    for class_id = class_ids
        y_predicted(:, cls_id) = gurls_test(models{cls_id}.gurlsOpt{1, 1}.model_classifier, x_test);
    end
end

% ------------------------------------------------------------------------
function [model] = update_model(cache, opts, pos_inds, neg_inds)
% ------------------------------------------------------------------------

if ~exist('pos_inds', 'var') || isempty(pos_inds)
  num_pos = size(cache.X_pos, 1);
  pos_inds = 1:num_pos;
else
  num_pos = length(pos_inds);
  fprintf('[subset mode] using %d out of %d total positives\n', ...
      num_pos, size(cache.X_pos,1));
end
if ~exist('neg_inds', 'var') || isempty(neg_inds)
  num_neg = size(cache.X_neg, 1);
  neg_inds = 1:num_neg;
else
  num_neg = length(neg_inds);
  fprintf('[subset mode] using %d out of %d total negatives\n', ...
      num_neg, size(cache.X_neg,1));
end

%DA VEDERE IN CHE FORMATO SONO I DATI
X = zeros(size(cache.X_pos,2), num_pos+num_neg);
X(:,1:num_pos) = cache.X_pos(pos_inds,:)';
X(:,num_pos+1:end) = cache.X_neg(neg_inds,:)';

%Features adpted to GURLS format: n x d matrix
X = X';

y = cat(1, ones(num_pos,1), -ones(num_neg,1));

%Labels adpted to GURLS format: n x T matrix (T = 2, [bkg, cls])
y = cat(2, -y, y);

%AGGIUNTO
% train_classifier_options definition
train_classifier_options = struct;
train_classifier_options.gurlsOptions = struct;
train_classifier_options.gurlsOptions.kernelfun = 'linear';
% train_classifier_options.gt_regions = 1; %1 = gt regions, 0 = proposals with iou > thresh
% train_classifier_options.subtract_mean = 1; % 1 = feature mean subtraction
% train_classifier_options.cache_dir = 'cache_classifiers/gurls/';

%For rebalancing
if opts.rebalancing
    train_classifier_options.gurlsOptions.rebalancing = true;
    train_classifier_options.gurlsOptions.AlphaElisa = 0.7;
    train_classifier_options.gurlsOptions.GammaElisa = computeGamma(y);
else
    model.rebalancing = false;
%     model.rls.Alpha = 0.7;
%     model.rls.Gamma = gamma;
end

model = gurls_train(X, y, train_classifier_options.gurlsOptions);

end

function gamma = computeGamma(Y)
    n_train = size(Y,1);
    [~,tmp] = find(Y == 1);
    a = unique(tmp);
    out = [a,histc(tmp(:),a)];
    p = out(:,2)'/n_train;

    t = numel(p);
    % Compute t x t recoding matrix C
    gamma = zeros(t);
    for i = 1:t
%         gamma(i,i) = prod( t * p([1:i-1 , i+1:t]));
        gamma(i,i) = 1 / p(i);
    end
end

% ------------------------------------------------------------------------
function [X_pos, keys] = get_positive_pool5_features(imdb, opts)
% ------------------------------------------------------------------------
X_pos = cell(max(imdb.class_ids), 1);
keys = cell(max(imdb.class_ids), 1);

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
%CHANGED THRESHOLD
cache.evict_thresh = -1;
cache.hard_thresh = -0.7;
% cache.evict_thresh = -1.2;
% cache.hard_thresh = -1.0001;
cache.pos_loss = [];
cache.neg_loss = [];
cache.reg_loss = [];
cache.tot_loss = [];
end
