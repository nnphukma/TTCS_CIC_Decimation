#!/usr/bin/env python3
"""
CIC Decimator - Single-tone V2 reproducible analysis

Configuration:
    Fs_in = 1 MHz, R = 16, N = 4, M = 1
    W_IN = W_OUT = 12 bits
    Input sine: amplitude 1000 LSB
    FFT: 256 points, fundamental bin 37

Usage (from this folder):
    py -3.13 analyze_cic_sine.py

Optional:
    py -3.13 analyze_cic_sine.py --input stimulus_sine.mem \
        --output rtl_sine_output.mem --outdir results
"""
from __future__ import annotations

import argparse
import csv
import math
import re
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt

FS_IN = 1_000_000.0
R = 16
N_STAGES = 4
M = 1
W_IN = 12
W_OUT = 12
INPUT_AMPLITUDE = 1000.0
FFT_SIZE = 256
FUNDAMENTAL_BIN = 37
EXPECTED_INPUT_SAMPLES = 5000
EXPECTED_OUTPUT_SAMPLES = 312


def read_hex_mem(path: Path, bits: int) -> np.ndarray:
    """Read one hex word per line; also tolerates 'index | HEX' text files."""
    text = path.read_text(encoding="utf-8", errors="replace")
    words = re.findall(r"(?m)^\s*(?:\d+\s*\|\s*)?([0-9A-Fa-f]+)\s*$", text)
    if not words:
        raise ValueError(f"No hexadecimal words found in {path}")
    vals = np.asarray([int(w, 16) for w in words], dtype=np.int64)
    mask = (1 << bits) - 1
    if np.any(vals > mask):
        raise ValueError(f"Value outside {bits}-bit range in {path}")
    sign = 1 << (bits - 1)
    return np.where(vals & sign, vals - (1 << bits), vals)


def db10(value: float) -> float:
    return 10.0 * math.log10(value) if value > 0 else float("-inf")


