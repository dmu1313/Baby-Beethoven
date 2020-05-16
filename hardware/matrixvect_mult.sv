
module matrixvect_mult
	#(
	parameter addr_W_size = 16,
	parameter addr_x_size = 12,
	parameter addr_y_size = 12,
	parameter length_M = 512,		//y is length M
	parameter length_N = 32		//x is length N
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
    output [3:0] bram_we_y,
    output [31:0] state
	);
    
    //internal signals
    logic clr_x, clr_y, inc_x, inc_y, done_x, done_y;
    
    assign bram_we_W = 0;
    assign bram_we_x = 0;
    assign bram_wrdata_W = 32'bxxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx;
    assign bram_wrdata_x = 32'bxxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx;

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
		 .bram_addr_x(bram_addr_x),
		 .bram_rddata_x(bram_rddata_x),
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
		 .bram_we_y(bram_we_y),
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
	parameter addr_W_size = 16,
	parameter addr_x_size = 12,
	parameter addr_y_size = 12,
	parameter length_M = 512,		//y is length M
	parameter length_N = 32		//x is length N
	)(
    input   	 clk,
    input   	 reset,
    //BRAM connections
    //W
    output      [addr_W_size-1:0] bram_addr_W,
    input 	 	[31:0] bram_rddata_W,
    //x
    output      [addr_x_size-1:0] bram_addr_x,
    input   	[31:0] bram_rddata_x,
    //y
    output      [addr_y_size-1:0] bram_addr_y,
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
    
    logic [addr_x_size-1:0] counterX;
    logic [addr_y_size-1:0] counterY;

    logic fp_mult_valid;
    logic [31:0] fp_mult_result;
    logic fp_add_valid;

    assign bram_addr_x = counterX;
    assign bram_addr_y = counterY;
    assign bram_addr_W = ((counterY * length_N) + counterX);

	//Done signals
    assign done_x = (counterX == ((length_N-1)*4));
	assign done_y = (counterY == ((length_M-1)*4));
    
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

    //Incrementer for x
    always_ff @(posedge clk) begin
        if (clr_x)
            counterX <= 0;		
        else if (inc_x)
            counterX <= counterX + 4;
    end

    //Incrementer for y
    always_ff @(posedge clk) begin	
        if (clr_y)
            counterY <= 0;
        else if (inc_y)
            counterY <= counterY + 4;
    end
endmodule

//---------------------------------------------------------
//CONTROLPATH----------------------------------------------
module controlpath
(
        input   	 clk,
        input   	 reset,
        //BRAM connections
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
    always_ff @(posedge clk) begin
        if (reset) begin
            p_state <= 0;
        end
        else begin
            p_state <= next_state;
        end
    end
    
//Next State Logic
    always_comb begin
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
            if(ps_control[0] == 0)
                next_state = 0;
            else
                next_state = 4;
        end

        else begin
            next_state = 0;
        end
    end
    
    //Assign control signals
    assign bram_we_y = (p_state == 2 || p_state == 3) ? 4'hf : 4'h0;

	assign pl_status = (p_state == 4) ? 1 : 0;
    assign state = { 29'b0, p_state };

    assign clr_x = (p_state == 0 || p_state == 4 )? 1 : 0; 
    assign clr_y = (p_state == 0 || p_state == 3) ? 1 : 0;
    assign inc_x = (p_state == 3) ? 1 : 0;
    assign inc_y = (p_state == 2) ? 1 : 0;
	
endmodule
