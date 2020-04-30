
from model import *
from musicdata import MusicDataset
import os
from generate import *

import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim

# Set up training and test data
trainset = MusicDataset(midi_file_dir, sequence_length, notes_save_file,
                        prepared_input_save_file, prepared_output_save_file,
                        song_start_indices_save_file)
trainloader = torch.utils.data.DataLoader(trainset, batch_size=batchSize,
                                          shuffle=True, num_workers=0)
##################################
# Define our network
myNet = Net(trainset.num_unique_notes)
print(myNet)
print("Total number of parameters: ", myNet.num_params())
torch.set_num_threads(numThreads)

###################################
# Training
# Loss function: negative log likelihood
criterion = nn.NLLLoss()

# Configuring stochastic gradient descent optimizer
optimizer = optim.SGD(myNet.parameters(), lr=learning_rate, momentum=momentum)

if os.path.isfile(model_save_file):
    checkpoint = torch.load(model_save_file)
    myNet.load_state_dict(checkpoint[CHECK_MODEL_STATE])
    optimizer.load_state_dict(checkpoint[CHECK_OPTIMIZER_STATE])
    epoch = checkpoint[CHECK_EPOCH]
    # loss = checkpoint['loss']
else:
    epoch = 0

myNet.train()

# Each epoch will go over training set once; run two epochs
while epoch < epochs: 
    running_loss = 0.0

    # iterate over the training set
    for i, data in enumerate(trainloader, 0):
        # Get the inputs
        inputs, labels = data

        if (labels.size(0) != batchSize):
            print("BREAKING")
            break

        # Clear the parameter gradients
        optimizer.zero_grad()

        #################################
        # forward + backward + optimize
        # 1. evaluate the current network on a minibatch of the training set
        outputs, (hn, cn) = myNet(inputs, batchSize)
        # 2. compute the loss function
        loss = criterion(outputs, labels)
        # 3. compute the gradients
        loss.backward()                    
        # 4. update the parameters based on gradients
        optimizer.step()

        # Update the average loss
        running_loss += loss.item()

        # Print the average loss every 256 minibatches ( == 16384 images)
        if i % 8 == 7:
            print('[%d, %5d] loss: %.3f' %
                  (epoch + 1, i + 1, running_loss / 8))
            running_loss = 0.0

    epoch += 1
    torch.save({
        CHECK_MODEL_STATE:      myNet.state_dict(),
        CHECK_OPTIMIZER_STATE:  optimizer.state_dict(),
        CHECK_EPOCH:            epoch
    }, model_save_file)

print('Finished Training!')

print("Generating: ")
generateLoader = torch.utils.data.DataLoader(trainset, batch_size=1,
                                        shuffle=True, num_workers=0)
myNet.eval()

with torch.no_grad():
    # Only get 1 random sequence to start things off
    for data in generateLoader:
        initial_inputs, labels = data
        break
    
    pitchnames = sorted(set(item for item in trainset.notes))
    int_to_note = dict((number, note) for number, note in enumerate(pitchnames))

    final_outputs = []
    for i in range(SONG_LENGTH):
        output, (hn, cn) = myNet(initial_inputs, 1)
        _, predicted = torch.max(output.data, 1)
        
        int_out = predicted.numpy()[0]
        final_outputs.append(int_to_note[int_out])
        for j in range(1, len(initial_inputs[0])):
            initial_inputs[0][j-1] = initial_inputs[0][j]
        initial_inputs[0][sequence_length-1] = torch.from_numpy(to_one_hot(int_out, trainset.num_unique_notes))

create_midi(final_outputs, 0)
