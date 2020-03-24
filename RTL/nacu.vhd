-------------------------------------------------------
--! @file nacu.vhd
--! @brief NACU: Non-linear Arithmetic Unit for Neural Networks
--! @details 
--! @author Guido Baccelli
--! @version 1.1
--! @date 20/08/2019
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
-- Title      : UnitX
-- Project    : SiLago
-------------------------------------------------------------------------------
-- File       : nacu.vhd
-- Author     : Guido Baccelli
-- Company    : KTH
-- Created    : 20/08/2019
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
-- 20/08/2019  1.0      Guido Baccelli          Created
-- 2020-03-15  1.1      Dimitrios Stathis       Code clean up and minor fixes
--                                              for public git
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

--! This module is the NACU: Non-linear Arithmetic Unit for Neural Networks

--! This module implements the following functions:
--! \verbatim
--! Multiply-Add-Accumulate
--! Sigmoid
--! Hyperbolic Tangent
--! Exponential tail (for use in Softmax)
--! Division (for use in Softmax) 
--! \endverbatim
--! This means the module provides all the required functionality for neuron 
--! activations in common Deep Neural Networks such as CNN and LSTM.
ENTITY NACU IS
    PORT (
        clk    : IN std_logic;                   --! Clock signal
        clear  : IN std_logic;                   --! Synchronous Reset
        rst_n  : IN std_logic;                   --! Asynchronous Reset
        opcode : IN std_logic_vector(opc_range); --! Operation Code
        in0    : IN std_logic_vector(in_range);  --! Input 0
        in1    : IN std_logic_vector(in_range);  --! Input 1
        sm_in  : IN std_logic_vector(div_range); --! Softmax denominator input
        out0   : OUT std_logic_vector(in_range); --! Output 0
        sm_out : OUT std_logic_vector(div_range) --! Softmax result output
    );
END ENTITY;

