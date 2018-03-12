# MemTest - Utility to test SDRAM daughter board.

## Screen shows 4 numbers:
* Upper left is time in minutes passed.
* Upper right is memory frequency in MHz.
* Middle (green) is amount of passed cycles (each cycle is 32MB)
* Lower (red) is amount of errors.
* Dash in cyan color will fly on top in auto mode.

## Controls (keyboard)
* Up - increase frequency
* Down - decrease frequency
* Enter - reset the test
* A - auto mode, detecting the maximum frequency for module being tested. Test starts from maximum frequency.
With every error frequency will be decreased.

Test is passed if amount of errors is 0. For quick test let it run for 10 minutes in auto mode. If you want to be sure, let it run for 1-2 hours.
Board should pass at least 130MHz clock test. Any higher clock will assure the higher quality of the board.
