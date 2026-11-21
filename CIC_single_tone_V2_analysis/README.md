# CIC Single-tone V2: reproducible analysis

## Contents
- `stimulus_sine.mem`: 5,000 signed 12-bit input samples (hex, two's complement).
- `rtl_sine_output.mem`: 312 signed 12-bit output samples captured from RTL simulation.
- `analyze_cic_sine.py`: reproducible Python analysis.
- `results/analysis_summary.txt`: numerical summary.
- `results/fft_spectrum.csv`: FFT amplitude and power per bin.
- `results/fft_spectrum.png`: FFT spectrum in dBc.
- `results/rtl_vs_ideal.csv`: sample-by-sample comparison with the ideal CIC FIR equivalent.

## Requirements
Python 3.10+ with NumPy and Matplotlib.

On Windows:
```cmd
py -3.13 -m pip install numpy matplotlib
```

## Run
Open a terminal in this folder and run:
```cmd
py -3.13 analyze_cic_sine.py
```

To select another output folder:
```cmd
py -3.13 analyze_cic_sine.py --outdir results
```

The script checks the sample counts, verifies that all settled RTL samples equal
`floor(ideal CIC output)`, computes the coherent 256-point FFT, writes the
spectrum and sample comparison CSV files, and saves the FFT plot.

## FFT conventions
The FFT uses the last 256 output samples (indices 56..311), with a rectangular
window. The tone is coherent at bin 37. DC is excluded from AC metrics.
SNR excludes the fundamental and the 2nd/3rd in-band harmonics; SINAD includes
all non-DC bins except the fundamental. THD includes the 2nd/3rd in-band
harmonics. SFDR uses the largest non-fundamental non-DC bin.
