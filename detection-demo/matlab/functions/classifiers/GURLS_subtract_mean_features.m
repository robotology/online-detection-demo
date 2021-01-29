function [ f  ] = GURLS_subtract_mean_features( f, mean_feat )

fprintf('gurls subtraction feature mean\n');

f = f - mean_feat;

end