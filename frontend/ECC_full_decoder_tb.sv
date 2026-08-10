import cache_pkg::*;

//------------------------------------------------------------------------------
// ECC full decoder verification testbench
//
// This testbench evaluates the error-correction capability of the
// ECC_full_decoder independently from the cache controller and memory.
//
// Test vectors are read from "vector.txt". Each vector contains:
//   - a corrupted data field
//   - the corresponding redundancy field
//   - the expected original data
//   - the number of injected bit errors
//   - the error type (random or burst)
//
// The testbench classifies the results according to:
//   - 1 to 4 random bit errors
//   - 1 to 4 burst bit errors
//
// For each category, the number and percentage of correctly recovered
// data values are reported.
//
// The objective is to evaluate the decoder's correction accuracy for
// different error patterns and error multiplicities.
//------------------------------------------------------------------------------

module ECC_full_decoder_tb;

    // inout decoder
    data_cache_ecc_t data_cache_ecc;
    data_cache_t     data_cache;

    int fd, exp, nb_err, burst;

    //------------------------------------------------------------------------------
    // Test statistics
    //
    // Index mapping:
    //   0..3 : 1..4 random errors
    //   4..7 : 1..4 burst errors
    //------------------------------------------------------------------------------
    int tab_correct[8];
    int tab_total[8];


    //------------------------------------------------------------------------------
    // DUT decoder
    //
    // The decoder is tested independently by directly applying corrupted
    // ECC-protected data and checking the recovered data against the expected
    // original value.
    //------------------------------------------------------------------------------
    ECC_full_decoder dut_dec (
        .data_cache_ecc (data_cache_ecc),
        .data_cache     (data_cache)
    );


    initial begin
        // Initialize unused fields.
        // Only data1 and redun1 are modified by the test vectors.
        int idx;

        data_cache_ecc.tag    = '0;
        data_cache_ecc.valid  = 1'b0;
        data_cache_ecc.data2  = '0;
        data_cache_ecc.redun2 = '0;

        // Initialize correction statistics.
        foreach (tab_correct[i]) tab_correct[i] = 0;
        foreach (tab_total[i])   tab_total[i]   = 0;

        // Open the generated test vectors containing corrupted ECC data.
        fd = $fopen("vector.txt", "r");
        if (fd == 0) begin
            $display("ERREUR: impossible d'ouvrir vector.txt");
            $finish;
        end

        // Read one test vector:
        //   data1_corrupted, redundancy, expected_data, number_of_errors, error_type
        while (!$feof(fd)) begin
            if ($fscanf(fd, "%d %d %d %d %d\n",
                    data_cache_ecc.data1, data_cache_ecc.redun1, exp, nb_err, burst) == 5) begin

                #1;

                // Classify the result:
                //   0..3 -> 1..4 random errors
                //   4..7 -> 1..4 burst errors
                idx = (nb_err - 1) + 4 * burst;
                tab_total[idx]++;
                // A vector is considered successfully corrected when the
                // decoder output matches the expected original data.
                if (data_cache.data1 == exp) tab_correct[idx]++;
            end
        end
        $fclose(fd);

        // Report the correction accuracy for each error category
        $display("=== Correction rate ===\n");
        $display("1 erreur  aleatoire : %0d / %0d (%.2f %%)", tab_correct[0], tab_total[0], (tab_total[0] > 0) ? 100.0*tab_correct[0]/tab_total[0] : 0.0);
        $display("2 erreurs aleatoire : %0d / %0d (%.2f %%)", tab_correct[1], tab_total[1], (tab_total[1] > 0) ? 100.0*tab_correct[1]/tab_total[1] : 0.0);
        $display("3 erreurs aleatoire : %0d / %0d (%.2f %%)", tab_correct[2], tab_total[2], (tab_total[2] > 0) ? 100.0*tab_correct[2]/tab_total[2] : 0.0);
        $display("4 erreurs aleatoire : %0d / %0d (%.2f %%)", tab_correct[3], tab_total[3], (tab_total[3] > 0) ? 100.0*tab_correct[3]/tab_total[3] : 0.0);
        $display("1 erreur  burst     : %0d / %0d (%.2f %%)", tab_correct[4], tab_total[4], (tab_total[4] > 0) ? 100.0*tab_correct[4]/tab_total[4] : 0.0);
        $display("2 erreurs burst     : %0d / %0d (%.2f %%)", tab_correct[5], tab_total[5], (tab_total[5] > 0) ? 100.0*tab_correct[5]/tab_total[5] : 0.0);
        $display("3 erreurs burst     : %0d / %0d (%.2f %%)", tab_correct[6], tab_total[6], (tab_total[6] > 0) ? 100.0*tab_correct[6]/tab_total[6] : 0.0);
        $display("4 erreurs burst     : %0d / %0d (%.2f %%)", tab_correct[7], tab_total[7], (tab_total[7] > 0) ? 100.0*tab_correct[7]/tab_total[7] : 0.0);


        
        $display("\n=== Simulation completed ===");
        $finish;
    end

endmodule