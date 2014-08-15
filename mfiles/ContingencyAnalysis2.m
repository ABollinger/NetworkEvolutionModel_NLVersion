%% SET SOME VARIABLES

printstuff = false;
%analysistype = 0;

%mpc = loadcase('case9');
%mpc = loadcase('case14');
%mpc = loadcase('case118');
%mpc = loadcase('testcase9');
%mpc = loadcase('validationInputData2');
%addpath('/home/andrewbollinger/AndrewBollinger/projects/NetlogoModels/NetworkEvolution/modelFiles/outputdata/');
%v9outputtest

%mpc.branch(:,14) = 1;

%% CREATE THE ADJACENCY MATRIX

% construct the adjacency matrix from the bus and branch data
adjacencymatrix = zeros(length(mpc.bus(:,1)),length(mpc.bus(:,1)));
for x = 1:size(mpc.branch(:,1))
    adjacencymatrix(mpc.branch(x,1), mpc.branch(x,2)) = 1;
    adjacencymatrix(mpc.branch(x,2), mpc.branch(x,1)) = 1;
end

% add ones to the diagonal of the adjacency matrix
for x = 1:length(adjacencymatrix)
    adjacencymatrix(x,x) = 1;
end

%% RUN THE LOAD FLOW

% parse the data in the branch list
circuits = mpc.branch(:,14);
voltage = mpc.branch(:,15);
contingencytest = mpc.branch(:,16);
mpc.branch = mpc.branch(:,1:13);

% create some vectors/matrices for use later
numrows = length(mpc.branch(:,1));
% contingencyresults = [];
% for u = 1:numrows
%     if contingencytest(u) == 1
%         contingencyresults = vertcat(contingencyresults, mpc.branch(u,1:2));
%     end
% end
contingencyresults = mpc.branch(:,1:2);
numrowscontingency = length(contingencyresults(:,1));
contingencyresults = horzcat(contingencyresults,zeros(numrowscontingency,3));
%contingencyresults = horzcat(mpc.branch(:,1:2),zeros(numrows,3));
n0contingencyresults = contingencyresults;
mpopt = mpoption('PF_DC', 1, 'OUT_ALL', 0, 'VERBOSE', 0);
%mpopt = mpoption('PF_DC', 1);

generatorresults = mpc.gen(:,1:2);
generatorresults(:,2) = 0;

% the network might be composed of multiple isolated components
% to deal with this, we first identify the nodes belonging to the different components
m = adjacencymatrix;

% remove the failed lines from the adjacency matrix
for x = 1:length(mpc.branch(:,1))
    if mpc.branch(x,11) == 0
        bus1 = mpc.branch(x,1);
        bus2 = mpc.branch(x,2);
        m(bus1,bus2) = 0;
        m(bus2,bus1) = 0;
    end
end

[p,q,r,s] = dmperm(m);
components = zeros(length(r) - 1, numrows);
for y = 2:length(r)
    nodevector = p(r(y - 1):r(y) - 1);
    for z = 1:length(nodevector)
        components(y-1, z) = nodevector(z);
    end
end

if printstuff == true
    disp('components = ');
    disp(components);
end

% for each component
for component = 1:length(components(:,1))

    % create a vector of the nodes in the component
    nodesinthiscomponent = nonzeros(components(component,:));

    mpc2.bus = mpc.bus(nodesinthiscomponent,:);
    mpc2.gen = mpc.gen(ismember(mpc.gen(:,1), nodesinthiscomponent),:);
    mpc2.branch = mpc.branch(ismember(mpc.branch(:,1), nodesinthiscomponent),:);
    mpc2.branch = mpc2.branch(ismember(mpc2.branch(:,2), nodesinthiscomponent),:);
    mpc2.branch = mpc2.branch(find(mpc2.branch(:,11) == 1),:);
    
    % create some empty matrices for the power flow analysis
