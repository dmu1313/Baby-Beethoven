#Import Libraries ----------------------------------------
#import torch
#import torchvision
from music21 import * 
import numpy as np
import os
import pickle

#Parameters-----------------------------------------------
path = '/Users/Hannah Kim/Desktop/ESE587/FinalProject/MidiFiles/'
sequence_length = 100


#Method for reading MIDI files with music21---------------
#writes notes and chords to an array
def readMIDIfile(filePath):
    print("Reading MIDI files!")
    
    notes=[]
    
    #For every file in folder
    for file in os.listdir(filePath):
        if file.endswith(".mid"):
            print("Parsing %s" % filePath+file)
            
            #Open MIDI file
            midiFile = converter.parse(filePath+file)
            notes_to_parse = None
            
            p = instrument.partitionByInstrument(midiFile)
            
            for part in p.parts:
                #Only extract Piano
                notes_to_parse = part.recurse()
           
                for element in notes_to_parse:
                    if isinstance(element, note.Note):
                        notes.append(str(element.pitch))
                    elif isinstance(element, chord.Chord):
                        notes.append('.'.join(str(n) for n in element.normalOrder))
                    elif isinstance(element, note.Rest):
                        notes.append(element.name)
                        
    with open('data/notes','wb') as filepath
        pickle.dump(notes, filepath)
                
    return notes
    
#copied from Skuldur:------------------------------------
#creates arrays for network input/output and maps notes to numbers
def prepareData(notes, length):

    # get all pitch names
    pitchnames = sorted(set(item for item in notes))
    
    # create a dictionary to map pitches to integers
    note_to_int = dict((note, number) for number, note in enumerate(pitchnames))
    
    
    network_input = []
    network_output = []
    
    # create input sequences and the corresponding outputs
    for i in range(0, len(notes) - sequence_length, 1):
        sequence_in = notes[i:i + sequence_length]
        sequence_out = notes[i + sequence_length]
        
        network_input.append([note_to_int[char] for char in sequence_in])
        network_output.append(note_to_int[sequence_out])
        
    n_patterns = len(network_input)
    
    # reshape the input into a format compatible with LSTM layers
    network_input = np.reshape(network_input, (n_patterns, sequence_length, 1))
    
    # normalize input??????
    #network_input = network_input / float(length)
    
    #one hot encode output???????? (Using keras)
    #network_output = np_utils.to_categorical(network_output)
    
    return (network_input, network_output)
    

notes = readMIDIfile(path)
notes_len = len(set(notes))
network_in, network_out = prepareData(notes, notes_len)

print("This is the input array: \n", network_in)
#print("input size:", network_in.shape)
#print("output size:", len(network_out))

print("\n\nThis is the output array: \n" , network_out)


#copied from Skuldur:-------------------------------------
#From "generate_notes" module
#Gets a random sequence from an input array and passes it
#thru the network to get the next expected note, which is 
#then appended to the original input and fed back in (repeat this 500 tiems)
def generateMusic():
    





#copied from Skuldur:-------------------------------------
#From "create_midi" module
#Takes the string of notes output of makeMusic(), converts it
#to note and chord objects, and then written to midi file
def createMIDI(network_output):
    offset = 0
    output_notes = []
    
    #Convert to notes
    
    
    #Create MIDI file

    for pattern in network_output:
        # pattern is a chord
        if ('.' in pattern) or pattern.isdigit():
            notes_in_chord = pattern.split('.')
            notes = []
            for current_note in notes_in_chord:
                new_note = note.Note(int(current_note))
                new_note.storedInstrument = instrument.Piano()
                notes.append(new_note)
            new_chord = chord.Chord(notes)
            new_chord.offset = offset
            output_notes.append(new_chord)
        # pattern is a note
        else:
            new_note = note.Note(pattern)
            new_note.offset = offset
            new_note.storedInstrument = instrument.Piano()
            output_notes.append(new_note)

        # increase offset each iteration so that notes do not stack
        offset += 0.5

    midi_stream = stream.Stream(output_notes)

    midi_stream.write('midi', fp='test_output.mid')




