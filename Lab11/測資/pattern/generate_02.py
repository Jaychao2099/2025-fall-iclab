import random
import os

# ==========================================
# 設定參數
# ==========================================
NUM_IMAGES = 128
IMG_SIZE = 16
NUM_CMDS = 10000  # 產生 10000 筆指令
OUTPUT_DIR = "./verification_data"

if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

# ==========================================
# 輔助函式: 產生樣式表 (Look-up Tables)
# ==========================================

def get_zigzag_4x4_order():
    # 4x4 Zig-zag path indices (0~15)
    return [
        0, 1, 4, 8, 
        5, 2, 3, 6, 
        9, 12, 13, 10, 
        7, 11, 14, 15
    ]

def get_morton_4x4_order():
    # 4x4 Morton (Z-order) path indices
    return [
         0,  1,  4,  5,
         2,  3,  6,  7,
         8,  9, 12, 13,
        10, 11, 14, 15
    ]

def get_zigzag_8x8_order():
    # Standard 8x8 Zigzag
    return [
         0,  1,  8, 16,  9,  2,  3, 10,
        17, 24, 32, 25, 18, 11,  4,  5,
        12, 19, 26, 33, 40, 48, 41, 34,
        27, 20, 13,  6,  7, 14, 21, 28,
        35, 42, 49, 56, 57, 50, 43, 36,
        29, 22, 15, 23, 30, 37, 44, 51,
        58, 59, 52, 45, 38, 31, 39, 46,
        53, 60, 61, 54, 47, 55, 62, 63
    ]

def get_morton_8x8_order():
    # 8x8 Morton (Recursive Z)
    path = []
    for k in range(64):
        r = 0
        c = 0
        if k & 1: c |= 1
        if k & 2: r |= 1
        if k & 4: c |= 2
        if k & 8: r |= 2
        if k & 16: c |= 4
        if k & 32: r |= 4
        path.append(r * 8 + c)
    return path

# ==========================================
# 核心運算類別
# ==========================================

class GTE_Simulator:
    def __init__(self):
        self.images = [] # 128 images, each is 16x16 list (2D)
        self.init_data()
        
        # Pre-calculate Pattern maps
        self.zz4_map = self.build_block_map(4, get_zigzag_4x4_order())
        self.zz8_map = self.build_block_map(8, get_zigzag_8x8_order())
        self.mo4_map = self.build_block_map(4, get_morton_4x4_order())
        self.mo8_map = self.build_block_map(8, get_morton_8x8_order())

    def init_data(self):
        # 隨機產生 128 張 16x16 圖片
        for _ in range(NUM_IMAGES):
            img = [random.randint(0, 255) for _ in range(IMG_SIZE * IMG_SIZE)]
            self.images.append(self.to_2d(img))

    def to_2d(self, flat_list):
        return [flat_list[i*IMG_SIZE:(i+1)*IMG_SIZE] for i in range(IMG_SIZE)]

    def to_1d(self, grid_2d):
        return [pixel for row in grid_2d for pixel in row]

    def build_block_map(self, block_size, pattern):
        mapping = [0] * 256
        steps = IMG_SIZE // block_size
        
        for br in range(steps): 
            for bc in range(steps): 
                base_r = br * block_size
                base_c = bc * block_size
                
                block_raster_indices = []
                for r in range(block_size):
                    for c in range(block_size):
                        block_raster_indices.append((base_r + r) * IMG_SIZE + (base_c + c))
                
                for i in range(len(pattern)):
                    dest_global_idx = block_raster_indices[i]
                    src_global_idx = block_raster_indices[pattern[i]]
                    mapping[dest_global_idx] = src_global_idx
        return mapping

    # --- Operations ---

    def op_mirror(self, img, axis):
        new_img = [[0]*16 for _ in range(16)]
        for r in range(16):
            for c in range(16):
                if axis == 'X': new_img[r][c] = img[15-r][c]
                else: new_img[r][c] = img[r][15-c]
        return new_img

    def op_transpose(self, img, type='MAIN'):
        new_img = [[0]*16 for _ in range(16)]
        for r in range(16):
            for c in range(16):
                if type == 'MAIN': new_img[c][r] = img[r][c]
                else: new_img[15-c][15-r] = img[r][c]
        return new_img

    def op_rotate(self, img, angle):
        new_img = [[0]*16 for _ in range(16)]
        for r in range(16):
            for c in range(16):
                if angle == 90: new_img[c][15-r] = img[r][c]
                elif angle == 180: new_img[15-r][15-c] = img[r][c]
                elif angle == 270: new_img[15-c][r] = img[r][c]
        return new_img

    def op_shift(self, img, direction):
        new_img = [[0]*16 for _ in range(16)]
        amt = 5
        for r in range(16):
            for c in range(16):
                val = 0
                if direction == 'RS':
                    # Right Shift: 左邊補鏡像
                    if c >= amt: val = img[r][c-amt]
                    else: pad_src = (amt - 1) - c; val = img[r][pad_src]
                elif direction == 'LS':
                    # Left Shift: 右邊補鏡像
                    if c <= 15 - amt: val = img[r][c+amt]
                    else: gap = c - (16 - amt); pad_src = 15 - gap; val = img[r][pad_src]
                elif direction == 'US':
                    # Up Shift: 下方補鏡像 (【修正處】)
                    if r <= 15 - amt: val = img[r+amt][c]
                    else: 
                        gap = r - (16 - amt)
                        pad_src = 15 - gap # 修正：抓取下方邊界的鏡像
                        val = img[pad_src][c]
                elif direction == 'DS':
                    # Down Shift: 上方補鏡像 (【修正處】)
                    if r >= amt: val = img[r-amt][c]
                    else: 
                        pad_src = (amt - 1) - r # 修正：抓取上方邊界的鏡像
                        val = img[pad_src][c]
                new_img[r][c] = val
        return new_img

    def op_reorder(self, img, mapping):
        flat_src = self.to_1d(img)
        flat_dst = [0] * 256
        for dst_i in range(256):
            src_i = mapping[dst_i]
            flat_dst[dst_i] = flat_src[src_i]
        return self.to_2d(flat_dst)

    def execute_cmd(self, opcode, funct, ms, md):
        src_img = self.images[ms] # This is a reference to the current list
        res_img = []
        op_name = ""

        if opcode == 0:
            if funct == 0: op_name = "MX"; res_img = self.op_mirror(src_img, 'X')
            elif funct == 1: op_name = "MY"; res_img = self.op_mirror(src_img, 'Y')
            elif funct == 2: op_name = "TRP"; res_img = self.op_transpose(src_img, 'MAIN')
            elif funct == 3: op_name = "STRP"; res_img = self.op_transpose(src_img, 'SEC')
        elif opcode == 1:
            if funct == 0: op_name = "R90"; res_img = self.op_rotate(src_img, 90)
            elif funct == 1: op_name = "R180"; res_img = self.op_rotate(src_img, 180)
            elif funct == 2: op_name = "R270"; res_img = self.op_rotate(src_img, 270)
        elif opcode == 2:
            if funct == 0: op_name = "RS"; res_img = self.op_shift(src_img, 'RS')
            elif funct == 1: op_name = "LS"; res_img = self.op_shift(src_img, 'LS')
            elif funct == 2: op_name = "US"; res_img = self.op_shift(src_img, 'US')
            elif funct == 3: op_name = "DS"; res_img = self.op_shift(src_img, 'DS')
        elif opcode == 3:
            if funct == 0: op_name = "ZZ4"; res_img = self.op_reorder(src_img, self.zz4_map)
            elif funct == 1: op_name = "ZZ8"; res_img = self.op_reorder(src_img, self.zz8_map)
            elif funct == 2: op_name = "MO4"; res_img = self.op_reorder(src_img, self.mo4_map)
            elif funct == 3: op_name = "MO8"; res_img = self.op_reorder(src_img, self.mo8_map)

        # Update Memory
        self.images[md] = res_img
        return op_name, res_img