%     mpc2.bus = [];
%     mpc2.gen = [];
%     mpc2.branch = [];
%     
%     % fill the power flow analysis matrices
%     for currentnode = 1:length(nodesinthiscomponent)
%         mpc2.bus = vertcat(mpc2.bus, mpc.bus(nodesinthiscomponent(currentnode),:));
%         mpc2.gen = vertcat(mpc2.gen, mpc.gen(find(mpc.gen(:,1) == nodesinthiscomponent(currentnode)),:)); 
% 
%         for othernode = 1:length(nodesinthiscomponent)
%             mpc2.branch = vertcat(mpc2.branch, mpc.branch(find(mpc.branch(:,1) == nodesinthiscomponent(currentnode) & mpc.branch(:,2) == nodesinthiscomponent(othernode) & mpc.branch(:,11) == 1),:));
%         end
%     end

    % remove duplicate entries in the new branch matrix
    mpc2.branch = unique(mpc2.branch, 'rows');

    if printstuff == true
        disp('bus list = ');
        disp(mpc2.bus);
        disp('gen list = ');
        disp(mpc2.gen);
        disp('branch list = ');
        disp(mpc2.branch);
    end
    
    % reset the demand of the buses in case there is not enough
    % generation capacity
    totalgenerationcapacityinthiscomponent = sum(mpc2.gen(:,9));
    totalloadinthiscomponent = sum(mpc2.bus(:,3));
    if totalgenerationcapacityinthiscomponent < totalloadinthiscomponent
        mpc2.bus(:,3) = mpc2.bus(:,3) * totalgenerationcapacityinthiscomponent / totalloadinthiscomponent;
    end
    
    % initially set the bus types of all buses to 1
    mpc2.bus(:,2) = 1;
    
    % set the bus types of all buses with generators attached to 2
    buseswithgeneratorsattached = [];
    numbersofbuseswithattachedgenerators = mpc2.gen(:,1);
    for j = 1:length(numbersofbuseswithattachedgenerators)
        buseswithgeneratorsattached = vertcat(buseswithgeneratorsattached, find(mpc2.bus(:,1) == numbersofbuseswithattachedgenerators(j)));
    end
    mpc2.bus(buseswithgeneratorsattached,2) = 2;
    
    %identify the isolated buses and set their bus types = 4
    %isolated buses are buses with no attached demand, no attached 
    %generators and only one attached line
    buseswithnodemand = find(mpc2.bus(:,3) == 0); 
    buseswithnogenerators = find(mpc2.bus(:,2) == 1);
    isolatedbuses = intersect(buseswithnodemand, buseswithnogenerators);

    busesofbranches = vertcat(mpc2.branch(:,1), mpc2.branch(:,2));
    [busfrequencies, busnos] = hist(busesofbranches, unique(busesofbranches));
    buseswithonebranch = [];
    numbersofbuseswithonebranch = busnos(find(busfrequencies == 1));
    for k = 1:length(numbersofbuseswithonebranch)
        buseswithonebranch = vertcat(buseswithonebranch, find(mpc2.bus(:,1) == numbersofbuseswithonebranch(k)));
    end
    
%     buseswithonebranch = [];
%     busnumbers = mpc2.bus(:,1);
%     for currentbus = 1:length(busnumbers)
%         countoccurrences = sum(mpc2.branch(:,1) == busnumbers(currentbus));
%         countoccurrences = countoccurrences + sum(mpc2.branch(:,2) == busnumbers(currentbus));
%         if countoccurrences == 1
%            buseswithonebranch = vertcat(buseswithonebranch, mpc2.bus(find(mpc2.bus(:,1) == busnumbers(currentbus)),1));
%         end
%     end
        
    isolatedbuses = intersect(isolatedbuses, buseswithonebranch);
    mpc2.bus(isolatedbuses,2) = 4;

    % if there are generators and branches in this component
    if length(find(mpc2.bus(:,2) == 2)) > 0 && length(mpc2.branch(:,1)) > 0 && length(find(mpc2.bus(:,2) ~= 4)) > 1

        % if there is no slack bus, create one
        if length(find(mpc2.bus(:,2) == 3)) == 0  
            buseswithgenerators = find(mpc2.bus(:,2) == 2);
            mpc2.bus(buseswithgenerators(1),2) = 3;
        end
        
        % fill in the missing matrices for the power flow analysis
        mpc2.version = mpc.version;
        mpc2.baseMVA = mpc.baseMVA;
        %mpc2.areas = mpc.areas;

        % run the power flow analysis and save the results
        results = runpf(mpc2, mpopt);

        branchflows = max(abs(results.branch(:,14)), abs(results.branch(:,16)));
        branchinjectedfromend = results.branch(:,14);
        branchinjectedtoend = results.branch(:,16);
        branchresults = horzcat(mpc2.branch(:,1:2), branchinjectedfromend, branchinjectedtoend, branchflows);
        
        generatorresults = results.gen(:,1:2);

        if printstuff == true
            disp('branch results = ');
            disp(branchresults);
        end
        
