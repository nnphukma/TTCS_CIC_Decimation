
import numpy as np

# ==========================================
# CIC CONFIGURATION
# ==========================================
FS = 1_000_000
R = 16
NUM_SAMPLES = 5000

W_IN = 12
AMPLITUDE = 1000

# FFT configuration
FFT_SIZE = 256
TONE_BIN = 37

FOUT = FS / R
TONE_FREQ = TONE_BIN * FOUT / FFT_SIZE

print("===== SINGLE-TONE STIMULUS V2 =====")
print(f"Input sampling rate : {FS} Hz")
print(f"Output sampling rate: {FOUT} Hz")
print(f"Tone frequency      : {TONE_FREQ:.6f} Hz")
print(f"FFT fundamental bin : {TONE_BIN}")
print(f"Input amplitude     : {AMPLITUDE}")

# ==========================================
# GENERATE SINE
# ==========================================
n = np.arange(NUM_SAMPLES)

signal = AMPLITUDE * np.sin(
    2 * np.pi * TONE_FREQ * n / FS
)

samples = np.rint(signal).astype(np.int32)

# Check signed 12-bit range
min_val = -(2 ** (W_IN - 1))
max_val = (2 ** (W_IN - 1)) - 1

if np.any(samples < min_val) or np.any(samples > max_val):
    raise ValueError("Stimulus exceeds signed 12-bit range!")

# ==========================================
# WRITE HEX MEMORY FILE
# ==========================================
with open("stimulus_sine.mem", "w") as f:
    for value in samples:
        hex_value = int(value) & 0xFFF
        f.write(f"{hex_value:03X}\n")

print("\nStimulus generated successfully!")
print(f"Number of samples : {len(samples)}")
print(f"Minimum value     : {samples.min()}")
print(f"Maximum value     : {samples.max()}")
print("Output file       : stimulus_sine.mem")
