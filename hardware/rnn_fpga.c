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

#include "input_notes.h"

#include <stdio.h>
#include <math.h>

// #include "platform.h"
// #include "xil_printf.h"
// #include "xtmrctr.h"  // timer

// #define TIMER_BASE 0x42800000   // change to match base address of your AXI timer if necessary
// #define TIMER_FREQ 				XPAR_TMRCTR_0_CLOCK_FREQ_HZ
// #define TMRCTR_DEVICE_ID        XPAR_TMRCTR_0_DEVICE_ID

float sigmoid(float x);
void vector_sigmoid(float * vector, int length);
void vector_tanh(float * input, float * output, int length);
void hadamard_product(float * a, float * b, float * output, int length);
void vector_add(float * a, float * b, float * output, int length);

void setup_weight_arrays(float** W_ii[2], float** W_if[2], float** W_ig[2], float** W_io[2],
                         float** W_hi[2], float** W_hf[2], float** W_hg[2], float** W_ho[2],
                         float* b_ii[2], float* b_if[2], float* b_ig[2], float* b_io[2],
                         float* b_hi[2], float* b_hf[2], float* b_hg[2], float* b_ho[2]
                        );
void fc_calc(float lstm_output[HIDDEN_SIZE], float fc_results[INPUT_SIZE]);
int log_softmax(float fc_results[INPUT_SIZE]);


void lstm_matrix_component_0(float (* weight_input)[INPUT_SIZE], float * input, float * bias_input,
                           float (* weight_hidden)[HIDDEN_SIZE], float * hidden_state, float * bias_hidden, 
                           float * result, int hidden_size, int input_size);
void lstm_matrix_component_1(float (* weight_input)[HIDDEN_SIZE], float * input, float * bias_input,
                           float (* weight_hidden)[HIDDEN_SIZE], float * hidden_state, float * bias_hidden, 
                           float * result, int hidden_size, int input_size);

void matrix_vector_mult_0(float (* weights)[INPUT_SIZE], float * input, float * bias, float * output, int rows, int cols);
void matrix_vector_mult_1(float (* weights)[HIDDEN_SIZE], float * input, float * bias, float * output, int rows, int cols);

void calc_cell_state(float * f_t, float * prev_c_t, float * i_t, float * g_t, float * output, int length);
void calc_hidden_state(float * o_t, float * c_t, float * output, int length);