%         maxDim = max(max(n0contingencyresults(:,1:2)));
%         n0contingencyresults_am = zeros(maxDim,maxDim);
%         branchresults_am = zeros(maxDim,maxDim);
%         linearindex_n0contingencyresults = sub2ind([maxDim maxDim], n0contingencyresults(:,1), n0contingencyresults(:,2));
%         n0contingencyresults_am(linearindex_n0contingencyresults) = n0contingencyresults(:,3);
%         linearindex_branchresults = sub2ind([maxDim maxDim], branchresults(:,1), branchresults(:,2));
%         branchresults_am(linearindex_branchresults) = branchresults(:,3);
%         new_n0contingencyresults_am = max(n0contingencyresults_am, branchresults_am);
%         new_n0contingencyresults = max(new_n0contingencyresults_am, [],2);
%         n0contingencyresults = horzcat(n0contingencyresults(:,1:4), new_n0contingencyresults);
       
        n0contingencyresults_indices = 1:length(n0contingencyresults(:,1));
        n0contingencyresults_indices = n0contingencyresults_indices';
        n0contingencyresults = horzcat(n0contingencyresults, n0contingencyresults_indices);
        n0contingencyresults_tocompare = n0contingencyresults(ismember(n0contingencyresults(:,1:2), branchresults(:,1:2),'rows'),:);
        n0contingencyresults_toexclude = n0contingencyresults(~ismember(n0contingencyresults(:,1:2), branchresults(:,1:2),'rows'),:);
        n0contingencyresults_tocompare = sortrows(n0contingencyresults_tocompare, [1 2]);
        branchresults = sortrows(branchresults, [1 2]);
        maxvalues = max(branchresults(:,5), n0contingencyresults_tocompare(:,5));
        n0contingencyresults_tocompare(:,5) = maxvalues;
        n0contingencyresults = vertcat(n0contingencyresults_tocompare, n0contingencyresults_toexclude);
        n0contingencyresults = sortrows(n0contingencyresults, 6);
        n0contingencyresults(:,6) = [];

%         % fill the contingency analysis results matrix with the
%         % results of the power flow analysis for this component
%         for y = 1:length(branchresults(:,1))
%             for z = 1:length(n0contingencyresults(:,1))
%                 if branchresults(y,1) == n0contingencyresults(z,1) && branchresults(y,2) == n0contingencyresults(z,2)
%                     if branchresults(y,5) > n0contingencyresults(z,5) 
%                         n0contingencyresults(z,5) = branchresults(y,5);
%                         %n0contingencyresults(z,4) = branchresults(y,4);
%                         %n0contingencyresults(z,3) = branchresults(y,3);
%                     end
%                 end
%             end
%         end
    end
end


%% N-1 CONTINGENCY ANALYSIS

if analysistype == 1 || analysistype == 2
    
    iteration = 0;
    
    n1contingencyresults = n0contingencyresults;

    % iterate through the branches, removing each one in turn
    for x = 1:numrows
        
        % we only want to remove lines with one circuit because lines with
        % more than one circuit will be operational in all contingencies
        if circuits(x) == 1 && contingencytest(x) == 1
            
            if printstuff == true
                disp('removed line = ');
                disp(x);
            end

            % remove the branch by setting the status (column 11) to 0
            mpc.branch(x,11) = 0;

            % edit the adjacency matrix to reflect the removal of this link
            m = adjacencymatrix;
            bus1 = mpc.branch(x,1);
            bus2 = mpc.branch(x,2);
            m(bus1,bus2) = 0;
            m(bus2,bus1) = 0;

            % identify the nodes belonging to the different components
            [p,q,r,s] = dmperm(m);
            components = zeros(length(r) - 1, numrows);
            for y = 2:length(r)
                nodevector = p(r(y - 1):r(y) - 1);
                for z = 1:length(nodevector)
                    components(y-1, z) = nodevector(z);
                end
            end

            if printstuff == true
                disp('components = ');
                disp(components);
            end

            % for each component
            for component = 1:length(components(:,1))

                % create a vector of the nodes in the component
                nodesinthiscomponent = nonzeros(components(component,:));

                mpc2.bus = mpc.bus(nodesinthiscomponent,:);
                mpc2.gen = mpc.gen(ismember(mpc.gen(:,1), nodesinthiscomponent),:);
                mpc2.branch = mpc.branch(ismember(mpc.branch(:,1), nodesinthiscomponent),:);
                mpc2.branch = mpc2.branch(ismember(mpc2.branch(:,2), nodesinthiscomponent),:);
                mpc2.branch = mpc2.branch(find(mpc2.branch(:,11) == 1),:);
                
                % create some empty matrices for the power flow analysis
