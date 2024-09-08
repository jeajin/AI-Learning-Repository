load test_data
run_Callback(hObject, eventdata, handles)
h = get(gca,'Children')
x = get(h(2),'xdata')
y = get(h(2),'ydata')
test_data = [x' ; y']

yy=y
for i=1:numel(yy)/5
    yy(i) = yy(i*5);
end
yy = yy(1:numel(yy)/7)


d = yy
numTimeStepsTrain = floor(0.9*numel(d));

dataTrain = d(1:numTimeStepsTrain+1);
dataTest = d(numTimeStepsTrain+1:end);

mu = mean(dataTrain);
sig = std(dataTrain);

dataTrainStandardized = (dataTrain - mu) / sig;

XTrain = dataTrainStandardized(1:end-1);
YTrain = dataTrainStandardized(2:end);

numFeatures = 1;
numResponses = 1;
numHiddenUnits = 200;

layers = [ ...
    sequenceInputLayer(numFeatures)
    lstmLayer(numHiddenUnits)
    fullyConnectedLayer(numResponses)
    regressionLayer];

options = trainingOptions('adam', ...
    'MaxEpochs',250, ...
    'GradientThreshold',1, ...
    'InitialLearnRate',0.005, ...
    'LearnRateSchedule','piecewise', ...
    'LearnRateDropPeriod',125, ...
    'LearnRateDropFactor',0.2, ...
    'Verbose',0, ...
    'Plots','training-progress');

net = trainNetwork(XTrain,YTrain,layers,options);


dataTestStandardized = (dataTest - mu) / sig;
XTest = dataTestStandardized(1:end-1);

%net = predictAndUpdateState(net,XTrain);
%[net,YPred] = predictAndUpdateState(net,YTrain(end));

net = resetState(net);
net = predictAndUpdateState(net,XTrain);

YPred = [];
numTimeStepsTest = numel(XTest);
for i = 1:numTimeStepsTest
    [net,YPred(:,i)] = predictAndUpdateState(net,XTest(:,i),'ExecutionEnvironment','cpu');
end

YPred = sig*YPred + mu;

YTest = dataTest(2:end);
rmse = sqrt(mean((YPred-YTest).^2))

figure
plot(dataTrain(1:end-1))
hold on
idx = numTimeStepsTrain:(numTimeStepsTrain+numTimeStepsTest);
plot(idx,[d(numTimeStepsTrain) YPred],'-')
hold off
xlabel("Month")
ylabel("Cases")
title("Forecast")
legend(["Observed" "Forecast"])

function run_Callback(hObject, eventdata, handles)
% hObject    handle to run (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
 display('T1DMS Simulation IN PROGRESS, please wait . . .')
warning('off','all')
load sim_data Lstruttura Lscenario hardware
Lst=Lstruttura;
hd=hardware;
Nscenario=length(Lscenario);

for scen=1:Nscenario
    scenario=Lscenario(scen);
    
    if isempty(scenario.CR)
        scenario.CR='off';
    end
    
    sc_checked=get(handles.scenario_check,'Value');
    sb_checked=get(handles.subject_check,'Value');
    
    if ~sc_checked
        error_window('string','You need to select a scenario')
    elseif ~sb_checked
        error_window('string','You need to select at least 1 subject')
    else
        
%          sb = statusbar(hObject,['Scenario ' num2str(scen) '/' num2str(Nscenario) ' simulation in progress, please wait.']);
%                 sb.getParent.setVisible(1)
%                 set(sb.ProgressBar, 'Visible','on', 'Indeterminate','off');
%                 set(sb.ProgressBar, 'Visible','on', 'StringPainted','on');
%                 set(sb.ProgressBar,'Value',0)
        n=length(Lstruttura);
        
        rep=round(str2double(get(handles.repeat,'String')))*get(handles.repInd,'Value');
        
        if isempty(rep)
            rep=1;
        elseif rep<=0
            rep=1;
        end
        
        %creating a single randomgenerator per patient ensures independence
        %accross subject AND reproducibility.
        seed=str2double(get(handles.seed,'String'));
        if isnan(seed) || isempty(seed)
            seed=sum(100*clock);
        end
        for ind=1:n
            Lst(ind).rg=RandStream.create('mrg32k3a','NumStreams',n,'StreamIndices',ind,'Seed',seed);
        end
        
        bck_SQinsulin=scenario.SQ_insulin.signals;
        
        bck_meals=scenario.meals;
        bck_meal_announce=scenario.meal_announce;
        scenario_bck=scenario;
        tic % tic toc tic toc tic toc tic toc 
        addpath('controller setup')
%      
%      
%      
%      
%       
%      
%      
%      
%      

        parfor ind=1:n    % % 
            try
            sc=scenario_bck;
            struttura=Lst(ind);
            display(['simulating ' struttura.names])
            drawnow
            res_aux=run_simulation(sc,struttura,hd,rep,bck_meals,...
                bck_meal_announce,bck_SQinsulin,ind);
            resultsb(ind).res=res_aux;
            display(['end of ' struttura.names])        
            catch e                
                rethrow(e);
            end
        end

        toc % tic toc tic toc tic toc tic toc 
        for ind=1:n
            for k=1:rep
                results((ind-1)*rep+k)=resultsb(ind).res{k};
            end
        end
        
        clear resultsb
        data(scen).results=results;
        data(scen).scenario=scenario_bck;
        data(scen).hardware=hd;    % % for Audit in dataFile
        % ***** Store ctrlsetup settings ***** 
        % Subject Specific (Quest calculated) values are reported as 0
        % All Values may not be used in The Controller
         data(scen).ctrlsetup = ctrlsetup(...
             struct('basal',0,'OB',0,'MD',0,'names',0,'weight',0,'fastingBG',0),...
             [],...
             [],...
             [],[]);  % {'basal','OB','MD','CR','CF','name','BW','fastingBG'});
            data(scen).ctrlsetup.Note_1 = 'Subject Specific Values (Quest.*, OB, CR, basal, etc.) may be reported = 0';
            data(scen).ctrlsetup.Note_2 = 'ctrlsetup.m ctrller.* Info is not necessarily included in Simulink controller';
            data(scen).ctrlsetup.Note_3 = 'ctrlsetup.m Info provided for auditing purposes';
        %***** Done storing ctrolsetup *****
        save sim_results data
        display('T1DMS Simulation of Subjects is complete, Computing Outcomes . . .')
        load sim_out output
        delete(['tempres' filesep '*'])
        %    
        create_output(results,output,[scenario.Tdose(2:end)' scenario.dose(2:end)'],scenario.Treg,get(handles.saveastxt,'Value'));
        clear results
           SCEN1 = int2str(scen);
           SCEN2 = int2str(Nscenario);
            message1 = strcat('Scenario_', SCEN1,'_of_',SCEN2);
            disp(message1)        
            display('T1DMS Simulation has ended . . .')
            if scen < Nscenario
                display('WAIT for next Scenario Simulation . . .')
                display('T1DMS Simulation IN PROGRESS, please wait . . .')
            end

    end
    
        
    guidata(hObject,handles)
    
    
end
if length(Lscenario)>1
    popstat=accrossscenario_output('String','Do you want summary statistics and graphs (accross scenario)?');
    if popstat
        load sim_out output
        accross_output(data,output,get(handles.saveastxt,'Value'));
        display(' accross_outpu')
    end
end
end






