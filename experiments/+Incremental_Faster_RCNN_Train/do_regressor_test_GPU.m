function [ res ] = do_regressor_test_GPU(conf, bbox_reg, rcnn_model, imdb, fid)

suffix = '_bbox_reg';
res = cnn_test_bbox_regressor_GPU(conf, imdb, rcnn_model, bbox_reg, suffix, fid);


end