%                 mpc2.bus = [];
%                 mpc2.gen = [];
%                 mpc2.branch = [];
% 
%                 % fill the power flow analysis matrices
%                 for currentnode = 1:length(nodesinthiscomponent)
%                     mpc2.bus = vertcat(mpc2.bus, mpc.bus(nodesinthiscomponent(currentnode),:));
%                     mpc2.gen = vertcat(mpc2.gen, mpc.gen(find(mpc.gen(:,1) == nodesinthiscomponent(currentnode)),:)); 
% 
%                     for othernode = 1:length(nodesinthiscomponent)
%                         mpc2.branch = vertcat(mpc2.branch, mpc.branch(find(mpc.branch(:,1) == nodesinthiscomponent(currentnode) & mpc.branch(:,2) == nodesinthiscomponent(othernode) & mpc.branch(:,11) == 1),:));
%                     end
%                 end

                % remove duplicate entries in the new branch matrix
                mpc2.branch = unique(mpc2.branch, 'rows');

                if printstuff == true
                    disp('bus list = ');
                    disp(mpc2.bus);
                    disp('gen list = ');
                    disp(mpc2.gen);
                    disp('branch list = ');
                    disp(mpc2.branch);
                end

                % reset the demand of the buses in case there is not enough
                % generation capacity
                totalgenerationcapacityinthiscomponent = sum(mpc2.gen(:,9));
                totalloadinthiscomponent = sum(mpc2.bus(:,3));
                if totalgenerationcapacityinthiscomponent < totalloadinthiscomponent
                    mpc2.bus(:,3) = mpc2.bus(:,3) * totalgenerationcapacityinthiscomponent / totalloadinthiscomponent;
                end

                % initially set the bus types of all buses to 1
                mpc2.bus(:,2) = 1;

                % set the bus types of all buses with generators attached to 2
                buseswithgeneratorsattached = [];
                numbersofbuseswithattachedgenerators = mpc2.gen(:,1);
                for j = 1:length(numbersofbuseswithattachedgenerators)
                    buseswithgeneratorsattached = vertcat(buseswithgeneratorsattached, find(mpc2.bus(:,1) == numbersofbuseswithattachedgenerators(j)));
                end
                mpc2.bus(buseswithgeneratorsattached,2) = 2;

                %identify the isolated buses and set their bus types = 4
                %isolated buses are buses with no attached demand, no attached 
                %generators and only one attached line
                buseswithnodemand = find(mpc2.bus(:,3) == 0); 
                buseswithnogenerators = find(mpc2.bus(:,2) == 1);
                isolatedbuses = intersect(buseswithnodemand, buseswithnogenerators);

                busesofbranches = vertcat(mpc2.branch(:,1), mpc2.branch(:,2));
                [busfrequencies, busnos] = hist(busesofbranches, unique(busesofbranches));
                buseswithonebranch = [];
                numbersofbuseswithonebranch = busnos(find(busfrequencies == 1));
                for k = 1:length(numbersofbuseswithonebranch)
                    buseswithonebranch = vertcat(buseswithonebranch, find(mpc2.bus(:,1) == numbersofbuseswithonebranch(k)));
                end                

