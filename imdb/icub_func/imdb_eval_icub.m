function res = imdb_eval_icub(cls, boxes, imdb, cache_name, suffix)

% Add a random string ("salt") to the end of the results file name
% to prevent concurrent evaluations from clobbering each other
use_res_salt = true;
% Delete results files after computing APs
rm_res = true;
% comp4 because we use outside data (ILSVRC2012)
comp_id = 'comp4';
% draw each class curve
draw_curve = true; %ELISA check

% save results
if ~exist('suffix', 'var') || isempty(suffix) || strcmp(suffix, '')
  suffix = '';
else
  if suffix(1) ~= '_'
    suffix = ['_' suffix];
  end
end
conf = struct;
conf.cache_dir = fullfile('output', 'fast_rcnn_cachedir', cache_name, imdb.name);
ICUBopts  = imdb.details.ICUBopts;
image_ids = imdb.image_ids;
% test_set = ICUBopts.testset;
% year = ICUBopts.dataset(4:end);

if use_res_salt
  prev_rng = rng;
  rng shuffle;
  salt = sprintf('%d', randi(100000));
  res_id = [comp_id '-' salt];
  rng(prev_rng);
else
  res_id = comp_id;
end
res_fn = sprintf(ICUBopts.detrespath, res_id, cls);
fprintf('schifo di path: %s \n',res_fn)
% write out detections in PASCAL format and score
fid = fopen(res_fn, 'w');
for i = 1:length(image_ids);
  bbox = boxes{i};
  keep = nms(bbox, 0.3);
  bbox = bbox(keep,:);
  for j = 1:size(bbox,1)
    fprintf(fid, '%s %f %.3f %.3f %.3f %.3f\n', image_ids{i}, bbox(j,end), bbox(j,1:4));
  end
end
fclose(fid);

recall = [];
prec = [];
ap = 0;
ap_auc = 0;

% do_eval = (str2num(year) <= 2007) | ~strcmp(test_set, 'test');
do_eval = true;
if do_eval
  % Bug in ICUBevaldet requires that tic has been called first
  tic;
  [recall, prec, ap] = VOCevaldet_reduced(ICUBopts, res_id, cls, draw_curve,imdb.removed_classes);
  ap_auc = xVOCap(recall, prec);

  % force plot limits
  ylim([0 1]);
  xlim([0 1]);

%   print(gcf, '-djpeg', '-r0', ...
%         fullfile(conf.cache_dir, [cls '_pr_' imdb.name suffix '.jpg']));
end
fprintf('!!! %s : %.4f %.4f\n', cls, ap, ap_auc);

save(fullfile(conf.cache_dir,  [cls '_pr_' imdb.name suffix]), ...
    'recall', 'prec', 'ap', 'ap_auc');

res.recall = recall;
res.prec = prec;
res.ap = ap;
res.ap_auc = ap_auc;
if rm_res
  delete(res_fn);
end
