# ERIM Data Discrete Choice Models

To estimate the simple quadratic (`QUAD`) model with a very high (`VHIGH`) interest rate  (assuming that there is a dataset in the data directory called `pbutter.dta`):

```bash
./pbs pbutter VHQ VHIGH+QUAD
```

When the model completes output and log files will be in the *output/* folder. `pbutterVHQ.log`,
`pbutterVHQ.optobj` and `pbutterVHQ.out` should be created as output.

To run all the models used in the paper on `sharcnet`:

```bash
./run
```
