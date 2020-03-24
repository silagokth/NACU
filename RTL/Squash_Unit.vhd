-------------------------------------------------------
--! @file Squash_Unit.vhd
--! @brief Unit to implement Squash functions (Sigmoid and Tanh)
--! @details 
--! @author Guido Baccelli
--! @version 1.1
--! @date 19/01/2019
--! @bug NONE
--! @todo NONE
--! @copyright  GNU Public License [GPL-3.0].
-------------------------------------------------------
---------------- Copyright (c) notice -----------------------------------------
--
-- The VHDL code, the logic and concepts described in this file constitute
-- the intellectual property of the authors listed below, who are affiliated
-- to KTH(Kungliga Tekniska Högskolan), School of ICT, Kista.
-- Any unauthorised use, copy or distribution is strictly prohibited.
-- Any authorised use, copy or distribution should carry this copyright notice
-- unaltered.
-------------------------------------------------------------------------------
-- Title      : Squash unit
-- Project    : SiLago
-------------------------------------------------------------------------------
-- File       : Squash_Unit.vhd
-- Author     : Guido Baccelli
-- Company    : KTH
-- Created    : 19/01/2019
-- Last update: 2020-03-15
-- Platform   : SiLago
-- Standard   : VHDL'08
-- Supervisor : Dimitrios Stathis
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Contact    : Guido Baccelli <stathis@kth.se>
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                  Description
-- 2020-03-15  1.0      Guido Baccelli          Created
-- 2020-03-15  1.1      Dimitrios Stathis       Minor Changes and fixes 
-------------------------------------------------------------------------------

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
--                                                                         #
--This file is part of SiLago.                                             #
--                                                                         #
--    SiLago platform source code is distributed freely: you can           #
--    redistribute it and/or modify it under the terms of the GNU          #
--    General Public License as published by the Free Software Foundation, #
--    either version 3 of the License, or (at your option) any             #
--    later version.                                                       #
--                                                                         #
--    SiLago is distributed in the hope that it will be useful,            #
--    but WITHOUT ANY WARRANTY; without even the implied warranty of       #
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        #
--    GNU General Public License for more details.                         #
--                                                                         #
--    You should have received a copy of the GNU General Public License    #
--    along with SiLago.  If not, see <https://www.gnu.org/licenses/>.     #
--                                                                         #
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

--! Standard ieee library
LIBRARY ieee;
--! Default working library
LIBRARY work;
--! Standard logic package
USE ieee.std_logic_1164.ALL;
--! Standard numeric package for signed and unsigned
USE ieee.numeric_std.ALL;
--! Package for CGRA Types and Constants
--USE work.top_consts_types_package.ALL;
--! Utilities package
--USE work.util_package.ALL;
--! Package for misc functions
--USE work.functions.ALL;

--! This module provides slope and offset for PWL implementation of Sigmoid and Tanh

--! This module contains the LUT for slope and offset, for all Q formats from Q15.0 to Q4.11.
--! for formats Q3.12 to Q0.15, the same LUT for Q4.11 is reused. Since the input Q format is a generic,
--! only LUTs for the input Q format are actually instantiated. The control signal 'squash_mode' chooses
--! between Sigmoid, Tanh and Sigmoid for Exponential.
ENTITY Squash_Unit IS
    GENERIC (
        Nb        : INTEGER; --! Number of bits
        frac_part : INTEGER  --! Number of fractional bits
    );
    PORT (
        data_in         : IN signed(Nb - 1 DOWNTO 0);      --! Input data
        data_in_2scompl : IN signed(Nb - 1 DOWNTO 0);      --! 2's complement of input data
        squash_mode     : IN std_logic_vector(1 DOWNTO 0); --! Selects Sigmoid, Tanh or Sigmoid for Exponential
        slope           : OUT signed(Nb - 1 DOWNTO 0);     --! Value of slope 
        offset          : OUT signed(Nb - 1 DOWNTO 0)      --! Value of offset
    );
END ENTITY;

