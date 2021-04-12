clear;close all

load('TrackMate_Raw6.mat');
raw = RawResults;

CheckResults = 0;

trackIDs = length(raw);
max_length = 0;
for ii = 1:trackIDs
    tr = raw(ii);
    raw(ii).Displacement = hypot(tr.Position(1,1)-tr.Position(end,1),tr.Position(1,2)-tr.Position(end,2));
    raw(ii).Distance = [0;hypot(tr.Position(1:end-1,1)-tr.Position(2:end,1),tr.Position(1:end-1,2)-tr.Position(2:end,2))];
    
    Angle_Corr0 = (xcorr(sin(tr.Angular(:,1)))+xcorr(cos(tr.Angular(:,1))))./xcorr(tr.Angular(:,1)*0+1);
    raw(ii).Angle_Corr = Angle_Corr0((length(Angle_Corr0)+1)/2:end);
    max_length = max(max_length,length(tr.Velocity));
end
Angle_Corr_Sum = zeros(max_length,1);
for ii = 1:trackIDs
    Angle_Corr_Sum(1:length(raw(ii).Angle_Corr)) = ...
        Angle_Corr_Sum(1:length(raw(ii).Angle_Corr)) + raw(ii).Angle_Corr;
end
Angle_Corr_Avg = Angle_Corr_Sum/trackIDs;

