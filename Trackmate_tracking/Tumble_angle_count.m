clear;close all

load('Tumble_angle.mat');
tumble_hist = zeros(length(angle_hist),4);
trackIDs = length(tr);
period = 16;
counter = 1;
for ii = 1:trackIDs
    tr0 = tr(ii);
    for jj = 1:size(tr0.Tumble_StartEnd,1)
        tumble_hist(counter,1) = tr0.Position(tr0.Tumble_StartEnd(jj,1),1);
        tumble_hist(counter,2) = tr0.Position(tr0.Tumble_StartEnd(jj,1),2);
        tumble_hist(counter,3) = tr0.Tumble_Angle(jj);
        judgement = (-1)^double(mod(tumble_hist(counter,1),2048/period)>=2048/period/2);
        if (judgement*cos(tr0.Angular(tr0.Tumble_StartEnd(jj,1),1)))*...
                (judgement*cos(tr0.Angular(tr0.Tumble_StartEnd(jj,2),1)))>0
            tumble_hist(counter,4) = -1;
        elseif (judgement*cos(tr0.Angular(tr0.Tumble_StartEnd(jj,1),1)))>0&&...
                (judgement*cos(tr0.Angular(tr0.Tumble_StartEnd(jj,2),1)))<0
            tumble_hist(counter,4) = 0.5;
        elseif (judgement*cos(tr0.Angular(tr0.Tumble_StartEnd(jj,1),1)))<0&&...
            (judgement*cos(tr0.Angular(tr0.Tumble_StartEnd(jj,2),1)))>0
            tumble_hist(counter,4) = 1;
        end
        counter = counter+1;
    end
end

blue_channel = @(x)-80/(2048/period/2)*abs(x-2048/period/2)+80;
tumble_counter(:,1) = blue_channel(mod(tumble_hist(tumble_hist(:,3)~=0,1),2048/period));
tumble_counter(:,2) = mod(tumble_hist(tumble_hist(:,3)~=0,3)+2*pi,4*pi)-2*pi;
Xedges = linspace(0,80,80);
Yedges = linspace(-2*pi,2*pi,100);
N = histcounts2(tumble_counter(:,1),tumble_counter(:,2),Xedges,Yedges);
N(N==0) = nan;
f = figure('Position',[0 100 1600 400]);
subplot(1,3,1)
colormap('jet')
[X,Y] = meshgrid(Xedges(2:end),Yedges(2:end));
N_temp = N';
scatter(X(:),Y(:),5,N_temp(:),'Filled')
c = colorbar;
c.Label.String = 'Frequency';
box on;
grid on;
xlim([0 80])
ylim([-2*pi 2*pi])
yticks(-2*pi:1/2*pi:2*pi)
yticklabels({'-2\pi','-3/2\pi','-\pi','-1/2\pi','0','1/2\pi','\pi','3/2\pi','2\pi'})

xlabel('Blue Channel')
ylabel('$\phi$/rad','Interpreter','Latex')

subplot(1,3,2)
Xedges2 = linspace(0,80,40);
tumble_against1 = histcounts(blue_channel(mod(tumble_hist(tumble_hist(:,3)~=0&tumble_hist(:,4)==1,1),2048/period)),Xedges2);
tumble_against2 = histcounts(blue_channel(mod(tumble_hist(tumble_hist(:,3)~=0&tumble_hist(:,4)==0.5,1),2048/period)),Xedges2);
tumble_against = histcounts(blue_channel(mod(tumble_hist(tumble_hist(:,3)~=0&tumble_hist(:,4)>0,1),2048/period)),Xedges2);
tumble_toward = histcounts(blue_channel(mod(tumble_hist(tumble_hist(:,3)~=0,1),2048/period)),Xedges2);
plot(Xedges2(2:end),tumble_against1./tumble_toward,'r-')
hold on
plot(Xedges2(2:end),tumble_against1./tumble_against,'b-')
plot(Xedges2(2:end),tumble_against2./tumble_against,'g-')
ylabel('Ratio')
yyaxis right
plot(Xedges2(2:end),tumble_against1./tumble_against2)
xlabel('Blue Channel')
ylabel('Ration')
legend('\leftarrow\rightarrow/all tumble events',...
    '\leftarrow\rightarrow/(\leftarrow\rightarrow+\rightarrow\leftarrow)',...
    '\rightarrow\leftarrow/(\leftarrow\rightarrow+\rightarrow\leftarrow)',...
    '\leftarrow\rightarrow/\rightarrow\leftarrow')
grid minor;
hold off;
% Yedges = linspace(-2*pi,2*pi,100);
% N2 = histcounts2(tumble_toward(:,1),tumble_toward(:,2),Xedges,Yedges);
% N2(N2==0) = nan;
% colormap('jet')
% [X,Y] = meshgrid(Xedges(2:end),Yedges(2:end));
% N_temp2 = N2';
% scatter(X(:),Y(:),5,N_temp2(:),'Filled')
% c = colorbar;
% c.Label.String = 'Frequency';

% plot(tumble_counter(:,1),tumble_counter(:,2),'.','MarkerSize',2)

% box on;
% grid on;
% xlim([0 80])
% ylim([-2*pi 2*pi])
% yticks(-2*pi:1/2*pi:2*pi)
% yticklabels({'-2\pi','-3/2\pi','-\pi','-1/2\pi','0','1/2\pi','\pi','3/2\pi','2\pi'})
% 
% xlabel('Blue Channel')
% ylabel('$\phi$/rad','Interpreter','Latex')

subplot(1,3,3)
h = histogram(tumble_counter(:,2),linspace(-2*pi,2*pi,50),'Normalization','PDF');
xticks(-2*pi:1/2*pi:2*pi)
xticklabels({'-2\pi','-3/2\pi','-\pi','-1/2\pi','0','1/2\pi','\pi','3/2\pi','2\pi'})
xlabel('$\phi$/rad','Interpreter','Latex')
ylabel('PDF')
grid minor;

saveas(f,'Tumble_angle_count.fig');
saveas(f,'Tumble_angle_count.png');
