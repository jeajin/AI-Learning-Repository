%> @file run_metabolic_test.m
%> @brief Run an open loop scenario from the ctrlsetup.m file through the metab_platform simulink model (open loop model). 
%> The metabolic test data & data collection timing is set using *Define Metabolic Test* in the main window.
%> The completed test results can be saved in metab_results.mat and are available in the ctrlsetup.m file prior to continuing the simulation into a closed loop controller. 
%>
%> The output data is confined to the selections using `measures` in the *metab_meas.mat*. 
%> 
%> See **controller_doc.m** and **ctrlsetup_MetabTest.m** for more information.  
%> The user is encouraged to investigate this tool before implementing into a controller.
%>
%> @copyright 2008-2013 University of Virginia.
%> @copyright 2014 The Epsilon Group, An Alere Company.

%> @par Syntax
%> @code 
%>  [data]=run_metabolic_test(filename,Quest,struttura,hardware)
%> @endcode
%> @param filename scenario filename (.scn) that is used for metabolic_test.
%> @param struttura A matlab structure containing the main parameters in the human model. See @link strt_doc.m @endlink for more detail.
%> @param scenario A matlab structure containing scenario profiles. See @link scn_doc.m @endlink for more detail.
%> @param hardware Hardware specification. Loaded from sim_data.mat after hardware selection.
%> @param Quest Subject specific parameters as a return value of @link load_quest @endlink. See @link load_quest @endlink for more detail.
%> @retval data Metabolic test result with confined range pre-set using `measures` in the *metab_meas.mat*.
function [data]=run_metabolic_test(filename,struttura,scenario,hardware,Quest)
%
%
path_root=[cd '..'];
addpath(path_root)

%  
[struttura,scenario]=set_metabolic_test(filename,Quest,struttura,hardware);

%     version 3.2 steady state
    if ~isempty(scenario.BGinit)
        if scenario.BGinit<struttura.Gb
            fGp=log(scenario.BGinit)^struttura.r1-struttura.r2;
            risk=10*fGp^2;
        else
            risk=0;
        end
        if scenario.BGinit*struttura.Vg>struttura.ke2
            Et=struttura.ke1*(scenario.BGinit*struttura.Vg-struttura.ke2);
        else
            Et=0;
        end
        Gpop=scenario.BGinit*struttura.Vg;
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

cd ..

    
sim('metab_platform',[0:scenario.Tsimul],simset('SrcWorkspace','current'));
                metab_results.G=G;
                metab_results.states=system_state;
                metab_results.injection=injection;
                metab_results.CGM=CGM;
                metab_results.CHO=carb_intake;
save metab_results

try
    load metab_meas measures
catch %#ok<CTCH>
    measures=[];
end
% 
data=[];
if ~isempty(measures)
    for i=1:length(measures)
        data(i).time=measures(i).T+1;
        data(i).value=measured.signals.values(measures(i).T+1,measures(i).ID);
    end
else
    data=system_state.signals.values;
end