--! @brief This module provides slope and offset for PWL implementation of Sigmoid and Tanh
--! @details Dedicated LUTs are present for formats Q15.0 to Q4.11. For formats Q3.12 to Q0.15, same LUT
--! of Q4.11 is reused. The LUTs only contain slope and offset for the case of Sigmoid with positive inputs.
--! By exploiting the Sigmoid and Tanh symmetry, it is possible to derive all other slopes and offsets 
--! (for Sigmoid negative inputs and for the whole Tanh curve). This is done by the 'offset_gen' components.
ARCHITECTURE struct OF Squash_Unit IS

    -- CONSTANTS
    --! LUT inputs are spaced by 2^(num_in_lut), so the relevant part of the input goes from the MSB to the 'num_in_lut+1' bit.
    --! Practical example on format Q4.11: LUT inputs are spaced by 2^(num_in_lut)=2^9=512 values, so the relevant bits of the input go from 15 to 'num_in_lut+1'=10.
    TYPE const_array IS ARRAY(11 DOWNTO 0) OF INTEGER;
    TYPE slope_offs_array IS ARRAY(11 DOWNTO 0) OF signed(Nb - 1 DOWNTO 0);
    TYPE mux_in_array IS ARRAY(15 DOWNTO 0) OF signed(Nb - 1 DOWNTO 0);
    TYPE lut_array IS ARRAY(INTEGER RANGE <>) OF signed(Nb - 1 DOWNTO 0);

    --! LUT inputs are spaced by 2^(num_in_lut), so the relevant part of the input goes from the MSB to the 'num_in_lut+1' bit.
    --! Practical example on format Q4.11: LUT inputs are spaced by 2^(num_in_lut)=2^9=512 values, so the relevant bits of the input go from 15 to 'num_in_lut+1'=10.
    --! This constant contains 'num_in_lut' values for all Q formats 
    CONSTANT num_in_lut_array            : const_array := (9, 8, 8, 7, 7, 7, 6, 3, 1, 1, 1, 10); -- Values come from linear interp. algorithm
    CONSTANT max_fb_lut                  : NATURAL     := 11;
    -- SIGNALS
    SIGNAL squash_mode_int               : INTEGER;                                        --! Squash Unit operation mode

    --signal q_format_cfg		: std_logic_vector(log2c(Nb)-1 downto 0);
    SIGNAL data_in_abs, data_in_abs_newq : signed(Nb - 1 DOWNTO 0);                        --! LUT input for sigmoid case
    SIGNAL data_2sat                     : signed(Nb - 1 DOWNTO 0);                        --! LUT input for tanh case
    SIGNAL lut_in                        : signed(Nb - 1 DOWNTO 0);                        --! Extended LUT input

    SIGNAL x_fp0                         : signed(Nb - 1 - num_in_lut_array(0) DOWNTO 0);  --! LUT input sub-portion for format Q15.0
    SIGNAL x_fp1                         : signed(Nb - 1 - num_in_lut_array(1) DOWNTO 0);  --! LUT input sub-portion for format Q14.1
    SIGNAL x_fp2                         : signed(Nb - 1 - num_in_lut_array(2) DOWNTO 0);  --! LUT input sub-portion for format Q13.2
    SIGNAL x_fp3                         : signed(Nb - 1 - num_in_lut_array(3) DOWNTO 0);  --! LUT input sub-portion for format Q12.3
    SIGNAL x_fp4                         : signed(Nb - 1 - num_in_lut_array(4) DOWNTO 0);  --! LUT input sub-portion for format Q11.4
    SIGNAL x_fp5                         : signed(Nb - 1 - num_in_lut_array(5) DOWNTO 0);  --! LUT input sub-portion for format Q10.5
    SIGNAL x_fp6                         : signed(Nb - 1 - num_in_lut_array(6) DOWNTO 0);  --! LUT input sub-portion for format Q9.6
    SIGNAL x_fp7                         : signed(Nb - 1 - num_in_lut_array(7) DOWNTO 0);  --! LUT input sub-portion for format Q8.7
    SIGNAL x_fp8                         : signed(Nb - 1 - num_in_lut_array(8) DOWNTO 0);  --! LUT input sub-portion for format Q7.8
    SIGNAL x_fp9                         : signed(Nb - 1 - num_in_lut_array(9) DOWNTO 0);  --! LUT input sub-portion for format Q6.9
    SIGNAL x_fp10                        : signed(Nb - 1 - num_in_lut_array(10) DOWNTO 0); --! LUT input sub-portion for format Q5.10
    SIGNAL x_fp11                        : signed(Nb - 1 - num_in_lut_array(11) DOWNTO 0); --! LUT input sub-portion for format Q4.11

    SIGNAL slope_tmp                     : signed(Nb - 1 DOWNTO 0);                        --! LUT slope output
    SIGNAL offset_tmp                    : signed(Nb - 1 DOWNTO 0);                        --! LUT offset output 
    SIGNAL slope_sigm_tanh               : signed(Nb - 1 DOWNTO 0);                        --! Updated Slope output for tanh case
    SIGNAL offset_sigm_tanh              : signed(Nb - 1 DOWNTO 0);                        --! Updated Offset output for tanh case
    SIGNAL slope_q12_to_q15              : signed(Nb - 1 DOWNTO 0);                        --! Slope for formats Q12.3 to Q15.0
    SIGNAL offset_q12_to_q15             : signed(Nb - 1 DOWNTO 0);                        --! Offset for formats Q12.3 to Q15.0

    SIGNAL offset_sel                    : std_logic_vector(1 DOWNTO 0);                   --! Select correct offset
    SIGNAL d_in_sign                     : std_logic;                                      --! Input data sign
    SIGNAL tanh_mode                     : std_logic;                                      --! Control bit for tanh mode
    SIGNAL exp_mode                      : std_logic;                                      --! Control bit for exponential mode

