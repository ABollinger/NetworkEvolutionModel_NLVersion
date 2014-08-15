%% LOAD AND CHECK THE NETWORK DATA

% load the network data
%mpc = loadcase('case9');
mpopt = mpoption('PF_DC', 1, 'OUT_ALL', 0);

% create a vector for saving the results
numrows = length(mpc.branch(:,1));
contingencyresults = zeros(numrows, 1);

% create an adjacency matrix for use in determining connectivity
adjacencymatrix = zeros(length(mpc.bus(:,1)),length(mpc.bus(:,1)));
for x = 1:size(mpc.branch(:,1))
    adjacencymatrix(mpc.branch(x,1), mpc.branch(x,2)) = 1;
    adjacencymatrix(mpc.branch(x,2), mpc.branch(x,1)) = 1;
end

% confirm connectivity of the original network
m = adjacencymatrix;
CheckConnectivity;

% calculate flows for the base scenario (without any links removed)
if connected
    disp('The base network is fully connected.');
    results = runpf(mpc, mpopt);
    branchflows = max(abs(results.branch(:,14)), abs(results.branch(:,16)));
    contingencyresults = max(contingencyresults, branchflows);
else 
    disp('The base network is NOT fully connected.');
end

%% N-1 CONTINGENCY ANALYSIS

if analysistype == 1 

    % add the path for the CheckConnectivity file
    %addpath('/home/andrewbollinger/AndrewBollinger/projects/NetlogoModels/MatpowerConnectTest');

    for x = 1:numrows

        % remove the branch by setting the status (column 11) to 0
        mpc.branch(x,11) = 0;

        % check the connectivity of the new network
        % first, edit the adjacency matrix to reflect the removal of this link
        m = adjacencymatrix;
        bus1 = mpc.branch(x,1);
        bus2 = mpc.branch(x,2);
        m(bus1,bus2) = 0;
        m(bus2,bus1) = 0;
        CheckConnectivity;

        % if the network is fully connected, run the power flow calculations
        if connected
            results = runpf(mpc, mpopt);
            branchflows = max(abs(results.branch(:,14)), abs(results.branch(:,16)));
            contingencyresults = max(contingencyresults, branchflows);
        else
            stringtoprint = ['Network is not fully connected when line ', num2str(x), ' is removed. This scenario is excluded from the contingency analysis'];
            disp(stringtoprint);
        end

        % set the status of the branch back to its original value
        mpc.branch(x,11) = 1;
    end
    
end

%% N-2 CONTINGENCY ANALYSIS

if analysistype == 2

    % add the path for the CheckConnectivity file
    %addpath('/home/andrewbollinger/AndrewBollinger/projects/NetlogoModels/MatpowerConnectTest');

    for x = 1:numrows

        % remove the branch by setting the status (column 11) to 0
        mpc.branch(x,11) = 0;

        %z = 1:numrows;
        %z(x) = []; %no need to remove the one that's already removed
        %for y = z
        for y = 1:numrows;    

            % remove the branch by setting the status (column 11) to 0
            mpc.branch(y,11) = 0;

            %check the connectivity of the new network
            % first, edit the adjacency matrix to reflect the removal of this
            % link
            m = adjacencymatrix;
            bus1 = mpc.branch(x,1);
            bus2 = mpc.branch(x,2);
            m(bus1,bus2) = 0;
            m(bus2,bus1) = 0;
            bus1 = mpc.branch(y,1);
            bus2 = mpc.branch(y,2);
            m(bus1,bus2) = 0;
            m(bus2,bus1) = 0;
            CheckConnectivity;

            % if the network is fully connected, run the power flow
            % calculations
            if connected
                results = runpf(mpc, mpopt);
                branchflows = max(abs(results.branch(:,14)), abs(results.branch(:,16)));
                contingencyresults = max(contingencyresults, branchflows);
            else
                stringtoprint = ['Network is not fully connected when lines ', num2str(x), ' and ', num2str(y), ' are removed. This scenario is excluded from the contingency analysis'];
                disp(stringtoprint);
            end

            % set the status of the branch back to its original value
            mpc.branch(y,11) = 1;

        end

        % set the status of the branch back to its original value
        mpc.branch(x,11) = 1;
    end

end

%% ADD THE BUS NUMBERS TO THE CONTINGENCY ANALYSIS RESULTS

busnumbers = mpc.branch(:,1:2);
contingencyresults = horzcat(busnumbers, contingencyresults);