--! @brief Structural view of NACU
--! @details A common mathematical basis for the calculation of Sigmoid, Tanh, Exponential and Softmax is exploited to maximize
--! the reuse of internal components. A multiplier-adder chain covers the MAC operation. In this case, the output register is used as accumulator.
--! Sigmoid and Tanh are implemented by means of Piece-Wise Linear interpolation. A LUT-based Squash Unit provides slopes and offset
--! for each interpolation interval, both for Sigmoid and Tanh. The LUT only contains slopes and offsets for Sigmoid with positive inputs.
--! Some mathematical optimisations are used to derive slopes and offset for the Sigmoid with negative inputs and for the whole Tanh curve.
--! The same MAC components are reused to build the PWL interpolation. The Exponential tail is derived from the Sigmoid function. The required division
--! can be carried out by reusing the same divider for the Softmax function. 
--! All these implementation choices maximize area savings while still achieving very good accuracy. 
ARCHITECTURE rtl OF NACU IS

    -- #################### SIGNALS ####################

    SIGNAL opcode_int, opcode_reg_int               : INTEGER;                         --! Opcode 
    SIGNAL opcode_reg                               : std_logic_vector(opc_range);     --! 	Registered Opcode 
    SIGNAL squash_pipe_en, mult_pipe_en, io_regs_en : std_logic;                       --! Registers enable
    SIGNAL const_one                                : signed(in_range);                --! Constant "1" for Exponential operation
    SIGNAL const_one_resz                           : signed(div_range);               --! signal 'const_one' resized to divider input
    SIGNAL in0s, in1s, in0s_rin, in1s_rin           : signed(in_range);                --! Signed inputs
    SIGNAL in0_2s                                   : signed(in_range);                --! 2's complement of in0s
    SIGNAL m_in0, m_in1                             : signed(in_range);                --! Multiplier input
    SIGNAL sq_in0                                   : signed(in_range);                --! Squash Unit input
    SIGNAL sq_slope                                 : signed(in_range);                --! Slope from Squash Unit
    SIGNAL sq_offs, sq_offs_reg                     : signed(in_range);                --! Offset from Squash Unit
    SIGNAL sat_in_neur                              : signed(add_out_range);           --! Standard Saturation Unit input
    SIGNAL sat_out_neur                             : signed(in_range);                --! Standard Saturation Unit output
    SIGNAL sat_out_sm                               : signed(div_range);               --! Softmax Saturation Unit output
    SIGNAL sat_out_final                            : signed(div_range);               --! Final Saturation Unit output	
    SIGNAL m_out                                    : signed(add_in_range);            --! Multiplier Output
    SIGNAL m_out_cut                                : signed(mult_out_range);          --! Multiplier output without extra fractional bits
    SIGNAL m_out_reg                                : signed(mult_out_range);          --! Multiplier Pipeline Stage output
    SIGNAL ad_in0, ad_in1                           : signed(add_in_range);            --! Adder input
    SIGNAL sm_in_s_rin, sm_in_s                     : signed(div_range);               --! Signed Softmax denominator signal
    SIGNAL div_in0, div_in1                         : signed(div_range);               --! Divider input
    SIGNAL div_quot, div_rem                        : signed(div_range);               --! Divider output
    SIGNAL exp_result                               : signed(div_range);               --! Exponential result signal
    SIGNAL acc_out                                  : signed(div_range);               --! Output register signal
    SIGNAL add_out                                  : signed(add_out_range);           --! Adder output signal
    SIGNAL sq_mode, exp_offs_sel                    : std_logic_vector(sq_mode_range); --! Squash Unit mode selector

    -- #################### COMPONENTS ####################

    COMPONENT mult IS
        GENERIC (Nb : INTEGER);
        PORT (
            in_a  : IN signed(Nb - 1 DOWNTO 0);
            in_b  : IN signed(Nb - 1 DOWNTO 0);
            d_out : OUT signed(2 * Nb - 1 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT adder_nbits IS
        GENERIC (Nb : INTEGER);
        PORT (
            a      : IN signed(Nb - 1 DOWNTO 0);
            b      : IN signed(Nb - 1 DOWNTO 0);
            output : OUT signed(Nb DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT Squash_Unit IS
        GENERIC (
            Nb        : INTEGER;
            frac_part : INTEGER
        );
        PORT (
            data_in         : IN signed(Nb - 1 DOWNTO 0);
            data_in_2scompl : IN signed(Nb - 1 DOWNTO 0);
            squash_mode     : IN std_logic_vector(1 DOWNTO 0);
            slope           : OUT signed(Nb - 1 DOWNTO 0);
            offset          : OUT signed(Nb - 1 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT offset_gen IS
        GENERIC (
            Nb            : INTEGER;
            frac_part_lut : INTEGER
        );
        PORT (
            offset_sel : IN std_logic_vector(1 DOWNTO 0);
            offset_in  : IN signed(Nb - 1 DOWNTO 0);
            offset_out : OUT signed(Nb - 1 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT twos_compl IS
        GENERIC (Nb : INTEGER := 16);
        PORT (
            d_in  : IN signed(Nb - 1 DOWNTO 0);
            d_out : OUT signed(Nb - 1 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT Saturation_Unit IS
        GENERIC (
            Nb_in  : INTEGER;
            Nb_out : INTEGER
        );
        PORT (
            d_in  : IN signed(Nb_in - 1 DOWNTO 0);
            d_out : OUT signed(Nb_out - 1 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT reg_n_signed IS
        GENERIC (Nb : INTEGER := 16);
        PORT (
            clk   : IN std_logic;
            rst_n : IN std_logic;
            clear : IN std_logic;
            en    : IN std_logic;
            d_in  : IN signed(Nb - 1 DOWNTO 0);
            d_out : OUT signed(Nb - 1 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT reg_n IS
        GENERIC (Nb : INTEGER := 16);
        PORT (
            clk   : IN std_logic;
            rst_n : IN std_logic;
            clear : IN std_logic;
            en    : IN std_logic;
            d_in  : IN std_logic_vector(Nb - 1 DOWNTO 0);
            d_out : OUT std_logic_vector(Nb - 1 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT divider_pipe IS
        GENERIC (
            bits_div  : INTEGER;
            Np        : INTEGER;
            frac_part : INTEGER
        );
        PORT (
            clk       : IN std_logic;
            rst_n     : IN std_logic;
            const_one : IN signed(bits_div - 1 DOWNTO 0);
            dividend  : IN signed(bits_div - 1 DOWNTO 0);
            divisor   : IN signed(bits_div - 1 DOWNTO 0);
            quotient  : OUT signed(bits_div - 1 DOWNTO 0);
            remainder : OUT signed(bits_div - 1 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT divider_pipe_tb IS
        GENERIC (
            bits_div  : INTEGER;
            Np        : INTEGER;
            frac_part : INTEGER
        );
        PORT (
            clk       : IN std_logic;
            rst_n     : IN std_logic;
            const_one : IN signed(bits_div - 1 DOWNTO 0);
            dividend  : IN signed(bits_div - 1 DOWNTO 0);
            divisor   : IN signed(bits_div - 1 DOWNTO 0);
            quotient  : OUT signed(bits_div - 1 DOWNTO 0);
            remainder : OUT signed(bits_div - 1 DOWNTO 0)
        );
    END COMPONENT;

BEGIN
    -- #################### BEGIN ARCHITECTURE ####################

    -- #################### Signed Inputs ####################

    in0s_rin       <= signed(in0);                      --! Converts input 0 to signed
    in1s_rin       <= signed(in1);                      --! Converts input 1 to signed
    sm_in_s_rin    <= signed(sm_in);                    --! Converts Softmax denominator to signed
    opcode_int     <= to_integer(unsigned(opcode));     --! Converts opcode input to integer
    opcode_reg_int <= to_integer(unsigned(opcode_reg)); --! Converts opcode register output to integer
    io_regs_en     <= '0' WHEN opcode_int = IDLE ELSE
        '1'; --! Disables IO registers when NACU is inactive

    --! Input 0 register
    in0_in_reg : reg_n_signed
    GENERIC MAP(Nb => Nb)
    PORT MAP(
        clk   => clk,
        rst_n => rst_n,
        clear => clear,
        en    => '1',
        d_in  => in0s_rin,
        d_out => in0s
    );

    --! Input 1 register
    in1_in_reg : reg_n_signed
    GENERIC MAP(Nb => Nb)
    PORT MAP(
        clk   => clk,
        rst_n => rst_n,
        clear => clear,
        en    => '1',
        d_in  => in1s_rin,
        d_out => in1s
    );

    --! Softmax denominator input register
    sm_in_reg : reg_n_signed
    GENERIC MAP(Nb => Nb_div)
    PORT MAP(
        clk   => clk,
        rst_n => rst_n,
        clear => clear,
        en    => '1',
        d_in  => sm_in_s_rin,
        d_out => sm_in_s
    );

    --! Opcode register
    opc_reg : reg_n
    GENERIC MAP(Nb => Nb_opc)
    PORT MAP(
        clk   => clk,
        rst_n => rst_n,
        clear => clear,
        en    => '1',
        d_in  => opcode,
        d_out => opcode_reg
    );
    -- #################### Squash Unit ####################

    --! input 2s complement
    in0_2scompl : twos_compl
    GENERIC MAP(
        Nb => 16
    )
    PORT MAP(
        d_in  => in0s,
        d_out => in0_2s
    );

    --! Selects type of Nonlinear activator 	
    squashmode : PROCESS (opcode_reg_int)
        VARIABLE sq_mode_var : INTEGER;
    BEGIN
        CASE opcode_reg_int IS
            WHEN SIGM =>
                sq_mode_var := 1; -- Sigmoid
            WHEN TANHYP =>
                sq_mode_var := 2; -- Hyperbolic Tangent
            WHEN OTHERS =>    -- Exponential
                sq_mode_var := 3;
        END CASE;
        sq_mode <= std_logic_vector(to_unsigned(sq_mode_var, sq_mode'length));
    END PROCESS;

    --! Squash Unit
    squashunit : Squash_Unit
    GENERIC MAP(
        Nb        => Nb,
        frac_part => fb
    )
    PORT MAP(
        data_in         => in0s,
        data_in_2scompl => in0_2s,
        squash_mode     => sq_mode,
        slope           => sq_slope,
        offset          => sq_offs
    );

    --! Squash Pipe enable 
    squash_pipe_en_proc : PROCESS (opcode_reg_int)
    BEGIN
        CASE opcode_reg_int IS
            WHEN SIGM | TANHYP | EXPON =>
                squash_pipe_en <= '1';
            WHEN OTHERS =>
                squash_pipe_en <= '0';
        END CASE;
    END PROCESS;

    --! Squash Unit Pipeline Stage
    squash_pipe : reg_n_signed
    GENERIC MAP(Nb => Nb)
    PORT MAP(
        clk   => clk,
        rst_n => rst_n,
        clear => clear,
        en    => squash_pipe_en,
        d_in  => sq_offs,
        d_out => sq_offs_reg
    );

    -- #################### Multiplier ####################

    --! Multiplier Inputs selection
    mult_in_sel : PROCESS (opcode_reg_int, in0s, in1s, in0_2s, sq_slope)
    BEGIN
        m_in0 <= in0s;
        CASE opcode_reg_int IS
            WHEN MAC =>
                m_in1 <= in1s;
            WHEN SM =>
                m_in0 <= to_signed(0, m_in0'length);
                m_in1 <= to_signed(0, m_in1'length);
            WHEN SIGM | TANHYP =>
                m_in1 <= sq_slope;
            WHEN OTHERS => -- EXPON
                m_in0 <= in0_2s;
                m_in1 <= sq_slope;
        END CASE;
    END PROCESS;

    --! Multiplier
    multiplier : mult
    GENERIC MAP(
        Nb => Nb
    )
    PORT MAP(
        in_a  => m_in0,
        in_b  => m_in1,
        d_out => m_out
    );

    --! Multiplier output cut
    m_out_cut    <= m_out(m_out'length - 1 DOWNTO fb);

    -- Multiplier Pipe enable
    mult_pipe_en <= '0' WHEN opcode_reg_int = SM ELSE
        '1';

    -- Multiplier Pipeline stage
    mult_pipe : reg_n_signed
    GENERIC MAP(
        Nb => Nb_m_cut
    )
    PORT MAP(
        clk   => clk,
        rst_n => rst_n,
        clear => clear,
        en    => mult_pipe_en,
        d_in  => m_out_cut,
        d_out => m_out_reg
    );

    -- #################### Adder ####################	

    --! Adder inputs selection
    adder_ins : PROCESS (opcode_reg_int, m_out_reg, acc_out, sq_offs_reg)
    BEGIN
        ad_in0 <= resize(m_out_reg, ad_in0'length);
        CASE opcode_reg_int IS
            WHEN SIGM | TANHYP | EXPON =>
                ad_in1 <= resize(sq_offs_reg, ad_in1'length);
            WHEN MAC =>
                ad_in1 <= resize(acc_out, ad_in1'length);
            WHEN OTHERS => -- SM
                ad_in0 <= to_signed(0, ad_in0'length);
                ad_in1 <= to_signed(0, ad_in1'length);
        END CASE;
    END PROCESS;

    --! Adder
    adder : adder_nbits
    GENERIC MAP(
        Nb => Nb_add
    )
    PORT MAP(
        a      => ad_in0,
        b      => ad_in1,
        output => add_out
    );
    -- #################### Exponential ####################

    --! Constant One generation
    one_gen_cond_1 : IF fb < Nb - 1 GENERATE
        const_one <= to_signed(2 ** (fb), const_one'length);
    END GENERATE;

    --! If fixed-point format has no integer bits, 1 can not be represented, so we saturate to 1-2^(-frac_point)
    one_gen_cond_2 : IF fb = Nb - 1 GENERATE
        const_one <= to_signed(2 ** (Nb - 1) - 1, const_one'length);
    END GENERATE;

    --! Resize constant one to divider bitwidth
    const_one_resz <= resize(const_one, const_one_resz'length);

    --! Divider input selection
    divider_ins : PROCESS (opcode_reg_int, const_one_resz, sq_offs_reg, in0s, sm_in_s, add_out)
    BEGIN
        CASE opcode_reg_int IS
            WHEN EXPON =>
                div_in0 <= const_one_resz;
                div_in1 <= add_out(div_in1'length - 1 DOWNTO 0);
            WHEN SM =>
                div_in0 <= resize(in0s, div_in0'length);
                div_in1 <= sm_in_s;
            WHEN OTHERS => -- MAC, SIGM, TANH
                div_in0 <= to_signed(0, div_in0'length);
                div_in1 <= to_signed(1, div_in1'length);
        END CASE;
    END PROCESS;

    --! DesignWare Divider for synthesis
    syn_gen : IF synth_div = '1' GENERATE
        divider_syn : divider_pipe
        GENERIC MAP(
            bits_div  => Nb_div,
            Np        => div_pipe_num,
            frac_part => fb
        )
        PORT MAP(
            clk       => clk,
            rst_n     => rst_n,
            const_one => const_one_resz,
            dividend  => div_in0,
            divisor   => div_in1,
            quotient  => div_quot,
            remainder => div_rem
        );
    END GENERATE;

    --! Behavioral model of divider for simulation
    tb_gen : IF synth_div = '0' GENERATE
        divider_tb : divider_pipe_tb
        GENERIC MAP(
            bits_div  => Nb_div,
            Np        => div_pipe_num,
            frac_part => fb
        )
        PORT MAP(
            clk       => clk,
            rst_n     => rst_n,
            const_one => const_one_resz,
            dividend  => div_in0,
            divisor   => div_in1,
            quotient  => div_quot,
            remainder => div_rem
        );
    END GENERATE;

    --! Optimised -1 for Exponential computation
    PROCESS (div_quot)
    BEGIN
        --! Fractional part
        exp_result(fb - 1 DOWNTO 0)                      <= (div_quot(fb - 1 DOWNTO 0));
        --! Sign AND integer part except the lowest integer bit
        exp_result(exp_result'length - 1 DOWNTO Nb - ib) <= (OTHERS => '0');
        --! Lowest integer bit
        exp_result(Nb - ib - 1)                          <= div_quot(Nb - ib);
    END PROCESS;

    -- #################### Saturation Units ####################

    --! Saturation Unit input selection
    neur_sat_in : PROCESS (opcode_reg_int, add_out, exp_result)
    BEGIN
        CASE opcode_reg_int IS
            WHEN MAC | SIGM | TANHYP =>
                sat_in_neur <= add_out;
            WHEN EXPON =>
                sat_in_neur <= resize(exp_result, sat_in_neur'length);
            WHEN OTHERS =>
                sat_in_neur <= to_signed(0, sat_in_neur'length);
        END CASE;
    END PROCESS;

    --! Saturation Unit for all modes except Softmax division
    sat_unit_neur : Saturation_Unit
    GENERIC MAP(
        Nb_in  => Nb_add + 1,
        Nb_out => Nb
    )
    PORT MAP(
        d_in  => sat_in_neur,
        d_out => sat_out_neur
    );

    --! Saturation Unit for Softmax division
    sat_unit_sm : Saturation_unit
    GENERIC MAP(
        Nb_in  => Nb_div,
        Nb_out => Nb_div
    )
    PORT MAP(
        d_in  => div_quot,
        d_out => sat_out_sm
    );

    --! Selects correct output
    sat_out_final <= sat_out_sm WHEN opcode_reg_int = SM ELSE
        resize(sat_out_neur, sat_out_final'length);

    -- #################### Outputs ####################

    --! Output register
    output_reg : reg_n_signed
    GENERIC MAP(
        Nb => Nb_div
    )
    PORT MAP(
        clk   => clk,
        rst_n => rst_n,
        clear => clear,
        en    => '1',
        d_in  => sat_out_final,
        d_out => acc_out
    );

    --! Output port assignment
    out0   <= std_logic_vector(acc_out(in_range));
    --! Output port assignment
    sm_out <= std_logic_vector(acc_out);

END rtl;