%                 buseswithonebranch = [];
%                 busnumbers = mpc2.bus(:,1);
%                 for currentbus = 1:length(busnumbers)
%                     countoccurrences = sum(mpc2.branch(:,1) == busnumbers(currentbus));
%                     countoccurrences = countoccurrences + sum(mpc2.branch(:,2) == busnumbers(currentbus));
%                     if countoccurrences == 1
%                        buseswithonebranch = vertcat(buseswithonebranch, mpc2.bus(find(mpc2.bus(:,1) == busnumbers(currentbus)),1));
%                     end
%                 end
                
                isolatedbuses = intersect(isolatedbuses, buseswithonebranch);
                mpc2.bus(isolatedbuses,2) = 4;

                % if there are generators and branches in this component
                if length(find(mpc2.bus(:,2) == 2)) > 0 && length(mpc2.branch(:,1)) > 0 && length(find(mpc2.bus(:,2) ~= 4)) > 1

                    % if there is no slack bus, create one
                    if length(find(mpc2.bus(:,2) == 3)) == 0  
                        buseswithgenerators = find(mpc2.bus(:,2) == 2);
                        mpc2.bus(buseswithgenerators(1),2) = 3;
                    end

                    % fill in the missing matrices for the power flow analysis
                    mpc2.version = mpc.version;
                    mpc2.baseMVA = mpc.baseMVA;
                    %mpc2.areas = mpc.areas;

                    % run the power flow analysis and save the results
                    results = runpf(mpc2, mpopt);

                    branchflows = max(abs(results.branch(:,14)), abs(results.branch(:,16)));
                    branchinjectedfromend = results.branch(:,14);
                    branchinjectedtoend = results.branch(:,16);
                    branchresults = horzcat(mpc2.branch(:,1:2), branchinjectedfromend, branchinjectedtoend, branchflows);

                    if printstuff == true
                        disp('branch results = ');
                        disp(branchresults);
                    end

                    n1contingencyresults_indices = 1:length(n1contingencyresults(:,1));
                    n1contingencyresults_indices = n1contingencyresults_indices';
                    n1contingencyresults = horzcat(n1contingencyresults, n1contingencyresults_indices);
                    n1contingencyresults_tocompare = n1contingencyresults(ismember(n1contingencyresults(:,1:2), branchresults(:,1:2),'rows'),:);
                    n1contingencyresults_toexclude = n1contingencyresults(~ismember(n1contingencyresults(:,1:2), branchresults(:,1:2),'rows'),:);
                    n1contingencyresults_tocompare = sortrows(n1contingencyresults_tocompare, [1 2]);
                    branchresults = sortrows(branchresults, [1 2]);
                    maxvalues = max(branchresults(:,5), n1contingencyresults_tocompare(:,5));
                    n1contingencyresults_tocompare(:,5) = maxvalues;
                    n1contingencyresults = vertcat(n1contingencyresults_tocompare, n1contingencyresults_toexclude);
                    n1contingencyresults = sortrows(n1contingencyresults, 6);
                    n1contingencyresults(:,6) = [];
                    
                    %fill the contingency analysis results matrix with the
                    %results of the power flow analysis for this component
%                     for y = 1:length(branchresults(:,1))
%                         for z = 1:length(n1contingencyresults(:,1))
%                             if branchresults(y,1) == n1contingencyresults(z,1) & branchresults(y,2) == n1contingencyresults(z,2)
%                                 if branchresults(y,5) > n1contingencyresults(z,5) 
%                                     n1contingencyresults(z,5) = branchresults(y,5);
%                                     %n1contingencyresults(z,4) = branchresults(y,4);
%                                     %n1contingencyresults(z,3) = branchresults(y,3);
%                                 end
%                             end
%                         end
%                     end
                end
            end

            iteration = iteration + 1;
            if printstuff == true
                disp('iteration =');
                disp(iteration);
            end

            if mod(iteration,100) == 0
                disp(iteration)
            end

            % replace the removed branch by setting the status (column 11) back to 1
            mpc.branch(x,11) = 1;
        end
    end
end

%% N-2 CONTINGENCY ANALYSIS

