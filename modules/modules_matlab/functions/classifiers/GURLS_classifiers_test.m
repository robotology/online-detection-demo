function [ res ] = GURLS_classifiers_test( config, rcnn_model, imdb, suffix  )



conf.cache_dir = 'cache_classifiers/gurls/';
conf.use_gpu =   config.use_gpu;
if ~exist(conf.cache_dir)
    mkdir(conf.cache_dir);
end
image_ids = imdb.image_ids;

% assume they are all the same
feat_opts = rcnn_model.training_opts;
num_classes = length(imdb.classes);

[rcnn_model, caffe_net]  = cnn_load_model(config, rcnn_model);

if ~exist('suffix', 'var') || isempty(suffix)
  suffix = '';
else
  suffix = ['_' suffix];
end

try
  aboxes = cell(num_classes, 1);
  for i = 1:num_classes
    load([conf.cache_dir rcnn_model.classes{i} '_boxes_' imdb.name suffix]);
    aboxes{i} = boxes;
  end

catch
  aboxes = cell(num_classes, 1);
  box_inds = cell(num_classes, 1);
  for i = 1:num_classes
    aboxes{i} = cell(length(image_ids), 1);
    box_inds{i} = cell(length(image_ids), 1);
  end

  % heuristic that yields at most 100k pre-NMS boxes
  % per 2500 images
  max_per_set = ceil(100000/2500)*length(image_ids);
  max_per_image = 100;
  top_scores = cell(num_classes, 1);
  thresh = -inf(num_classes, 1);
  box_counts = zeros(num_classes, 1);

  if ~isfield(rcnn_model, 'folds')
    folds{1} = 1:length(image_ids);
  else
    folds = rcnn_model.folds;
  end

  count = 0;
  for f = 1:length(folds)
    for i = folds{f}
      count = count + 1;
      fprintf('%s: test (%s) %d/%d\n', procid(), imdb.name, count, length(image_ids));
      d = cnn_load_cached_pool5_features(feat_opts.cache_name, ...
          imdb.name, image_ids{i});
      if isempty(d.feat)
        continue;
      end
      d.feat = cnn_pool5_to_fcX(d.feat, feat_opts.layer, rcnn_model, caffe_net);
      d.feat = SVM_scale_features(d.feat, feat_opts.feat_norm_mean);
      zs = bsxfun(@plus, d.feat*rcnn_model.detectors(f).W, rcnn_model.detectors(f).B);

      for j = 1:num_classes
        boxes = d.boxes;
        z = zs(:,j);
        I = find(~d.gt & z > thresh(j));
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

    save_file = [conf.cache_dir rcnn_model.classes{i} '_boxes_' imdb.name suffix];
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
  cls = rcnn_model.classes{model_ind};
  res(model_ind) = imdb.eval_func(cls, aboxes{model_ind}, imdb, suffix);
end

fprintf('\n~~~~~~~~~~~~~~~~~~~~\n');
fprintf('Results:\n');
aps = [res(:).ap]';
disp(aps);
disp(mean(aps));
fprintf('~~~~~~~~~~~~~~~~~~~~\n');



