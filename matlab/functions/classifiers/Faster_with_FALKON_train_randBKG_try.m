function [ rcnn_model ] = Faster_with_FALKON_train_randBKG_try(train_options, config, cnn_model, imdb, negatives_selection, rebalancing, fid, varargin )

%% Parse inputs
ip = inputParser;
ip.addRequired('imdb',                                               @isstruct);
ip.addRequired('negatives_selection',                                @isstruct);
ip.addParamValue('layer',               7,                           @isscalar);
ip.addParamValue('checkpoint',          0,                           @isscalar);
ip.addParamValue('cache_name',          'feature_extraction_cache',  @isstr);
ip.addParamValue('rebal_alpha',         0.5,                         @isscalar);

ip.parse(imdb, negatives_selection, varargin{:});
opts = ip.Results;

opts.negatives_selection = negatives_selection;
opts.train_classifier_options = train_options;
opts.train_classifier_options.kernel = gaussianKernel(opts.train_classifier_options.sigma); 

opts.net_file = cnn_model.binary_file;
opts.net_def_file = cnn_model.net_def_file;

%% Negative selection options
 if strcmp(opts.negatives_selection.policy, 'all_from_M')
     fprintf('All_from_M negatives selection policy chosen \n');
 elseif strcmp(opts.negatives_selection.policy, 'from_all')
     fprintf('from_all negatives selection policy chosen \n');
 else
     fprintf('no negatives selection policy specified, default from_all chosen \n');
 end
 
%% Rebalancing options
if ~exist('rebalancing', 'var') || isempty(rebalancing)
    fprintf('rebalancing disabled \n');
    opts.rebalancing.required = false;
elseif strcmp(rebalancing, 'inv_freq')
    fprintf('inv_freq rebalancing policy chosen \n');
    opts.rebalancing.required = true;
    opts.rebalancing.policy = rebalancing;
    opts.rebalancing.alpha = opts.rebal_alpha;
elseif strcmp(rebalancing, 'prod_freq')
    fprintf('prod_freq rebalancing policy chosen \n');
    opts.rebalancing.required = true;
    opts.rebalancing.policy = rebalancing;
    opts.rebalancing.alpha = opts.rebal_alpha;
else
    fprintf('unrecognized rebalancing policy, Rebalancing disabled \n');
end

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
rcnn_model.classes = imdb.classes;

opts.feat_norm_mean = rcnn_feature_stats(imdb, opts.layer, rcnn_model);
fprintf('average norm = %.3f\n', opts.feat_norm_mean);
rcnn_model.training_opts = opts;

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

%% Get negative examples
save_file_negative = sprintf('./feat_cache/%s/%s/gt_neg_%d%s_cache.mat', rcnn_model.cache_name, imdb.name,opts.negatives_selection.N, opts.negatives_selection.policy);

try
  load(save_file_negative);
  fprintf('Loaded saved negatives from ground truth boxes\n');
catch
  [X_neg, keys_neg] = get_negatives_features(imdb, opts);
  save(save_file_negative, 'X_neg', 'keys_neg', '-v7.3');
end
% Update training caches with negative samples
for i = imdb.class_ids
  fprintf('%14s has %6d negative instances\n', imdb.classes{i}, size(X_neg{i},1));
  fprintf(fid, '%14s has %6d negative instances\n', imdb.classes{i}, size(X_neg{i},1));
  X_neg{i} = rcnn_scale_features(X_neg{i}, opts.feat_norm_mean);
  caches{i}.X_neg =  X_neg{i};
  caches{i}.keys_neg = keys_neg;
end

%% Train models
train_time = tic;
for j = imdb.class_ids
    fprintf('>>> Updating %s detector <<<\n', imdb.classes{j});
    fprintf('Cache holds %d pos examples %d neg examples\n', size(caches{j}.X_pos,1), size(caches{j}.X_neg,1));

    rcnn_model.detectors.models{j} = update_model(caches{j}, opts);
end
fprintf('time required for training %d models: %f seconds\n',length(imdb.class_ids), toc(train_time));
fprintf(fid, 'time required for training %d models: %f seconds\n',length(imdb.class_ids), toc(train_time));

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
opts.train_classifier_options.C = Nystrom_centres_choice( cache.X_pos, cache.X_neg, opts.train_classifier_options.M );

model.opts = opts.train_classifier_options;
model.alpha = falkon(X , opts.train_classifier_options.C , ...
                         opts.train_classifier_options.kernel, y, ...
                         opts.train_classifier_options.lambda, ...
                         opts.train_classifier_options.T, cobj, callback, ...
                         opts.train_classifier_options.memToUse, ...
                         opts.train_classifier_options.useGPU);
                                                 
end

