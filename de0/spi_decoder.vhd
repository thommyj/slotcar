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
			
			leds					: out std_logic_vector(7 downto 0);
			pll_locked        : in  std_logic;
			version           : in  std_logic_vector(7 downto 0);
			
			extreg_dataout		: out std_logic_vector(7 downto 0);
			extreg_addressout	: out std_logic_vector(7 downto 0);
			extreg_enable		: out std_logic;
			
			extreg_datain		: in std_logic_vector(7 downto 0);
			extreg_addressin	: out std_logic_vector(7 downto 0)
       );
end entity spi_decoder;

--*****************************************************************************
--*  DEFINE: Architecture                                                     *
--****************************************************************************

architecture syn of spi_decoder is

   --
   -- Define all local signals (like static data) here
   --
	type state_type is (SPISTATE_IDLE,SPISTATE_WRITE,SPISTATE_READ_WAITFORDONE,SPISTATE_READ_WAITFORDATA);
	type out_content_type is (SPIOUT_OK, SPIOUT_ERROR, SPIOUT_INTERNAL, SPIOUT_EXTERNAL);
	
	signal state : state_type;
	signal out_content : out_content_type;
	
	--received command from peer
	signal rec_cmd  : std_logic_vector(7 downto 0);
	signal rec_data : std_logic_vector(7 downto 0);
	--internal registers
   signal status_reg : std_logic_vector(7 downto 0);
	signal config_reg : std_logic_vector(7 downto 0) := "00000000";
	signal led_reg    : std_logic_vector(7 downto 0) := "00000000";
	
	--local copies of output
	signal int_reg_muxout: std_logic_vector(7 downto 0);
	signal ext_reg_out: std_logic_vector(7 downto 0);
	
	
	signal led_states: std_logic_vector(7 downto 0);

	--Protocol
	--First byte is the command, MSB sent first
	---bit7 = r/w (w=1b1)
	---bit6 = internal registers (1b1)/slotcar registers (1b0)
	--bit5-0 = address
	--Second byte is data, MSB sent first. Peer is assumed to wait "long enough" before reading/writing data 
	---If command is a read, Peer should send 0xAA (OK) as second command
	
	--Return values
	---During write of command, 0xAA is returned if everything is ok. If FPGA is in an error state 0xFF is returned 
   --	During second byte, if command was a write, 0xAA is returned if command was ok. Otherwise 0xFF if an error was found
	
	--Internal registers
	---0x00, version register r
	---0x01, status r
	---0x02, config r/w,
	   --bit7 - 1, reserved
	   --bit0, led output. 1b0 = spi data from master, 1b1 = led register
	---0x03, leds r/w
	
	--External registers
	---
	
begin
					
process(clk,rst)
begin
	if (rst = '1') then
		state <= SPISTATE_IDLE;
		out_content <= SPIOUT_OK;
		
		config_reg <= (others=>'0');
		led_reg    <= (others=>'0');
		
		extreg_dataout		<= (others => '0');
		extreg_addressout	<= (others => '0');
		extreg_enable		<= '0';
	
	elsif rising_edge(clk) then
		extreg_enable		<= '0'; --external write only needs one cycle
		
		case state is
		---------IDLE--------------
		when SPISTATE_IDLE =>
			--command received?
			if (spidata_valid_in = '1') then
				rec_cmd <= spidata_in;
					 
				--if MSB is set, command is write 	 
				if (spidata_in(7) = '1') then
					state <= SPISTATE_WRITE;
					out_content <= SPIOUT_OK;
				else --otherwise command is read			
					--internal read if bit 6 is set
					if(spidata_in(6) = '1') then 
						state <= SPISTATE_READ_WAITFORDONE;			
						out_content <= SPIOUT_INTERNAL;
					else --external registers, need an extra clkcycle
						state <= SPISTATE_READ_WAITFORDATA;			
						out_content <= SPIOUT_ERROR;
						--in reality even fewer registers, but we have 6 address bits
						--so lets send them. If user exceeds limits register file will
						--send error
						extreg_addressin <= "00" & spidata_in(5 downto 0);
					end if;
				end if;
			end if;
					 
		----------WRITE--------------	 
		when SPISTATE_WRITE =>
			--if peer writes data
			if (spidata_valid_in = '1') then
				rec_data <= spidata_in;
				state <= SPISTATE_IDLE;
				out_content <= SPIOUT_OK;
				
				--internal
				if(rec_cmd(6) = '1') then
					case rec_cmd(5 downto 0) is
						when "000010" =>
							config_reg <= spidata_in;
						when "000011" =>
							led_reg    <= spidata_in;
						when others =>
					end case;
				--external
				else
					extreg_dataout		<= spidata_in;
					extreg_addressout	<= "00" & rec_cmd(5 downto 0);
					extreg_enable		<= '1';
				end if;
			end if;
					 
		----------READ--------------	 
		when SPISTATE_READ_WAITFORDONE =>
			--when second byte is received, peer has alread read data
			if (spidata_valid_in = '1') then
				rec_data <= spidata_in;
				state <= SPISTATE_IDLE;
				out_content <= SPIOUT_OK;
			end if;
		when SPISTATE_READ_WAITFORDATA =>
			--address to registerfile was put out last cycle,
			--data should be available now
			ext_reg_out <= extreg_datain;
			state <= SPISTATE_READ_WAITFORDONE;
			out_content <= SPIOUT_EXTERNAL;
			
		end case;
	end if; --if reset
end process;
	
	status_reg <= "0000000" & pll_locked;
	   
	with out_content select
		spidata_out <= x"AA" 			when SPIOUT_OK,
							x"FF" 			when SPIOUT_ERROR,
							int_reg_muxout when SPIOUT_INTERNAL,
							ext_reg_out		when SPIOUT_EXTERNAL;
							
	with rec_cmd(5 downto 0) select
		int_reg_muxout <= version		when "000000",
								status_reg	when "000001",
								config_reg	when "000010",
								led_reg		when "000011", 
								x"FF" when others;
								
	with config_reg(0) select
		leds <= 	led_states	when '0',
					led_reg		when '1';

	with state select
		led_states <= x"01" when SPISTATE_IDLE,
				    x"02" when SPISTATE_WRITE,
					 x"04" when SPISTATE_READ_WAITFORDONE,
					 x"08" when SPISTATE_READ_WAITFORDATA;
end architecture syn;

-- *** EOF ***
