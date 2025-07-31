# MuffinMan

FFXI Sortie 9-boss metric tracking add-on that generates an easy to copy/paste report of the following:

- Party composition for the run
- Aminon battle parse with weaponskill averages (leverages Scoreboard output)
- Tally of total gallimaufry obtained during the run
- Aminon battle duration
- Bonus objective tracking:
    - Ground floor aurum chest 
    - Number of naakual sets completed
    - Which basement mini-NMs were defeated

For statics that are looking to improve and track metrics over time, this add-on cuts down on the time for filtering and screenshotting scoreboard data, organizes the data in a cleaner formatted table, and easily tallies Gallimaufry without the need for doing manual maths based on your existing total.

Usage:

```lua
//lua load muffinman
```

To ensure a clear cache and scoreboard (despite filtering for Aminon), use the `reset` command prior to entering Sortie.

```lua
//mm reset
```

Once the run is over, generate a report which is output to the data folder with the `report` command.

```lua
//mm report
```

Example report output:

```
[Sortie Report - DAY MONTH DD HH:MM:SS 20YY]
Total Gallimaufry: 87,927
-----------------------------
[Completed Bonus Objectives]
Ground floor Aurum Chest
Naakual sets defeated: 1
Tulittia
Naraka
Ixion
Botulus
-----------------------------
[Party Composition]
PLAYER1 (GEO99/DRK58)
PLAYER2 (COR99/DRK59)
PLAYER3 (BRD99/DRK59)
PLAYER4 (DNC99/DRG58)
PLAYER5 (PLD99/RUN58)
PLAYER6 (RDM99/DRK57)
-----------------------------
[Aminon Damage Report]
Name                 Damage       Percent
PLAYER4              2,073,289    38.6%
PLAYER2              932,289      17.3%
PLAYER6              834,728      15.5%
PLAYER1              616,451      11.5%
PLAYER3              559,107      10.4%
PLAYER5              318,947      5.9%
Skillchain (P4)      21,561       0.4%
Skillchain (P6)      13,390       0.2%
Skillchain (P5)      6,215        0.1%
Skillchain (P2)      202          0.0%
-----------------------------
[Weaponskill Averages]
Name            WS Avg     Count
PLAYER4         96,932     21
PLAYER6         83,375     10
PLAYER2         66,588     14
PLAYER3         62,123     9
PLAYER1         47,406     13
PLAYER5         38,461     8
-----------------------------
[Aminon Fight Duration] 
5 min 6 sec
```


While the gallimaufry tally is reported each time more gallimaufry is obtained, you can use the `total` command to check the curren tally any time.

```lua
//mm total
```


Todo:

- Add functionality for sending data to Discord channel via webhook
- Collect COR roll data for Aminon
- Number of +1 chests obtained