if analysistype == 2

   iteration = 0;
   
   n2contingencyresults = n1contingencyresults;

    % iterate through the branches, removing each one in turn
    for x = 1:numrows
        
        % we only want to remove lines with two or fewer circuits because lines with
        % more than two circuits will be operational in all contingencies
        % we only do an n-2 contingency for EHV lines
        if circuits(x) <= 2 && contingencytest(x) == 1

            % remove the branch by setting the status (column 11) to 0
            mpc.branch(x,11) = 0;

            for w = 1:numrows

                % we only want to remove lines with two or fewer circuits because lines with
                % more than two circuits will be operational in all contingencies
                % we only do an n-2 contingency for EHV lines
                if circuits(w) <= 2 && contingencytest(w) == 1

                    if printstuff == true
                        disp('removed lines = ');
                        disp(x);
                        disp(w);
                    end

                    % remove the branch by setting the status (column 11) to 0
                    mpc.branch(w,11) = 0;

                    % edit the adjacency matrix to reflect the removal of the links
                    m = adjacencymatrix;

                    bus1 = mpc.branch(x,1);
                    bus2 = mpc.branch(x,2);
                    m(bus1,bus2) = 0;
                    m(bus2,bus1) = 0;

                    bus3 = mpc.branch(w,1);
                    bus4 = mpc.branch(w,2);
                    m(bus3,bus4) = 0;
                    m(bus4,bus3) = 0;

                    % identify the nodes belonging to the different components
                    [p,q,r,s] = dmperm(m);
                    components = zeros(length(r) - 1, numrows);
                    for y = 2:length(r)
                        nodevector = p(r(y - 1):r(y) - 1);
                        for z = 1:length(nodevector)
                            components(y-1, z) = nodevector(z);
                        end
                    end

                    if printstuff == true
                        disp('components = ');
                        disp(components);
                    end

                    % for each component
                    for component = 1:length(components(:,1))

                        % create a vector of the nodes in the component
                        nodesinthiscomponent = nonzeros(components(component,:));

                        mpc2.bus = mpc.bus(nodesinthiscomponent,:);
                        mpc2.gen = mpc.gen(ismember(mpc.gen(:,1), nodesinthiscomponent),:);
                        mpc2.branch = mpc.branch(ismember(mpc.branch(:,1), nodesinthiscomponent),:);
                        mpc2.branch = mpc2.branch(ismember(mpc2.branch(:,2), nodesinthiscomponent),:);
                        mpc2.branch = mpc2.branch(find(mpc2.branch(:,11) == 1),:);
                        
                        % create some empty matrices for the power flow analysis
%                         mpc2.bus = [];
%                         mpc2.gen = [];
%                         mpc2.branch = [];
% 
%                         % fill the power flow analysis matrices
%                         for currentnode = 1:length(nodesinthiscomponent)
%                             mpc2.bus = vertcat(mpc2.bus, mpc.bus(nodesinthiscomponent(currentnode),:));
%                             mpc2.gen = vertcat(mpc2.gen, mpc.gen(find(mpc.gen(:,1) == nodesinthiscomponent(currentnode)),:));
% 
%                             for othernode = 1:length(nodesinthiscomponent)
%                                 mpc2.branch = vertcat(mpc2.branch, mpc.branch(find(mpc.branch(:,1) == nodesinthiscomponent(currentnode) & mpc.branch(:,2) == nodesinthiscomponent(othernode) & mpc.branch(:,11) == 1),:));
%                             end
%                         end

                        % remove duplicate entries in the new branch matrix
                        mpc2.branch = unique(mpc2.branch, 'rows');

                        if printstuff == true
                            disp('bus list = ');
                            disp(mpc2.bus);
                            disp('gen list = ');
                            disp(mpc2.gen);
                            disp('branch list = ');
                            disp(mpc2.branch);
                        end

                        % reset the demand of the buses in case there is not enough
                        % generation capacity
                        totalgenerationcapacityinthiscomponent = sum(mpc2.gen(:,9));
                        totalloadinthiscomponent = sum(mpc2.bus(:,3));
                        if totalgenerationcapacityinthiscomponent < totalloadinthiscomponent
                            mpc2.bus(:,3) = mpc2.bus(:,3) * totalgenerationcapacityinthiscomponent / totalloadinthiscomponent;
                        end

                        % initially set the bus types of all buses to 1
                        mpc2.bus(:,2) = 1;

                        % set the bus types of all buses with generators attached to 2
                        buseswithgeneratorsattached = [];
                        numbersofbuseswithattachedgenerators = mpc2.gen(:,1);
                        for j = 1:length(numbersofbuseswithattachedgenerators)
                            buseswithgeneratorsattached = vertcat(buseswithgeneratorsattached, find(mpc2.bus(:,1) == numbersofbuseswithattachedgenerators(j)));
                        end
                        mpc2.bus(buseswithgeneratorsattached,2) = 2;

                        %identify the isolated buses and set their bus types = 4
                        %isolated buses are buses with no attached demand, no attached 
                        %generators and only one attached line
                        buseswithnodemand = find(mpc2.bus(:,3) == 0); 
                        buseswithnogenerators = find(mpc2.bus(:,2) == 1);
                        isolatedbuses = intersect(buseswithnodemand, buseswithnogenerators);

                        busesofbranches = vertcat(mpc2.branch(:,1), mpc2.branch(:,2));
                        [busfrequencies, busnos] = hist(busesofbranches, unique(busesofbranches));
                        buseswithonebranch = [];
                        numbersofbuseswithonebranch = busnos(find(busfrequencies == 1));
                        for k = 1:length(numbersofbuseswithonebranch)
                            buseswithonebranch = vertcat(buseswithonebranch, find(mpc2.bus(:,1) == numbersofbuseswithonebranch(k)));
                        end
                        
