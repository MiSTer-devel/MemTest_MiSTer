# MemTest - Utility to test SDRAM daughter board.

## Screen shows 2 numbers:
* Upper (green) number shows passed cycles (each cycle is 32MB)
* Lower (red) number shows amount of errors.

There are several versions for different frequencies in release folder. Test is passed if amount of errors is 0.
For quick test let it run for 10 minutes. If you want to be sure, let it run for 1-2 hours.
Board should pass at least 120MHz clock test. Any higher clock will assure the higher quality of the board.
