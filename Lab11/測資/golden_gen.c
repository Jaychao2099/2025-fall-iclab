#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

#define NUM_IMAGES 128
#define IMG_SIZE 16
#define NUM_PATS 1000

// 影像結構
typedef struct {
    unsigned char pixels[IMG_SIZE][IMG_SIZE];
} Image;

Image RAM[NUM_IMAGES];

// 輔助函式：寫入二進制字串
void write_bin(FILE *fp, int val, int bits) {
    for (int i = bits - 1; i >= 0; i--) {
        fprintf(fp, "%d", (val >> i) & 1);
    }
}

// 產生亂數影像
void init_images() {
    for (int i = 0; i < NUM_IMAGES; i++) {
        for (int r = 0; r < IMG_SIZE; r++) {
            for (int c = 0; c < IMG_SIZE; c++) {
                RAM[i].pixels[r][c] = rand() % 256;
            }
        }
    }
}

// 複製影像
void copy_image(int src_idx, int dst_idx) {
    for (int r = 0; r < IMG_SIZE; r++) {
        for (int c = 0; c < IMG_SIZE; c++) {
            RAM[dst_idx].pixels[r][c] = RAM[src_idx].pixels[r][c];
        }
    }
}

// Operation Implementations
void op_mirror_x(int src, int dst) {
    for(int r=0; r<IMG_SIZE; r++)
        for(int c=0; c<IMG_SIZE; c++)
            RAM[dst].pixels[r][c] = RAM[src].pixels[IMG_SIZE-1-r][c];
}

void op_mirror_y(int src, int dst) {
    for(int r=0; r<IMG_SIZE; r++)
        for(int c=0; c<IMG_SIZE; c++)
            RAM[dst].pixels[r][c] = RAM[src].pixels[r][IMG_SIZE-1-c];
}

void op_transpose(int src, int dst) {
    for(int r=0; r<IMG_SIZE; r++)
        for(int c=0; c<IMG_SIZE; c++)
            RAM[dst].pixels[r][c] = RAM[src].pixels[c][r];
}

void op_sec_transpose(int src, int dst) {
    for(int r=0; r<IMG_SIZE; r++)
        for(int c=0; c<IMG_SIZE; c++)
            RAM[dst].pixels[r][c] = RAM[src].pixels[IMG_SIZE-1-c][IMG_SIZE-1-r];
}

void op_rotate_90(int src, int dst) {
    for(int r=0; r<IMG_SIZE; r++)
        for(int c=0; c<IMG_SIZE; c++)
            RAM[dst].pixels[r][c] = RAM[src].pixels[IMG_SIZE-1-c][r];
}

void op_rotate_180(int src, int dst) {
    for(int r=0; r<IMG_SIZE; r++)
        for(int c=0; c<IMG_SIZE; c++)
            RAM[dst].pixels[r][c] = RAM[src].pixels[IMG_SIZE-1-r][IMG_SIZE-1-c];
}

void op_rotate_270(int src, int dst) {
    for(int r=0; r<IMG_SIZE; r++)
        for(int c=0; c<IMG_SIZE; c++)
            RAM[dst].pixels[r][c] = RAM[src].pixels[c][IMG_SIZE-1-r];
}

void op_shift_right(int src, int dst) {
    for(int r=0; r<IMG_SIZE; r++) {
        for(int c=0; c<IMG_SIZE; c++) {
            if (c >= 5) RAM[dst].pixels[r][c] = RAM[src].pixels[r][c-5];
            else        RAM[dst].pixels[r][c] = RAM[src].pixels[r][4-c]; // Mirror padding
        }
    }
}

void op_shift_left(int src, int dst) {
    for(int r=0; r<IMG_SIZE; r++) {
        for(int c=0; c<IMG_SIZE; c++) {
            if (c <= 10) RAM[dst].pixels[r][c] = RAM[src].pixels[r][c+5];
            else         RAM[dst].pixels[r][c] = RAM[src].pixels[r][26-c]; // Mirror padding (15 - (c-11)) = 26-c
        }
    }
}

