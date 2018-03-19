function f = zscores_standardization(f, standard_deviation,mean_feat, feat_norm_mean)

% f = (f-mean_feat)./standard_deviation;
% renorm = @(W,Z) W*(diag(1./std(Z)));
% recenter = @(W, Z) (renorm(W - ones(size(W,1),1)*mean(Z),Z));
% f=recenter(f,f);

f = f - mean_feat;
target_norm = 20;
f = f .* (target_norm / feat_norm_mean);
end
