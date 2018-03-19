function [ res ] = cnn_test_bbox_regressor( conf, imdb, rcnn_model, bbox_reg, suffix, fid )
% conf = rcnn_config('sub_dir', imdb.name);
image_ids = imdb.image_ids;
conf.cache_dir = conf.boxes_dir;
feat_opts.cache_name = 'feature_extraction_cache';
feat_opts.layer = 7;
caffe_net=[];

% assume they are all the same
feat_opts = bbox_reg.training_opts;
num_classes = length(imdb.classes);

if ~exist('suffix', 'var') || isempty(suffix)
  suffix = '_bbox_reg';
else
  if suffix(1) ~= '_'
    suffix = ['_' suffix];
  end
end

%Try to load existing bbox predictions, otherwise predict them
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
    load([conf.cache_dir imdb.classes{i} '_boxes_' imdb.name]);
    aboxes{i} = boxes;
    box_inds{i} = inds;
    clear boxes inds;
  end
  
%   [feat_opts.feat_norm_mean, feat_opts.stdd, feat_opts.mean_feat] = cnn_feature_stats(imdb, feat_opts.layer, rcnn_model, caffe_net , feat_opts.cache_name);
  feat_opts.feat_norm_mean = rcnn_feature_stats(imdb, feat_opts.layer, rcnn_model); %OK

  tic
  for i = 1:length(image_ids)
    fprintf('%s: bbox reg test (%s) %d/%d\n', procid(), imdb.name, i, length(image_ids));
    d = cnn_load_cached_pool5_features(feat_opts.cache_name, ...
        imdb.name, image_ids{i});
    if isempty(d.feat)
      continue;
    end

%     d.feat = cnn_pool5_to_fcX(d.feat, feat_opts.layer, rcnn_model);
%     d.feat = cnn_scale_features(d.feat, feat_opts.feat_norm_mean);
%     d.feat = GURLS_subtract_mean_features(d.feat, feat_opts.mean_feat);


    if feat_opts.binarize
      d.feat = single(d.feat > 0);
    end

    for j = 1:num_classes
      I = box_inds{j}{i};
      boxes = aboxes{j}{i};
      if ~isempty(boxes)
        scores = boxes(:,end);
        boxes = boxes(:,1:4);
        assert(sum(sum(abs(d.boxes(I,:) - boxes))) == 0);
        boxes = rcnn_predict_bbox_regressor(bbox_reg.models{j}, d.feat(I,:), boxes);
        boxes(:,1) = max(boxes(:,1), 1);
        boxes(:,2) = max(boxes(:,2), 1);
        boxes(:,3) = min(boxes(:,3), imdb.sizes(i,2));
        boxes(:,4) = min(boxes(:,4), imdb.sizes(i,1));
        aboxes{j}{i} = cat(2, single(boxes), single(scores));

        if 0
          % debugging visualizations
          im = imread(imdb.image_at(i));
          keep = nms(aboxes{j}{i}, 0.3);
          for k = 1:min(10, length(keep))
            if aboxes{j}{i}(keep(k),end) > -0.9
              showboxes(im, aboxes{j}{i}(keep(k),1:4));
              title(sprintf('%s %d score: %.3f\n', rcnn_model.classes{j}, ...
                  k, aboxes{j}{i}(keep(k),end)));
              pause;
            end
          end
        end
      end
    end
  end
  fprintf('time required for testing 7 regressors over %d images: %f seconds\n', length(image_ids),toc);
  fprintf(fid, 'time required for testing 7 regressors over %d images: %f seconds\n', length(image_ids),toc)

 for i = 1:num_classes
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
  try
    ld = load([conf.cache_dir cls '_pr_' imdb.name suffix]);
    fprintf('!!! %s : %.4f %.4f\n', cls, ld.res.ap, ld.res.ap_auc);
    res(model_ind) = ld.res;
  catch
    res(model_ind) = imdb.eval_func(cls, aboxes{model_ind}, imdb, '');
  end
end

fprintf('\n~~~~~~~~~~~~~~~~~~~~\n');
fprintf('Results (bbox reg):\n');
aps = [res(:).ap]'* 100;
disp(aps);
disp(mean(aps));
fprintf('~~~~~~~~~~~~~~~~~~~~\n');

fprintf(fid, '\n~~~~~~~~~~~~~~~~~~~~\n');
fprintf(fid, 'Results:\n');
aps = [res(:).ap]'* 100;
fprintf(fid, '%f\n%f\n%f\n%f\n%f\n%f\n%f\n\n',aps);
fprintf(fid, 'mAP: %f\n',mean(aps));
fprintf(fid, '~~~~~~~~~~~~~~~~~~~~\n');

