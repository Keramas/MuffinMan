# MuffinMan

FFXI Sortie 9-boss metric tracking add-on that generates an easy to copy/paste report of the following:

- Party composition for the run
- Bosses defeated during the run
- Aminon battle data:
    - Full party parse with weaponskill averages (leverages Scoreboard output)
    - Battle duration
    - Corsair's Miser/Tact roll values and Wild Card values
- Tally of total gallimaufry obtained during the run
- Bonus objective tracking:
    - Ground floor aurum chest 
    - Number of naakual sets completed
    - Which basement mini-NMs were defeated
- Number of +1 chests obtained

By adding a Discord webhook, you can easily send the report to your group's Discord channel as well.

For statics that are looking to improve and track metrics over time, this add-on cuts down on the time for filtering and screenshotting scoreboard data, organizes the data in a cleaner formatted table, and easily tallies Gallimaufry without the need for doing manual maths based on your existing total.

Usage:

```lua
//lua load muffinman
```

Interact with the addon via either `muff`, `muffins`, or `muffinman`.

To ensure a clear cache and scoreboard (despite filtering for Aminon), use the `reset` command prior to entering Sortie.

```lua
//muffins reset
```

To enable/disable automatic report sending to a Discord channel via webhook, use the `discord` command. 

```lua
//muffins discord
```
Additionally, once your webhook has been generated, add it to the top of the `muffinman.lua` file replacing the placeholder text:

```lua
local webhook_url = "ADD YOUR WEBHOOK HERE"
```

If fighting Aminon hardmode, you can enable this for the report and also track Meso drops:

```lua
//muffins hm
```

You can also add a note at the bottom of the report for any additional mentions (who got a +2 etc):

```lua
//muffins addnote YOURMESSAGE
```

Once the run is over, generate a report which is output to the data folder with the `report` command. If pushes to Discord have been enabled, this will also be pushed to the channel associated with the webhook.

```lua
//muffins report
```

Example report output:

```
[Sortie Report - DAY MONTH DD HH:MM:SS 20YY]
Total Gallimaufry: 87,927
Total Old Case +1: 1
-----------------------------
[Defeated Bosses]
Degei
Aita
Triboulex
Leshonn
Dhartok
Skomora
Gartell
Ghatjot
Aminon
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
[COR Rolls]
Miser's: 5 (Lucky!)
Tactician's: 5 (Lucky!)
Wild Card: 5
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


While the gallimaufry tally is reported each time more gallimaufry is obtained, you can use the `total` command to check the currency tally any time.

```lua
//muffins total
```
