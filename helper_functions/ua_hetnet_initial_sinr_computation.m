function [peak_rate, sinr_RB] = ua_hetnet_initial_sinr_computation(rx_power, RB_allocation)

global netconfig;
nb_BSs = netconfig.nb_BSs;
nb_users = netconfig.nb_users;
nb_RBs = netconfig.nb_RBs;
nb_femto_RBs = netconfig.nb_femto_RBs;
nb_macro_femto_BSs = netconfig.nb_macro_femto_BSs;
RB_bandwidth = netconfig.RB_bandwidth;
mmwave_bandwidth = netconfig.mmwave_bandwidth;
noise_density = netconfig.noise_density;

% Define BS transmit power per RB
% Beware that there is no RB in mmwave
% tx_RB_power = [macro_tx_power*ones(1,nb_macro_BSs)./nb_RBs, ...
%             femto_tx_power*ones(1,nb_femto_BSs)./nb_RBs, ...
%             mmwave_tx_power*ones(1,nb_mmwave_BSs)];

% tx_RB_power = [macro_tx_power*ones(1,nb_macro_BSs)./nb_macro_RBs, ...
%             zeros(1,nb_femto_BSs), ...
%             mmwave_tx_power*ones(1,nb_mmwave_BSs)];
% 
% % Femto power is computed starting from a constant power budget  
% for b = nb_macro_BSs+1:nb_macro_femto_BSs
%     if sum(RB_allocation(b,:)) == 0
%         tx_RB_power(b) = 0;
%     else
%         tx_RB_power(b) = femto_tx_power/sum(RB_allocation(b,:));
%     end
% end

% Check for penetration loss
% for u = 1:nb_users
%     for b = 1:nb_macro_femto_BSs
%         rx_RB_power(u,b) = (tx_RB_power(b)*tx_antenna_gain*rx_antenna_gain)/pathloss(u,b);
%     end
%     for b = nb_macro_femto_BSs+1:nb_BSs
%         rx_RB_power(u,b) = (tx_RB_power(b)*mmwave_tx_antenna_gain*mmwave_rx_antenna_gain)/pathloss(u,b);
%     end
% end

% Received power and SINR matrices
%rx_power = zeros(nb_users,nb_BSs);
sinr_RB = zeros(nb_users,nb_macro_femto_BSs,nb_RBs);
peak_rate_RB = zeros(nb_users,nb_BSs,nb_RBs);
peak_rate = zeros(nb_users,nb_BSs);

% SINR peak rate equivalence map is given per Hz
% http://www.etsi.org/deliver/etsi_tr/136900_136999/136942/08.01.00_60/tr_136942v080100p.pdf
%sinr_peak_rate_equivalence = load('./radio_conditions/snr-peak-rate.txt','-ascii');
%sinr_range = sinr_peak_rate_equivalence(:,1);
%peak_rate_range = sinr_peak_rate_equivalence(:,2);

% Transformed to output of Vienna simulator, adding only fictive high SINR 1000
%load('SNR_to_throughput_mod_mapping.mat');
% Testing with MIMO
load('SNR_to_throughput_mod_mimo_88_mapping.mat');

% SINR per RB is expressed only for macro and femto BSs
% Skip this if you want to compute mmwave SINR
for u = 1:nb_users
    for b = 1:nb_macro_femto_BSs
        % Iterate over allocated RB on BS b
        for k = find(RB_allocation(b,:)==1)
            interf = sum(rx_power(u,RB_allocation(:,k)==1))-rx_power(u,b);
            real_sinr = rx_power(u,b)/(noise_density*RB_bandwidth + interf);
            sinr_RB(u,b,k) = 10*log10(real_sinr);
            peak_rate_round = find(sinr_RB(u,b,k)<sinr_range);
            if isempty(peak_rate_round)
                % No need for this condition
                peak_rate_RB(u,b,k) = 0;
                continue;
            end
            peak_rate_RB(u,b,k) = peak_rate_range(peak_rate_round(1))*RB_bandwidth;
        end
        peak_rate(u,b) = sum(peak_rate_RB(u,b,:)); 
    end
end

for u = 1:nb_users
    % Reuse 1 model for mmwave
    for b = nb_macro_femto_BSs+1:nb_BSs
        mmwave_interf = sum(rx_power(u,nb_macro_femto_BSs+1:nb_BSs))-rx_power(u,b);
        tmp_sinr_mmwave = 10*log10(rx_power(u,b)/(noise_density*mmwave_bandwidth + mmwave_interf));
        sinr_RB(u,b,:) = tmp_sinr_mmwave;
        if tmp_sinr_mmwave < -20
            peak_rate(u,b) = 0;
        else
            peak_rate(u,b) = mmwave_bandwidth*log2(1+10^(tmp_sinr_mmwave/10));
        end
    end
end

end

