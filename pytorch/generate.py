
from model import *
from musicdata import MusicDataset
import os
from music21 import *
from fractions import Fraction
import random

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

# Song length can't be too long. Does not generate long music well.
SONG_LENGTH = 80

def oneHotIndex(vector):
    for i in range(len(vector)):
        if vector[i] == 0:
            continue
        elif vector[i] == 1:
            return i
        else:
            print("Invalid one hot vector, vector[" +  str(i) + "] = " + str(vector[i]))
            return -1
    print("Bad one hot vector. We shouldn't reach here.")
    return -1

def to_one_hot(values, num_classes):
    return np.eye(num_classes, dtype='float')[values]

def getDurationFloat(durationString):
    if "/" in durationString:
        values = durationString.split("/")
        return Fraction(int(values[0]), int(values[1]))
        # return float(float(values[0]) / float(values[1]))
    return float(durationString)

def create_midi(prediction_output, songNum, useCustomFilename=False, filename=""):
    offset = 0
    output_notes = []
    # create note and chord objects based on the values generated by the model
    for note_full_representation in prediction_output:
        pattern = note_full_representation.split(",")[0]
        duration = note_full_representation.split(",")[1]
        # print("Duration: " + duration + ", " + str(getDurationFloat(duration)))
        duration = getDurationFloat(duration)
        

        # pattern is a chord
        if ('.' in pattern) or pattern.isdigit():
            notes_in_chord = pattern.split('.')
            notes = []
            for current_note in notes_in_chord:
                new_note = note.Note(int(current_note))
                new_note.quarterLength = duration
                new_note.storedInstrument = instrument.Piano()
                notes.append(new_note)
            new_chord = chord.Chord(notes)
            new_chord.quarterLength = duration
            new_chord.offset = offset
            output_notes.append(new_chord)

            # if duration > 0.55:
            #     offset += 0.5
            # else:
            #     offset += duration
        # pattern is a rest
        elif('rest' in pattern):
            new_rest = note.Rest(pattern)
            new_rest.quarterLength = duration
            new_rest.offset = offset
            new_rest.storedInstrument = instrument.Piano() #???
            output_notes.append(new_rest)

            # offset += duration
        # pattern is a note
        else:
            new_note = note.Note(pattern)
            new_note.quarterLength = duration
            new_note.offset = offset
            new_note.storedInstrument = instrument.Piano()
            output_notes.append(new_note)

            # if duration > 0.55:
            #     offset += 0.5
            # else:
            #     offset += duration


        offset += duration
        # increase offset each iteration so that notes do not stack
        # if duration >= 1.0:
        #     offset += 0.00
        # else:
        #     offset += duration

    midi_stream = stream.Stream()
    tempo_mm = tempo.MetronomeMark(number=72)
    timeSig = meter.TimeSignature('4/4')
    
    midi_stream.append(tempo_mm)
    midi_stream.append(timeSig)
    midi_stream.append(output_notes)
    # print(output_notes)

    if useCustomFilename:
        song_save_file = "./saves/" + filename + ".mid"
    else:
        song_save_file = generate_save_file_prefix + '_' + str(songNum) + generate_save_file_extension
    midi_stream.write('midi', fp=song_save_file)

def generate(numSongs, genRandom=False):
    # Initialize Network
    trainset = MusicDataset(midi_file_dir, sequence_length, notes_save_file,
                            prepared_input_save_file, prepared_output_save_file,
                            song_start_indices_save_file, True)
    generateLoader = torch.utils.data.DataLoader(trainset, batch_size=1,
                                            shuffle=True, num_workers=0)

    myNet = Net(trainset.num_unique_notes)
    print(myNet)

    # Load Weights
    if os.path.isfile(model_save_file):
        checkpoint = torch.load(model_save_file)
        myNet.load_state_dict(checkpoint[CHECK_MODEL_STATE])
        # optimizer.load_state_dict(checkpoint[CHECK_OPTIMIZER_STATE])
        # epoch = checkpoint[CHECK_EPOCH]
        # loss = checkpoint['loss']
    else:
        print("No saved weights found at: " + model_save_file)
        assert(True == False)

    torch.set_num_threads(numThreads)

    myNet.eval()

    with torch.no_grad():
        inputs = []
        counter = 0

        if genRandom == False:
            for data in generateLoader:
                initial_inputs, labels = data
                inputs.append(initial_inputs)
                counter += 1
                if (counter == numSongs):
                    break
        
        pitchnames = sorted(set(item for item in trainset.notes))
        int_to_note = dict((number, note) for number, note in enumerate(pitchnames))

        # Generate a <sequence_length> length stream of random one-hot vectors as input
        num_unique_notes = len(pitchnames)
        
        if genRandom:
            for i in range(numSongs):
                randSequence = []
                for note_num in range(sequence_length):
                    randIndex = random.randint(0, num_unique_notes-1) # Generate random int in range, inclusive
                    randSequence.append([1 if randIndex == j else 0 for j in range(num_unique_notes)])
                npRandSeq = np.reshape(np.array(randSequence), (1, sequence_length, num_unique_notes))
                torchSeq = torch.from_numpy(npRandSeq)
                inputs.append(torchSeq)

        # Debugging output so that we can determine what notes were passed to the network initially
        for i in range(len(inputs)):
            generated_indices = "song " + str(i) + " (input): "
            for j in range(sequence_length):
                generated_indices = generated_indices + str(oneHotIndex(inputs[i][0][j])) + ", "
            print(generated_indices)

        for songNum in range(numSongs):
            final_outputs = []
            debug_outputs = []
            for i in range(SONG_LENGTH):
                output, (hn, cn) = myNet(inputs[songNum], 1)
                _, predicted = torch.max(output.data, 1)
                
                int_out = predicted.numpy()[0]
                final_outputs.append(int_to_note[int_out])
                debug_outputs.append(int_out)
                for j in range(1, len(inputs[songNum][0])):
                    inputs[songNum][0][j-1] = inputs[songNum][0][j]
                inputs[songNum][0][sequence_length-1] = torch.from_numpy(to_one_hot(int_out, trainset.num_unique_notes))

            generated_outputs = "song " + str(songNum) + " (output): "
            for i in range(len(debug_outputs)):
                generated_outputs = generated_outputs + str(debug_outputs[i]) + ", "
            print(generated_outputs)

            create_midi(final_outputs, songNum)

if __name__ == "__main__":
    generate(15, False)
