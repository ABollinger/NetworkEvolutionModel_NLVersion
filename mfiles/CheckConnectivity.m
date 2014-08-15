%% CHECK THE CONNECTIVITY OF THE NETWORK

% based on:
% http://www.mathworks.nl/matlabcentral/newsreader/view_thread/54886

connected = false;
n = zeros(length(mpc.bus(:,1)),length(mpc.bus(:,1)));

while isequal(n,m) == 0 
    n = m;
    m = m | (m * m');
    m = double(m);
end

if length(find(m)) == numel(m)
    connected = true;
end

