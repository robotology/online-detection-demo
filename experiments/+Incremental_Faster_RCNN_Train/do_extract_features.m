function do_extract_features(conf, model, chunk, imdb, roidb)

% -------------------- CONFIG --------------------
% net_file     = './data/caffe_nets/finetune_voc_2007_trainval_iter_70k';
% model.cache_name   = 'cache_extraction_feature_TASK2expModel_fakeExp';
% model.crop_mode    = 'warp'; 
% model.crop_padding = 16;
% change to point to your icub_dev install
% icub_dev                      = './datasets/iCubWorld-Transformations_devkit';
% ------------------------------------------------

% imdb_train = imdb_from_icub(icub_dev, 'train');
% imdb_val   = imdb_from_icub(icub_dev, 'val');
% imdb_test  = imdb_from_icub(icub_dev, 'test');
% imdb_trainval = imdb_from_voc(icub_dev, 'trainval');

switch chunk
  case 'train'
    cache_fc7_features(conf, model, imdb, roidb);
%     link_up_trainval(cache_name, imdb_train, imdb_trainval); %ELISA dato per buono
%     link_up_trainval(cache_name, imdb_train);
  case 'test'
    end_at = ceil(length(imdb_test.image_ids)/2);
    cache_fc7_features(imdb_test, ...
        'start', 1, 'end', end_at, ...
        'net_file', net_file, ...
        'cache_name', cache_name);
%   case 'test_2'
%     start_at = ceil(length(imdb_test.image_ids)/2)+1;
%     rcnn_cache_pool5_features(imdb_test, ...
%         'start', start_at, ...
%         'crop_mode', crop_mode, ...
%         'crop_padding', crop_padding, ...
%         'net_file', net_file, ...
%         'cache_name', cache_name);
end


% ------------------------------------------------------------------------
function link_up_trainval(cache_name, imdb_split, imdb_trainval)
% ------------------------------------------------------------------------
cmd = {['mkdir -p ./feat_cache/' cache_name '/' imdb_trainval.name '; '], ...
    ['cd ./feat_cache/' cache_name '/' imdb_trainval.name '/; '], ...
    ['for i in `ls -1 ../' imdb_split.name '`; '], ... 
    ['do ln -s ../' imdb_split.name '/$i $i; '], ... 
    ['done;']};
cmd = [cmd{:}];
fprintf('running:\n%s\n', cmd);
system(cmd);
fprintf('done\n');


