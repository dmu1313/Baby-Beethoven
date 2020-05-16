`timescale 1ns / 1ps

module activation_tb
#(
    BRAM_WIDTH = 32,
    WORD_BYTES = 4,
    ADDR_WIDTH = 12
)();
    logic executing; // Use this to differentiate between when we are loading from PS vs executing on PL
        
    logic clk;
    logic reset;
    logic [31:0] ps_control, pl_status;
    
    // Signals that are actually used by the BRAMs.
    logic [ADDR_WIDTH-1:0] addr_a, addr_product;
    logic [BRAM_WIDTH-1:0] rddata_a, rddata_product;
    logic [BRAM_WIDTH-1:0] wrdata_a, wrdata_product;
    logic [WORD_BYTES-1:0] we_a, we_product;
    
    // Signals that our simulated PS can use to interact with the BRAMs.
    logic [ADDR_WIDTH-1:0] ps_addr_a, ps_addr_product;
    logic [BRAM_WIDTH-1:0] ps_wrdata_a, ps_wrdata_product;
    logic [WORD_BYTES-1:0] ps_we_a, ps_we_product;
    
    // Signals for the PL to use to interact with the BRAMs
    logic [ADDR_WIDTH-1:0] pl_addr_a, pl_addr_product;
    logic [BRAM_WIDTH-1:0] pl_wrdata_a, pl_wrdata_product;
    logic [WORD_BYTES-1:0] pl_we_a, pl_we_product;
    
    // Start Multiplexers /////////////////////////////////////////////////////////
    assign addr_a = executing ? pl_addr_a : ps_addr_a;
    assign addr_product = executing ? pl_addr_product : ps_addr_product;
    
    assign wrdata_a = executing ? pl_wrdata_a : ps_wrdata_a;
    assign wrdata_product = executing ? pl_wrdata_product : ps_wrdata_product;

    assign we_a = executing ? pl_we_a : ps_we_a;
    assign we_product = executing ? pl_we_product : ps_we_product;
    // Stop Multiplexers //////////////////////////////////////////////////////////
    

    bram #(.BRAM_WIDTH(BRAM_WIDTH), .BRAM_SIZE(4096), .WORD_SIZE(WORD_BYTES), .ADDR_WIDTH(ADDR_WIDTH))
    in (
        .clk, .reset,
        .bram_addr(addr_a), .bram_rddata(rddata_a),
        .bram_wrdata(wrdata_a), .bram_we(we_a)
    );

    bram #(.BRAM_WIDTH(BRAM_WIDTH), .BRAM_SIZE(4096), .WORD_SIZE(WORD_BYTES), .ADDR_WIDTH(ADDR_WIDTH))
    out (
        .clk, .reset,
        .bram_addr(addr_product), .bram_rddata(rddata_product),
        .bram_wrdata(wrdata_product), .bram_we(we_product)
    );

    activation act (
        .clk, .reset,
        .ps_control, .pl_status,
        
        .bram_addr_in(pl_addr_a),
        .bram_rddata_in(rddata_a),
        .bram_wrdata_in(pl_wrdata_a),
        .bram_we_in(pl_we_a),

        .bram_addr_out(pl_addr_product),
        .bram_rddata_out(rddata_product),
        .bram_wrdata_out(pl_wrdata_product),
        .bram_we_out(pl_we_product)
    );
    
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        executing = 0;

        ps_wrdata_a = 0;
        ps_wrdata_product = 0;

        ps_addr_a = 0;
        ps_addr_product = 0;
        
        ps_we_a = 0;
        ps_we_product = 0;

        ps_control = 0;
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        #1; reset = 0;
        @(posedge clk);
        @(posedge clk);

        // fill bram a0
        for (int i=0; i < (2**ADDR_WIDTH)/WORD_BYTES; i=i+1) begin
            ps_wrdata_a = 32'h00000000; // floating point test
            ps_addr_a = i * 4;
            ps_we_a = 4'b1111;
            @(posedge clk);
        end
        
        ps_we_a = 0;
        
        executing = 1;

        @(posedge clk);
        @(posedge clk);
        ps_control[0] = 1;
        @(posedge clk);
        @(posedge clk);

        // wait enough cycles for computations to be done
        while (pl_status[0] == 0) begin
            @(posedge clk);
        end

        @(posedge clk);

        ps_control[0] = 0;
        
        executing = 0;
        
        @(posedge clk);
        for (int i=0; i < (2**ADDR_WIDTH)/WORD_BYTES/2; i=i+1) begin
            ps_addr_product = i * 4;
            @(posedge clk);
            $display("rddata_product[%d] = %x", i, rddata_product);
        end
        
        
        // Start 2nd test

        // fill bram a0
//         for (int i=0; i < (2**ADDR_WIDTH)/WORD_BYTES; i=i+1) begin
// //            ps_wrdata_a = 2; // integer test
//             ps_wrdata_a = 32'hc0490fdb; // floating point test
//             ps_addr_a = i * 4;
//             ps_we_a = 4'b1111;
//             @(posedge clk);
//         end
        
        ps_we_a = 0;
        
        executing = 1;
        
        @(posedge clk);
        ps_control[1] = 1;
        while (pl_status[0] == 0)
            @(posedge clk);
        
        ps_control[0] = 0;
        
        executing = 0;
        
        @(posedge clk);

        for (int i=0; i < (2**ADDR_WIDTH)/WORD_BYTES/2; i=i+1) begin
            ps_addr_product = i * 4;
            @(posedge clk);
            $display("rddata_product[%d] = %x", i, rddata_product);
        end
        
        $finish;
        
    end
endmodule
