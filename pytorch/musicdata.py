
import torch
from torch.utils.data import Dataset
import os
import sys
import numpy as np
from music21 import *
import pickle
import h5py
from fractions import Fraction

input_dataset_name = 'input'
output_dataset_name = 'output'

allowed_values = [Fraction(1, 6), 0.25, Fraction(1, 3), 0.5, Fraction(2, 3), 0.75, 1.0, Fraction(4, 3), 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]

def roundLength(quarterLength):
    assert(quarterLength >= 0.0 and quarterLength <= 5.0)
    closestIndex = 0
    closestDiff = 1000
    for i in range(len(allowed_values)):
        diff = abs(allowed_values[i] - quarterLength)
        if diff < closestDiff:
            closestDiff = diff
            closestIndex = i
    return allowed_values[closestIndex]

class MusicDataset(Dataset):

    def readMidiFiles(self, dir):
        # Store all the notes of all our songs in "notes"
        # Store the index of the first note of each song in "notes" into "song_start_indices"
        notes=[]
        song_start_indices = []

        #For every file in folder
        for file in os.listdir(dir):
            if file.endswith(".mid"):
                print("Parsing %s" % dir+file)

                song_start_indices.append(len(notes))
                
                #Open MIDI file
                midiFile = converter.parse(dir+file)
                notes_to_parse = None
                
                # p = instrument.partitionByInstrument(midiFile)
                
                # for part in p.parts:
                    #Only extract Piano
                # notes_to_parse = part.recurse()
                notes_to_parse = midiFile.recurse()

                for element in notes_to_parse:
                    if element.quarterLength > 5.0 or element.quarterLength < 0.1:
                        continue

                    elementLength = roundLength(element.quarterLength)
                    
                    if isinstance(element, note.Note):
                        notes.append(str(element.pitch) + "," + str(elementLength))
                    elif isinstance(element, chord.Chord):
                        sortedNormalOrder = [i for i in element.normalOrder]
                        sortedNormalOrder.sort()
                        notes.append(('.'.join(str(n) for n in sortedNormalOrder)) + "," + str(elementLength))
                    elif isinstance(element, note.Rest):
                        notes.append(element.name + "," + str(elementLength))
        
        with open(self.notes_save_file, 'wb') as file:
            pickle.dump(notes, file)
        with open(self.song_start_indices_save_file, 'wb') as file:
            pickle.dump(song_start_indices, file)

        return notes, song_start_indices

    def prepareData(self, notes, num_unique_notes, song_start_indices):
        # get all pitch names
        pitchnames = sorted(set(item for item in notes))
        
        # create a dictionary to map pitches to integers
        note_to_int = dict((note, number) for number, note in enumerate(pitchnames))
        
        network_input = []
        network_output = []
        
        # create input sequences and the corresponding outputs
        for j in range(len(song_start_indices)):
            print("Generating inputs/outputs for song " + str(j))
            if (j + 1 == len(song_start_indices)):
                song_end = len(notes)
            else:
                song_end = song_start_indices[j+1]

            for i in range(song_start_indices[j], song_end - self.sequence_length, 1):
                sequence_in = notes[i:i + self.sequence_length]
                sequence_out = notes[i + self.sequence_length]

                # [self.to_one_hot(note_to_int[char], num_unique_notes) for char in sequence_in]
                # np.asarray(list, dtype=np.float32)
                network_input.append([ [1 if note_to_int[char]==index else 0 for index in range(num_unique_notes)] for char in sequence_in])
                network_output.append(note_to_int[sequence_out])
                del sequence_in
                del sequence_out
            
        n_patterns = len(network_input)
        
        # reshape the input into a format compatible with LSTM layers
        network_input_reshaped = np.reshape(network_input, (n_patterns, self.sequence_length, num_unique_notes))
        del network_input
        # # normalize input
        # network_input = network_input / float(num_unique_notes)
        # network_output = self.to_one_hot(network_output, num_unique_notes)
        
        print(network_input_reshaped.dtype)

        with h5py.File(self.prepared_input_save_file, "a") as file:
            if file.get(input_dataset_name):
                del file[input_dataset_name]
            file.create_dataset(input_dataset_name, data=network_input_reshaped)
            # file[input_dataset_name] = network_input_reshaped
        with h5py.File(self.prepared_output_save_file, "a") as file:
            if file.get(output_dataset_name):
                del file[output_dataset_name]
            file.create_dataset(output_dataset_name, data=network_output)
            # file[output_dataset_name] = network_output

        return (network_input_reshaped, network_output)

    def to_one_hot(self, values, num_classes):
        return np.eye(num_classes, dtype='float')[values]

    def __init__(self, dir, sequence_length, notes_save_file,
                prepared_input_save_file, prepared_output_save_file,
                song_start_indices_save_file, stream=False):
        self.dir = dir
        self.sequence_length = sequence_length
        self.notes_save_file = notes_save_file
        self.prepared_input_save_file = prepared_input_save_file
        self.prepared_output_save_file = prepared_output_save_file
        self.song_start_indices_save_file = song_start_indices_save_file
        self.stream = stream

        if os.path.isfile(notes_save_file):
            with open(notes_save_file, 'rb') as file:
                notes = pickle.load(file)
            with open(song_start_indices_save_file, 'rb') as file:
                song_start_indices = pickle.load(file)
        else:
            notes, song_start_indices = self.readMidiFiles(dir)

        self.num_unique_notes = len(set(notes))
        print("num unique notes: " + str(self.num_unique_notes))
        print("num songs: " + str(len(song_start_indices)))
        print(song_start_indices)

        if os.path.isfile(prepared_input_save_file) and os.path.isfile(prepared_output_save_file):
            if stream:
                self.input_file = h5py.File(self.prepared_input_save_file, "r")
                self.output_file = h5py.File(self.prepared_output_save_file, "r")
                inputs = self.input_file[input_dataset_name]
                outputs = self.output_file[output_dataset_name]
            else:
                with h5py.File(self.prepared_input_save_file, "r") as file:
                    inputs = file[input_dataset_name][:]
                with h5py.File(self.prepared_output_save_file, "r") as file:
                    outputs = file[output_dataset_name][:]
        else:
            inputs, outputs = self.prepareData(notes, self.num_unique_notes, song_start_indices)

        assert(len(inputs) == len(outputs))
        self.notes = notes
        self.inputs = inputs
        self.outputs = outputs

    def __len__(self):
        return len(self.inputs)

    def __getitem__(self, idx):
        return (self.inputs[idx], self.outputs[idx])
