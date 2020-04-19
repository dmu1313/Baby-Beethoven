
from Model import *
from MusicData import MusicDataset
import os
from generate import *

import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim

# Set up training and test data
trainset = MusicDataset(midi_file_dir, sequence_length, notes_save_file,
                        prepared_input_save_file, prepared_output_save_file)
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
        if i % 4 == 3:
            print('[%d, %5d] loss: %.3f' %
                  (epoch + 1, i + 1, running_loss / 4))
            running_loss = 0.0

    epoch += 1
    torch.save({
        CHECK_MODEL_STATE:      myNet.state_dict(),
        CHECK_OPTIMIZER_STATE:  optimizer.state_dict(),
        CHECK_EPOCH:            epoch
    }, model_save_file)

"""
    correct = 0
    total = 0
    with torch.no_grad():       # this tells PyTorch that we don't need to keep track
                                # of the gradients because we aren't training
        for data in testloader:
            images, labels = data
            outputs = myNet(images)
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()
            
        print('Epoch %d: Accuracy of the network on the %d test images: %d/%d = %f %%' % (epoch+1, total, correct, total, (100 * correct / total)))
"""

print('Finished Training!')

print("Generating: ")
# Initialize Network
# trainset = MusicDataset(midi_file_dir, sequence_length, notes_save_file,
#                         prepared_input_save_file, prepared_output_save_file)
generateLoader = torch.utils.data.DataLoader(trainset, batch_size=1,
                                        shuffle=True, num_workers=0)

# myNet = Net(trainset.num_unique_notes)
# print(myNet)

# Load Weights
# if os.path.isfile(model_save_file):
#     checkpoint = torch.load(model_save_file)
#     myNet.load_state_dict(checkpoint[CHECK_MODEL_STATE])
    # optimizer.load_state_dict(checkpoint[CHECK_OPTIMIZER_STATE])
    # epoch = checkpoint[CHECK_EPOCH]
    # loss = checkpoint['loss']
# else:
#     print("No saved weights found at: " + model_save_file)
#     assert(True == False)

# torch.set_num_threads(numThreads)

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
        # print(predicted.shape)
        # print(predicted.numpy()[0])
        # print(initial_inputs.shape)
        # print(initial_inputs)
        
        int_out = predicted.numpy()[0]
        final_outputs.append(int_to_note[int_out])
        for j in range(1, len(initial_inputs[0])):
            initial_inputs[0][j-1] = initial_inputs[0][j]
        initial_inputs[0][sequence_length-1] = torch.from_numpy(to_one_hot(int_out, trainset.num_unique_notes))

create_midi(final_outputs, trainset)

##################################
# Let's comptue the total accuracy across the training set

"""
correct = 0
total = 0
with torch.no_grad():       # this tells PyTorch that we don't need to keep track
                            # of the gradients because we aren't training
    for data in trainloader:
        images, labels = data
        outputs = myNet(images)
        _, predicted = torch.max(outputs.data, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()

print('Accuracy of the network on the %d training images: %f %%' % (total, (100 * correct / total)))
"""

##################################
# Now we want to compute the total accuracy across the test set

"""
correct = 0
total = 0
with torch.no_grad():       # this tells PyTorch that we don't need to keep track
                            # of the gradients because we aren't training
    for data in testloader:
        images, labels = data
        outputs = myNet(images)
        _, predicted = torch.max(outputs.data, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()

print('Accuracy of the network on the %d test images: %d/%d = %f %%' % (total, correct, total, (100 * correct / total)))


class_correct = list(0. for i in range(10))
class_total = list(0. for i in range(10))
with torch.no_grad():
    for data in testloader:
        images, labels = data
        outputs = myNet(images)
        _, predicted = torch.max(outputs, 1)
        c = (predicted == labels).squeeze()
        for i in range(4):
            label = labels[i]
            class_correct[label] += c[i].item()
            class_total[label] += 1


for i in range(10):
    print('Accuracy of %10s : %f %%' % (
        classes[i], 100 * class_correct[i] / class_total[i]))

"""
