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
	parameter LOG_P = 2,
    parameter P = 2,
	
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
	output [31:0] state,
    //BRAM connections
    //W1
    output [addr_W_size-1:0] bram_addr_W1,
    input  [31:0] bram_rddata_W1,
    output [31:0] bram_wrdata_W1,
    output [3:0] bram_we_W1,
	//W2
    output [addr_W_size-1:0] bram_addr_W2,
    input  [31:0] bram_rddata_W2,
    output [31:0] bram_wrdata_W2,
    output [3:0] bram_we_W2,
	
    //x
    output [addr_x_size-1:0] bram_addr_x,
    input  [31:0] bram_rddata_x,
    output [31:0] bram_wrdata_x,
    output [3:0] bram_we_x,
	
    //y1
    output [addr_y_size-1:0] bram_addr_y1,
    input  [31:0] bram_rddata_y1,
    output [31:0] bram_wrdata_y1,
    output [3:0] bram_we_y1,
	//y2
    output [addr_y_size-1:0] bram_addr_y2,
    input  [31:0] bram_rddata_y2,
    output [31:0] bram_wrdata_y2,
    output [3:0] bram_we_y2
	);
    
    //internal signals
    wire clr_x, clr_y, inc_x, inc_y, done_x, done_y;
    
    datapath 
		#(
		 .LOG_P(LOG_P),
		 .P(P),
		 .addr_W_size(addr_W_size),
		 .addr_x_size(addr_x_size),
		 .addr_y_size(addr_y_size),
		 .length_M(length_M),		
		 .length_N(length_N)			
		 )
		dp(
		 .clk(clk),
		 .reset(reset),
		 .bram_addr_W1(bram_addr_W1),
		 .bram_rddata_W1(bram_rddata_W1),
		 .bram_wrdata_W1(bram_wrdata_W1), 
		 .bram_addr_W2(bram_addr_W2),
		 .bram_rddata_W2(bram_rddata_W2),
		 .bram_wrdata_W2(bram_wrdata_W2),  //don't need?
		 .bram_addr_x(bram_addr_x),
		 .bram_rddata_x(bram_rddata_x),
		 .bram_wrdata_x(bram_wrdata_x),    //don't need?
		 .bram_addr_y1(bram_addr_y1),
		 .bram_rddata_y1(bram_rddata_y1),
		 .bram_wrdata_y1(bram_wrdata_y1),
		 .bram_addr_y2(bram_addr_y2),
		 .bram_rddata_y2(bram_rddata_y2),
		 .bram_wrdata_y2(bram_wrdata_y2),
		 .clr_x(clr_x),
		 .inc_x(inc_x),
		 .clr_y(clr_y),
		 .inc_y(inc_y),
		 .done_y(done_y),
		 .done_x(done_x)
		);   		 
   
    controlpath 
		#(
		.LOG_P(LOG_P),
		.P(P)
		)
		cp(
		 .clk(clk),
		 .reset(reset),
		 .bram_we_W1(bram_we_W1),
		 .bram_we_W2(bram_we_W2),
		 .bram_we_x(bram_we_x),
		 .bram_we_y1(bram_we_y1),
		 .bram_we_y2(bram_we_y2),
		 .clr_x(clr_x),
		 .clr_y(clr_y),
		 .inc_x(inc_x),
		 .inc_y(inc_y),
		 .done_y(done_y),
		 .done_x(done_x),
		 .ps_control(ps_control),
		 .pl_status(pl_status),
		 .state(state)
    );

endmodule

//---------------------------------------------------------
//DATAPATH-------------------------------------------------
module datapath
	#(
	parameter LOG_P = 2,
    parameter P = 2,
	
	parameter addr_W_size = 16,
	parameter addr_x_size = 12,
	parameter addr_y_size = 12,
	parameter length_M = 128,		//y is length M
	parameter length_N = 128		//x is length N
	)(
    input   	 clk,
    input   	 reset,
    //BRAM connections
    //W1
    output reg  [addr_W_size-1:0] bram_addr_W1,
    input 	 	[31:0] bram_rddata_W1,
    output   	[31:0] bram_wrdata_W1,  //don't need?
    //W2
    output reg  [addr_W_size-1:0] bram_addr_W2,
    input 	 	[31:0] bram_rddata_W2,
    output   	[31:0] bram_wrdata_W2,  //don't need?
	
    //x
    output reg  [addr_x_size-1:0] bram_addr_x,
    input   	[31:0] bram_rddata_x,
    output   	[31:0] bram_wrdata_x,    //don't need?
	
    //y1
    output reg  [addr_y_size-1:0] bram_addr_y1,
    input  	 	[31:0] bram_rddata_y1,
    output  	[31:0] bram_wrdata_y1,
    //y2
    output reg  [addr_y_size-1:0] bram_addr_y2,
    input  	 	[31:0] bram_rddata_y2,
    output  	[31:0] bram_wrdata_y2,
	
    //CONTROLPATH connections
    input   	 clr_x,
    input   	 inc_x,
    input   	 clr_y,
    input   	 inc_y,
    output  	 done_y,
    output   	 done_x
	);
    
    wire fp_mult_valid;
    wire [LOG_P-1:0][31:0] fp_mult_results;
    wire fp_add_valid;
    
	//Parallel signals for W and y
