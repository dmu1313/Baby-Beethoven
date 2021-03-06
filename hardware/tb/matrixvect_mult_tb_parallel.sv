`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2020 01:25:44 AM
// Design Name: 
// Module Name: tb1
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


module tb1();
    logic clk, reset;
    logic  [31:0] ps_control;
    logic [31:0] pl_status;
    logic [31:0] state;
    logic [15:0] bram_addr_W1;
    logic  [31:0] bram_rddata_W1;
    logic [31:0] bram_wrdata_W1;
    logic [3:0]  bram_we_W1;
	    logic [15:0] bram_addr_W2;
    logic  [31:0] bram_rddata_W2;
    logic [31:0] bram_wrdata_W2;
    logic [3:0]  bram_we_W2;
    
    logic [11:0] bram_addr_x;
    logic  [31:0] bram_rddata_x;
    logic [31:0] bram_wrdata_x;
    logic [3:0]  bram_we_x;
    
    logic [11:0] bram_addr_y1;
    logic  [31:0] bram_rddata_y1;
    logic [31:0] bram_wrdata_y1;
    logic [3:0]  bram_we_y1;
	   logic [11:0] bram_addr_y2;
    logic  [31:0] bram_rddata_y2;
    logic [31:0] bram_wrdata_y2;
    logic [3:0]  bram_we_y2;

    logic [11:0] y_addr1;
	logic [11:0] y_addr2;
    logic [11:0] read_addr;
    logic done;

//DECLARATIONS -------------------------------------------------
//matrix-vector multiplier 
    matrixvect_mult 
         #(
			.LOG_P(2),
			.P(2),
            .addr_W_size(16),
            .addr_x_size(12),
            .addr_y_size(12),
            .length_M(128),        //y is length M
            .length_N(128)
            )
            dut(
         .clk(clk), 
        .reset(reset),
        .ps_control(ps_control),
        .pl_status(pl_status),
        .state(state),
        .bram_addr_W1(bram_addr_W1),
        .bram_rddata_W1(bram_rddata_W1),
        .bram_wrdata_W1(bram_wrdata_W1),
        .bram_we_W1(bram_we_W1),
		        .bram_addr_W2(bram_addr_W2),
        .bram_rddata_W2(bram_rddata_W2),
        .bram_wrdata_W2(bram_wrdata_W2),
        .bram_we_W2(bram_we_W2),
        
        .bram_addr_x(bram_addr_x),
        .bram_rddata_x(bram_rddata_x),
        .bram_wrdata_x(bram_wrdata_x),
        .bram_we_x(bram_we_x),
        
        .bram_addr_y1(bram_addr_y1),
        .bram_rddata_y1(bram_rddata_y1),
        .bram_wrdata_y1(bram_wrdata_y1),
        .bram_we_y1(bram_we_y1),
		        .bram_addr_y2(bram_addr_y2),
        .bram_rddata_y2(bram_rddata_y2),
        .bram_wrdata_y2(bram_wrdata_y2),
        .bram_we_y2(bram_we_y2)
    );
//W memory loader
    memory_sim_W ms1(
        .clk(clk), 
        .reset(reset), 
        .bram_addr(bram_addr_W1), 
        .bram_rddata(bram_rddata_W1), 
        .bram_wrdata(bram_wrdata_W1),
        .bram_we(bram_we_W1)
    );
	memory_sim_W ms2(
        .clk(clk), 
        .reset(reset), 
        .bram_addr(bram_addr_W2), 
        .bram_rddata(bram_rddata_W2), 
        .bram_wrdata(bram_wrdata_W2),
        .bram_we(bram_we_W2)
    );
//x memory loader                    
    memory_sim_x xms(
        .clk(clk),
        .reset(reset),
        .bram_addr(bram_addr_x), 
        .bram_rddata(bram_rddata_x), 
        .bram_wrdata(bram_wrdata_x),
        .bram_we(bram_we_x)
     );
//y memory loader       
    memory_sim_y yms1(
       .clk(clk),
       .reset(reset),
       .bram_addr(y_addr1), 
       .bram_rddata(bram_rddata_y1), 
       .bram_wrdata(bram_wrdata_y1),
       .bram_we(bram_we_y1)
    );
    memory_sim_y yms2(
       .clk(clk),
       .reset(reset),
       .bram_addr(y_addr2), 
       .bram_rddata(bram_rddata_y2), 
       .bram_wrdata(bram_wrdata_y2),
       .bram_we(bram_we_y2)
    );
        
    assign y_addr1 = (done == 0) ? bram_addr_y1 : read_addr;
assign y_addr2 = (done == 0) ? bram_addr_y2 : read_addr;
 initial clk=0;
    always #5 clk = ~clk;

    initial begin
        done = 0;
        ps_control = 0;
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        
        #1; 
        reset = 0;

        @(posedge clk);
        @(posedge clk);
        
        #1; 
        ps_control = 1;   //start

        wait(pl_status[0] == 1'b1); //wait done

        @(posedge clk);
        #1; 
        ps_control = 0;

        wait(pl_status[0] == 1'b0);

        @(posedge clk);
        
        done = 1;
        for (int i=0; i<128; i=i+1) begin //read first couple of values
                read_addr = 4 * i;
                @(posedge clk);
                @(posedge clk);
                @(posedge clk);
                @(posedge clk);
                $display("1: y[%d] = %h", i, bram_rddata_y1);
				$display("2: y[%d] = %h", i, bram_rddata_y2);
        end

        #100;
        $stop;
    end

endmodule


module memory_sim_W(
    input         clk,
    input         reset,
    input        [15:0] bram_addr,
    output logic [31:0] bram_rddata,
    input        [31:0] bram_wrdata,
    input         [3:0] bram_we);

    logic [31:0] mem [128*128-1:0];

    initial begin
        integer i;
        for (i=0; i<(2**14)-1; i=i+1)
            mem[i] = 0;

    //A
    	mem[0] = 32'h41200000;
    	mem[32] = 32'h41A00000;
    	mem[127] = 32'h40A00000;    	
    	mem[6400] = 32'h42100000;
        mem[6527] = 32'h40800000;
        mem[8064] = 32'h42C80000;
        mem[8191] = 32'h40000000;
    //B
        mem[8192] = 32'h40400000;
        mem[8319] = 32'h41000000;
     	mem[9420] = 32'h42780000;	 
    	mem[16256] = 32'h41200000;
    	mem[16290] = 32'h40E00000;
    	mem[16383] = 32'h40400000;
    end // initial

    always @(posedge clk) begin
        bram_rddata <= mem[bram_addr[15:2]];
        if (bram_we == 4'hf)
            mem[bram_addr[15:2]] <= bram_wrdata;
        else if (bram_we != 0)
            $display("ERROR: Memory simulation model only implemented we = 0 and we=4'hf. Simulation will be incorrect.");              
    end
endmodule // memory_sim


module memory_sim_x(
    input         clk,
    input         reset,
    input        [11:0] bram_addr,
    output logic [31:0] bram_rddata,
    input        [31:0] bram_wrdata,
    input         [3:0] bram_we);

    logic [31:0] mem [1023:0];

    initial begin
        integer i;
        for (i=0; i<(2**10)-1; i=i+1)
           mem[i] = 32'h3F800000; //value 1 (float)

        
    end // initial

    always @(posedge clk) begin
        bram_rddata <= mem[bram_addr[11:2]];
        if (bram_we == 4'hf)
            mem[bram_addr[11:2]] <= bram_wrdata;
        else if (bram_we != 0)
            $display("ERROR: Memory simulation model only implemented we = 0 and we=4'hf. Simulation will be incorrect.");              
    end
endmodule // memory_sim

module memory_sim_y(
    input         clk,
    input         reset,
    input        [11:0] bram_addr,
    output logic [31:0] bram_rddata,
    input        [31:0] bram_wrdata,
    input         [3:0] bram_we);

    logic [31:0] mem [1023:0];

    initial begin
        integer i;
        for (i=0; i<(2**10)-1; i=i+1)
            mem[i] = 0;
        
    end // initial

    always @(posedge clk) begin
        bram_rddata <= mem[bram_addr[11:2]];
        if (bram_we == 4'hf)
            mem[bram_addr[11:2]] <= bram_wrdata;
        else if (bram_we != 0)
            $display("ERROR: Memory simulation model only implemented we = 0 and we=4'hf. Simulation will be incorrect.");              
    end
endmodule // memory_sim