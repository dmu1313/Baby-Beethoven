
import torch
from torch.utils.data import Dataset
import os
import sys
import numpy as np
from music21 import *
import pickle

class MusicDataset(Dataset):

    def readMidiFiles(self, dir):
        notes=[]
        #For every file in folder
        for file in os.listdir(dir):
            if file.endswith(".mid"):
                print("Parsing %s" % dir+file)
                
                #Open MIDI file
                midiFile = converter.parse(dir+file)
                notes_to_parse = None
                
                # p = instrument.partitionByInstrument(midiFile)
                
                # for part in p.parts:
                    #Only extract Piano
                # notes_to_parse = part.recurse()
                notes_to_parse = midiFile.recurse()

                for element in notes_to_parse:
                    if isinstance(element, note.Note):
                        notes.append(str(element.pitch) + "," + str(element.quarterLength))
                    elif isinstance(element, chord.Chord):
                        notes.append(('.'.join(str(n) for n in element.normalOrder)) + "," + str(element.quarterLength))
                    elif isinstance(element, note.Rest):
                        notes.append(element.name + "," + str(element.quarterLength))
        
        with open(self.notes_save_file, 'wb') as file:
            pickle.dump(notes, file)

        return notes

    def prepareData(self, notes, num_unique_notes):
        # get all pitch names
        pitchnames = sorted(set(item for item in notes))
        
        # create a dictionary to map pitches to integers
        note_to_int = dict((note, number) for number, note in enumerate(pitchnames))
        
        network_input = []
        network_output = []
        
        # create input sequences and the corresponding outputs
        for i in range(0, len(notes) - self.sequence_length, 4):
            sequence_in = notes[i:i + self.sequence_length]
            sequence_out = notes[i + self.sequence_length]

            # [self.to_one_hot(note_to_int[char], num_unique_notes) for char in sequence_in]
            # np.asarray(list, dtype=np.float32)
            network_input.append([ [1 if note_to_int[char]==index else 0 for index in range(num_unique_notes)] for char in sequence_in])
            network_output.append(note_to_int[sequence_out])
            
        n_patterns = len(network_input)
        
        # reshape the input into a format compatible with LSTM layers
        network_input = np.reshape(network_input, (n_patterns, self.sequence_length, num_unique_notes))

        # # normalize input
        # network_input = network_input / float(num_unique_notes)
        # network_output = self.to_one_hot(network_output, num_unique_notes)
        
        with open(self.prepared_input_save_file, 'wb') as file:
            pickle.dump(network_input, file)
        with open(self.prepared_output_save_file, 'wb') as file:
            pickle.dump(network_output, file)

        return (network_input, network_output)

    def to_one_hot(self, values, num_classes):
        return np.eye(num_classes, dtype='float')[values]

    def __init__(self, dir, sequence_length, notes_save_file,
                prepared_input_save_file, prepared_output_save_file):
        self.dir = dir
        self.sequence_length = sequence_length
        self.notes_save_file = notes_save_file
        self.prepared_input_save_file = prepared_input_save_file
        self.prepared_output_save_file = prepared_output_save_file

        if os.path.isfile(notes_save_file):
            with open(notes_save_file, 'rb') as file:
                notes = pickle.load(file)
        else:
            notes = self.readMidiFiles(dir)

        self.num_unique_notes = len(set(notes))
        print("num unique notes: " + str(self.num_unique_notes))

        if os.path.isfile(prepared_input_save_file) and os.path.isfile(prepared_output_save_file):
            with open(prepared_input_save_file, 'rb') as file:
                inputs = pickle.load(file)
            with open(prepared_output_save_file, 'rb') as file:
                outputs = pickle.load(file)
        else:
            inputs, outputs = self.prepareData(notes, self.num_unique_notes)

        assert(len(inputs) == len(outputs))
        self.notes = notes
        self.inputs = inputs
        self.outputs = outputs

    def __len__(self):
        return len(self.inputs)

    def __getitem__(self, idx):
        return (self.inputs[idx], self.outputs[idx])