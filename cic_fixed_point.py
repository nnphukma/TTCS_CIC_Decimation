import numpy as np
import matplotlib.pyplot as plt

# --- 1. CẤU HÌNH HỆ THỐNG ---
R = 16
N = 4
M = 1
B_in = 12  # Đầu vào 12-bit
B_growth = int(np.ceil(N * np.log2(R * M)))  # Tăng thêm 16 bit
B_max = B_in + B_growth  # 28 bit

print(f"Độ rộng bit đầu vào: {B_in}")
print(f"Độ rộng bit tối đa (chống tràn): {B_max}")

# Tạo tín hiệu đầu vào: Sóng sin tần số thấp (0.01 * Fs) + Nhiễu tần số cao (để test bộ lọc)
# Sử dụng 1000 mẫu
num_samples = 5000
fs = 1000
t = np.arange(num_samples)
f_sig = 10
f_noise = 200
# Tín hiệu lý tưởng (số thực)
signal_float = 0.5 * np.sin(2 * np.pi * f_sig * t / fs) + 0.2 * np.sin(2 * np.pi * f_noise * t / fs)

# Lượng tử hóa thành số nguyên 12-bit (từ -2048 đến 2047)
input_signal = np.round(signal_float * 2047).astype(int)

# --- 2. MÔ PHỎNG CIC FIXED-POINT ---
# Khởi tạo thanh ghi
integrators = np.zeros(N, dtype=np.int64)
combs = np.zeros(N, dtype=np.int64)
comb_delay = np.zeros((N, M), dtype=np.int64)
decimator_counter = 0

output_signal = []

for i in range(num_samples):
    # A. Integrator Stages (Chạy ở Fs)
    x = input_signal[i]
    for stage in range(N):
        integrators[stage] = integrators[stage] + x
        x = integrators[stage]

    # B. Decimation
    decimator_counter += 1
    if decimator_counter == R:
        decimator_counter = 0

        # C. Comb Stages (Chạy ở Fs/R)
        y = x
        for stage in range(N):
            # Lưu giá trị cũ (trễ M mẫu)
            old_val = comb_delay[stage, M - 1]
            # Dịch trễ
            comb_delay[stage, 1:] = comb_delay[stage, :-1]
            comb_delay[stage, 0] = y

            # Tính toán Comb: x[n] - x[n-M]
            combs[stage] = y - old_val
            y = combs[stage]

        # D. Truncation (Cắt bit)
        # Bỏ 16 bit LSB (tương đương chia cho 2^16)
        out_val = y >> B_growth
        output_signal.append(out_val)

# --- 3. GHI FILE CHO VERILOG TESTBENCH ---
# Lưu ý: Verilog $readmemh đọc file dạng Hex.
with open("stimulus.mem", "w") as f:
    for val in input_signal:
        # Chuyển sang hex 12-bit, nếu âm thì bù 2 (two's complement)
        f.write(f"{val & 0xFFF:03X}\n")

with open("expected.mem", "w") as f:
    for val in output_signal:
        # Chuyển sang hex 12-bit
        f.write(f"{val & 0xFFF:03X}\n")

print("Đã tạo xong file stimulus.mem và expected.mem")

# --- 4. VẼ ĐỒ THỊ SO SÁNH ---
# Vẽ 100 mẫu đầu tiên để dễ nhìn
plt.figure(figsize=(12, 6))

plt.subplot(2, 1, 1)
plt.plot(input_signal[:200], label='Đầu vào (Có nhiễu)', color='orange')
plt.title("Tín hiệu Đầu vào (12-bit)")
plt.grid(True)

plt.subplot(2, 1, 2)
plt.plot(output_signal[:200], label='Đầu ra (Đã lọc)', color='blue')
plt.title("Tín hiệu Đầu ra sau CIC (Đã lọc sạch nhiễu)")
plt.grid(True)

plt.tight_layout()
plt.show()