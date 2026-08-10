#!/home/epiphane-lamy/Documents/mes_projets_python/mini_CNN/.venv/bin/python3

"""
===========================================================
 ECC Monte-Carlo Fault Injection Platform
-----------------------------------------------------------
Data bits      : 8
Redundancy     : 8
Stored word    : 16 bits = (data || redundancy)
===========================================================
"""

import random
from collections import defaultdict
import matplotlib.pyplot as plt


# =========================================================
#                 Bit manipulation helpers
# =========================================================

def get_bit(x, b):
    return (x >> b) & 1


def set_bit(x, b, value):
    if value:
        return x | (1 << b)
    else:
        return x & ~(1 << b)


# =========================================================
#                     ECC ENCODER
# =========================================================

def encode(data):
    # Encode an 8-bit data word --> redundancy (8 bits)

    d = [get_bit(data, i) for i in range(8)]

    r = [0] * 8

    r[7] = d[5] ^ d[1] ^ d[3]
    r[6] = d[0] ^ d[7]
    r[5] = d[5] ^ d[3] ^ d[2]
    r[4] = d[0] ^ d[6] ^ d[2] ^ d[5] ^ d[1]
    r[3] = d[5] ^ d[3] ^ d[0] ^ d[7]
    r[2] = d[0] ^ d[1] ^ d[5] ^ d[3] ^ d[2]
    r[1] = d[1] ^ d[4] ^ d[3] ^ d[2]
    r[0] = d[0] ^ d[6] ^ d[3] ^ d[2] ^ d[1] ^ d[4]

    redundancy = 0

    for i in range(8):
        redundancy |= (r[i] << i)

    return redundancy


# =========================================================
#                    ECC DECODER
# =========================================================

def decode_from_redundancy(red):
    """
    Reconstruct data from redundancy.
    """

    r = [get_bit(red, i) for i in range(8)]

    d = [0] * 8

    d[7] = r[7] ^ r[3] ^ r[2] ^ r[5]
    d[6] = r[7] ^ r[6] ^ r[5] ^ r[3] ^ r[2] ^ r[1] ^ r[0]
    d[5] = r[7] ^ r[5] ^ r[4] ^ r[1] ^ r[0]
    d[4] = r[6] ^ r[4] ^ r[3] ^ r[0]
    d[3] = r[7] ^ r[6] ^ r[5] ^ r[4] ^ r[3] ^ r[1] ^ r[0]
    d[2] = r[6] ^ r[5] ^ r[3]
    d[1] = r[7] ^ r[6] ^ r[3]
    d[0] = r[7] ^ r[6] ^ r[3] ^ r[2] ^ r[5]

    data = 0

    for i in range(8):
        data |= d[i] << i

    return data


# =========================================================
#                Complete stored word
# =========================================================

def make_codeword(data):

    redundancy = encode(data)

    return (data << 8) | redundancy


def split_codeword(word):

    data = (word >> 8) & 0xFF
    redundancy = word & 0xFF

    return data, redundancy


# =========================================================
#               Decoder / Current correction
# =========================================================

def correct(word):

    d_recv, r_recv = split_codeword(word)

    d_out = decode_from_redundancy(r_recv)

    syndrome_data = d_recv ^ d_out

    r_calc = encode(d_recv)

    syndrome_red = r_recv ^ r_calc

    weight_data = bin(syndrome_data).count('1')
    weight_redundancy = bin(syndrome_red).count('1')

    if weight_data < weight_redundancy:
        corrected = d_out
        corrected_flag = True
    else:
        corrected = d_recv
        corrected_flag = (syndrome_data!=0 or syndrome_red!=0)

    return {
        "output": corrected,
        "corrected": corrected_flag,
        "syndrome_data": syndrome_data,
        "syndrome_red": syndrome_red,
    }


# =========================================================
#              Fault Injection
# =========================================================

def inject_faults(word, num_faults, adjacent=False):

    if num_faults == 0:
        return word

    bits = list(range(16))

    if adjacent:

        start = random.randint(0, 16 - num_faults)

        positions = list(range(start, start + num_faults))

    else:

        positions = random.sample(bits, num_faults)

    corrupted = word

    for b in positions:
        corrupted ^= (1 << b)

    return corrupted, positions


