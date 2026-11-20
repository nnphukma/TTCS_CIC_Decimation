
import numpy as np
import matplotlib.pyplot as plt

# ==========================================
# CIC CONFIGURATION
# ==========================================
N = 4
R = 16
M = 1

FS = 1_000_000
FOUT = FS / R
FNYQUIST_OUT = FOUT / 2

# Frequency axis
f = np.linspace(0, FS / 2, 200_001)

# Normalized CIC magnitude response
x = np.pi * f / FS

H = np.ones_like(f)
nonzero = f != 0

H[nonzero] = (
    np.abs(
        np.sin(R * M * x[nonzero])
        / (R * M * np.sin(x[nonzero]))
    ) ** N
)

# Convert to dB
H_dB = 20 * np.log10(np.maximum(H, 1e-15))

# ==========================================
# NULL FREQUENCIES
# ==========================================
null_freqs = np.array([
    k * FS / (R * M)
    for k in range(1, R * M)
])

# ==========================================
# PASSBAND DROOP
# ==========================================
test_freqs = np.array([
    0,
    5_000,
    10_000,
    15_000,
    20_000,
    25_000,
    FNYQUIST_OUT
])

test_x = np.pi * test_freqs / FS

test_H = np.ones_like(test_freqs)
mask = test_freqs != 0

test_H[mask] = np.abs(
    np.sin(R * M * test_x[mask])
    / (R * M * np.sin(test_x[mask]))
) ** N

test_dB = 20 * np.log10(np.maximum(test_H, 1e-15))

print("===== CIC FREQUENCY RESPONSE =====")
print(f"fs       : {FS / 1e6:.3f} MHz")
print(f"fout     : {FOUT / 1e3:.3f} kHz")
print(f"Nyquist  : {FNYQUIST_OUT / 1e3:.3f} kHz")

print("\n===== NULL FREQUENCIES =====")
for i, freq in enumerate(null_freqs, start=1):
    print(f"Null {i}: {freq / 1e3:.3f} kHz")

print("\n===== PASSBAND DROOP =====")
for freq, gain in zip(test_freqs, test_dB):
    print(f"{freq / 1e3:8.3f} kHz : {gain:8.4f} dB")

# ==========================================
# PLOT
# ==========================================
plt.figure(figsize=(12, 6))

plt.plot(f / 1e3, H_dB, linewidth=1.5,
         label="CIC theoretical response")

plt.axvline(
    FNYQUIST_OUT / 1e3,
    linestyle="--",
    label="Output Nyquist"
)

plt.scatter(
    null_freqs / 1e3,
    np.full(len(null_freqs), -150),
    marker="x",
    label="Theoretical nulls"
)

plt.xlim(0, FS / 2 / 1e3)
plt.ylim(-160, 5)

plt.xlabel("Frequency (kHz)")
plt.ylabel("Magnitude (dB)")
plt.title("CIC Frequency Response (N=4, R=16, M=1)")
plt.grid(True)
plt.legend()
plt.tight_layout()

plt.savefig("cic_frequency_response.png", dpi=300)
plt.show()
