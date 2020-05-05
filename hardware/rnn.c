/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#define HIDDEN_SIZE     512
#define INPUT_SIZE      1572

// LSTM Layer 0 weights
#include "W_ii_0.h"
#include "b_ii_0.h"
#include "W_hi_0.h"
#include "b_hi_0.h"
#include "W_if_0.h"
#include "b_if_0.h"
#include "W_hf_0.h"
#include "b_hf_0.h"
#include "W_ig_0.h"
#include "b_ig_0.h"
#include "W_hg_0.h"
#include "b_hg_0.h"
#include "W_io_0.h"
#include "b_io_0.h"
#include "W_ho_0.h"
#include "b_ho_0.h"

// LSTM Layer 1 weights
#include "W_ii_1.h"
#include "b_ii_1.h"
#include "W_hi_1.h"
#include "b_hi_1.h"
#include "W_if_1.h"
#include "b_if_1.h"
#include "W_hf_1.h"
#include "b_hf_1.h"
#include "W_ig_1.h"
#include "b_ig_1.h"
#include "W_hg_1.h"
#include "b_hg_1.h"
#include "W_io_1.h"
#include "b_io_1.h"
#include "W_ho_1.h"
#include "b_ho_1.h"

// FC Layer weights
#include "fc1_weight.h"
#include "fc1_bias.h"

#define NUM_LSTM_LAYERS 2
#define GENERATED_SONG_LENGTH 80
#define SEQUENCE_LENGTH 85

// int inputs[SEQUENCE_LENGTH][] = {

// };
#include "inputs.h"

#include <stdio.h>
#include <math.h>

#include "platform.h"
#include "xil_printf.h"
// #include "xtmrctr.h"  // timer

// #define TIMER_BASE 0x42800000   // change to match base address of your AXI timer if necessary
// #define TIMER_FREQ 				XPAR_TMRCTR_0_CLOCK_FREQ_HZ
// #define TMRCTR_DEVICE_ID        XPAR_TMRCTR_0_DEVICE_ID


float sigmoid(float x) {
    return 1.0 / (1.0 + exp(-x))
}

void setup_weight_arrays(float** W_ii[2], float** W_if[2], float** W_ig[2], float** W_io[2],
                         float** W_hi[2], float** W_hf[2], float** W_hg[2], float** W_ho[2],
                         float* b_ii[2], float* b_if[2], float* b_ig[2], float* b_io[2],
                         float* b_hi[2], float* b_hf[2], float* b_hg[2], float* b_ho[2]
                        );
void fc_calc(float lstm_output[HIDDEN_SIZE], float fc_results[INPUT_SIZE]);
int log_softmax(float fc_results[INPUT_SIZE]);

