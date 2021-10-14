function p = KtsProd_onGPU(X, C, alpha, blk, kern)
    n = size(X,1); m = size(C,1);
    ms = ceil(linspace(0, n, blk+1));
    p = zeros(n, size(alpha,2) , 'like', C);
    if issparse(X) && strcmp(kern.func, 'linear')
        coeff2 = 1/kern.param2^2;
        coeff1 = kern.param1;
        p = coeff1*ones(size(X,1),1)*sum(alpha,1)+ coeff2*X*(C'*alpha);
    else
        for i=1:blk
%                 clear Kr;
%                 blk_X = feval(class(C), X((ms(i)+1):ms(i+1), :));
%                 Kr = kern(feval(class(C), X((ms(i)+1):ms(i+1), :)), gpuArray(C));
                p((ms(i)+1):ms(i+1), :) = gather(kern(feval(class(C), X((ms(i)+1):ms(i+1), :)), gpuArray(C)))*alpha;

        end

    end
end
% function p = KtsProd_onGPU(X, C, alpha, blk, kern)
%     n = size(X,1); m = size(C,1);
%     ms = ceil(linspace(0, n, blk+1));
%     p = zeros(n, size(alpha,2) , 'like', C);
%     if issparse(X) && strcmp(kern.func, 'linear')
%         coeff2 = 1/kern.param2^2;
%         coeff1 = kern.param1;
%         p = coeff1*ones(size(X,1),1)*sum(alpha,1)+ coeff2*X*(C'*alpha);
%     else
% %    fprintf('prod on GPU');
%         for i=1:blk
%                 clear Kr;
%                 ftic = tic;
% %                 blk_X = feval(class(C), X((ms(i)+1):ms(i+1), :));
%                 fprintf('feval tic %f\n',toc(ftic));
%                 ktic = tic;
% %                 Kr = kern(gpuArray(blk_X), gpuArray(C));
%                 Kr = kern(X((ms(i)+1):ms(i+1), :), gpuArray(C));
%                 fprintf('Kr tic %f\n',toc(ktic));
%                 ptic =tic;
%                 p((ms(i)+1):ms(i+1), :) = gather(Kr)*alpha;
%                 fprintf('p tic %f\n',toc(ptic));
%                % fprintf('*');
%         end
% %         p = gather(p);
%    % fprintf('\n');
%     end
% end
