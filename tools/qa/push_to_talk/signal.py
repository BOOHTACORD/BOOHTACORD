"""A synthetic looped microphone; never captures the user's microphone."""
import math
import struct
import wave


def write_signal(path):
    with wave.open(str(path), 'wb') as target:
        target.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
        target.writeframes(b''.join(struct.pack('<h', round(32767*(.12*math.sin(2*math.pi*440*i/48000)
            + .04*math.sin(2*math.pi*880*i/48000))*(.75+.25*math.sin(2*math.pi*3*i/48000))))
            for i in range(48000*4)))
