
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

#define GENERATED_SONG_LENGTH 5
#define SEQUENCE_LENGTH 85
#define CHUNK_SIZE 32

// #define USE_SOFTWARE_MATRIX
// #define USE_SOFTWARE_HADAMARD
#define USE_SOFTWARE_ACTIVATION

#include "input_notes.h"

#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#include "platform.h"
#include "xil_printf.h"
#include "xscugic.h" // interrupt handler
#include "xdmaps.h"  // DMA driver

#define TIMEOUT_LIMIT           0x2000000
int SetupInterruptSystem(XScuGic *GicPtr, XDmaPs *DmaPtr);
void DmaDoneHandler(unsigned int Channel, XDmaPs_Cmd *DmaCmd, void *CallbackRef);
void transfer_array_to_bram(float * source, volatile float * dest, int length);
void transfer_array_from_bram(volatile float* source, float * dest, int length);
XDmaPs DmaInstance;
XScuGic GicInstance;

float sigmoid(float x);
void vector_sigmoid(float * vector, int length);
void vector_tanh(float * input, float * output, int length);
void hadamard_product(float * a, float * b, float * output, int length);
void vector_add(float * a, float * b, float * output, int length);
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

// Matrix Multiplication hardware (mm):
volatile float* mm_bram_W1 = (float*)XPAR_AXI_BRAM_CTRL_3_S_AXI_BASEADDR;
volatile float* mm_bram_x = (float*)XPAR_AXI_BRAM_CTRL_4_S_AXI_BASEADDR;
volatile float* mm_bram_y1 = (float*)XPAR_AXI_BRAM_CTRL_5_S_AXI_BASEADDR;
volatile float* mm_bram_y2 = (float*)XPAR_AXI_BRAM_CTRL_6_S_AXI_BASEADDR;
volatile float* mm_bram_W2 = (float*)XPAR_AXI_BRAM_CTRL_7_S_AXI_BASEADDR;
volatile unsigned int* mm_hw = (unsigned int*)XPAR_BRAM_MATRIXVECT_MULT_0_S00_AXI_BASEADDR;

// Hadamard Product hardware (hp):
volatile float* hp_bram_a = (float*)XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR;
volatile float* hp_bram_b = (float*)XPAR_AXI_BRAM_CTRL_1_S_AXI_BASEADDR;
volatile float* hp_bram_product = (float*)XPAR_AXI_BRAM_CTRL_2_S_AXI_BASEADDR;
volatile unsigned int* hp_hw = (unsigned int*)XPAR_BRAM_HADAMARD_0_S00_AXI_BASEADDR;

// Activation hardware (hp):
// volatile float* act_bram_in = (float*)XPAR_AXI_BRAM_CTRL_5_S_AXI_BASEADDR;
// volatile float* act_bram_out = (float*)XPAR_AXI_BRAM_CTRL_6_S_AXI_BASEADDR;
// volatile unsigned int* act_hw = (unsigned int*)XPAR_BRAM_ACTIVATION_0_S00_AXI_BASEADDR;

int main()
{
    init_platform();
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
        printf("selected note: %d\r\n", selected_note);

        // Append selected note to list of input notes when predicting the next note
        for (int i = 1; i < SEQUENCE_LENGTH; i++)
            for (int j = 0; j < INPUT_SIZE; j++)
                initial_inputs[i-1][j] = initial_inputs[i][j];
        for (int i = 0; i < INPUT_SIZE; i++) initial_inputs[SEQUENCE_LENGTH-1][i] = 0;
        initial_inputs[SEQUENCE_LENGTH-1][selected_note] = 1;
    }

    for (int i = 0; i < GENERATED_SONG_LENGTH; i++) {
        printf("%d, ", selected_notes[i]);
        if (i % 10 == 0) {
            printf("\r\n");
        }
    }

    printf("\n-------------- Done ------------\r\n\n\n\n");
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

