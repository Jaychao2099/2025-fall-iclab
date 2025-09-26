// generate_sudoku.cpp
// 產生指定數量的數獨題目 (每題保證至少一解且唯一解)
// 輸出格式：每行一題（或一解），81 個數以空格分隔，0 表示空格
// 編譯：g++ -std=c++23 -O2 generate_sudoku.cpp -o generate_sudoku
// 執行範例：./generate_sudoku --count 1000 --min_remove 20 --max_remove 60 --input input_1000.txt --output output_1000.txt
#include <bits/stdc++.h>
using namespace std;
using Grid = array<array<int, 9>, 9>;

static std::mt19937_64 rng((std::random_device())());

inline pair<int,int> idx_to_rc(int idx) { return {idx/9, idx%9}; }
inline int block_index(int r,int c) { return (r/3)*3 + (c/3); }

// 檢查能否放置
bool ok_put(const Grid &g, int r, int c, int v) {
    if (g[r][c] != 0) return false;
    for (int j = 0; j < 9; ++j) if (g[r][j] == v) return false;
    for (int i = 0; i < 9; ++i) if (g[i][c] == v) return false;
    int br = (r / 3) * 3, bc = (c / 3) * 3;
    for (int i = br; i < br + 3; ++i)
        for (int j = bc; j < bc + 3; ++j)
            if (g[i][j] == v) return false;
    return true;
}

// 產生完整解 (亂數回溯)
bool generate_full(Grid &g) {
    for (auto &row: g) row.fill(0);
    array<int, 9> digits = {1,2,3,4,5,6,7,8,9};
    function<bool(int)> backtrack = [&](int pos)->bool {
        if (pos == 81) return true;
        int r = pos/9, c = pos%9;
        // shuffle digits
        vector<int> ds(digits.begin(), digits.end());
        shuffle(ds.begin(), ds.end(), rng);
        for (int d: ds) {
            if (ok_put(g,r,c,d)) {
                g[r][c] = d;
                if (backtrack(pos+1)) return true;
                g[r][c] = 0;
            }
        }
        return false;
    };
    return backtrack(0);
}

// 計算解的個數 (上限 limit)
int count_solutions_flat(const array<int,81> &flat, int limit=2) {
    Grid g{};
    for (int r = 0; r < 9; ++r) for (int c = 0; c < 9; ++c) g[r][c] = flat[r*9 + c];
    // bitmask: bit 0 => 1, bit 8 => 9
    array<int,9> rowmask{}, colmask{}, blockmask{};
    vector<pair<int,int>> empties;
    for (int r = 0; r < 9; ++r) {
        for (int c = 0; c < 9; ++c) {
            int v = g[r][c];
            if (v == 0) empties.emplace_back(r,c);
            else {
                int bit = 1 << (v-1);
                if (rowmask[r] & bit) return 0; // 衝突
                if (colmask[c] & bit) return 0;
                int b = block_index(r,c);
                if (blockmask[b] & bit) return 0;
                rowmask[r] |= bit; colmask[c] |= bit; blockmask[b] |= bit;
            }
        }
    }
    int solutions = 0;
    function<void()> backtrack = [&]() {
        if (solutions >= limit) return;
        if (empties.empty()) { ++solutions; return; }
        // 選擇候選最少 (MRV)
        int best_i = -1, best_count = 10;
        int best_mask = 0;
        for (int i = 0; i < (int)empties.size(); ++i) {
            int r = empties[i].first, c = empties[i].second;
            int b = block_index(r,c);
            int mask = (~(rowmask[r] | colmask[c] | blockmask[b])) & 0x1FF;
            if (mask == 0) return; // dead end
            int cnt = __builtin_popcount((unsigned)mask);
            if (cnt < best_count) {
                best_count = cnt;
                best_mask = mask;
                best_i = i;
                if (cnt == 1) break;
            }
        }
        // take out the chosen empty
        auto chosen = empties[best_i];
        empties.erase(empties.begin() + best_i);
        int r = chosen.first, c = chosen.second, b = block_index(r,c);
        int mask = best_mask;
        while (mask && solutions < limit) {
            int lowbit = mask & -mask;
            int d = __builtin_ctz((unsigned)lowbit) + 1; // digit
            mask -= lowbit;
            // place d
            int bit = 1 << (d-1);
            rowmask[r] |= bit; colmask[c] |= bit; blockmask[b] |= bit;
            backtrack();
            rowmask[r] &= ~bit; colmask[c] &= ~bit; blockmask[b] &= ~bit;
        }
        // restore empty
        empties.insert(empties.begin() + best_i, chosen);
    };
    backtrack();
    return solutions;
}

