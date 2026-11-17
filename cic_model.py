import numpy as np
import matplotlib.pyplot as plt
import scipy.signal as signal

# --- THÔNG SỐ THIẾT KẾ ---
R = 16  # Hệ số Decimation
N = 4   # Số tầng (Stages)
M = 1   # Độ trễ vi phân (Differential Delay)

print(f"--- Golden Model CIC (R={R}, N={N}, M={M}) ---")

# 1. Mô phỏng CIC bằng hàm của SciPy (Đáp ứng xung hữu hạn)
# CIC tương đương với bộ lọc FIR có đáp ứng xung là hình chữ nhật
# Tạo hệ số FIR cho 1 tầng: (1 - z^-RM) / (1 - z^-1)
# Thực chất là một xung vuông (rectangular window) dài R*M
h_single = np.ones(R * M)
# Cascade N tầng bằng cách nhân chập (convolve) N lần
h_cic = h_single
for _ in range(N - 1):
    h_cic = np.convolve(h_cic, h_single)

# 2. Tính đáp ứng tần số (Frequency Response)
# Sử dụng hàm freqz để tính toán đáp ứng biên độ
fs = 1.0 # Tần số lấy mẫu chuẩn hóa là 1
w, h = signal.freqz(h_cic, worN=2048, fs=fs)

# Tính độ lợi (Gain) của CIC để chuẩn hóa đồ thị
gain = (R * M) ** N

# 3. Vẽ đồ thị
plt.figure(figsize=(10, 6))
# Chuyển đổi biên độ sang dB
plt.plot(w, 20 * np.log10(np.abs(h) / gain))
plt.title(f'Đáp ứng tần số bộ lọc CIC (R={R}, N={N}, M={M})')
plt.xlabel('Tần số chuẩn hóa (x Fs)')
plt.ylabel('Biên độ (dB)')
plt.grid(True)

# Đánh dấu tần số cắt (Passband edge) và tần số Nyquist mới (Fs_out/2)
plt.axvline(x=0.5/R, color='r', linestyle='--', label=f'Fs_out/2 (Tần số Nyquist mới)')
plt.axvline(x=1/R, color='g', linestyle='--', label=f'Điểm Null đầu tiên (Fs_out)')

plt.legend()
plt.show()