int main()
{
    init_platform();
    printf("-------------- Starting Test ------------\n\r");

    // Pointers to our BRAM and the control interface of our custom hardware (hw)
    int FIRST_HALF_BASE = 0;
    int SECOND_HALF_BASE = 512;
    volatile float* bram_had_a = XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR;
    volatile float* bram_had_b = XPAR_AXI_BRAM_CTRL_1_S_AXI_BASEADDR;
    volatile float* bram_had_product = XPAR_AXI_BRAM_CTRL_2_S_AXI_BASEADDR;
    
    // volatile unsigned int* hw = (unsigned int*)XPAR_BRAM_MULT_ACC_0_S00_AXI_BASEADDR;
    volatile unsigned int* hadamard_hw = (unsigned int*)XPAR_BRAM_HADAMARD_0_S00_AXI_BASEADDR;

    // Combine weights of different LSTM layers into 1 array.
    float** W_ii[NUM_LSTM_LAYERS];
    float** W_if[NUM_LSTM_LAYERS];
    float** W_ig[NUM_LSTM_LAYERS];
    float** W_io[NUM_LSTM_LAYERS];

    float** W_hi[NUM_LSTM_LAYERS];
    float** W_hf[NUM_LSTM_LAYERS];
    float** W_hg[NUM_LSTM_LAYERS];
    float** W_ho[NUM_LSTM_LAYERS];

    float* b_ii[NUM_LSTM_LAYERS];
    float* b_if[NUM_LSTM_LAYERS];
    float* b_ig[NUM_LSTM_LAYERS];
    float* b_io[NUM_LSTM_LAYERS];

    float* b_hi[NUM_LSTM_LAYERS];
    float* b_hf[NUM_LSTM_LAYERS];
    float* b_hg[NUM_LSTM_LAYERS];
    float* b_ho[NUM_LSTM_LAYERS];
    
    setup_weight_arrays(W_ii, W_if, W_ig, W_io,
                         W_hi, W_hf, W_hg, W_ho,
                         b_ii, b_if, b_ig, b_io,
                         b_hi, b_hf, b_hg, b_ho
                        );

    for (int noteNum = 0; noteNum < GENERATED_SONG_LENGTH; noteNum++) {
        // Do calculations for LSTM layers
        for (int layer = 0; layer < NUM_LSTM_LAYERS; layer++) {
            float hidden_state[HIDDEN_SIZE];
            float cell_state[HIDDEN_SIZE];
            for (int i = 0; i < HIDDEN_SIZE; i++) hidden_state[i] = 0;
            for (int i = 0; i < HIDDEN_SIZE; i++) cell_state[i] = 0;

            for (int t = 0; t < SEQUENCE_LENGTH; t++) {
                // Calculate i_t
                float i_t[HIDDEN_SIZE];
                for (int i = 0; i < HIDDEN_SIZE; i++) i_t[i] = 0;
                
                for (int i = 0; i < HIDDEN_SIZE; i++) {
                    for (int j = 0; j < INPUT_SIZE; j++) {
                        i_t += W_ii[layer][i][j] * inputs[t][j];
                    }
                    i_t += b_ii[i];
                }

                for (int i = 0; i < HIDDEN_SIZE; i++) {
                    for (int j = 0; j < HIDDEN_SIZE; j++) {
                        i_t += W_hi[layer][i][j] * hidden_state[t][j];
                    }
                    i_t += b_hi[i];
                }
                

                // Calculate f_t
                

                // Calculate g_t


                // Calculate o_t


                // Calculate c_t


                // Calculate h_t
            }
        }

        // input to FC: lstm_output[512]

        float fc_results[INPUT_SIZE];
        fc_calc(lstm_output, fc_results);
        int selected_note = log_softmax(fc_results);
        // Done
    }




    float i_t[HIDDEN_SIZE];
	float hadarmard_results[HIDDEN_SIZE];

    for (int i = 0; i < HIDDEN_SIZE; i++) {
        int index = FIRST_HALF_BASE+i;
        bram_had_a[index] = ;
        bram_had_b[index] = ;
        bram_had_product[index] = ;
    }

	// Load all weights from W into your weight BRAM
	for (int i = 0; i < 128; i++) {
		for (int j = 0; j < 128; j++) {
			bram_w[i*128 + j] = W[i][j];
		}
	}


	// Prepare timer stuff
    // XTmrCtr TimerCounter;
    // int Status = XTmrCtr_Initialize(&TimerCounter, TMRCTR_DEVICE_ID);
    // if (Status != XST_SUCCESS) {
    //     return XST_FAILURE;
    // }

    // // Set up timer. Clear it. Take the first reading; start the timer.
    // XTmrCtr_SetOptions(&TimerCounter, 0, XTC_AUTO_RELOAD_OPTION);
    // XTmrCtr_Reset(&TimerCounter, 0);                     // reset timer

    // int time0 = XTmrCtr_GetValue(&TimerCounter, 0);      // read timer value
    // XTmrCtr_Start(&TimerCounter, 0);                     // start timer


    for (int t = 0; t < C; t += P) {

    	// Copy input t (x[t][0] through x[t][N-1]) to input BRAM
    	for (int j = 0; j < P; j++) {
			for (int i = 0; i < N; i++) {
				brams[j][i] = x[t+j][i];
			}
    	}

    	// Start FPGA
        hw[0] = 1;

    	// Wait for FPGA to finish
        while ( (hw[1] & 0x1) == 0) {
            ;
        }

        // Deassert start signal
        hw[0] = 0;

    	// Copy the result from the output BRAM to memory y[t][0...N-1]
        for (int j = 0; j < P; j++) {
			for (int i = 0; i < N; i++) {
				volatile int* bram_y = brams[j] + 128;
				y[t+j][i] = bram_y[i];
			}
        }
    }

    // Read the timer value again
    // int time1 = XTmrCtr_GetValue(&TimerCounter, 0);
    // printf("Measured %d clock cycles == %f seconds\r\n", (time1-time0),((double)(time1-time0))/(TIMER_FREQ));


    // Verify results
    int errors = verify_results(expected, y);
    printf("%d errors\r\n", errors);

    printf("-------------- Done ------------\r\n\n\n\n");


    cleanup_platform();
    return 0;
}

