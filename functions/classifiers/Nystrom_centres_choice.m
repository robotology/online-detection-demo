function [ C ] = Nystrom_centres_choice( X_pos, X_neg, num_of_centres )

n_pos = size(X_pos,1);
n_neg = size(X_neg,1);
c_pos = num_of_centres/2;
c_neg = num_of_centres/2;
if n_pos < c_pos
    c_pos = n_pos;
    c_neg = num_of_centres-c_pos;
end
if n_neg < c_neg
    c_neg = n_neg;
end

c_pos_idx = randperm(n_pos,c_pos);
c_neg_idx = randperm(n_neg,c_neg);

C = zeros(c_pos+c_neg, size(X_pos,2));

C(1:c_pos,:) = X_pos(c_pos_idx,:);
C(c_pos+1:end, :) = X_neg(c_neg_idx,:);
fprintf('Final number of nystrom centres is: %d\n', c_pos+c_neg);
end

