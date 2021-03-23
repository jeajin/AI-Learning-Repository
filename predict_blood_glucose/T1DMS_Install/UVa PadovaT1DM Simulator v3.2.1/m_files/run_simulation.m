%> @file run_simulation.m
%> @brief Runs a simulation based on scenario, subject, and other specifications.
%>
%> Function prepares the simulation with values such as the simulation time, meal, and bolus
%> amounts and times. It also sets up the initial conditions for the human model, 
%> and finally calls function @link simulateT1DM@endlink to run the simulation. 
%> Results are stored in the resultsa structured, the returned value.
%> @par Calls: 
%> @link simulateT1DM@endlink, @link ctrlsetup@endlink.
%> @par Called: 
%> called from Simulator.m 
%>
%> @copyright 2008-2013 University of Virginia
%> @copyright 2013 The Epsilon Group

%> @brief Setup, run, and process results of the simulation
%> @param sc Scenario information contained in a structure (see @link scn_doc.m@endlink).
%> @param struttura Subject information.
%> @param hd Hardware (sensor + pump) information.
%> @param rep Number of replicates for the simulation.
%> @param bck_meals Meal times and amounts.
%> @param bck_meal_announce Meal announcement times & amounts.
%> @param bck_SQinsulin Subcutaneous insulin information.
%> @param ind subject identifier.
function resultsa=run_simulation(sc,struttura,hd,rep,bck_meals,bck_meal_announce,bck_SQinsulin,ind)
% RUN_SIMULATION Setup, run, and process results of the simulation
%   resulsa = run_simulation( sc, struttura, hd, rep, bck_meals, bck_meal_announce, bck_SQinsulin )
%
% 2014.01.07 Ensure compatibility with Matlab versions 2010 thru 2013 
% 2014.01.07 Implemented in the beginning of run_simulation.m 
% 2014.01.07 +++ rand generate +++ per Matlab Version
% 2014.01.07 sets the random generator to the subject specific stream
    curVer = version('-release');
    VerCheck = strrep(curVer, 'a', '0');
    VerCheck = strrep(VerCheck, 'b', '1');
    VERnum = str2num(VerCheck);
if VERnum > 20110  % corresponds to ver 2011a
	RandStream.setGlobalStream(struttura.rg);
    else
    RandStream.setDefaultStream(struttura.rg);
end           % +++++++++++

path_root=[cd filesep 'controller setup']; %path_root=[cd '\controller setup'];
% path_root=[cd '..'];
addpath(path_root)
resultsa=cell(rep,1);

struttura.Tclosed=sc.Tclosed;
struttura.simul=sc.Tsimul;
struttura.simToD=sc.simToD;

struttura.Tdose=sc.Tdose;
struttura.dose=sc.dose;
if strcmp(sc.Qmeals,'perkg')
    sc.meals(:,2)=bck_meals(:,2)*struttura.BW;
    sc.meal_announce.signals.values(:,1)=bck_meal_announce.signals.values(:,1)*struttura.BW;
    struttura.dose(2:end)=sc.dose(2:end)*struttura.BW;
end
% 
% Converts doses to absolute values when boluses are specified per kg.
if strcmp(sc.Qbolus,'perkg')
    sc.SQ_insulin.signals.values(:,2)=bck_SQinsulin.values(:,2)*struttura.BW;
end

%load questionnaires answers
Quest=load_quest(struttura.names);

if strcmp(sc.Qbasal,'quest')
    sc.SQ_insulin.signals.values(:,1)=Quest.basal/60;
end
%  Open Loop 'perkg'
% 
    if strcmp(sc.QIVins,'perkg')
        sc.IV_insulin(:,2)=sc.IV_insulin(:,2)*struttura.BW;
    end
%  OL perkg IV_glucose
    if strcmp(sc.QIVD,'perkg')
        sc.IV_glucose(:,2)=sc.IV_glucose(:,2)*struttura.BW;
    end
