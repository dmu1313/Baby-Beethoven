
module hadamard
#(
    FP_WIDTH = 32,
    BRAM_WIDTH = 32,
    WORD_BYTES = 4,
    ADDR_WIDTH = 12,
    NUM_WORDS = 512,
    P = 1
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
    logic doneA;
    logic incA;
    logic clearA;
    
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

        .incA,
        .clearA,
        
        .mult_out_valid
    );
    
    had_control c(
        .clk,
        .reset,
        
        .ps_control,
        .pl_status,
        
        .bram_we_product,
        
        .doneA,
        
        .incA,
        .clearA
    );
endmodule

module had_datapath
#(
    FP_WIDTH = 32,
    BRAM_WIDTH = 32,
    WORD_BYTES = 4,
    ADDR_WIDTH = 12,
    NUM_WORDS = 512
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
    
    input incA,
    input clearA,
    
    output mult_out_valid
);
    logic [ADDR_WIDTH-1:0]  counterA;
    logic [ADDR_WIDTH-1:0]  addr;
    logic [FP_WIDTH-1:0]    mult_out;
//    logic mult_out_valid;
    logic [ADDR_WIDTH-1:0] wr_addr;
    
    assign doneA = counterA == ((NUM_WORDS - 1) * WORD_BYTES);
    
    assign addr = counterA;
    assign bram_addr_a = addr;
    assign bram_addr_b = addr;

    assign bram_addr_product = wr_addr;
    assign bram_wrdata_product = mult_out;

//    assign mult_out = bram_rddata_a * bram_rddata_b;
    had_fp_mult fp_mult (
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
    end

endmodule

typedef enum bit[3:0] {
    WAIT_TO_START   = 0,
    START_A         = 1,
    LOOP_A          = 2,
    DONE_A          = 3,
    WAIT_FOR_ACKNOW = 4,
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
    
    output incA,
    output clearA
);
    logic [3:0] state;
    logic [3:0] next_state;
    
    assign pl_status[0] = state == WAIT_FOR_ACKNOW;
    assign incA = state == START_A || state == LOOP_A;
    assign clearA = state == WAIT_TO_START;
    
    assign bram_we_product = (state == LOOP_A || state == DONE_A) ? 4'b1111 : 4'b0000;

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
            if (ps_control[0] == 1)
                next_state = START_A;
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
            next_state = WAIT_FOR_ACKNOW;
        end
        else if (state == WAIT_FOR_ACKNOW) begin
            if (ps_control[0] == 0)
                next_state = WAIT_TO_START;
            else
                next_state = WAIT_FOR_ACKNOW;
        end
        else begin
            next_state = WAIT_TO_START;
        end
    end
endmodule
