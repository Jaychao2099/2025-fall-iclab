#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// 結構定義參考 Note 1: [MSB] {HP, Month, Day, Attack, Defense, Exp, MP} [LSB]
// 優化說明：不修改 Mapping，僅修改數值生成的機率分佈，以協助 Coverage 收斂。

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

    printf("Generating optimized dram.dat for %d players...\n", num_players);

    for (int i = 0; i < num_players; i++) {
        int hp, mp, exp, atk, def;
        int month, day;

        // ==================================================================================
        // 優化數值生成策略 (Strategy Pattern)
        // ==================================================================================
        
        if (i % 10 == 0) {
            // [Group 1: 瀕死/弱小玩家] -> 針對 HP_Warn (HP=0)
            hp = 0;                 // 觸發 HP_Warn
            mp = rand() % 100;      // MP 不足
            exp = 0;                // Exp 不足
            atk = 0;
            def = 0;
            month = (rand() % 12) + 1;
            day = 1; 
        } 
        else if (i % 10 == 1) {
            // [Group 2: 極限玩家] -> 針對 Saturation_Warn (數值接近 65535)
            hp = 65500 + (rand() % 35);
            mp = 65500 + (rand() % 35);
            exp = 65500 + (rand() % 35);
            atk = 65500 + (rand() % 35);
            def = 65500 + (rand() % 35);
            month = (rand() % 12) + 1;
            day = 1;
        }
        else if (i % 10 == 2) {
            // [Group 3: 臨界值玩家] -> 針對 Saturation_Warn (中高數值，加一點就爆)
            hp = 64000;
            mp = 64000;
            exp = 64000;
            atk = 64000;
            def = 64000;
            month = (rand() % 12) + 1;
            day = 15;
        }
        else if (i % 10 == 3) {
            // [Group 4: 冬眠玩家] -> 針對 Date_Warn (>90天)
            // 設定為年初，Pattern 隨機到年中時就會觸發
            hp = (rand() % 65535) + 1;
            mp = rand() % 65536;
            exp = rand() % 65536;
            atk = rand() % 65536;
            def = rand() % 65536;
            month = 1; 
            day = 1;
        }
        else if (i % 10 == 4) {
             // [Group 5: 技能測試玩家] -> MP 極少，測試 Use Skill 失敗
            hp = 1000;
            mp = 10; // MP 極低
            exp = rand() % 65536;
            atk = rand() % 65536;
            def = rand() % 65536;
            month = (rand() % 12) + 1;
            day = 1;
        }
        else {
            // [Group 0: 一般隨機玩家] -> 填充其餘 Bins
            hp = rand() % 65536;
            mp = rand() % 65536;
            exp = rand() % 65536;
            atk = rand() % 65536;
            def = rand() % 65536;
            month = (rand() % 12) + 1;
            day = (rand() % 28) + 1; // 簡化天數生成
        }

        // 修正日期邊界 (雖然後面的邏輯已簡化，但為了安全檢查一下)
        int max_days;
        if (month == 2) max_days = 28;
        else if (month == 4 || month == 6 || month == 9 || month == 11) max_days = 30;
        else max_days = 31;
        if (day > max_days) day = max_days;

        // ==================================================================================
        // 以下 Mapping 邏輯完全保持原樣
        // ==================================================================================

        // 3. 將數據填入 Byte Array
        unsigned char data[12];

        // Word 1: HP, Month, Day (注意：您的原始代碼這裡是填 MP 和 Exp，我保持您的原始邏輯)
        // 根據您的原始代碼:
        // data[0-1] 是 MP
        // data[2-3] 是 Exp
        data[0] = mp & 0xFF;
        data[1] = (mp >> 8) & 0xFF;
        data[2] = exp & 0xFF;
        data[3] = (exp >> 8) & 0xFF;

        // Word 2: Attack, Defense
        // 根據您的原始代碼:
        // data[4-5] 是 Def
        // data[6-7] 是 Atk
        data[4] = def & 0xFF;
        data[5] = (def >> 8) & 0xFF;
        data[6] = atk & 0xFF;
        data[7] = (atk >> 8) & 0xFF;

        // Word 3: Exp, MP (注意：您的原始代碼這裡是填 Day, Month, HP)
        // data[8] 是 Day
        // data[9] 是 Month
        // data[10-11] 是 HP
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
    printf("Done! Optimized 'dram.dat' generated.\n");

    return 0;
}