void hadamard_product(float * a, float * b, float * output, int length) {
#ifdef USE_SOFTWARE_HADAMARD
    for (int i = 0; i < length; i++) {
        output[i] = a[i] * b[i];
    }
#else
    // Load data
    transfer_array_to_bram(a, hp_bram_a, length);
    transfer_array_to_bram(b, hp_bram_b, length);
    // for (int i = 0; i < length; i++) {
    //     hp_bram_a[i] = a[i];
    //     hp_bram_b[i] = b[i];
    // }

    // Start
    hp_hw[0] = 1;

    // Wait for FPGA to finish
    while ( (hp_hw[1] & 0x1) == 0) {}

    // Deassert start signal
    hp_hw[0] = 0;

    transfer_array_from_bram(hp_bram_product, output, length);
    // for (int i = 0; i < length; i++) {
    //     output[i] = hp_bram_product[i];
    // }
#endif
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
#ifdef USE_SOFTWARE_MATRIX
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            output[i] += weights[i][j] * input[j];
        }
        output[i] += bias[i];
    }
#else
    // Load bias into BRAM
    transfer_array_to_bram(bias, mm_bram_y1, rows / 2);
    transfer_array_to_bram((bias+(rows/2)), mm_bram_y2, rows / 2);
    // for (int i = 0; i < rows; i++) mm_bram_y[i] = bias[i];

    // Load all weights and inputs into BRAM W and x
	int num_iter = (cols % CHUNK_SIZE == 0)? cols/CHUNK_SIZE : cols/CHUNK_SIZE +1;

    for (int chunkNum = 0; chunkNum < num_iter; chunkNum++){	//iterate on every chunk (before remainding one)
		int remaining_cols = cols - (chunkNum * CHUNK_SIZE) ;
        remaining_cols = (remaining_cols >= CHUNK_SIZE) ? CHUNK_SIZE : remaining_cols;

		//Load W
        float (* offset)[INPUT_SIZE] = weights + (rows / 2);
		for(int row = 0; row < rows / 2; row++){
            int row_offset = row * CHUNK_SIZE;
            transfer_array_to_bram(weights[row] + chunkNum*CHUNK_SIZE, (mm_bram_W1 + row_offset), remaining_cols);
            transfer_array_to_bram(offset[row] + chunkNum*CHUNK_SIZE, (mm_bram_W2 + row_offset), remaining_cols);
            // for(int col = 0; col < remaining_cols; col++){
			// 	mm_bram_W1[(row_offset) + col] = weights[row][ (chunkNum * CHUNK_SIZE) + col ];
            //     mm_bram_W2[(row_offset) + col] = offset[row][ (chunkNum * CHUNK_SIZE) + col ];
			// }
		}

		//Load x
        transfer_array_to_bram((input + (chunkNum * CHUNK_SIZE)), mm_bram_x, remaining_cols);
		// for (int row = 0; row < remaining_cols; row++){
		// 	mm_bram_x[row] = input[(chunkNum * CHUNK_SIZE) + row ];
		// }		
		for (int j = remaining_cols; j < CHUNK_SIZE; j++){
			mm_bram_x[j] = 0;
		}

		//start computation, wait for pl
		mm_hw[0] = 1;
		while ( (mm_hw[1] & 0x1) == 0) {}
        // Deassert start signal
        mm_hw[0] = 0;
	}

    float y1_output[HIDDEN_SIZE/2];
    float y2_output[HIDDEN_SIZE/2];
    transfer_array_from_bram(mm_bram_y1, y1_output, rows / 2);
    transfer_array_from_bram(mm_bram_y2, y2_output, rows / 2);
    volatile float * offset = output + (rows / 2);
    for (int i = 0; i < rows/2; i++) {
        output[i] += y1_output[i];
        offset[i] += y2_output[i];
    }
    // for (int i = 0; i < rows/2; i++) {
    //     output[i] += mm_bram_y1[i];
    //     offset[i] += mm_bram_y2[i];
    // }
#endif
}

void matrix_vector_mult_1(float (* weights)[HIDDEN_SIZE], float * input, float * bias, float * output,
                        int rows, int cols) {
#ifdef USE_SOFTWARE_MATRIX
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            output[i] += weights[i][j] * input[j];
        }
        output[i] += bias[i];
    }