void fc_calc(float lstm_output[HIDDEN_SIZE], float fc_results[INPUT_SIZE]) {
    // Do calculations for FC layer
    for (int i = 0; i < INPUT_SIZE; i++) {
        fc_results[i] = 0;
        for (int j = 0; j < HIDDEN_SIZE; j++) {
            fc_results[i] += fc1_weight[i][j] * lstm_output[j];
        }
        fc_results[i] += fc1_bias[i];
    }
}

int log_softmax(float fc_results[INPUT_SIZE]) {
    // Do log softmax
    float denominator = 0;
    for (int i = 0; i < INPUT_SIZE; i++) {
        float temp = exp(fc_results[i]);
        denominator += temp;
        fc_results[i] = temp;
    }

    for (int i = 0; i < INPUT_SIZE; i++) {
        fc_results[i] = log(fc_results[i] / denominator);
    }

    float max = fc_results[0];
    int index = 0;
    for (int i = 1; i < INPUT_SIZE; i++) {
        if (fc_results[i] > max) {
            max = fc_results[i];
            index = i;
        }
    }

    return index;
}


void setup_weight_arrays(float** W_ii[2], float** W_if[2], float** W_ig[2], float** W_io[2],
                         float** W_hi[2], float** W_hf[2], float** W_hg[2], float** W_ho[2],
                         float* b_ii[2], float* b_if[2], float* b_ig[2], float* b_io[2],
                         float* b_hi[2], float* b_hf[2], float* b_hg[2], float* b_ho[2]
                        )
{
    W_ii[0] = W_ii_0;
    W_ii[1] = W_ii_1;
    W_if[0] = W_if_0;
    W_if[1] = W_if_1;
    W_ig[0] = W_ig_0;
    W_ig[1] = W_ig_1;
    W_io[0] = W_io_0;
    W_io[1] = W_io_1;

    W_hi[0] = W_hi_0;
    W_hi[1] = W_hi_1;
    W_hf[0] = W_hf_0;
    W_hf[1] = W_hf_1;
    W_hg[0] = W_hg_0;
    W_hg[1] = W_hg_1;
    W_ho[0] = W_ho_0;
    W_ho[1] = W_ho_1;

    b_ii[0] = b_ii_0;
    b_ii[1] = b_ii_1;
    b_if[0] = b_if_0;
    b_if[1] = b_if_1;
    b_ig[0] = b_ig_0;
    b_ig[1] = b_ig_1;
    b_io[0] = b_io_0;
    b_io[1] = b_io_1;

    b_hi[0] = b_hi_0;
    b_hi[1] = b_hi_1;
    b_hf[0] = b_hf_0;
    b_hf[1] = b_hf_1;
    b_hg[0] = b_hg_0;
    b_hg[1] = b_hg_1;
    b_ho[0] = b_ho_0;
    b_ho[1] = b_ho_1;
}
