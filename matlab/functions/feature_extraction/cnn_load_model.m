function [cnn_model, caffe_net] = cnn_load_model(conf, cnn_model_or_file)
% rcnn_model = rcnn_load_model(rcnn_model_or_file, use_gpu)
%   Takes an rcnn_model structure and loads the associated Caffe
%   CNN into memory. Since this is nasty global state that is carried
%   around, a randomly generated 'key' (or handle) is returned.
%   Before making calls to caffe it's a good idea to check that
%   rcnn_model.cnn.key is the same as caffe('get_init_key').

% AUTORIGHTS
% ---------------------------------------------------------
% Copyright (c) 2014, Ross Girshick
% 
% This file is part of the R-CNN code and is available 
% under the terms of the Simplified BSD License provided in 
% LICENSE. Please retain this notice and LICENSE if you use 
% this file (or any portion of it) in your project.
% ---------------------------------------------------------

if isstr(cnn_model_or_file)
  assert(exist(cnn_model_or_file, 'file') ~= 0);
  ld = load(cnn_model_or_file);
  cnn_model = ld.rcnn_model; clear ld;
else
  cnn_model = cnn_model_or_file;
end

caffe_net = caffe.Net(cnn_model.net_def_file, cnn_model.binary_file, 'test');

% set gpu/cpu
if conf.use_gpu
    caffe.set_mode_gpu();
else
    caffe.set_mode_cpu();
end      

cnn_model.max_rois_num_in_gpu = check_gpu_memory(conf, caffe_net);

cnn_model.cnn.layers = caffe_net.layer_names;

% cnn_model.cnn.init_key = ...
%     caffe('init', cnn_model.definition_file, cnn_model.binary_file);
% if exist('use_gpu', 'var') && ~use_gpu
%   caffe('set_mode_cpu');
% else
%   caffe('set_mode_gpu');
% end
% caffe('set_phase_test');
% cnn_model.cnn.layers = caffe('get_weights');

end

function max_rois_num = check_gpu_memory(conf, caffe_net)
%%  try to determine the maximum number of rois

    max_rois_num = 0;
    for rois_num = 500:500:5000
        % generate pseudo testing data with max size
        im_blob = single(zeros(conf.max_size, conf.max_size, 3, 1));
        rois_blob = single(repmat([0; 0; 0; conf.max_size-1; conf.max_size-1], 1, rois_num));
        rois_blob = permute(rois_blob, [3, 4, 1, 2]);

        net_inputs = {im_blob, rois_blob};

        % Reshape net's input blobs
        caffe_net.reshape_as_input(net_inputs);

        caffe_net.forward(net_inputs);
        gpuInfo = gpuDevice();

        max_rois_num = rois_num;
            
        if gpuInfo.FreeMemory < 2 * 10^9  % 2GB for safety
            break;
        end
    end

end
