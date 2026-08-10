#!/home/epiphane-lamy/Documents/mes_projets_python/mini_CNN/.venv/bin/python3

import matplotlib.pyplot as plt
import numpy as np

# -------------------------------------------------------------------------
# Data Definition
# -------------------------------------------------------------------------
# STD 45nm Sweep Points
freq_std = [50, 100, 150, 200, 250, 300, 335]
surface_std = [8246.646, 8310.942, 8299.998, 8345.826, 8506.908, 8627.634, 8883.792] # um^2
power_std = [0.123, 0.250, 0.373, 0.5, 0.640, 0.768, 0.892]                 # in mW

# RHBD 180nm Single Point
freq_rhbd = 80                                      # Clock period 12.5ns -> 80 MHz
surface_rhbd = 527338.766                           # um^2
power_rhbd = 46.617                                 # mW

# -------------------------------------------------------------------------
# Plot Configuration (Two subplots side-by-side)
# -------------------------------------------------------------------------
fig, (ax1, ax3) = plt.subplots(1, 2, figsize=(14, 6), dpi=300)

color_surf = '#2b5c8f'  # Slate Blue
color_pwr = '#d95f02'   # Muted Orange

# =========================================================================
# LEFT SUBPLOT: 45nm Sweep Trend (Linear Scale)
# =========================================================================
ax1.set_xlabel('Fréquence (MHz)', fontsize=10, fontweight='bold', labelpad=8)
ax1.set_ylabel('Surface du cœur (µm²)', color=color_surf, fontsize=10, fontweight='bold')
line1 = ax1.plot(freq_std, surface_std, color=color_surf, marker='o', linewidth=2, label='Surface 45nm')
ax1.tick_params(axis='y', labelcolor=color_surf)
ax1.grid(True, linestyle=':', alpha=0.6)

# Dual axis for Power
ax2 = ax1.twinx()
ax2.set_ylabel('Puissance Totale (mW)', color=color_pwr, fontsize=10, fontweight='bold')
line2 = ax2.plot(freq_std, power_std, color=color_pwr, marker='s', linewidth=2, linestyle='--', label='Puissance 45nm')
ax2.tick_params(axis='y', labelcolor=color_pwr)

# Combine legends for the first plot
lines = line1 + line2
labels = [l.get_label() for l in lines]
ax1.legend(lines, labels, loc='upper left', frameon=True, facecolor='#f8f9fa')
ax1.set_title('a) Évolution du cache Standard Cell 45nm', fontsize=11, fontweight='bold', pad=10)

# =========================================================================
# RIGHT SUBPLOT: Architectural Comparison (Logarithmic Scale)
# =========================================================================
categories = ['Std Cell (335 MHz)', 'RHBD (80 MHz)']
surfaces = [surface_std[-1], surface_rhbd]
powers = [power_std[-1], power_rhbd]

x = np.arange(len(categories))
width = 0.35

# Set logarithmic scale to handle the huge data gap
ax3.set_yscale('log')
rects1 = ax3.bar(x - width/2, surfaces, width, label='Surface (µm²)', color='#4292c6', edgecolor='#1f77b4')
rects2 = ax3.bar(x + width/2, powers, width, label='Puissance (mW)', color='#fdd0a2', edgecolor='#d95f02', hatch='//')

ax3.set_xticks(x)
ax3.set_xticklabels(categories, fontweight='bold')
ax3.set_ylabel('Valeurs (Échelle Logarithmique)', fontsize=10, fontweight='bold')
ax3.legend(loc='upper left', frameon=True, facecolor='#f8f9fa')
ax3.grid(True, linestyle=':', alpha=0.4, which="both")
ax3.set_title('b) Coût macroscopique du durcissement (RHBD)', fontsize=11, fontweight='bold', pad=10)

# Add text values on top of the bars for clarity
for rect in rects1:
    h = rect.get_height()
    ax3.annotate(f'{int(h):,}', xy=(rect.get_x() + rect.get_width()/2, h),
                 xytext=(0, 3), textcoords="offset points", ha='center', va='bottom', fontsize=9, fontweight='bold')
for rect in rects2:
    h = rect.get_height()
    ax3.annotate(f'{h:.2f}', xy=(rect.get_x() + rect.get_width()/2, h),
                 xytext=(0, 3), textcoords="offset points", ha='center', va='bottom', fontsize=9, fontweight='bold')

# -------------------------------------------------------------------------
# Global Layout Polish
# -------------------------------------------------------------------------
plt.suptitle('Exploration de l\'Espace de Conception (DSE) & Impact du Durcissement Spatial',
             fontsize=13, fontweight='bold', y=0.98)
fig.tight_layout()

# Save the high-resolution figure for your report
plt.savefig('dse_subplots_comparison.png', dpi=300)