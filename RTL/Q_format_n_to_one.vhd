-------------------------------------------------------
--! @file Q_format_n_to_one.vhd
--! @brief Combinatorial Unit that changes Q format. Selectable format in input, fixed in output 
--! @details 
--! @author Guido Baccelli
--! @version 1.1
--! @date 05/02/2019
--! @bug NONE
--! @todo Move constants to a package
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
-- Title      : Q format from n to one
-- Project    : SiLago
-------------------------------------------------------------------------------
-- File       : Q_format_n_to_one.vhd
-- Author     : Guido Baccelli
-- Company    : KTH
-- Created    : 05/02/2019
-- Last update: 2020-03-15
-- Platform   : SiLago
-- Standard   : VHDL'08
-- Supervisor : Dimitrios Stathis
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Contact    : Dimitrios Stathis <stathis@kth.se>
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                  Description
-- 05/02/2019  1.0      Guido Baccelli          Created
-- 2020-03-15  1.1      Dimitrios Stathis       Minor Changes
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
--! Standard logic package
USE ieee.std_logic_1164.ALL;
--! Standard numeric package for signed and unsigned
USE ieee.numeric_std.ALL;
--! Package for math with real numbers
USE IEEE.math_real.ALL;
--! Package with ann_unit types and constants
USE work.ann_pkg.ALL;

--! This module converts input data from a Q format to another. Selectable format in input, fixed in output

--! In this current version, the number of fractional bits 'frac_part' is just a generic and static.
--! The unit can be modified to to be configured to in run-time. To enable this modification, move the
--! 'frac_part' in the input ports.
ENTITY Q_format_n_to_one IS
    GENERIC (
        Nb        : INTEGER;      --! Bitwidth
        frac_part : INTEGER;      --! Size of input fractional part 
        out_fp    : INTEGER := 11 --! Size of output fractional part
    );
    PORT (
        d_in  : IN signed(Nb - 1 DOWNTO 0); --! Input data
        d_out : OUT signed(Nb - 1 DOWNTO 0) --! Output data
    );
END ENTITY;

--! @brief Structural definition of Q_format_n_to_one
--! @details Starting from the Input data, the output representation is derived for all possible Q formats. 
--! integer parts and fractional parts of the output are derived separately.
--! Two multiplexers select the integer and fractional parts of the wanted output Q format.
--! At last, the integer and fractional strings are merged to form the output data. 
--! NOTE: In this current version, the num. of fractional bits 'frac_part' is just a generic, but the unit is already configured to
--! function if 'frac_part' is turned into a run-time dynamic input
ARCHITECTURE struct OF Q_format_n_to_one IS
    CONSTANT out_ip      : INTEGER := Nb - out_fp;                                                        --! Number of output integer bits + sign bit
    CONSTANT max_num_out : INTEGER := 2 ** (out_ip - 1) - 1;                                              --! Biggest positive number on out_ip bits
    CONSTANT min_num_out : INTEGER := - 2 ** (out_ip - 1);                                                --! Smallest negative number on out_ip bits

    SUBTYPE frac_part_range IS INTEGER RANGE 0 TO Nb - 1;                                                 --! Numbers of fractional bits for all fixed-point formats
    TYPE array_int_part_satin IS ARRAY(frac_part_range) OF signed(Nb - 1 DOWNTO 0);                       --! Integer parts for all fixed-point formats
    TYPE array_frac_part IS ARRAY(frac_part_range) OF signed(out_fp - 1 DOWNTO 0);                        --! Fractional parts for all fixed-point formats

    SIGNAL frac_part_cuts                                                  : array_frac_part;             --! Fractional parts for all fixed-point formats
    SIGNAL int_part_cuts                                                   : array_int_part_satin;        --! Integer parts for all fixed-point formats
    SIGNAL int_sat_flag                                                    : std_logic;                   --! Integer part saturation flag
    SIGNAL int_part_sat_in                                                 : signed(Nb - 1 DOWNTO 0);     --! Integer part representation that matches with the output Q format

    SIGNAL out_int_part                                                    : signed(out_ip - 1 DOWNTO 0); --! Output integer part
    SIGNAL out_fractional_part, out_fractional_part_tmp, out_frac_part_sat : signed(out_fp - 1 DOWNTO 0); --! Output fractional part

BEGIN

    --########## Integer Part ##########

    --! Value of the integer part of the input, represented on each possible Q format
    int_part_gen : FOR i IN frac_part_range GENERATE
        int_part_cuts(i) <= resize(d_in(d_in'length - 1 DOWNTO i), int_part_cuts(i)'length);
    END GENERATE;

    int_part_sat_in <= int_part_cuts(frac_part); --! Choose the right integer part representation that matches with the output Q format

    --! Saturate the input if it cannot be represented on the output Q format
    --! NOTE: if saturation occurs, the fractional part of the output is also affected
    int_part_sat : PROCESS (int_part_sat_in)
    BEGIN
        IF int_part_sat_in > max_num_out THEN
            out_int_part      <= to_signed(max_num_out, out_int_part'length);
            out_frac_part_sat <= (OTHERS => '1');
            int_sat_flag      <= '1';
        ELSIF int_part_sat_in < min_num_out THEN
            out_int_part      <= to_signed(min_num_out, out_int_part'length);
            out_frac_part_sat <= (OTHERS => '0');
            int_sat_flag      <= '1';
        ELSE
            out_int_part      <= int_part_sat_in(out_int_part'length - 1 DOWNTO 0);
            out_frac_part_sat <= (OTHERS => '0');
            int_sat_flag      <= '0';
        END IF;
    END PROCESS;

    --! Fractional Part
    frac_part_exists : IF out_fp > 0 GENERATE
        frac_part_gen : FOR i IN frac_part_range GENERATE
            --! If input value is integer, set fractional part to "0"
            frac_eq_0 : IF i = 0 GENERATE
                frac_part_cuts(i) <= (OTHERS => '0');
            END GENERATE;
            --! If fractional part of input is smaller than the output one, take all
            --! decimal bits of input and zero pad the remaining ones
            input_frac_lt_out_frac : IF (i > 0) AND (i < out_fp) GENERATE
                frac_part_cuts(i)(out_fp - 1 DOWNTO out_fp - i) <= d_in(i - 1 DOWNTO 0);
                frac_part_cuts(i)(out_fp - i - 1 DOWNTO 0)      <= (OTHERS => '0');
            END GENERATE;
            --! If fractional part of input is greater than the output one, take the first
            --! out_fp decimal bits from the input and assign them to output
            input_frac_gteq_out_frac : IF i > out_fp - 1 GENERATE
                frac_part_cuts(i) <= d_in(i - 1 DOWNTO i - out_fp);
            END GENERATE;
        END GENERATE;
    END GENERATE;

    out_fractional_part_tmp <= frac_part_cuts(frac_part); --! Choose the right fractional part representation that matches with the output Q format

    --! Fix the fractional part if the integer part undergoes saturation
    sel_frac_part_sat : PROCESS (int_sat_flag, out_fractional_part_tmp, out_frac_part_sat)
    BEGIN
        IF int_sat_flag = '1' THEN
            out_fractional_part <= out_frac_part_sat;
        ELSE
            out_fractional_part <= out_fractional_part_tmp;
        END IF;
    END PROCESS;

    --! Final output in case of pure integer format
    final_frac_part_0 : IF out_fp = 0 GENERATE
        d_out <= out_int_part;
    END GENERATE;

    --! Final output in case of fixed-point format
    final_frac_part_1 : IF out_fp > 0 GENERATE
        d_out <= out_int_part & out_fractional_part;
    END GENERATE;

END ARCHITECTURE;