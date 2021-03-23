%> @file create_output.m
%> @brief Creates graphs and text outcome measures after running simulation.
%> @par Called by 
%> Simulator>@link run_Callback @endlink \n
%> @par Calls 
%> CVGA.mat \n
%> @link choose_display @endlink \n
%> @link eliminate @endlink \n
%> @link enter_filename @endlink \n
%> @link error_window @endlink \n
%> @link scaledBG @endlink \n
%> <a href="http://www.mathworks.com/help/stats/ecdf.html">ecdf</a> (Statistics Toolbox) \n
%> <a href="http://www.mathworks.com/help/stats/ksdensity.html">ksdensity</a> (Statistics Toolbox)\n
%> @copyright 2008-2013 University of Virginia.
%> @copyright 2013 The Epsilon Group, An Alere Company.

%> @par Syntax
%> @code 
%> create_output(results,output,meals,sb,Treg,saveastxt)
%> @endcode
%> @param results Simulation result, usually `data` stored in `sim_results.mat`. 
%> @param output Output settings that received from main GUI outcome measure settings. The output setting is usually stored in `sim_out.mat`. 
%> @param meals The amount and timing for meal intake during simulation.
%> @param Treg Time after which data is included in analysis calcs of results data
%> @param saveastxt Boolean value indicating whether saving results in a txt file.\n
%> result will be saved in results_default.txt by default.
function test = create_output(results,output,meals,Treg,saveastxt)
if ~exist('results','dir')
    mkdir('results')
end
try
n=length(results);


%create outcome graphs-----------------------------------------------------
displaymode='sub';
if n>1 && sum(output.graphs)~=0
    displaymode=choose_display('string', ['Your simulation covers ' num2str(n) ' subjects, do you want']);
end
drawnow
numgraph=sum(output.graphs>0);
numg=0;
% 
% 
if strcmp(displaymode,'pop')
    if output.graphs(1)  % Blood Glucose Trace

        figure

        for i=1:n
            G(i,:)=results(i).G.signals.values;
            numg=numg+100*(1/n)/numgraph;
%             
        end
        mg=mean(G);
        sdg=std(G);
        maxg=max(G);
        ming=min(G);
        ind=find(results(1).time.signals.values<=Treg,1,'last');
        plot(results(1).time.signals.values(1:ind)/60,mg(1:ind),'k','LineWidth',2)
        hold on
        plot(results(1).time.signals.values(ind:end)/60,mg(ind:end),'g','LineWidth',2)
        
        plot(results(1).time.signals.values/60,sdg+mg,'-.','Color',[1 0.5 0])
        plot(results(1).time.signals.values/60,mg-sdg,'-.','Color',[1 0.5 0])
        plot(results(1).time.signals.values/60,maxg,'-.r')
        plot(results(1).time.signals.values/60,ming,'-.r')
        title('Glucose Trace: mean \pm 1 STD  (orange) and min/max envelope)')
        xlabel('time [hour]')
        ylabel('blood glucose [mg/dl]')
        grid on
        drawnow

    end
    if output.graphs(2) % Risk Trace
        ind=find(results(1).time.signals.values<=Treg,1,'last');
        for i=1:n
            for j=1:60:length(results(i).time.signals.values)-60-mod(length(results(i).time.signals.values),60)
                data(i,(j-1)/60+1)=mean(10*(scaledBG(results(i).G.signals.values(j:j+59)).^2).*sign(scaledBG(results(i).G.signals.values(j:j+59))));
            end
            numg=numg+100*(1/n)/numgraph;
