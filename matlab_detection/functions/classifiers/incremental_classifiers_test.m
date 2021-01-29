function  mAP  = incremental_classifiers_test(cache_dir, config, model, imdb, suffix  )

conf.cache_dir = cache_dir;
conf.use_gpu =   config.use_gpu;
if ~exist(conf.cache_dir)
    mkdir(conf.cache_dir);
end
image_ids = imdb.image_ids;

% assume they are all the same
% feat_opts = rcnn_model.training_opts;
feat_opts.cache_name = 'feature_extraction_cache';
feat_opts.layer = 7;


num_classes = length(imdb.classes);

[model, caffe_net]  = cnn_load_model(config, model);

[feat_opts.feat_norm_mean, feat_opts.stdd, feat_opts.mean_feat] = cnn_feature_stats(imdb, feat_opts.layer, model, caffe_net , feat_opts.cache_name);

if ~exist('suffix', 'var') || isempty(suffix)
  suffix = '';
else
  suffix = ['_' suffix];
end

try
  aboxes = cell(num_classes, 1);
  for i = 1:num_classes
    load([conf.cache_dir imdb.classes{i} '_boxes_' imdb.name suffix]);
    aboxes{i} = boxes;
  end
catch
  aboxes = cell(num_classes, 1);
  box_inds = cell(num_classes, 1);
  for i = 1:num_classes
    aboxes{i} = cell(length(image_ids), 1);
    box_inds{i} = cell(length(image_ids), 1);
  end

  % heuristic that yields at most 100k pre-NMS boxes per 2500 images
   max_per_set = ceil(100000/2500)*length(image_ids);
   max_per_image = 100;
   top_scores = cell(num_classes, 1);
   thresh = -inf(num_classes, 1);
   box_counts = zeros(num_classes, 1);

  if ~isfield(model, 'folds')
    folds{1} = 1:length(image_ids);
  else
    folds = model.folds;
  end

  count = 0;

  for f = 1:length(folds)
    for i = folds{f} %for each image
      count = count + 1;
      fprintf('%s: test (%s) %d/%d\n', procid(), imdb.name, count, length(image_ids));
      d = cnn_load_cached_pool5_features(feat_opts.cache_name, imdb.name, image_ids{i});
      if isempty(d.feat)
        continue;
      end
      x_test = d.feat;
      x_test = GURLS_subtract_mean_features(x_test, feat_opts.mean_feat);
      y_predicted = cls_predict(model.w, x_test);
      [y_max, y_max_ids] = max(y_predicted, [], 2);
      
      for j = 1:num_classes %for each class
        boxes = d.boxes; %keep all boxes
        z = y_predicted(:,j);%keep scores for that class
     
        I = find(~d.gt & z > thresh(j) & y_max_ids == j); %keep indexes for those predictions which have score over the class threshold 
        boxes = boxes(I,:);
        scores = z(I);
        aboxes{j}{i} = cat(2, single(boxes), single(scores));
        [~, ord] = sort(scores, 'descend');
        ord = ord(1:min(length(ord), max_per_image));
        aboxes{j}{i} = aboxes{j}{i}(ord, :);
        box_inds{j}{i} = I(ord);
 
        box_counts(j) = box_counts(j) + length(ord);
        top_scores{j} = cat(1, top_scores{j}, scores(ord));
        top_scores{j} = sort(top_scores{j}, 'descend');
        if box_counts(j) > max_per_set
          top_scores{j}(max_per_set+1:end) = [];
          thresh(j) = top_scores{j}(end);
        end
      end    
    end
  end

   for i = 1:num_classes
     % go back through and prune out detections below the found threshold
     for j = 1:length(image_ids)
       if ~isempty(aboxes{i}{j})
         I = find(aboxes{i}{j}(:,end) < thresh(i));
         aboxes{i}{j}(I,:) = [];
         box_inds{i}{j}(I,:) = [];
       end
     end


     save_file = [conf.cache_dir imdb.classes{i} '_boxes_' imdb.name suffix];
     boxes = aboxes{i};
     inds = box_inds{i};
     save(save_file, 'boxes', 'inds');
     clear boxes inds;
  end

end

% ------------------------------------------------------------------------
% Peform AP evaluation
% ------------------------------------------------------------------------
for model_ind = 1:num_classes
  cls = imdb.classes{model_ind};
  res(model_ind) = imdb.eval_func(cls, aboxes{model_ind}, imdb, suffix);
end

if ~isempty(res)
    fprintf('\n~~~~~~~~~~~~~~~~~~~~\n');
    fprintf('Results:\n');
    aps = [res(:).ap]' * 100;
    disp(aps);
    disp(mean(aps));
    fprintf('~~~~~~~~~~~~~~~~~~~~\n');
    mAP = mean(aps);
else
    mAP = nan;
end
    
    diary off;
end

function y_pred = cls_predict(w, x_test)
%%
% x_test = n_test x d
% w = d x T
% y_pred = n_test x T

y_pred = x_test * w;

end
