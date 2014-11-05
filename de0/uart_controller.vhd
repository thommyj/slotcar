--*****************************************************************************
--*  Copyright (c) 2012 by Michael Fischer. All rights reserved.
--*
--*  Redistribution and use in source and binary forms, with or without 
--*  modification, are permitted provided that the following conditions 
--*  are met:
--*  
--*  1. Redistributions of source code must retain the above copyright 
--*     notice, this list of conditions and the following disclaimer.
--*  2. Redistributions in binary form must reproduce the above copyright
--*     notice, this list of conditions and the following disclaimer in the 
--*     documentation and/or other materials provided with the distribution.
--*  3. Neither the name of the author nor the names of its contributors may 
--*     be used to endorse or promote products derived from this software 
--*     without specific prior written permiSS_asyncion.
--*
--*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
--*  "AS IS" AND ANY EXPRESS_async OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
--*  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS_async 
--*  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
--*  THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
--*  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
--*  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS_async 
--*  OF USE, DATA, OR PROFITS; OR BUSINESS_async INTERRUPTION) HOWEVER CAUSED 
--*  AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
--*  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
--*  THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSS_asyncIBILITY OF 
--*  SUCH DAMAGE.
--*
--*****************************************************************************
--*  History:
--*
--*  14.07.2011  mifi  First Version
--*****************************************************************************


--*****************************************************************************
--*  DEFINE: Library                                                          *
--*****************************************************************************
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_arith.all;


--*****************************************************************************
--*  DEFINE: Entity                                                           *
--*****************************************************************************

entity uart_controller is
   port( 
         clk                      : in   std_logic;
			rst                      : in   std_logic;
			rts_screen               : out  std_logic;
			datarec_screen           : in   std_logic;
			rts_track                : out  std_logic;
			datarec_track            : in   std_logic
			);
end entity uart_controller;

--*****************************************************************************
--*  DEFINE: Architecture                                                     *
--****************************************************************************

architecture syn of uart_controller is

	type uartstate_type is (IDLE, STORE_FROM_SCREEN, STORE_FROM_TRACK, SEND_TO_SCREEN, SEND_TO_TRACK);
	signal uartstate : uartstate_type;
	
begin

	
	--
	-- sample uart data
	--
	process(clk,rst)
	begin
		if rst = '1' then
			uartstate <= IDLE;
			rts_screen <= '0';
			rts_track <= '0';
		elsif rising_edge(clk) then
		   rts_screen <= '0';
			rts_track <= '0';
		   case uartstate is
				when IDLE =>
					if datarec_screen = '1' then
						uartstate <= STORE_FROM_SCREEN;
					elsif datarec_track = '1' then
					   uartstate <= STORE_FROM_TRACK;
					end if;
				when STORE_FROM_SCREEN =>
				   uartstate <= SEND_TO_TRACK;
				when STORE_FROM_TRACK =>
				   uartstate <= SEND_TO_SCREEN;
				when SEND_TO_TRACK =>
				   rts_track <= '1';
				   uartstate <= IDLE;
				when SEND_TO_SCREEN =>
				   rts_screen <= '1';
				   uartstate <= IDLE;
			end case;
		end if; 
	end process;
	
	
end architecture syn;

-- *** EOF ***
