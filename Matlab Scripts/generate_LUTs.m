%% generate_LUTs: generates files with slope and offset LUTs for VHDL language
%
%   The script loads optimal result workspace from 'find_opt_sigmoid.m' and prints
%   to different files the slope and offset LUTs for each fractional bit in the desired range.
%   The files content is meant for VHDL and can be directly used by copy-pasting it.
%
%   MAIN PARAMETERS
%   fl_start = lower bound of fractional bits 'fl' to explore
%   fl_end = upper bound of fractional bits 'fl' to explore
%   ni_start = 2^(ni_start) is the lower bound of number of intervals 'ni' to explore
%   ni_end = 2^(ni_end) is the upper bound of number of intervals 'ni' to explore
%   ['number of interval' values are only powers of 2 from 2^(ni_start) to 2^(ni_end)]
%


%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
%                                                                         #
%This file is part of SiLago.                                             #
%                                                                         #
%    SiLago platform source code is distributed freely: you can           #
%    redistribute it and/or modify it under the terms of the GNU          #
%    General Public License as published by the Free Software Foundation, #
%    either version 3 of the License, or (at your option) any             #
%    later version.                                                       #
%                                                                         #
%    SiLago is distributed in the hope that it will be useful,            #
%    but WITHOUT ANY WARRANTY; without even the implied warranty of       #
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        #
%    GNU General Public License for more details.                         #
%                                                                         #
%    You should have received a copy of the GNU General Public License    #
%    along with SiLago.  If not, see <https://www.gnu.org/licenses/>.     #
%                                                                         #
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

clear variables
close all
clc

%% Initialization

savepath = './';

% Load results workspace from 'find_opt_sigmoid.m'
% Change loaded '.mat' file for different Sigmoid implem. 
load('sigm_linear_interp_fl.mat');

%% Create LUT for slope and offset

% For all fractional bits in range
for fl=fl_start:fl_end
    
    fl_idx = fl-fl_start+1; % Get proper index for cells and vectors
    
    partition_sfi = sfi(partition_opt{fl_idx}, wl, fl); % For extra safety, discretize partition
    new_coeffs = sfi(new_coeffs_opt{fl_idx}, wl, fl); % For extra safety, discretize coefficients
    
    step = partition_step_opt(fl_idx); % Take partition step
    signif_bit(fl_idx) = wl-log2(step/(2^(-fl))); % Compute number of input significant bits to address LUT
    
    % Create files to write slope and offset LUT
    str = strcat(savepath, sprintf('Sigmoid_li_lut_slope_fp%d.txt', fl));
    fid_slope = fopen(str, 'w');
    str = strcat(savepath, sprintf('Sigmoid_li_lut_offset_fp%d.txt', fl));
    fid_offset = fopen(str, 'w');

    % Write each LUT entry to file
    for j=1:length(partition_sfi)-2
        newLUT_input = bin(partition_sfi(j)); % Convert fixed-point real number to binary
        newLUT_input = newLUT_input(1:signif_bit(fl_idx)); % Extract the significant bits from the binary vector
        newLUT_slope = bin(new_coeffs(j,1)); % Convert fixed-point real slopes to binary
        newLUT_offset = bin(new_coeffs(j,2)); % Convert fixed-point real offsets to binary
        % Print slope VHDL string to file
        str = sprintf('"%s" when x = "%s" else \n', newLUT_slope, newLUT_input);
        fprintf(fid_slope, str);
        % Print offset VHDL string to file
        str = sprintf('"%s" when x = "%s" else \n', newLUT_offset, newLUT_input);
        fprintf(fid_offset, str);
    end
    % Print final slope VHDL string to file
    str = sprintf('"%s";\n', bin(new_coeffs(end,1)));
    fprintf(fid_slope,str);
    % Print final offset VHDL string to file
    str = sprintf('"%s";\n', bin(new_coeffs(end,2)));
    fprintf(fid_offset,str);
    % Close files
    fclose(fid_slope);
    fclose(fid_offset);
end