def db20(value: float) -> float:
    return 20.0 * math.log10(value) if value > 0 else float("-inf")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=Path("stimulus_sine.mem"))
    parser.add_argument("--output", type=Path, default=Path("rtl_sine_output.mem"))
    parser.add_argument("--outdir", type=Path, default=Path("results"))
    args = parser.parse_args()

    x = read_hex_mem(args.input, W_IN)
    y = read_hex_mem(args.output, W_OUT)
    if len(x) != EXPECTED_INPUT_SAMPLES:
        raise ValueError(f"Expected {EXPECTED_INPUT_SAMPLES} input samples, got {len(x)}")
    if len(y) != EXPECTED_OUTPUT_SAMPLES:
        raise ValueError(f"Expected {EXPECTED_OUTPUT_SAMPLES} output samples, got {len(y)}")

    fs_out = FS_IN / R
    fin = FUNDAMENTAL_BIN * fs_out / FFT_SIZE

    # Ideal CIC impulse response: convolution of N rectangular windows of R taps.
    h = np.array([1.0])
    for _ in range(N_STAGES):
        h = np.convolve(h, np.ones(R))
    ideal_full = np.convolve(x.astype(float), h) / ((R * M) ** N_STAGES)

    # Testbench samples the first output after input index R-1, then every R samples.
    input_indices = (R - 1) + np.arange(len(y)) * R
    ideal_at_output = ideal_full[input_indices]
    settled_start = math.ceil((len(h) - 1 - (R - 1)) / R)
    settled_start = max(0, settled_start)

    # Compare the fixed-point RTL with floor(ideal CIC output).
    quantized_ideal = np.floor(ideal_at_output)
    comparison_error = y.astype(float) - quantized_ideal
    settled_error = comparison_error[settled_start:]
    if not np.all(settled_error == 0):
        raise AssertionError(
            "RTL does not exactly match floor(ideal CIC) after settling; "
            f"max abs mismatch={np.max(np.abs(settled_error)):.6g} LSB"
        )

    # Use the last 256 samples, all well after settling, for coherent FFT.
    start = len(y) - FFT_SIZE
    segment = y[start:].astype(float)
    spectrum = np.fft.rfft(segment)
    amplitude = np.abs(spectrum) / FFT_SIZE
    amplitude[1:-1] *= 2.0

    # One-sided power spectrum; DC and Nyquist are not doubled.
    power = np.abs(spectrum) ** 2
    power[1:-1] *= 2.0

    fund = FUNDAMENTAL_BIN
    bins = set(range(1, FFT_SIZE // 2 + 1))
    nonfund = bins - {fund}

    # Harmonics that remain below output Nyquist: 2nd and 3rd.
    harmonic_bins = set()
    for order in range(2, 4):
        folded = (order * fund) % FFT_SIZE
        folded = min(folded, FFT_SIZE - folded)
        if folded not in (0, fund) and folded <= FFT_SIZE // 2:
            harmonic_bins.add(folded)

    noise_bins = bins - {fund} - harmonic_bins
    p_fund = power[fund]
    p_noise = float(np.sum(power[list(noise_bins)]))
    p_dist_noise = float(np.sum(power[list(nonfund)]))
    p_harm = float(np.sum(power[list(harmonic_bins)])) if harmonic_bins else 0.0

    snr_db = db10(p_fund / p_noise)
    sinad_db = db10(p_fund / p_dist_noise)
    thd_db = db10(p_harm / p_fund)
    largest_spur_bin = max(nonfund, key=lambda k: amplitude[k])
    sfdr_dbc = db20(amplitude[fund] / amplitude[largest_spur_bin])

    # Theoretical CIC magnitude at the selected input frequency.
    numerator = math.sin(math.pi * R * M * fin / FS_IN)
    denominator = R * M * math.sin(math.pi * fin / FS_IN)
    gain = abs(numerator / denominator) ** N_STAGES
    gain_db = db20(gain)
    theoretical_output_amplitude = INPUT_AMPLITUDE * gain
    measured_output_amplitude = float(amplitude[fund])

    # Save complete sample-by-sample comparison.
    args.outdir.mkdir(parents=True, exist_ok=True)
    with (args.outdir / "rtl_vs_ideal.csv").open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "output_sample_index", "input_sample_index",
            "rtl_output_signed", "ideal_output_float",
            "floor_ideal_output", "rtl_minus_floor_ideal",
            "rtl_minus_ideal_float", "settled"
        ])
        for i, (idx, actual, ideal, qideal, err) in enumerate(
            zip(input_indices, y, ideal_at_output, quantized_ideal, comparison_error)
        ):
            writer.writerow([
                i, int(idx), int(actual), f"{ideal:.12f}",
                int(qideal), f"{err:.0f}", f"{actual-ideal:.12f}",
                int(i >= settled_start)
            ])

    # Save FFT bins and spectrum relative to the fundamental.
    with (args.outdir / "fft_spectrum.csv").open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "bin", "frequency_hz", "amplitude_lsb",
            "relative_to_fundamental_dBc", "one_sided_power"
        ])
        for k in range(len(amplitude)):
            rel = db20(amplitude[k] / amplitude[fund]) if amplitude[k] > 0 else float("-inf")
            writer.writerow([
                k, f"{k * fs_out / FFT_SIZE:.9f}",
                f"{amplitude[k]:.12f}", f"{rel:.6f}", f"{power[k]:.12f}"
            ])

    # FFT plot (exclude DC from the displayed dBc spectrum).
    freq = np.arange(1, len(amplitude)) * fs_out / FFT_SIZE
    rel_db = 20.0 * np.log10(np.maximum(amplitude[1:] / amplitude[fund], 1e-12))
    plt.figure(figsize=(11, 5.5))
    plt.stem(freq / 1000.0, rel_db, basefmt=" ")
    plt.axvline(fin / 1000.0, linestyle="--", linewidth=1, label=f"Fundamental {fin:.2f} Hz")
    plt.xlabel("Frequency (kHz)")
    plt.ylabel("Magnitude relative to fundamental (dBc)")
    plt.title("CIC Decimator - Single-tone V2 FFT (256 points)")
    plt.grid(True, alpha=0.3)
    plt.ylim(-140, 5)
    plt.legend()
    plt.tight_layout()
    plt.savefig(args.outdir / "fft_spectrum.png", dpi=180)
    plt.close()

    # Summary report.
    rms_quant_error = float(np.sqrt(np.mean((y[settled_start:] - ideal_at_output[settled_start:]) ** 2)))
    mean_quant_error = float(np.mean(y[settled_start:] - ideal_at_output[settled_start:]))
    max_quant_error = float(np.max(np.abs(y[settled_start:] - quantized_ideal[settled_start:])))
    summary = f"""CIC DECIMATOR - SINGLE-TONE V2 ANALYSIS
========================================

Configuration
-------------
Input sample rate             : {FS_IN:.0f} Hz
Decimation factor R            : {R}
CIC stages N                   : {N_STAGES}
Differential delay M           : {M}
Input/output width             : {W_IN}/{W_OUT} bits
Output sample rate             : {fs_out:.0f} Hz
Input samples                  : {len(x)}
RTL output samples             : {len(y)}
Input tone frequency           : {fin:.9f} Hz
Input tone amplitude (nominal) : {INPUT_AMPLITUDE:.3f} LSB
FFT length                     : {FFT_SIZE}
Fundamental FFT bin             : {fund}

RTL vs ideal CIC
----------------
CIC FIR-equivalent length      : {len(h)} input samples
Settling output samples skipped: {settled_start}
Settled samples compared       : {len(y) - settled_start}
RTL == floor(ideal)             : {int(np.sum(settled_error == 0))}/{len(settled_error)}
Maximum mismatch vs floor      : {max_quant_error:.6f} LSB
Mean RTL - ideal                : {mean_quant_error:.9f} LSB
RMS RTL - ideal                 : {rms_quant_error:.9f} LSB

FFT amplitude response
----------------------
Theoretical CIC gain             : {gain:.12f}
Theoretical CIC gain             : {gain_db:.9f} dB
Theoretical output amplitude     : {theoretical_output_amplitude:.9f} LSB
Measured FFT fundamental         : {measured_output_amplitude:.9f} LSB
Measured gain                    : {measured_output_amplitude/INPUT_AMPLITUDE:.12f}
Measured gain                    : {db20(measured_output_amplitude/INPUT_AMPLITUDE):.9f} dB
Amplitude difference             : {measured_output_amplitude-theoretical_output_amplitude:.9f} LSB

FFT quality metrics
-------------------
SNR                              : {snr_db:.6f} dB
SINAD                            : {sinad_db:.6f} dB
SFDR                             : {sfdr_dbc:.6f} dBc
THD (2nd and 3rd in-band)        : {thd_db:.6f} dB
Largest non-fundamental spur     : bin {largest_spur_bin}
Largest spur frequency           : {largest_spur_bin*fs_out/FFT_SIZE:.9f} Hz
Largest spur amplitude           : {amplitude[largest_spur_bin]:.9f} LSB
Largest spur relative level      : {-sfdr_dbc:.6f} dBc
Harmonic bins included in THD    : {sorted(harmonic_bins)}

Metric conventions
------------------
- Rectangular window; coherent sampling (256 samples, bin 37).
- DC excluded from AC SNR/SINAD/SFDR calculations.
- SNR excludes fundamental and in-band 2nd/3rd harmonic bins.
- SINAD includes all non-DC, non-fundamental bins.
- THD includes the 2nd and 3rd harmonics within output Nyquist.
- SFDR compares the fundamental with the largest other non-DC FFT bin.
- These metrics describe this specific quantized single-tone V2 test, not
  a universal CIC performance limit.

Files
-----
fft_spectrum.csv : one-sided FFT spectrum
fft_spectrum.png : FFT plot in dBc
rtl_vs_ideal.csv : sample-by-sample RTL/ideal comparison
"""
    (args.outdir / "analysis_summary.txt").write_text(summary, encoding="utf-8")
    print(summary)
    print(f"Saved results to: {args.outdir.resolve()}")


if __name__ == "__main__":
    main()
