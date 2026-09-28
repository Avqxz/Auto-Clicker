"""Opening route estimate at two taps/sec; no promo codes or rare pet luck.

Models the combo (two taps/sec stays inside the 1s combo window, so the combo keeps
climbing; each purchase means opening a menu, which breaks it) and the 5% / 2x base
crit as its average (x1.05). Mirrors GameConfig.Combo.
"""
TAPS_PER_SEC = 2
COMBO_TIERS = [(200, 3), (100, 2), (50, 1.5), (25, 1.25), (0, 1)]
CRIT_AVG = 1 + 0.05 * (2 - 1)


def combo_mult(combo):
    return next(m for threshold, m in COMBO_TIERS if combo >= threshold)


coins = 0; power = 1; seconds = 0; pet = 1; passive = 0; combo = 0


def tick():
    global seconds, coins, combo
    seconds += 1
    for _ in range(TAPS_PER_SEC):
        combo += 1
        coins += power * combo_mult(combo) * CRIT_AVG * pet
    coins += passive * pet


route = [('upgrade', 10, 1), ('upgrade', 11, 1), ('egg', 60, 0), ('bot', 25, 0),
         ('upgrade', 13, 1), ('upgrade', 15, 1), ('upgrade', 17, 1)]
for kind, cost, gain in route:
    while coins < cost:
        tick()
    coins -= cost
    combo = 0  # opening the shop/eggs menu breaks the combo
    if kind == 'upgrade': power += gain
    elif kind == 'egg': pet = 1.1
    else: passive = 2
    print(f'{seconds:3d}s {kind}: power={power}, coins={coins:.1f}, combo={combo}')
while coins < 1500:
    tick()
print(f'First rebirth: {seconds}s ({seconds/60:.2f} min)')
assert 90 <= seconds <= 180