#else
    // Load bias into BRAM
    transfer_array_to_bram(bias, mm_bram_y1, rows / 2);
    transfer_array_to_bram((bias+(rows/2)), mm_bram_y2, rows / 2);
    // for (int i = 0; i < rows; i++) mm_bram_y[i] = bias[i];

    // Load all weights and inputs into BRAM W and x
	int num_iter = (cols % CHUNK_SIZE == 0)? cols/CHUNK_SIZE : cols/CHUNK_SIZE +1;

    for (int chunkNum = 0; chunkNum < num_iter; chunkNum++){	//iterate on every chunk (before remainding one)
		int remaining_cols = cols - (chunkNum * CHUNK_SIZE) ;
        remaining_cols = (remaining_cols >= CHUNK_SIZE) ? CHUNK_SIZE : remaining_cols;

		//Load W
        float (* offset)[HIDDEN_SIZE] = weights + (rows / 2);
		for(int row = 0; row < rows / 2; row++){
            int row_offset = row * CHUNK_SIZE;
            transfer_array_to_bram(weights[row] + chunkNum*CHUNK_SIZE, (mm_bram_W1 + row_offset), remaining_cols);
            transfer_array_to_bram(offset[row] + chunkNum*CHUNK_SIZE, (mm_bram_W2 + row_offset), remaining_cols);
            // for(int col = 0; col < remaining_cols; col++){
			// 	mm_bram_W1[(row_offset) + col] = weights[row][ (chunkNum * CHUNK_SIZE) + col ];
            //     mm_bram_W2[(row_offset) + col] = offset[row][ (chunkNum * CHUNK_SIZE) + col ];
			// }
		}

		//Load x
        transfer_array_to_bram((input + (chunkNum * CHUNK_SIZE)), mm_bram_x, remaining_cols);
		// for (int row = 0; row < remaining_cols; row++){
		// 	mm_bram_x[row] = input[(chunkNum * CHUNK_SIZE) + row ];
		// }		
		for (int j = remaining_cols; j < CHUNK_SIZE; j++){
			mm_bram_x[j] = 0;
		}

		//start computation, wait for pl
		mm_hw[0] = 1;
		while ( (mm_hw[1] & 0x1) == 0) {}
        // Deassert start signal
        mm_hw[0] = 0;
	}

    float y1_output[HIDDEN_SIZE/2];
    float y2_output[HIDDEN_SIZE/2];
    transfer_array_from_bram(mm_bram_y1, y1_output, rows / 2);
    transfer_array_from_bram(mm_bram_y2, y2_output, rows / 2);
    volatile float * offset = output + (rows / 2);
    for (int i = 0; i < rows/2; i++) {
        output[i] += y1_output[i];
        offset[i] += y2_output[i];
    }
    // for (int i = 0; i < rows/2; i++) {
    //     output[i] += mm_bram_y1[i];
    //     offset[i] += mm_bram_y2[i];
    // }
#endif
}

void vector_add(float * a, float * b, float * output, int length) {
    for (int i = 0; i < length; i++) {
        output[i] = a[i] + b[i];
    }
}

float sigmoid(float x) {
    return 1.0 / (1.0 + exp(-x));
}

// ps_control[0] = 1, means sigmoid
// ps_control[1] = 1, means tanh
void vector_sigmoid(float * vector, int length) {
#ifdef USE_SOFTWARE_ACTIVATION
    for (int i = 0; i < length; i++) {
        vector[i] = sigmoid(vector[i]);
    }
#else
    // Load data
    transfer_array_to_bram(vector, act_bram_in, length);
    // for (int i = 0; i < length; i++) {
    //     act_bram_in[i] = vector[i];
    // }

    // Start
    act_hw[0] = 1;
    // Wait for FPGA to finish
    while ( (act_hw[1] & 0x1) == 0) {}
    // Deassert start signal
    act_hw[0] = 0;

    transfer_array_from_bram(act_bram_out, vector, length);
    // for (int i = 0; i < length; i++) {
    //     vector[i] = act_bram_out[i];
    // }
#endif
}

