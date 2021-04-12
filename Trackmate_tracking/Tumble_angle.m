clear;close all;
load('RawResults_with_tumble6.mat');

Interval_lim = 10;

tr = raw;

trackIDs = length(raw);
% ii = 1;
for ii = 1:trackIDs
   tr0 = raw(ii);
   [StartIndex,EndIndex,NN,IndexValue] = ...
       FindStartEndIndex(tr0.Tumble_or_not(:,3));
   TrueIndexValue = find(IndexValue==1);
   if isempty(TrueIndexValue)
       tr(ii).Tumble_StartEnd = [];
       tr(ii).Tumble_Angle = [];
       tr(ii).Short_run = [];
       continue;
   end
   tumbleStart = StartIndex(TrueIndexValue);
   tumbleEnd = EndIndex(TrueIndexValue);
   angle_div = zeros(length(tumbleStart),1);
   short_run = zeros(length(tumbleStart),1);
   for jj = 1:length(tumbleStart)-1
       if abs(tumbleEnd(jj)-tumbleStart(jj+1))<Interval_lim
           short_run(jj,1) = tr0.Angular(tumbleEnd(jj+1),1)-tr0.Angular(tumbleStart(jj),1);
           continue;
       end
       angle_div(jj,1) = tr0.Angular(tumbleEnd(jj),1)-tr0.Angular(tumbleStart(jj),1);
   end
   angle_div(length(tumbleStart),1) = tr0.Angular(tumbleEnd(end),1)-tr0.Angular(tumbleStart(end),1);
   tr(ii).Tumble_StartEnd = [tumbleStart,tumbleEnd];
   tr(ii).Tumble_Angle = angle_div;
   tr(ii).Short_Run = short_run;
end
angle_hist = vertcat(tr.Tumble_Angle);
% histogram(angle_hist);
save('Tumble_angle6.mat','tr','D_rot','angle_hist');