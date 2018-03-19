function do_extract_features(conf, model, layer, imdb, roidb)

% -------------------- CONFIG --------------------
% net_file     = './data/caffe_nets/finetune_voc_2007_trainval_iter_70k';
% model.cache_name   = 'cache_extraction_feature_TASK2expModel_fakeExp';
% model.crop_mode    = 'warp'; 
% model.crop_padding = 16;
% change to point to your icub_dev install
% icub_dev                      = './datasets/iCubWorld-Transformations_devkit';
% ------------------------------------------------

% cache_name = 'features_full_voc2007_faster_80k40k';
fprintf('Feature extraction details:\n');
fprintf(strcat('layer: ', layer));
fprintf(strcat('of dataset: ', imdb.name))

cache_features(conf, model, imdb, roidb, layer, 'cache_name', model.cache_name);



end



