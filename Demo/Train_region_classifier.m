function [ rcnn_model ] = Train_region_classifier( dataset, opts )
%TRAIN_REGION_CLASSIFIER Summary of this function goes here
%   Detailed explanation goes here

%% 
num_classes = length(dataset);

for i =1:num_classes
    X_pos = dataset{i}.pos_region_classifier;
    X_neg = dataset{i}.neg_region_classifier;
    
    cache       = struct;
    cache.X_pos = zscores_standardization(X_pos.feat, opts.statistics.standard_deviation,...
                                                      opts.statistics.mean_feat, ...
                                                      opts.statistics.mean_norm);
    
    X_neg       = zscores_standardization(X_neg.feat, opts.statistics.standard_deviation,...
                                                      opts.statistics.mean_feat, ...
                                                      opts.statistics.mean_norm);
    
    train_time    = tic;
    
    first_time    = true;
    first_neg_idx = 1;
    last_neg_idx  = opts.negatives_selection.batch_size;
    for b = 1:opts.negatives_selection.iterations
        if first_time     
            if last_neg_idx > size(X_neg,1)
                last_neg_idx = size(X_neg,1);
                disp('last_neg_idx lower than X_neg size*******************');
            end
            cache.X_neg =  X_neg(first_neg_idx:last_neg_idx,:); % TO-CHECK-----------------------------------------------------------------------------------------
            fprintf('Cache holds %d pos examples %d neg examples\n', ...
                    size(cache.X_pos,1), size(cache.X_neg,1));
            first_time = false;
        else
            if last_neg_idx > size(X_neg,1)
                last_neg_idx = size(X_neg,1);
                disp('last_neg_idx lower than X_neg size*******************');
            end
            X_neg_batch = X_neg(first_neg_idx:last_neg_idx,:);
            X_neg_GPU = gpuArray(X_neg_batch);  % TO-CHECK-----------------------------------------------------------------------------------------
            z_neg = KtsProd_onGPU(X_neg_GPU,  rcnn_model.detectors.models{i}.opts.C, ...
                                  rcnn_model.detectors.models{i}.alpha, 1, rcnn_model.detectors.models{i}.opts.kernel);
                        
            z_neg = z_neg(:,2);
            hard = find(z_neg > opts.negatives_selection.select_hard_thresh);
                       
            cache.X_neg = cat(1, cache.X_neg, X_neg_batch(hard,:));% Da sistemare----------------------------------------------------------------------
            fprintf('  After selecting hard, Cache holds %d pos examples %d neg examples\n', ...
                    size(cache.X_pos,1), size(cache.X_neg,1));
            fprintf('  Selected hard negatives\n');
            
           
        end
%         fprintf('>>> Updating %s detector <<<\n', imdb.classes{j});
        fprintf('>>> Updating %d detector <<<\n', i);
        
        rcnn_model.detectors.models{i} = update_model(cache, opts);
        
        if b ~= opts.negatives_selection.iterations % Don't do it after last update (or maybe yes......???)
            fprintf('  Pruning easy negatives\n');           
            new_X_neg_GPU = gpuArray(cache.X_neg);
            new_z_neg = KtsProd_onGPU(new_X_neg_GPU,  rcnn_model.detectors.models{i}.opts.C, ...
                            rcnn_model.detectors.models{i}.alpha, 1, rcnn_model.detectors.models{i}.opts.kernel);

            new_z_neg = new_z_neg(:,2);
            easy = find(new_z_neg < opts.negatives_selection.evict_easy_thresh);
            cache.X_neg(easy,:) = [];
%             cache.keys_neg(easy,:) = [];
            fprintf('  Cache holds %d pos examples %d neg examples\n', ...
                    size(cache.X_pos,1), size(cache.X_neg,1));
        end
        first_neg_idx = first_neg_idx + opts.negatives_selection.batch_size;
        last_neg_idx  = last_neg_idx  + opts.negatives_selection.batch_size;
    end

end
fprintf('time required for training %d models: %f seconds\n', num_classes, toc(train_time));

end

function model =  update_model(cache, opts)

    num_pos = size(cache.X_pos, 1);
    pos_inds = 1:num_pos;
    num_neg = size(cache.X_neg, 1);
    neg_inds = 1:num_neg;
    
    switch opts.cls_mod
        case {'FALKON'}
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
            opts.train_classifier_options.C = Nystrom_centres_choice(cache.X_pos, cache.X_neg, opts.train_classifier_options.M);
            model.opts = opts.train_classifier_options;
            model.alpha = falkon(X , opts.train_classifier_options.C , ...
                                     opts.train_classifier_options.kernel, y, ...
                                     opts.train_classifier_options.lambda, ...
                                     opts.train_classifier_options.T, cobj, callback, ...
                                     opts.train_classifier_options.memToUse, ...
                                     opts.train_classifier_options.useGPU);
                                                 
        otherwise
            error('classifier unknown');    
    end

end