//BRAM rddata
	//Ws
	logic [LOG_P-1:0][31:0] bram_rddata_Ws;
    assign  bram_rddata_Ws[0] = bram_rddata_W1;
    assign  bram_rddata_Ws[1] = bram_rddata_W2 ;
	//ys
	logic [LOG_P-1:0][31:0] bram_rddata_ys;
    assign bram_rddata_ys[0] = bram_rddata_y1;
    assign bram_rddata_ys[1] = bram_rddata_y2;
	
//BRAM wrdata
	//Ws
    logic [LOG_P-1:0][31:0] bram_wrdata_Ws;
    assign bram_wrdata_W1 = bram_wrdata_Ws[0];//
    assign bram_wrdata_W2 = bram_wrdata_Ws[1];//
	//ys
	logic [LOG_P-1:0][31:0] bram_wrdata_ys;
    assign bram_wrdata_y1 = bram_wrdata_ys[0];
    assign bram_wrdata_y2 = bram_wrdata_ys[1];
    
 //BRAM addr 
	//Ws
    logic [LOG_P-1:0][31:0] bram_addr_Ws;
	logic [31:0] bram_addr_W;
    assign bram_addr_W1 = bram_addr_Ws[0];
    assign bram_addr_W2 = bram_addr_Ws[1];
	//ys
	logic [LOG_P-1:0][31:0] bram_addr_ys;
	logic [31:0] bram_addr_y;
    assign bram_addr_y1 = bram_addr_ys[0];
    assign bram_addr_y2 = bram_addr_ys[1];

 ///////////////////////////////////////////////////////
	
//generate block
	generate
		genvar i;
		for( i = 0; i < P; i++) begin
		
		assign bram_addr_Ws[i] = bram_addr_W;
		assign bram_addr_ys[i] = bram_addr_y;
		
		//Floating Point Multiplication
		fp_mult mult (
		  .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
		  .s_axis_a_tdata(bram_rddata_Ws[i]),              // input wire [31 : 0] s_axis_a_tdata
		  .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
		  .s_axis_b_tdata(bram_rddata_x),              // input wire [31 : 0] s_axis_b_tdata
		  .m_axis_result_tvalid(fp_mult_valid),  // output wire m_axis_result_tvalid
		  .m_axis_result_tdata(fp_mult_results[i])    // output wire [31 : 0] m_axis_result_tdata
		);
		
		//Floating Point Addition
		fp_add add (
		  .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
		  .s_axis_a_tdata(bram_rddata_ys[i]),              // input wire [31 : 0] s_axis_a_tdata
		  .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
		  .s_axis_b_tdata(fp_mult_results[i]),              // input wire [31 : 0] s_axis_b_tdata
		  .m_axis_result_tvalid(fp_add_valid),  // output wire m_axis_result_tvalid
		  .m_axis_result_tdata(bram_wrdata_ys[i])    // output wire [31 : 0] m_axis_result_tdata
		);	
	
		end
	endgenerate


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
	assign done_y = (bram_addr_y == ((length_M/P)-1)*4); 

endmodule

//---------------------------------------------------------
//CONTROLPATH----------------------------------------------
module controlpath 
	#(
	parameter LOG_P = 2,
	parameter P = 2
	)(
    input   	 clk,
    input   	 reset,
    //BRAM connections
    output [3:0] bram_we_W1,
	output [3:0] bram_we_W2,
    output [3:0] bram_we_x,
    output [3:0] bram_we_y1,
	output [3:0] bram_we_y2,
    //DATAPATH connections
    output    	 clr_x,
    output   	 clr_y,
    output   	 inc_x,
    output   	 inc_y,
    input    	 done_y,
    input   	 done_x,
    //PS connections
    input  [31:0] ps_control, 	//bit 1 for 2nd half, bit 0 for 1st half
    output [31:0] pl_status,
	output [31:0] state

	);


    //current state and next state regs
    logic [2:0]   	 p_state;
    logic [2:0]   	 next_state;
    
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
	 else begin	
		next_state = 0;
	
	 end
    end
    
//Assign control signals
    assign bram_we_W1 = 0;   	 //always in read mode
	assign bram_we_W2 = 0;
	
    assign bram_we_x = 0;    
	
    assign bram_we_y1 = (p_state == 2 || p_state == 3) ? 4'hf : 4'h0;
	assign bram_we_y2 = (p_state == 2 || p_state == 3) ? 4'hf : 4'h0;
	
	assign pl_status = (p_state == 4)? 1 : 0;
	assign state = { 29'b0, p_state };
    assign clr_x = (p_state == 0 || p_state == 4 )? 1 : 0; 
    assign clr_y = (p_state == 0 || p_state == 3) ? 1 : 0;
    assign inc_x = (p_state == 3) ? 1 : 0;
    assign inc_y = (p_state == 2) ? 1 : 0;
	
endmodule
