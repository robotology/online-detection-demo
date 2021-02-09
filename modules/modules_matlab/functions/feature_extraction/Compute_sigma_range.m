function [ sigma_range ] = Compute_sigma_range( imdb,  opts, fid)

rcnn_model.cache_name = opts.cache_name;

opts.feat_norm_mean = rcnn_feature_stats(imdb, opts.layer, rcnn_model);

%% Get all positive examples
save_file = sprintf('./feat_cache/%s/%s/gt_pos_layer_5_cache.mat', opts.cache_name, imdb.name);

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
save_file_negative = sprintf('./feat_cache/%s/%s/gt_neg_%d%s_cache_.mat', opts.cache_name, imdb.name,opts.negatives_selection.N, opts.negatives_selection.policy);

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

    % Features adpted to format: n x d matrix
    num_pos = size(caches{1}.X_pos, 1);
    pos_inds = 1:num_pos;
    num_neg = size(caches{1}.X_neg, 1);
    neg_inds = 1:num_neg;
    
    X = zeros(size( caches{1}.X_pos,2), num_pos+num_neg);
    X(:,1:num_pos) =  caches{1}.X_pos(pos_inds,:)';
    X(:,num_pos+1:end) =  caches{1}.X_neg(neg_inds,:)';
    X = X';

%     y = cat(1, ones(num_pos,1), -ones(num_neg,1));
%     y = cat(2, -y, y);

    C = Nystrom_centres_choice(  caches{1}.X_pos,  caches{1}.X_neg, opts.train_classifier_options.M );
    
    obj.n = num_pos+num_neg;
    obj.m = size(C, 1);
    obj.choose_sigma_range = true;
    obj.max_longD_size = 1000000; % ????????????????????????
    obj.blk_n = 1;
    obj.blk_m = 1;
    obj.Xny = C;
    obj.Xtr = X;
    obj.kern_dist = @(X1,X2) sqdist(X1,X2);
    obj.numel_range = 10^7;  % ????????????????????????
    obj.sigma_numel = 10;
    
    sigma_range = computeDistances(obj);



end

%% ---------------------------------------------------------------------------------------------------------------------------   

function sigma_range = computeDistances(obj)

    n = obj.n;
    m = obj.m;
    
    blk_n = obj.blk_n;
    blk_m = obj.blk_m;

    
    if obj.choose_sigma_range
        hist_sigma = [];
        longD = zeros(obj.max_longD_size,1);
        longD_curr_idx = 1;
    end

   
    
    for j = 1:blk_m
        
        fprintf('Doing iteration %d of blk_m=%d\n', j, blk_m)
        

        Xcp_m = obj.Xny;
        % training set
        for i = 1:blk_n
            

            Xcp_n = obj.Xtr;
            
            D = obj.kern_dist(Xcp_n,Xcp_m);

      
            if obj.choose_sigma_range
                D(D==0) = [];
                
                if numel(hist_sigma)>0
                    hist_sigma = hist_sigma + hist(D,hist_range);
                else                    
                    tmp_s = min(longD_curr_idx-1+numel(D),obj.max_longD_size);
                    longD(longD_curr_idx:tmp_s) = D(1:(tmp_s-longD_curr_idx+1));

                    longD_curr_idx = longD_curr_idx + numel(D) + 1;
                                            
                    if longD_curr_idx >= numel(longD);    
                        hist_range = linspace(min(longD),max(longD),obj.numel_range);
                        hist_sigma = hist(longD,hist_range);    
                        clear longD;
                        longD_curr_idx = 0;
                    end
                end
                
                
                
            end
            
            clear D;
            clear Xcp_n;
        end

    % if we are also choosing the range for sigma
    if obj.choose_sigma_range

        if exist('longD','var')>0;
            longD(longD_curr_idx:end) = [];
            hist_range = linspace(min(longD),max(longD),obj.numel_range);
            hist_sigma = hist(longD,hist_range);    
            clear longD;
        end
        
        
        % find the sigma range
        int_hist_sigma = cumsum(hist_sigma);

        tmp_itr = 1;
        tmp_thresh = 0.01*int_hist_sigma(end);
        while tmp_itr < obj.numel_range
            if int_hist_sigma(tmp_itr) > tmp_thresh
                break;
            end
            tmp_itr = tmp_itr + 1;
        end
        sigma_min = hist_range(tmp_itr);

        tmp_itr = obj.numel_range;
        tmp_thresh = 0.99*int_hist_sigma(end);
        while tmp_itr < obj.numel_range
            if int_hist_sigma(tmp_itr) < tmp_thresh
                break;
            end
            tmp_itr = tmp_itr + -1;
        end
        sigma_max = hist_range(tmp_itr);

        q = (sigma_max/sigma_min)^(1/(obj.sigma_numel - 1));

        % finally get the sigma range
        sigma_range = sigma_min*(q.^(obj.sigma_numel:-1:0));    
    end
    
    end
end
    
% utilities
function [vmin,vmax,len] = compute_vmin_vmax(~,idx,sbl,size)
    vmin = (idx-1)*sbl + 1;
    vmax = min(sbl*idx, size);
    len = vmax-vmin+1;
end

function D = sqdist(A,B)
    if (size(A,2) ~= size(B,2))
       error('A and B should be of same dimensionality');
    end
    AA=sum(A.*A,2); BB=sum(B.*B,2); AB=A*B';
    D = (abs(repmat(AA,[1 size(B,1)]) + repmat(BB',[size(A,1) 1]) - 2*AB));
end
%% ---------------------------------------------------------------------------------------------------------------------------   


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
end
