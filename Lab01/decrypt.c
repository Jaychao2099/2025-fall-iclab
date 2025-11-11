#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>

void print_binary_16(uint16_t n) {
    for (int i = 16; i >= 0; i--) {
        uint16_t mask = 1u << i;
        putchar((n & mask) ? '1' : '0');
    }
    putchar('\n');
}

uint16_t ROR(uint16_t x, int shift) {
    for (int i = 0; i < shift; i++) {
        uint16_t cf = (x & 1) ? (uint16_t)0x8000U : 0U;
        x = (x >> 1) | cf;
    }
    return x;
}

uint16_t ROL(uint16_t x, int shift) {
    for (int i = 0; i < shift; i++) {
        uint16_t cf = (x & 0x8000) ? 1U : 0U;
        x = (x << 1) | cf;
    }
    return x;
}

void handle_packets(char *p, uint16_t *packets, int size) {
    char *token = strtok(p, "_");
    int i = size - 1;
    while (token != NULL) {
        packets[i] = (uint16_t)strtol(token, NULL, 16);
        token = strtok(NULL, "_");
        i--;
    }
}

void handle_key(char *k, uint16_t *key, int size) {
    char *token = strtok(k, "_");
    int i = size - 1;
    while (token != NULL) {
        key[i] = (uint16_t)strtol(token, NULL, 16);
        token = strtok(NULL, "_");
        i--;
    }
}

int main() {
    char p[] = "2b1a_8439_817f_70fa_7f05_e461_9a75_45db";
    uint16_t *packets = malloc(8 * sizeof(uint16_t));

    handle_packets(p, packets, 8);

    // printf("packets[2] = %x\n", packets[2]);


    uint16_t *key = malloc(4 * sizeof(uint16_t));
    char k[] = "ac3d_bbde_3c63_40c2";

    handle_key(k, key, 4);

    // printf("key[1] = %x\n", key[1]);

    uint16_t k0, k1, k2, k3;
    k0 = key[0];
    k1 = ((ROR(k0, 7) + key[1])) ^ 0;
    k2 = ((ROR(k1, 7) + key[2])) ^ 1;
    k3 = ((ROR(k2, 7) + key[3])) ^ 2;

    print_binary_16(k0);
    print_binary_16(k1);
    print_binary_16(k2);
    print_binary_16(k3);

    int x0, x1, x2, x3;
    int y0, y1, y2, y3;

    uint16_t de[8];

    y3 = ROR(packets[1] ^ packets[0], 2);
    x3 = ROL((packets[0] ^ k3) - y3, 7);
    y2 = ROR(y3 ^ x3, 2);
    x2 = ROL((x3 ^ k2) - y2, 7);
    y1 = ROR(y2 ^ x2, 2);
    x1 = ROL((x2 ^ k1) - y1, 7);
    y0 = ROR(y1 ^ x1, 2);
    x0 = ROL((x1 ^ k0) - y0, 7);
    de[0] = x0;
    de[1] = y0;

    y0 = ROR(packets[3] ^ packets[2], 2);
    x0 = ROL((packets[2] ^ k3) - y0, 7);
    y3 = ROR(y0 ^ x0, 2);
    x3 = ROL((x0 ^ k2) - y3, 7);
    y2 = ROR(y3 ^ x3, 2);
    x2 = ROL((x3 ^ k1) - y2, 7);
    y1 = ROR(y2 ^ x2, 2);
    x1 = ROL((x2 ^ k0) - y1, 7);
    de[2] = x1;
    de[3] = y1;

    y1 = ROR(packets[5] ^ packets[4], 2);
    x1 = ROL((packets[4] ^ k3) - y1, 7);
    y0 = ROR(y1 ^ x1, 2);
    x0 = ROL((x1 ^ k2) - y0, 7);
    y3 = ROR(y0 ^ x0, 2);
    x3 = ROL((x0 ^ k1) - y3, 7);
    y2 = ROR(y3 ^ x3, 2);
    x2 = ROL((x3 ^ k0) - y2, 7);
    de[4] = x2;
    de[5] = y2;

    y2 = ROR(packets[7] ^ packets[6], 2);
    x2 = ROL((packets[6] ^ k3) - y2, 7);
    y1 = ROR(y2 ^ x2, 2);
    x1 = ROL((x2 ^ k2) - y1, 7);
    y0 = ROR(y1 ^ x1, 2);
    x0 = ROL((x1 ^ k1) - y0, 7);
    y3 = ROR(y0 ^ x0, 2);
    x3 = ROL((x0 ^ k0) - y3, 7);
    de[6] = x3;
    de[7] = y3;

    // uint16_t prefer_ch[8];

    // for (int i = 0; i < 8; i++) {
    //     printf("de[%d] = %x = ", i, de[i]);
    //     print_binary_16(de[i]);
    // }

    for (int i = 7; i >= 0; i--) {
        printf("%x", de[i]);
        if (i > 0) printf("_");
    }
    printf("\n");

    return 0;
}