function gamma = computeGamma(Y, policy)
    n_train = size(Y,1);
    [~,tmp] = find(Y == 1);
    a = unique(tmp);
    out = [a,histc(tmp(:),a)];
    p = out(:,2)'/n_train;

    t = numel(p);
    % Compute t x t recoding matrix C
    gamma = zeros(t);
    if strcmp(policy,'inv_freq')
        for i = 1:t
            gamma(i,i) = 1 / p(i);
        end
    elseif strcmp(policy,'prod_freq')
        for i = 1:t
            gamma(i,i) = prod( t * p([1:i-1 , i+1:t]));
        end
    else
        error('policy for computing Gamma not recognized')
    end
end

% ------------------------------------------------------------------------
function [X_pos, keys] = get_positive_features(imdb, opts)
% ------------------------------------------------------------------------
X_pos = cell(max(imdb.class_ids), 1);
keys = cell(max(imdb.class_ids), 1);

for i = 1:length(imdb.image_ids)
  tic_toc_print('%s: pos features %d/%d\n', procid(), i, length(imdb.image_ids));

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

function [X_neg, keys] = get_negatives_features(imdb, opts)
    X_neg = cell(max(imdb.class_ids), 1);
    keys = cell(max(imdb.class_ids), 1);
    
    %Select negatives using policy
    switch opts.negatives_selection.policy
        case {'from_all'}
            fprintf('selecting %d negatives per class from all images \n',opts.negatives_selection.N);
            step = ceil((length(imdb.image_ids)*620)/opts.negatives_selection.N);
            for i = 1:length(imdb.image_ids)
                tic_toc_print('%s: neg features %d/%d\n', procid(), i, length(imdb.image_ids));
        
                d = cnn_load_cached_pool5_features(opts.cache_name, imdb.name, imdb.image_ids{i});        
%                 d.feat = rcnn_scale_features(d.feat, opts.feat_norm_mean);

                neg_ovr_thresh = 0.3;
                for cls_id = imdb.class_ids
                    I = find(d.overlap(:, cls_id) < neg_ovr_thresh);
                    I = I(1:step:length(I));                    
                    cur_neg = d.feat(I,:);
                    cur_keys = [cls_id*ones(length(I),1) I];
                    
                    X_neg{cls_id} = cat(1,X_neg{cls_id},cur_neg);
                    keys{cls_id} = cat(1,keys{cls_id},cur_keys);
                end
            end
        case {'from_part'}
            fprintf('from_part unimplemented\n');

        case {'all_from_M'}
            fprintf('selecting all negatives from %d images \n',opts.negatives_selection.M);
            if(opts.negatives_selection.M>length(imdb.image_ids))
                fprintf('Dataset contains only %d images, I cannot pick %d...\n',length(imdb.image_ids),opts.negatives_selection.M);
                fprintf('Negatives from all the images will be considered.. \n')
               
                
                for i = 1:length(imdb.image_ids)
                    tic_toc_print('%s: neg features %d/%d\n', procid(), i, length(imdb.image_ids));

                    d = cnn_load_cached_pool5_features(opts.cache_name, imdb.name, imdb.image_ids{i});        
                    d.feat = rcnn_scale_features(d.feat, opts.feat_norm_mean);

                    neg_ovr_thresh = 0.3;
                    for cls_id = imdb.class_ids
                        I = find(d.overlap(:, cls_id) < neg_ovr_thresh);                
                        cur_neg = d.feat(I,:);
                        cur_keys = [cls_id*ones(length(I),1) I];

                        X_neg{cls_id} = cat(1,X_neg{cls_id},cur_neg);
                        keys{cls_id} = cat(1,keys{cls_id},cur_keys);
                    end
                end
            else
                fprintf('Dataset contains %d images, I will pick the negatives from %d of them...\n',length(imdb.image_ids),opts.negatives_selection.M);
                
                rand_inds = randi([1 1071], 1,opts.negatives_selection.M);
                fprintf('Chosen indexes are: \n')
                disp(rand_inds);
                
                for i = 1:length(rand_inds)
                    tic_toc_print('%s: neg features %d/%d\n', procid(), i, length(rand_inds));

                    d = cnn_load_cached_pool5_features(opts.cache_name, imdb.name, imdb.image_ids{rand_inds(i)});        
                    d.feat = rcnn_scale_features(d.feat, opts.feat_norm_mean);

                    neg_ovr_thresh = 0.3;
                    for cls_id = imdb.class_ids
                        I = find(d.overlap(:, cls_id) < neg_ovr_thresh);                
                        cur_neg = d.feat(I,:);
                        cur_keys = [cls_id*ones(length(I),1) I];

                        X_neg{cls_id} = cat(1,X_neg{cls_id},cur_neg);
                        keys{cls_id} = cat(1,keys{cls_id},cur_keys);
                    end
                end
            end

        otherwise
            error('Nevatives selection policy unknown');
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
