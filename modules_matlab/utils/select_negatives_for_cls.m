function [curr_cls_neg, I] = select_negatives_for_cls(aboxes, overlaps, negatives_selection)
    I = find(overlaps < negatives_selection.neg_ovr_thresh);
    idx = randperm(length(I), negatives_selection.neg_per_image);
    curr_cls_neg = aboxes(I(idx),:);
    I = I(idx);
end