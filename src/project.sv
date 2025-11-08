/*
 * Copyright (c) 2025 ED2 nkpng
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_vga_projekt_ed_nkpng (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [11:0] vga;

  // TinyVGA PMOD
  assign uo_out = {hsync, vga[9], vga[5], vga[1], vsync, vga[11], vga[7], vga[3]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in, vga, rst_n};

  vga_projekt_ed_nkpng_top vgad_0(clk, vga, hsync, vsync);
  
endmodule

// The testbench module is placed at the end of the code

// ---------------------- top-level module ----------------------- //

module vga_projekt_ed_nkpng_top(input logic MAX10_CLK1_50,
		output logic [11:0] VGA_OUT,
		output logic VGA_HS, VGA_VS);
		
	// 50MHz to 25MHz clock divider
	
	logic clk;
	always_ff @(posedge MAX10_CLK1_50)
		clk <= ~clk;
	
	// VGA driver
	
	logic [9:0] img_x, img_y;
	logic [11:0]img_rgb;
	
	vga_driver vgad_0(.clk(clk),
		.img_x(img_x), .img_y(img_y),
		.rgb_in(img_rgb),
		.vga_out(VGA_OUT),
		.vga_hs(VGA_HS), .vga_vs(VGA_VS));
	
	// Embedded image
		
	test_image timg_0(.x(img_x), .y(img_y), .rgb(img_rgb));
		
endmodule

// ------------------------- vga driver -------------------------- //

module vga_driver(input logic clk,
		output logic [9:0] img_x, img_y,
		input logic [11:0] rgb_in,
		output logic [11:0] vga_out,
		output logic vga_hs, vga_vs);
	
	logic [1:0] horz_state, vert_state;
	
	vga_timing vgatim_0(.clk(clk), 
		.img_x(img_x), .img_y(img_y),
		.horz_state(horz_state), .vert_state(vert_state));
	
	vga_output vgaout_0(.clk(clk), 
		.horz_state(horz_state), .vert_state(vert_state),
		.rgb_in(rgb_in), .vga_out(vga_out),
		.vga_hs(vga_hs), .vga_vs(vga_vs));
	
endmodule

// ------------------------- vga timing -------------------------- //

module vga_timing(input logic clk, 
		output logic [9:0] img_x, img_y,
		output logic [1:0] horz_state, vert_state);
		
	logic horz_rst, vert_rst;
	
	horz_state_cnt hsc_0(.clk(clk), .en(1'b1), 
		.full_rst(horz_rst), .state(horz_state), .cnt(img_x));
	vert_state_cnt vsc_0(.clk(clk), .en(horz_rst), 
		.full_rst(vert_rst), .state(vert_state), .cnt(img_y));
		
endmodule

// ------------------------- vga output -------------------------- //

module vga_output(input logic clk, 
		input logic [1:0] horz_state, vert_state,
		input logic [11:0] rgb_in,
		output logic [11:0] vga_out,
		output logic vga_hs, vga_vs);
		
	always_ff @(posedge clk) begin
		if (horz_state == 2'b10 && vert_state == 2'b10)
			vga_out <= rgb_in;
		else
			vga_out <= 12'h000;
			
		vga_hs <= horz_state != 2'b00;
		vga_vs <= vert_state != 2'b00;
	end
	
endmodule

// ------------------ horizontal state counter ------------------- //

module horz_state_cnt(input logic clk, en,
		output full_rst,
		output logic [1:0] state,
		output [9:0]cnt);
	
	logic [9:0]horz_cnt_goal;
	logic horz_reset;
	
	assign horz_reset = cnt >= horz_cnt_goal;
	assign full_rst = horz_reset && state == 2'b11;
	
	video_state vids_0(.clk(clk), .en(en && horz_reset), .state(state));
	
	syn_cnt #(10) scnt_0(.clk(clk), .en(en), .rst(horz_reset), .cnt(cnt));
	
	horz_timing htim_0(.horz_state(state), .horz_cnt_goal(horz_cnt_goal));
	
endmodule

// ------------------- vertical state counter -------------------- //

module vert_state_cnt(input logic clk, en,
		output full_rst,
		output logic [1:0] state,
		output [9:0]cnt);
	
	logic [9:0]vert_cnt_goal;
	logic vert_reset;
	
	assign vert_reset = cnt >= vert_cnt_goal;
	assign full_rst = vert_reset && state == 2'b11;
	
	video_state vids_0(.clk(clk), .en(en && vert_reset), .state(state));
	
	syn_cnt #(10) scnt_0(.clk(clk), .en(en), .rst(vert_reset), .cnt(cnt));
	
	vert_timing vtim_0(.vert_state(state), .vert_cnt_goal(vert_cnt_goal));
	
endmodule

// ---------------- generic video state machine ------------------ //

module video_state(input logic clk, en,
		output logic [1:0] state);
		
	logic [1:0] next_state;
		
	always_comb
		case (state)
			2'b00:     next_state = 2'b01;
			2'b01:      next_state = 2'b10;
			2'b10:     next_state = 2'b11;
			2'b11:      next_state = 2'b00;
			default: next_state = 2'b00;
		endcase
		
	always_ff @(posedge clk)
		if (en)
			state <= next_state;
			
endmodule

// ----------------- vga output timing constants ----------------- //

module horz_timing(input logic [1:0] horz_state,
		output logic[9:0] horz_cnt_goal);

	/*
	Sync 96 cycles
	Back porch 48 cycles
	Video 640 cycles
	Front porch 16 cycles
	*/
	always_comb
		case (horz_state)
			2'b00:     horz_cnt_goal = 10'd95;
			2'b01:      horz_cnt_goal = 10'd47;
			2'b10:     horz_cnt_goal = 10'd639;
			2'b11:      horz_cnt_goal = 10'd15;
			default: horz_cnt_goal = 10'd0;
		endcase
		