%                         buseswithonebranch = [];
%                         busnumbers = mpc2.bus(:,1);
%                         for currentbus = 1:length(busnumbers)
%                             countoccurrences = sum(mpc2.branch(:,1) == busnumbers(currentbus));
%                             countoccurrences = countoccurrences + sum(mpc2.branch(:,2) == busnumbers(currentbus));
%                             if countoccurrences == 1
%                                buseswithonebranch = vertcat(buseswithonebranch, mpc2.bus(find(mpc2.bus(:,1) == busnumbers(currentbus)),1));
%                             end
%                         end
                        
                        isolatedbuses = intersect(isolatedbuses, buseswithonebranch);
                        mpc2.bus(isolatedbuses,2) = 4;

                        % if there are generators and branches in this component
                        if length(find(mpc2.bus(:,2) == 2)) > 0 && length(mpc2.branch(:,1)) > 0 && length(find(mpc2.bus(:,2) ~= 4)) > 1

                            % if there is no slack bus, create one
                            if length(find(mpc2.bus(:,2) == 3)) == 0  
                                buseswithgenerators = find(mpc2.bus(:,2) == 2);
                                mpc2.bus(buseswithgenerators(1),2) = 3;
                            end

                            % fill in the missing matrices for the power flow analysis
                            mpc2.version = mpc.version;
                            mpc2.baseMVA = mpc.baseMVA;
                            %mpc2.areas = mpc.areas;

                            % run the power flow analysis and save the results
                            results = runpf(mpc2, mpopt);

                            branchflows = max(abs(results.branch(:,14)), abs(results.branch(:,16)));
                            branchinjectedfromend = results.branch(:,14);
                            branchinjectedtoend = results.branch(:,16);
                            branchresults = horzcat(mpc2.branch(:,1:2), branchinjectedfromend, branchinjectedtoend, branchflows);

                            if printstuff == true
                                disp('branch results = ');
                                disp(branchresults);
                            end

                            n2contingencyresults_indices = 1:length(n2contingencyresults(:,1));
                            n2contingencyresults_indices = n2contingencyresults_indices';
                            n2contingencyresults = horzcat(n2contingencyresults, n2contingencyresults_indices);
                            n2contingencyresults_tocompare = n2contingencyresults(ismember(n2contingencyresults(:,1:2), branchresults(:,1:2),'rows'),:);
                            n2contingencyresults_toexclude = n2contingencyresults(~ismember(n2contingencyresults(:,1:2), branchresults(:,1:2),'rows'),:);
                            n2contingencyresults_tocompare = sortrows(n2contingencyresults_tocompare, [1 2]);
                            branchresults = sortrows(branchresults, [1 2]);
                            maxvalues = max(branchresults(:,5), n2contingencyresults_tocompare(:,5));
                            n2contingencyresults_tocompare(:,5) = maxvalues;
                            n2contingencyresults = vertcat(n2contingencyresults_tocompare, n2contingencyresults_toexclude);
                            n2contingencyresults = sortrows(n2contingencyresults, 6);
                            n2contingencyresults(:,6) = [];
                            
                            % fill the contingency analysis results matrix with the
                            % results of the power flow analysis for this component
