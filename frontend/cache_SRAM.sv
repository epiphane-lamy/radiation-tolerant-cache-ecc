import cache_pkg::*;

module cache_SRAM (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       we_cache,
    input  logic [2:0] addr_cache,
    input  logic       way_select,
    input  data_cache_ecc_t data_in,

    output data_cache_ecc_t data_out1,
    output data_cache_ecc_t data_out2
    );

    //------------------------------------------------------------------------------
    // Cache SRAM
    //
    // Stores the ECC-protected cache lines of the 2-way set-associative cache.
    //
    // The cache contains 8 sets and 2 ways per set. Each entry stores one complete
    // ECC-protected cache line.
    //
    // Cache accesses are synchronous. The read address is registered so that the
    // cache data is available with a one-cycle read latency.
    //
    // Valid bits are stored separately from the cache data so that they can be
    // reset independently.
    //------------------------------------------------------------------------------
    
    data_cache_ecc_t cache [0:7][0:1];

    // Separate resettable storage for the valid bits
    logic valid_array [0:7][0:1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 8; i++) begin
                valid_array[i][0] <= 1'b0;
                valid_array[i][1] <= 1'b0;
            end
        end else begin
            if (we_cache)
                valid_array[addr_cache][way_select] <= data_in.valid;
        end
    end

    data_cache_ecc_t data_out1_raw, data_out2_raw;
    logic [2:0] addr_cache_reg;

    always_ff @(posedge clk) begin
        // Register the read address to match the cache read latency
        addr_cache_reg <= addr_cache;
        data_out1_raw  <= cache[addr_cache][0];
        data_out2_raw  <= cache[addr_cache][1];
        if (we_cache)
            cache[addr_cache][way_select] <= data_in;
    end

    // Combine the stored cache data with the corresponding valid bits
    always_comb begin
        data_out1       = data_out1_raw;
        data_out1.valid = valid_array[addr_cache_reg][0];
        data_out2       = data_out2_raw;
        data_out2.valid = valid_array[addr_cache_reg][1];
    end

endmodule

