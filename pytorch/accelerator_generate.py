
# This file is for creating MIDI files based on what our hot accelerator spits out

import torch
from generate import *
from musicdata import *

# Put the integers output by the accelerator here
accelerator_output = []

if __name__ == "__main__":
    trainset = MusicDataset(midi_file_dir, sequence_length, notes_save_file,
                            prepared_input_save_file, prepared_output_save_file,
                            song_start_indices_save_file, True)

    pitchnames = sorted(set(item for item in trainset.notes))
    int_to_note = dict((number, note) for number, note in enumerate(pitchnames))
    num_unique_notes = len(pitchnames)

    output = []
    for i in accelerator_output:
        output.append(int_to_note[i])
    create_midi(output, 0, True, "accelerator_output")
