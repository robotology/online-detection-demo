function [ res ] = do_regressor_test(conf, bbox_reg, rcnn_model, imdb, fid, varargin)

suffix = '_bbox_reg';

ip = inputParser;
ip.addParamValue('reg_mode', 'no_norm',   @isstr);
ip.parse(varargin{:});

% train the bbox regression model
switch ip.Results.reg_mode
    case {'no_norm'}
        res = cnn_test_bbox_regressor(conf, imdb, rcnn_model, bbox_reg, suffix, fid);
    case {'norm'}
        res = cnn_test_bbox_regressor_norm(conf, imdb, rcnn_model, bbox_reg, suffix, fid);
    otherwise
        error('regressor mode unknown');

end