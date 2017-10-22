function [ res ] = do_regressor_test(conf, bbox_reg, rcnn_model, imdb)

suffix = '_bbox_reg';
res = cnn_test_bbox_regressor(conf, imdb, rcnn_model, bbox_reg, suffix);


end