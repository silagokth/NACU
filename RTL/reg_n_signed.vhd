-------------------------------------------------------
--! @file reg_n_signed.vhd
--! @brief Signed n-bit Register
--! @details 
--! @author Guido Baccelli
--! @version 1.0
--! @date 09/01/2019
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
-- Title      : Signed n-bit Register
-- Project    : SiLago
-------------------------------------------------------------------------------
-- File       : reg_n_signed.vhd
-- Author     : Guido Baccelli
-- Company    : KTH
-- Created    : 09/01/2019
-- Last update: 09/01/2019
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
-- 09/01/2019  1.0      Guido Baccelli          Created
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
--! Standard numeric library for signed
USE IEEE.NUMERIC_STD.ALL;

--! Register for signed data with reset, clear and enable commands
ENTITY reg_n_signed IS
    GENERIC (Nb : INTEGER := 16); --! Number of bits
    PORT (
        clk   : IN std_logic;               --! Clock
        rst_n : IN std_logic;               --! Asynchronous Reset
        clear : IN std_logic;               --! Clear (synchronous reset)
        en    : IN std_logic;               --! Enable
        d_in  : IN signed(Nb - 1 DOWNTO 0); --! Input data
        d_out : OUT signed(Nb - 1 DOWNTO 0) --! Output data
    );
END ENTITY;

--! @brief Behavioral description with sequential process
ARCHITECTURE bhv OF reg_n_signed IS
BEGIN
    reg_proc : PROCESS (rst_n, clk)
    BEGIN
        IF rst_n = '0' THEN
            d_out <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            IF en = '1' THEN
                IF clear = '0' THEN
                    d_out <= d_in;
                ELSE
                    d_out <= (OTHERS => '0');
                END IF;
            END IF;
        END IF;
    END PROCESS;
END ARCHITECTURE;