%     
        end
        figure
    if ind>=60
        bar(0.5:length(data(1,1:floor(ind/60)))-0.5,mean(data(:,1:floor(ind/60))),'k')
        hold on
        bar(length(data(1,1:floor(ind/60)))+0.5:length(data(1,1:end))-0.5,mean(data(:,ceil(ind/60):end)),'g')
        errorbar(0.5:length(data(1,:))-0.5,mean(data),std(data),'+')
    else

        bar(0.5:length(data(1,1:end))-0.5,mean(data),'g')
        hold on
        errorbar(0.5:length(data(1,:))-0.5,mean(data),std(data),'+')
    end
    
        title('Glucose Risk Trace: mean \pm 1 STD')
        xlabel('time [hour]')
        ylabel('Risk Index')
        grid on
        drawnow

    end
    if output.graphs(3)  % Aggregated BG Trace
        numg=numg+1/numgraph;
%  

        error_window('string', 'the aggregated trace graph is not a valid population plot')
        drawnow
    end
    if output.graphs(4)  % histogram of BG Rate of Change
        ind=find(results(1).time.signals.values<=Treg,1,'last');
        data=[];
        for i=1:n
            for j=1:length(results(i).time.signals.values)-15
                Y=(results(i).G.signals.values(j:j+14));
                X=[ones(15,1) (1:15)'];
                beta=((X'*X)^(-1)*X'*Y);
                data=[data beta(2)];
            end
            numg=numg+100*(1/n)/numgraph;
%   
        end
        figure
        hist(data(ind:end))
        title('Histogram of the Blood Glucose Rate of Change During Regulation')
        xlabel('Rate of Change [md.dl^{-1}.min^{-1}')
        ylabel('Count')
        drawnow

    end
    if output.graphs(5)  % Poincare Plot
        numg=numg+1/numgraph;
%  

        error_window('string','The Poincare plot is not a valid population plot')
        drawnow
    end
    if output.graphs(6)==1   % CVGA per Day

        figure
        load CVGA
        imagesc(CVEG)
        set(gca,'Ytick',[10 833 1653 2472],'YtickLabel',[400 300 180 110])
        axis([0 2482 0 2482])
        set(gca,'Xtick',[10 832 1652 2472],'XtickLabel',[110 90 70 50])
        set(gca,'Box','off')
        hold on
        xlabel('lower 95% confidence bound [mg/dl]')
        ylabel('upper 95% confidence bound [mg/dl]')
        for i=1:n
            T=results(i).time.signals.values;
            G=results(i).G.signals.values;
            ind=find(T<=Treg,1,'last');
            T=T(ind:end);
            G=G(ind:end);
            if length(T)>2880
                for j=1:1440:length(T)-1440-mod(length(T),1440)
                    [f,x]=ecdf(G(j:j+1439));
                    mini(i,(j-1)/1440+1)=min([110 max([50 x(find(f<=0.025,1,'last'))])]);
                    maxi(i,(j-1)/1440+1)=max([110 min([400 x(find(f<=0.975,1,'last'))])]);
                end
            else
                [f,x]=ecdf(G);
                mini(i,1)=min([110 max([50 x(find(f<=0.025,1,'last'))])]);
                maxi(i,1)=max([110 min([400 x(find(f<=0.975,1,'last'))])]);
            end
            numg=numg+100*(1/n)/numgraph;
%    
        end
        for i=1:n
            plot(bmin(1)*mini(i,:)+bmin(2),bmax(1)*maxi(i,:).^3+bmax(2)*maxi(i,:).^2+bmax(3)*maxi(i,:)+bmax(4),'o','MarkerEdgeColor',[0 0 0],'MarkerFaceColor',[0 0 0])
        end

        A=round(100*sum(sum(maxi<=180 & mini>=90))/(sum(size(maxi).*fliplr(size(maxi)))/2));
        B=round(100*sum(sum((maxi >180 & maxi<=300 & mini>=70) | (mini<90 & maxi<=180 & mini>=70)))/(sum(size(maxi).*fliplr(size(maxi)))/2));
        C=round(100*sum(sum((maxi >300 & mini>=90) | (mini<70 & maxi<=180)))/(sum(size(maxi).*fliplr(size(maxi)))/2));
        D=round(100*sum(sum((maxi >300 & mini<90 & mini>=70) | (mini<70 & maxi>180 & maxi<300)))/(sum(size(maxi).*fliplr(size(maxi)))/2));
        E=round(100*sum(sum((maxi >300 & mini<70)))/(sum(size(maxi).*fliplr(size(maxi)))/2));
        if A+B+C+D+E<100
            t=find(max([A B C D E])==[A B C D E],1,'first');
            switch t
                case 1
                    A=A+100-A-B-C-D-E;
                case 2
                    B=B+100-A-B-C-D-E;
                case 3
                    C=C+100-A-B-C-D-E;
                case 4
                    D=D+100-A-B-C-D-E;
                otherwise
            end
        end
        title(['A zone ' num2str(A) '%, B zone ' num2str(B) '%, C zone ' num2str(C) '%, D zone ' num2str(D) '%E zone ' num2str(E) '%'])
        drawnow


    elseif output.graphs(6)==2  % CVGA per subject
        figure
        load CVGA
        imagesc(CVEG)
        set(gca,'Ytick',[10 833 1653 2472],'YtickLabel',[400 300 180 110])
        axis([0 2482 0 2482])
        set(gca,'Xtick',[10 832 1652 2472],'XtickLabel',[110 90 70 50])
        set(gca,'Box','off')
        hold on
        xlabel('lower 95% confidence bound [mg/dl]')
        ylabel('upper 95% confidence bound [mg/dl]')
        for i=1:n
            T=results(i).time.signals.values;
            G=results(i).G.signals.values;
            ind=find(T<=Treg,1,'last');
            T=T(ind:end);
            G=G(ind:end);
            [f,x]=ecdf(G);
            mini(i)=min([110 max([50 x(find(f<=0.025,1,'last'))])]);
            maxi(i)=max([110 min([400 x(find(f<=0.975,1,'last'))])]);
            numg=numg+100*(1/n)/numgraph;
%    
        end
        plot(bmin(1)*mini+bmin(2),bmax(1)*maxi.^3+bmax(2)*maxi.^2+bmax(3)*maxi+bmax(4),'o','MarkerFaceColor',[0 0 0])
        A=round(100*sum(maxi<=180 & mini>=90)/length(maxi));
        B=round(100*sum((maxi >180 & maxi<=300 & mini>=70) | (mini<90 & maxi<=180 & mini>=70))/length(maxi));
        C=round(100*sum((maxi >300 & mini>=90) | (mini<70 & maxi<=180))/length(maxi));
        D=round(100*sum((maxi >300 & mini<90 & mini>=70) | (mini<70 & maxi>180 & maxi<300))/length(maxi));
        E=round(100*sum((maxi >300 & mini<70))/length(maxi));
        if A+B+C+D+E<100
            t=find(max([A B C D E])==[A B C D E],1,'first');
            switch t
                case 1
                    A=A+100-A-B-C-D-E;
                case 2
                    B=B+100-A-B-C-D-E;
                case 3
                    C=C+100-A-B-C-D-E;
                case 4
                    D=D+100-A-B-C-D-E;
                otherwise
            end
        end
        title(['A zone ' num2str(A) '%, B zone ' num2str(B) '%, C zone ' num2str(C) '%, D zone ' num2str(D) '%E zone ' num2str(E) '%'])
        drawnow    

    end
    if output.graphs(7)==1 % Blood Glucose density
        figure
        G=[];
        ind=find(results(1).time.signals.values<=Treg,1,'last');
        for i=1:n
            G=[G results(i).G.signals.values(ind:end)'];
            numg=numg+100*(1/n)/numgraph;
%   
        end
        [f,x]=ksdensity(log(G));
        x=exp(x);
        f=f/sum(f);

        tgt=output.tgt;

        bnd=[0 tgt(1) tgt(2) 600];
        for bin=1:3
            Q(bin)=100*sum(f((bnd(bin)<=x) & (x<bnd(bin+1))));
            if isempty(Q(bin))
                Q(bin)=0;
            end
        end

        plot(x,f,'b','LineWidth',2)
        hold on
        axis([0 600 0 max(f)*1.1])

        plot(tgt(1)*[1 1],[0 max(f)*1.1],'g--','LineWidth',2)
        plot(tgt(2)*[1 1],[0 max(f)*1.1],'g--','LineWidth',2)

        for bin=1:3
            text(mean(bnd(bin:bin+1)),max(f)/8,[num2str(round(Q(bin))) '%'],'FontSize',14,'HorizontalAlignment','center')
        end
        grid on
        xlabel('blood glucose [mg/dl]')
        title('BG density function')
        drawnow
    end

        
else
    for i=1:n
        
        if output.graphs(1)
            figure
            ind=find(results(i).time.signals.values<=Treg,1,'last');
            plot(results(i).time.signals.values(1:ind)/60,results(i).G.signals.values(1:ind),'k','Linewidth',2)
            hold on
            plot(results(i).time.signals.values(ind:end)/60,results(i).G.signals.values(ind:end),'g','Linewidth',2)
            title(['Glucose Trace subj: ' results(i).ID])
            xlabel('time [hour]')
            ylabel('blood glucose [mg/dl]')
            grid on
            drawnow
        end
        if output.graphs(2)
            ind=find(results(i).time.signals.values<=Treg,1,'last');
            for j=1:60:length(results(i).time.signals.values)-60-mod(length(results(i).time.signals.values),60)
                data((j-1)/60+1)=mean(10*(scaledBG(results(i).G.signals.values(j:j+59)).^2).*sign(scaledBG(results(i).G.signals.values(j:j+59))));
            end
            figure
            if ind>60
                bar(0.5:length(data(1:floor(ind/60)))-0.5,data(1:floor(ind/60)),'k')
                hold on
                bar(length(data(1:floor(ind/60)))+0.5:length(data(1:end))-0.5,data(ceil(ind/60):end),'g')
            else
                bar(0.5:length(data)-0.5,data,'g')
            end
            title(['Glucose Risk Trace subj: ' results(i).ID])
            xlabel('time [hour]')
            ylabel('Risk Index')
            grid on
            drawnow

        end
        if output.graphs(3)
            figure
            T1=[];
            T2=[];
            T3=[];
            ind=find(results(i).time.signals.values<=Treg,1,'last');
            for j=1:60:length(results(i).time.signals.values)-60-mod(length(results(i).time.signals.values),60)
                if mean(results(i).G.signals.values(j:j+59))<70
                    T1=[T1 (j-1)/60];
                elseif mean(results(i).G.signals.values(j:j+59))<=180
                    T2=[T2 (j-1)/60];
                elseif mean(results(i).G.signals.values(j:j+59))>180
                    T3=[T3 (j-1)/60];
                end
            end
            if ~isempty(T1)
                plot(T1,-1,'ksquare','MarkerFaceColor',[1 0 0])
            end
            hold on
            if ~isempty(T2)
                plot(T2,0,'ksquare','MarkerFaceColor',[0 1 0])
            end
            if ~isempty(T3)
                plot(T3,1,'ksquare','MarkerFaceColor',[1 1 0])
            end
            plot([0 max([T1 T2 T3 -1.5 1.5])],[-1 -1],':k')
            plot(ind/60*[1 1],[-1.5 1.5],'r-.','LineWidth',2)
            plot([0 max([T1 T2 T3 -1.5 1.5])],[0 0],':k')
            plot([0 max([T1 T2 T3 -1.5 1.5])],[1 1],':k')
            title(['Glucose Aggregated Trace subj: ' results(i).ID])
            xlabel('time [hour]')
            ylabel('Clinical zone')
            axis([0 max([T1 T2 T3]) -1.5 1.5] )
            set(gca,'YTick',[-1 0 1],'YtickLabel',{'Hypoglycemia','Euglycemia','Hyperglycemia'})
            drawnow

        end
        if output.graphs(4)
            clear data
            ind=find(results(i).time.signals.values<=Treg,1,'last');
            for j=1:length(results(i).time.signals.values)-15
                Y=results(i).G.signals.values(j:j+14);
                X=[ones(15,1) (1:15)'];
                beta=((X'*X)^(-1)*X'*Y);
                data(j)=beta(2);
            end
            figure
            hist(data(ind:end))
            title(['Histogram of the Blood Glucose Rate of Change during Regulation subj: ' results(i).ID])
            xlabel('Rate of Change [md.dl^{-1}.min^{-1}]')
            ylabel('Count')
            set(gca,'Xlim',[-4 4])
            drawnow

        end
        if output.graphs(5)
            clear data
            for j=1:60:length(results(i).time.signals.values)-60-mod(length(results(i).time.signals.values),60)
                data((j-1)/60+1)=mean(results(i).G.signals.values(j:j+59));

            end
            figure
            if ind>=60
                plot(data(1:floor(ind/60)-1),data(2:floor(ind/60)),'ok')
                hold on
                plot(data(floor(ind/60):end-1),data(floor(ind/60)+1:end),'og')
            else
                plot(data(1:end-1),data(2:end),'og')
            end
            title(['Poincare Plot subj: ' results(i).ID])
            xlabel('BG at hour h [mg/dl]')
            ylabel('BG at hour h+1 [mg/dl]')
            grid on
            axis([20 400 20 400])
            drawnow

        end
        if output.graphs(6)==1
            figure
            load CVGA
            imagesc(CVEG)
            set(gca,'Ytick',[10 833 1653 2472],'YtickLabel',[400 300 180 110])
            axis([0 2482 0 2482])
            set(gca,'Xtick',[10 832 1652 2472],'XtickLabel',[110 90 70 50])
            set(gca,'Box','off')
            hold on
            xlabel('lower 95% confidence bound [mg/dl]')
            ylabel('higher 95% confidence bound [mg/dl]')

            T=results(i).time.signals.values;
            G=results(i).G.signals.values;
            ind=find(T<=Treg,1,'last');
            T=T(ind:end);
            G=G(ind:end);
            if length(T)>2880
                for j=1:1440:length(T)-1440-mod(length(T),1440)
                    [f,x]=ecdf(G(j:j+1439));
                    mini((j-1)/1440+1)=min([110 max([50 x(find(f<=0.025,1,'last'))])]);
                    maxi((j-1)/1440+1)=max([110 min([400 x(find(f<=0.975,1,'last'))])]);
                end
            else
                [f,x]=ecdf(G);
                mini=min([110 max([50 x(find(f<=0.025,1,'last'))])]);
                maxi=max([110 min([400 x(find(f<=0.975,1,'last'))])]);
            end
            numg=numg+100*(1/n)/numgraph;
% 

            plot(bmin(1)*mini+bmin(2),bmax(1)*maxi.^3+bmax(2)*maxi.^2+bmax(3)*maxi+bmax(4),'o','MarkerFaceColor',[0 0 0])

            A=round(100*sum(sum(maxi<=180 & mini>=90)/sum(size(maxi).*fliplr(size(maxi)))/2));
            B=round(100*sum(sum((maxi >180 & maxi<=300 & mini>=70) | (mini<90 & maxi<=180 & mini>=70))/sum(size(maxi).*fliplr(size(maxi)))/2));
            C=round(100*sum(sum((maxi >300 & mini>=90) | (mini<70 & maxi<=180))/sum(size(maxi).*fliplr(size(maxi)))/2));
            D=round(100*sum(sum((maxi >300 & mini<90 & mini>=70) | (mini<70 & maxi>180 & maxi<300))/sum(size(maxi).*fliplr(size(maxi)))/2));
            E=round(100*sum(sum((maxi >300 & mini<70))/sum(size(maxi).*fliplr(size(maxi)))/2));
            if A+B+C+D+E<100
                t=find(max([A B C D E])==[A B C D E],1,'first');
                switch t
                    case 1
                        A=A+100-A-B-C-D-E;
                    case 2
                        B=B+100-A-B-C-D-E;
                    case 3
                        C=C+100-A-B-C-D-E;
                    case 4
                        D=D+100-A-B-C-D-E;
                    otherwise
                end
            end
            title(['subj ' results(i).ID 'A zone ' num2str(A) '%, B zone ' num2str(B) '%, C zone ' num2str(C) '%, D zone ' num2str(D) '%E zone ' num2str(E) '%'])

            drawnow

        elseif output.graphs(6)==2
            error_window('string','per subject CVGA points not compatible with per subject graph')


        end
        if output.graphs(7)==1
            figure
            T=results(i).time.signals.values;
            G=results(i).G.signals.values;
            ind=find(T<=Treg,1,'last');
            T=T(ind:end);
            G=G(ind:end);
            [f,x]=ksdensity(log(G));
            x=exp(x);
            f=f/sum(f);
            tgt=output.tgt;

            bnd=[0 tgt(1) tgt(2) 600];
            for bin=1:3
                Q(bin)=100*sum(f((bnd(bin)<=x) & (x<bnd(bin+1))));
                if isempty(Q(bin))
                    Q(bin)=0;
                end
            end

            plot(x,f,'b','LineWidth',2)
            hold on
            axis([0 600 0 max(f)*1.1])
            plot(tgt(1)*[1 1],[0 max(f)*1.1],'g--','LineWidth',2)
            plot(tgt(2)*[1 1],[0 max(f)*1.1],'g--','LineWidth',2)
            for bin=1:3
                text(mean(bnd(bin:bin+1)),max(f)/8,[num2str(round(Q(bin))) '%'],'FontSize',14,'HorizontalAlignment','center')
            end
            grid on
            xlabel('blood glucose [mg/dl]')
            title(['BG density function subj: ' results(i).ID])
            drawnow
        end

%  

    end
end

drawnow

%create outcome measures---------------------------------------------------
T=results(1).time.signals.values;
% 

parfor i=1:n
    T=results(i).time.signals.values;
    G=results(i).G.signals.values;
    ind=find(T<=Treg,1,'last');
    T=T(ind:end);
    G=G(ind:end);
    m=length(G);
    mBG(i)=mean(G);
    k=1;
    preBGa=[];
    postBGa=[];
    AUCa=[];
    lpostpra=[];
    postpra=[];
    

    Tmeal=results(i).time.signals.values(find(diff(results(i).CHO.signals.values)>0)+1);
    cumM=cumsum(results(i).CHO.signals.values);
    
    if sum(output.outcomes([2 3 9 14 15]))~=0
    Ameal=cumM(find(diff(results(i).CHO.signals.values)<0)+1);
    if ~isempty(Ameal)
        Ameal=[Ameal(1);diff(Ameal)];
        meals=[(Tmeal(Tmeal>=Treg)-Treg) Ameal(Tmeal>=Treg)]; % T=T-Treg & Meals >Treg
    else
        Ameal=[];
        meals=[];
    end
    
        for j=1:length(meals(:,1))
                preBGa(k)=mean(G(max([1 meals(j,1)-60]):meals(j,1)));
                postBGa(k)=mean(G(min([m meals(j,1)+60]):min([m meals(j,1)+120])));
                postpra=[postpra;G(min([m meals(j,1)+15]):min([m meals(j,1)+180]))];
                lpostpra=[lpostpra min([m meals(j,1)+15]):min([m meals(j,1)+180])];
                AUCa(k)=sum(G(meals(j,1)+1:min([m meals(j,1)+181]))-preBGa(k))/meals(j,2);
                k=k+1;
        end

        postabs=G(eliminate(1:m,lpostpra));

        preBG(i)=mean(preBGa(~isnan(preBGa)));
        postBG(i)=mean(postBGa(~isnan(preBGa)));
        AB(i)=100*(sum((postabs>80) & (postabs<=130))+sum((postpra>110) & (postpra<=180)))/m;
        EF(i)=100*(sum((postabs<=60) | (postabs>250))+sum((postpra>450) | (postpra<=60)))/m;
        AUC(i)=mean(AUCa);
    else
        preBG(i)=-9999;
        postBG(i)=-9999;
        AB(i)=-9999;
        EF(i)=-9999;
        AUC(i)=-9999;
    end
    
    pclow(i)=100*sum(G<=output.tgt(1))/m;
    pchigh(i)=100*sum(G>output.tgt(2))/m;
    pc50(i)=100*sum(G<=50)/m;
    pc300(i)=100*sum(G>300)/m;
    pctgt(i)=100-pclow(i)-pchigh(i);
    data=[];
    
    if sum(output.outcomes([10 11 12]))~=0
        for j=1:60:m-60-mod(m,60)
            data((j-1)/60+1)=mean(scaledBG(G(j:j+59)));
        end
        
        LBGI(i)=mean(10*(data.^2).*(data<=0));
        HBGI(i)=mean(10*(data.^2).*(data>=0));
        RI(i)=LBGI(i)+HBGI(i);
    else
        LBGI(i)=-9999;
        HBGI(i)=-9999;
        RI(i)=-9999;
    end
    
    data=[];
    if output.outcomes(13)~=0
        for j=1:m-15-mod(m,15)
            Y=mean(G(j:j+14));
            X=[ones(15,1) (1:15)'];
            beta=((X'*X)^(-1)*X'*Y);
            data=[data beta(2)];
        end
        SD_RoC(i)=std(data);
    else
        SD_RoC(i)=-9999;
    end
    % 
    ID{i}=results(i).ID;
end
% 
% 
data=[mBG' preBG' postBG' pc50' pclow' pctgt' pchigh' pc300' AUC' LBGI' HBGI' RI' SD_RoC' AB' EF'];
%ColNames={'Mean BG','Mean pre-meal BG','Mean post-meal BG','% time < 50','% time < 70','% time in [70-180]','% time > 180','% time > 300','Post-prandial AUC/g CHO','LBGI','HBGI','BG Risk Index (BGRI)','SD of BG Rate of Change (RoC)','% A+B zone','% E+F zone'};
ColNames={'Mean BG','Mean pre-meal BG','Mean post-meal BG','% time < 50','% time < TGT-low','% time in Target','% time > TGT-high','% time > 300','Post-prandial AUC/g CHO','LBGI','HBGI','BG Risk Index (BGRI)','SD of BG Rate of Change (RoC)','% A+B zone','% E+F zone'};

dataW=[ID'];
datanames={'ID'};
data=mat2cell(data,ones(size(data(:,1))),ones(size(data(1,:)')));

% Re Orders Column Names to match Col Names order + choose outcome measures
columnew=[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
for i=1:15
    if output.outcomes(i)
        if i==6
        columnew(4)=1;  
        elseif i==4
        columnew(5)=1;         
        elseif i==8
        columnew(6)=1;             
        elseif i==5
        columnew(7)=1;    
        elseif i==7
        columnew(8)=1;            
        else
         columnew(i)=1;
        end
    end
end

k=2;
for i=1:15
    if columnew(i)
        dataW=[dataW data(:,i)];
        datanames{k}=ColNames{i};
        k=k+1;
    end
end
drawnow
%test function call placement
test.o =output;
test.r =results;
%write in the output file
if saveastxt
filename=enter_filename('string','results_default');
drawnow

dlmwrite(['results' filesep filename '.txt'],[]);
s=size(dataW);
fid=fopen(['results' filesep filename '.txt'],'w');
for i=1:s(2)
    fprintf(fid,'%s\t',datanames{i});
end
fprintf(fid,'%s\n',[]);

for i=1:s(1)
    fprintf(fid,'%s\t',dataW{i,1});
    for j=2:s(2)
        fprintf(fid,'%.2f\t',dataW{i,j});
    end
    fprintf(fid,'%s\n',[]);
end
fclose(fid);
end
catch e
    e.message
end