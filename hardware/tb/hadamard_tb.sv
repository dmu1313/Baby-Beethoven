`timescale 1ns / 1ps

module hadamard_tb
#(
    BRAM_WIDTH = 32,
    WORD_BYTES = 4,
    ADDR_WIDTH = 12
)();
    logic executing;

    logic clk;
    logic reset;
    logic [31:0] ps_control, pl_status;

    logic [ADDR_WIDTH-1:0] addr_a, addr_b, addr_product;
    logic [BRAM_WIDTH-1:0] rddata_a, rddata_b, rddata_product;
    logic [BRAM_WIDTH-1:0] wrdata_a, wrdata_b, wrdata_product;
    logic [WORD_BYTES-1:0] we_a, we_b, we_product;

    bram a0 #(
        .BRAM_WIDTH(BRAM_WIDTH), .BRAM_SIZE(4096), .WORD_SIZE(WORD_BYTES), .ADDR_WIDTH(ADDR_WIDTH)
    ) (
        .clk, .reset,
        .bram_addr(addr_a), .bram_rddata(rddata_a),
        .bram_wrdata(wrdata_a), .bram_we(we_a)
    );

    bram b0 #(
        .BRAM_WIDTH(BRAM_WIDTH), .BRAM_SIZE(4096), .WORD_SIZE(WORD_BYTES), .ADDR_WIDTH(ADDR_WIDTH)
    ) (
        .clk, .reset,
        .bram_addr(addr_b), .bram_rddata(rddata_b),
        .bram_wrdata(wrdata_b), .bram_we(we_b)
    );

    bram product #(
        .BRAM_WIDTH(BRAM_WIDTH), .BRAM_SIZE(4096), .WORD_SIZE(WORD_BYTES), .ADDR_WIDTH(ADDR_WIDTH)
    ) (
        .clk, .reset,
        .bram_addr(addr_product), .bram_rddata(rddata_product),
        .bram_wrdata(wrdata_product), .bram_we(we_product)
    );

    hadamard h0
    #(
        .BRAM_WIDTH(BRAM_WIDTH),
        .WORD_BYTES(WORD_BYTES),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) (
        .clk, .reset,
        .ps_control, .pl_status,
        
        .bram_addr_a(addr_a),
        .bram_rddata_a(rddata_a),
        .bram_wrdata_a(wrdata_a),
        .bram_we_a(we_a),
        
        .bram_addr_b(addr_b),
        .bram_rddata_b(rddata_b),
        .bram_wrdata_b(wrdata_b),
        .bram_we_b(we_b),
        
        .bram_addr_product(addr_product),
        .bram_rddata_product(rddata_product),
        .bram_wrdata_product(wrdata_product),
        .bram_we_product(we_product)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        ps_control = 0;
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        #1; reset0;
        @(posedge clk);

        // fill bram a0
        for (int i=0; i < 2**ADDR_WIDTH-1; i=i+1) begin
            wrdata_a = 2;
            addr_a = i * 4;
            we_a = 4'b1111;
            @(posedge clk);
        end

        // fill bram b0
        for (int i=0; i < 2**ADDR_WIDTH-1; i=i+1) begin
            wrdata_b = 3;
            addr_b = i * 4;
            we_b = 4'b1111;
            @(posedge clk);
        end

        ps_control[0] = 1;
        @(posedge clk);
        @(posedge clk);
        ps_control[1] = 1;
        @(posedge clk);
        @(posedge clk);

        // wait enough cycles for computations to be done
        for (int i=0; i < 1024 + 100; i=i+1) begin
            @(posedge clk);
        end

        





    end

endmodule
