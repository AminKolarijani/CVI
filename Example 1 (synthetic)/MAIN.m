% This file is an example of implementation of the CVI and VI algorithms 
% for solving the infinite-horizon optimal control problem for a
% stochastic linear dyanmics. 
% Please also see Section 4.1 of the following article for more details:
%   
%   M.A.S. Kolarijani, C.F. Max, and P. Mohajerin Esfahani (2021), 
%   Fast Approximate Dynamic Programming for Infinite-Horizon 
%   Continuous-State Markov Decision Processes, 
%   preprint arXiv:2102.08880.
% 

clc
clear all

%% Optimal control problem instances (initial states and horizon) 
T = 100; % horizon
NumInstances = 100; % the number of instances (initial states)

% Initial states
initial_state_set = cell(NumInstances,1); % the set of initial states (allocation)
Delta_x = [-1,1; -1,1]; % i-th row determines the range of i-th state
for i_Inst = 1:NumInstances
    initial_state_set{i_Inst} = Delta_x(:,1) + (Delta_x(:,2) - Delta_x(:,1)).*rand(size(Delta_x,1),1);
end

% Stochasticity 
W1 = [-.05, 0, .05];
W2 = 0;
W = combvec(W1,W2); % discrete set of disturbance (column vectors)
pmf_W = ones(1,size(W,2))/size(W,2); % disturbance probability mass function

disturb_seq = cell(NumInstances,1);
for i_Inst = 1:NumInstances
    ind_w_t = randsample(length(pmf_W),T,true,pmf_W);
    disturb_seq{i_Inst} = W(:,ind_w_t);
end

%% Implementation of algorithms and solving the problem instances

% Size of the grids for discretization
N_set = [11 15 21 25 31 35 41]; % grid sizes 11*11, ...

i_N = 1;
save GS_IS_Data

