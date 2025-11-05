#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

static inline void printBinary(uint32_t n) {
    for (int i = 31; i >= 0; i--) printf("%d", (n >> i) & 1);
    // printf("\n");
}

#define Q   12289   // 14'b11000000000001
#define Q0I 12287   // 14'b10111111111111

// max = 12276 = 14'b10111111110100
uint32_t GMb[128] = 
{
    4091, 
    7888, 
    11060, 
    11208, 
    6960, 
    4342, 
    6275, 
    9759, 
    1591, 
    6399, 
    9477, 
    5266, 
    586, 
    5825, 
    7538, 
    9710, 
    1134, 
    6407, 
    1711, 
    965, 
    7099, 
    7674, 
    3743, 
    6442, 
    10414, 
    8100, 
    1885, 
    1688, 
    1364, 
    10329, 
    10164, 
    9180, 
    12210, 
    6240, 
    997, 
    117, 
    4783, 
    4407, 
    1549, 
    7072, 
    2829, 
    6458, 
    4431, 
    8877, 
    7144, 
    2564, 
    5664, 
    4042, 
    12189, 
    432, 
    10751, 
    1237, 
    7610, 
    1534, 
    3983, 
    7863, 
    2181, 
    6308, 
    8720, 
    6570, 
    4843, 
    1690, 
    14, 
    3872, 
    5569, 
    9368, 
    12163, 
    2019, 
    7543, 
    2315, 
    4673, 
    7340, 
    1553, 
    1156, 
    8401, 
    11389, 
    1020, 
    2967, 
    10772, 
    7045, 
    3316, 
    11236, 
    5285, 
    11578, 
    10637, 
    10086, 
    9493, 
    6180, 
    9277, 
    6130, 
    3323, 
    883, 
    10469, 
    489, 
    1502, 
    2851, 
    11061, 
    9729, 
    2742, 
    12241, 
    4970, 
    10481, 
    10078, 
    1195, 
    730, 
    1762, 
    3854, 
    2030, 
    5892, 
    10922, 
    9020, 
    5274, 
    9179, 
    3604, 
    3782, 
    10206, 
    3180, 
    3467, 
    4668, 
    2446, 
    7613, 
    9386, 
    834, 
    7703, 
    6836, 
    3403, 
    5351, 
    12276
};

uint32_t modq_mul(uint32_t a, uint32_t b) {
    // int R = 0x1 << 16;
    uint32_t x = a * b;
    uint32_t y = (x * Q0I) & 0xFFFF; // (...) % R
    uint32_t z = (x + y * Q) >> 16;  // (...) / R
    // printf("%d\t,%d\t,%d\t,%d\t,%d\n", a, b, x, y, z);
    return (z >= Q) ? (z - Q) : z;
}

void NTT(uint32_t *array) {     // 4-bit
    FILE *fp = fopen("NTT_reg.txt", "w");
    for (int i = 0; i < 128; i++) fprintf(fp, "%d, ", array[i]); fprintf(fp, "\n");
    // int t = 128;
    for (int m = 1, ht = 64; m < 128; m <<= 1, ht >>= 1) {
        for (int i = 0, j_1 = 0; i < m; i++, j_1 += (ht << 1)) {
            uint32_t s = GMb[m+i];  // 14-bit
            // printf("GMb[%d]\n", m+i);
            // int j_2 = j_1 + ht;
            for (int j = j_1; j < j_1 + ht; j++) {
                uint32_t u = array[j];                      // 16-bit
                uint32_t v = modq_mul(array[j + ht], s);    // 14-bit, 12288, 14'b11000000000000
                array[j]      = (u + v) % Q;
                // array[j + ht] = (u - v) % Q;
                array[j + ht] = (u >= v) ? (u - v) : (uint32_t)((int64_t)(u + Q) - (int64_t)v); // (u - v) % Q;
                
                
                // printf("%d, %d\n", j, j + ht);
            }
            // printf("\n");
        }
        for (int i = 0; i < 128; i++) fprintf(fp, "%d, ", array[i]); fprintf(fp, "\n");
        // printf("\n");
    }
    fclose(fp);
}

int main(int argc, char **argv) {
    // printf("a\t,b\t,x\t,y\t,z\n");

    // int pattern_num = 100;
    int pattern_num = 1;
    if (argc == 2) pattern_num = atoi(argv[1]);

    // FILE *fp = fopen("NTT_in.txt", "w");
    // FILE *fp_out = fopen("NTT_out.txt", "w");
    // fprintf(fp, "%d\n", pattern_num);

    uint32_t *ntt_array = calloc(128, sizeof(uint32_t));
    srand(0);

    for (int p = 0; p < pattern_num; p++) {
        for (int i = 0; i < 128; i++) ntt_array[i] = rand() % 16; // 4-bit
        // for (int i = 0; i < 128; i++) fprintf(fp, "%d\n", ntt_array[i]);
        NTT(ntt_array);
        // for (int i = 0; i < 128; i++) fprintf(fp_out, "%d\n", ntt_array[i]);

        // fprintf(fp, "\n");
        // fprintf(fp_out, "\n");
    }

    // fclose(fp);
    // fclose(fp_out);
    free(ntt_array);
    return 0;
}
