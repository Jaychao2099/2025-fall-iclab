# ==========================================================
#  generate_poker_patterns.py
#  產生 Lab06 Poker.v 測試用測資 (含正確勝者)
# ==========================================================
import itertools, random

# ---------------- Config ----------------
IP_WIDTH = 2      # 玩家數量 (2~9)
N_PATTERNS = 10000 # 測資數量
OUT_FILE = f"patterns_{IP_WIDTH}.txt"

# ---------------- Card encode ----------------
# 編號與花色依 PDF:
# number: 2~14 (J=11, Q=12, K=13, A=14)
# suit: 0=Clubs,1=Diamonds,2=Hearts,3=Spades
deck = [(num, suit) for num in range(2, 15) for suit in range(4)]

# ---------------- Helper functions ----------------
def pack_nums(nums, bits_per=4):
    val = 0
    for n in nums:
        val = (val << bits_per) | (n & ((1 << bits_per) - 1))
    return val

def pack_suits(suits, bits_per=2):
    val = 0
    for s in suits:
        val = (val << bits_per) | (s & ((1 << bits_per) - 1))
    return val

# ---- Poker hand evaluation ----
def evaluate_five(cards):
    """cards: list of (num,suit) length=5"""
    nums = sorted([c[0] for c in cards], reverse=True)
    suits = [c[1] for c in cards]
    counts = {n: nums.count(n) for n in set(nums)}
    is_flush = len(set(suits)) == 1
    uniq_nums = sorted(set(nums), reverse=True)

    # Handle Ace-low straight
    is_straight = False
    high_card = max(nums)
    if len(uniq_nums) == 5:
        if uniq_nums[0] - uniq_nums[4] == 4:
            is_straight = True
        elif uniq_nums == [14,5,4,3,2]:
            is_straight = True
            high_card = 5

    # Hand rank tuple (rank_id, rank_tiebreaker list)
    # Higher rank_id is stronger
    # 9: Royal Flush, 8: Straight Flush, 7: 4K, 6: Full House, 5: Flush, 4: Straight,
    # 3: 3K, 2: Two Pair, 1: One Pair, 0: High Card

    # Straight Flush
    if is_straight and is_flush:
        return (8, [high_card])
    # Four of a Kind
    if 4 in counts.values():
        four = max(k for k,v in counts.items() if v==4)
        kicker = max(k for k,v in counts.items() if v==1)
        return (7, [four, kicker])
    # Full House
    if sorted(counts.values()) == [2,3]:
        three = max(k for k,v in counts.items() if v==3)
        pair  = max(k for k,v in counts.items() if v==2)
        return (6, [three, pair])
    # Flush
    if is_flush:
        return (5, nums)
    # Straight
    if is_straight:
        return (4, [high_card])
    # Three of a Kind
    if 3 in counts.values():
        three = max(k for k,v in counts.items() if v==3)
        kickers = sorted([k for k,v in counts.items() if v==1], reverse=True)
        return (3, [three]+kickers)
    # Two Pair
    pairs = sorted([k for k,v in counts.items() if v==2], reverse=True)
    if len(pairs)==2:
        kicker = max(k for k,v in counts.items() if v==1)
        return (2, pairs+[kicker])
    # One Pair
    if len(pairs)==1:
        pair = pairs[0]
        kickers = sorted([k for k,v in counts.items() if v==1], reverse=True)
        return (1, [pair]+kickers)
    # High Card
    return (0, nums)

def best_five_of_seven(cards7):
    """return best rank tuple for 7 cards"""
    best = (-1, [])
    for comb in itertools.combinations(cards7, 5):
        r = evaluate_five(list(comb))
        if r > best:
            best = r
    return best

# ---------------- Generate random patterns ----------------
with open(OUT_FILE, "w") as f:
    for i in range(N_PATTERNS):
        cards = deck[:]
        random.shuffle(cards)

        # 玩家手牌 (2*IP_WIDTH)
        hole_cards = [cards.pop() for _ in range(2 * IP_WIDTH)]
        pub_cards = [cards.pop() for _ in range(5)]

        # 建立每位玩家的七張牌
        players_hands = []
        for p in range(IP_WIDTH):
            c1 = hole_cards[2*p]
            c2 = hole_cards[2*p + 1]
            players_hands.append([c1, c2] + pub_cards)

        # 評分
        scores = [best_five_of_seven(ph) for ph in players_hands]
        best_score = max(scores)
        winners = [1 if s == best_score else 0 for s in scores]

        # ---------------------------------
        # 轉成輸出格式 (MSB→LSB: player[N-1]→player[0])
        # ---------------------------------
        hole_nums, hole_suits = [], []
        for p in reversed(range(IP_WIDTH)):
            c1 = hole_cards[2*p]
            c2 = hole_cards[2*p + 1]
            hole_nums += [c1[0], c2[0]]
            hole_suits += [c1[1], c2[1]]

        pub_nums = [c[0] for c in pub_cards]
        pub_suits = [c[1] for c in pub_cards]

        in_hole_num  = pack_nums(hole_nums)
        in_hole_suit = pack_suits(hole_suits)
        in_pub_num   = pack_nums(pub_nums)
        in_pub_suit  = pack_suits(pub_suits)

        # winner bits (MSB→LSB: player[N-1]→player[0])
        expected_bits = "".join(str(w) for w in reversed(winners))
        # expected_bits = reversed(expected_bits)  # LSB→MSB
        w_hn = (8 * IP_WIDTH + 3) // 4
        w_hs = (4 * IP_WIDTH + 3) // 4
        w_pn = (20 + 3) // 4
        w_ps = (10 + 3) // 4

        f.write(f"{in_hole_num:0{w_hn}x} {in_hole_suit:0{w_hs}x} "
                f"{in_pub_num:0{w_pn}x} {in_pub_suit:0{w_ps}x} {expected_bits}\n")

print(f"✅ Generated {N_PATTERNS} random patterns with winners to {OUT_FILE}")
