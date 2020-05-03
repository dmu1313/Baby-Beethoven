
# Run this script to generate C-style header files that contain arrays holding the weights of the neural network.

import torch
import os

CHECK_MODEL_STATE = 'model_state_dict' # Comes from model.py in the "pytorch" directory
file = "./model_weights.pt"
currentHiddenSize = 512 # For the LSTM layers
currentInputSize = 1572

def genSpacing(level, unit="\t"):
    result = ""
    for i in range(level):
        result = result + unit
    return result

def writeWithSpacing(output, level, file):
    spacing = genSpacing(level)
    file.write(spacing + output)

def writeTensors(weights, level, file):
    dimensions = weights.dim()
    if dimensions == 1:
        writeWithSpacing("{", level, file)
        for i in range(len(weights)):
            # output = str(weights[i].item())
            output = "{:.8f}".format(weights[i].item())
            if i < len(weights)-1:
                file.write(output + ",")
            else:
                file.write(output)
        file.write("}")
    else:
        writeWithSpacing("{\n", level, file)
        for i in range(len(weights)):
            writeTensors(weights[i], level+1, file)
            if i < len(weights)-1:
                file.write(",\n")
            else:
                file.write("\n")
        writeWithSpacing("}", level, file)

def generateFile(label, weights):
    dimensions = weights.dim()
    assert(dimensions > 0)

    f = open(label + ".h", "w")
    f.write("// HIDDEN_SIZE and INPUT_SIZE are macros that should be defined in the main file.\n\n")

    f.write("float " + str(label))
    for i in range(dimensions):
        if weights.size()[i] == currentHiddenSize:
            constant = "HIDDEN_SIZE"
        elif weights.size()[i] == currentInputSize:
            constant = "INPUT_SIZE"
        else:
            print("Not a supported dimension size for our weights.")
            exit()
        f.write("[" + constant + "]")

    f.write(" =\n")
    writeTensors(weights, 1, f)
    f.write(";")
    f.close()

def parseLstmLayer(ih_weight, hh_weight, ih_bias, hh_bias, layerNum):
    hiddenSize = ih_weight.size()[0] // 4
    assert(currentHiddenSize == hiddenSize)
    columnSize = ih_weight.size()[1]
    assert(currentInputSize == columnSize or currentHiddenSize == columnSize)

    generateFile("W_ii_" + str(layerNum), ih_weight[0:hiddenSize][:])
    generateFile("b_ii_" + str(layerNum), ih_bias[0:hiddenSize])
    generateFile("W_hi_" + str(layerNum), hh_weight[0:hiddenSize][:])
    generateFile("b_hi_" + str(layerNum), hh_bias[0:hiddenSize])

    generateFile("W_if_" + str(layerNum), ih_weight[hiddenSize:2*hiddenSize][:])
    generateFile("b_if_" + str(layerNum), ih_bias[hiddenSize:2*hiddenSize])
    generateFile("W_hf_" + str(layerNum), hh_weight[hiddenSize:2*hiddenSize][:])
    generateFile("b_hf_" + str(layerNum), hh_bias[hiddenSize:2*hiddenSize])
    
    generateFile("W_ig_" + str(layerNum), ih_weight[2*hiddenSize:3*hiddenSize][:])
    generateFile("b_ig_" + str(layerNum), ih_bias[2*hiddenSize:3*hiddenSize])
    generateFile("W_hg_" + str(layerNum), hh_weight[2*hiddenSize:3*hiddenSize][:])
    generateFile("b_hg_" + str(layerNum), hh_bias[2*hiddenSize:3*hiddenSize])

    generateFile("W_io_" + str(layerNum), ih_weight[3*hiddenSize:4*hiddenSize][:])
    generateFile("b_io_" + str(layerNum), ih_bias[3*hiddenSize:4*hiddenSize])
    generateFile("W_ho_" + str(layerNum), hh_weight[3*hiddenSize:4*hiddenSize][:])
    generateFile("b_ho_" + str(layerNum), hh_bias[3*hiddenSize:4*hiddenSize])
    
def parseFcLayer(fc_weight, fc_bias):
    generateFile("fc1_weight", fc_weight)
    generateFile("fc1_bias", fc_bias)

if __name__ == "__main__":
    if os.path.isfile(file):
        model = torch.load(file)[CHECK_MODEL_STATE]
    else:
        exit()
    
    # This is our network and the weights that we trained
    ih_weight_0 = model['lstm1.weight_ih_l0']
    hh_weight_0 = model['lstm1.weight_hh_l0']

    ih_bias_0 = model['lstm1.bias_ih_l0']
    hh_bias_0 = model['lstm1.bias_hh_l0']

    ih_weight_1 = model['lstm1.weight_ih_l1']
    hh_weight_1 = model['lstm1.weight_hh_l1']

    ih_bias_1 = model['lstm1.bias_ih_l1']
    hh_bias_1 = model['lstm1.bias_hh_l1']

    fc1_weight = model['fc1.weight']
    fc1_bias = model['fc1.bias']

    parseLstmLayer(ih_weight_0, hh_weight_0, ih_bias_0, hh_bias_0, 0)
    parseLstmLayer(ih_weight_1, hh_weight_1, ih_bias_1, hh_bias_1, 1)
    parseFcLayer(fc1_weight, fc1_bias)
