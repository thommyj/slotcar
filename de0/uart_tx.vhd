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

entity txuart is
   port( 
         clk                      : in  std_logic;
			rst                      : in  std_logic;
			parallell_data_in        : in  std_logic_vector(7 downto 0);
			parallell_data_in_valid  : in  std_logic;
			parallell_data_in_sent   : out std_logic;
			uart_data_out				 : out std_logic;
			busy							 : out std_logic
       );
end entity txuart;

--*****************************************************************************
--*  DEFINE: Architecture                                                     *
--****************************************************************************

architecture syn of txuart is

	type sendstate_type is (TXSTATE_IDLE, TXSTATE_START, TXSTATE_DATA, TXSTATE_STOP);
	signal send_state  : sendstate_type;
	type clkstate_type is (CLKSTATE_IDLE, CLKSTATE_COUNTING);
	signal clk_state  : clkstate_type;
	signal send_data   : std_logic_vector(7 downto 0);
	signal uart_clk_re : std_logic;


	
begin

	process(clk, rst)
		variable uart_clk_cnt : integer := 0;
	begin
		if rst = '1' then
			uart_clk_cnt := 0;
			uart_clk_re  <= '0';
		elsif rising_edge(clk) then
		
			case clk_state is
				when CLKSTATE_IDLE =>
					uart_clk_cnt := 0;
					uart_clk_re  <= '0';
				when CLKSTATE_COUNTING =>
					--TODO: fix average frequency
					if uart_clk_cnt = 2604 then
						uart_clk_re <= '1';
						uart_clk_cnt := 0;
					else
						uart_clk_re <= '0';
						uart_clk_cnt := uart_clk_cnt + 1;
					end if;
			end case;
		end if;
	end process;

	--
	-- when data_in_valid goes high, start sending out data
	--
	process(clk,rst)
		variable send_cnt     : integer   := 0;
	begin
		if rst = '1' then
				send_state <= TXSTATE_IDLE;
				clk_state  <= CLKSTATE_IDLE;
				send_cnt   := 0;
				
				uart_data_out <= '1';
				parallell_data_in_sent <= '0';
				busy <= '0';
		elsif rising_edge(clk) then
			parallell_data_in_sent <= '0';
			
			case send_state is
				when TXSTATE_IDLE =>
					uart_data_out <= '1'; --high during idle
					busy <= '0';
					clk_state <= CLKSTATE_IDLE;

					send_cnt  := 0;
							
					if(parallell_data_in_valid = '1') then
						send_state <= TXSTATE_START;
						clk_state  <= CLKSTATE_COUNTING; --restart UART clock
						busy <= '1';
						send_data <= parallell_data_in;
					end if;
					
				when TXSTATE_START =>
					uart_data_out <= '0'; --start bit low
					
					if uart_clk_re = '1' then
						send_state    <= TXSTATE_DATA;
					end if;
						
				when TXSTATE_DATA =>
					uart_data_out <= send_data(send_cnt);
					
					if uart_clk_re = '1' then
						send_cnt := send_cnt + 1;
						if(send_cnt > 7) then
							send_state <= TXSTATE_STOP;
						end if;
					end if;
						
				when TXSTATE_STOP =>
					uart_data_out <= '1';  --stop bit high
					
					if uart_clk_re = '1' then
						parallell_data_in_sent <= '1'; --transmit done
						send_state <= TXSTATE_IDLE;
						busy <= '0';
					end if;
			end case;
		end if; 
	end process;
	
	
end architecture syn;

-- *** EOF ***
