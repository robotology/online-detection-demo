function [ rcnn_model ] = add_SVMs_model( cnn_model )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

rcnn_model = cnn_model;
% init empty detectors
detectors.W = [];
detectors.B = [];
detectors.crop_mode = 'warp';
detectors.crop_padding = 16;
detectors.nms_thresholds = [];

rcnn_model.detectors = detectors;

end