%                             for y = 1:length(branchresults(:,1))
%                                 for z = 1:length(n2contingencyresults(:,1))
%                                     if branchresults(y,1) == n2contingencyresults(z,1) & branchresults(y,2) == n2contingencyresults(z,2)
%                                         if branchresults(y,5) > n2contingencyresults(z,5) 
%                                             n2contingencyresults(z,5) = branchresults(y,5);
%                                             %n2contingencyresults(z,4) = branchresults(y,4);
%                                             %n2contingencyresults(z,3) = branchresults(y,3);
%                                         end
%                                     end
%                                 end
%                             end
                        end
                    end

                    iteration = iteration + 1;
                    if printstuff == true
                        disp('iteration =');
                        disp(iteration);
                    end
                    
                    if mod(iteration,100) == 0
                        disp(iteration)
                    end

                    % replace the removed branch by setting the status (column 11)
                    % back to 1
                    mpc.branch(w,11) = 1;
                end
            end

            % replace the removed branch by setting the status (column 11) back to 1
            mpc.branch(x,11) = 1;
        end
    end
end

%% CALCULATE THE MAXIMUM FLOWS OVER EACH CIRCUIT IN EACH LINE

%TODO: The injection values (columns 3 and 4) of the contingencresults
%matrix are probably incorrect in some cases now because they have the
%wrong sign, since we're getting the absolute value of them.

if analysistype == 0
    for v = 1:numrowscontingency
        contingencyresults(v,5) = n0contingencyresults(v,5) / circuits(v);
        %contingencyresults(v,4) = n0contingencyresults(v,4) / circuits(v);
        %contingencyresults(v,3) = n0contingencyresults(v,3) / circuits(v);
    end
end

if analysistype == 1
    for v = 1:numrowscontingency
        if circuits(v) > 1
            contingencyresults(v,5) = max(n0contingencyresults(v,5) / (circuits(v) - 1), n1contingencyresults(v,5) / (circuits(v)));
            %contingencyresults(v,4) = max(abs(n0contingencyresults(v,4) / (circuits(v) - 1)), abs(n1contingencyresults(v,4) / (circuits(v))));
            %contingencyresults(v,3) = max(abs(n0contingencyresults(v,3) / (circuits(v) - 1)), abs(n1contingencyresults(v,3) / (circuits(v))));
        else 
            contingencyresults(v,5) = n1contingencyresults(v,5) / circuits(v);
            %contingencyresults(v,4) = n1contingencyresults(v,4) / circuits(v);
            %contingencyresults(v,3) = n1contingencyresults(v,3) / circuits(v);
        end 
    end
end

if analysistype == 2
    for v = 1:numrowscontingency
        if circuits(v) > 2
            contingencyresults(v,5) = max(n0contingencyresults(v,5) / (circuits(v) - 2), n1contingencyresults(v,5) / (circuits(v) - 1));
            contingencyresults(v,5) = max(contingencyresults(v,5), n2contingencyresults(v,5) / (circuits(v)));
            %contingencyresults(v,4) = max(abs(n0contingencyresults(v,4) / (circuits(v) - 2)), abs(n1contingencyresults(v,4) / (circuits(v) - 1)));
            %contingencyresults(v,4) = max(abs(contingencyresults(v,4)), abs(n2contingencyresults(v,4) / (circuits(v))));
            %contingencyresults(v,3) = max(abs(n0contingencyresults(v,3) / (circuits(v) - 2)), abs(n1contingencyresults(v,3) / (circuits(v) - 1)));
            %contingencyresults(v,3) = max(abs(contingencyresults(v,3)), abs(n2contingencyresults(v,3) / (circuits(v))));
        elseif circuits(v) == 2
            contingencyresults(v,5) = max(n1contingencyresults(v,5) / (circuits(v) - 1), n2contingencyresults(v,5) / (circuits(v)));
            %contingencyresults(v,4) = max(abs(n1contingencyresults(v,4) / (circuits(v) - 1)), abs(n2contingencyresults(v,4) / (circuits(v))));
            %contingencyresults(v,3) = max(abs(n1contingencyresults(v,3) / (circuits(v) - 1)), abs(n2contingencyresults(v,3) / (circuits(v))));
        else
            contingencyresults(v,5) = n2contingencyresults(v,5) / circuits(v);
            %contingencyresults(v,4) = n2contingencyresults(v,4) / circuits(v);
            %contingencyresults(v,3) = n2contingencyresults(v,3) / circuits(v);
        end
    end
end

%% PLOTTING

%contingencyresults2 = sortrows(contingencyresults,[1 2]);
%plot(contingencyresults2(:,5))

