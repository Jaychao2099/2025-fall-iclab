#include <iostream>
#include <vector>
#include <fstream>
#include <random>
#include <algorithm>
#include <cmath>
#include <set>

using namespace std;

struct Point {
    int x, y;
    Point(int x = 0, int y = 0) : x(x), y(y) {}
    
    bool operator<(const Point& other) const {
        if (x != other.x) return x < other.x;
        return y < other.y;
    }
    
    bool operator==(const Point& other) const {
        return x == other.x && y == other.y;
    }
};

class ConvexHullTestGenerator {
private:
    mt19937 gen;
    uniform_int_distribution<int> coord_dis;
    
public:
    ConvexHullTestGenerator() : gen(random_device{}()), coord_dis(0, 1023) {}
    
    // 計算叉積，判斷點的相對位置
    long long crossProduct(const Point& a, const Point& b, const Point& c) {
        return (long long)(b.x - a.x) * (c.y - a.y) - (long long)(b.y - a.y) * (c.x - a.x);
    }
    
    // 檢查三點是否共線
    bool areCollinear(const Point& a, const Point& b, const Point& c) {
        return crossProduct(a, b, c) == 0;
    }
    
    // 生成隨機點
    Point generateRandomPoint() {
        return Point(coord_dis(gen), coord_dis(gen));
    }
    
    // 生成前三個不共線的點形成三角形
    vector<Point> generateInitialTriangle() {
        vector<Point> points;
        set<Point> used_points;
        
        // 生成第一個點
        Point p1 = generateRandomPoint();
        points.push_back(p1);
        used_points.insert(p1);
        
        // 生成第二個點（與第一個點不同）
        Point p2;
        do {
            p2 = generateRandomPoint();
        } while (used_points.count(p2));
        points.push_back(p2);
        used_points.insert(p2);
        
        // 生成第三個點（與前兩個點不共線且不重複）
        Point p3;
        do {
            p3 = generateRandomPoint();
        } while (used_points.count(p3) || areCollinear(p1, p2, p3));
        points.push_back(p3);
        used_points.insert(p3);
        
        return points;
    }
    
    // 生成特定模式的點：在凸包內部、外部、邊界上
    vector<Point> generateSpecialPoints(const vector<Point>& triangle, int num_points, 
                                      double inside_ratio = 0.3, double outside_ratio = 0.6) {
        vector<Point> points;
        set<Point> used_points(triangle.begin(), triangle.end());
        
        int inside_count = (int)(num_points * inside_ratio);
        int outside_count = (int)(num_points * outside_ratio);
        int random_count = num_points - inside_count - outside_count;
        
        // 生成三角形內部的點
        for (int i = 0; i < inside_count; i++) {
            Point p = generatePointInsideTriangle(triangle[0], triangle[1], triangle[2]);
            while (used_points.count(p)) {
                p = generatePointInsideTriangle(triangle[0], triangle[1], triangle[2]);
            }
            points.push_back(p);
            used_points.insert(p);
        }
        
        // 生成三角形外部的點
        for (int i = 0; i < outside_count; i++) {
            Point p = generatePointOutsideTriangle(triangle[0], triangle[1], triangle[2]);
            while (used_points.count(p)) {
                p = generateRandomPoint();
            }
            points.push_back(p);
            used_points.insert(p);
        }
        
        // 生成隨機點
        for (int i = 0; i < random_count; i++) {
            Point p = generateRandomPoint();
            while (used_points.count(p)) {
                p = generateRandomPoint();
            }
            points.push_back(p);
            used_points.insert(p);
        }
        
        return points;
    }
    
    // 使用重心座標生成三角形內部的點
    Point generatePointInsideTriangle(const Point& a, const Point& b, const Point& c) {
        uniform_real_distribution<double> dis(0.0, 1.0);
        
        double r1 = dis(gen);
        double r2 = dis(gen);
        
        // 確保點在三角形內部
        if (r1 + r2 > 1) {
            r1 = 1 - r1;
            r2 = 1 - r2;
        }
        
        double r3 = 1 - r1 - r2;
        
        int x = (int)(r1 * a.x + r2 * b.x + r3 * c.x);
        int y = (int)(r1 * a.y + r2 * b.y + r3 * c.y);
        
        // 確保座標在有效範圍內
        x = max(0, min(1023, x));
        y = max(0, min(1023, y));
        
        return Point(x, y);
    }
    