int main()
{
//    init_platform();
    printf("-------------- Starting Test ------------\n\r");

    // Set up input one-hot vectors
    float initial_inputs[SEQUENCE_LENGTH][INPUT_SIZE];
    for (int i = 0; i < SEQUENCE_LENGTH; i++)
        for (int j = 0; j < INPUT_SIZE; j++)
            initial_inputs[i][j] = 0;
    for (int i = 0; i < SEQUENCE_LENGTH; i++) initial_inputs[i][input_notes[i]] = 1;

    // Store generated notes
    int selected_notes[GENERATED_SONG_LENGTH];

    float i_t[HIDDEN_SIZE];
    float f_t[HIDDEN_SIZE];
    float g_t[HIDDEN_SIZE];
    float o_t[HIDDEN_SIZE];

    // Inputs for layers beyond 1
    float intermediate_inputs[SEQUENCE_LENGTH][HIDDEN_SIZE];

    for (int noteNum = 0; noteNum < GENERATED_SONG_LENGTH; noteNum++) {
        printf("Generating Note Number: %d\n", noteNum);
        
        // LSTM Layer 1 computations
        int input_size = INPUT_SIZE;

        float hidden_state[HIDDEN_SIZE];
        float cell_state[HIDDEN_SIZE];
        for (int i = 0; i < HIDDEN_SIZE; i++) hidden_state[i] = 0;
        for (int i = 0; i < HIDDEN_SIZE; i++) cell_state[i] = 0;

        for (int t = 0; t < SEQUENCE_LENGTH; t++) {
            // Calculate i_t
            for (int i = 0; i < HIDDEN_SIZE; i++) i_t[i] = 0;
            lstm_matrix_component_0(
                        W_ii_0, initial_inputs[t], b_ii_0,
                        W_hi_0, hidden_state, b_hi_0, 
                        i_t, HIDDEN_SIZE, input_size
                    );
            vector_sigmoid(i_t, HIDDEN_SIZE);

            // Calculate f_t
            for (int i = 0; i < HIDDEN_SIZE; i++) f_t[i] = 0;
            lstm_matrix_component_0(
                        W_if_0, initial_inputs[t], b_if_0,
                        W_hf_0, hidden_state, b_hf_0, 
                        f_t, HIDDEN_SIZE, input_size
                    );
            vector_sigmoid(f_t, HIDDEN_SIZE);

            // Calculate g_t
            for (int i = 0; i < HIDDEN_SIZE; i++) g_t[i] = 0;
            lstm_matrix_component_0(
                        W_ig_0, initial_inputs[t], b_ig_0,
                        W_hg_0, hidden_state, b_hg_0, 
                        g_t, HIDDEN_SIZE, input_size
                    );
            vector_tanh(g_t, g_t, HIDDEN_SIZE);

            // Calculate o_t
            for (int i = 0; i < HIDDEN_SIZE; i++) o_t[i] = 0;
            lstm_matrix_component_0(
                        W_io_0, initial_inputs[t], b_io_0,
                        W_ho_0, hidden_state, b_ho_0, 
                        o_t, HIDDEN_SIZE, input_size
                    );
            vector_sigmoid(o_t, HIDDEN_SIZE);

            // Calculate c_t
            calc_cell_state(f_t, cell_state, i_t, g_t, cell_state, HIDDEN_SIZE);

            // Calculate h_t
            calc_hidden_state(o_t, cell_state, hidden_state, HIDDEN_SIZE);
            for (int i = 0; i < HIDDEN_SIZE; i++) { 
                intermediate_inputs[t][i] = hidden_state[i];
            }
        }

        // Start LSTM layer 2 computations
        input_size = HIDDEN_SIZE;
        for (int i = 0; i < HIDDEN_SIZE; i++) hidden_state[i] = 0;
        for (int i = 0; i < HIDDEN_SIZE; i++) cell_state[i] = 0;

        for (int t = 0; t < SEQUENCE_LENGTH; t++) {
            // Calculate i_t
            for (int i = 0; i < HIDDEN_SIZE; i++) i_t[i] = 0;
            lstm_matrix_component_1(
                        W_ii_1, intermediate_inputs[t], b_ii_1,
                        W_hi_1, hidden_state, b_hi_1, 
                        i_t, HIDDEN_SIZE, input_size
                    );
            vector_sigmoid(i_t, HIDDEN_SIZE);

            // Calculate f_t
            for (int i = 0; i < HIDDEN_SIZE; i++) f_t[i] = 0;
            lstm_matrix_component_1(
                        W_if_1, intermediate_inputs[t], b_if_1,
                        W_hf_1, hidden_state, b_hf_1, 
                        f_t, HIDDEN_SIZE, input_size
                    );
            vector_sigmoid(f_t, HIDDEN_SIZE);

            // Calculate g_t
            for (int i = 0; i < HIDDEN_SIZE; i++) g_t[i] = 0;
            lstm_matrix_component_1(
                        W_ig_1, intermediate_inputs[t], b_ig_1,
                        W_hg_1, hidden_state, b_hg_1, 
                        g_t, HIDDEN_SIZE, input_size
                    );
            vector_tanh(g_t, g_t, HIDDEN_SIZE);

            // Calculate o_t
            for (int i = 0; i < HIDDEN_SIZE; i++) o_t[i] = 0;
            lstm_matrix_component_1(
                        W_io_1, intermediate_inputs[t], b_io_1,
                        W_ho_1, hidden_state, b_ho_1, 
                        o_t, HIDDEN_SIZE, input_size
                    );
            vector_sigmoid(o_t, HIDDEN_SIZE);

            // Calculate c_t
            calc_cell_state(f_t, cell_state, i_t, g_t, cell_state, HIDDEN_SIZE);

            // Calculate h_t
            calc_hidden_state(o_t, cell_state, hidden_state, HIDDEN_SIZE);
            for (int i = 0; i < HIDDEN_SIZE; i++) { 
                intermediate_inputs[t][i] = hidden_state[i];
            }
        }

        // Completed LSTM Calculations. Now do FC and log softmax
        // intermediate_inputs[SEQUENCE_LENGTH-1] is the output we take from the LSTMs
        // input to FC: lstm_output[512]
        float fc_results[INPUT_SIZE];
        fc_calc(intermediate_inputs[SEQUENCE_LENGTH-1], fc_results);
        
        // log softmax and get most likely next note
        int selected_note = log_softmax(fc_results);
        selected_notes[noteNum] = selected_note;

        // Append selected note to list of input notes when predicting the next note
        for (int i = 1; i < SEQUENCE_LENGTH; i++)
            for (int j = 0; j < INPUT_SIZE; j++)
                initial_inputs[i-1][j] = initial_inputs[i][j];
        for (int i = 0; i < INPUT_SIZE; i++) initial_inputs[SEQUENCE_LENGTH-1][i] = 0;
        initial_inputs[SEQUENCE_LENGTH-1][selected_note] = 1;
    }

    for (int i = 0; i < GENERATED_SONG_LENGTH; i++) {
        printf("%d, ", selected_notes[i]);
    }

    printf("\n-------------- Done ------------\r\n\n\n\n");
    // cleanup_platform();
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

void hadamard_product(float * a, float * b, float * output, int length) {
    for (int i = 0; i < length; i++) {
        output[i] = a[i] * b[i];
    }
}

void calc_cell_state(float * f_t, float * prev_c_t, float * i_t, float * g_t, float * output, int length) {
    // Overwrite f_t and use it as temporary storage since we don't need f_t after this point.
    hadamard_product(f_t, prev_c_t, f_t, length);
    hadamard_product(i_t, g_t, output, length);
    vector_add(f_t, output, output, length);
}

void calc_hidden_state(float * o_t, float * c_t, float * output, int length) {
    float temp[HIDDEN_SIZE];
    vector_tanh(c_t, temp, length);
    hadamard_product(o_t, temp, output, length);
}

// Use this for i_t, f_t, g_t, o_t
void lstm_matrix_component_0(float (* weight_input)[INPUT_SIZE], float * input, float * bias_input,
                           float (* weight_hidden)[HIDDEN_SIZE], float * hidden_state, float * bias_hidden, 
                           float * result, int hidden_size, int input_size) {
    matrix_vector_mult_0(weight_input, input, bias_input, result, hidden_size, input_size);
    matrix_vector_mult_1(weight_hidden, hidden_state, bias_hidden, result, hidden_size, hidden_size);
}

void lstm_matrix_component_1(float (* weight_input)[HIDDEN_SIZE], float * input, float * bias_input,
                           float (* weight_hidden)[HIDDEN_SIZE], float * hidden_state, float * bias_hidden, 
                           float * result, int hidden_size, int input_size) {
    matrix_vector_mult_1(weight_input, input, bias_input, result, hidden_size, input_size);
    matrix_vector_mult_1(weight_hidden, hidden_state, bias_hidden, result, hidden_size, hidden_size);
}

// weights_cols == len(input)
// weights_rows == len(bias) == len(output)
void matrix_vector_mult_0(float (* weights)[INPUT_SIZE], float * input, float * bias, float * output,
                        int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            output[i] += weights[i][j] * input[j];
        }
        output[i] += bias[i];
    }
}

void matrix_vector_mult_1(float (* weights)[HIDDEN_SIZE], float * input, float * bias, float * output,
                        int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            output[i] += weights[i][j] * input[j];
        }
        output[i] += bias[i];
    }
}

void vector_add(float * a, float * b, float * output, int length) {
    for (int i = 0; i < length; i++) {
        output[i] = a[i] + b[i];
    }
}

float sigmoid(float x) {
    return 1.0 / (1.0 + exp(-x));
}

void vector_sigmoid(float * vector, int length) {
    for (int i = 0; i < length; i++) {
        vector[i] = sigmoid(vector[i]);
    }
}

void vector_tanh(float * input, float * output, int length) {
    for (int i = 0; i < length; i++) {
        output[i] = tanhf(input[i]);
    }
}