// ps_control[0] = 1, means sigmoid
// ps_control[1] = 1, means tanh
void vector_tanh(float * input, float * output, int length) {
#ifdef USE_SOFTWARE_ACTIVATION
    for (int i = 0; i < length; i++) {
        output[i] = tanhf(input[i]);
    }
#else
    // Load data
    transfer_array_to_bram(input, act_bram_in, length);
    // for (int i = 0; i < length; i++) {
    //     act_bram_in[i] = input[i];
    // }

    // Start
    act_hw[0] = 2;
    // Wait for FPGA to finish
    while ( (act_hw[1] & 0x1) == 0) {}
    // Deassert start signal
    act_hw[0] = 0;

    transfer_array_from_bram(act_bram_out, output, length);
    // for (int i = 0; i < length; i++) {
    //     output[i] = act_bram_out[i];
    // }
#endif
}



void transfer_array_from_bram(volatile float* source, float * dest, int length) {
    volatile int* txDone = malloc(sizeof(int));
    *txDone = 0;

    u16 DeviceId = XPAR_XDMAPS_1_DEVICE_ID;
    XDmaPs_Config *DmaCfg;
    XDmaPs *DmaInst = &DmaInstance;
    XDmaPs_Cmd DmaCmd;
    memset(&DmaCmd, 0, sizeof(XDmaPs_Cmd));
    DmaCmd.ChanCtrl.SrcBurstSize = 4;
    DmaCmd.ChanCtrl.SrcBurstLen = 4;
    DmaCmd.ChanCtrl.SrcInc = 1;
    DmaCmd.ChanCtrl.DstBurstSize = 4;
    DmaCmd.ChanCtrl.DstBurstLen = 4;
    DmaCmd.ChanCtrl.DstInc = 1;
    DmaCmd.BD.SrcAddr = (u32) source;  // source = txBuff
    DmaCmd.BD.DstAddr = (u32) dest;    // destination = bram
    DmaCmd.BD.Length = length * sizeof(float);   // length of data to transfer

    // Initialize DMA driver
    DmaCfg = XDmaPs_LookupConfig(DeviceId);
    if (DmaCfg == NULL) {
    	printf("DmaCfg error!\r\n");
    	return;
    }
    int Status = XDmaPs_CfgInitialize(DmaInst, DmaCfg, DmaCfg->BaseAddress);
    if (Status != XST_SUCCESS) {
    	printf("CfgInitialize error!\r\n");
        return;
    }
    // Setup interrupts
    Status = SetupInterruptSystem(&GicInstance, DmaInst);
    if (Status != XST_SUCCESS) {
    	printf("SetupInterrupt error!\r\n");
        return;
    }
    // Enable the interrupt handler
    XDmaPs_SetDoneHandler(DmaInst, 0, DmaDoneHandler, (void *)txDone);
    // Start the DMA
    Status = XDmaPs_Start(DmaInst, 0, &DmaCmd, 0);
    if (Status != XST_SUCCESS) {
    	printf("Start error!\r\n");
        return;
    }
    // Loop until the DMA is done --  txDone will be set in interrupt handler
    int TimeOutCnt=0;
    while (!(*txDone) && TimeOutCnt < TIMEOUT_LIMIT) {
        TimeOutCnt++;
    }
    if (TimeOutCnt >= TIMEOUT_LIMIT) {
        printf("timeout\r\n");
        return;
    }
}

