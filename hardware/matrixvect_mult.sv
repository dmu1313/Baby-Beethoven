`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 03/02/2020 05:54:45 PM
// Design Name:
// Module Name: matrixvect_mult
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


//TOPLEVEL------------------------------------------------------------------------
module matrixvect_mult
	#(
	parameter addr_W_size = 16,
	parameter addr_x_size = 12,
	parameter addr_y_size = 12,
	parameter length_M = 128,		//y is length M
	parameter length_N = 128		//x is length N
	)(
    input   	 clk,
    input    	 reset,
    //AXI4 Lite connections
    input  [31:0] ps_control,		//using bit 1 and 0
    output [31:0] pl_status,		//using bit 1 and 0
    //BRAM connections
    //W
    output [addr_W_size-1:0] bram_addr_W,
    input  [31:0] bram_rddata_W,
    output [31:0] bram_wrdata_W,
    output [3:0] bram_we_W,
    //x
    output [addr_x_size-1:0] bram_addr_x,
    input  [31:0] bram_rddata_x,
    output [31:0] bram_wrdata_x,
    output [3:0] bram_we_x,
    //y
    output [addr_y_size-1:0] bram_addr_y,
    input  [31:0] bram_rddata_y,
    output [31:0] bram_wrdata_y,
    output [3:0] bram_we_y
	);
    
    //internal signals
    wire clr_x, clr_y, inc_x, inc_y, done_x, done_y;
    
    datapath 
		#(
		 .addr_W_size(addr_W_size),
		 .addr_x_size(addr_x_size),
		 .addr_y_size(addr_y_size),
		 .length_M(length_M),		
		 .length_N(length_N)			
		 )
		dp(
		 .clk(clk),
		 .reset(reset),
		 .bram_addr_W(bram_addr_W),
		 .bram_rddata_W(bram_rddata_W),
		 .bram_wrdata_W(bram_wrdata_W),  //don't need?
		 .bram_addr_x(bram_addr_x),
		 .bram_rddata_x(bram_rddata_x),
		 .bram_wrdata_x(bram_wrdata_x),    //don't need?
		 .bram_addr_y(bram_addr_y),
		 .bram_rddata_y(bram_rddata_y),
		 .bram_wrdata_y(bram_wrdata_y),
		 .clr_x(clr_x),
		 .inc_x(inc_x),
		 .clr_y(clr_y),
		 .inc_y(inc_y),
		 .done_y(done_y),
		 .done_x(done_x)
		);   		 
   
    controlpath 
		cp(
		 .clk(clk),
		 .reset(reset),
		 .bram_we_W(bram_we_W),
		 .bram_we_x(bram_we_x),
		 .bram_we_y(bram_we_y),
		 .clr_x(clr_x),
		 .clr_y(clr_y),
		 .inc_x(inc_x),
		 .inc_y(inc_y),
		 .done_y(done_y),
		 .done_x(done_x),
		 .ps_control(ps_control),
		 .pl_status(pl_status)
    );

endmodule

//---------------------------------------------------------
//DATAPATH-------------------------------------------------
module datapath
	#(
	parameter addr_W_size = 16,
	parameter addr_x_size = 12,
	parameter addr_y_size = 12,
	parameter length_M = 128,		//y is length M
	parameter length_N = 128		//x is length N
	)(
    input   	 clk,
    input   	 reset,
    //BRAM connections
    //W
    output reg  [addr_W_size-1:0] bram_addr_W,
    input 	 	[31:0] bram_rddata_W,
    output   	[31:0] bram_wrdata_W,  //don't need?
    //x
    output reg  [addr_x_size-1:0] bram_addr_x,
    input   	[31:0] bram_rddata_x,
    output   	[31:0] bram_wrdata_x,    //don't need?
    //y
    output reg  [addr_y_size-1:0] bram_addr_y,
    input  	 	[31:0] bram_rddata_y,
    output  	[31:0] bram_wrdata_y,
    //CONTROLPATH connections
    input   	 clr_x,
    input   	 inc_x,
    input   	 clr_y,
    input   	 inc_y,
    output  	 done_y,
    output   	 done_x
	);
    
    wire fp_mult_valid;
    wire [31:0] fp_mult_result;
    wire fp_add_valid;
    
    //Floating Point Multiplication
    fp_mult mult (
      .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
      .s_axis_a_tdata(bram_rddata_W),              // input wire [31 : 0] s_axis_a_tdata
      .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
      .s_axis_b_tdata(bram_rddata_x),              // input wire [31 : 0] s_axis_b_tdata
      .m_axis_result_tvalid(fp_mult_valid),  // output wire m_axis_result_tvalid
      .m_axis_result_tdata(fp_mult_result)    // output wire [31 : 0] m_axis_result_tdata
    );
    //Floating Point Addition
    fp_add add (
      .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
      .s_axis_a_tdata(bram_rddata_y),              // input wire [31 : 0] s_axis_a_tdata
      .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
      .s_axis_b_tdata(fp_mult_result),              // input wire [31 : 0] s_axis_b_tdata
      .m_axis_result_tvalid(fp_add_valid),  // output wire m_axis_result_tvalid
      .m_axis_result_tdata(bram_wrdata_y)    // output wire [31 : 0] m_axis_result_tdata
    );
   
	//Multiply/Accumulate
    //assign bram_wrdata_y = (bram_rddata_y) + (bram_rddata_W * bram_rddata_x);
    
	//Address signals
    always @* begin
    	bram_addr_W = ((bram_addr_y * length_N) + bram_addr_x) ; 
			
	end
    //Incrementer for x
    always @(posedge clk) begin
   	 if(clr_x)
   		 bram_addr_x <= 0;		
   	 else if (inc_x)
   		 bram_addr_x <= bram_addr_x + 4;
    end
    //Incrementer for y
    always @(posedge clk) begin	
   	 if(clr_y)

		bram_addr_y <= 0;

   	 else if (inc_y)
   		 bram_addr_y <= bram_addr_y + 4;
    end

	//Done signals    
    assign done_x = (bram_addr_x == (length_N-1)*4); 
	assign done_y = (bram_addr_y == (length_M-1)*4); 

endmodule

//---------------------------------------------------------
//CONTROLPATH----------------------------------------------
module controlpath (
    input   	 clk,
    input   	 reset,
    //BRAM connections
    output [3:0] bram_we_W,
    output [3:0] bram_we_x,
    output [3:0] bram_we_y,
    //DATAPATH connections
    output    	 clr_x,
    output   	 clr_y,
    output   	 inc_x,
    output   	 inc_y,
    input    	 done_y,
    input   	 done_x,
    //PS connections
    input  [31:0] ps_control, 	//bit 1 for 2nd half, bit 0 for 1st half
    output [31:0] pl_status

	);


    //current state and next state regs
    reg [2:0]   	 p_state;
    reg [2:0]   	 next_state;
    
    //FSM: -----------------------------------------//
    //state 0: Reset   								//
    //state 1: write to y[]   						//
    //state 2: increment y index   				 	//
    //state 3: increment x index and clear y index  //
    //state 4: Done, wait for ACK					//
    //----------------------------------------------//
    
//State transitions
    always @(posedge clk) begin
   	 if(reset)
   		 p_state <= 0;
   	 else
   		 p_state <= next_state;
    end
    
//Next State Logic
    always @(*) begin
   	 if (p_state == 0) begin
   		 if (ps_control[0] == 1)
   			 next_state = 1;
   		 else    
   			 next_state = 0;
   	 end
   	 
   	 else if (p_state == 1) begin
   		 if (done_y) begin
   			 next_state = 3;
   		 end
   		 else
   			 next_state = 2;
   	 end
   	 
   	 else if (p_state == 2) begin
   		 next_state = 1;
   	 end    
   	 
   	 else if (p_state == 3) begin
   		 if (done_x) 
			next_state = 4;
   		 else
   			 next_state = 1;
   	 end
   	 
   	 else if (p_state == 4) begin
   		if(ps_control[0] == 1)
			next_state = 4;
		else
			next_state = 0;
   	 end
	 
	 
    end
    
//Assign control signals
    assign bram_we_W = 0;   	 //always in read mode
    assign bram_we_x = 0;    
    assign bram_we_y = (p_state == 2 || p_state == 3) ? 4'hf : 4'h0;
	assign pl_status = (p_state == 4)? 1 : 0;
    assign clr_x = (p_state == 0 || p_state == 4 )? 1 : 0; 
    assign clr_y = (p_state == 0 || p_state == 3) ? 1 : 0;
    assign inc_x = (p_state == 3) ? 1 : 0;
    assign inc_y = (p_state == 2) ? 1 : 0;
	
endmodule
