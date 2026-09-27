"""Opening route estimate at two taps/sec; no promo codes or rare pet luck."""
coins=0; power=1; seconds=0; pet=1; passive=0
route=[('upgrade',10,1),('upgrade',11,1),('egg',60,0),('bot',25,0),('upgrade',13,1),('upgrade',15,1),('upgrade',17,1)]
for kind,cost,gain in route:
 while coins<cost:
  seconds+=1; coins+=(2*power+passive)*pet
 coins-=cost
 if kind=='upgrade': power+=gain
 elif kind=='egg': pet=1.1
 else: passive=2
 print(f'{seconds:3d}s {kind}: power={power}, coins={coins:.1f}')
while coins<1500:
 seconds+=1; coins+=(2*power+passive)*pet
print(f'First rebirth: {seconds}s ({seconds/60:.2f} min)')
assert 90<=seconds<=180