void transfer_array_to_bram(float * source, volatile float * dest, int length) {
    volatile int* txDone = malloc(sizeof(int));
    *txDone = 0;

    u16 DeviceId = XPAR_XDMAPS_1_DEVICE_ID;
    XDmaPs_Config *DmaCfg;
    XDmaPs *DmaInst = &DmaInstance;
    XDmaPs_Cmd DmaCmd;
    memset(&DmaCmd, 0, sizeof(XDmaPs_Cmd));
    DmaCmd.ChanCtrl.SrcBurstSize = 4;
    DmaCmd.ChanCtrl.SrcBurstLen = 4;
    DmaCmd.ChanCtrl.SrcInc = 1;
    DmaCmd.ChanCtrl.DstBurstSize = 4;
    DmaCmd.ChanCtrl.DstBurstLen = 4;
    DmaCmd.ChanCtrl.DstInc = 1;
    DmaCmd.BD.SrcAddr = (u32) source;  // source = txBuff
    DmaCmd.BD.DstAddr = (u32) dest;    // destination = bram
    DmaCmd.BD.Length = length * sizeof(float);   // length of data to transfer

    // Initialize DMA driver
    DmaCfg = XDmaPs_LookupConfig(DeviceId);
    if (DmaCfg == NULL) {
    	printf("DmaCfg error!\r\n");
    	return;
    }
    int Status = XDmaPs_CfgInitialize(DmaInst, DmaCfg, DmaCfg->BaseAddress);
    if (Status != XST_SUCCESS) {
    	printf("CfgInitialize error!\r\n");
        return;
    }
    // Setup interrupts
    Status = SetupInterruptSystem(&GicInstance, DmaInst);
    if (Status != XST_SUCCESS) {
    	printf("SetupInterrupt error!\r\n");
        return;
    }
    // Enable the interrupt handler
    XDmaPs_SetDoneHandler(DmaInst, 0, DmaDoneHandler, (void *)txDone);
    // Start the DMA
    Status = XDmaPs_Start(DmaInst, 0, &DmaCmd, 0);
    if (Status != XST_SUCCESS) {
    	printf("Start error!\r\n");
        return;
    }
    // Loop until the DMA is done --  txDone will be set in interrupt handler
    int TimeOutCnt=0;
    while (!(*txDone) && TimeOutCnt < TIMEOUT_LIMIT) {
        TimeOutCnt++;
    }
    if (TimeOutCnt >= TIMEOUT_LIMIT) {
        printf("timeout\r\n");
        return;
    }
}











int SetupInterruptSystem(XScuGic *GicPtr, XDmaPs *DmaPtr)
{
    int Status;
    XScuGic_Config *GicConfig;

    Xil_ExceptionInit();

    /*
     * Initialize the interrupt controller driver so that it is ready to
     * use.
     */
    GicConfig = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
    if (NULL == GicConfig) {
        return XST_FAILURE;
    }

    Status = XScuGic_CfgInitialize(GicPtr, GicConfig,
                       GicConfig->CpuBaseAddress);
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    /*
     * Connect the interrupt controller interrupt handler to the hardware
     * interrupt handling logic in the processor.
     */
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT,
                 (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                 GicPtr);

    /*
     * Connect the device driver handlers that will be called when an interrupt
     * for the device occurs, the device driver handler performs the specific
     * interrupt processing for the device
     */

    /*
     * Connect the Fault ISR
     */
    Status = XScuGic_Connect(GicPtr,
                 XPAR_XDMAPS_0_FAULT_INTR,
                 (Xil_InterruptHandler)XDmaPs_FaultISR,
                 (void *)DmaPtr);
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    /*
     * Connect the Done ISR for all 8 channels of DMA 0
     */
    Status = XScuGic_Connect(GicPtr,
                 XPAR_XDMAPS_0_DONE_INTR_0,
                 (Xil_InterruptHandler)XDmaPs_DoneISR_0,
                 (void *)DmaPtr);

    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    /*
     * Enable the interrupts for the device
     */
    XScuGic_Enable(GicPtr, XPAR_XDMAPS_0_DONE_INTR_0);
    XScuGic_Enable(GicPtr, XPAR_XDMAPS_0_FAULT_INTR);

    Xil_ExceptionEnable();

    return XST_SUCCESS;

}
void DmaDoneHandler(unsigned int Channel, XDmaPs_Cmd *DmaCmd, void *CallbackRef)
{
    volatile int *done = (volatile int *)CallbackRef;
    *done = 1;
    return;
}