    // 生成三角形外部的點
    Point generatePointOutsideTriangle(const Point& a, const Point& b, const Point& c) {
        Point p;
        int attempts = 0;
        do {
            p = generateRandomPoint();
            attempts++;
            if (attempts > 1000) break; // 防止無限循環
        } while (isPointInsideTriangle(p, a, b, c) && attempts < 1000);
        
        return p;
    }
    
    // 判斷點是否在三角形內部
    bool isPointInsideTriangle(const Point& p, const Point& a, const Point& b, const Point& c) {
        long long cp1 = crossProduct(a, b, p);
        long long cp2 = crossProduct(b, c, p);
        long long cp3 = crossProduct(c, a, p);
        
        return (cp1 >= 0 && cp2 >= 0 && cp3 >= 0) || (cp1 <= 0 && cp2 <= 0 && cp3 <= 0);
    }
    
    // 生成一個完整的測試模式
    vector<Point> generatePattern(int total_points) {
        if (total_points < 4) {
            cout << "警告：點數量少於4，設置為4" << endl;
            total_points = 4;
        }
        if (total_points > 500) {
            cout << "警告：點數量超過500，設置為500" << endl;
            total_points = 500;
        }
        
        vector<Point> pattern;
        
        // 生成初始三角形
        vector<Point> triangle = generateInitialTriangle();
        pattern.insert(pattern.end(), triangle.begin(), triangle.end());
        
        // 生成剩餘的點
        if (total_points > 3) {
            vector<Point> additional = generateSpecialPoints(triangle, total_points - 3);
            pattern.insert(pattern.end(), additional.begin(), additional.end());
        }
        
        return pattern;
    }
    
    // 生成簡單的隨機模式（完全隨機）
    vector<Point> generateSimplePattern(int total_points) {
        vector<Point> pattern;
        set<Point> used_points;
        
        // 生成初始三角形
        vector<Point> triangle = generateInitialTriangle();
        pattern.insert(pattern.end(), triangle.begin(), triangle.end());
        used_points.insert(triangle.begin(), triangle.end());
        
        // 生成剩餘的隨機點
        for (int i = 3; i < total_points; i++) {
            Point p;
            do {
                p = generateRandomPoint();
            } while (used_points.count(p));
            
            pattern.push_back(p);
            used_points.insert(p);
        }
        
        return pattern;
    }
};

// 讀取現有的input.txt文件
vector<vector<Point>> readInputFile(const string& filename) {
    ifstream file(filename);
    vector<vector<Point>> allPatterns;
    
    if (!file.is_open()) {
        cout << "無法打開文件: " << filename << endl;
        return allPatterns;
    }
    
    int numPatterns;
    file >> numPatterns;
    cout << "讀取到 " << numPatterns << " 個測試模式" << endl;
    
    for (int i = 0; i < numPatterns; i++) {
        int numPoints;
        file >> numPoints;
        cout << "模式 " << (i+1) << ": " << numPoints << " 個點" << endl;
        
        vector<Point> pattern;
        for (int j = 0; j < numPoints; j++) {
            int x, y;
            file >> x >> y;
            pattern.push_back(Point(x, y));
        }
        allPatterns.push_back(pattern);
    }
    
    file.close();
    return allPatterns;
}

// 寫入測試數據到文件
void writeTestData(const vector<vector<Point>>& patterns, const string& filename) {
    ofstream file(filename);
    
    if (!file.is_open()) {
        cout << "無法創建文件: " << filename << endl;
        return;
    }
    
    file << patterns.size() << endl;
    
    for (const auto& pattern : patterns) {
        file << pattern.size() << endl;
        for (const auto& point : pattern) {
            file << point.x << " " << point.y << endl;
        }
    }
    
    file.close();
    cout << "測試數據已寫入 " << filename << endl;
}

