
import torch
import torch.nn as nn
import torch.nn.functional as F

CHECK_MODEL_STATE       = 'model_state_dict'
CHECK_OPTIMIZER_STATE   = 'optimizer_state_dict'
CHECK_EPOCH             = 'epoch'

# Useful constants
numThreads = 8
midi_file_dir = "./music/"

saveBase = './saves/'
notes_save_file = saveBase + '05_notes.b'
song_start_indices_save_file = saveBase + '05_notes_song_starts.b'
prepared_input_save_file = saveBase + '05_inputs.hdf5'
prepared_output_save_file = saveBase + '05_outputs.hdf5'
model_save_file = saveBase + '05_model.pt'
generate_save_file_prefix = saveBase + 'song_35'
generate_save_file_extension = '.mid'

############################
# Hyperparameters
batchSize = 64          # The batch size used for learning
learning_rate = 0.05    # Learning rate used in SGD
momentum = 0.5          # Momentum used in SGD
epochs = 50              # Number of epochs to train for
############################################

sequence_length = 85

bidirectional = False

num_layers = 2
num_directions = 1
if (bidirectional == True):
    num_directions = 2
hidden_size = 512
dropout = 0.5

class Net(nn.Module):
    def __init__(self, input_size):
        super(Net, self).__init__()
        
        # Defaults: num_layers=1, bias=True, batch_first=False, dropout=0, bidirectional=False
        self.lstm1 = nn.LSTM(input_size, hidden_size, num_layers, dropout=dropout, batch_first=True)
        self.fc1 = nn.Linear(hidden_size, input_size)

    def forward(self, x, batch_size):
        h0 = torch.zeros(num_layers * num_directions, batch_size, hidden_size).float()
        c0 = torch.zeros(num_layers * num_directions, batch_size, hidden_size).float()
        x, (hn, cn) = self.lstm1(x.float(), (h0, c0))

        x = x[:,sequence_length-1,:]
        
        x = x.view(-1, hidden_size)
        x = self.fc1(x)
        x = F.log_softmax(x, dim=1)

        return x, (hn, cn)

    # def init_hidden(self):
    #     num_layers * num_directions, batchSize, hidden_size

    # Some simple code to calculate the number of parametesr
    def num_params(self):
        numParams = 0
        for param in self.parameters():
            thisLayerParams=1
            for s in list(param.size()):
                thisLayerParams *= s
            numParams += thisLayerParams

        return numParams
