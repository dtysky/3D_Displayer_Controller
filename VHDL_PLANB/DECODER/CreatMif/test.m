clear;
clc;

%先切一百八十片，然后对称出剩下一百八十片 
%对称部分先在这里实现，之后在FPGA内实现，节省一半存储空间

%通过直线端点定义直线
p=zeros(12,2,3);
p(1,:,:)=[[-1.6079,-0.4078,-0.4982];[-0.4690, 1.0140,-1.3235]];
p(2,:,:)=[[-0.4690, 1.0140,-1.3235];[ 1.0920,-0.2363,-1.3235]];
p(3,:,:)=[[-0.0470,-1.6582,-0.4982];[ 1.0920,-0.2363,-1.3235]];
p(4,:,:)=[[-0.0470,-1.6582,-0.4982];[-1.6079,-0.4078,-0.4982]];
p(5,:,:)=[[-1.6079,-0.4078,-0.4982];[-1.0920, 0.2363, 1.3235]];
p(6,:,:)=[[ 0.0470, 1.6582, 0.4982];[-0.4690, 1.0140,-1.3235]];
p(7,:,:)=[[ 1.0920,-0.2363,-1.3235];[ 1.6079, 0.4078, 0.4982]];
p(8,:,:)=[[ 0.4690,-1.0140, 1.3235];[-0.0470,-1.6582,-0.4982]];
p(9,:,:)=[[-1.0920, 0.2363, 1.3235];[ 0.0470, 1.6582, 0.4982]];
p(10,:,:)=[[ 1.6079, 0.4078, 0.4982];[ 0.0470, 1.6582, 0.4982]];
p(11,:,:)=[[ 0.4690,-1.0140, 1.3235];[ 1.6079, 0.4078, 0.4982]];
p(12,:,:)=[[-1.0920, 0.2363, 1.3235];[ 0.4690,-1.0140, 1.3235]];

% p=zeros(4,2,3);
% p(1,:,:)=[[0,-1,1];[1,0,1]];
% p(2,:,:)=[[0,-1,1];[-1,0,1]];
% p(3,:,:)=[[0,1,1];[-1,0,1]];
% p(4,:,:)=[[0,1,1];[1,0,1]];

%获取边界
tmpx=p(:,1,1);
tmpy=p(:,1,2);
tmpz=p(:,1,3);
tmpx2=p(:,2,1);
tmpy2=p(:,2,2);
tmpz2=p(:,2,3);
xmax=max([max(tmpx),max(tmpx2)]);
xmin=min([min(tmpx),min(tmpx2)]);
ymax=max([max(tmpx),max(tmpx2)]);
ymin=min([min(tmpy),min(tmpy2)]);
zmax=max([max(tmpz),max(tmpz2)])+0.001;
zmin=min([min(tmpz),min(tmpz2)])-0.001;

%算直线方程组
%a1x1+b1y1+d1=0
%b2y2+c2z2+d2=0
a=zeros(length(p(:,1,1)),3,4);
for i = 1:length(p(:,1,1))
    x1=p(i,1,1);
    x2=p(i,2,1);
    y1=p(i,1,2);
    y2=p(i,2,2);
    z1=p(i,1,3);
    z2=p(i,2,3);
    %x,y
    a(i,1,1)=y2-y1;
    a(i,1,2)=-(x2-x1);
    a(i,1,3)=0;
    a(i,1,4)=(x2-x1)*y1-(y2-y1)*x1;
    %y,z
    a(i,2,1)=0;
    a(i,2,2)=-(z2-z1);
    a(i,2,3)=y2-y1;
    a(i,2,4)=(z2-z1)*y1-(y2-y1)*z1;
    %x,z
    a(i,3,1)=z2-z1;
    a(i,3,2)=0;
    a(i,3,3)=-(x2-x1);
    a(i,3,4)=(x2-x1)*z1-(z2-z1)*x1;
end

%构造平面并切片
res=[];
ii=1;
for i = 1:180
    b=[tan(deg2rad(i)),-1,0,0];
    for j = 1:length(a(:,1,1))
        f1=strcat( num2str(a(j,1,1)),'*x+',num2str(a(j,1,2)),'*y+',num2str(a(j,1,3)),'*z+',num2str(a(j,1,4)));
        f2=strcat( num2str(a(j,2,1)),'*x+',num2str(a(j,2,2)),'*y+',num2str(a(j,2,3)),'*z+',num2str(a(j,2,4)));
        f3=strcat( num2str(a(j,3,1)),'*x+',num2str(a(j,3,2)),'*y+',num2str(a(j,3,3)),'*z+',num2str(a(j,3,4)));
        f4=strcat( num2str(b(1)),'*x+',num2str(b(2)),'*y+',num2str(b(3)),'*z+',num2str(b(4)));
        [x,y,z]=solve(f1,f2,f4,'x','y','z');
        if ~isempty(x) && ~isempty(y) && ~isempty(z)
            if (x>=xmin && x<=xmax) && (y>=ymin && y<=ymax) && (z>=zmin && z<=zmax)
                res(ii,:)=[x,y,z];
                ii=ii+1;
            end
        end 
    end
    res(ii,:)=[0 0 0];
    ii=ii+1;
end

%平面点映射并纵向变换坐标系
tymax=max(abs(zmax),abs(zmin));
res2=[];
for i = 1:length(res)
    if res(i,1)==0 && res(i,2)==0 && res(i,3)==0
        res2(i,:)=[0 0];
    else
        x=res(i,1);
        y=res(i,2);
        z=res(i,3);
        tx=sqrt(x^2+y^2);
        if x*y<0
            res2(i,1)=-tx;
        else
            res2(i,1)=tx;
        end
        ty=z;
        res2(i,2)=zmax-ty;
    end
end

%进行对称操作
len=length(res2);
for i=1:length(res2)
    res2(len+i,1)=-res2(i,1);
    res2(len+i,2)=res2(i,2);
end

%放大取整并横向平变换坐标系
resfin=[];
for i =1:length(res2)
    resfin(i,:)=round(res2(i,:)*36);
    if resfin(i,1)==0 && resfin(i,2)==0
    else
       resfin(i,1)=resfin(i,1)+59;
    end
end

%输出
resout=resfin';
fo=fopen('mifsource.txt','w');
fprintf(fo,'%i %i\r\n',resout);
fclose(fo);