# ==========================================
# 主程式
# ==========================================

def print_matrix_hex(f, flat_data, label):
    """
    將 1D Array 格式化為 16x16 Hex 矩陣並寫入檔案
    """
    f.write(f"{label}:\n")
    # 畫上方框線
    f.write("    " + " ".join([f"{i:02X}" for i in range(16)]) + "\n")
    f.write("   " + "-" * 48 + "\n")
    
    for r in range(16):
        row_data = flat_data[r*16 : (r+1)*16]
        row_str = " ".join([f"{x:02X}" for x in row_data])
        f.write(f"{r:02X} | {row_str}\n")
    f.write("\n")

def main():
    sim = GTE_Simulator()
    
    f_in = open(os.path.join(OUTPUT_DIR, "input.txt"), "w")
    f_out = open(os.path.join(OUTPUT_DIR, "output.txt"), "w")
    f_debug = open(os.path.join(OUTPUT_DIR, "debug.txt"), "w")

    print(f"Generating data for {NUM_IMAGES} images and {NUM_CMDS} commands...")

    # 1. 寫入初始 Image Data (128 images)
    for img in sim.images:
        flat = sim.to_1d(img)
        for pix in flat:
            f_in.write(f"{pix:02X}\n")

    # 2. 產生指令並執行
    valid_ops = [
        (0,0), (0,1), (0,2), (0,3),
        (1,0), (1,1), (1,2), 
        (2,0), (2,1), (2,2), (2,3),
        (3,0), (3,1), (3,2), (3,3)
    ]

    f_debug.write("=== Lab 11 GTE Debug Log ===\n\n")

    for i in range(NUM_CMDS):
        op, funct = random.choice(valid_ops)
        ms = random.randint(0, 127)
        md = random.randint(0, 127)

        # 執行前先備份 Source Image 的數據 (Flattened)
        src_flat_before = sim.to_1d(sim.images[ms])

        # 執行模擬
        op_name, result_img = sim.execute_cmd(op, funct, ms, md)
        flat_res = sim.to_1d(result_img)

        # 寫入 input.txt (Command Hex)
        cmd_val = (op << 16) | (funct << 14) | (ms << 7) | md
        f_in.write(f"{cmd_val:05X}\n")

        # 寫入 output.txt (Golden Answer)
        f_out.write(f"// Cmd {i}: {op_name} Src={ms} Dst={md}\n")
        for pix in flat_res:
            f_out.write(f"{pix:3d} ")
        f_out.write("\n")

        # 寫入 debug.txt (包含轉換前後的圖片矩陣)
        f_debug.write("=" * 60 + "\n")
        f_debug.write(f"CMD #{i}: {op_name} (Op={op}, Funct={funct})\n")
        f_debug.write(f"Source Index: {ms}  --->  Dest Index: {md}\n")
        f_debug.write("-" * 60 + "\n")
        
        # 使用 Hex 顯示矩陣，方便對齊
        print_matrix_hex(f_debug, src_flat_before, f"Source Image (Index {ms}) [BEFORE]")
        print_matrix_hex(f_debug, flat_res,        f"Result Image (Index {md}) [AFTER]")
        
        f_debug.write("\n")

    f_in.close()
    f_out.close()
    f_debug.close()
    print("Done! Files generated in ./verification_data/")

if __name__ == "__main__":
    main()