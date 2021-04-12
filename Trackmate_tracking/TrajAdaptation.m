% clear;close all;
load('Tumble_angle6.mat');
currentFolder = pwd;
backslash0 = strfind(currentFolder,'\');
lightcontain = currentFolder(backslash0(end)+1:end);
backslash1 = strfind(lightcontain,'_');
T = max(vertcat(tr.FrameNum));
adaptation0 = zeros(T+1,1);
% light = zeros(T+1,1);
window = 10;
timelapse = 0.1:0.1:(T+1)/10;
% light(1:1800) = str2double(lightcontain(1:backslash1(1)-1));
% light(601:3600) = str2double(lightcontain(backslash1(1)+1:backslash1(2)-1));
% light(3601:end) = str2double(lightcontain(backslash1(2)+1:end));
counter = 0;
tr1(1:length(tr)) = struct('FrameNum',[]);
for ii = 1:length(tr)
    tr0 = tr(ii);
%     if tr0.Displacement*sum(tr0.Distance)<20%length(tr0.FrameNum)<800
%         continue;
%     end
%     if abs((tr(ii).Angular(end,1)-tr(ii).Angular(1,1))/(tr(ii).FrameNum(end)-tr(ii).FrameNum(1)+1))>0.01
%         continue;
%     end
    if (std(tr0.Position(:,1))+std(tr0.Position(:,2)))<10
        continue;
    end
    counter = counter+1;
    tr1(counter).FrameNum = tr0.FrameNum;
    adaptation0(tr0.FrameNum(find(tr0.Tumble_or_not(:,3)==1))+1) = ...
        adaptation0(tr0.FrameNum(find(tr0.Tumble_or_not(:,3)==1))+1) + 1;
end
N = vertcat(tr1.FrameNum);
N = sort(N);
NN = histcounts(N,-0.5+min(N):1:0.5+max(N));

adaptation = adaptation0./NN';
f0 = figure('Position',[20 20 600 600]);
% yyaxis right;
% plot(timelapse,light,'LineWidth',1)
% ylim([0 100])
% ylabel('Blue Channel');
% yyaxis left;
time2 = timelapse(10:10:end);
adaptation2 = zeros(length(time2),1);
adaptation3 = zeros(length(time2),1);
NN2 = adaptation3;
for jj = 1:length(time2)
   adaptation2(jj) = mean(adaptation((jj-1)*10+1:jj*10));
   adaptation3(jj) = sum(adaptation0((jj-1)*10+1:jj*10));
   NN2 = sum(NN((jj-1)*10+1:jj*10));
end
adaptation4 = adaptation3./NN2';


[fitcurve, ~] = fit(time2',adaptation4,'SmoothingSpline','SmoothingParam',2e-5);

plot(time2,adaptation4)
hold on
fplot(@(x)fitcurve(x)',[0,1200],'LineWidth',2)
xlim([0 (T+1)/10])
% xticks(linspace(0,T+1,15))
ylabel('Tumble events/Num Euglena');
box on;
grid minor;
xlabel('Time/s')

saveas(f0,'Adaptation.fig');
saveas(f0,'Adaptation.png');
save(['Adaptation',lightcontain],'adaptation','timelapse','adaptation4','time2');