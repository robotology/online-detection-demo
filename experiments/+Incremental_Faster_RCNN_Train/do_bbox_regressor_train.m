function [ bbox_reg ] = do_bbox_regressor_train(conf, cnn_model, imdb_train, roidb_train )


% load the rcnn_model trained by rcnn_exp_train_and_test()
% conf = rcnn_config('sub_dir', imdb_train.name);
% ld = load([conf.cache_dir 'rcnn_model']);

% train the bbox regression model
bbox_reg = cnn_train_bbox_regressor(conf, imdb_train, roidb_train, cnn_model, ...
    'min_overlap', 0.6, ...
    'layer', 5, ...
    'lambda', 1000, ...
    'robust', 0, ...
    'binarize', false);

end