# =========================================================
#             Monte-Carlo Campaign
# =========================================================

def simulate(num_faults,
             trials=10000,
             adjacent=False):

    stats = defaultdict(int)

    for _ in range(trials):

        original = random.randint(0, 255)

        codeword = make_codeword(original)

        faulty, positions = inject_faults(
            codeword,
            num_faults,
            adjacent
        )

        result = correct(faulty)

        output = result["output"]

        corrected = result["corrected"]

        if output == original:

            stats["success"] += 1

        else:

            if corrected:
                stats["false_correction"] += 1
            else:
                stats["detected_not_corrected"] += 1

    return stats


# =========================================================
#                Print
# =========================================================

def report(stats, trials):

    print("----------------------------------------")

    for k in stats:
        print(f"{k:25s}: {stats[k]:6d} ({100*stats[k]/trials:.2f} %)")

    print("----------------------------------------")


# =========================================================
#               Full campaign
# =========================================================
def campaign(trials=10000):

    curve_random = []
    curve_adj    = []

    curve_hamming = [100, 0, 0, 0]

    print("\n========= RANDOM ERRORS =========\n")

    for faults in range(1, 5):

        stats = simulate(
            faults,
            trials,
            adjacent=False
        )

        print(f"\nFaults = {faults}")
        report(stats, trials)

        curve_random.append(
            100 * stats["success"] / trials
        )

    print("\n========= ADJACENT ERRORS =========\n")

    for faults in range(1, 5):

        stats = simulate(
            faults,
            trials,
            adjacent=True
        )

        print(f"\nAdjacent faults = {faults}")
        report(stats, trials)

        curve_adj.append(
            100 * stats["success"] / trials
        )

    # ------------------ Plot ------------------

    plt.figure(figsize=(9, 6), dpi=150)

    plt.plot(
        range(1, 5),
        curve_random,
        'o-',
        linewidth=2.5,
        markersize=8,
        label="Proposed ECC - Random faults"
    )

    plt.plot(
        range(1, 5),
        curve_adj,
        's-',
        linewidth=2.5,
        markersize=8,
        label="Proposed ECC - Adjacent faults"
    )

    plt.plot(
        range(1, 5),
        curve_hamming,
        'o-',
        linewidth=2.5,
        markersize=8,
        label="Hamming SECDED"
    )


    plt.xlabel("Number of flipped bits", fontsize=16)
    plt.ylabel("Correction success (%)", fontsize=16)

    plt.xticks(fontsize=14)
    plt.yticks(fontsize=14)

    plt.legend(fontsize=14)

    plt.grid(True, linestyle="--", alpha=0.6)

    plt.tight_layout()

    plt.show()


# =========================================================
#          Génération du fichier de vecteurs pour l'UVM/TB SV
# =========================================================

def generate_vector_file(filename="vector.txt", trials=10000):
    """
    Génère un fichier texte avec, par ligne :
    data1_corrompu redun1_corrompu data1_correct nb_erreurs burst

    Pour chaque catégorie (1 à 4 erreurs, random puis burst),
    on tire `trials` mots aléatoires.
    """

    with open(filename, "w") as f:

        # --- Random rrors ---
        for num_faults in range(1, 5):
            for _ in range(trials):

                original = random.randint(0, 255)
                codeword = make_codeword(original)

                faulty, _ = inject_faults(codeword, num_faults, adjacent=False)

                d_corrupted, r_corrupted = split_codeword(faulty)

                f.write(f"{d_corrupted} {r_corrupted} {original} {num_faults} 0\n")

        # --- Burst errors ---
        for num_faults in range(1, 5):
            for _ in range(trials):

                original = random.randint(0, 255)
                codeword = make_codeword(original)

                faulty, _ = inject_faults(codeword, num_faults, adjacent=True)

                d_corrupted, r_corrupted = split_codeword(faulty)

                f.write(f"{d_corrupted} {r_corrupted} {original} {num_faults} 1\n")

    print(f"Fichier {filename} généré ({8 * trials} vecteurs).")


# =========================================================

if __name__ == "__main__":

    random.seed()

    campaign(trials=100000)

    #generate_vector_file("vector.txt", trials=10000)