// 從完整解挖空，保證唯一解
Grid make_puzzle_from_solution(const Grid &sol, int min_remove, int max_remove) {
    Grid puzzle = sol;
    int target_remove = min_remove + (int)(rng() % (max_remove - min_remove + 1));
    vector<int> indices(81);
    iota(indices.begin(), indices.end(), 0);
    shuffle(indices.begin(), indices.end(), rng);
    int removed = 0;
    for (int idx: indices) {
        if (removed >= target_remove) break;
        auto [r,c] = idx_to_rc(idx);
        if (puzzle[r][c] == 0) continue;
        int backup = puzzle[r][c];
        puzzle[r][c] = 0;
        array<int,81> flat;
        for (int i = 0; i < 81; ++i) flat[i] = puzzle[i/9][i%9];
        int sc = count_solutions_flat(flat, 2);
        if (sc  ==  1) {
            ++removed;
        } else {
            // restore
            puzzle[r][c] = backup;
        }
    }
    // 無論如何 puzzle 至少會是可解（如果移除失敗會變回完整解）
    return puzzle;
}

string grid_to_line(const Grid &g) {
    stringstream ss;
    for (int r = 0; r < 9; ++r) {
        for (int c = 0; c < 9; ++c) {
            if (r == 0 && c == 0) ss << g[r][c]; else ss << ' '<< g[r][c];
        }
    }
    return ss.str();
}

int main(int argc,char** argv) {
    int count = 1;
    int min_remove = 20, max_remove = 60;
    string out_input = "input_1000.txt", out_output = "output_1000.txt";
    // 簡單參數解析
    for (int i = 1; i < argc; ++i) {
        string s = argv[i];
        if (s == "--count" && i+1<argc) count = stoi(argv[++i]);
        else if (s == "--min_remove" && i+1<argc) min_remove = stoi(argv[++i]);
        else if (s == "--max_remove" && i+1<argc) max_remove = stoi(argv[++i]);
        else if (s == "--input" && i+1<argc) out_input = argv[++i];
        else if (s == "--output" && i+1<argc) out_output = argv[++i];
        else if (s == "--help") { cout << "Usage: " << argv[0] << " [--count N] [--min_remove A] [--max_remove B] [--input file] [--output file]\n"; return 0; }
    }
    if (min_remove<0) min_remove=0; if (max_remove>81) max_remove=81; if (min_remove>max_remove) swap(min_remove,max_remove);
    vector<string> input_lines, output_lines;
    input_lines.reserve(count);
    output_lines.reserve(count);
    for (int i = 0; i < count; ++i) {
        cout << "Generating puzzle " << i+1 << "/...\n";
        Grid full;
        if (!generate_full(full)) {
            cerr << "Failed to generate full solution (unexpected)\n";
            return 1;
        }
        Grid puzzle = make_puzzle_from_solution(full, min_remove, max_remove);
        // double-check unique
        array<int,81> flat;
        for (int k=0;k<81; ++k) flat[k] = puzzle[k/9][k%9];
        int sc = count_solutions_flat(flat, 2);
        if (sc != 1) {
            // 若未達到唯一解，退回使用完整解（完整解是唯一的）
            puzzle = full;
            for (int k=0;k<81; ++k) flat[k] = puzzle[k/9][k%9];
            sc = 1;
        }
        input_lines.push_back(grid_to_line(puzzle));
        output_lines.push_back(grid_to_line(full));
        cout << "  -> puzzle " << i+1 << " done (unique_check=" << sc << ")\n";
    }
    // 寫檔
    ofstream fi(out_input); if (!fi) { cerr << "Cannot open " << out_input << " for writing\n"; return 1; }
    ofstream fo(out_output); if (!fo) { cerr << "Cannot open " << out_output << " for writing\n"; return 1; }
    for (auto &ln: input_lines) fi << ln << "\n";
    for (auto &ln: output_lines) fo << ln << "\n";
    cout << "Wrote " << input_lines.size() << " puzzles to '" << out_input << "' and solutions to '" << out_output << "'\n";
    return 0;
}
