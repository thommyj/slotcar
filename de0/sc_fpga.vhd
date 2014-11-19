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
			SCLK_out      : buffer std_logic;
			MOSI_out      : out std_logic;
			MISO_out      : out std_logic;
			UART0_out	  : out std_logic;
			UART0_in	     : in std_logic;
--			UART0_rts     : out std_logic;
			UART1_out	  : out std_logic;
			UART1_in	     : in std_logic
--			UART1_rts     : out std_logic
       );
end entity sc_fpga;

--*****************************************************************************
--*  DEFINE: Architecture                                                     *
--****************************************************************************

architecture syn of sc_fpga is

	type uartstate_type is (IDLE0,UART0TX,UART1RX,IDLE1,UART1TX,UART0RX);
	signal uartstate : uartstate_type;
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
			data_out       : buffer std_logic_vector(7 downto 0);		--from rpi
			data_in        : in  std_logic_vector(7 downto 0);			--to rpi
         data_out_valid : buffer std_logic
       );
	end component;
		 
	component spi_decoder
		port( 
         clk               : in  std_logic;
			rst               : in  std_logic;
			spidata_out       : out std_logic_vector(7 downto 0);    --to rpi
			spidata_in        : in  std_logic_vector(7 downto 0);		--from rpi
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
			
			writer2_data	: in  std_logic_vector(7 downto 0);
			writer2_address: in  std_logic_vector(7 downto 0);
			writer2_enable	: in  std_logic;
			
			reader_data    : out std_logic_vector(7 downto 0);
			reader_address : in  std_logic_vector(7 downto 0);
			
			reader2_data    : out std_logic_vector(7 downto 0);
			reader2_address : in  std_logic_vector(7 downto 0)
       );
	end component;
	
	component uart_halfduplex is
   port( 
			clk                      : in   std_logic;
			rst                      : in   std_logic;
			parallell_data_out       : out  std_logic_vector(7 downto 0);
			parallell_data_out_valid : out  std_logic;
			uart_data_in				 : in   std_logic;
			
			parallell_data_in        : in  std_logic_vector(7 downto 0);
			parallell_data_in_valid  : in  std_logic;
			parallell_data_in_sent   : out std_logic;
			uart_data_out				 : out std_logic;
			
			rts							 : out std_logic
       );
	end component;
	
	component uart_controller
   port ( 
         clk                      : in   std_logic;
			rst                      : in   std_logic;
			
			rts_screen               : out  std_logic;
			datarec_screen           : in   std_logic;
			data_from_screen         : in   std_logic_vector(7 downto 0);
			data_to_screen           : out  std_logic_vector(7 downto 0);
			
			write_address            : out  std_logic_vector(7 downto 0);
			write_data               : out  std_logic_vector(7 downto 0);
			write_en                 : out  std_logic;
			
			read_address             : out  std_logic_vector(7 downto 0);
			read_data                : in   std_logic_vector(7 downto 0);
			
			rts_track                : out  std_logic;
			datarec_track            : in   std_logic;
			data_from_track          : in   std_logic_vector(7 downto 0);
			data_to_track            : out  std_logic_vector(7 downto 0)
        );
   end component uart_controller;
	
		 
	 signal clk                       	: std_logic;
	 signal rst                       	: std_logic;
	 signal rst_cnt				       	: std_logic_vector(15 downto 0):= "0000000000000000";
	 signal pll_locked                	: std_logic;
	 signal spidata_from_master       	: std_logic_vector(7 downto 0);
	 signal spidata_to_master         	: std_logic_vector(7 downto 0); 
	 signal spidata_valid_from_master 	: std_logic;
	 constant VERSION                 	: std_logic_vector(7 downto 0):= "00001000";
	 
	 signal uart_controller_to_rf_write_data		      : std_logic_vector(7 downto 0);
	 signal uart_controller_to_rf_write_address	      : std_logic_vector(7 downto 0);
	 signal uart_controller_to_rf_write_valid	         : std_logic;
	 
	 signal rf_to_uart_controller_read_address 			: std_logic_vector(7 downto 0);
	 signal rf_to_uart_controller_read_data 				: std_logic_vector(7 downto 0);
	 
	 signal spi_decoder_to_rf_data		: std_logic_vector(7 downto 0);
	 signal spi_decoder_to_rf_address	: std_logic_vector(7 downto 0);
	 signal spi_decoder_to_rf_valid	   : std_logic;
	 
	 signal rs485data_to_spi				: std_logic_vector(7 downto 0);
	 signal rs485address_to_spi			: std_logic_vector(7 downto 0);
	 
	 --UART
	 signal UART0_parallell_data_out			: std_logic_vector(7 downto 0);
	 signal UART0_parallell_data_out_valid : std_logic;
	 signal UART0_parallell_data_in			: std_logic_vector(7 downto 0);
	 signal UART0_parallell_data_in_valid	: std_logic;
	 signal UART0_parallell_data_in_sent	: std_logic;
						
	 signal UART1_parallell_data_out			: std_logic_vector(7 downto 0);
	 signal UART1_parallell_data_out_valid : std_logic;
	 signal UART1_parallell_data_in			: std_logic_vector(7 downto 0);
	 signal UART1_parallell_data_in_valid	: std_logic;
	 signal UART1_parallell_data_in_sent	: std_logic;
	 
	 signal UART_payload							: std_logic_vector(7 downto 0);
	
	

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
						leds 					=> open, --LED_GREEN,
						extreg_dataout		=> spi_decoder_to_rf_data, --should later come from rs485 block
						extreg_addressout	=> spi_decoder_to_rf_address, --should later come from rs485 block
						extreg_enable		=> spi_decoder_to_rf_valid,
						extreg_datain		=> rs485data_to_spi,
						extreg_addressin	=> rs485address_to_spi
               );
					
   inst_registerfile : registerfile
		port map( 
						clk				 => clk,
						rst				 => rst,
						
						writer_data		 => spi_decoder_to_rf_data,
						writer_address	 => spi_decoder_to_rf_address,
						writer_enable	 => spi_decoder_to_rf_valid,
						
						writer2_data	 => uart_controller_to_rf_write_data,
						writer2_address => uart_controller_to_rf_write_address,
						writer2_enable	 => uart_controller_to_rf_write_valid,
						
						reader_data		 => rs485data_to_spi,
						reader_address  => rs485address_to_spi,
						
						reader2_data    => rf_to_uart_controller_read_data,
						reader2_address => rf_to_uart_controller_read_address
						
       );
	inst_UART0 : uart_halfduplex
		port map( 
						clk                      => clk,
						rst                      => rst,
						parallell_data_out       => UART0_parallell_data_out,
						parallell_data_out_valid => UART0_parallell_data_out_valid,
						uart_data_in				 => UART0_in,
						parallell_data_in        => UART0_parallell_data_in,
						parallell_data_in_valid  => UART0_parallell_data_in_valid,
						parallell_data_in_sent   => UART0_parallell_data_in_sent,
						uart_data_out				 => UART0_out,
						rts							 => open
       );
		 
	inst_UART1 : uart_halfduplex
		port map( 
						clk                      => clk,
						rst                      => rst,
						parallell_data_out       => UART1_parallell_data_out,
						parallell_data_out_valid => UART1_parallell_data_out_valid,
						uart_data_in				 => UART1_in,
						parallell_data_in        => UART1_parallell_data_in,
						parallell_data_in_valid  => UART1_parallell_data_in_valid,
						parallell_data_in_sent   => UART1_parallell_data_in_sent,
						uart_data_out				 => UART1_out,
						rts							 => open
       );
	inst_UART_CONTROLLER : uart_controller
	   port map(
						clk                      => clk,
	  		         rst                      => rst,
			         rts_screen               => UART1_parallell_data_in_valid,
						datarec_screen           => UART1_parallell_data_out_valid,
						data_from_screen         => UART1_parallell_data_out,
						data_to_screen           => UART1_parallell_data_in,
				
						write_address            => uart_controller_to_rf_write_address,
						write_data               => uart_controller_to_rf_write_data,
						write_en                 => uart_controller_to_rf_write_valid,
				
						read_address             => rf_to_uart_controller_read_address,
						read_data                => rf_to_uart_controller_read_data,
				
						rts_track                => UART0_parallell_data_in_valid,
						datarec_track            => UART0_parallell_data_out_valid,
						data_from_track          => UART0_parallell_data_out,
						data_to_track            => UART0_parallell_data_in
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

 --UART1_parallell_data_in <= UART0_parallell_data_out;
 --UART0_parallell_data_in <= UART1_parallell_data_out;
 
	--SS_out   <= '0';
	--SCLK_out <= '0';
	MOSI_out <= '0';
	MISO_out <= '0';
	
	LED_GREEN <= uart_controller_to_rf_write_address;
--	LED_GREEN <= UART1_parallell_data_in;
   
end architecture syn;

-- *** EOF ***