void op_shift_up(int src, int dst) {
    for(int r=0; r<IMG_SIZE; r++) {
        for(int c=0; c<IMG_SIZE; c++) {
            if (r <= 10) RAM[dst].pixels[r][c] = RAM[src].pixels[r+5][c];
            else         RAM[dst].pixels[r][c] = RAM[src].pixels[26-r][c]; // Mirror padding
        }
    }
}

void op_shift_down(int src, int dst) {
    for(int r=0; r<IMG_SIZE; r++) {
        for(int c=0; c<IMG_SIZE; c++) {
            if (r >= 5) RAM[dst].pixels[r][c] = RAM[src].pixels[r-5][c];
            else        RAM[dst].pixels[r][c] = RAM[src].pixels[4-r][c]; // Mirror padding
        }
    }
}

// Reordering Helpers
// ZigZag 4x4 Table
const int ZZ4_MAP[16] = {
    0, 1, 4, 8, 5, 2, 3, 6, 9, 12, 13, 10, 7, 11, 14, 15
};

// ZigZag 8x8 Table
const int ZZ8_MAP[64] = {
     0,  1,  8, 16,  9,  2,  3, 10,
    17, 24, 32, 25, 18, 11,  4,  5,
    12, 19, 26, 33, 40, 48, 41, 34,
    27, 20, 13,  6,  7, 14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36,
    29, 22, 15, 23, 30, 37, 44, 51,
    58, 59, 52, 45, 38, 31, 39, 46,
    53, 60, 61, 54, 47, 55, 62, 63
};

// Morton Generator (Interleave bits)
int morton_code(int r, int c, int bits) {
    int res = 0;
    for (int i = 0; i < bits; i++) {
        res |= ((r & (1 << i)) << (i+1)) | ((c & (1 << i)) << i);
    }
    return res; 
    // Usually Morton is interleaving. 
    // But for verification, we need to match the SPEC's "Z-path".
    // Looking at SPEC Fig 15, source indices 0,1,8,9 match coords (0,0),(0,1),(1,0),(1,1).
    // The Z-order path visits (0,0), (0,1), (1,0), (1,1) -> TL, TR, BL, BR recursion.
    // This function is not directly used for the path index, but to verify logic.
    // We will use a recursive generator or hardcoded logic for path.
}

// Generate Z-order coordinates for NxN
void get_morton_coords(int n, int* rows, int* cols) {
    if (n == 1) {
        rows[0] = 0; cols[0] = 0;
        return;
    }
    int half = n / 2;
    int k = 0;
    int sub_size = half * half;
    
    // TL
    int *r_sub = malloc(sub_size * sizeof(int));
    int *c_sub = malloc(sub_size * sizeof(int));
    get_morton_coords(half, r_sub, c_sub);
    
    for(int i=0; i<sub_size; i++) { rows[k] = r_sub[i]; cols[k] = c_sub[i]; k++; } // TL
    for(int i=0; i<sub_size; i++) { rows[k] = r_sub[i]; cols[k] = c_sub[i] + half; k++; } // TR
    for(int i=0; i<sub_size; i++) { rows[k] = r_sub[i] + half; cols[k] = c_sub[i]; k++; } // BL
    for(int i=0; i<sub_size; i++) { rows[k] = r_sub[i] + half; cols[k] = c_sub[i] + half; k++; } // BR
    
    free(r_sub); free(c_sub);
}

void op_zigzag_4(int src, int dst) {
    for(int br=0; br<16; br+=4) {
        for(int bc=0; bc<16; bc+=4) {
            // Process 4x4 block
            for(int i=0; i<16; i++) { // Raster index in Dest
                // Scan Order Index in Src
                int src_flat_idx = ZZ4_MAP[i]; 
                int sr = br + (src_flat_idx / 4);
                int sc = bc + (src_flat_idx % 4);
                
                int dr = br + (i / 4);
                int dc = bc + (i % 4);
                RAM[dst].pixels[dr][dc] = RAM[src].pixels[sr][sc];
            }
        }
    }
}

