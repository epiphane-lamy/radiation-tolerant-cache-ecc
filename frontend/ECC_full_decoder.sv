import cache_pkg::*;

//------------------------------------------------------------------------------
// Full ECC decoder
//
// Decodes and checks a complete ECC-protected cache line.
//
// For each 8-bit data word, the module:
//   1. Decodes the received redundancy bits to reconstruct the data.
//   2. Re-encodes the received data.
//   3. Computes the syndrome by comparing the received and regenerated values.
//   4. Compares the syndrome weights to select the most likely correct data.
//
// The tag and valid bit are preserved unchanged.
//
// The ECC encoder and decoder are instantiated as combinational building
// blocks. This wrapper combines their results to perform the complete
// cache-line decoding and error-correction process.
//------------------------------------------------------------------------------

module ECC_full_decoder (
    input  data_cache_ecc_t data_cache_ecc,
    output data_cache_t     data_cache
    );

    logic [7:0] data_in_1;
    logic [7:0] data_in_2;

    logic [7:0] redun_in_1;
    logic [7:0] redun_in_2;

    logic [7:0] data_out_1;
    logic [7:0] data_out_2;

    logic [7:0] redun_out_1;
    logic [7:0] redun_out_2;

    ECC_encoder u_encoder (
        .data1  (data_in_1),
        .data2  (data_in_2),
        .redun1 (redun_out_1),
        .redun2 (redun_out_2)
    );
        
    ECC_decoder u_decoder (
        .redun1 (redun_in_1),
        .redun2 (redun_in_2),
        .data1  (data_out_1),
        .data2  (data_out_2)
    );


    assign data_in_1  = data_cache_ecc.data1;
    assign redun_in_1 = data_cache_ecc.redun1;
    assign data_in_2  = data_cache_ecc.data2;
    assign redun_in_2 = data_cache_ecc.redun2;

    logic [7:0] syndrome_data1;
    logic [7:0] syndrome_redun1;
    logic [7:0] syndrome_data2;
    logic [7:0] syndrome_redun2;

    assign syndrome_data1  = data_in_1  ^ data_out_1;
    assign syndrome_redun1 = redun_in_1 ^ redun_out_1;

    assign syndrome_data2  = data_in_2  ^ data_out_2;
    assign syndrome_redun2 = redun_in_2 ^ redun_out_2;

    logic [3:0] weight_data1;
    logic [3:0] weight_redundancy1;
    logic [3:0] weight_data2;
    logic [3:0] weight_redundancy2;

    assign weight_data1       = $countones(syndrome_data1);
    assign weight_redundancy1 = $countones(syndrome_redun1);

    assign weight_data2       = $countones(syndrome_data2);
    assign weight_redundancy2 = $countones(syndrome_redun2);

    // Select the decoded value when the syndrome indicates that it is more
    // likely to be correct than the received data.
    always_comb begin
        data_cache.tag   = data_cache_ecc.tag;
        data_cache.valid = data_cache_ecc.valid;

        data_cache.data1 = (weight_data1 < weight_redundancy1) ? data_out_1 : data_in_1;
        data_cache.data2 = (weight_data2 < weight_redundancy2) ? data_out_2 : data_in_2;

    end


endmodule