BEGIN

    squash_mode_int <= to_integer(unsigned(squash_mode)); --! Change to integer value to use inside processes

    -- ############################

    --! Get dpu_mode control signals 
    op_mode_proc : PROCESS (squash_mode_int)
    BEGIN
        tanh_mode <= '0';
        exp_mode  <= '0';
        IF squash_mode_int = 2 THEN -- TANHYP = 2
            tanh_mode <= '1';
        ELSIF squash_mode_int = 3 THEN -- EXPON = 3
            exp_mode <= '1';
        END IF;
    END PROCESS;

    --! Sign bit of original input
    --! d_in_sign = 1 when data is 0 and exp_mode is 1 fixes a bug when getting the
    --! slope and offset for sigmoid(-x)
    d_in_sign <= '1' WHEN (data_in = 0 AND exp_mode = '1') ELSE
        data_in(Nb - 1);
    offset_sel <= (exp_mode XOR d_in_sign) & tanh_mode; --! Selection of offset depends on the input sign but also on the desired function

    -- #####################################

    --! Take the absolute value of the input, symmetry of SIGMOID/TANHYP is used to derive functions for negative inputs
    abs_data_in_proc : PROCESS (d_in_sign, data_in, data_in_2scompl)
    BEGIN
        IF d_in_sign = '1' THEN
            data_in_abs <= data_in_2scompl;
        ELSE
            data_in_abs <= data_in;
        END IF;
    END PROCESS;
    --! Changes format from (Q0.15, Q1.14, ..., Q3.12) to Q4.11 because they all use same LUT as Q4.11
    format_n_to_one_1 : IF frac_part > max_fb_lut GENERATE
        lut_input_gen : ENTITY work.Q_format_n_to_one
            GENERIC MAP(
                Nb        => data_in_abs'length,
                frac_part => frac_part,
                out_fp    => 11
            )
            PORT MAP(
                d_in  => data_in_abs,
                d_out => data_in_abs_newq
            );
    END GENERATE;
    format_n_to_one_0 : IF frac_part <= max_fb_lut GENERATE
        data_in_abs_newq                 <= data_in_abs;
    END GENERATE;

    --! Multiplication by 2 followed by Saturation, for formats Q15.0 to Q4.11
    data_2sat <= data_in_abs_newq(Nb - 1) & shift_left(data_in_abs_newq(Nb - 2 DOWNTO 0), 1) WHEN data_in_abs_newq(Nb - 2) = '0' ELSE
        to_signed(2 ** (Nb - 1) - 1, data_in_abs_newq'length);
    --! If the op is TANHYP, we need the saturated 2*data_in as the LUT input to get Sigmoid(2*data_in)
    lut_in <= data_2sat WHEN tanh_mode = '1' ELSE
        data_in_abs_newq;

    -- Extracts the relevant subportion of the LUT input. Q formats have different LUTs with different number of relevant bits

    x_fp0 <= lut_in(Nb - 1 DOWNTO num_in_lut_array(0)) WHEN frac_part = 0 ELSE
        to_signed(0, x_fp0'length);
    x_fp1 <= lut_in(Nb - 1 DOWNTO num_in_lut_array(1)) WHEN frac_part = 1 ELSE
        to_signed(0, x_fp1'length);
    x_fp2 <= lut_in(Nb - 1 DOWNTO num_in_lut_array(2)) WHEN frac_part = 2 ELSE
        to_signed(0, x_fp2'length);
    x_fp3 <= lut_in(Nb - 1 DOWNTO num_in_lut_array(3)) WHEN frac_part = 3 ELSE
        to_signed(0, x_fp3'length);
    x_fp4 <= lut_in(Nb - 1 DOWNTO num_in_lut_array(4)) WHEN frac_part = 4 ELSE
        to_signed(0, x_fp4'length);
    x_fp5 <= lut_in(Nb - 1 DOWNTO num_in_lut_array(5)) WHEN frac_part = 5 ELSE
        to_signed(0, x_fp5'length);
    x_fp6 <= lut_in(Nb - 1 DOWNTO num_in_lut_array(6)) WHEN frac_part = 6 ELSE
        to_signed(0, x_fp6'length);
    x_fp7 <= lut_in(Nb - 1 DOWNTO num_in_lut_array(7)) WHEN frac_part = 7 ELSE
        to_signed(0, x_fp7'length);
    x_fp8 <= lut_in(Nb - 1 DOWNTO num_in_lut_array(8)) WHEN frac_part = 8 ELSE
        to_signed(0, x_fp8'length);
    x_fp9 <= lut_in(Nb - 1 DOWNTO num_in_lut_array(9)) WHEN frac_part = 9 ELSE
        to_signed(0, x_fp9'length);
    x_fp10 <= lut_in(Nb - 1 DOWNTO num_in_lut_array(10)) WHEN frac_part = 10 ELSE
        to_signed(0, x_fp10'length);
    --! Formats from Q0.15 to Q3.12 all use same LUT as Q4.11
    x_fp11 <= lut_in(Nb - 1 DOWNTO num_in_lut_array(11)) WHEN frac_part > 10 ELSE
        to_signed(0, x_fp11'length);

    -- #########################################################

    -- ##### LUT Q0 (INTEGER) #####
    --! LUT Q15.0 (integer numbers)
    case_fp0 : IF frac_part = 0 GENERATE
        slope_tmp  <= "0000000000000000";
        offset_tmp <= "0000000000000001";
    END GENERATE;
    -- ##### LUT Q14.1 #####
    --! LUT Q14.1
    case_fp1 : IF frac_part = 1 GENERATE
        slope_tmp  <= "0000000000000000";
        offset_tmp <= "0000000000000001" WHEN x_fp1 = "000000000000000" ELSE
            "0000000000000010";
    END GENERATE;
    -- ##### LUT Q13.2 #####
    --! LUT Q13.2
    case_fp2 : IF frac_part = 2 GENERATE
        slope_tmp  <= "0000000000000000";
        offset_tmp <= "0000000000000010" WHEN x_fp2 = "000000000000000" ELSE
            "0000000000000011" WHEN x_fp2 = "000000000000001" ELSE
            "0000000000000011" WHEN x_fp2 = "000000000000010" ELSE
            "0000000000000011" WHEN x_fp2 = "000000000000011" ELSE
            "0000000000000100";
    END GENERATE;
    -- ##### LUT Q12.3 #####
    --! LUT Q12.3
    case_fp3 : IF frac_part = 3 GENERATE
        slope_tmp  <= "0000000000000000";
        offset_tmp <= "0000000000000100" WHEN x_fp3 = "000000000000000" ELSE
            "0000000000000101" WHEN x_fp3 = "000000000000001" ELSE
            "0000000000000101" WHEN x_fp3 = "000000000000010" ELSE
            "0000000000000110" WHEN x_fp3 = "000000000000011" ELSE
            "0000000000000110" WHEN x_fp3 = "000000000000100" ELSE
            "0000000000000110" WHEN x_fp3 = "000000000000101" ELSE
            "0000000000000111" WHEN x_fp3 = "000000000000110" ELSE
            "0000000000000111" WHEN x_fp3 = "000000000000111" ELSE
            "0000000000000111" WHEN x_fp3 = "000000000001000" ELSE
            "0000000000000111" WHEN x_fp3 = "000000000001001" ELSE
            "0000000000000111" WHEN x_fp3 = "000000000001010" ELSE
            "0000000000001000";
    END GENERATE;

    -- ##### LUT Q11.4 #####
    --! LUT Q11.4	
    case_fp4 : IF frac_part = 4 GENERATE
        slope_tmp <= "0000000000000100" WHEN x_fp4 = "0000000000000" ELSE
            "0000000000000100" WHEN x_fp4 = "0000000000001" ELSE
            "0000000000000000";
        offset_tmp <= "0000000000001000" WHEN x_fp4 = "0000000000000" ELSE
            "0000000000001000" WHEN x_fp4 = "0000000000001" ELSE
            "0000000000001100" WHEN x_fp4 = "0000000000010" ELSE
            "0000000000001110" WHEN x_fp4 = "0000000000011" ELSE
            "0000000000001110" WHEN x_fp4 = "0000000000100" ELSE
            "0000000000001111" WHEN x_fp4 = "0000000000101" ELSE
            "0000000000001111" WHEN x_fp4 = "0000000000110" ELSE
            "0000000000010000";
    END GENERATE;
    -- ##### LUT Q10.5 #####
    --! LUT Q10.5
    case_fp5 : IF frac_part = 5 GENERATE
        slope_tmp <= "0000000000000110" WHEN x_fp5 = "0000000000" ELSE
            "0000000000000010" WHEN x_fp5 = "0000000001" ELSE
            "0000000000000000";
        offset_tmp <= "0000000000010001" WHEN x_fp5 = "0000000000" ELSE
            "0000000000011000" WHEN x_fp5 = "0000000001" ELSE
            "0000000000100000";
    END GENERATE;
    -- ##### LUT Q9.6 #####
    --! LUT Q9.6
    case_fp6 : IF frac_part = 6 GENERATE
        slope_tmp <= "0000000000001100" WHEN x_fp6 = "000000000" ELSE
            "0000000000000011" WHEN x_fp6 = "000000001" ELSE
            "0000000000000000";
        offset_tmp <= "0000000000100010" WHEN x_fp6 = "000000000" ELSE
            "0000000000110100" WHEN x_fp6 = "000000001" ELSE
            "0000000001000000";
    END GENERATE;
    -- ##### LUT Q8.7 #####
    --! LUT Q8.7
    case_fp7 : IF frac_part = 7 GENERATE
        slope_tmp <= "0000000000011101" WHEN x_fp7 = "000000000" ELSE
            "0000000000010100" WHEN x_fp7 = "000000001" ELSE
            "0000000000001010" WHEN x_fp7 = "000000010" ELSE
            "0000000000000100" WHEN x_fp7 = "000000011" ELSE
            "0000000000000000";
        offset_tmp <= "0000000001000001" WHEN x_fp7 = "000000000" ELSE
            "0000000001001010" WHEN x_fp7 = "000000001" ELSE
            "0000000001011101" WHEN x_fp7 = "000000010" ELSE
            "0000000001101110" WHEN x_fp7 = "000000011" ELSE
            "0000000001111111" WHEN x_fp7 = "000000100" ELSE
            "0000000001111111" WHEN x_fp7 = "000000101" ELSE
            "0000000010000000";
    END GENERATE;
    -- ##### LUT Q7.8 #####
    --! LUT Q7.8
    case_fp8 : IF frac_part = 8 GENERATE
        slope_tmp <= "0000000001000000" WHEN x_fp8 = "000000000" ELSE
            "0000000000111001" WHEN x_fp8 = "000000001" ELSE
            "0000000000101011" WHEN x_fp8 = "000000010" ELSE
            "0000000000100000" WHEN x_fp8 = "000000011" ELSE
            "0000000000010110" WHEN x_fp8 = "000000100" ELSE
            "0000000000001110" WHEN x_fp8 = "000000101" ELSE
            "0000000000001001" WHEN x_fp8 = "000000110" ELSE
            "0000000000000111" WHEN x_fp8 = "000000111" ELSE
            "0000000000000101" WHEN x_fp8 = "000001000" ELSE
            "0000000000000000" WHEN x_fp8 = "000001001" ELSE
            "0000000000000000" WHEN x_fp8 = "000001010" ELSE
            "0000000000000000" WHEN x_fp8 = "000001011" ELSE
            "0000000000000001" WHEN x_fp8 = "000001100" ELSE
            "0000000000000000";
        offset_tmp <= "0000000010000000" WHEN x_fp8 = "000000000" ELSE
            "0000000010000011" WHEN x_fp8 = "000000001" ELSE
            "0000000010010001" WHEN x_fp8 = "000000010" ELSE
            "0000000010100010" WHEN x_fp8 = "000000011" ELSE
            "0000000010110110" WHEN x_fp8 = "000000100" ELSE
            "0000000011001010" WHEN x_fp8 = "000000101" ELSE
            "0000000011011001" WHEN x_fp8 = "000000110" ELSE
            "0000000011100000" WHEN x_fp8 = "000000111" ELSE
            "0000000011100111" WHEN x_fp8 = "000001000" ELSE
            "0000000011111110" WHEN x_fp8 = "000001001" ELSE
            "0000000011111111" WHEN x_fp8 = "000001010" ELSE
            "0000000011111111" WHEN x_fp8 = "000001011" ELSE
            "0000000011111001" WHEN x_fp8 = "000001100" ELSE
            "0000000100000000";
    END GENERATE;
    -- ##### LUT Q6.9 #####
    --! LUT Q6.9
    case_fp9 : IF frac_part = 9 GENERATE
        slope_tmp <= "0000000001111110" WHEN x_fp9 = "00000000" ELSE
            "0000000001101111" WHEN x_fp9 = "00000001" ELSE
            "0000000001011010" WHEN x_fp9 = "00000010" ELSE
            "0000000001000001" WHEN x_fp9 = "00000011" ELSE
            "0000000000101100" WHEN x_fp9 = "00000100" ELSE
            "0000000000011100" WHEN x_fp9 = "00000101" ELSE
            "0000000000010011" WHEN x_fp9 = "00000110" ELSE
            "0000000000001100" WHEN x_fp9 = "00000111" ELSE
            "0000000000000111" WHEN x_fp9 = "00001000" ELSE
            "0000000000000101" WHEN x_fp9 = "00001001" ELSE
            "0000000000000000";
        offset_tmp <= "0000000100000000" WHEN x_fp9 = "00000000" ELSE
            "0000000100001000" WHEN x_fp9 = "00000001" ELSE
            "0000000100011101" WHEN x_fp9 = "00000010" ELSE
            "0000000101000010" WHEN x_fp9 = "00000011" ELSE
            "0000000101101100" WHEN x_fp9 = "00000100" ELSE
            "0000000110010100" WHEN x_fp9 = "00000101" ELSE
            "0000000110101111" WHEN x_fp9 = "00000110" ELSE
            "0000000111000111" WHEN x_fp9 = "00000111" ELSE
            "0000000111011011" WHEN x_fp9 = "00001000" ELSE
            "0000000111100100" WHEN x_fp9 = "00001001" ELSE
            "0000000111111101" WHEN x_fp9 = "00001010" ELSE
            "0000000111111110" WHEN x_fp9 = "00001011" ELSE
            "0000000111111111" WHEN x_fp9 = "00001100" ELSE
            "0000000111111111" WHEN x_fp9 = "00001101" ELSE
            "0000001000000000";
    END GENERATE;
    -- ##### LUT Q5.10 #####
    --! LUT Q5.10
    case_fp10 : IF frac_part = 10 GENERATE
        slope_tmp <= "0000000100000000" WHEN x_fp10 = "00000000" ELSE
            "0000000011110111" WHEN x_fp10 = "00000001" ELSE
            "0000000011101000" WHEN x_fp10 = "00000010" ELSE
            "0000000011010100" WHEN x_fp10 = "00000011" ELSE
            "0000000010111110" WHEN x_fp10 = "00000100" ELSE
            "0000000010100011" WHEN x_fp10 = "00000101" ELSE
            "0000000010001101" WHEN x_fp10 = "00000110" ELSE
            "0000000001110100" WHEN x_fp10 = "00000111" ELSE
            "0000000001100100" WHEN x_fp10 = "00001000" ELSE
            "0000000001001111" WHEN x_fp10 = "00001001" ELSE
            "0000000001000001" WHEN x_fp10 = "00001010" ELSE
            "0000000000110110" WHEN x_fp10 = "00001011" ELSE
            "0000000000100111" WHEN x_fp10 = "00001100" ELSE
            "0000000000100000" WHEN x_fp10 = "00001101" ELSE
            "0000000000011010" WHEN x_fp10 = "00001110" ELSE
            "0000000000010110" WHEN x_fp10 = "00001111" ELSE
            "0000000000001110" WHEN x_fp10 = "00010000" ELSE
            "0000000000001110" WHEN x_fp10 = "00010001" ELSE
            "0000000000001011" WHEN x_fp10 = "00010010" ELSE
            "0000000000000110" WHEN x_fp10 = "00010011" ELSE
            "0000000000000000";
        offset_tmp <= "0000001000000000" WHEN x_fp10 = "00000000" ELSE
            "0000001000000010" WHEN x_fp10 = "00000001" ELSE
            "0000001000001010" WHEN x_fp10 = "00000010" ELSE
            "0000001000011001" WHEN x_fp10 = "00000011" ELSE
            "0000001000101111" WHEN x_fp10 = "00000100" ELSE
            "0000001001010001" WHEN x_fp10 = "00000101" ELSE
            "0000001001110010" WHEN x_fp10 = "00000110" ELSE
            "0000001010011110" WHEN x_fp10 = "00000111" ELSE
            "0000001010111110" WHEN x_fp10 = "00001000" ELSE
            "0000001011101101" WHEN x_fp10 = "00001001" ELSE
            "0000001100010000" WHEN x_fp10 = "00001010" ELSE
            "0000001100101110" WHEN x_fp10 = "00001011" ELSE
            "0000001101011011" WHEN x_fp10 = "00001100" ELSE
            "0000001101110010" WHEN x_fp10 = "00001101" ELSE
            "0000001110000111" WHEN x_fp10 = "00001110" ELSE
            "0000001110010110" WHEN x_fp10 = "00001111" ELSE
            "0000001110110110" WHEN x_fp10 = "00010000" ELSE
            "0000001110110110" WHEN x_fp10 = "00010001" ELSE
            "0000001111000011" WHEN x_fp10 = "00010010" ELSE
            "0000001111011011" WHEN x_fp10 = "00010011" ELSE
            "0000001111111010" WHEN x_fp10 = "00010100" ELSE
            "0000001111111011" WHEN x_fp10 = "00010101" ELSE
            "0000001111111100" WHEN x_fp10 = "00010110" ELSE
            "0000001111111101" WHEN x_fp10 = "00010111" ELSE
            "0000001111111110" WHEN x_fp10 = "00011000" ELSE
            "0000001111111110" WHEN x_fp10 = "00011001" ELSE
            "0000001111111111" WHEN x_fp10 = "00011010" ELSE
            "0000001111111111" WHEN x_fp10 = "00011011" ELSE
            "0000001111111111" WHEN x_fp10 = "00011100" ELSE
            "0000001111111111" WHEN x_fp10 = "00011101" ELSE
            "0000001111111111" WHEN x_fp10 = "00011110" ELSE
            "0000010000000000";
    END GENERATE;
    -- ##### LUT Q4.11 #####
    --! LUT Q4.11. Reused for formats Q3.12 to Q0.15
    case_fp11_to_15 : IF frac_part >= 11 GENERATE
        slope_q411 : slope_tmp <= "0000001000000000" WHEN x_fp11 = "0000000" ELSE
        "0000000111101111" WHEN x_fp11 = "0000001" ELSE
        "0000000111010001" WHEN x_fp11 = "0000010" ELSE
        "0000000110101000" WHEN x_fp11 = "0000011" ELSE
        "0000000101111101" WHEN x_fp11 = "0000100" ELSE
        "0000000101001001" WHEN x_fp11 = "0000101" ELSE
        "0000000100011001" WHEN x_fp11 = "0000110" ELSE
        "0000000011101110" WHEN x_fp11 = "0000111" ELSE
        "0000000011000001" WHEN x_fp11 = "0001000" ELSE
        "0000000010100001" WHEN x_fp11 = "0001001" ELSE
        "0000000001111111" WHEN x_fp11 = "0001010" ELSE
        "0000000001100110" WHEN x_fp11 = "0001011" ELSE
        "0000000001010100" WHEN x_fp11 = "0001100" ELSE
        "0000000001000000" WHEN x_fp11 = "0001101" ELSE
        "0000000000110110" WHEN x_fp11 = "0001110" ELSE
        "0000000000100111" WHEN x_fp11 = "0001111" ELSE
        "0000000000100010" WHEN x_fp11 = "0010000" ELSE
        "0000000000011001" WHEN x_fp11 = "0010001" ELSE
        "0000000000010101" WHEN x_fp11 = "0010010" ELSE
        "0000000000001101" WHEN x_fp11 = "0010011" ELSE
        "0000000000001110" WHEN x_fp11 = "0010100" ELSE
        "0000000000001100" WHEN x_fp11 = "0010101" ELSE
        "0000000000001001" WHEN x_fp11 = "0010110" ELSE
        "0000000000000000";
        offset_q411 : offset_tmp <= "0000010000000000" WHEN x_fp11 = "0000000" ELSE
        "0000010000000100" WHEN x_fp11 = "0000001" ELSE
        "0000010000010011" WHEN x_fp11 = "0000010" ELSE
        "0000010000110010" WHEN x_fp11 = "0000011" ELSE
        "0000010001011101" WHEN x_fp11 = "0000100" ELSE
        "0000010010011110" WHEN x_fp11 = "0000101" ELSE
        "0000010011100110" WHEN x_fp11 = "0000110" ELSE
        "0000010100110001" WHEN x_fp11 = "0000111" ELSE
        "0000010110001011" WHEN x_fp11 = "0001000" ELSE
        "0000010111010011" WHEN x_fp11 = "0001001" ELSE
        "0000011000101000" WHEN x_fp11 = "0001010" ELSE
        "0000011001101101" WHEN x_fp11 = "0001011" ELSE
        "0000011010100011" WHEN x_fp11 = "0001100" ELSE
        "0000011011100100" WHEN x_fp11 = "0001101" ELSE
        "0000011100000111" WHEN x_fp11 = "0001110" ELSE
        "0000011100111111" WHEN x_fp11 = "0001111" ELSE
        "0000011101010011" WHEN x_fp11 = "0010000" ELSE
        "0000011101111001" WHEN x_fp11 = "0010001" ELSE
        "0000011110001011" WHEN x_fp11 = "0010010" ELSE
        "0000011110110001" WHEN x_fp11 = "0010011" ELSE
        "0000011110101100" WHEN x_fp11 = "0010100" ELSE
        "0000011110110110" WHEN x_fp11 = "0010101" ELSE
        "0000011111000110" WHEN x_fp11 = "0010110" ELSE
        "0000011111111010" WHEN x_fp11 = "0010111" ELSE
        "0000011111111100" WHEN x_fp11 = "0011000" ELSE
        "0000011111111101" WHEN x_fp11 = "0011001" ELSE
        "0000011111111101" WHEN x_fp11 = "0011010" ELSE
        "0000011111111110" WHEN x_fp11 = "0011011" ELSE
        "0000011111111110" WHEN x_fp11 = "0011100" ELSE
        "0000011111111111" WHEN x_fp11 = "0011101" ELSE
        "0000011111111111" WHEN x_fp11 = "0011110" ELSE
        "0000011111111111" WHEN x_fp11 = "0011111" ELSE
        "0000011111111111" WHEN x_fp11 = "0100000" ELSE
        "0000100000000000";
    END GENERATE;

    --! If TANHYP is needed, then slope=4*slope_tmp, otherwise the normal slope is kept
    slope_sigm_tanh <= signed(slope_tmp(Nb - 1) & shift_left(signed(slope_tmp(Nb - 2 DOWNTO 0)), 2)) WHEN tanh_mode = '1' ELSE
        signed(slope_tmp);

    --! Offset generator for formats Q15.0 to Q4.11
    offset_case_fp0_to_11 : IF frac_part <= max_fb_lut GENERATE
        offset_gen_i : ENTITY work.offset_gen
            GENERIC MAP(
                Nb            => Nb,
                frac_part_lut => frac_part
            )
            PORT MAP(
                offset_sel => offset_sel,
                offset_in  => offset_tmp,
                offset_out => offset_sigm_tanh
            );
    END GENERATE;
    --! Offset generator for formats Q3.12 to Q0.15
    offset_case_fp12_to_15 : IF frac_part > max_fb_lut GENERATE
        offset_gen_i : ENTITY work.offset_gen
            GENERIC MAP(
                Nb            => Nb,
                frac_part_lut => max_fb_lut
            )
            PORT MAP(
                offset_sel => offset_sel,
                offset_in  => offset_tmp,
                offset_out => offset_sigm_tanh
            );
    END GENERATE;

    --! In case of formats Q3.12 to Q0.15, the slope and offset Q format must be changed from Q4.11
    final_outs_case_fp12_to_15 : IF frac_part > max_fb_lut GENERATE
        final_slope_gen : ENTITY work.Q_format_one_to_n
            GENERIC MAP(
                Nb        => Nb,
                frac_part => frac_part,
                in_fp     => max_fb_lut
            )
            PORT MAP(
                d_in  => slope_sigm_tanh,
                d_out => slope_q12_to_q15
            );
        final_offset_gen : ENTITY work.Q_format_one_to_n
            GENERIC MAP(
                Nb        => Nb,
                frac_part => frac_part,
                in_fp     => max_fb_lut
            )
            PORT MAP(
                d_in  => offset_sigm_tanh,
                d_out => offset_q12_to_q15
            );
    END GENERATE;

    --! Selects correct output signals depending on 'frac_part'
    slope_mux_in_gen1 : IF frac_part <= 11 GENERATE
        slope                            <= slope_sigm_tanh;
        offset                           <= offset_sigm_tanh;
    END GENERATE;

    --! Selects correct output signals depending on 'frac_part'
    slope_mux_in_gen2 : IF frac_part > 11 GENERATE
        slope  <= slope_q12_to_q15;
        offset <= offset_q12_to_q15;
    END GENERATE;

END ARCHITECTURE;