%
if strcmp(sc.CR,'on')
    sc.SQ_insulin.signals.values(:,2)=bck_SQinsulin.values(:,2)/Quest.OB;
    if strcmp(sc.Qmeals,'perkg')
        sc.SQ_insulin.signals.values(:,2)=bck_SQinsulin.values(:,2)/Quest.OB*struttura.BW;
    end
end

if ~isfield(sc,'BGinit') 
    sc.BGinit=Quest.fastingBG;
end
if isempty(sc.BGinit) 
    sc.BGinit=Quest.fastingBG;
end
% % default values
ctrller.default=0;
%  
ctrller=ctrlsetup(Quest,hd,sc,ctrller,struttura);
%  


for k2=1:rep
    
    
    
    struttura=create_noise(struttura,sc,hd);
    
    
    
    if ~isempty(sc.BGinit)
        if sc.BGinit<struttura.Gb
            fGp=log(sc.BGinit)^struttura.r1-struttura.r2;
            risk=10*fGp^2;
        else
            risk=0;
        end
        if sc.BGinit*struttura.Vg>struttura.ke2
            Et=struttura.ke1*(sc.BGinit*struttura.Vg-struttura.ke2);
        else
            Et=0;
        end
        Gpop=sc.BGinit*struttura.Vg;
        GGta=-struttura.k2-struttura.Vmx*(1+struttura.r3*risk)*struttura.k2/struttura.kp3;
        GGtb=struttura.k1*Gpop-struttura.k2*struttura.Km0-struttura.Vm0+struttura.Vmx*(1+struttura.r3*risk)*struttura.Ib+...
            (struttura.Vmx*(1+struttura.r3*risk)*(struttura.k1+struttura.kp2)*Gpop-struttura.Vmx*(1+struttura.r3*risk)*struttura.kp1+struttura.Vmx*(1+struttura.r3*risk)*(struttura.Fsnc+Et))/struttura.kp3;
        GGtc=struttura.k1*Gpop*struttura.Km0;
        Gtop=(-GGtb-sqrt(GGtb^2-4*GGta*GGtc))/(2*GGta);
        Idop=max([0 (-(struttura.k1+struttura.kp2)*Gpop+struttura.k2*Gtop+struttura.kp1-(struttura.Fsnc+Et))/struttura.kp3]);
        Ipop=Idop*struttura.Vi;
        ILop=struttura.m2*Ipop/(struttura.m1+struttura.m30);
        Xop=Ipop/struttura.Vi-struttura.Ib;
        isc1op=max([0 ((struttura.m2+struttura.m4)*Ipop-struttura.m1*ILop)/(struttura.ka1+struttura.kd)]);
        isc2op=struttura.kd*isc1op/struttura.ka2;
        u2op=(struttura.ka1+struttura.kd)*isc1op;
        
        
        struttura.x0=[0	0 0	Gpop Gtop Ipop Xop Idop	Idop ILop isc1op isc2op Gpop struttura.Gnb 0 struttura.k01g*struttura.Gnb 0 0];

        
    end
    
    G=0;
    system_state=0;
    time=0;
    injection=0;
    sensor=0;  % 
    carb_intake=0;
    BOLUS=0;
    BASAL=0;
    To_PUMP=0;
  
    
    %  - modify variable names to simulateT1DM
    [G,system_state,time,injection,sensor,carb_intake,BOLUS,BASAL,To_PUMP]=simulateT1DM(struttura,sc,hd,Quest,ctrller,k2,ind);

    drawnow
    %         
    resultsa{k2}.G=G;
    resultsa{k2}.state=system_state;
    resultsa{k2}.time=time;
    resultsa{k2}.injection=injection;
    resultsa{k2}.sensor=sensor;
    resultsa{k2}.ID=struttura.names;
    resultsa{k2}.CHO=carb_intake;
    resultsa{k2}.BOLUS=BOLUS;
    resultsa{k2}.BASAL=BASAL;
    resultsa{k2}.To_PUMP=To_PUMP;

    clear G system_state time injection sensor carb_intake
    clear BOLUS BASAL To_PUMP
    
    
    
    drawnow
end