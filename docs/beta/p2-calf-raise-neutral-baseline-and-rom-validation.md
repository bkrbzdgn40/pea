# P2.2 Calf Raise neutral baseline and ROM validation

## Device evidence

The barefoot device session completed three range-rep lifecycles, but all three
were rejected for `insufficientRom`. The visible movement showed full heel
raises while the engine frequently started ROM near the 120-degree threshold
instead of the earlier stable neutral around 110-117 degrees.

## Root cause

For increasing-to-peak movements with retained peak evidence, the generic
engine used the final neutral sample before active confirmation. Calf Raise has
a narrow 120/121/122-degree lifecycle band, so threshold-edge jitter could
replace the physical start baseline and shrink an observed 10-20 degree heel
raise below the 15-degree validation minimum.

## Change

Calf Raise opts into a 1500 ms recent-neutral baseline. Only samples at least
2 degrees inside neutral (`<= 118`) contribute. The engine uses their median as
the rep start metric, preserving the earlier stable stance while rejecting
threshold-edge jitter. Other exercises keep the existing first-crossing
semantics because the feature is disabled by default.

The Calf Raise validation minimum changes from 15 to 10 degrees. The peak gate
remains strict at `> 122`, so an 8-degree 115-to-123 spike is still rejected,
while a real 113-to-123 movement can count.

## Preserved constraints

- neutral / active / peak thresholds are unchanged
- active and peak entry margins are unchanged
- peak exit margin remains 1 degree
- knee-form validation remains unchanged
- other exercises do not use the new baseline window
