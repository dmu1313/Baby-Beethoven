
module hadamard
#(
    FP_WIDTH = 32,
    BRAM_WIDTH = 32,
    WORD_BYTES = 4,
    ADDR_WIDTH = 12
)
(
    input clk,
    input reset,
    
    input  [31:0] ps_control,
    output [31:0] pl_status,
    
    output [ADDR_WIDTH-1:0] bram_addr_a,
    input  [BRAM_WIDTH-1:0] bram_rddata_a,
    output [BRAM_WIDTH-1:0] bram_wrdata_a,
    output [WORD_BYTES-1:0] bram_we_a,
    
    output [ADDR_WIDTH-1:0] bram_addr_b,
    input  [BRAM_WIDTH-1:0] bram_rddata_b,
    output [BRAM_WIDTH-1:0] bram_wrdata_b,
    output [WORD_BYTES-1:0] bram_we_b,
    
    output [ADDR_WIDTH-1:0] bram_addr_product,
    input  [BRAM_WIDTH-1:0] bram_rddata_product,
    output [BRAM_WIDTH-1:0] bram_wrdata_product,
    output [WORD_BYTES-1:0] bram_we_product,
    output mult_out_valid
);
    logic doneA, doneB;
    logic incA, incB;
    logic clearA, clearB;
    logic first_half;
    
    assign bram_we_a = 0;
    assign bram_we_b = 0;
    assign bram_wrdata_a = 32'bxxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx;
    assign bram_wrdata_b = 32'bxxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx;

    had_datapath d(
        .clk,
        .reset,
        
        .bram_addr_a,
        .bram_rddata_a,
        
        .bram_addr_b,
        .bram_rddata_b,
                
        .bram_addr_product,
        .bram_wrdata_product,
        
        .doneA,
        .doneB,
        .first_half,
            
        .incA,
        .incB,
        .clearA,
        .clearB,
        
        .mult_out_valid
    );
    
    had_control c(
        .clk,
        .reset,
        
        .ps_control,
        .pl_status,
        
        .bram_we_product,
        
        .doneA,
        .doneB,
        .first_half,
        
        .incA,
        .incB,
        .clearA,
        .clearB
    );
endmodule

module had_datapath
#(
    FP_WIDTH = 32,
    BRAM_WIDTH = 32,
    WORD_BYTES = 4,
    ADDR_WIDTH = 12
)
(
    input clk,
    input reset,
    
    output [ADDR_WIDTH-1:0] bram_addr_a,
    input  [BRAM_WIDTH-1:0] bram_rddata_a,
    
    output [ADDR_WIDTH-1:0] bram_addr_b,
    input  [BRAM_WIDTH-1:0] bram_rddata_b,
    
    output [ADDR_WIDTH-1:0] bram_addr_product,
    output [BRAM_WIDTH-1:0] bram_wrdata_product,
    
    output doneA,
    output doneB,
    input first_half,
    
    input incA,
    input incB,
    input clearA,
    input clearB,
    
    output mult_out_valid
);
    logic [ADDR_WIDTH-1:0]  counterA;
    logic [ADDR_WIDTH-1:0]  counterB;
    logic [ADDR_WIDTH-1:0]  addr;
    logic [FP_WIDTH-1:0]    mult_out;
//    logic mult_out_valid;
    logic [ADDR_WIDTH-1:0] wr_addr;
    
    assign doneA = counterA == 2044;
    assign doneB = counterB == 4092;
    
    assign addr = first_half ? counterA : counterB;
    assign bram_addr_a = addr;
    assign bram_addr_b = addr;

    assign bram_addr_product = wr_addr;
    assign bram_wrdata_product = mult_out;

//    assign mult_out = bram_rddata_a * bram_rddata_b;
    had_fp_mult your_instance_name (
      .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
      .s_axis_a_tdata(bram_rddata_a),              // input wire [31 : 0] s_axis_a_tdata
      .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
      .s_axis_b_tdata(bram_rddata_b),              // input wire [31 : 0] s_axis_b_tdata
      .m_axis_result_tvalid(mult_out_valid),  // output wire m_axis_result_tvalid
      .m_axis_result_tdata(mult_out)    // output wire [31 : 0] m_axis_result_tdata
    );
    
    always_ff @(posedge clk) begin
        if (reset)
            wr_addr <= 0;
        else
            wr_addr <= addr;
    
        if (clearA)
            counterA <= 0;
        else if (incA)
            counterA <= counterA + 4;
        
        if (clearB)
            counterB <= 2048;
        else if (incB)
            counterB <= counterB + 4;
    end

endmodule

typedef enum bit[3:0] {
    WAIT_TO_START   = 0,
    START_A         = 1,
    LOOP_A          = 2,
    DONE_A          = 3,
    START_B         = 4,
    LOOP_B          = 5,
    DONE_B          = 6
} hadamard_states;

module had_control
#(
    BRAM_WIDTH = 32,
    WORD_BYTES = 4,
    ADDR_WIDTH = 12
)
(
    input clk,
    input reset,
    
    input  [31:0] ps_control,
    output [31:0] pl_status,
    
    output [WORD_BYTES-1:0] bram_we_product,
    
    input  doneA,
    input  doneB,
    output first_half,
    
    output incA,
    output incB,
    output clearA,
    output clearB
);
    logic [3:0] state;
    logic [3:0] next_state;
    logic completedA, completedB;
    
    assign pl_status[0] = completedA;
    assign pl_status[1] = completedB;
    
    assign incA = state == START_A || state == LOOP_A;
    assign incB = state == START_B || state == LOOP_B;
    
    assign clearA = state == WAIT_TO_START;
    assign clearB = state == WAIT_TO_START;

    assign first_half = (state == START_A || state == LOOP_A || state == DONE_A) ? 1 : 0;
    
    assign bram_we_product = (state == LOOP_A || state == DONE_A || state == LOOP_B || state == DONE_B) ? 4'b1111 : 4'b0000;

    always_ff @(posedge clk) begin
        if (reset)
            completedA <= 0;
        else if (state == DONE_A)
            completedA <= 1;
        else if (completedA == 1 && ps_control[0] == 0)
            completedA <= 0;
            
        if (reset)
            completedB <= 0;
        else if (state == DONE_B)
            completedB <= 1;
        else if (completedB == 1 && ps_control[1] == 0)
            completedB <= 0;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= WAIT_TO_START;
        end
        else begin
            state <= next_state;
        end
    end

    always_comb begin
        if (state == WAIT_TO_START) begin
            if (ps_control[0] && completedA == 0)
                next_state = START_A;
            else if (ps_control[1] && completedB == 0)
                next_state = START_B;
            else
                next_state = WAIT_TO_START;
        end
        
        else if (state == START_A) begin
            next_state = LOOP_A;
        end
        else if (state == LOOP_A) begin
            if (doneA)
                next_state = DONE_A;
            else
                next_state = LOOP_A;
        end
        else if (state == DONE_A) begin
            next_state = WAIT_TO_START;
        end
        
        else if (state == START_B) begin
            next_state = LOOP_B;
        end
        else if (state == LOOP_B) begin
            if (doneB)
                next_state = DONE_B;
            else
                next_state = LOOP_B;
        end
        else if (state == DONE_B) begin
            next_state = WAIT_TO_START;
        end        
    end
endmodule