endmodule

module vert_timing(input logic [1:0] vert_state,
		output logic[9:0] vert_cnt_goal);
	
	/*
	Sync 2 lines
	Back porch 33 lines
	Video 480 lines
	Front porch 10 lines
	*/
	always_comb
		case (vert_state)
			2'b00:     vert_cnt_goal = 10'd1;
			2'b01:      vert_cnt_goal = 10'd32;
			2'b10:     vert_cnt_goal = 10'd479;
			2'b11:      vert_cnt_goal = 10'd9;
			default:	vert_cnt_goal = 10'd0;
		endcase
	
endmodule

// --------------------- synchronous counter --------------------- //

module syn_cnt
		#(parameter wd = 8)
		(input logic clk, en, rst, 
		output logic [wd-1:0]cnt);
	
	always_ff @(posedge clk)
		if (en)
			cnt <= rst ? 0 : (cnt + 1);

endmodule

// ------------------------- test image -------------------------- //

module test_image(input logic [9:0] x, y,
		output logic [11:0] rgb);

	logic [3:0]scale;
	assign scale = x[6:3];
		
	always_comb
		case (y[8:6])
			3'b000: rgb = {scale, 4'h0, 4'h0};
			3'b001: rgb = {4'h0, scale, 4'h0};
			3'b010: rgb = {4'h0, 4'h0, scale};
			3'b011: rgb = {scale, 4'h0, scale};
			3'b100: rgb = {scale, scale, 4'h0};
			3'b101: rgb = {4'h0, scale, scale};
			3'b110: rgb = {scale, scale, scale};
			3'b111: rgb = {scale, 4'h0, 4'h0};
			default: rgb = 12'h000;
		endcase
		
endmodule

// ------------------------- testbench --------------------------- //

/*
`timescale 1ns/1ps

module testbench();

	logic clk;

	logic VGA_HS, VGA_VS;
	logic [3:0] VGA_R, VGA_G, VGA_B;
	
	// Instantiate device under test
	project dut_0(clk, VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS);
	
	// Generate clock
	parameter period = 20; // 20ns to generate 50MHz

	initial begin
		// No reset was implemented so internal signals have to be reset here
		dut_0.clk = 0;
		dut_0.vgad_0.vgatim_0.hsc_0.vids_0.state = 2'b00;
		dut_0.vgad_0.vgatim_0.vsc_0.vids_0.state = 2'b00;
		dut_0.vgad_0.vgatim_0.hsc_0.scnt_0.cnt = 10'b0;
		dut_0.vgad_0.vgatim_0.vsc_0.scnt_0.cnt = 10'b0;
		
		clk = 0;
		forever #(period/2) clk = ~clk;
	end

	// Stop simulation
	// Delay is to simulate one frame
	// 20ns * 2 * 800 * 525 = 16 800 000
	initial #16_800_000 $stop;

endmodule
*/