// 顯示統計信息
void showStatistics(const vector<vector<Point>>& patterns) {
    cout << "\n=== 測試數據統計 ===" << endl;
    cout << "總模式數: " << patterns.size() << endl;
    
    for (size_t i = 0; i < patterns.size(); i++) {
        cout << "模式 " << (i+1) << ": " << patterns[i].size() << " 個點" << endl;
        
        // 計算座標範圍
        int min_x = 1024, max_x = -1, min_y = 1024, max_y = -1;
        for (const auto& point : patterns[i]) {
            min_x = min(min_x, point.x);
            max_x = max(max_x, point.x);
            min_y = min(min_y, point.y);
            max_y = max(max_y, point.y);
        }
        cout << "  座標範圍: x[" << min_x << "," << max_x << "], y[" << min_y << "," << max_y << "]" << endl;
    }
}

int main() {
    ConvexHullTestGenerator generator;
    
    cout << "=== Convex Hull 測資產生器 ===" << endl;
    cout << "1. 讀取現有input.txt文件並分析" << endl;
    cout << "2. 生成新的測試數據（智能模式）" << endl;
    cout << "3. 生成新的測試數據（簡單隨機模式）" << endl;
    cout << "4. 生成多種規模的測試數據" << endl;
    cout << "5. 生成與原input.txt相似規模的數據" << endl;
    
    int choice;
    cout << "\n請選擇操作模式 (1-5): ";
    cin >> choice;
    
    vector<vector<Point>> patterns;
    
    switch (choice) {
        case 1: {
            // 讀取並分析現有文件
            patterns = readInputFile("input.txt");
            if (!patterns.empty()) {
                showStatistics(patterns);
                
                cout << "\n是否重新輸出到新文件? (y/n): ";
                char yn;
                cin >> yn;
                if (yn == 'y' || yn == 'Y') {
                    writeTestData(patterns, "input_copy.txt");
                }
            }
            break;
        }
        
        case 2: {
            // 智能模式生成
            int numPatterns;
            cout << "輸入模式數量: ";
            cin >> numPatterns;
            
            for (int i = 0; i < numPatterns; i++) {
                int numPoints;
                cout << "輸入模式 " << (i+1) << " 的點數量 (4-500): ";
                cin >> numPoints;
                
                patterns.push_back(generator.generatePattern(numPoints));
                cout << "生成模式 " << (i+1) << " 完成" << endl;
            }
            
            writeTestData(patterns, "smart_generated.txt");
            showStatistics(patterns);
            break;
        }
        
        case 3: {
            // 簡單隨機模式
            int numPatterns;
            cout << "輸入模式數量: ";
            cin >> numPatterns;
            
            for (int i = 0; i < numPatterns; i++) {
                int numPoints;
                cout << "輸入模式 " << (i+1) << " 的點數量 (4-500): ";
                cin >> numPoints;
                
                patterns.push_back(generator.generateSimplePattern(numPoints));
                cout << "生成模式 " << (i+1) << " 完成" << endl;
            }
            
            writeTestData(patterns, "simple_generated.txt");
            showStatistics(patterns);
            break;
        }
        
        case 4: {
            // 多種規模測試
            vector<int> sizes = {10, 25, 50, 100, 200, 300, 450};
            
            cout << "生成多種規模的測試數據..." << endl;
            for (int size : sizes) {
                patterns.push_back(generator.generatePattern(size));
                cout << "生成了 " << size << " 個點的模式" << endl;
            }
            
            writeTestData(patterns, "multi_scale.txt");
            showStatistics(patterns);
            break;
        }
        
        case 5: {
            // 生成與原文件相似規模的數據
            cout << "生成與原input.txt相似規模的數據..." << endl;
            vector<int> sizes = {438, 409, 403}; // 基於原文件的規模
            
            for (int size : sizes) {
                patterns.push_back(generator.generatePattern(size));
                cout << "生成了 " << size << " 個點的模式" << endl;
            }
            
            writeTestData(patterns, "similar_scale.txt");
            showStatistics(patterns);
            break;
        }
        
        default:
            cout << "無效選擇" << endl;
            return 1;
    }
    
    cout << "\n程式執行完成！" << endl;
    return 0;
}