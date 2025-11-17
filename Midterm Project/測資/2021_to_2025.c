#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "用法: %s input.txt output.txt\n", argv[0]);
        return 1;
    }

    const char *inpath = argv[1];
    const char *outpath = argv[2];

    FILE *fin = fopen(inpath, "r");
    if (!fin) {
        perror("開啟輸入檔失敗");
        return 1;
    }
    FILE *fout = fopen(outpath, "w");
    if (!fout) {
        perror("開啟輸出檔失敗");
        fclose(fin);
        return 1;
    }

    char line[1024];
    while (fgets(line, sizeof(line), fin)) {
        size_t len = strlen(line);

        // 保留原始換行符號（若有）
        int has_newline = (len > 0 && line[len-1] == '\n');

        // 去掉結尾的換行, 方便處理
        if (has_newline) line[--len] = '\0';

        // 若空行或只包含空白，直接複製
        int allspace = 1;
        for (size_t i = 0; i < len; ++i) if (!isspace((unsigned char)line[i])) { allspace = 0; break; }
        if (len == 0 || allspace) {
            if (has_newline) fputs("\n", fout); else fputs("", fout);
            continue;
        }

        // 若第一個非空白字元是 '@' -> 不改寫，直接寫回（保持行尾換行）
        size_t pos = 0;
        while (pos < len && isspace((unsigned char)line[pos])) ++pos;
        if (pos < len && line[pos] == '@') {
            // 寫回原行（恢復換行）
            fputs(line, fout);
            if (has_newline) fputc('\n', fout);
            continue;
        }

        // 嘗試解析兩個 hex byte（允許前後有空白）
        unsigned int a = 0, b = 0;
        // 使用 sscanf 從字串中擷取兩個 hex
        // %2x 會讀最多兩個 hex digits（安全）
        int matched = sscanf(line, " %2x %2x", &a, &b);

        if (matched == 2) {
            uint8_t byte_a = (uint8_t)(a & 0xFF); // 左邊 token
            uint8_t byte_b = (uint8_t)(b & 0xFF); // 右邊 token

            // 左右半互換成 16-bit（b 為高位）
            uint16_t val = ((uint16_t)byte_b << 8) | (uint16_t)byte_a;

            // 取最高 3 bit (bits 15..13)
            unsigned top3 = (val >> 13) & 0x7;

            if (top3 == 0 || top3 == 1) {
                // MSB 為 000 或 001：對 LSB 做 NOT（只反轉低 8 bit）
                uint8_t lsb = (~(uint8_t)(val & 0x00FF)) & 0xFF;
                val = (val & 0xFF00) | (uint16_t)lsb;
            } else {
                // 其他情況 (010/011/100/101) -> toggle bit13
                val ^= (1u << 13);
            }

            // 將改寫結果轉為 hex，並左右半互換回輸出格式（先取低位再高位）
            uint8_t out_a = (uint8_t)(val & 0x00FF);
            uint8_t out_b = (uint8_t)((val >> 8) & 0x00FF);

            // 小寫兩位 hex，中間一格，然後換行
            fprintf(fout, "%02x %02x", out_a, out_b);
            if (has_newline) fputc('\n', fout);
        } else {
            // 無法解析成 "xx yy" 格式：原樣寫回（保留換行）
            fputs(line, fout);
            if (has_newline) fputc('\n', fout);
        }
    }

    fclose(fin);
    fclose(fout);
    return 0;
}
