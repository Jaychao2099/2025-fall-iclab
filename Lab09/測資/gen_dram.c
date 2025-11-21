#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// 結構定義參考 Note 1: [MSB] {HP, Month, Day, Attack, Defense, Exp, MP} [LSB]

int main() {
    FILE *fp = fopen("dram.dat", "w");
    if (fp == NULL) {
        printf("Error: Cannot create dram.dat\n");
        return 1;
    }

    // 設定隨機種子
    srand((unsigned int)time(NULL));

    int start_addr = 0x10000;
    int num_players = 256;

    printf("Generating dram.dat for %d players...\n", num_players);

    for (int i = 0; i < num_players; i++) {
        // 1. 生成屬性 (0-65535)
        // HP 設為 1-65535 以避免初始死亡 (雖然 Spec 沒規定，但比較合理)
        // int hp = (rand() % 65535) + 1;
        int hp = rand() % 65536;
        int mp = rand() % 65536;
        int exp = rand() % 65536;
        int atk = rand() % 65536;
        int def = rand() % 65536;

        // 2. 生成日期
        int month = (rand() % 12) + 1;
        int max_days;
        
        if (month == 2) {
            max_days = 28; // Spec Note 2: February only has 28 days
        } else if (month == 4 || month == 6 || month == 9 || month == 11) {
            max_days = 30;
        } else {
            max_days = 31;
        }
        
        int day = (rand() % max_days) + 1;

        // 3. 將數據填入 Byte Array
        unsigned char data[12];

        // Word 1: HP, Month, Day
        data[0] = mp & 0xFF;
        data[1] = (mp >> 8) & 0xFF;
        data[2] = exp & 0xFF;
        data[3] = (exp >> 8) & 0xFF;

        // Word 2: Attack, Defense
        data[4] = def & 0xFF;
        data[5] = (def >> 8) & 0xFF;
        data[6] = atk & 0xFF;
        data[7] = (atk >> 8) & 0xFF;

        // Word 3: Exp, MP
        data[8] = day & 0xFF;
        data[9] = month & 0xFF;
        data[10] = hp & 0xFF;
        data[11] = (hp >> 8) & 0xFF;

        // 4. 寫入檔案 (每4 Bytes一行)
        // Address 0
        fprintf(fp, "@%05X\n", start_addr);
        fprintf(fp, "%02X %02X %02X %02X\n", data[0], data[1], data[2], data[3]);

        // Address 4
        fprintf(fp, "@%05X\n", start_addr + 4);
        fprintf(fp, "%02X %02X %02X %02X\n", data[4], data[5], data[6], data[7]);

        // Address 8
        fprintf(fp, "@%05X\n", start_addr + 8);
        fprintf(fp, "%02X %02X %02X %02X\n", data[8], data[9], data[10], data[11]);

        start_addr += 12;
    }

    fclose(fp);
    printf("Done! File 'dram.dat' generated.\n");

    return 0;
}