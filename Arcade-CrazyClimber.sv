//============================================================================
//  Arcade: CrazyClimber
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S    // 1 - signed audio samples, 0 - unsigned
);

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : 8'd4;
assign HDMI_ARY = status[1] ? 8'd9  : 8'd3;

`include "build_id.v" 
localparam CONF_STR = {
	"A.CCLIMB;;",
	"-;",
	"O1,Aspect Ratio,Original,Wide;",
	"O34,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"-;",
	"R0,Reset;",
	"J,R Right,R Left,R Down,R Up,Start 1P,Start 2P;",
	"V,v1.00.",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire [10:0] ps2_key;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

wire        forced_scandoubler;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.ps2_key(ps2_key)
);

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'hX75: btn_up          <= pressed; // up
			'hX72: btn_down        <= pressed; // down
			'hX6B: btn_left        <= pressed; // left
			'hX74: btn_right       <= pressed; // right

			'hX1D: btn_rup         <= pressed; // W
			'hX1C: btn_rleft       <= pressed; // A
			'hX1B: btn_rdown       <= pressed; // S
			'hX23: btn_rright      <= pressed; // D

			'h005: btn_one_player  <= pressed; // F1
			'h006: btn_two_players <= pressed; // F2
		endcase
	end
end

reg btn_up     = 0;
reg btn_down   = 0;
reg btn_right  = 0;
reg btn_left   = 0;
reg btn_rup    = 0;
reg btn_rdown  = 0;
reg btn_rright = 0;
reg btn_rleft  = 0;
reg btn_one_player  = 0;
reg btn_two_players = 0;

wire m_right  = btn_rright | joy[0];
wire m_left   = btn_rleft  | joy[1];
wire m_down   = btn_rdown  | joy[2];
wire m_up     = btn_rup    | joy[3];
wire m_rright = btn_right  | joy[4];
wire m_rleft  = btn_left   | joy[5];
wire m_rdown  = btn_down   | joy[6];
wire m_rup    = btn_up     | joy[7];

wire m_start1 = btn_one_player  | joy[8];
wire m_start2 = btn_two_players | joy[9];
wire m_coin   = m_start1 | m_start2;

wire ce_vid = ce_6;
wire hs, vs;
wire [2:0] r,g;
wire [1:0] b;

assign VGA_CLK  = clk_sys;
assign HDMI_CLK = VGA_CLK;
assign HDMI_CE  = VGA_CE;
assign HDMI_R   = VGA_R;
assign HDMI_G   = VGA_G;
assign HDMI_B   = VGA_B;
assign HDMI_DE  = VGA_DE;
assign HDMI_HS  = VGA_HS;
assign HDMI_VS  = VGA_VS;
assign HDMI_SL  = 0;

wire HSync = ~hs;
wire VSync = ~vs;
wire HBlank, VBlank;

wire [1:0] scale = status[4:3];

video_mixer #(.LINE_LENGTH(260), .HALF_DEPTH(1)) video_mixer
(
	.*,
	.clk_sys(VGA_CLK),
	.ce_pix(ce_vid),
	.ce_pix_out(VGA_CE),

	.scanlines({scale == 3, scale == 2}),
	.scandoubler(scale || forced_scandoubler),
	.hq2x(scale==1),
	.mono(0),

	.R({r,r[2]}),
	.G({g,g[2]}),
	.B({b,b})
);

wire [15:0] audio;
assign AUDIO_L = audio;
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

reg initReset_n = 0;
always @(posedge clk_sys) begin
	reg old_download;
	old_download <= ioctl_download;
	if(old_download & ~ioctl_download) initReset_n <= 1;
end

reg ce_12,ce_6;
always @(negedge clk_sys) begin
	reg [2:0] div;

	div   <= div + 1'd1;
	ce_12 <= !div[1:0];
	ce_6  <= !div[2:0];
end

crazy_climber crazy_climber
(
	.clock_12(clk_sys & ce_12),
	.reset(RESET | status[0] | buttons[1] | ~initReset_n),

	.dn_clk(clk_sys),
	.dn_addr(ioctl_addr[15:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr),

	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_hs(hs),
	.video_vs(vs),
	.video_hblank(HBlank),
	.video_vblank(VBlank),

	.audio_out(audio),

	.coin1(m_coin),
	.start1(m_start1),
	.start2(m_start2),

	.l_up1(m_up),
	.l_down1(m_down),
	.l_left1(m_left),
	.l_right1(m_right),
	.r_up1(m_rup),
	.r_down1(m_rdown),
	.r_left1(m_rleft),
	.r_right1(m_rright),

	.l_up2(m_up),
	.l_down2(m_down),
	.l_left2(m_left),
	.l_right2(m_right),
	.r_up2(m_rup),
	.r_down2(m_rdown),
	.r_left2(m_rleft),
	.r_right2(m_rright)
);


endmodule