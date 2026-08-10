import cache_pkg::*;

module ECC_tb;

    //------------------------------------------------------------------------------
    // ECC full encoder/decoder testbench
    //
    // Verifies the complete ECC encoding and decoding path independently from
    // the cache controller and cache SRAM.
    //
    // The testbench checks:
    //   - ECC encoding of cache lines
    //   - Decoding of valid ECC-protected cache lines
    //   - Correction of injected data errors
    //   - Correction/rejection behavior for corrupted redundancy bits
    //
    // The ECC encoder and decoder are combinational, therefore no clock is
    // required for these tests. A small simulation delay is used after applying
    // the inputs to allow combinational signals to propagate.
    //------------------------------------------------------------------------------

    // inout encoder
    data_cache_t     data_cache_e;
    data_cache_ecc_t data_cache_ecc_e;

    // inout decoder
    data_cache_ecc_t data_cache_ecc_d;
    data_cache_t     data_cache_d;

    // DUT encoder
    ECC_full_encoder dut_enc (
        .data_cache     (data_cache_e),
        .data_cache_ecc (data_cache_ecc_e)
    );

    // DUT decoder
    ECC_full_decoder dut_dec (
        .data_cache_ecc (data_cache_ecc_d),
        .data_cache     (data_cache_d)
    );


    // print task
    task display_state(input string label);
        $display("[%0t] %-22s | data_cache_e=%h data_cache_ecc_e=%h data_cache_d=%h data_cache_ecc_d=%h",
            $time, label, data_cache_e, data_cache_ecc_e, data_cache_d, data_cache_ecc_d);
    endtask


    data_cache_ecc_t data_cache_ecc_e_test;
    data_cache_t     data_cache_d_test;


    initial begin
        #1;

        //--------------------------------------------------------------------------
        // TEST 1 : ECC encoding
        //
        // Verify that the ECC full encoder correctly converts a cache line into
        // its ECC-protected representation.
        //
        // The tag, valid bit and original data fields must be preserved, while
        // the redundancy fields must match the expected ECC values.
        //--------------------------------------------------------------------------
        $display("\n=== TEST 1: ECC encoding ===");

        // Test input cache line
        data_cache_e.tag   = 4'b1010;
        data_cache_e.valid = 1'b1;
        data_cache_e.data1 = 8'hCC;
        data_cache_e.data2 = 8'hDD;
        #1;

        // Expected ECC-protected cache line
        data_cache_ecc_e_test.tag    = 4'b1010;
        data_cache_ecc_e_test.valid  = 1'b1;
        data_cache_ecc_e_test.data1  = 8'hCC;
        data_cache_ecc_e_test.redun1 = 8'hC1;
        data_cache_ecc_e_test.data2  = 8'hDD;
        data_cache_ecc_e_test.redun2 = 8'h9F;


        display_state("ECC encoding");
        assert (data_cache_ecc_e == data_cache_ecc_e_test) else $error("TEST_1 FAIL: incorrect encoded output");
        $display(" data_cache_ecc_e=%h : %s", data_cache_ecc_e, data_cache_ecc_e == data_cache_ecc_e_test ? "PASS" : "FAIL");
    
        //--------------------------------------------------------------------------
        // TEST 2 : ECC decoding - single-bit error
        //
        // Verify that the ECC full decoder can recover the original data when
        // a single-bit error is introduced in the stored cache line.
        //
        // The error is injected into data1 by modifying one bit of the encoded
        // data. The decoder must detect the inconsistency between the data and
        // its redundancy and recover the original value.
        //--------------------------------------------------------------------------
        $display("\n=== TEST 2: ECC decoding - single-bit error ===");

        // Test output cache line
        data_cache_ecc_d.tag    = 4'b1010;
        data_cache_ecc_d.valid  = 1'b1;
        data_cache_ecc_d.data1  = 8'hDF;   // Correct: 8'hDD -> corrupted: 8'hDF (1 bit flipped)
        data_cache_ecc_d.redun1 = 8'h9F;
        data_cache_ecc_d.data2  = 8'hDF;
        data_cache_ecc_d.redun2 = 8'h9F;

        #1;
        // Display internal decoder signals to observe error detection and
        // the relative Hamming weights used by the correction logic.
        $display("data_in_1    = %h", dut_dec.data_in_1);
        $display("redun_in_1   = %h", dut_dec.redun_in_1);
        $display("data_out_1   = %h", dut_dec.data_out_1);
        $display("redun_out_1  = %h", dut_dec.redun_out_1);
        $display("syndrome_data1  = %h  weight = %0d", dut_dec.syndrome_data1, dut_dec.weight_data1);
        $display("syndrome_redun1 = %h  weight = %0d", dut_dec.syndrome_redun1, dut_dec.weight_redundancy1);

        // Expected decoded cache line after error correction
        data_cache_d_test.tag   = 4'b1010;
        data_cache_d_test.valid = 1'b1;
        data_cache_d_test.data1 = 8'hDD;
        data_cache_d_test.data2 = 8'hDD;

        display_state("ECC decoding - single-bit error");
        assert (data_cache_d == data_cache_d_test) else $error("TEST_2 FAIL: incorrect decoded output");
        $display(" data_cache_d=%h : %s", data_cache_d, data_cache_d == data_cache_d_test ? "PASS" : "FAIL");


        //--------------------------------------------------------------------------
        // TEST 3 : ECC decoding - redundancy error
        //
        // Verify that the decoder correctly handles an error affecting the
        // redundancy field instead of the data field.
        //
        // The data2 redundancy is corrupted by flipping two adjacent bits.
        // The decoder must determine that the original data is still the most
        // reliable representation and preserve the correct data value.
        //--------------------------------------------------------------------------
        $display("\n=== TEST 3: ECC decoding - redundancy error ===");

        data_cache_ecc_d.tag    = 4'b1010;
        data_cache_ecc_d.valid  = 1'b1;
        data_cache_ecc_d.data1  = 8'hAC;
        data_cache_ecc_d.redun1 = 8'h6C;
        data_cache_ecc_d.data2  = 8'hD6;
        data_cache_ecc_d.redun2 = 8'h3A;   // Correct: 8'hFA -> corrupted: 8'h3A (2 bits flipped)

        #1;


        // Display internal decoder signals to verify that the corrupted
        // redundancy is identified as less reliable than the data.
        $display("data_in_1    = %h", dut_dec.data_in_1);
        $display("redun_in_1   = %h", dut_dec.redun_in_1);
        $display("data_out_1   = %h", dut_dec.data_out_1);
        $display("redun_out_1  = %h", dut_dec.redun_out_1);
        $display("syndrome_data1  = %h  weight = %0d", dut_dec.syndrome_data1, dut_dec.weight_data1);
        $display("syndrome_redun1 = %h  weight = %0d", dut_dec.syndrome_redun1, dut_dec.weight_redundancy1);

        // Expected decoded cache line
        data_cache_d_test.tag   = 4'b1010;
        data_cache_d_test.valid = 1'b1;
        data_cache_d_test.data1 = 8'hAC;
        data_cache_d_test.data2 = 8'hD6;

        display_state("ECC decoding - redundancy error");
        assert (data_cache_d == data_cache_d_test) else $error("TEST_2 FAIL: incorrect decoded output");
        $display(" data_cache_d=%h : %s", data_cache_d, data_cache_d == data_cache_d_test ? "PASS" : "FAIL");


        //--------------------------------------------------------------------------
        // TEST 4 : ECC decoding - multiple-bit error
        //
        // Verify the decoder behavior when several bits of the redundancy field
        // are corrupted.
        //
        // Six bits are flipped in redun1. The decoder compares the
        // Hamming weights of the data and redundancy syndromes to determine which
        // representation is more reliable.
        //--------------------------------------------------------------------------
        $display("\n=== TEST 4: ECC decoding - multiple-bit error ===");

        data_cache_ecc_d.tag    = 4'b1010;
        data_cache_ecc_d.valid  = 1'b1;
        data_cache_ecc_d.data1  = 8'h2E;
        data_cache_ecc_d.redun1 = 8'hCB;   // Correct: 8'h33 -> corrupted: 8'hCB (6 bits flipped)
        data_cache_ecc_d.data2  = 8'hAC;
        data_cache_ecc_d.redun2 = 8'h6C;

        #1;
        // Display internal decoder signals to observe the effect of the
        // multiple-bit error on the calculated syndromes.
        $display("data_in_1    = %h", dut_dec.data_in_1);
        $display("redun_in_1   = %h", dut_dec.redun_in_1);
        $display("data_out_1   = %h", dut_dec.data_out_1);
        $display("redun_out_1  = %h", dut_dec.redun_out_1);
        $display("syndrome_data1  = %h  weight = %0d", dut_dec.syndrome_data1, dut_dec.weight_data1);
        $display("syndrome_redun1 = %h  weight = %0d", dut_dec.syndrome_redun1, dut_dec.weight_redundancy1);

        // Expected decoded cache line
        data_cache_d_test.tag   = 4'b1010;
        data_cache_d_test.valid = 1'b1;
        data_cache_d_test.data1 = 8'h2E;
        data_cache_d_test.data2 = 8'hAC;

        display_state("ECC decoding - redundancy error");
        assert (data_cache_d == data_cache_d_test) else $error("TEST_2 FAIL: out false");
        $display(" data_cache_d=%h : %s", data_cache_d, data_cache_d == data_cache_d_test ? "PASS" : "FAIL");

        $display("\n=== Simulation completed ===");
        $finish;
    end

endmodule