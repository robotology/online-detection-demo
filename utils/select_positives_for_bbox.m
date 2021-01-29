function [cur_bbox_X, cur_bbox_Y, sel_ex] = select_positives_for_bbox(boxes, gt_box, overlaps, min_overlap)

sel_ex = find(overlaps >= min_overlap); 

cur_bbox_X = cat(1,gt_box, boxes(sel_ex, :));
cur_bbox_Y = [];

for j = 1:size(cur_bbox_X, 1)
    ex_box = cur_bbox_X(j, :);

    src_w = ex_box(3) - ex_box(1) + eps;
    src_h = ex_box(4) - ex_box(2) + eps;
    src_ctr_x = ex_box(1) + 0.5*src_w;
    src_ctr_y = ex_box(2) + 0.5*src_h;

    gt_w = gt_box(3) - gt_box(1) + eps;
    gt_h = gt_box(4) - gt_box(2) + eps;
    gt_ctr_x = gt_box(1) + 0.5*gt_w;
    gt_ctr_y = gt_box(2) + 0.5*gt_h;

    dst_ctr_x = (gt_ctr_x - src_ctr_x) * 1/src_w;
    dst_ctr_y = (gt_ctr_y - src_ctr_y) * 1/src_h;
    dst_scl_w = log(gt_w / src_w);
    dst_scl_h = log(gt_h / src_h);

    target = [dst_ctr_x dst_ctr_y dst_scl_w dst_scl_h];

    cur_bbox_Y = cat(1,cur_bbox_Y,target);
end
end