void op_zigzag_8(int src, int dst) {
    for(int br=0; br<16; br+=8) {
        for(int bc=0; bc<16; bc+=8) {
            for(int i=0; i<64; i++) {
                int src_flat_idx = ZZ8_MAP[i];
                int sr = br + (src_flat_idx / 8);
                int sc = bc + (src_flat_idx % 8);
                
                int dr = br + (i / 8);
                int dc = bc + (i % 8);
                RAM[dst].pixels[dr][dc] = RAM[src].pixels[sr][sc];
            }
        }
    }
}

void op_morton_4(int src, int dst) {
    int r_seq[16], c_seq[16];
    get_morton_coords(4, r_seq, c_seq);
    
    for(int br=0; br<16; br+=4) {
        for(int bc=0; bc<16; bc+=4) {
            for(int i=0; i<16; i++) {
                // i is raster index in Dest
                // Morton sequence gives coordinates in Src
                int sr = br + r_seq[i];
                int sc = bc + c_seq[i];
                
                int dr = br + (i / 4);
                int dc = bc + (i % 4);
                RAM[dst].pixels[dr][dc] = RAM[src].pixels[sr][sc];
            }
        }
    }
}

void op_morton_8(int src, int dst) {
    int r_seq[64], c_seq[64];
    get_morton_coords(8, r_seq, c_seq);
    
    for(int br=0; br<16; br+=8) {
        for(int bc=0; bc<16; bc+=8) {
            for(int i=0; i<64; i++) {
                int sr = br + r_seq[i];
                int sc = bc + c_seq[i];
                
                int dr = br + (i / 8);
                int dc = bc + (i % 8);
                RAM[dst].pixels[dr][dc] = RAM[src].pixels[sr][sc];
            }
        }
    }
}

int main() {
    FILE *f_in = fopen("data.txt", "w");
    FILE *f_cmd = fopen("cmd.txt", "w");
    FILE *f_check = fopen("mem_check.txt", "w");
    
    if(!f_in || !f_cmd || !f_check) { printf("Error opening files\n"); return 1; }
    
    srand(time(NULL));
    init_images();
    
    // Dump initial data
    for(int i=0; i<NUM_IMAGES; i++) {
        for(int r=0; r<IMG_SIZE; r++) {
            for(int c=0; c<IMG_SIZE; c++) {
                fprintf(f_in, "%02x\n", RAM[i].pixels[r][c]);
            }
        }
    }
    
    // Generate Patterns
    for(int p=0; p<NUM_PATS; p++) {
        int opcode = rand() % 4;
        int funct = rand() % 4;
        int ms = rand() % 128;
        int md = rand() % 128;
        
        // Write Cmd
        write_bin(f_cmd, opcode, 2);
        write_bin(f_cmd, funct, 2);
        write_bin(f_cmd, ms, 7);
        write_bin(f_cmd, md, 7);
        fprintf(f_cmd, "\n");
        
        // Execute Model
        int cmd_code = (opcode << 2) | funct;
        switch(cmd_code) {
            case 0: op_mirror_x(ms, md); break;
            case 1: op_mirror_y(ms, md); break;
            case 2: op_transpose(ms, md); break;
            case 3: op_sec_transpose(ms, md); break;
            case 4: op_rotate_90(ms, md); break;
            case 5: op_rotate_180(ms, md); break;
            case 6: op_rotate_270(ms, md); break;
            case 8: op_shift_right(ms, md); break;
            case 9: op_shift_left(ms, md); break;
            case 10: op_shift_up(ms, md); break;
            case 11: op_shift_down(ms, md); break;
            case 12: op_zigzag_4(ms, md); break;
            case 13: op_zigzag_8(ms, md); break;
            case 14: op_morton_4(ms, md); break;
            case 15: op_morton_8(ms, md); break;
            default: copy_image(ms, md); break; // Should not happen based on random % 4
        }
        
        // Dump Golden Result for this pattern (Only the destination image)
        for(int r=0; r<IMG_SIZE; r++) {
            for(int c=0; c<IMG_SIZE; c++) {
                fprintf(f_check, "%02x\n", RAM[md].pixels[r][c]);
            }
        }
    }
    
    fclose(f_in);
    fclose(f_cmd);
    fclose(f_check);
    
    printf("Golden generation done.\n");
    return 0;
}