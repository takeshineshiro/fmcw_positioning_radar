%% 运行参数设置
doJoggleTest_firstRampTime=1;
doShiftTest_firstRampTime=0;

%% 清理
close all;

%% 加载数据、参数
load '../data/dataSim_200kHz_400rps_5rpf_1t3r_static.mat'

nRx=size(antBits,1);
ys=log2array(logsout,'dataSim');
lRamp=fS/fTr;%length ramp
lF=size(ys,2);
nCyclePF=lF/lRamp/nRx;

%% 提取两路信号
ysLo=real(ys);%ys local
ysTr=imag(ys);%ys triger

%% 显示示例帧，计算参数，检验firstRampTime函数
% 抽取示例帧
iSam=3;
ts=0:1/fS:1/fS*(size(ysLo,2)-1);
ysLoSam=ysLo(iSam,:);
ysTrSam=ysTr(iSam,:);

% 计算触发电平
trThres=(max(ysTrSam)+min(ysTrSam))/2;%triger threshold
trThres=(mean(ysTrSam(ysTrSam>trThres))+mean(ysTrSam(ysTrSam<trThres)))/2;

% 绘制信号
figure('name','示例帧触发沿检测');
plot(ts,ysLoSam);
hold on
plot(ts,ysTrSam);
plot([ts(1),ts(end)],[trThres,trThres]);

% 检验firstRampTime函数
tFrampSam=firstRampTime(ysTrSam,fS,fTr,tPul,nPul,0,trThres);%time Ramp
plot(tFrampSam,trThres,'o');

% 检验触发沿index，为后面circshift准备
iTrF=ceil(tFrampSam*fS)+1;
plot(ts(iTrF),ysTrSam(iTrF),'o');

% 绘制坐标轴和图例
title(['第' num2str(iSam) '帧的同步信号和中频信号']);
xlabel('t(s)');
legend('中频信号','同步信号','触发电平','第一个同步信号触发沿','反推得到的触发沿index');

hold off

%% 测试firstRampTime的效率和抖动
if doJoggleTest_firstRampTime
    tsFramp=zeros(size(ys,1),1);
    for iF=1:size(ys,1)
        tsFramp(iF)=firstRampTime(ysTr(iF,:),fS,fTr,tPul,3,0,trThres);%time Ramp
    end
    figure('name','firstRampTime的抖动');
    % 理想情况下，触发信号时间应该线性变化，但由于触发沿的非线性、采样点不够密集，仍可能带来相位抖动
    % 通过估计触发信号时间增量的抖动，可以简单地估计firstRampTime函数可能带来的相位抖动
    tsDeltaInc=detrend(tsFramp(2:end)-tsFramp(1:end-1));%times delta increment
    plot(tsDeltaInc);
    title('firstRampTime函数可能带来的相位抖动');
    ylabel('t(s)');
    xlabel('帧');
    disp(['触发信号时间增量的抖动均方差为' num2str(std(tsDeltaInc))]);
end

%% 通过循环位移样本帧模拟了长时间运行时可能触发的边界条件
if doShiftTest_firstRampTime
    hV=figure('name','长时间运行测试firstRampTime');
    tsFramp=zeros(size(ys,2),1);
    for iShift=1:lRamp*nRx
        ysTrShift=circshift(ysTrSam,iShift);
        tsFramp(iShift)=firstRampTime(ysTrShift,fS,fTr,tPul,3,0,trThres);%time Ramp
        %绘制触发信号和触发点
        figure(hV);
        plot(ts,ysTrShift);
        hold on;
        plot(tsFramp(iShift),trThres,'o');
        hold off
        pause(0.001);
    end
end

%% 用ysTrSam测试getAntIndex函数
iAnt=getAntIndex(ysTrSam, tFrampSam, fS, tPul, trThres, antBits);
isAnt=zeros(1,lF/lRamp-1);
for iSwitch=1:lF/lRamp-1
    isAnt(iSwitch)=getAntIndex(ysTrSam, tFrampSam+iSwitch/fTr, fS, tPul, trThres, antBits);
end
disp(['样本帧中检测到的天线编号有：' num2str(isAnt)]);

%% 用ysTrSam测试interpShift函数，对中频信号进行循环移位
figure('name','interpShift移位测试');

subplot(1,2,1);
ysTrSamShifted=interpShift(ysTrSam,calcShiftDis(iAnt,tFrampSam,lRamp,fS,nRx));%少移一位，让过零点移到首位
plot(ts,ysTrSamShifted,ts,ysTrSam);
hold on;
plot(tFrampSam,trThres,'o');
plot(ts(1),ysTrSamShifted(1),'o');
title('对同步信号进行循环移位');
xlabel('t(s)');
legend('移位前的同步信号','移位后的同步信号','移位前的触发沿','移位后的触发沿');
hold off;

subplot(1,2,2);
ysLoSamShifted=interpShift(ysLoSam,calcShiftDis(iAnt,tFrampSam,lRamp,fS,nRx));
plot(ts,ysLoSamShifted,ts,ysLoSam);
title('对中频信号进行循环移位');
xlabel('t(s)');
legend('移位前的中频信号','移位后的中频信号');

%% reshape移位后的中频信号ysLoSamShifted
ysLoRxi=reshape(ysLoSamShifted,lRamp*nRx,nCyclePF);
figure('name','斜坡分割测试');
plot(repmat(ts(1:lRamp*nRx)',1,5),ysLoRxi);
legend([repmat('第',nCyclePF,1),num2str((1:nCyclePF)'),repmat('个周期',nCyclePF,1)]);
title('样本帧中的各周期');
xlabel('t(s)');

