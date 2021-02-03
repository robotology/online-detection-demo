function [ bbox_reg ] = Train_bbox_regressor(bbox_reg, dataset, cls_ids, varargin)
%TRAIN_BBOX_REGRESSOR Summary of this function goes here
%   Detailed explanation goes here

ip = inputParser;

ip.addParamValue('lambda',      1000,  @isscalar);
ip.addParamValue('robust',      0,     @isscalar);

ip.parse(varargin{:});
opts = ip.Results;

    num_classes = length(dataset);
%     models = cell(num_classes, 1);
    method = 'ridge_reg_chol';
    tic
    for i = 1:num_classes
      if ~isempty(find(cls_ids==i))
          Xi = dataset{i}.pos_bbox_regressor.feat ; 

          Yi = dataset{i}.y_bbox_regressor; 

          % add bias feature
          Xi = cat(2, Xi, ones(size(Xi,1), 1, class(Xi)));

          % Center and decorrelate targets
          mu = mean(Yi);
          Yi = bsxfun(@minus, Yi, mu);
          S = Yi'*Yi / size(Yi,1);
          [V, D] = eig(S);
          D = diag(D);
          T = V*diag(1./sqrt(D+0.001))*V';
          T_inv = V*diag(sqrt(D+0.001))*V';
          Yi = Yi * T;

          bbox_reg.models{i}.mu = mu;
          bbox_reg.models{i}.T = T;
          bbox_reg.models{i}.T_inv = T_inv;

          bbox_reg.models{i}.Beta = [ ...
            solve_robust(Xi, Yi(:,1), opts.lambda, method, opts.robust) ...
            solve_robust(Xi, Yi(:,2), opts.lambda, method, opts.robust) ...
            solve_robust(Xi, Yi(:,3), opts.lambda, method, opts.robust) ...
            solve_robust(Xi, Yi(:,4), opts.lambda, method, opts.robust)];
      end
    end
    fprintf('time required for training regressors: %f seconds\n',toc);

%     bbox_reg.models = models;
    bbox_reg.training_opts = opts;

end

% ------------------------------------------------------------------------
function [x, losses] = solve_robust(A, y, lambda, method, qtile)
% ------------------------------------------------------------------------
    [x, losses] = solve(A, y, lambda, method);
    fprintf('loss = %.3f\n', mean(losses));
    if qtile > 0
      thresh = quantile(losses, 1-qtile);
      I = find(losses < thresh);
      [x, losses] = solve(A(I,:), y(I), lambda, method);
      fprintf('loss (robust) = %.3f\n', mean(losses));
    end
end

% ------------------------------------------------------------------------
function [x, losses] = solve(A, y, lambda, method)
% ------------------------------------------------------------------------

    %tic;
    switch method
    case 'ridge_reg_chol'
      % solve for x in min_x ||Ax - y||^2 + lambda*||x||^2
      %
      % solve (A'A + lambdaI)x = A'y for x using cholesky factorization
      % R'R = (A'A + lambdaI)
      % R'z = A'y  :  solve for z  =>  R'Rx = R'z  =>  Rx = z
      % Rx = z     :  solve for x
      R = chol(A'*A + lambda*eye(size(A,2)));
      z = R' \ (A'*y);
      x = R \ z;
    case 'ridge_reg_inv'
      % solve for x in min_x ||Ax - y||^2 + lambda*||x||^2
      x = inv(A'*A + lambda*eye(size(A,2)))*A'*y;
    case 'ls_mldivide'
      % solve for x in min_x ||Ax - y||^2
      if lambda > 0
        warning('ignoring lambda; no regularization used');
      end
      x = A\y;
    end
    %toc;
    losses = 0.5 * (A*x - y).^2;
end
