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


--*****************************************************************************
--*  DEFINE: Entity                                                           *
--*****************************************************************************

entity spi_decoder is
   port( 
         clk               : in  std_logic;
			rst               : in  std_logic;
			spidata_out       : out std_logic_vector(7 downto 0);
			spidata_in        : in  std_logic_vector(7 downto 0);
			spidata_valid_in  : in  std_logic;
			pll_locked        : in  std_logic;
			version           : in  std_logic_vector(7 downto 0)
       );
end entity spi_decoder;

--*****************************************************************************
--*  DEFINE: Architecture                                                     *
--****************************************************************************

architecture syn of spi_decoder is

   --
   -- Define all local signals (like static data) here
   --
	type state_type is (idle_state,write_state,read_state);
	signal state : state_type;
	signal rec_cmd : std_logic_vector(7 downto 0);
   signal status : std_logic_vector(7 downto 0);
	
	--Protocol
	--First byte is the command, MSB sent first
	---bit7 = r/w (w=1b1)
	---bit6 = internal registers (1b1)/slotcar registers (1b0)
	--Second byte is data, MSB sent first. Peer is assumed to wait "long enough" before reading/writing data 
	---If command is a read, Peer should send 0xAA (OK) as second command
	
	--Return values
	---During write of command, 0xAA is returned if everything is ok. If FPGA is in an error state 0xFF is returned 
   --	During second byte, if command was a write, 0xAA is returned if command was ok. Otherwise 0xFF if an error was found
	
	--Internal registers
	---0x00, version register (read only)
	---0x01, status (read only)
	
	--External registers
	---
	
begin
					
process(clk)
begin	
	if rising_edge(clk) then
		if (rst = '1') then
			state <= idle_state;
			spidata_out <= x"AA";
		else
			case state is
			---------IDLE--------------
			when idle_state =>
				--command received?
				if (spidata_valid_in = '1') then
					rec_cmd <= spidata_in;
						 
					--if MSB is set, command is write 	 
					if (spidata_in(7) = '1') then
						state <= write_state;
						spidata_out <= x"AA";
					else --otherwise command is read
						state <= read_state;						
						--internal read if bit 6 is set
						if(spidata_in(6) = '1') then 
							case spidata_in(5 downto 0) is
								when "000000" =>
									spidata_out <= version;
								when "000001" =>
									spidata_out <= status;
								when others =>
									spidata_out <= x"FF";
								end case;
						else --external registers
							spidata_out <= x"FF"; --TODO: add external registers
						end if;
					end if;
				end if;
						 
			----------WRITE--------------	 
			when write_state =>
				--if data write
				if (spidata_valid_in = '1') then
					--TODO send to external
				end if;
						 
			----------READ--------------	 
			when read_state =>
				--when second byte is received, peer has alread read data
				if (spidata_valid_in = '1') then
					state <= idle_state;
					spidata_out <= x"AA";
				end if;
				
			end case;
		end if; --if reset
	end if; --if clk
end process;
	
	status <= "0000000" & pll_locked;
	   
end architecture syn;

-- *** EOF ***
