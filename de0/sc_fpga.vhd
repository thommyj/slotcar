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
use IEEE.std_logic_unsigned.ALL;


--*****************************************************************************
--*  DEFINE: Entity                                                           *
--*****************************************************************************

entity sc_fpga is
   port( 
         CLOCK_50      : in  std_logic;
			LED_GREEN     : out std_logic_vector(7 downto 0);
         KEY           : in  std_logic_vector(1 downto 0);
         SW            : in  std_logic_vector(3 downto 0);
			RPI           : in  std_logic_vector(3 downto 0);
			SS_async      : in  std_logic;
			SCLK_async    : in  std_logic;
			MOSI_async    : in  std_logic;
			MISO_async    : out std_logic;
			SS_out        : out std_logic;
			SCLK_out      : out std_logic;
			MOSI_out      : out std_logic;
			MISO_out      : out std_logic
       );
end entity sc_fpga;

--*****************************************************************************
--*  DEFINE: Architecture                                                     *
--****************************************************************************

architecture syn of sc_fpga is

   --
   -- Define all components which are included here
   --
	component pll
     port ( 
            inclk0   : in  std_logic  := '0';
            c0       : out std_logic ;
            locked   : out std_logic 
          );
   end component pll;
	
	component spi 
	   port( 
         clk            : in  std_logic;
			rst            : in  std_logic;
			SS_async       : in  std_logic;
			SCLK_async     : in  std_logic;
			MOSI_async     : in  std_logic;
			MISO_async     : out std_logic;
			data_out       : buffer std_logic_vector(7 downto 0);
			data_in        : in  std_logic_vector(7 downto 0);
         data_out_valid : buffer std_logic
       );
	end component;
		 
	component spi_decoder
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
	end component;
	
	component registerfile is
   port( 
         clk				: in  std_logic;
			rst				: in	std_logic;
			
			writer_data		: in  std_logic_vector(7 downto 0);
			writer_address	: in  std_logic_vector(7 downto 0);
			writer_enable	: in  std_logic;
			
			reader_data    : out std_logic_vector(7 downto 0);
			reader_address : in  std_logic_vector(7 downto 0)
       );
	end component;
		 
	 signal clk                       	: std_logic;
	 signal rst                       	: std_logic;
	 signal rst_cnt				       	: std_logic_vector(15 downto 0):= "0000000000000000";
	 signal pll_locked                	: std_logic;
	 signal spidata_from_master       	: std_logic_vector(7 downto 0);
	 signal spidata_to_master         	: std_logic_vector(7 downto 0); 
	 signal spidata_valid_from_master 	: std_logic;
	 constant VERSION                 	: std_logic_vector(7 downto 0):= "00001000";
	 signal rs485data_from_powerbase		: std_logic_vector(7 downto 0);
	 signal rs485address_from_powerbase	: std_logic_vector(7 downto 0);
	 signal rs485data_enable				: std_logic;
	 signal rs485data_to_spi				: std_logic_vector(7 downto 0);
	 signal rs485address_to_spi			: std_logic_vector(7 downto 0);

begin

   inst_pll : pll
      port map ( 
                 inclk0 => CLOCK_50,
                 c0     => clk,
                 locked => pll_locked
               );

	inst_spi : spi
      port map (
		           clk        => clk,
			        rst        => rst,
			        SS_async   => SS_async,
			        SCLK_async => SCLK_async,
			        MOSI_async => MOSI_async,
			        MISO_async => MISO_async,
			        data_out   => spidata_from_master,
			        data_in    => spidata_to_master,
					  data_out_valid => spidata_valid_from_master
               );
					
	inst_spi_decoder : spi_decoder
      port map (
						clk 					=> clk,
						rst 					=> rst,
						spidata_out 		=> spidata_to_master,
						spidata_in 			=> spidata_from_master,
						spidata_valid_in 	=> spidata_valid_from_master,
						pll_locked 			=> pll_locked,
						version 				=> VERSION,
						leds 					=> LED_GREEN,
						extreg_dataout		=> rs485data_from_powerbase, --should later come from rs485 block
						extreg_addressout	=> rs485address_from_powerbase, --should later come from rs485 block
						extreg_enable		=> rs485data_enable,
						extreg_datain		=> rs485data_to_spi,
						extreg_addressin	=> rs485address_to_spi
               );
					
   inst_registerfile : registerfile
		port map( 
						clk				=> clk,
						rst				=> rst,
						writer_data		=> rs485data_from_powerbase,
						writer_address	=> rs485address_from_powerbase,
						writer_enable	=> rs485data_enable,
						reader_data		=> rs485data_to_spi,
						reader_address => rs485address_to_spi
       );

		 
--async trigg of reset, sync release
process(clk,pll_locked)
begin
	if(pll_locked = '0')	then
		rst <= '1';
	elsif(clk'event and clk = '1') then
		if(rst_cnt = x"FFFF") then
			rst <= '0';
		else
			rst_cnt <= rst_cnt + 1;
		end if;
	end if;
end process;	
					     
	SS_out   <= '0';
	SCLK_out <= '0';
	MOSI_out <= '0';
	MISO_out <= '0';
   
end architecture syn;

-- *** EOF ***
