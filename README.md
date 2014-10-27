# ERIM Data Discrete Choice Models

To the simple model (assuming that there is a dataset in the data directory called `pbutter.dta`:

```
./pbs pbutter _fullQUAD
```

When the model completes output and log files will be in the *output/* folder. `pbutter_fullQUAD.log`,
`pbutter_fullQUAD.optobj` and `pbutter_fullQUAD.optobj` should be created as output.

The `pbs` bash script has the following line

```
oxl -DVHIGH+QUAD+COMPLEX -c <files>
```

The `-D` switch `VHIGH` sets the discount rate, `QUAD` sets the inventory holding cost to be quadratic
and `COMPLEX` adds coupon transition and brand preference variables.

Logfiles are [here](https://gist.github.com/ff7039506fa6c8dd40a1)