[tData, yData] = prepareCurveData((1:max_length)',Angle_Corr_Avg);

% Set up fittype and options.
ft = fittype( 'exp(-D_rot*x)', 'independent', 'x', 'dependent', 'y' );
opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
opts.StartPoint = 0.01;
% Fit model to data.
[fitresult, gof] = fit( tData, yData, ft, opts );
D_rot = fitresult.D_rot; %rad^2/frame;

% ii = 1;
for ii = 1:trackIDs
    tr = raw(ii);
    tumble = findtumble(tr,D_rot);
    raw(ii).Tumble_or_not = tumble;
end

% if CheckResults
%     figure('Position',[0 20 1600 700]);
%     loops = length(raw(ii).Position);
%     F(loops) = struct('cdata',[],'colormap',[]);
%     tumble_pos1 = find(raw(ii).Tumble_or_not(:,1)==1);
%     tumble_pos2 = find(raw(ii).Tumble_or_not(:,2)==1);
%     colormap('summer');
%     for j = 1:loops
%         subplot(2,2,[1 3])
%         scatter(raw(ii).Position(1:j,1),raw(ii).Position(1:j,2),5,...
%             raw(ii).FrameNum(1:j),'filled');
%         hold on
%         scatter(raw(ii).Position(tumble_pos1(1:find(tumble_pos1<j,1,'last')),1),...
%             raw(ii).Position(tumble_pos1(1:find(tumble_pos1<j,1,'last')),2),5,'r','filled')
%         scatter(raw(ii).Position(tumble_pos2(1:find(tumble_pos2<j,1,'last')),1),...
%             raw(ii).Position(tumble_pos2(1:find(tumble_pos2<j,1,'last')),2),5,'b','filled')
%         xlabel('x')
%         xlim([min(raw(ii).Position(:,1)),max(raw(ii).Position(:,1))])
%         ylabel('y')
%         ylim([min(raw(ii).Position(:,2)),max(raw(ii).Position(:,2))])
%         axis equal;
%         box on;grid minor;
%         caxis([min(raw(ii).FrameNum) max(raw(ii).FrameNum)]);
%         colorbar;
%         
%         subplot(2,2,2)
%         plot(raw(ii).FrameNum(1:j),hypot(raw(ii).Velocity(1:j,1),...
%             raw(ii).Velocity(1:j,2)),'b-');
%         ylabel('v(pixels/frame)')
%         hold on
%         yyaxis right;
%         plot(raw(ii).FrameNum(1:j),abs(raw(ii).Angular(1:j,2)),'r-')
%         ylabel('|w|(rad/frame)')
%         xlim([min(raw(ii).FrameNum) max(raw(ii).FrameNum)])
%         hold off
%         
%         subplot(2,2,4)
%         tumble_or_not = raw(ii).Tumble_or_not(:,1)|raw(ii).Tumble_or_not(:,2);
%         area(raw(ii).FrameNum(1:j),tumble_or_not(1:j))
%         xlim([min(raw(ii).FrameNum) max(raw(ii).FrameNum)])
% 
%         drawnow;
%         F(j) = getframe;
%     end
% end
save('RawResults_with_tumble6.mat','raw','D_rot');

% vw = VideoWriter([mfilename,'2'],'MPEG-4');
% vw.FrameRate = 1;
% open(vw)
% for ii = 1:trackIDs
%     h = figure('Position',[0 20 1600 700],'Visible','Off');
%     tumble_pos1 = find(raw(ii).Tumble_or_not(:,1)==1);
%     tumble_pos2 = find(raw(ii).Tumble_or_not(:,2)==1);
%     colormap('summer');
%     subplot(2,2,[1 3])
%     scatter(raw(ii).Position(:,1),raw(ii).Position(:,2),5,...
%         raw(ii).FrameNum,'filled');
%     hold on
%     scatter(raw(ii).Position(tumble_pos1,1),...
%         raw(ii).Position(tumble_pos1,2),5,'r','filled')
%     scatter(raw(ii).Position(tumble_pos2,1),...
%         raw(ii).Position(tumble_pos2,2),5,'b','filled')
%     xlabel('x')
% %     xlim([min(raw(ii).Position(:,1)),max(raw(ii).Position(:,1))])
%     ylabel('y')
% %     ylim([min(raw(ii).Position(:,2)),max(raw(ii).Position(:,2))])
%     axis equal;
%     box on;grid minor;
%     caxis([min(raw(ii).FrameNum) max(raw(ii).FrameNum)]);
%     colorbar;
% 
%     subplot(2,2,2)
%     plot(raw(ii).FrameNum,hypot(raw(ii).Velocity(:,1),...
%         raw(ii).Velocity(:,2)),'b-');
%     ylabel('v(pixels/frame)')
%     hold on
%     yyaxis right;
%     plot(raw(ii).FrameNum,abs(raw(ii).Angular(:,2)),'r-')
%     ylabel('|w|(rad/frame)')
%     xlim([min(raw(ii).FrameNum) max(raw(ii).FrameNum)])
%     hold off
% 
%     subplot(2,2,4)
%     tumble_or_not = raw(ii).Tumble_or_not(:,1)|raw(ii).Tumble_or_not(:,2);
%     area(raw(ii).FrameNum,tumble_or_not)
%     xlim([min(raw(ii).FrameNum) max(raw(ii).FrameNum)])
% 
%     drawnow;
%     writeVideo(vw,getframe(h));
%     close(h);
% end
% close(vw);
function p = findtumble(s,D_rot)
    alpha = 1;
    beta = 0.5;
    gamma = 3;
    epsilon = 0.6;
    
    p = zeros(length(s.FrameNum),3);
    % 1 v; 2 w; 3 total
    v = hypot(s.Velocity(:,1),s.Velocity(:,2));
    w = s.Angular(:,2);
    Timeline = zeros(length(s.FrameNum),3);
    Timeline(:,1) = s.FrameNum;
    Timeline(:,2) = double(islocalmin(v))+double(islocalmax(v))*2;
    Timeline(:,3) = double(islocalmin(abs(w)))+double(islocalmax(abs(w)))*2;
    
    index_v_min = find(Timeline(:,2)==1);
    index_v_max = [1;find(Timeline(:,2)==2);length(Timeline)-1];
    
    index_w_min = [1;find(Timeline(:,3)==1);length(Timeline)-1];
    index_w_max = find(Timeline(:,3)==2);
    % First criterion
    for ii = 1:length(index_v_min)
%         fprintf('ii:%d\t',ii);
        left_max = sum(index_v_min(ii)>index_v_max);
        right_max = left_max+1;
        delta_v = max(v(index_v_max(left_max))-v(index_v_min(ii)),...
            v(index_v_max(right_max))-v(index_v_min(ii)));
        if delta_v/v(index_v_min(ii))>=alpha
            for jj = index_v_max(left_max):(index_v_max(right_max))
%                 fprintf('jj%d',jj);
                if v(jj)<=v(index_v_min(ii))+beta*delta_v
                    p(jj,1) = 1;
                end
            end
        end
    end
    
    % Second criterion
    for ii = 1:length(index_w_max)
        left_min = sum(index_w_max(ii)>index_w_min);
        right_min = left_min+1;
        Sum_angle = sum(abs(diff(s.Angular(index_w_min(left_min):index_w_min(right_min)+1,1))));
        delta_w = max(abs(w(index_w_max(ii))-w(index_w_min(left_min))),...
            abs(w(index_w_max(ii))-w(index_w_min(right_min))));
        if Sum_angle>=gamma*sqrt(D_rot*(s.FrameNum(index_w_min(right_min))-...
                s.FrameNum(index_w_min(left_min))))
            for jj = index_w_min(left_min):index_w_min(right_min)
                if abs(abs(w(index_w_max(ii)))-abs(w(jj)))<=epsilon*delta_w
                    p(jj,2) = 1;
                end
            end
        end
    end
    p(:,3) = p(:,1)|p(:,2);
end
