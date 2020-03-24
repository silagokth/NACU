-------------------------------------------------------
--! @file divider_pipe_tb.vhd
--! @brief This is a pipelined divider to use for simulations.
--! @details In this file no DW or other IPs are used to allow simulation and avoid compatibility issues.
--! The divider can be replaced by a DW or other IP. During synthesis, re-time command must be used
--! to distribute the registers in the pipeline. 
--! @author Guido Baccelli
--! @version 1.1
--! @date 26/01/2019
--! @bug NONE
--! @todo Move types and definitions to a new package
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
-- Title      : Pipeline Divider
-- Project    : SiLago
-------------------------------------------------------------------------------
-- File       : divider_pipe_tb.vhd
-- Author     : Guido Baccelli
-- Company    : KTH
-- Created    : 26/01/2019
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
-- 26/01/2019  1.0      Guido Baccelli          Created
-- 2020-03-15  1.1      Dimitrios Stathis       Minor change and clean up for
--                                              public git publication
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
--! Package with ann_unit types and constants
USE work.ann_pkg.ALL;

--! This module is a pipelined divider for fixed-point numbers

--! This module implements a divider for fixed-point numbers with generic number 
--! of pipeline stages, operands bitwidth and number of fractional bits.
--! Given two operands originally on 'N' bits and with a 'fb' number of fractional bits, the actual inputs 
--! to the divider must be extended to '2*N' bits but retaining the same number of fractional bits. This 
--! means that the final divider inputs have 'Nb=2*N' with same 'frac_part' as the initial inputs. These
--! assumptions lead to quotient and remainder with same frac_part as the inputs. The quotient and remainder
--! at the output of this module have bitwidth 'Nb', so to bring them back to 'N' bits they have to be saturated
--! by an external module.
--! This version uses no DesignWare libraries and components, so it can still be simulated without access to them.
ENTITY divider_pipe IS
    GENERIC (
        Nb        : INTEGER; --! Operands number of bits
        Np        : INTEGER; --! Number of internal pipeline stages
        frac_part : INTEGER  --! Number of fractional bits
    );
    PORT (
        clk       : IN std_logic;                --! Clock
        rst_n     : IN std_logic;                --! Asynchronous reset
        const_one : IN signed(Nb - 1 DOWNTO 0);  --! Constant one represented in same format as inputs
        dividend  : IN signed(Nb - 1 DOWNTO 0);  --! Input dividend
        divisor   : IN signed(Nb - 1 DOWNTO 0);  --! Input divisor
        quotient  : OUT signed(Nb - 1 DOWNTO 0); --! Output quotient
        remainder : OUT signed(Nb - 1 DOWNTO 0)  --! Output remainder
    );
END ENTITY;

--! @brief Structural description for DesignWare divider, behavioral for simulation
--! @details All inputs and outputs of divider of this module have the same fixed-point format.
--! In case the divisor is 0, a protection mechanism changes the dividend to max or min representable
--! number, depending on the dividend sign. The divisor is changed to one so that quotient=dividend and
--! remainder=0. In order to obtain quotient and remainder on same fixed-point format as inputs, 
--! the dividend is left shifted by the number of fractional bits 'frac_part'. In case the divider
--! has to be synthesized, the constant 'syn' must be set to '1' so that the DesignWare pipelined divider is used.
--! If the divider has to be simulated, 'syn' must be set to '0' so that a behavioral model is used. This model 
--! simply uses the '/' and 'rem' operators to get quotient and remainder and feeds them to a delay line that emulates
--! the pipeline stages.
ARCHITECTURE bhv OF divider_pipe IS

    SUBTYPE frac_part_range IS INTEGER RANGE 0 TO (Nb/2) - 1;                      --! The range is based on assumption that Nb is two times the original inputs bitwidth
    TYPE type_array_dividend IS ARRAY(frac_part_range) OF signed(Nb - 1 DOWNTO 0); --! Array of dividend for all fixed-point formats
    TYPE pipeline_type IS ARRAY(0 TO Np) OF signed(Nb - 1 DOWNTO 0);               --! Array of delay line signals

    CONSTANT max_num                     : INTEGER := 2 ** (Nb - 1) - 1;           --! Max number that can be represented on 'Nb' bits and 2's complement format
    CONSTANT min_num                     : INTEGER := - 2 ** (Nb - 1);             --! Min number that can be represented on 'Nb' bits and 2's complement format

    SIGNAL pipe_quotient, pipe_rem       : pipeline_type;                          --! Min number that can be represented on 'Nb' bits and 2's complement format

    SIGNAL dividend_array                : type_array_dividend;                    --! Array of dividers with all fractional bit numbers in 'frac_part_range'
    SIGNAL dividend_tmp, divisor_tmp     : signed(Nb - 1 DOWNTO 0);                --! Temporary operand
    SIGNAL dividend_final, divisor_final : signed(Nb - 1 DOWNTO 0);                --! Final operands
    SIGNAL quotient_tmp, remainder_tmp   : signed(Nb - 1 DOWNTO 0);                --! Temporary quotient and remainder
    SIGNAL divide_by_zero                : std_logic;                              --! Division by zero control signal (unused)

BEGIN
    --! Generation of all dividends for all fixed-point formats
    dividend_gen : FOR i IN frac_part_range GENERATE
        dividend_array(i) <= shift_left(dividend, i);
    END GENERATE;

    dividend_tmp <= dividend_array(frac_part); --! Selects dividend of desired fixed-point format
    divisor_tmp  <= divisor;

    --! Control logic to handle division by zero
    sel_inputs_proc : PROCESS (dividend_tmp, divisor_tmp, const_one)
        VARIABLE dividend_var, divisor_var : signed(Nb - 1 DOWNTO 0);
    BEGIN
        --! If divisor is 0 
        IF divisor_tmp = 0 THEN
            --! If dividend is positive
            IF dividend_tmp > 0 THEN
                dividend_var := to_signed(max_num, dividend_var'length); --! Saturate input to max. representable number
                --! If dividend is negative
            ELSE
                dividend_var := to_signed(min_num, dividend_var'length); --! Saturate input to min. representable number
            END IF;
            --! Force divisor to "1" so that quotient = dividend
            divisor_var := const_one;
        ELSE
            dividend_var := dividend_tmp;
            divisor_var  := divisor_tmp;
        END IF;
        dividend_final <= dividend_var;
        divisor_final  <= divisor_var;
    END PROCESS;

    --! Behavioral model of pipelined divider for simulation

    pipe_quotient(0) <= (dividend_final/divisor_final);     --! Quotient computation
    pipe_rem(0)      <= (dividend_final REM divisor_final); --! Remainder computation

    --! Delay line to simulate pipeline stages
    pipe_gen : FOR i IN 1 TO Np GENERATE
        pipe_qu_i : ENTITY work.reg_n_signed
            GENERIC MAP(Nb => Nb)
            PORT MAP(
                clk   => clk,
                rst_n => rst_n,
                clear => '0',
                en    => '1',
                d_in  => pipe_quotient(i - 1),
                d_out => pipe_quotient(i)
            );

        pipe_rem_i : ENTITY work.reg_n_signed
            GENERIC MAP(Nb => Nb)
            PORT MAP(
                clk   => clk,
                rst_n => rst_n,
                clear => '0',
                en    => '1',
                d_in  => pipe_rem(i - 1),
                d_out => pipe_rem(i)
            );
    END GENERATE;

    quotient  <= pipe_quotient(Np);
    remainder <= pipe_rem(Np);

END ARCHITECTURE;