while i_N <= length(N_set) % iteraton over grid sizes
    
    clear all
    
    % Optimal control problem instances (initial states and horizon)
    load GS_IS_Data
    
    %======================================================================
    
    % (1) Problem data (inputs given by the user)

    % Dynamics: f(x,u) = Ax+Bu (linear dynamics)
    A = [2 1;1 3]; state_dynamics = @(x) (A*x); 
    B = [1 1;1 2]; input_matrix = B; 
    
    % Constraints
    x_constraints = @(x) ([1 0;-1 0; 0 1; 0 -1]*x - ones(4,1)); % state constraints: x \in [-1,1]^2
    u_constraints = @(u) ([1 0;-1 0; 0 1; 0 -1]*u - 2*ones(4,1)); % input constraints: u \in [-2,2]^2

    % Cost functions
    state_cost = @(x) (10*x'*x); % quadratic stage cost (state)
    input_cost = @(u) (exp(abs(u(1))) + exp(abs(u(2))))-2; % L-1 stage cost (input)

    % Conjugate of input-dependent stage cost
    Delta_u = [-2,2; -2,2]; % i-th row determines the range of i-th input
    conj_input_cost = @(v) (conj_ExpL1_box(Delta_u(:,1),Delta_u(:,2),v));
    
    % Discouont factor
    gamma = 0.95;

    % Discretization of the state and input (and their dual) spaces    
    %   State space discretization (uniform grid)
    N = N_set(i_N)*[1,1];
    N_x = N; % vector of number of data points in the discretization of state space in EACH dimension
    Delta_x = [-1,1; -1,1]; % i-th row determines the range of i-th state
    state_grid = unif_grid(Delta_x,N_x); % so the discretization of the state space is a uniform grid of size 11^2 over [-1,1]^2 
    %   Input space discretization (uniform grid) - similar to state space discretization described above
    N_u = N; 
    Delta_u = [-2,2; -2,2]; 
    input_grid = unif_grid(Delta_u,N_u); 
    %   The state dual grid (Y_g):
    N_y = N_x; 
    %   The grid (Z_g):
    N_z = N_x;
    %   The input dual grid (V_g):
    N_v = N_u;
    %   Set the value of the coefficeint "alpha" 
    alpha_y = 1;
    
    % Configuration of VI and CVI algorithms
    VI_implementation = true;
    fast_stoch_DP = false;
    VI_interpol_mehtod = 'linear';
    VI_extrapol_mehtod = 'linear';
    
    CVI_interpol_mehtod = 'linear';
    CVI_extrapol_mehtod = 'linear';

    epsilon = 0.001; % Termination bound
    max_iteration = 1000; % Maximum number of iterations (if the algorithm is not convergent)
    %======================================================================
    
    % (2) Problem data (data objects defined for internal use)

    ProblemData = struct;

    % Dynamics
    ProblemData.StateDynamics = state_dynamics;
    ProblemData.InputMatrix = input_matrix;
    ProblemData.InputDynamics = @(x) (input_matrix); 
    ProblemData.Dynamics = @(x,u) (ProblemData.StateDynamics(x) + ProblemData.InputDynamics(x) * u);
    
    % Disturbance
    ProblemData.DiscreteDisturbance = W; 
    ProblemData.DisturbancePMF = pmf_W;

    % Constraints
    ProblemData.StateConstraints = x_constraints; 
    ProblemData.InputConstraints = u_constraints; 

    % Cost functions and conjugates
    ProblemData.StateCost = state_cost;
    ProblemData.InputCost = input_cost;
    ProblemData.ConjugateInputCost = conj_input_cost; 

    % Discount factor
    ProblemData.DiscountFactor = gamma; 

    % Control problem instance
    ProblemData.Horizon = T;

    % Discretizations
    ProblemData.StateGridSize = N_x; 
    ProblemData.InputGridSize = N_u; 
    ProblemData.StateDualGridSize = N_y;
    ProblemData.StateDynamicsGridSize = N_z;
    ProblemData.InputDualGridSize = N_v; 
    
    ProblemData.StateGrid = state_grid;
    ProblemData.InputGrid = input_grid;

    % Configuration of VI and CVI algorithms
    VI_Data = struct;
    VI_Data.FastStochastic = fast_stoch_DP ;
    VI_Data.ExtensionInterpolationMethod = VI_interpol_mehtod;
    VI_Data.ExtensionExtrapolationMethod = VI_extrapol_mehtod;
    VI_Data.TerminationError = epsilon;
    VI_Data.MaxIteration = max_iteration;

    CVI_Data = struct;
    CVI_Data.TerminationError = epsilon;
    CVI_Data.MaxIteration = max_iteration;
    CVI_Data.ExpectationInterpolationMethod = CVI_interpol_mehtod;
    CVI_Data.ExpectationExtrapolationMethod = CVI_extrapol_mehtod;
    
    %======================================================================
    
    % Feasibility check of discretization scheme
    ProblemData.Stochastic = true;
    feasibility_check(ProblemData)
    
    %======================================================================
    % (3) Implementation and Results
    
    %  Output data
    Result = struct;
    Result.InitialState = initial_state_set;
    Result.DisturbanceSequence = disturb_seq;
    
    %----------------------------------------------------------------------
    % CVI Algorithm 
    
    ProblemData.Stochastic = true; % Stochastic dynamcis
    CVI_Data.NumericalConjugateCost = true; % numerical computation of the conjugate of input cost
    CVI_Data.DualGridConstructionAlpha = 1; % the coefficient alpha for construction of Y_g
    CVI_Data.DynamicDualGridConstruction = false; % dynamic construction of Y_g
    
    [temp1, temp2, temp3] = CVI_Alg(ProblemData, CVI_Data);
    Result.V_CVI = temp1;
    Result.conv_CVI = temp2;
    Result.rt_CVI = sum(temp3);

    for i_Inst = 1:NumInstances % Iteraton over control problem instances

        ProblemData.InitialState = Result.InitialState{i_Inst}; 
        ProblemData.DisturbanceSequence = Result.DisturbanceSequence{i_Inst}; 

        [dummy1, dummy2, temp4] = forward_iter(ProblemData, temp1);
        Result.tc_CVI(i_Inst) = temp4;
    end
    
    %----------------------------------------------------------------------
    % CVI Algorithm (dynamic contruction of Y_g)
    
    ProblemData.Stochastic = true; % Stochastic dynamcis
    CVI_Data.NumericalConjugateCost = true; % numerical computation of the conjugate of input cost
    CVI_Data.DualGridConstructionAlpha = 1; % the coefficient alpha for construction of Y_g
    CVI_Data.DynamicDualGridConstruction = true; % dynamic construction of Y_g
    
    [temp5, temp6, temp7] = CVI_Alg(ProblemData, CVI_Data);
    Result.V_CVI_d = temp5;
    Result.conv_CVI_d = temp6;
    Result.rt_CVI_d = sum(temp7);

    for i_Inst = 1:NumInstances % Iteraton over control problem instances

        ProblemData.InitialState = Result.InitialState{i_Inst};
        ProblemData.DisturbanceSequence = Result.DisturbanceSequence{i_Inst}; 

        [dummy3, dummy4, temp8] = forward_iter(ProblemData, temp5);
        Result.tc_CVI_d(i_Inst) = temp8;
    end

    %----------------------------------------------------------------------
    % VI Algorithm
    
    [temp13, temp14, temp15] = VI_Alg(ProblemData, VI_Data);
    Result.V_VI = temp13;
    Result.conv_VI = temp14;
    Result.rt_VI = temp15;

    for i_Inst = 1:NumInstances % Iteraton over control problem instances
        
        ProblemData.InitialState = Result.InitialState{i_Inst};
        ProblemData.DisturbanceSequence = Result.DisturbanceSequence{i_Inst};
        
        [dummy7, dummy8, temp16] = forward_iter(ProblemData, temp13);
        Result.tc_VI(i_Inst) = temp16;
    end
    
    %----------------------------------------------------------------------
    % CVI Algorithm (deterministic system)
    
    ProblemData.Stochastic = false; % Stochastic dynamcis
    CVI_Data.NumericalConjugateCost = true; % numerical computation of the conjugate of input cost
    CVI_Data.DualGridConstructionAlpha = 1; % the coefficient alpha for construction of Y_g
    CVI_Data.DynamicDualGridConstruction = false; % dynamic construction of Y_g
    
    [temp9, temp10, temp11] = CVI_Alg(ProblemData, CVI_Data);
    Result.V_CVI_dd = temp9;
    Result.conv_CVI_dd = temp10;
    Result.rt_CVI_dd = sum(temp11);

    %----------------------------------------------------------------------
    % CVI Algorithm (deterministic system - dynamic dual grid with alpha = 1)
    
    ProblemData.Stochastic = false; % Stochastic dynamcis
    CVI_Data.NumericalConjugateCost = true; % numerical computation of the conjugate of input cost
    CVI_Data.DualGridConstructionAlpha = 1; % the coefficient alpha for construction of Y_g
    CVI_Data.DynamicDualGridConstruction = true; % dynamic construction of Y_g
    
    [temp17, temp18, temp19] = CVI_Alg(ProblemData, CVI_Data);
    Result.V_CVI_d1_dd = temp17;
    Result.conv_CVI_d1_dd = temp18;
    Result.rt_CVI_d1_dd = sum(temp19);

    %----------------------------------------------------------------------
    % CVI Algorithm (deterministic system - dynamic dual grid with alpha = 3)
    
    ProblemData.Stochastic = false; % Stochastic dynamcis
    CVI_Data.NumericalConjugateCost = true; % numerical computation of the conjugate of input cost
    CVI_Data.DualGridConstructionAlpha = 3; % the coefficient alpha for construction of Y_g
    CVI_Data.DynamicDualGridConstruction = true; % dynamic construction of Y_g
    
    [temp20, temp21, temp22] = CVI_Alg(ProblemData, CVI_Data);
    Result.V_CVI_d3_dd = temp20;
    Result.conv_CVI_d3_dd = temp21;
    Result.rt_CVI_d3_dd = sum(temp22);

    %----------------------------------------------------------------------
    % VI Algorithm (deterministic dynamics)
    
    [temp23, temp24, temp25] = VI_Alg(ProblemData, VI_Data);
    Result.V_VI_dd = temp23;
    Result.conv_VI_dd = temp24;
    Result.rt_VI_dd = temp25;
    
    %----------------------------------------------------------------------
    % CVI Algorithm (analyticallay avaialble conjugate of input cost) 
    
    ProblemData.Stochastic = true; % Stochastic dynamcis
    CVI_Data.NumericalConjugateCost = false; % numerical computation of the conjugate of input cost
    CVI_Data.DualGridConstructionAlpha = 1; % the coefficient alpha for construction of Y_g
    CVI_Data.DynamicDualGridConstruction = false; % dynamic construction of Y_g
    
    [temp26, temp27, temp28] = CVI_Alg(ProblemData, CVI_Data);
    Result.V_CVI_a = temp26;
    Result.conv_CVI_a = temp27;
    Result.rt_CVI_a = sum(temp28);

    for i_Inst = 1:NumInstances % Iteraton over control problem instances

        ProblemData.InitialState = Result.InitialState{i_Inst}; 
        ProblemData.DisturbanceSequence = Result.DisturbanceSequence{i_Inst}; 

        [dummy9, dummy10, temp29] = forward_iter(ProblemData, temp26);
        Result.tc_CVI_a(i_Inst) = temp29;
    end
    
    %----------------------------------------------------------------------

    % Saving the results for each grid size 
    str = sprintf('Ex_1_Data_N%2.0f',N(1));
    save(str,'ProblemData','VI_Data','CVI_Data','Result')
    
    % Next grid size
    i_N = i_N+1
    save('GS_IS_Data','i_N','-append')

end

%% Analysis of results

gamma = 0.95; % discount factor
N_set = [11 15 21 25 31 35 41]; % grid sizes 11*11, ...

% Convergence rate of VI and CVI for largest grid size
i_N = length(N_set);
N = N_set(i_N);
str = sprintf('Ex_1_Data_N%2.0f',N);
load(str)

Convergence_VI = Result.conv_VI(2:end);
Convergence_CVI = Result.conv_CVI(2:end);  
Convergence_CVI_d = Result.conv_CVI_d(2:end); % CVI with dynamic Y_g

gamma_rate = zeros(1,length(Convergence_VI));
gamma_rate(1) = Convergence_CVI_d(1);
for i=1:length(Convergence_VI)
    gamma_rate(i+1) = gamma*gamma_rate(i);
end

h1 = figure;
semilogy(1:length(Convergence_VI),Convergence_VI,'Color',[.0 .45 .74],'LineStyle','-','Marker','none','LineWidth',1.5)
hold on
semilogy(1:length(Convergence_CVI),Convergence_CVI,'Color',[0 0.5 0],'LineStyle','-.','Marker','none','LineWidth',1.5)
semilogy(1:length(Convergence_CVI_d),Convergence_CVI_d,'Color',[.85 .33 .1],'LineStyle','--','Marker','none','LineWidth',1.5)
semilogy(1:length(gamma_rate),gamma_rate,'Color','k','LineStyle',':','Marker','none','LineWidth',1.5)
hold off
ylabel('$\Vert J - J_+ \Vert_{\infty}$','FontSize',10,'Interpreter','latex')
xlabel('Iteration, $k$','FontSize',10,'Interpreter','latex')
txt1 = 'VI';
txt2 = 'CVI';
txt3 = 'CVI-d';
legend({txt1, txt2, txt3},'Interpreter','latex','Orientation','vertical','Location','northeast','FontSize',10)
ax = gca;
ax.Box = 'on';
grid on

% %==========================================================================
% Running time of VI and CVI for different grid sizes
RunTime_VI = zeros(1,length(N_set));
RunTime_CVI = zeros(1,length(N_set)); 
RunTime_CVI_d = zeros(1,length(N_set));  % CVI with dynamic Y_g

for i_N = 1:length(N_set)
    
    N = N_set(i_N);
    str = sprintf('Ex_1_Data_N%2.0f',N);
    load(str)
    
    RunTime_VI(i_N) = Result.rt_VI;
    RunTime_CVI(i_N) = Result.rt_CVI;
    RunTime_CVI_d(i_N) = Result.rt_CVI_d;
    
end

h2 = figure;
N_vec = (N_set.^4);
loglog(N_vec,RunTime_VI,'Color',[.0 .45 .74],'LineStyle','-','Marker','s','LineWidth',1)
hold on
loglog(N_vec,RunTime_CVI,'Color',[0 0.5 0],'LineStyle','-','Marker','d','LineWidth',1)
loglog(N_vec,RunTime_CVI_d,'Color',[.85 .33 .1],'LineStyle','-','Marker','o','LineWidth',1)
hold off
ylabel('Time (sec)','FontSize',10,'Interpreter','latex')
xlabel('Grid size, $X\times U$','FontSize',10,'Interpreter','latex')
txt1 = 'VI';
txt2 = 'CVI';
txt3 = 'CVI-d';
legend({txt1, txt2, txt3},'Interpreter','latex','Orientation','vertical','Location','northwest','FontSize',10)
ax = gca;
ax.Box = 'on';
grid on

% %==========================================================================
% Trajectory cost of VI and CVI for different grid sizes
Cost_VI = zeros(2,length(N_set)); % mean and std
Cost_CVI = zeros(2,length(N_set)); % mean and std
Cost_CVI_d = zeros(2,length(N_set)); % mean and std for CVI with dynamic Y_g

for i_N = 1:length(N_set)
    
    N = N_set(i_N);
    str = sprintf('Ex_1_Data_N%2.0f',N);
    load(str)
    temp_ind = ~isinf(Result.tc_VI) & ~isinf(Result.tc_CVI) & ~isinf(Result.tc_CVI_d);
    Cost_VI(1,i_N) = mean(Result.tc_VI(temp_ind));
    Cost_VI(2,i_N) = std(Result.tc_VI(temp_ind));
    Cost_CVI(1,i_N) = mean(Result.tc_CVI(temp_ind));
    Cost_CVI(2,i_N) = std(Result.tc_CVI(temp_ind));
    Cost_CVI_d(1,i_N) = mean(Result.tc_CVI_d(temp_ind));
    Cost_CVI_d(2,i_N) = std(Result.tc_CVI_d(temp_ind));
    
end

h3 = figure;
semilogx(N_vec,Cost_VI(1,:),'Color',[.0 .45 .74],'LineStyle','-','Marker','s','LineWidth',1)
hold on
semilogx(N_vec,Cost_CVI(1,:),'Color',[0 0.5 0],'LineStyle','-','Marker','d','LineWidth',1)
semilogx(N_vec,Cost_CVI_d(1,:),'Color',[.85 .33 .1],'LineStyle','-','Marker','o','LineWidth',1)
hold off
ylabel('Average cost','FontSize',10,'Interpreter','latex')
xlabel('Grid size, $X\times U$','FontSize',10,'Interpreter','latex')
txt1 = 'VI';
txt2 = 'CVI';
txt3 = 'CVI-d';
legend({txt1, txt2, txt3},'Interpreter','latex','Orientation','vertical','Location','northeast','FontSize',10)
ax = gca;
ax.Box = 'on';
grid on

% %==========================================================================
% Convergence rate of VI and CVI for largest grid size (deterministic systems)
i_N = length(N_set);
N = N_set(i_N);
str = sprintf('Ex_1_Data_N%2.0f',N);
load(str)

Convergence_VI_det = Result.conv_VI_dd(2:end);
Convergence_CVI_det = Result.conv_CVI_dd(2:end); % 
Convergence_CVI_det_d1 = Result.conv_CVI_d1_dd(2:end); % CVI with dynamic Y_g and alpha = 1

h4 = figure;
semilogy(1:length(Convergence_VI_det),Convergence_VI_det,'Color',[.0 .45 .74],'LineStyle','-','Marker','none','LineWidth',1.5)
hold on
semilogy(1:length(Convergence_CVI_det),Convergence_CVI_det,'Color',[0 0.5 0],'LineStyle','-.','Marker','none','LineWidth',1.5)
semilogy(1:length(Convergence_CVI_det_d1),Convergence_CVI_det_d1,'Color',[.85 .33 .1],'LineStyle','--','Marker','none','LineWidth',1.5)
hold off
ylabel('$\Vert J - J_+ \Vert_{\infty}$','FontSize',10,'Interpreter','latex')
xlabel('Iteration, $k$','FontSize',10,'Interpreter','latex')
txt1 = 'VI';
txt2 = 'CVI';
txt3 = 'CVI-d';
legend({txt1, txt2, txt3},'Interpreter','latex','Orientation','vertical','Location','northeast','FontSize',10)
ax = gca;
ax.Box = 'on';
grid on

% %==========================================================================
% Performance using analytical conjugate of input cost

i_N = length(N_set);
N = N_set(i_N);
str = sprintf('Ex_1_Data_N%2.0f',N);
load(str)

Convergence_CVI_a = Result.conv_CVI_a(2:end); 
RunTime_CVI_a = zeros(1,length(N_set));
Cost_CVI_new = zeros(2,length(N_set));
Cost_CVI_a = zeros(2,length(N_set)); 

for i_N = 1:length(N_set)
    
    N = N_set(i_N);
    str = sprintf('Ex_1_Data_N%2.0f',N);
    load(str)
    
    RunTime_CVI_a(i_N) = Result.rt_CVI_a;
    
    temp_ind = ~isinf(Result.tc_CVI) & ~isinf(Result.tc_CVI_a);
    Cost_CVI_new(1,i_N) = mean(Result.tc_CVI(temp_ind));
    Cost_CVI_new(2,i_N) = std(Result.tc_CVI(temp_ind));
    Cost_CVI_a(1,i_N) = mean(Result.tc_CVI_a(temp_ind));
    Cost_CVI_a(2,i_N) = std(Result.tc_CVI_a(temp_ind));
    
end

h5 = figure;
subplot(1,3,1)
semilogy(1:length(Convergence_CVI),Convergence_CVI,'Color',[0 0.5 0],'LineStyle','-.','Marker','none','LineWidth',1.5)
hold on
semilogy(1:length(Convergence_CVI_a),Convergence_CVI_a,'Color',[.85 .33 .1],'LineStyle','--','Marker','none','LineWidth',1.5)
hold off
ylabel('$\Vert J - J_+ \Vert_{\infty}$','FontSize',10,'Interpreter','latex')
xlabel('Iteration, $k$','FontSize',10,'Interpreter','latex')
txt2 = 'CVI';
txt3 = 'CVI-a';
legend({txt2, txt3},'Interpreter','latex','Orientation','vertical','Location','northeast','FontSize',10)
ax = gca;
ax.Box = 'on';
grid on
subplot(1,3,2)
loglog(N_vec,RunTime_CVI,'Color',[0 0.5 0],'LineStyle','-','Marker','d','LineWidth',1)
hold on
loglog(N_vec,RunTime_CVI_a,'Color',[.85 .33 .1],'LineStyle','-','Marker','o','LineWidth',1)
hold off
ylabel('Time (sec)','FontSize',10,'Interpreter','latex')
xlabel('Grid size, $X\times U$','FontSize',10,'Interpreter','latex')
txt2 = 'CVI';
txt3 = 'CVI-a';
legend({txt2, txt3},'Interpreter','latex','Orientation','vertical','Location','northwest','FontSize',10)
ax = gca;
ax.Box = 'on';
grid on
subplot(1,3,3)
semilogx(N_vec,Cost_CVI_new(1,:),'Color',[0 0.5 0],'LineStyle','-','Marker','d','LineWidth',1)
hold on
semilogx(N_vec,Cost_CVI_a(1,:),'Color',[.85 .33 .1],'LineStyle','-','Marker','o','LineWidth',1)
hold off
ylabel('Average cost','FontSize',10,'Interpreter','latex')
xlabel('Grid size, $X\times U$','FontSize',10,'Interpreter','latex')
txt2 = 'CVI';
txt3 = 'CVI-a';
legend({txt2, txt3},'Interpreter','latex','Orientation','vertical','Location','northeast','FontSize',10)
ax = gca;
ax.Box = 'on';
grid on

% Saving the results of analysis
str = sprintf('Ex_1_Analysis');
save(str,'Convergence_VI','Convergence_CVI','Convergence_CVI_d',...
    'RunTime_VI','RunTime_CVI','RunTime_CVI','RunTime_CVI_d',...
    'Cost_VI','Cost_CVI','Cost_CVI_d',...
    'Convergence_VI_det','Convergence_CVI_det','Convergence_CVI_det_d1',...
    'Convergence_CVI_a', 'RunTime_CVI_a', 'Cost_CVI_a')
