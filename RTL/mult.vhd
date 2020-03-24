-------------------------------------------------------
--! @file mult.vhd
--! @brief Multiplier
--! @details 
--! @author Guido Baccelli
--! @version 1.1
--! @date 10/01/2019
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
-- Title      : Multiplier
-- Project    : SiLago
-------------------------------------------------------------------------------
-- File       : mult.vhd
-- Author     : Guido Baccelli
-- Company    : KTH
-- Created    : 10/01/2019
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
-- 10/01/2019  1.0      Guido Baccelli          Created
-- 2020-03-15  1.1      Dimitrios Stathis       
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

--! This module is a multiplier with generic 'Nb' bits

--! This module simply performs multiplication between two inputs.
--! Given two inputs on 'Nb' bits, the result is given on double the number of bits
--! for a correct representation. 
ENTITY mult IS
    GENERIC (Nb : INTEGER); --! Number of bits
    PORT (
        in_a  : IN signed(Nb - 1 DOWNTO 0);     --! First input
        in_b  : IN signed(Nb - 1 DOWNTO 0);     --! Second input
        d_out : OUT signed(2 * Nb - 1 DOWNTO 0) --! Result
    );
END ENTITY;

--! @brief Behavioral description with implicit combinatorial process
--! @details The architecture is described with the operator '*', through which
--! logic synthesis tools infer the use of a multiplier
ARCHITECTURE bhv OF mult IS
BEGIN
    d_out <= in_a * in_b;
END ARCHITECTURE;